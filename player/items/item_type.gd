class_name ItemType extends Resource

@export var name : String
@export var sprite : Texture2D
@export var scene : PackedScene

func use(player: Player) -> void:
	#TODO maybe add more modes 	
	var item : Node3D = scene.instantiate()
	
	player.add_child(item)
	item.global_position = player.get_kart_position()
	
	if item is RigidBody3D:
		var dir = player.get_item_direction()
		dir = (dir + Vector3.UP).normalized()
		item.apply_central_impulse(dir * 10)
		
		var up = Vector3.UP
		var side = up.cross(dir)

		if side.length_squared() > 0.001:
			var axis = side.normalized()
			item.angular_velocity = axis * 10.0
		
		item.global_position += dir * 2

# In ItemType.gd, add this static function:
static func get_random_item() -> ItemType:
	var item := ItemType.new()
	var rand_value := randf()
	
	# Load your actual item scenes
	var mushroom_scene = load("res://items/Mushroom.tscn")
	var star_scene = load("res://items/Star.tscn")
	var feather_scene = load("res://items/Feather.tscn")
	var shell_scene = load("res://items/GreenShell.tscn")
	
	if rand_value < 0.10:   # 10% - Star
		item.name = "Star"
		item.sprite = load("res://items/sprites/star.png")
		item.scene = star_scene
	elif rand_value < 0.30:  # 20% - Feather
		item.name = "Feather"
		item.sprite = load("res://items/sprites/feather.png")
		item.scene = feather_scene
	elif rand_value < 0.60:  # 30% - Mushroom (most common)
		item.name = "Mushroom"
		item.sprite = load("res://items/sprites/mushroom.png")
		item.scene = mushroom_scene
	else:                    # 40% - Green Shell
		item.name = "Green Shell"
		item.sprite = load("res://items/sprites/shell.png")
		item.scene = shell_scene
	
	return item
