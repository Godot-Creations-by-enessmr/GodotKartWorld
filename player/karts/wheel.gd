class_name Wheel extends Node3D

@export var steering_enabled : bool
@export var traction_enabled : bool

@export var max_force : float = 250.0
@export var stiffness : float = 1.0
@export var spring_rest_length : float = .3

@onready var raycast : RayCast3D = $RayCast3D
@onready var wheel_visual : Node3D = $WheelVisual
var compression : float
var previous_compression: float = 0.0
var compression_velocity: float = 0.0


func is_grounded() -> bool:
	return raycast.is_colliding()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	raycast.target_position = Vector3(0, -spring_rest_length, 0)
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	var wheel_ground_point := raycast.get_collision_point()
	var raw_distance : float = clamp(wheel_ground_point.distance_to(global_position), 0, spring_rest_length)
	wheel_visual.position = Vector3(0, -raw_distance, 0)
	
	previous_compression = compression
	compression = spring_rest_length - raw_distance
	compression_velocity = (compression - previous_compression) / delta
	

func get_local_spring_force() -> Vector3:
	var spring_force = stiffness * compression
	var damping := 1000  # Adjust as needed
	var damping_force = damping * compression_velocity
	print("damping: %s" % [damping_force])
	print("spring: %s" % [spring_force])
	return Vector3.UP * clamp(spring_force - damping_force, -max_force, max_force)
