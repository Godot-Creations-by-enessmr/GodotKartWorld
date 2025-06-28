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
		item.global_position += dir * 2
		item.apply_central_impulse(dir * 10)
