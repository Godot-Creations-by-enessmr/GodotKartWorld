class_name Kart extends CharacterBody3D

# =============== Input Buffer ===============
var wish_acceleration : float
var wish_steering : float
var wish_jump : bool
var wish_break : bool
var wish_drift : bool
var wish_drift_direction : float
var drift_timer : float 
var drift_stage : int 

var boost_timer : float
var star_power_active := false
var star_power_timer := 0.0
var is_invincible := false

var wheels : Array[Wheel]
var steering : float = 0
var gravity_acceleration : Vector3 = 2.0 * Vector3(0, -9.81, 0)
var current_model_up : Vector3 = Vector3.UP

# ----- TRICK SYSTEM (INFINITE AIR TRICKS) -----
var feather_active := false
var trick_triggered := false
var air_time := 0.0

var in_water_timer := 0.0
var water_normal := Vector3(0,1,0)

# Star Power overlay
var star_material: ShaderMaterial = null
var star_mesh_instances: Array[MeshInstance3D] = []

# ----- CHARGE JUMP SYSTEM -----
var is_charging_jump := false
var charge_time := 0.0
var is_charging_blue := false
var jump_press_time := 0.0
var is_hold_jump := false
const TAP_THRESHOLD := 0.3
const MAX_CHARGE_TIME := 2.5
const MIN_JUMP_VELOCITY := 4.0

# ----- RAIL GRIND -----
var on_rail := false
var current_rail_curve: Curve3D = null
var rail_global_transform: Transform3D = Transform3D.IDENTITY
var rail_progress: float = 0.0
var rail_cooldown := 0.0
@export var rail_grind_speed_normal: float = 20.0
@onready var rail_detector: RayCast3D = $RailDetector

# --- Adjustable feather parameters (exported) ---
@export_group("Feather")
@export var feather_initial_vertical_velocity := 8.0
@export var feather_initial_boost_duration := 0.35
@export var feather_trick_boost := 1.0

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
@export var air_boost_multiplier := 1.1

@export_group("Boost")
@export var max_boost_time := 10.0

@export_group("Star Power")
@export var star_speed_multiplier := 1.5
@export var star_gradient_speed := 2.0
@export var star: AudioStreamPlayer3D

@export_group("Music")
@export var GCN_dih_dieach: AudioStreamPlayer

@export_group("Chargejump")
@export var charge_particles: GPUParticles3D = null

@onready var water_buoyancy_sensor : WaterBuoyancySensor = $WaterBuoyancySensor
@onready var visual_parent : Node3D = $Visual
@onready var visual_kart : Node3D = $Visual/Kart
@onready var steering_wheel : Node3D = $Visual/Kart/Body/Node3D/SteeringWheel
@onready var debug_label : Label = $DebugLabel
@onready var animation_player : AnimationPlayer = $Visual/Kart/AnimationPlayer
@onready var particles_manager : ParticlesManager = $ParticlesManager

func is_on_ground() -> bool:
	return is_on_floor() or water_buoyancy_sensor.is_in_water()

func is_on_solid_ground() -> bool:
	return is_on_floor()

func is_in_water() -> bool:
	return water_buoyancy_sensor.is_in_water()

func get_horizontal_velocity() -> Vector3:
	return Vector3(velocity.x, 0, velocity.z)

func reset_buffer() -> void:
	wish_jump = false
	wish_steering = 0
	wish_acceleration = 0 

