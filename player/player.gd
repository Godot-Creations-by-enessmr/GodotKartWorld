class_name Player extends Node3D

@onready var kart : Kart = $Kart
@onready var camera : Node3D = $CameraPivot
@onready var inventory : Inventory = $Inventory

var ocean_node : Ocean
var tire_marks_node : Node


func _ready() -> void:
	if !ocean_node:
		ocean_node = get_tree().get_first_node_in_group("ocean")
	if !tire_marks_node:
		tire_marks_node = get_tree().get_first_node_in_group("tire_marks")

func _follow_camera(_delta: float) -> void:
	camera.global_position = kart.visual_parent.global_position + Vector3(0, 1, 0)

func _process(delta: float) -> void:
	_follow_camera(delta)
	
	RenderingServer.global_shader_parameter_set("player_position", kart.global_position)
	
	if ocean_node:
		ocean_node.set_player_position(kart.global_position)
		if kart.water_buoyancy_sensor.is_on_water() and randf() < pow(kart.velocity.length() / kart.top_speed, 2.0):
			#var v = kart.velocity;
			var strength = clamp(0.2 * Vector2(kart.velocity.x, kart.velocity.z).length(), 0, 1);
			strength += clamp(2 * abs(kart.velocity.y), 0, 1);
			ocean_node.add_ripple(kart.global_position, 1, strength * 0.025);
	
	if tire_marks_node:
		tire_marks_node.set_player_position(kart.global_position)
		for wheel in kart.wheels:
			if wheel.is_grounded():
				tire_marks_node.add_tire(wheel.get_wheel_position(), 1.0, 9.0);
			else:
				tire_marks_node.add_tire(wheel.get_wheel_position(), 0.0, 0.0);


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("use_item"):
		inventory.use_item(self)

func add_item(item : ItemType) -> void:
	inventory.add_item(item)

func trigger_feather_boost() -> void:
	if kart and kart.has_method("trigger_feather_boost"):
		kart.trigger_feather_boost()

func get_kart_position() -> Vector3:
	return kart.global_position

func get_item_direction() -> Vector3:
	var dir = camera.basis.z	
	return Vector3(dir.x, 0, dir.z).normalized()
