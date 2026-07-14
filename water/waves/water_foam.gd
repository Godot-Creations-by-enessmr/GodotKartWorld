extends Node

@export var texture_resolution : Vector2i = Vector2i(512, 512)
@export var texture_size : Vector2 = Vector2(64, 64)
@export var texture_offset : Vector3 = Vector3.ZERO
@export var target_materials : Array[ShaderMaterial]
@export var texture_target : String = "foam_texture"

var texture_centers : Array[Vector2i] = [Vector2i.ZERO, Vector2i.ZERO]
var texture_pixel_offset : Vector2i

#INTERNAL, THESE ARE UPDATED BY THE OCEAN
var ripples_size_ratio : Vector2 = Vector2.ONE
var ripples_resolution : Vector2 = Vector2(256, 256)
var ripples_texture_set : RID = RID()

var waves_size_ratio : Vector2 = Vector2.ONE
var waves_resolution : Vector2 = Vector2(256, 256)
var waves_texture_set : RID = RID()

const FFT_CASCADE_COUNT = 3
var fft_size_ratio : Vector2 = Vector2.ONE
var fft_resolution : Vector2 = Vector2(256, 256)
var fft_wind_uv_offset : Vector2 = Vector2.ZERO
var fft_cascade_uv_scaled : Array[float] = [1.0, 2.0, 4.0]
var fft_uv_scale : float = 1.0
var fft_waves_texture_set : RID = RID()
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
	
	# Check if TextureRect exists before using it
	if has_node("TextureRect"):
		$TextureRect.texture = foam_texture
		
	for material in target_materials:
		if material:
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
		
	var offset = Vector2(texture_offset.x, texture_offset.z)
	var offset_scalar = Vector2(texture_resolution) / texture_size
	texture_pixel_offset = (offset_scalar * offset).round()
	
	texture_centers[next_texture] = texture_pixel_offset
		
	for material in target_materials:
		if material:
			material.set_shader_parameter(texture_target + "_offset", Vector2(texture_pixel_offset) / offset_scalar)
		
	RenderingServer.call_on_render_thread(_render_process.bind(next_texture))

###############################################################################
# Everything after this point is designed to run on our rendering thread.

var rd : RenderingDevice
var shader : RID
var pipeline : RID
var texture_rds : Array = [RID(), RID()]
var texture_sets : Array = [RID(), RID()]

func create_fft_waves_cascades_set(textures : Array[Texture2DRD]) -> void:
	if fft_waves_texture_set_initialized:
		return
	if textures.size() != FFT_CASCADE_COUNT:
		push_error("Not the right amount of cascades supplied to the foam shader. Expected ", FFT_CASCADE_COUNT, " got ", textures.size())
		return
	
	if rd == null:
		rd = RenderingServer.get_rendering_device()
	
	var uniforms : Array[RDUniform] = []
	var sampler = RDSamplerState.new()
	sampler.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
	sampler.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
	sampler.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler.mip_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	var sampler_rid : RID = rd.sampler_create(sampler)
	
	for i in range(textures.size()):
		var uniform := RDUniform.new()
		uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		uniform.binding = i
		uniform.add_id(sampler_rid)
		uniform.add_id(textures[i].texture_rd_rid)
		uniforms.append(uniform)
		
	if shader != RID():
		fft_waves_texture_set = rd.uniform_set_create(uniforms, shader, 4)
		fft_waves_texture_set_initialized = true

func _create_uniform_set(texture_rd : RID, binding : int) -> RID:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(texture_rd)
	return rd.uniform_set_create([uniform], shader, binding)

func _initialize_compute_code():
	rd = RenderingServer.get_rendering_device()
	if rd == null:
		push_error("RenderingDevice not available!")
		return

	# Create our shader.
	var shader_file = load("res://water/waves/accumulate_foam.glsl")
	if shader_file == null:
		push_error("Failed to load foam shader!")
		return
		
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	if shader == RID():
		push_error("Failed to create foam shader!")
		return
		
	pipeline = rd.compute_pipeline_create(shader)
	if pipeline == RID():
		push_error("Failed to create foam pipeline!")
		return

	# Create our textures
	var tf : RDTextureFormat = RDTextureFormat.new()
	tf.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	tf.width = texture_resolution.x
	tf.height = texture_resolution.y
	tf.depth = 1
	tf.array_layers = 1
	tf.mipmaps = 1
	tf.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT + 
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT +
		RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT + 
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT +
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + 
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	)

	for i in range(PING_PONG_AMOUNT):
		texture_rds[i] = rd.texture_create(tf, RDTextureView.new(), [])
		if texture_rds[i] == RID():
			push_error("Failed to create foam texture ", i)
			continue
		rd.texture_clear(texture_rds[i], Color(0, 0, 0, 0), 0, 1, 0, 1)
		# Create uniform set with correct binding
		texture_sets[i] = _create_uniform_set(texture_rds[i], i)

func _render_process(with_next_texture):
	if rd == null or shader == RID() or pipeline == RID():
		return
		
	var push_constant : PackedFloat32Array = PackedFloat32Array()
	var next_offset : Vector2 = texture_centers[with_next_texture]
	var current_offset : Vector2 = texture_centers[(with_next_texture - 1) % PING_PONG_AMOUNT]
	var texture_delta = (Vector2(next_offset) - Vector2(current_offset)).round()
	
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
	
	push_constant.push_back(fft_cascade_uv_scaled[0] if fft_cascade_uv_scaled.size() > 0 else 1.0)
	push_constant.push_back(fft_cascade_uv_scaled[1] if fft_cascade_uv_scaled.size() > 1 else 2.0)
	push_constant.push_back(fft_cascade_uv_scaled[2] if fft_cascade_uv_scaled.size() > 2 else 4.0)
	push_constant.push_back(fft_uv_scale)
	
	var x_groups = (texture_resolution.x - 1) / 8 + 1
	var y_groups = (texture_resolution.y - 1) / 8 + 1

	var next_set = texture_sets[with_next_texture]
	var current_set = texture_sets[(with_next_texture + 1) % PING_PONG_AMOUNT]
	
	if next_set == RID() or current_set == RID():
		return

	# Run our compute shader.
	var compute_list := rd.compute_list_begin()
	if compute_list == null:
		return
		
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, current_set, 0)  # Set 0: current texture
	rd.compute_list_bind_uniform_set(compute_list, next_set, 1)     # Set 1: next texture
	if ripples_texture_set != RID():
		rd.compute_list_bind_uniform_set(compute_list, ripples_texture_set, 2)
	if waves_texture_set != RID():
		rd.compute_list_bind_uniform_set(compute_list, waves_texture_set, 3)
	if fft_waves_texture_set != RID():
		rd.compute_list_bind_uniform_set(compute_list, fft_waves_texture_set, 4)
	rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
	rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
	rd.compute_list_end()

func _free_compute_resources():
	if rd == null:
		return
		
	for i in range(PING_PONG_AMOUNT):
		if i < texture_rds.size() and texture_rds[i] != RID():
			rd.free_rid(texture_rds[i])
		if i < texture_sets.size() and texture_sets[i] != RID():
			rd.free_rid(texture_sets[i])

	if shader != RID():
		rd.free_rid(shader)
	if pipeline != RID():
		rd.free_rid(pipeline)