func _apply_steering(delta : float) -> void:
	var v := get_horizontal_velocity()
	var horizontal_speed : float = v.length() * sign(v.dot(-global_transform.basis.z))
	steering = lerp(steering, wish_steering, 1.0 - pow(0.5, 60.0 * delta))
	
	var angular_velocity : float = deg_to_rad(air_steering_velocity * steering)
	
	var max_steering_angle = lerp(max_steering_angle_slow, max_steering_angle_fast, clamp(horizontal_speed / top_speed, 0.0, 1.0))
	var avg_steering_angle = lerp(max_steering_angle_slow, max_steering_angle_fast, 1.0)

	if is_on_ground():
		if wish_break && abs(horizontal_speed) < 1:
			angular_velocity = deg_to_rad(handbrake_steering_velocity * steering)
		elif abs(horizontal_speed) > 1e-2:
			var steering_angle : float
			if wish_drift:
				steering_angle = drift_steering_multiplier * max_steering_angle * (wish_drift_direction * 0.6 + 0.4 * steering)
			else:
				steering_angle = max_steering_angle * steering
			angular_velocity = (horizontal_speed * tan(deg_to_rad(steering_angle))) / wheel_base
		else:
			angular_velocity = 0.0
	
	rotate_y(-delta * angular_velocity)
	for wheel in wheels:
		wheel.set_steering(-steering * 2.0 * deg_to_rad(avg_steering_angle))
		wheel.speed = horizontal_speed
	steering_wheel.rotation.y = -steering * 3.0 * deg_to_rad(avg_steering_angle)
	visual_kart.rotation.z = steering * 0.5 * deg_to_rad(avg_steering_angle)

func _align_mesh_with_normal(_delta : float, normal: Vector3) -> void:
	var up := normal.normalized()
	var forward := -global_transform.basis.z
	forward = (forward - up * forward.dot(up)).normalized()

	if forward.length() < 0.001:
		return
		
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

func _setup_star_material() -> void:
	star_material = ShaderMaterial.new()
	star_material.shader = preload("res://shared/shaders/star_power.gdshader")
	
	star_material.set_shader_parameter("gradient_offset", 0.0)
	star_material.set_shader_parameter("gradient_speed", star_gradient_speed)
	star_material.set_shader_parameter("star_active", false)
	
	var meshes = visual_kart.find_children("*", "MeshInstance3D", true, false)
	for mesh_instance in meshes:
		if mesh_instance is MeshInstance3D:
			star_mesh_instances.append(mesh_instance)

func _apply_star_gradient(delta: float) -> void:
	if star_power_active and star_material:
		var current_offset = star_material.get_shader_parameter("gradient_offset")
		current_offset += delta * star_gradient_speed
		if current_offset > 1.0:
			current_offset -= 1.0
		star_material.set_shader_parameter("gradient_offset", current_offset)

func _ready() -> void:
	for child in visual_kart.get_children():
		if child is Wheel:
			wheels.append(child)
	GCN_dih_dieach.play()
			
	_set_drifing_stage(0)
	_setup_star_material()

func _process(delta: float) -> void:
	# Only visuals and passive updates remain here
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
		var forward : Vector3 = -global_transform.basis.z
		var side := forward.cross(up)		
		var vertical_velocity := velocity.dot(up)
		var lean_angle : float = clamp(vertical_velocity * lean_strength, -0.2, 0.2)
		new_up = up.rotated(side.normalized(), lean_angle)
		
	current_model_up = current_model_up.lerp(new_up, 1 - pow(t, 2 * delta))
	_align_mesh_with_normal(delta, current_model_up)
	
	_apply_star_gradient(delta)
	
	# Star power / boost timer updates (non‑physics)
	if boost_timer > 0:
		boost_timer -= delta
		if boost_timer <= 0:
			particles_manager.set_boost(false)

	if star_power_active:
		star_power_timer -= delta
		GCN_dih_dieach.stop()
		if star_power_timer <= 0:
			end_star_power()
	
	debug_label.text = "Position: " + str(global_position) + "\nVelocity: " + str(velocity)

# ----- CHARGE JUMP FUNCTIONS -----
func _set_charge_particle_color(color: Color) -> void:
	if not charge_particles:
		return
	var mesh = charge_particles.draw_pass_1
	if mesh:
		var material = mesh.surface_get_material(0)
		if material is StandardMaterial3D:
			material.albedo_color = color

