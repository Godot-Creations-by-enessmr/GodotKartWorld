class_name Kart extends VehicleBody3D

var wish_acceleration : float
var wish_steering : float
var wish_jump : bool

@export var top_speed = 25
@export var water_buoyancy : WaterBuoyancy
var wheels : Array[Wheel]

func reset_buffer() -> void:
	wish_jump = false
	wish_steering = 0
	wish_acceleration = 0 

func _ready() -> void:
	for child in get_children():
		if child is Wheel:
			wheels.append(child)

func get_relative_speed() -> float:
	return linear_velocity.length() / top_speed

func is_grounded() -> bool:
	for wheel in wheels:
		if wheel.is_in_contact():
			return true
	return false
	

func update_wheel_rotation() -> void:
	for wheel in wheels:
		if wheel.steering_enabled:
			wheel.rotation.y = steering
	
func _physics_process(delta: float) -> void:
	#apply_wheel_forces()
	#update_wheel_rotation()
	
	# Upright stabilization
	var current_up = global_transform.basis.y
	var upright_force = current_up.cross(Vector3.UP) * 5.0  # adjust multiplier
	apply_torque_impulse(upright_force)

	
	apply_central_force(water_buoyancy.water_force * 1)
	
	var forward = global_transform.basis.z;
	var relative_speed := get_relative_speed()
	var steer_target = wish_steering * -deg_to_rad(15);
	steering = move_toward(steering, steer_target, 10 * delta)
	if relative_speed < 1.0 && is_grounded():
		#linear_velocity = forward * linear_velocity.dot(forward) + forward * wish_acceleration * 0.1;
		apply_central_force(Vector3(-0,linear_velocity.length(),0))
		if wish_acceleration > 0:
			engine_force = -100
		if wish_acceleration < 0:
			engine_force = 1000
		else:
			engine_force = 0
	
	if wish_jump && is_grounded():
		linear_velocity += Vector3.UP * 2
		
	reset_buffer()
	
	
	
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("move_jump"):
		wish_jump = true;
	
func _process(delta: float) -> void:
	var move_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_backward");
	wish_steering = move_vector.x
	wish_acceleration = move_vector.y
	
