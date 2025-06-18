class_name Kart extends RigidBody3D

var wish_acceleration : float
var wish_steering : float
var wish_jump : bool

@export var top_speed = 25
@export var ground_raycast : RayCast3D

func reset_buffer() -> void:
	wish_jump = false
	wish_steering = 0
	wish_acceleration = 0 

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func get_relative_speed() -> float:
	return linear_velocity.length() / top_speed

func is_grounded() -> bool:
	return ground_raycast.is_colliding()
	
func _physics_process(delta: float) -> void:
	var forward = global_transform.basis.z;
	var relative_speed := get_relative_speed()
	rotate_y(delta * wish_steering * -2 * relative_speed)
	
	if relative_speed < 1.0 && is_grounded():
		linear_velocity = forward * linear_velocity.dot(forward) + forward * wish_acceleration;
	
	if wish_jump && is_grounded():
		linear_velocity += Vector3.UP * 10
		
	reset_buffer()
	
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("move_jump"):
		wish_jump = true;
	
func _process(delta: float) -> void:
	var move_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_backward");
	wish_steering = move_vector.x
	wish_acceleration = move_vector.y
	