func _start_charge_jump() -> void:
	if is_on_ground() or is_in_water():
		is_charging_jump = true
		is_charging_blue = false
		charge_time = 0.0
		if charge_particles:
			charge_particles.emitting = true
			charge_particles.scale = Vector3(1, 1, 1)
			_set_charge_particle_color(Color(0.3, 0.5, 1.0, 0.8))

func _cancel_charge_jump() -> void:
	is_charging_jump = false
	is_charging_blue = false
	charge_time = 0.0
	if charge_particles:
		charge_particles.emitting = false
		charge_particles.scale = Vector3(1, 1, 1)

func _perform_charge_jump() -> void:
	if not is_charging_jump:
		return
	
	var charge_percent = clamp(charge_time / MAX_CHARGE_TIME, 0.0, 1.0)
	var jump_velocity = lerp(MIN_JUMP_VELOCITY, feather_initial_vertical_velocity, charge_percent)
	velocity.y = jump_velocity
	
	if charge_time > 1.0:
		set_boost(min(charge_time * 0.2, 1.5))
	
	if charge_time >= 2.0:
		particles_manager.play_trick_particles()
	
	is_charging_jump = false
	is_charging_blue = false
	charge_time = 0.0
	
	if charge_particles:
		charge_particles.emitting = false
		charge_particles.scale = Vector3(1, 1, 1)
	
	in_water_timer = 0.0

func play_item_roll_animation(item_type: ItemType) -> StringName:
	if not animation_player or item_type == null:
		return &""

	var base_name := item_type.name.to_lower().replace(" ", "_").replace("-", "_")
	var animation_name := StringName(base_name + "_roll")

	if animation_player.has_animation(animation_name):
		animation_player.play(animation_name)
		return animation_name

	return &""

func set_boost(time : float):
	boost_timer = min(boost_timer + time, max_boost_time)
	particles_manager.set_boost(true)

func set_invincible(enabled: bool) -> void:
	is_invincible = enabled

func trigger_star_power(duration: float = 8.0) -> void:
	star_power_active = true
	star_power_timer = max(star_power_timer, duration)
	
	for mesh_instance in star_mesh_instances:
		if is_instance_valid(mesh_instance):
			mesh_instance.material_overlay = star_material
	
	if star_material:
		star_material.set_shader_parameter("star_active", true)
	
	set_invincible(true)
	particles_manager.set_rainbow_mode(true)
	
	if star and not star.playing:
		star.play()

func end_star_power() -> void:
	star_power_active = false
	star_power_timer = 0.0
	
	for mesh_instance in star_mesh_instances:
		if is_instance_valid(mesh_instance):
			mesh_instance.material_overlay = null
	
	if star_material:
		star_material.set_shader_parameter("star_active", false)
	
	if star and star.playing:
		star.stop()
		GCN_dih_dieach.play()
	
	set_invincible(false)
	particles_manager.set_rainbow_mode(false)

func trigger_feather_boost() -> void:
	velocity.y = feather_initial_vertical_velocity
	set_boost(feather_initial_boost_duration)
	
	animation_player.play("trick")
	particles_manager.play_trick_particles()
	
	feather_active = true

