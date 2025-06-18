class_name Player extends Node

@export var input_manager : PlayerInputManager
@export var kart : Kart
@export var camera : Node3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func _follow_camera(delta: float) -> void:
	camera.global_position = kart.global_position

func _process(delta: float) -> void:
	_follow_camera(delta)
