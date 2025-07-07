class_name Player extends Node3D

@onready var kart : Kart = $Kart
@onready var camera : Node3D = $CameraPivot
@onready var inventory : Inventory = $Inventory

var ocean_node : Ocean


func _ready() -> void:
	if !ocean_node:
		ocean_node = get_tree().get_first_node_in_group("ocean")

func _follow_camera(delta: float) -> void:
	camera.global_position = kart.global_position

func _process(delta: float) -> void:
	_follow_camera(delta)
	
	RenderingServer.global_shader_parameter_set("player_position", kart.global_position)
	
	if ocean_node:
		ocean_node.set_player_position(kart.global_position)
		if kart.water_buoyancy.is_on_water():
			#var v = kart.velocity;
			var strength = clamp(0.2 * Vector2(kart.velocity.x, kart.velocity.z).length(), 0, 1);
			strength += clamp(2 * abs(kart.velocity.y), 0, 1);
			ocean_node.add_ripple(kart.global_position, 1, strength * 0.25);
		#ocean_node.add_wave(kart.global_position, strength, 0);

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("use_item"):
		inventory.use_item(self)

func add_item(item : ItemType) -> void:
	inventory.add_item(item)

func get_kart_position() -> Vector3:
	return kart.global_position

func get_item_direction() -> Vector3:
	var dir = camera.basis.z	
	return Vector3(dir.x, 0, dir.z).normalized()