func _apply_car_engine_force(delta : float) -> void:
	# Use a strictly horizontal forward to avoid tilting causing vertical velocity
	var forward := -global_transform.basis.z
	var horizontal_forward := Vector3(forward.x, 0, forward.z).normalized()
	if horizontal_forward.length() < 0.001:
		horizontal_forward = Vector3.FORWARD
	
	var horizontal_velocity := get_horizontal_velocity()
	
	horizontal_velocity = horizontal_velocity.lerp(Vector3.ZERO, 1 - pow(0.5, roll_resistance * delta))
	
	if not wish_drift:
		horizontal_velocity = horizontal_forward * horizontal_forward.dot(horizontal_velocity)
	
	var speed = horizontal_velocity.length()
	
	var current_top_speed = top_speed
	var current_boost_speed = boost_speed
	var current_acceleration = acceleration
	
	if star_power_active:
		current_top_speed = top_speed * star_speed_multiplier
		current_boost_speed = boost_speed * star_speed_multiplier
		current_acceleration = acceleration * star_speed_multiplier
	
	if wish_break:
		horizontal_velocity = horizontal_velocity.lerp(Vector3.ZERO, 1 - pow(0.5, break_resistance * delta))
	elif boost_timer > 0 and speed < current_boost_speed:
		horizontal_velocity += horizontal_forward * delta * boost_acceleration
	elif wish_acceleration > 0 and speed < current_top_speed:
		horizontal_velocity += wish_acceleration * horizontal_forward * delta * current_acceleration
	elif wish_acceleration < 0 and speed < top_reverse_speed:
		horizontal_velocity += wish_acceleration * horizontal_forward * delta * acceleration

	# Preserve vertical velocity separately
	velocity = Vector3(horizontal_velocity.x, velocity.y, horizontal_velocity.z)
	
func _apply_air_force(delta : float) -> void:
	# Use a strictly horizontal forward
	var forward := -global_transform.basis.z
	var horizontal_forward := Vector3(forward.x, 0, forward.z).normalized()
	if horizontal_forward.length() < 0.001:
		horizontal_forward = Vector3.FORWARD
	
	var horizontal_velocity := get_horizontal_velocity()
	
	var is_boosting := boost_timer > 0
	
	var drag_multiplier := air_drag * (0.2 if is_boosting else 1.0)
	horizontal_velocity = horizontal_velocity.lerp(Vector3.ZERO, 1 - pow(0.5, drag_multiplier * delta))
	
	var current_speed = horizontal_velocity.length()
	var max_air_speed = top_speed * (air_boost_multiplier if is_boosting else air_speed_multiplier)
	
	if star_power_active:
		max_air_speed *= star_speed_multiplier
	
	if current_speed > max_air_speed:
		horizontal_velocity = horizontal_velocity.normalized() * max_air_speed
	
	horizontal_velocity = horizontal_forward * horizontal_forward.dot(horizontal_velocity)
	
	# Apply gravity only to the vertical component
	var new_vertical := velocity.y + gravity_acceleration.y * delta
	
	velocity = Vector3(horizontal_velocity.x, new_vertical, horizontal_velocity.z)
	
func _apply_water_force(delta : float) -> void:
	if not water_buoyancy_sensor.is_in_water():
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

# ==================== RAIL GRIND SYSTEM (FIXED) ====================

func _detect_rail() -> Curve3D:
	rail_detector.enabled = true
	rail_detector.force_raycast_update()
	if rail_detector.is_colliding():
		var collider = rail_detector.get_collider()
		if collider is Node3D:
			var path = _find_path3d_child(collider)
			if path and path.curve:
				rail_global_transform = path.global_transform
				rail_detector.enabled = false
				return path.curve
	rail_detector.enabled = false
	return null

func _find_path3d_child(node: Node3D) -> Path3D:
	# Check direct children of the collider
	for child in node.get_children():
		if child is Path3D:
			return child
	# Check the parent (if collider is a child of the rail mesh)
	var parent = node.get_parent()
	if parent is Node3D:
		for child in parent.get_children():
			if child is Path3D:
				return child
	# Check siblings (if Path3D is alongside the collider)
	if parent is Node3D and parent.get_parent() is Node3D:
		for child in (parent.get_parent() as Node3D).get_children():
			if child is Path3D:
				return child
	return null

