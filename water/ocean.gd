class_name Ocean extends Node3D


@onready var water_ripples : Node = $WaterRipples
@onready var water_waves : Node = $WaterWaves
@onready var water_foam : Node = $WaterFoam

@export var island_mask : Texture2D
var island_mask_image : Image
@export var island_mask_size := Vector2(960, 960)
@export var ocean:OceanFFTWaves


var player_position : Vector3

func _ready() -> void:
	#var camera := get_viewport().get_camera_3d()	
	if ocean and not ocean.initialized:
		ocean.initialize_simulation()
		
	island_mask_image = island_mask.get_image()
	if island_mask_image.is_compressed():
		island_mask_image.decompress()
		
	island_mask_image.convert(Image.FORMAT_RGBA8)

func _process(delta:float) -> void:	
	if not ocean.initialized:
		ocean.initialize_simulation()
	ocean.simulate(delta)
	
	
	##set textures used for foam computation
	if water_foam:
		water_foam.ripples_size_ratio = water_foam.texture_size / water_ripples.texture_size \
			* Vector2(water_foam.texture_resolution) / Vector2(water_ripples.texture_resolution)
		water_foam.ripples_resolution = water_ripples.texture_resolution
		water_foam.ripples_texture_set = water_ripples.get_current_image_set()
		
		water_foam.waves_size_ratio = water_foam.texture_size / water_waves.texture_size \
			* Vector2(water_foam.texture_resolution) / Vector2(water_waves.texture_resolution)
		water_foam.waves_resolution = water_waves.texture_resolution
		water_foam.waves_texture_set = water_waves.get_current_image_set()
		
		water_foam.fft_resolution = Vector2(ocean.fft_resolution, ocean.fft_resolution)
		water_foam.fft_size_ratio = water_foam.texture_size / ocean.horizontal_dimension \
			* Vector2(water_foam.texture_resolution) / Vector2(water_foam.fft_resolution)
		
		water_foam.fft_wind_uv_offset = ocean.wind_uv_offset
		water_foam.fft_cascade_uv_scaled = ocean.cascade_scales
		water_foam.fft_uv_scale = ocean._uv_scale
		
		water_foam.create_fft_waves_cascades_set(ocean.get_all_waves_textures())
	
	
func get_island_mask(pos : Vector3) -> float:
	return sample_image_bilinear(island_mask_image, Vector2(pos.x, pos.z) / island_mask_size + Vector2(0.5, 0.5)).r

func get_wave_height(global_pos:Vector3, max_cascade:int = 3, steps:int = 4) -> float:	
	var height : float = ocean.get_wave_height(get_viewport().get_camera_3d(), global_pos, max_cascade, steps) + water_waves.get_height(global_pos)
	return get_island_mask(global_pos) * height

func set_player_position(pos : Vector3) -> void:
	player_position = pos
	water_ripples.texture_offset = pos
	water_waves.texture_offset = pos
	water_foam.texture_offset = pos
	
	
func add_ripple(pos: Vector3, radius: float, strength: float) -> void:
	water_ripples.add_ripple(pos, radius, strength);
	
func add_wave(pos: Vector3, radius: float, strength: float) -> void:
	water_waves.add_ripple(pos, radius, strength);

func sample_image_bilinear(image: Image, uv: Vector2) -> Color:
	if image == null or image.is_empty():
		return Color.BLACK

	if uv.x < 0.0 or uv.y < 0.0 or uv.x >= 1.0 or uv.y >= 1.0:
		return Color.BLACK

	var size: Vector2i = image.get_size()

	# Convert UV to pixel space.
	# Use size - 1 so the maximum sample lands on the last valid pixel,
	# not one past the image edge.
	var pixel_uv: Vector2 = uv * Vector2(size.x - 1, size.y - 1)

	var px: Vector2 = floor(pixel_uv)
	var frac: Vector2 = pixel_uv - px

	var x0: int = clampi(int(px.x), 0, size.x - 1)
	var y0: int = clampi(int(px.y), 0, size.y - 1)

	var x1: int = clampi(x0 + 1, 0, size.x - 1)
	var y1: int = clampi(y0 + 1, 0, size.y - 1)

	var v00: Color = image.get_pixel(x0, y0)
	var v10: Color = image.get_pixel(x1, y0)
	var v01: Color = image.get_pixel(x0, y1)
	var v11: Color = image.get_pixel(x1, y1)

	var v0: Color = v00.lerp(v10, frac.x)
	var v1: Color = v01.lerp(v11, frac.x)

	return v0.lerp(v1, frac.y)
