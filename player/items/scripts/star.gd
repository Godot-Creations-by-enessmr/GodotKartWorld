extends Node3D

func _ready() -> void:
	var owner_node: Node = get_parent()
	while owner_node != null:
		if owner_node.has_method("trigger_star_power"):
			owner_node.trigger_star_power()
			break
		owner_node = owner_node.get_parent()

	queue_free()