func _enter_rail(curve: Curve3D) -> void:
	if rail_cooldown > 0.0:
		return
	
	on_rail = true
	current_rail_curve = curve
	rail_progress = 0.0

	air_time = 0.1
	trick_triggered = false
	feather_active = false

	for wheel in wheels:
		wheel.set_grinding(true, 1)

	var hit_pos = rail_detector.get_collision_point()
	var local_hit = rail_global_transform.affine_inverse() * hit_pos
	
	var baked = curve.get_baked_points()
	var closest_dist = 1e6
	var closest_idx = 0
	for i in range(baked.size()):
		var d = local_hit.distance_squared_to(baked[i])
		if d < closest_dist:
			closest_dist = d
			closest_idx = i
	var len = curve.get_baked_length()
	if baked.size() > 1:
		rail_progress = closest_idx * (len / (baked.size() - 1))

	velocity = Vector3.ZERO
	rail_cooldown = 0.0
	rail_detector.enabled = false

func _process_rail_grind(delta: float) -> void:
	var curve = current_rail_curve
	if not curve or curve.point_count == 0:
		_exit_rail()
		return

	var spd = boost_speed if boost_timer > 0.0 else rail_grind_speed_normal
	if star_power_active:
		spd *= star_speed_multiplier

	rail_progress += spd * delta

	var total_length = curve.get_baked_length()
	if total_length <= 0.0 or rail_progress >= total_length:
		_exit_rail()
		return

	var local_pt = curve.sample_baked(rail_progress, true)
	var local_tangent = curve.sample_baked(rail_progress, false)
	
	var global_pt = rail_global_transform * local_pt
	var global_tangent = rail_global_transform.basis * local_tangent.normalized()
	
	global_position = global_pt
	
	if global_tangent.length() > 0.001:
		var forward = global_tangent.normalized()
		var up_ref = Vector3.UP
		
		var right = up_ref.cross(forward).normalized()
		if right.length() < 0.001:
			right = Vector3.RIGHT
		up_ref = forward.cross(right).normalized()
		
		global_transform.basis = Basis(right, up_ref, forward)
		velocity = global_tangent * spd
	else:
		velocity = -global_transform.basis.z * spd

	if Input.is_action_just_pressed("move_jump"):
		wish_jump = true
	if wish_jump and not trick_triggered:
		trick_triggered = true
		animation_player.play("trick")
		particles_manager.play_trick_particles()
		set_boost(feather_trick_boost)
	if not wish_jump:
		trick_triggered = false

	air_time += delta

func _exit_rail() -> void:
	if not on_rail:
		return

	for wheel in wheels:
		wheel.set_grinding(false, 0)

	on_rail = false
	current_rail_curve = null
	rail_global_transform = Transform3D.IDENTITY
	rail_cooldown = 0.5

	# ----- SLOW DOWN ON EXIT (UNLESS W or S IS PRESSED) -----
	var pressing_forward = Input.is_action_pressed("move_forward")
	var pressing_backward = Input.is_action_pressed("move_backward")
	
	if not (pressing_forward or pressing_backward):
		var h_vel := get_horizontal_velocity()
		h_vel *= 0.2   # adjust slowdown factor as desired
		velocity = Vector3(h_vel.x, velocity.y, h_vel.z)
	# else keep velocity as is

	# ----- IMPROVED GROUND SNAPPING TO PREVENT CLIPPING -----
	var space_state = get_world_3d().direct_space_state
	# Cast from slightly above the kart to avoid starting inside the ground
	var origin := global_position + Vector3.UP * 0.5
	var target := origin - Vector3.UP * 5.0  # 5-meter ray
	var query = PhysicsRayQueryParameters3D.create(origin, target)
	query.collision_mask = 1  # adjust to your ground collision layer
	var result = space_state.intersect_ray(query)

	if not result.is_empty():
		# Place the kart exactly on the surface with a tiny offset
		global_position.y = result.position.y + 0.05
		velocity.y = 0.0
	# else: let gravity handle it naturally

# ==================== END RAIL SYSTEM ====================

