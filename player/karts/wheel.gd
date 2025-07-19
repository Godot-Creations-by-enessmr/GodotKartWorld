class_name Wheel extends Node3D

@export var steering_enabled : bool
@export var traction_enabled : bool
@export var left_side : bool

@export var max_force : float = 250.0
@export var stiffness : float = 1.0
@export var spring_rest_length : float = .3

@onready var raycast : RayCast3D = $RayCast3D
@onready var wheel_visual : Node3D = $WheelVisual
@onready var wheel_mesh : MeshInstance3D = $WheelVisual/WheelMesh
var compression : float
var speed : float = 0.0
@onready var radial_speed_factor : float = (2 * 0.21 * PI) / 2 * PI


func is_grounded() -> bool:
	return raycast.is_colliding()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	raycast.target_position = Vector3(0, -spring_rest_length, 0)

func get_wheel_position() -> Vector3:
	return wheel_visual.global_position


func _process(delta: float) -> void:
	var r = speed * delta * radial_speed_factor
	r = -r if left_side else r
	wheel_mesh.rotation.x += r

	var wheel_ground_point := raycast.get_collision_point()
	var raw_distance : float = clamp(wheel_ground_point.distance_to(global_position), 0, spring_rest_length)
	
	compression = lerp(compression, -raw_distance, 1.0 - pow(0.5, 60.0 * delta))
	wheel_visual.position = Vector3(0, compression, 0)


func set_steering(steering : float) -> void:
	if steering_enabled:
		wheel_visual.rotation.y = steering
