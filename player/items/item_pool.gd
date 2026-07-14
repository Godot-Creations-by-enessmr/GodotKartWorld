class_name ItemPool extends Resource

@export var possible_items : Array[ItemType]
@export var use_weights := true
@export var weights : Array[float]

func get_item() -> ItemType:
	if possible_items.is_empty():
		return null
	
	if use_weights and weights.size() == possible_items.size():
		var total_weight := 0.0
		for w in weights:
			total_weight += w
		
		var rand_val := randf() * total_weight
		var cumulative := 0.0
		
		for i in range(possible_items.size()):
			cumulative += weights[i]
			if rand_val <= cumulative:
				return possible_items[i].duplicate()
	
	# Fallback to random selection
	return possible_items[randi() % possible_items.size()].duplicate()