func _physics_process(delta: float) -> void:
	var move_vector = Input.get_vector("move_left", "move_right", "move_backward", "move_forward")
	wish_steering = move_vector.x
	wish_acceleration = move_vector.y
	wish_break = Input.is_action_pressed("move_brake") \
		or Input.is_action_pressed("move_forward") and Input.is_action_pressed("move_backward")
	
	if rail_cooldown > 0.0:
		rail_cooldown -= delta

	if on_rail:
		_process_rail_grind(delta)
		move_and_slide()
		reset_buffer()
		return

	if Input.is_action_just_pressed("move_jump"):
		if abs(wish_steering) > 0.1 and wish_acceleration > 0 and is_on_ground():
			wish_drift = true
			wish_drift_direction = sign(wish_steering)
			_set_drifing_stage(0)
			drift_timer = 0.0
			is_hold_jump = false
			wish_jump = false
			reset_buffer()
			move_and_slide()
			return

	if is_hold_jump and is_on_ground() and abs(wish_steering) < 0.1 and not is_charging_jump and not wish_drift:
		var elapsed = (Time.get_ticks_msec() / 1000.0) - jump_press_time
		if elapsed > TAP_THRESHOLD:
			_start_charge_jump()

	if is_charging_jump:
		charge_time += delta
		if charge_time >= 1.5 and not is_charging_blue:
			is_charging_blue = true
			_set_charge_particle_color(Color(0.0, 0.4, 1.0, 0.8))
		if charge_particles:
			var charge_percent = min(charge_time / MAX_CHARGE_TIME, 1.0)
			charge_particles.scale = Vector3(1 + charge_percent * 3, 1 + charge_percent * 3, 1 + charge_percent * 3)
		if abs(wish_steering) > 0.1:
			_cancel_charge_jump()

	if Input.is_action_just_released("move_jump"):
		if is_charging_jump:
			_perform_charge_jump()
		elif wish_drift:
			if drift_stage == 2: set_boost(0.5)
			if drift_stage == 3: set_boost(1.0)
			if drift_stage == 4: set_boost(4.0)
			wish_drift = false
			_set_drifing_stage(0)
		is_hold_jump = false

	if wish_drift and is_on_ground() and not is_charging_jump:
		if drift_stage < 1: _set_drifing_stage(1)
		if drift_timer > 0.8 and drift_stage < 2: _set_drifing_stage(2)
		drift_timer += delta
		if drift_timer > 3.0 and drift_stage < 3: _set_drifing_stage(3)
		if drift_timer > 5.0 and drift_stage < 4: _set_drifing_stage(4)

	_apply_steering(delta)	
	_apply_water_force(delta)	

	var on_solid_ground := is_on_solid_ground()
	var on_ground := is_on_ground()

	if on_solid_ground:
		feather_active = false
		trick_triggered = false
		air_time = 0.0
	else:
		air_time += delta

	var can_trick := not on_solid_ground and air_time > 0.05 and not trick_triggered
	if can_trick and wish_jump:
		trick_triggered = true
		animation_player.play("trick")
		particles_manager.play_trick_particles()
		set_boost(feather_trick_boost)
	if not wish_jump:
		trick_triggered = false

	if wish_jump and is_on_ground() and not is_charging_jump and not wish_drift:
		velocity.y = MIN_JUMP_VELOCITY
		in_water_timer = 0.0
		wish_jump = false

	if not on_solid_ground and velocity.y < 0.0 and rail_cooldown <= 0.0:
		var curve = _detect_rail()
		if curve:
			_enter_rail(curve)
			_process_rail_grind(delta)
			move_and_slide()
			reset_buffer()
			return

	if on_ground:
		_apply_car_engine_force(delta)
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
		wish_jump = true
		jump_press_time = Time.get_ticks_msec() / 1000.0
		is_hold_jump = true
	if event.is_action_released("move_jump"):
		is_hold_jump = false

func get_kart_position() -> Vector3:
	return global_position

func get_item_direction() -> Vector3:
	return -global_transform.basis.z

func _exit_tree() -> void:
	for mesh_instance in star_mesh_instances:
		if is_instance_valid(mesh_instance):
			mesh_instance.material_overlay = null
