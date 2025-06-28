extends RigidBody3D


func _ready() -> void:
	await get_tree().create_timer(2).timeout
	_explode()

func _explode() -> void:
	queue_free()
	
	
	var ocean_node : Ocean = get_tree().get_first_node_in_group("ocean")
	if ocean_node: 
		print("boom")
		ocean_node.add_wave(global_position, 32, 32)
