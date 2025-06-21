extends Node3D

@export var kart : RigidBody3D
@export var camera : Node3D
@export var look_sensitivity : float = 0.1
var input_active : bool = false
@export var camera_reset_delay : float = 2.5
var _camera_reset_cooldown : float = 0


func set_mouse(value: bool) -> void:
	input_active = value;
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if input_active else Input.MOUSE_MODE_VISIBLE;

func _ready() -> void:
	set_mouse(true);

#TODO: I if no inputs for a bit, align with kart velocity
func _input(event) -> void:
	if event is InputEventMouseMotion and input_active:
		rotation.y += -event.relative.x * 0.025 * look_sensitivity;
		rotation.x += -event.relative.y * 0.025 * look_sensitivity;
		rotation.x = clamp(rotation.x, -PI/2.2, PI/2.2)
		_camera_reset_cooldown = camera_reset_delay
		
		
func _process(delta: float) -> void:
	_camera_reset_cooldown -= delta
	if _camera_reset_cooldown < 0:
		var wish_basis := kart.global_basis
		var t = 1 -pow(0.2, 2 * delta)
		global_basis = global_basis.orthonormalized().slerp(wish_basis, t)
