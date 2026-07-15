extends Node

@export var texture_resolution : Vector2i = Vector2i(512, 512)
@export var texture_size : Vector2 = Vector2(64, 64)
@export var texture_offset : Vector3 = Vector3.ZERO
@export var debug_log_compute := false
@export var island_material : Array[ShaderMaterial]

@export var texture_target : String = "tire_marks_texture"

var texture_centers : Array[Vector2i] = [Vector2i.ZERO, Vector2i.ZERO]
var texture_pixel_offset : Vector2i
var tire_origins : Array[Vector4] = [];

var tire_marks_texture : Texture2DRD
var next_texture : int = 0
var frame_number : int = 0

const PING_PONG_AMOUNT : int = 2

func add_tire(position: Vector3, radius: float, strength: float) -> void:
	var pixel_position : Vector2i = Vector2(texture_resolution) / texture_size * Vector2(position.x, position.z)
	pixel_position -= texture_pixel_offset - Vector2i(texture_resolution * 0.5)
	tire_origins.append(Vector4(pixel_position.x, pixel_position.y, radius, strength))

func set_player_position(pos : Vector3) -> void:
	texture_offset = pos

func _ready():
	RenderingServer.call_on_render_thread(_initialize_compute_code)

	for i in range(PING_PONG_AMOUNT):
		texture_centers[i] = Vector2i.ZERO

	tire_marks_texture = Texture2DRD.new()

	for material in island_material:
		material.set_shader_parameter(texture_target, tire_marks_texture)
		material.set_shader_parameter(texture_target + "_resolution", texture_resolution)
		material.set_shader_parameter(texture_target + "_size", texture_size)


func _exit_tree():
	if tire_marks_texture:
		tire_marks_texture.texture_rd_rid = RID()

	RenderingServer.call_on_render_thread(_free_compute_resources)

func _process(_delta):
	next_texture = (next_texture + 1) % PING_PONG_AMOUNT
	if tire_marks_texture:
		tire_marks_texture.texture_rd_rid = texture_rds[next_texture]
	var offset = Vector2(texture_offset.x, texture_offset.z);
	var offset_scalar = Vector2(texture_resolution) / texture_size
	texture_pixel_offset = offset_scalar * offset

	texture_centers[next_texture] = texture_pixel_offset;

	for material in island_material:
		material.set_shader_parameter(texture_target + "_offset", Vector2(texture_pixel_offset) / offset_scalar)

	RenderingServer.call_on_render_thread(_render_process.bind(next_texture, tire_origins))


###############################################################################
# Everything after this point is designed to run on our rendering thread.

var rd : RenderingDevice
var _render_process_active := false

var shader : RID
var pipeline : RID

var texture_rds : Array = [ RID(), RID() ]
var texture_sets : Array = [ RID(), RID() ]

func _create_uniform_set(texture_rd : RID, set_index : int) -> RID:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(texture_rd)
	return rd.uniform_set_create([uniform], shader, set_index)

func _initialize_compute_code():
	rd = RenderingServer.get_rendering_device()

	# Create our shader.
	var shader_file = load("res://environment/levels/island/tire_marks_shader.glsl")
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

	for i in range(PING_PONG_AMOUNT):
		texture_rds[i] = rd.texture_create(tf, RDTextureView.new(), [])
		rd.texture_clear(texture_rds[i], Color(0, 0, 0, 0), 0, 1, 0, 1)
		texture_sets[i] = {
			"read_current": _create_uniform_set(texture_rds[i], 0),
			"write_output": _create_uniform_set(texture_rds[i], 1),
		}


func _render_process(with_next_texture, tire_origins_list : Array[Vector4]):
	if _render_process_active:
		if debug_log_compute:
			print("COMPUTE DEBUG: skipped tire_marks_manager.gd because previous render process is still active")
		return

	_render_process_active = true

	var push_constant : PackedFloat32Array = PackedFloat32Array()
	for i in range(4):
		var tire_origin = Vector4() if tire_origins_list.size() <= i else tire_origins_list[i]
		push_constant.push_back(tire_origin.x) # x position
		push_constant.push_back(tire_origin.y) # z position
		push_constant.push_back(tire_origin.z) # radius
		push_constant.push_back(tire_origin.w) # strength
	tire_origins_list.clear()

	push_constant.push_back(texture_resolution.x)
	push_constant.push_back(texture_resolution.y)

	# offsets
	var next_offset : Vector2 = texture_centers[with_next_texture]
	var current_offset : Vector2 = texture_centers[(with_next_texture - 1) % PING_PONG_AMOUNT]

	push_constant.push_back(current_offset.x)
	push_constant.push_back(current_offset.y)
	push_constant.push_back(next_offset.x)
	push_constant.push_back(next_offset.y)

	push_constant.push_back(0.0)
	push_constant.push_back(0.0)
	@warning_ignore("integer_division")
	var x_groups = (texture_resolution.x - 1) / 8 + 1
	@warning_ignore("integer_division")
	var y_groups = (texture_resolution.y - 1) / 8 + 1

	var next_set = texture_sets[with_next_texture]["write_output"]
	var current_set = texture_sets[(with_next_texture + 1) % PING_PONG_AMOUNT]["read_current"]
	if not current_set.is_valid():
		print("COMPUTE ERROR: empty uniform_set in TireMarks current_set")
		_render_process_active = false
		return
	if not next_set.is_valid():
		print("COMPUTE ERROR: empty uniform_set in TireMarks next_set")
		_render_process_active = false
		return

	var compute_list := rd.compute_list_begin()
	if compute_list <= 0:
		print("COMPUTE ERROR: compute_list_begin failed in tire_marks_manager.gd / TireMarks")
		_render_process_active = false
		return
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, current_set, 0)
	rd.compute_list_bind_uniform_set(compute_list, next_set, 1)
	rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
	rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
	rd.compute_list_end()
	_render_process_active = false


func _free_compute_resources():
	for i in range(PING_PONG_AMOUNT):
		if texture_rds[i]:
			rd.free_rid(texture_rds[i])

	if shader:
		rd.free_rid(shader)
