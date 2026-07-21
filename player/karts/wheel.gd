class_name Wheel extends Node3D

@export var steering_enabled : bool
@export var traction_enabled : bool
@export var left_side : bool
@export var is_front := true          # true = front wheel, false = rear

@export var max_force : float = 250.0
@export var stiffness : float = 1.0
@export var spring_rest_length : float = .3

@export var grind_sparks: GPUParticles3D = null

@onready var raycast : RayCast3D = $RayCast3D
@onready var wheel_visual : Node3D = $WheelVisual
@onready var wheel_mesh : MeshInstance3D = $WheelVisual/WheelMesh
var compression : float
var speed : float = 0.0
@onready var radial_speed_factor : float = (2 * 0.21 * PI) / 2 * PI

var grinding_active := false
var grind_side := 0   # 1 = right, -1 = left
var steering_angle: float = 0.0


func is_grounded() -> bool:
	return raycast.is_colliding()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	raycast.target_position = Vector3(0, -spring_rest_length, 0)

func get_wheel_position() -> Vector3:
	return wheel_visual.global_position


func _process(delta: float) -> void:
	# Rolling rotation
	var r = speed * delta * radial_speed_factor
	r = -r if left_side else r
	wheel_mesh.rotation.x += r

	# Suspension compression
	var wheel_ground_point := raycast.get_collision_point()
	var raw_distance : float = clamp(wheel_ground_point.distance_to(global_position), 0, spring_rest_length)
	
	compression = lerp(compression, -raw_distance, 1.0 - pow(0.5, 60.0 * delta))
	wheel_visual.position = Vector3(0, compression, 0)

	# Apply steering or grinding rotation
	if grinding_active:
		# Grind pose: tilt outward based on side and front/rear
		var tilt = grind_side * deg_to_rad(40.0)
		if is_front:
			wheel_mesh.rotation.z = tilt * 1.2   # front wheels tilt out more
			wheel_mesh.rotation.x = r   # keep rolling
		else:
			wheel_mesh.rotation.z = tilt * 0.8   # rear wheels tilt slightly less
			wheel_mesh.rotation.x = r + deg_to_rad(15.0) * grind_side   # add upward tilt
	else:
		# Normal steering or straight
		if steering_enabled:
			wheel_visual.rotation.y = steering_angle
		wheel_mesh.rotation.z = 0.0   # reset grind tilt

	# Spark particles
	if grind_sparks:
		grind_sparks.emitting = grinding_active


func set_steering(steering : float) -> void:
	steering_angle = steering


func set_grinding(active: bool, side: int) -> void:
	grinding_active = active
	grind_side = side
