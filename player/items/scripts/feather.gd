extends Node3D

func _ready() -> void:
	var owner_node := get_parent()
	if owner_node is Node:
		var kart = owner_node.get_node_or_null("Kart")
		if kart and kart.has_method("trigger_feather_boost"):
			kart.trigger_feather_boost()

	# Put your boost animation code
	queue_free()
	
