class_name Kart extends CharacterBody3D

var wish_acceleration : float
var wish_steering : float
var wish_jump : bool
var wish_break : bool
var wish_drift : bool
var wish_drift_direction : float
var drift_timer : float 
var drift_stage : int 

var boost_timer : float

var wheels : Array[Wheel]
var steering : float = 0
var gravity_acceleration : Vector3 = 2.0 * Vector3(0, -9.81, 0)
var current_model_up : Vector3 = Vector3.UP


var trick_timer := 0.0
var trick_cooldown := 0.4
var has_tricked := false
var feather_trick_active := false
var feather_trick_count := 0

var in_water_timer := 0.0
var water_normal := Vector3(0,1,0)

@export_custom(PROPERTY_HINT_NONE, "suffix:m/s") var boost_speed := 30.0
@export_custom(PROPERTY_HINT_NONE, "suffix:m/s") var boost_acceleration := 50.0
@export_custom(PROPERTY_HINT_NONE, "suffix:m/s") var top_speed := 20.0
@export_custom(PROPERTY_HINT_NONE, "suffix:m/s") var top_reverse_speed := 8.0
@export_custom(PROPERTY_HINT_NONE, "suffix:m/s/s") var acceleration := 20.0
@export var roll_resistance := 0.4
@export var break_resistance := 0.1

@export_group("Steering")
@export_custom(PROPERTY_HINT_NONE, "suffix:degrees") var max_steering_angle_slow := 16.0
@export_custom(PROPERTY_HINT_NONE, "suffix:degrees") var max_steering_angle_fast := 8.0
@export_custom(PROPERTY_HINT_NONE, "suffix:degrees/s") var handbrake_steering_velocity := 45.0
@export_custom(PROPERTY_HINT_NONE, "suffix:degrees/s") var air_steering_velocity := 50.0
@export_custom(PROPERTY_HINT_NONE, "suffix:m") var wheel_base := 1.5
@export var drift_steering_multiplier := 1.5

@export_group("Air Control")
@export var air_speed_multiplier := 0.9
@export var air_drag := 0.1
@export var air_boost_multiplier := 0.992  # How much speed you keep in air while boosting

@export_group("Boost")
@export var max_boost_time := 10.0

@onready var water_buoyancy_sensor : WaterBuoyancySensor = $WaterBuoyancySensor
@onready var visual_parent : Node3D = $Visual
@onready var visual_kart : Node3D = $Visual/Kart
@onready var steering_wheel : Node3D = $Visual/Kart/Body/Node3D/SteeringWheel
@onready var debug_label : Label = $DebugLabel
@onready var animation_player : AnimationPlayer = $Visual/Kart/AnimationPlayer
@onready var particles_manager : ParticlesManager = $ParticlesManager

func is_on_ground() -> bool:
	return is_on_floor() or water_buoyancy_sensor.is_in_water()

func get_horizontal_velocity() -> Vector3:
	return Vector3(velocity.x, 0, velocity.z)

func reset_buffer() -> void:
	wish_jump = false
	wish_steering = 0
	wish_acceleration = 0 

func _apply_steering(delta : float) -> void:
	var v := get_horizontal_velocity()
	var horizonal_speed : float = v.length() * sign(v.dot(-global_transform.basis.z))
	steering = lerp(steering, wish_steering, 1.0 - pow(0.5, 60.0 * delta))
	
	var angular_velocity : float = deg_to_rad(air_steering_velocity * steering)
	
	var max_steering_angle = lerp(max_steering_angle_slow, max_steering_angle_fast, clamp(horizonal_speed / top_speed, 0.0, 1.0))
	var avg_steering_angle = lerp(max_steering_angle_slow, max_steering_angle_fast, 1.0)

	if is_on_ground():
		if wish_break && abs(horizonal_speed) < 1:
			angular_velocity = deg_to_rad(handbrake_steering_velocity * steering)
		else:
			var steering_angle : float
			if wish_drift:
				steering_angle = drift_steering_multiplier * max_steering_angle * (wish_drift_direction * 0.6 + 0.4 * steering)
			elif abs(horizonal_speed) > 1e-2:
				steering_angle = max_steering_angle * steering
			angular_velocity = (horizonal_speed * tan(deg_to_rad(steering_angle))) / wheel_base
	
	
	rotate_y(-delta * angular_velocity)
	#exaggerate movements
	for wheel in wheels:
		wheel.set_steering(-steering * 2.0 * deg_to_rad(avg_steering_angle))
		wheel.speed = horizonal_speed
	steering_wheel.rotation.y = -steering * 3.0 * deg_to_rad(avg_steering_angle)
	visual_kart.rotation.z = steering * 0.5 * deg_to_rad(avg_steering_angle)
			

