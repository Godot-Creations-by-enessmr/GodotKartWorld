extends Node

@export var texture_resolution : Vector2i = Vector2i(512, 512)
@export var texture_size : Vector2 = Vector2(64, 64)
@export var texture_offset : Vector3 = Vector3.ZERO
@export var water_material : ShaderMaterial
@export var damp : float = 1.0
@export var c2 : float = 0.09

@export var texture_target : String = "waves_texture"

var ripple_texture_centers : Array[Vector2i] = [Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO]
var texture_pixel_offset : Vector2i
var ripple_origins : Array[Vector4] = [];

#used for CPU side collisions
@export var use_cpu_readback : bool = true
@export var cpu_readback_interval : int = 2
var water_image : Image 



var t = 0.0
var max_t = 0.1

var water_texture : Texture2DRD
var next_texture : int = 0
var frame_number : int = 0

func add_ripple(position: Vector3, radius: float, strength: float) -> void:
	var pixel_position : Vector2i = Vector2(texture_resolution) / texture_size * Vector2(position.x, position.z)
	pixel_position -= texture_pixel_offset - Vector2i(texture_resolution * 0.5)
	ripple_origins.append(Vector4(pixel_position.x, pixel_position.y, radius, strength))

func _ready():
	# In case we're running stuff on the rendering thread
	# we need to do our initialisation on that thread.
	RenderingServer.call_on_render_thread(_initialize_compute_code.bind(texture_resolution))

	for i in range(len(ripple_texture_centers)):
		ripple_texture_centers[i] = Vector2i.ZERO
		
	water_texture = Texture2DRD.new()
	
	if use_cpu_readback:
		water_image = Image.create(texture_resolution.x, texture_resolution.y, false, Image.FORMAT_RF)	
		
	if water_material:
		water_material.set_shader_parameter(texture_target, water_texture)
		water_material.set_shader_parameter(texture_target + "_resolution", texture_resolution)
		water_material.set_shader_parameter(texture_target + "_size", texture_size)


func _exit_tree():
	# Make sure we clean up!
	if water_texture:
		water_texture.texture_rd_rid = RID()

	RenderingServer.call_on_render_thread(_free_compute_resources)

func _process(delta):
	next_texture = (next_texture + 1) % 3
	if water_texture:
		water_texture.texture_rd_rid = texture_rds[next_texture]
	var offset = Vector2(texture_offset.x, texture_offset.z);
	var offset_scalar = Vector2(texture_resolution) / texture_size
	texture_pixel_offset = offset_scalar * offset
	
	ripple_texture_centers[next_texture] = texture_pixel_offset;
		
	if water_material:		
		water_material.set_shader_parameter(texture_target + "_offset", Vector2(texture_pixel_offset) / offset_scalar)
	
	var ripple = Vector4.ZERO
	if !ripple_origins.is_empty():
		ripple = ripple_origins.pop_back()
		#ripple_origins.clear()
	
	RenderingServer.call_on_render_thread(_render_process.bind(next_texture, ripple, texture_resolution, texture_size, damp))
	

###############################################################################
# Everything after this point is designed to run on our rendering thread.

var rd : RenderingDevice

var shader : RID
var pipeline : RID

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
	tf.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT + RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT \
		+ RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT + RenderingDevice.TEXTURE_USAGE_STORAGE_BIT \
		+ RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT

	for i in range(3):
		# Create our texture.
		texture_rds[i] = rd.texture_create(tf, RDTextureView.new(), [])

		# Make sure our textures are cleared.
		rd.texture_clear(texture_rds[i], Color(0, 0, 0, 0), 0, 1, 0, 1)

		# Now create our uniform set so we can use these textures in our shader.
		texture_sets[i] = _create_uniform_set(texture_rds[i])


func _render_process(with_next_texture, wave_point, tex_resolution, tex_size, damp):
	var push_constant : PackedFloat32Array = PackedFloat32Array()
	push_constant.push_back(wave_point.x) # x position
	push_constant.push_back(wave_point.y) # z position
	push_constant.push_back(wave_point.z) # radius
	push_constant.push_back(wave_point.w) # strength

	push_constant.push_back(tex_resolution.x)
	push_constant.push_back(tex_resolution.y)
	
	# offsets
	var next_offset : Vector2 = ripple_texture_centers[with_next_texture]
	var current_offset : Vector2 = ripple_texture_centers[(with_next_texture - 1) % 3]
	var previous_offset : Vector2 = ripple_texture_centers[(with_next_texture - 2) % 3]
	
	push_constant.push_back(current_offset.x)
	push_constant.push_back(current_offset.y)
	push_constant.push_back(previous_offset.x)
	push_constant.push_back(previous_offset.y)
	push_constant.push_back(next_offset.x)
	push_constant.push_back(next_offset.y)
	
	push_constant.push_back(damp)
	push_constant.push_back(c2)
	push_constant.push_back(0.0)
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
	

	if use_cpu_readback:
		frame_number += 1
		if frame_number % cpu_readback_interval == 0:
			var lambda = func (array : PackedByteArray) -> void:
				water_image.set_data(texture_resolution.x, texture_resolution.y, false, Image.FORMAT_RF, array)
					
			rd.texture_get_data_async(texture_rds[with_next_texture], 0, lambda)

func _free_compute_resources():
	for i in range(3):
		if texture_rds[i]:
			rd.free_rid(texture_rds[i])

	if shader:
		rd.free_rid(shader)


func get_height(position: Vector3) -> float:
	var pos = Vector2(position.x, position.z) - Vector2(texture_offset.x, texture_offset.z)
	pos += 0.5 * texture_size
	if pos.x < 0.0 or pos.y < 0.0 or pos.x >= texture_size.x or pos.y >= texture_size.y:
		return 0.0

	var uv = pos / texture_size * Vector2(texture_resolution)
	var px = floor(uv)
	var frac = uv - px

	var x = int(px.x)
	var y = int(px.y)

	if x < 0 or y < 0 or x >= texture_resolution.x - 1 or y >= texture_resolution.y - 1:
		return 0.0

	var v00 = water_image.get_pixel(x,     y    ).r
	var v10 = water_image.get_pixel(x + 1, y    ).r
	var v01 = water_image.get_pixel(x,     y + 1).r
	var v11 = water_image.get_pixel(x + 1, y + 1).r

	# Bilinear interpolation
	var v0 = lerp(v00, v10, frac.x)
	var v1 = lerp(v01, v11, frac.x)
	return lerp(v0, v1, frac.y)

	
