class_name WaterBuoyancy extends Node3D

@export var volume: float = 1.0
@export var max_depth: float = 1.0
@export var fluid_density: float = 1.0
@export var damping_coefficient: float = 2.0
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var align_to_normal: bool = false
@onready var parent : Node3D = $"../"

var ocean_node : Ocean

func _ready() -> void:
	if !ocean_node:
		ocean_node = get_tree().get_first_node_in_group("ocean")

var water_level: float = 0.0
var water_normal: Vector3 = Vector3.UP
var water_force: Vector3 = Vector3.ZERO

func is_on_water() -> bool:
	return water_level >= parent.global_position.y	

func get_water_height() -> float:
	return water_level

func get_surface_normal() -> Vector3:
	return water_normal

func _physics_process(delta: float) -> void:
	var pos : Vector3 = parent.global_position
	if ocean_node:
		water_level = ocean_node.get_wave_height(pos, 2, 2)
	
	var depth := water_level - pos.y
	if depth <= 0.0:
		water_force = Vector3.ZERO
		return

	var body := get_parent() as RigidBody3D
	if body == null:
		return

	# Get submersion ratio
	var submersion :float = clamp(depth / max_depth, 0.0, 1.0)

	# Base buoyant force: F = V * ρ * g * submersion
	var base_force : float = fluid_density * volume * gravity * submersion

	# Damping based on vertical velocity
	var vertical_velocity := -body.linear_velocity.dot(water_normal.normalized())
	var damping_force := damping_coefficient * vertical_velocity

	# Ensure damping doesn't cancel buoyancy entirely
	var total_force : float = clamp(base_force - damping_force, 0.0, base_force)
	water_force = water_normal.normalized() * total_force