func _align_mesh_with_normal(_delta : float, normal: Vector3) -> void:
	var up := normal.normalized()
	var forward := -global_transform.basis.z
	forward = (forward - up * forward.dot(up)).normalized()

	var right := up.cross(forward).normalized()

	var new_basis := Basis()
	new_basis.x = right
	new_basis.y = up
	new_basis.z = forward
	
	if !animation_player.is_playing():
		visual_parent.global_basis = new_basis
	
func _set_drifing_stage(stage: int) -> void:
	drift_stage = stage
	particles_manager.set_drifing_stage(stage)


func _ready() -> void:
	for child in visual_kart.get_children():
		if child is Wheel:
			wheels.append(child)
			
	_set_drifing_stage(0)
	

func _process(delta: float) -> void:
	var new_up := Vector3.UP
	var t := 0.5
	if water_buoyancy_sensor.is_in_water():
		t = 0.3
		water_normal = lerp(water_normal, water_buoyancy_sensor.compute_normal(), 1.0 - pow(0.5, 10 * delta))
		new_up = water_normal
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
		new_up = up.rotated(side.normalized(), lean_angle)
		
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
		_set_drifing_stage(0)
		drift_timer = 0.0
		
	if Input.is_action_just_released("move_jump") or wish_acceleration <= 0:
		wish_drift = false
		if drift_stage == 2:
			set_boost(0.5)
		if drift_stage == 3:
			set_boost(1.0)
		if drift_stage == 4:
			set_boost(4.0)
		
		_set_drifing_stage(0)
		
	if has_tricked and is_on_ground():
		set_boost(1.0)
		has_tricked = false
		
	if wish_drift && is_on_ground():
		if drift_stage < 1:
			_set_drifing_stage(1)
		if drift_timer > 0.8 and drift_stage < 2:
			_set_drifing_stage(2)
		drift_timer += delta
		if drift_timer > 3.0 && drift_stage < 3:
			_set_drifing_stage(3)
		if drift_timer > 5.0 && drift_stage < 4:
			_set_drifing_stage(4)
	
	if boost_timer > 0:
		boost_timer -= delta
		if boost_timer <= 0:
			particles_manager.set_boost(false)
			
	if trick_timer > 0 and not has_tricked:
		trick_timer -= delta
	
	debug_label.text = "Position: " + str(global_position) + "\nVelocity: " + str(velocity) 

func set_boost(time : float):
	boost_timer = min(boost_timer + time, max_boost_time)
	particles_manager.set_boost(true)

func trigger_feather_boost() -> void:
	var current_horizontal_velocity := get_horizontal_velocity()
	if current_horizontal_velocity.length_squared() < 1e-4:
		current_horizontal_velocity = -global_transform.basis.z * max(top_speed * 0.5, 1.0)

	velocity = current_horizontal_velocity + Vector3.UP * 8.0
	feather_trick_active = true
	feather_trick_count = 0
	set_boost(0.35)
	animation_player.current_animation = "trick"
	particles_manager.play_trick_particles()
	

func _apply_car_engine_force(delta : float) -> void:
	var forward : Vector3 = -global_transform.basis.z;	
	var horizontal_velocity := get_horizontal_velocity()
	
	#drag
	horizontal_velocity = horizontal_velocity.lerp(Vector3.ZERO, 1 - pow(0.5, roll_resistance * delta))
	
	var speed = horizontal_velocity.length()
	horizontal_velocity = forward * forward.dot(horizontal_velocity)
	
	if wish_break:
		horizontal_velocity = horizontal_velocity.lerp(Vector3.ZERO, 1 - pow(0.5, break_resistance * delta))
	elif boost_timer > 0 && speed < boost_speed:
		horizontal_velocity += forward * delta * boost_acceleration
	elif wish_acceleration > 0 && speed < top_speed:
		horizontal_velocity += wish_acceleration * forward * delta * acceleration
	elif wish_acceleration < 0 && speed < top_reverse_speed:
		horizontal_velocity += wish_acceleration * forward * delta * acceleration

	velocity = horizontal_velocity + Vector3.UP * velocity.y
	
	
