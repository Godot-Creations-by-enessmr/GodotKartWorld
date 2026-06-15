extends Node

@export var texture_resolution : Vector2i = Vector2i(512, 512)
@export var texture_size : Vector2 = Vector2(64, 64)
@export var texture_offset : Vector3 = Vector3.ZERO
@export var debug_log_compute := false
@export var target_materials : Array[ShaderMaterial]
@export var texture_target : String = "foam_texture"

var texture_centers : Array[Vector2i] = [Vector2i.ZERO, Vector2i.ZERO]
var texture_pixel_offset : Vector2i

#INTERNAL, THESE ARE UPDATED BY THE OCEAN
var ripples_size_ratio : Vector2
var ripples_resolution : Vector2
var ripples_texture_set : RID

var waves_size_ratio : Vector2
var waves_resolution : Vector2
var waves_texture_set : RID

const FFT_CASCADE_COUNT = 3
var fft_size_ratio : Vector2
var fft_resolution : Vector2
var fft_wind_uv_offset : Vector2
var fft_cascade_uv_scaled : Array[float] = [0.0, 0.0, 0.0]
var fft_uv_scale : float
var fft_waves_texture_set : RID
var fft_waves_texture_set_initialized = false
#END INTERNAL

var foam_texture : Texture2DRD
var next_texture : int = 0
var frame_number : int = 0

const PING_PONG_AMOUNT : int = 2


func set_player_position(pos : Vector3) -> void:
	texture_offset = pos

func _ready():
	RenderingServer.call_on_render_thread(_initialize_compute_code)

	for i in range(PING_PONG_AMOUNT):
		texture_centers[i] = Vector2i.ZERO

	foam_texture = Texture2DRD.new()
	$TextureRect.texture = foam_texture
	for material in target_materials:
		material.set_shader_parameter(texture_target, foam_texture)
		material.set_shader_parameter(texture_target + "_resolution", texture_resolution)
		material.set_shader_parameter(texture_target + "_size", texture_size)


func _exit_tree():
	if foam_texture:
		foam_texture.texture_rd_rid = RID()

	RenderingServer.call_on_render_thread(_free_compute_resources)

func _process(_delta):
	next_texture = (next_texture + 1) % PING_PONG_AMOUNT
	if foam_texture:
		foam_texture.texture_rd_rid = texture_rds[next_texture]
	var offset = Vector2(texture_offset.x, texture_offset.z);
	var offset_scalar = Vector2(texture_resolution) / texture_size
	texture_pixel_offset = offset_scalar * offset

	texture_centers[next_texture] = texture_pixel_offset;

	for material in target_materials:
		material.set_shader_parameter(texture_target + "_offset", Vector2(texture_pixel_offset) / offset_scalar)

	RenderingServer.call_on_render_thread(_render_process.bind(next_texture))


###############################################################################
# Everything after this point is designed to run on our rendering thread.

var rd : RenderingDevice
var _render_process_active := false

var shader : RID
var pipeline : RID
var _logged_missing_uniform_sets: Dictionary = {}

var texture_rds : Array = [ RID(), RID() ]
var texture_sets : Array = [ RID(), RID() ]

func create_fft_waves_cascades_set(textures : Array[Texture2DRD]) -> void:
	if fft_waves_texture_set_initialized:
		return
	if textures.size() != FFT_CASCADE_COUNT:
		printerr("Not the right amount of casccades supplied to the foam shader")

	var uniforms : Array[RDUniform] = []
	var sampler = RDSamplerState.new()
	sampler.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
	sampler.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
	sampler.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler.mip_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	var sampler_rid  : RID = rd.sampler_create(sampler)
	for i in range(textures.size()):
		var uniform := RDUniform.new()
		uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		uniform.binding = i
		uniform.add_id(sampler_rid)
		uniform.add_id(textures[i].texture_rd_rid)
		uniforms.append(uniform)

	fft_waves_texture_set = rd.uniform_set_create(uniforms, shader, 4)

	fft_waves_texture_set_initialized = true

