extends Node

############################################################################

@export var texture_resolution : Vector2i = Vector2i(512, 512)
@export var texture_size : Vector2 = Vector2(512, 512)
@export var water_material : ShaderMaterial
@export_range(1.0, 10.0, 0.1) var damp : float = 1.0

var ripple_texture_centers := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]

var t = 0.0
var max_t = 0.1

var water_texture : Texture2DRD
var next_texture : int = 0

func _ready():
	RenderingServer.call_on_render_thread(_initialize_compute_code.bind(texture_resolution))

	if water_material:
		water_material.set_shader_parameter("waves_texture_resolution", texture_resolution)
		water_material.set_shader_parameter("waves_texture_size", texture_size)
		water_texture = water_material.get_shader_parameter("waves_texture")


func _exit_tree():
	if water_texture:
		water_texture.texture_rd_rid = RID()

	RenderingServer.call_on_render_thread(_free_compute_resources)


func _process(delta):
	next_texture = (next_texture + 1) % 3

	if water_texture:
		water_texture.texture_rd_rid = texture_rds[next_texture]

	RenderingServer.call_on_render_thread(_render_process.bind(next_texture, Vector4.ZERO, texture_resolution, texture_size, damp))

###############################################################################
# Everything after this point is designed to run on our rendering thread.

var rd : RenderingDevice

var shader : RID
var pipeline : RID

# We use 3 textures:
# - One to render into
# - One that contains the last frame rendered
# - One for the frame before that
var texture_rds : Array = [ RID(), RID(), RID() ]
var texture_sets : Array = [ RID(), RID(), RID() ]

func _create_uniform_set(texture_rd : RID) -> RID:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(texture_rd)
	# Even though we're using 3 sets, they are identical, so we're kinda cheating.
	return rd.uniform_set_create([uniform], shader, 0)


func _initialize_compute_code(texture_resolution):
	rd = RenderingServer.get_rendering_device()

	# Create our shader.
	var shader_file = load("res://water/waves/water_waves_compute.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	pipeline = rd.compute_pipeline_create(shader)

	# Create our textures to manage our wave.
	var tf : RDTextureFormat = RDTextureFormat.new()
	tf.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	tf.width = texture_resolution.x
	tf.height = texture_resolution.y
	tf.depth = 1
	tf.array_layers = 1
	tf.mipmaps = 1
	tf.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT + RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT + RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT

	for i in range(3):
		# Create our texture.
		texture_rds[i] = rd.texture_create(tf, RDTextureView.new(), [])

		# Make sure our textures are cleared.
		rd.texture_clear(texture_rds[i], Color(0, 0, 0, 0), 0, 1, 0, 1)

		# Now create our uniform set so we can use these textures in our shader.
		texture_sets[i] = _create_uniform_set(texture_rds[i])


func _render_process(with_next_texture, wave_point, tex_resolution, tex_size, damp):
	# We don't have structures (yet) so we need to build our push constant
	# "the hard way"...
	var push_constant : PackedFloat32Array = PackedFloat32Array()
	push_constant.push_back(wave_point.x)
	push_constant.push_back(wave_point.y)
	push_constant.push_back(wave_point.z)
	push_constant.push_back(wave_point.w)

	push_constant.push_back(tex_resolution.x)
	push_constant.push_back(tex_resolution.y)
	push_constant.push_back(damp)
	push_constant.push_back(0.0)

	var x_groups = (tex_resolution.x - 1) / 8 + 1
	var y_groups = (tex_resolution.y - 1) / 8 + 1

	var next_set = texture_sets[with_next_texture]
	var current_set = texture_sets[(with_next_texture - 1) % 3]
	var previous_set = texture_sets[(with_next_texture - 2) % 3]

	# Run our compute shader.
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, current_set, 0)
	rd.compute_list_bind_uniform_set(compute_list, previous_set, 1)
	rd.compute_list_bind_uniform_set(compute_list, next_set, 2)
	rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
	rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
	rd.compute_list_end()

func _free_compute_resources():
	for i in range(3):
		if texture_rds[i]:
			rd.free_rid(texture_rds[i])

	if shader:
		rd.free_rid(shader)
