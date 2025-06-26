class_name Player extends Node3D

@export var input_manager : PlayerInputManager
@export var kart : Kart
@export var camera : Node3D

var ocean_node : Node


func _ready() -> void:
	if !ocean_node:
		ocean_node = get_tree().get_first_node_in_group("ocean")

func _follow_camera(delta: float) -> void:
	camera.global_position = kart.global_position

func _process(delta: float) -> void:
	_follow_camera(delta)
	
	if ocean_node:
		ocean_node.set_player_position(kart.global_position)
		if kart.water_buoyancy.is_on_water():
			var v = kart.velocity;
			var strength = clamp(0.2 * Vector2(kart.velocity.x, kart.velocity.z).length(), 0, 1);
			strength += clamp(2 * abs(kart.velocity.y), 0, 1);
			ocean_node.add_ripple(kart.global_position, strength, 0);
