class_name Kart extends CharacterBody3D

var wish_acceleration : float
var wish_steering : float
var wish_jump : bool
var wish_break : bool
var wish_drift : bool
var wish_drift_direction : float

@export_custom(PROPERTY_HINT_NONE, "suffix:m/s") var top_speed := 15
@export_custom(PROPERTY_HINT_NONE, "suffix:m/s") var top_reverse_speed := 5
@export_custom(PROPERTY_HINT_NONE, "suffix:m/s/s") var acceleration := 10
@export var roll_resistance := 0.4
@export var break_resistance := 0.1

@export_group("Steering")
@export_custom(PROPERTY_HINT_NONE, "suffix:degrees") var max_steering_angle := 10
@export_custom(PROPERTY_HINT_NONE, "suffix:degrees/s") var handbrake_steering_velocity := 45
@export_custom(PROPERTY_HINT_NONE, "suffix:degrees/s") var air_steering_velocity := 50
@export_custom(PROPERTY_HINT_NONE, "suffix:m") var wheel_base := 1.5
@export var drift_steering_multiplier := 1.5


var wheels : Array[Wheel]
var steering : float = 0

var gravity_acceleration : Vector3 = Vector3(0, -9.81, 0)
var current_model_up : Vector3 = Vector3.UP
#var velocity : Vector3

@onready var water_buoyancy : WaterBuoyancy = $WaterBuoyancy
@onready var visual_parent : Node3D = $Visual
@onready var debug_label : Label = $DebugLabel

func is_on_ground() -> bool:
	return is_on_floor() or water_buoyancy.is_on_water()

func get_horizontal_velocity() -> Vector3:
	return Vector3(velocity.x, 0, velocity.z)

func reset_buffer() -> void:
	wish_jump = false
	wish_steering = 0
	wish_acceleration = 0 

func _ready() -> void:
	for child in visual_parent.get_children():
		if child is Wheel:
			wheels.append(child)
	

func _apply_steering(delta : float) -> void:
	var v := get_horizontal_velocity()
	var horizonal_speed : float = v.length() * sign(v.dot(-global_transform.basis.z))
	var angular_velocity : float = deg_to_rad(air_steering_velocity * wish_steering)

	if is_on_ground():
		if wish_break && abs(horizonal_speed) < 1:
			angular_velocity = deg_to_rad(handbrake_steering_velocity * wish_steering)
		else:
			var steering_angle : float
			if wish_drift:
				steering_angle = drift_steering_multiplier * max_steering_angle * (wish_drift_direction * 0.25 + 0.75 * wish_steering)
			elif abs(horizonal_speed) > 1e-2:
				steering_angle = max_steering_angle * wish_steering
			angular_velocity = (horizonal_speed * tan(deg_to_rad(steering_angle))) / wheel_base
	
	steering = lerp(steering, deg_to_rad(max_steering_angle * wish_steering), pow(0.2, 5 * delta))
	rotate_y(-delta * angular_velocity)
	for wheel in wheels:
		if wheel.steering_enabled:
			wheel.rotation.y = steering
			

func _align_mesh_with_normal(delta : float, normal: Vector3) -> void:
	var up := normal.normalized()
	var forward := -global_transform.basis.z
	forward = (forward - up * forward.dot(up)).normalized()

	var right := up.cross(forward).normalized()

	var new_basis := Basis()
	new_basis.x = right
	new_basis.y = up
	new_basis.z = -forward
	
	visual_parent.global_basis = new_basis


func _process(delta: float) -> void:
	var new_up := Vector3.UP
	var t := 0.5
	if water_buoyancy.is_on_water():
		t = 0.25
		new_up = water_buoyancy.get_surface_normal()
	elif is_on_ground():
		t = 0.025
		new_up = get_floor_normal()
	else:
		var lean_strength := -0.2
		var up := Vector3.UP
		var forward : Vector3 = global_transform.basis.z;
		var side := forward.cross(up);		
		var vertical_velocity := velocity.dot(up)
		var lean_angle : float = clamp(vertical_velocity * lean_strength, -0.2, 0.2)  # In radians		
		new_up = up.rotated(side, lean_angle)
		
	current_model_up = current_model_up.lerp(new_up, 1 - pow(t, 2 * delta))
	_align_mesh_with_normal(delta, current_model_up)
		
	var move_vector = Input.get_vector("move_left", "move_right", "move_backward", "move_forward");
	wish_steering = move_vector.x
	wish_acceleration = move_vector.y
	wish_break = Input.is_action_pressed("move_brake") \
		or Input.is_action_pressed("move_forward") and Input.is_action_pressed("move_backward")
	
	if Input.is_action_just_pressed("move_jump") && wish_steering != 0 && wish_acceleration > 0:
		wish_drift = true
		wish_drift_direction = sign(wish_steering)
	if Input.is_action_just_released("move_jump") or wish_acceleration <= 0:
		wish_drift = false
	
	debug_label.text = "Position: " + str(global_position) + "\nVelocity: " + str(velocity) 
		

func _apply_car_engine_force(delta : float) -> void:
	var forward : Vector3 = -global_transform.basis.z;	
	var horizontal_velocity := get_horizontal_velocity()
	
	horizontal_velocity = forward * forward.dot(horizontal_velocity)
	var speed = horizontal_velocity.length()
	
	if wish_break:
		horizontal_velocity = horizontal_velocity.lerp(Vector3.ZERO, 1 - pow(break_resistance, delta))
	elif wish_acceleration == 0:
		horizontal_velocity = horizontal_velocity.lerp(Vector3.ZERO, 1 - pow(roll_resistance, delta))
	elif wish_acceleration > 0 && speed < top_speed:
		horizontal_velocity += wish_acceleration * forward * delta * acceleration
	elif wish_acceleration < 0 && speed < top_reverse_speed:
		horizontal_velocity += wish_acceleration * forward * delta * acceleration

		
	velocity = horizontal_velocity + Vector3.UP * velocity.y
	
		
func _apply_air_force(delta : float) -> void:
	var forward : Vector3 = -global_transform.basis.z;	
	var horizontal_velocity := get_horizontal_velocity()
	horizontal_velocity = forward * forward.dot(horizontal_velocity)
	velocity = horizontal_velocity + Vector3.UP * velocity.y + gravity_acceleration * delta
	

func _apply_water_force(delta : float) -> void:
	if !water_buoyancy.is_on_water():
		return
	var d := water_buoyancy.get_water_height()
	var a : float = 10
	if velocity.y > 0:
		a = 2.5
			
	velocity.y += (d - global_position.y) * delta * a
	

		

func _physics_process(delta: float) -> void:
	_apply_steering(delta)	
	_apply_water_force(delta)	
	
	if is_on_ground():
		_apply_car_engine_force(delta)
		if wish_jump:
			velocity += Vector3.UP * 2
	else:
		_apply_air_force(delta)
		
	reset_buffer()
	move_and_slide()
	
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("move_jump"):
		wish_jump = true;


	
