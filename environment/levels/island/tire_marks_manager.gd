extends Node

@export var texture_resolution : Vector2i = Vector2i(512, 512)
@export var texture_size : Vector2 = Vector2(64, 64)
@export var texture_offset : Vector3 = Vector3.ZERO
@export var island_material : Array[ShaderMaterial]

@export var texture_target : String = "tire_marks_texture"

var texture_centers : Array[Vector2i] = [Vector2i.ZERO, Vector2i.ZERO]
var texture_pixel_offset : Vector2i
var tire_origins : Array[Vector4] = []

var tire_marks_texture : Texture2DRD
var next_texture : int = 0
var frame_number : int = 0

const PING_PONG_AMOUNT : int = 2

# Max tire marks to process per frame (prevents lag)
const MAX_TIRE_MARKS_PER_FRAME := 4

func add_tire(position: Vector3, radius: float, strength: float) -> void:
	var pixel_position : Vector2i = Vector2(texture_resolution) / texture_size * Vector2(position.x, position.z)
	pixel_position -= texture_pixel_offset - Vector2i(texture_resolution * 0.5)
	tire_origins.append(Vector4(pixel_position.x, pixel_position.y, radius, strength))
	
	# Limit the queue size to prevent memory issues
	if tire_origins.size() > 100:
		tire_origins.remove_at(0)

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
	# Only process if we have tire marks to render
	if tire_origins.is_empty():
		return
		
	next_texture = (next_texture + 1) % PING_PONG_AMOUNT
	if tire_marks_texture:
		tire_marks_texture.texture_rd_rid = texture_rds[next_texture]
		
	var offset = Vector2(texture_offset.x, texture_offset.z)
	var offset_scalar = Vector2(texture_resolution) / texture_size
	texture_pixel_offset = (offset_scalar * offset).round()
	
	texture_centers[next_texture] = texture_pixel_offset
		
	for material in island_material:
		material.set_shader_parameter(texture_target + "_offset", Vector2(texture_pixel_offset) / offset_scalar)
	
	# Only take up to MAX_TIRE_MARKS_PER_FRAME marks to process
	var marks_to_process := []
	var marks_count := mini(tire_origins.size(), MAX_TIRE_MARKS_PER_FRAME)
	for i in range(marks_count):
		marks_to_process.append(tire_origins[i])
	
	# Remove processed marks
	if marks_count > 0:
		tire_origins.remove_at(0)
		# Remove subsequent marks (we removed the first one, so we need to remove marks_count-1 more)
		for i in range(marks_count - 1):
			if tire_origins.size() > 0:
				tire_origins.remove_at(0)
	
	if not marks_to_process.is_empty():
		RenderingServer.call_on_render_thread(_render_process.bind(next_texture, marks_to_process))

###############################################################################
# Everything after this point is designed to run on our rendering thread.

var rd : RenderingDevice
var shader : RID
var pipeline : RID
var texture_rds : Array = [RID(), RID()]
var texture_sets : Array = [RID(), RID()]

func _create_uniform_set(texture_rd : RID, binding : int = 0) -> RID:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = binding
	uniform.add_id(texture_rd)
	return rd.uniform_set_create([uniform], shader, binding)

func _initialize_compute_code():
	rd = RenderingServer.get_rendering_device()
	if rd == null:
		push_error("RenderingDevice not available!")
		return

	# Create our shader.
	var shader_file = load("res://environment/levels/island/tire_marks_shader.glsl")
	if shader_file == null:
		push_error("Failed to load tire marks shader!")
		return
		
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	if shader == RID():
		push_error("Failed to create tire marks shader!")
		return
		
	pipeline = rd.compute_pipeline_create(shader)
	if pipeline == RID():
		push_error("Failed to create tire marks pipeline!")
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
			push_error("Failed to create tire marks texture ", i)
			continue
		rd.texture_clear(texture_rds[i], Color(0, 0, 0, 0), 0, 1, 0, 1)
		
		# Create separate uniform sets for read and write
		texture_sets[i] = _create_uniform_set(texture_rds[i], 0)

func _render_process(with_next_texture, tire_origins_list : Array[Vector4]):
	if rd == null or shader == RID() or pipeline == RID():
		return
	
	if tire_origins_list.is_empty():
		return
	
	var push_constant := PackedFloat32Array()
	
	# Add tire marks data (max 4 per frame)
	var marks_to_send := tire_origins_list.slice(0, mini(tire_origins_list.size(), 4))
	for i in range(4):
		var tire_origin : Vector4
		if marks_to_send.size() <= i:
			tire_origin = Vector4.ZERO
		else:
			tire_origin = marks_to_send[i]
		push_constant.push_back(tire_origin.x)
		push_constant.push_back(tire_origin.y)
		push_constant.push_back(tire_origin.z)
		push_constant.push_back(tire_origin.w)

	push_constant.push_back(texture_resolution.x)
	push_constant.push_back(texture_resolution.y)
	
	var next_offset : Vector2 = texture_centers[with_next_texture]
	var current_offset : Vector2 = texture_centers[(with_next_texture - 1) % PING_PONG_AMOUNT]
	
	push_constant.push_back(current_offset.x)
	push_constant.push_back(current_offset.y)
	push_constant.push_back(next_offset.x)
	push_constant.push_back(next_offset.y)
	
	push_constant.push_back(0.0)
	push_constant.push_back(0.0)

	var x_groups = (texture_resolution.x - 1) / 8 + 1
	var y_groups = (texture_resolution.y - 1) / 8 + 1

	# ===== FIX: Create BOTH uniform sets =====
	# Set 0: Current texture (READ)
	var read_uniform := RDUniform.new()
	read_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	read_uniform.binding = 0
	read_uniform.add_id(texture_rds[(with_next_texture + 1) % PING_PONG_AMOUNT])
	var read_set := rd.uniform_set_create([read_uniform], shader, 0)
	
	# Set 1: Next texture (WRITE)
	var write_uniform := RDUniform.new()
	write_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	write_uniform.binding = 0
	write_uniform.add_id(texture_rds[with_next_texture])
	var write_set := rd.uniform_set_create([write_uniform], shader, 1)
	
	if read_set == RID() or write_set == RID():
		if read_set != RID(): rd.free_rid(read_set)
		if write_set != RID(): rd.free_rid(write_set)
		return

	var compute_list := rd.compute_list_begin()
	if compute_list == null:
		rd.free_rid(read_set)
		rd.free_rid(write_set)
		return
		
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, read_set, 0)   # Set 0
	rd.compute_list_bind_uniform_set(compute_list, write_set, 1)  # Set 1
	rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
	rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
	rd.compute_list_end()
	
	# Clean up
	rd.free_rid(read_set)
	rd.free_rid(write_set)

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
