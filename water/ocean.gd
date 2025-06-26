extends Node3D

@export var player_position : Vector3

@onready var water_ripples : Node = $WaterRipples
@onready var water_waves : Node = $WaterWaves

func set_player_position(position : Vector3) -> void:
	player_position = position
	water_ripples.texture_offset = position
	
func add_ripple(position: Vector3, radius: float, strength: float) -> void:
	water_ripples.add_ripple(position, radius, strength);
