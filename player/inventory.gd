class_name Inventory extends Node

const MAX_ITEM_COUNT : int = 2 

var items : Array[ItemType]
@export var item_slots : Array[Control]


func add_item(item : ItemType) -> bool:
	if items.size() > MAX_ITEM_COUNT:
		return false
		
	items.append(item)	
	return true
	
func use_item(player : Player) -> bool:
	#use item if in slot
	if items.size() <= 0:
		return false
	
	var item : ItemType = items.pop_front()
	item.use(player)
		
	return true
	
