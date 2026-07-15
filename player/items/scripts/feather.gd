extends Node3D

func _ready() -> void:
	var owner_node : Node = get_parent()
	while owner_node != null:
		if owner_node.has_method("trigger_feather_boost"):
			owner_node.trigger_feather_boost()
			break
		owner_node = owner_node.get_parent()

	# Put your boost animation code
	queue_free()
	