func _create_uniform_set(texture_rd : RID, set_index : int) -> RID:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(texture_rd)
	return rd.uniform_set_create([uniform], shader, set_index)

func _initialize_compute_code():
	rd = RenderingServer.get_rendering_device()

	# Create our shader.
	var shader_file = load("res://water/waves/accumulate_foam.glsl")
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


func _log_missing_uniform_set_once(message: String) -> void:
	if _logged_missing_uniform_sets.has(message):
		return

	_logged_missing_uniform_sets[message] = true
	print(message)


func _render_process(with_next_texture):
	if _render_process_active:
		if debug_log_compute:
			print("COMPUTE DEBUG: skipped water_foam.gd because previous render process is still active")
		return

	_render_process_active = true

	var push_constant : PackedFloat32Array = PackedFloat32Array()
	var next_offset : Vector2 = texture_centers[with_next_texture]
	var current_offset : Vector2 = texture_centers[(with_next_texture - 1) % PING_PONG_AMOUNT]
	var texture_delta = (next_offset - current_offset).round()

	push_constant.push_back(texture_resolution.x)
	push_constant.push_back(texture_resolution.y)
	push_constant.push_back(texture_delta.x)
	push_constant.push_back(texture_delta.y)
	push_constant.push_back(texture_size.x)
	push_constant.push_back(texture_size.y)
	push_constant.push_back(texture_offset.x)
	push_constant.push_back(texture_offset.z)

	push_constant.push_back(ripples_size_ratio.x)
	push_constant.push_back(ripples_size_ratio.y)
	push_constant.push_back(ripples_resolution.x)
	push_constant.push_back(ripples_resolution.y)

	push_constant.push_back(waves_size_ratio.x)
	push_constant.push_back(waves_size_ratio.y)
	push_constant.push_back(waves_resolution.x)
	push_constant.push_back(waves_resolution.y)

	push_constant.push_back(fft_size_ratio.x)
	push_constant.push_back(fft_size_ratio.y)
	push_constant.push_back(fft_resolution.x)
	push_constant.push_back(fft_resolution.y)

	push_constant.push_back(fft_cascade_uv_scaled[0])
	push_constant.push_back(fft_cascade_uv_scaled[1])
	push_constant.push_back(fft_cascade_uv_scaled[2])
	push_constant.push_back(fft_uv_scale)

	var x_groups = (texture_resolution.x - 1) / 8 + 1
	var y_groups = (texture_resolution.y - 1) / 8 + 1

	var next_set = texture_sets[with_next_texture]["write_output"]
	var current_set = texture_sets[(with_next_texture + 1) % PING_PONG_AMOUNT]["read_current"]
	if not ripples_texture_set.is_valid():
		_log_missing_uniform_set_once("WaterFoam skipped: ripples_texture_set is empty")
		_render_process_active = false
		return
	if not waves_texture_set.is_valid():
		_log_missing_uniform_set_once("WaterFoam skipped: waves_texture_set is empty")
		_render_process_active = false
		return
	if not fft_waves_texture_set.is_valid():
		_log_missing_uniform_set_once("WaterFoam skipped: fft_waves_texture_set is empty")
		_render_process_active = false
		return
	if not current_set.is_valid():
		print("COMPUTE ERROR: empty uniform_set in WaterFoam current_set")
		_render_process_active = false
		return
	if not next_set.is_valid():
		print("COMPUTE ERROR: empty uniform_set in WaterFoam next_set")
		_render_process_active = false
		return

	var compute_list := rd.compute_list_begin()
	if compute_list <= 0:
		print("COMPUTE ERROR: compute_list_begin failed in water_foam.gd / WaterFoam")
		_render_process_active = false
		return
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, current_set, 0)
	rd.compute_list_bind_uniform_set(compute_list, next_set, 1)
	rd.compute_list_bind_uniform_set(compute_list, ripples_texture_set, 2)
	rd.compute_list_bind_uniform_set(compute_list, waves_texture_set, 3)
	rd.compute_list_bind_uniform_set(compute_list, fft_waves_texture_set, 4)
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
