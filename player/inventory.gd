class_name Inventory extends Node

const MAX_ITEM_COUNT : int = 2 

var items : Array[ItemType]
@export var item_slots : Array[TextureRect]

func _update_visual_item_slots() -> void:
	for slot_index in range(item_slots.size()):
		if slot_index >= items.size():
			item_slots[slot_index].texture = null
		else:
			item_slots[slot_index].texture = items[slot_index].sprite

func _ready() -> void:
	_update_visual_item_slots()

func add_item(item : ItemType) -> bool:
	if items.size() > MAX_ITEM_COUNT:
		return false
		
	items.append(item)
	_update_visual_item_slots()
	return true
	
func use_item(player : Player) -> bool:
	#use item if in slot
	if items.size() <= 0:
		return false
	
	var item : ItemType = items.pop_front()
	item.use(player)
	_update_visual_item_slots()
		
	return true
	
