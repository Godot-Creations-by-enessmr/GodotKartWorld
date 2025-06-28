class_name ItemPool extends Resource

@export var items : Array[ItemType]
@export var weights : Array[float]

func get_item() -> ItemType:
	if items.size() != weights.size():
		return items.pick_random().duplicate()
	
	#todo add simple weighted sampling
	return items[0].duplicate();
