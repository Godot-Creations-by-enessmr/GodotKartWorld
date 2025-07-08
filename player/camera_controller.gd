extends Node3D

@export var kart : Node3D
@export var camera : Camera3D
@export var look_sensitivity : float = 0.1
@export var under_water_environment : Environment
var input_active : bool = false
@export var camera_reset_delay : float = 2.5
var _camera_reset_cooldown : float = 0
var ocean_node : Ocean
var is_under_water : bool = false

func set_mouse(value: bool) -> void:
	input_active = value;
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if input_active else Input.MOUSE_MODE_VISIBLE

func _ready() -> void:
	if !ocean_node:
		ocean_node = get_tree().get_first_node_in_group("ocean")

	set_mouse(true);
	#set_mouse(false);
			#get_viewport().debug_draw = Viewport.DEBUG_DRAW_WIREFRAME

func _input(event) -> void:
	if event is InputEventMouseMotion and input_active:
		rotation.y += -event.relative.x * 0.025 * look_sensitivity;
		rotation.x += -event.relative.y * 0.025 * look_sensitivity;
		rotation.x = clamp(rotation.x, -0.4 * PI, 0.4 * PI)
		_camera_reset_cooldown = camera_reset_delay
		
		
func _process(delta: float) -> void:	
	if ocean_node:
		var pos = camera.global_position;
		var water_level = ocean_node.get_wave_height(pos, 2, 2)
		var under_water : bool = pos.y < water_level
		if is_under_water != under_water:
			if under_water:
				camera.environment = under_water_environment
			else:
				camera.environment = null
			
		is_under_water = under_water
	
	return
	_camera_reset_cooldown -= delta
	if _camera_reset_cooldown < 0:
		var wish_basis := kart.global_basis
		var t = 1 -pow(0.2, 2 * delta)
		global_basis = global_basis.orthonormalized().slerp(wish_basis.orthonormalized(), t)
