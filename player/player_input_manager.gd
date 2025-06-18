class_name PlayerInputManager extends Node


var steering_factor : float
var acceleration_factor : float
	
func _process(delta: float) -> void:
	var move_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_backward");
	steering_factor = move_vector.x
	acceleration_factor = move_vector.y