func _apply_air_force(delta : float) -> void:
	var forward : Vector3 = -global_transform.basis.z	
	var horizontal_velocity := get_horizontal_velocity()
	
	# Check if boosting
	var is_boosting := boost_timer > 0
	
	# Apply air drag (reduced when boosting)
	var drag_multiplier := air_drag * (0.2 if is_boosting else 1.0)
	horizontal_velocity = horizontal_velocity.lerp(Vector3.ZERO, 1 - pow(0.5, drag_multiplier * delta))
	
	# Apply air speed penalty (reduced when boosting)
	var current_speed = horizontal_velocity.length()
	var max_air_speed = top_speed * (air_boost_multiplier if is_boosting else air_speed_multiplier)
	
	if current_speed > max_air_speed:
		horizontal_velocity = horizontal_velocity.normalized() * max_air_speed
	
	horizontal_velocity = forward * forward.dot(horizontal_velocity)
	
	velocity = horizontal_velocity + Vector3.UP * velocity.y + gravity_acceleration * delta
	

func _apply_water_force(delta : float) -> void:
	if !water_buoyancy_sensor.is_in_water():
		in_water_timer = 0.0
		return
	in_water_timer += delta
		
	var water_height := water_buoyancy_sensor.get_water_height() + 0.2
	
	var water_surface_sticking_strength = clamp(0.5 * in_water_timer, 0.0, 1.0)
	var water_time_threshold = 1.0
	
	if water_surface_sticking_strength >= 0.5 * water_time_threshold:
		global_position.y = lerp(global_position.y, water_height, 1.0 - pow(0.8, 60.0 * delta * water_surface_sticking_strength))
		velocity.y = lerp(velocity.y, 0.0, 1.0 - pow(0.5, 60.0 * delta * (1.0 - water_surface_sticking_strength)))
	if water_surface_sticking_strength < water_time_threshold:
		var a := 50.0 if velocity.y < 0 else 5.0
		velocity.y += (water_height - global_position.y) * delta * a

func _physics_process(delta: float) -> void:
	_apply_steering(delta)	
	_apply_water_force(delta)	
	
	if is_on_ground():
		feather_trick_active = false
		feather_trick_count = 0
	
	if !is_on_ground() and wish_jump:
		if feather_trick_active:
			var boost_time := 0.15 + min(0.1 * feather_trick_count, 0.35)
			feather_trick_count += 1
			set_boost(boost_time)
			velocity.y = max(velocity.y, 3.0)
			var current_horizontal_velocity := get_horizontal_velocity()
			if current_horizontal_velocity.length_squared() < 1e-4:
				current_horizontal_velocity = -global_transform.basis.z * max(top_speed * 0.6, 1.0)
			velocity = current_horizontal_velocity + Vector3.UP * velocity.y
			animation_player.current_animation = "trick"
			particles_manager.play_trick_particles()
		elif trick_timer <= 0.01:
			has_tricked = true
			animation_player.current_animation = "trick"
			particles_manager.play_trick_particles()
			trick_timer = trick_cooldown
	
	if is_on_ground():
		_apply_car_engine_force(delta)
		if wish_jump:
			if !water_buoyancy_sensor.is_in_water():
				trick_timer = trick_cooldown
			in_water_timer = 0.0
			velocity.y += 4
	else:
		_apply_air_force(delta)
		
	reset_buffer()
	move_and_slide()
	
	for i in get_slide_collision_count():
		var c = get_slide_collision(i)
		if c.get_collider() is RigidBody3D:
			const push_force = 1.0
			c.get_collider().apply_central_impulse(-c.get_normal() * push_force)
	
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("move_jump"):
		wish_jump = true;

# In your Kart/Player class
func get_kart_position() -> Vector3:
	return global_position

func get_item_direction() -> Vector3:
	return -global_transform.basis.z
