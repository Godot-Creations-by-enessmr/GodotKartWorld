class_name Ocean extends Node3D


@onready var water_ripples : Node = $WaterRipples
@onready var water_waves : Node = $WaterWaves

@export var ocean:Ocean3D


var player_position : Vector3

func _ready() -> void:
	var camera := get_viewport().get_camera_3d()
	
	if ocean and not ocean.initialized:
		ocean.initialize_simulation()

func _process(delta:float) -> void:
	var camera := get_viewport().get_camera_3d()
	
	if not ocean.initialized:
		ocean.initialize_simulation()
	ocean.simulate(delta)

func get_wave_height(global_pos:Vector3, max_cascade:int = 1, steps:int = 2) -> float:
	print(water_waves.get_height(global_pos))
	return ocean.get_wave_height(get_viewport().get_camera_3d(), global_pos, max_cascade, steps) + water_waves.get_height(global_pos)

func set_player_position(position : Vector3) -> void:
	player_position = position
	water_ripples.texture_offset = position
	water_waves.texture_offset = position
	
func add_ripple(position: Vector3, radius: float, strength: float) -> void:
	water_ripples.add_ripple(position, radius, strength);
	
func add_wave(position: Vector3, radius: float, strength: float) -> void:
	water_waves.add_ripple(position, radius, strength);
