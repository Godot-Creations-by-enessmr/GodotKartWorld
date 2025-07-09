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
