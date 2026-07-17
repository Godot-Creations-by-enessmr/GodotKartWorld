class_name Inventory extends Node

const MAX_ITEM_COUNT : int = 2 

var items : Array[ItemType]
@export var item_slots : Array[TextureRect]
@onready var inventory_control : Control = $GraphicalInventory

func _update_visual_item_slots() -> void:
	var item_count = items.size()
	inventory_control.visible = item_count > 0
	
	for slot_index in range(item_slots.size()):
		if slot_index >= item_count:
			item_slots[slot_index].texture = null
		else:
			item_slots[slot_index].texture = items[slot_index].sprite

func _ready() -> void:
	_update_visual_item_slots()

func _get_roll_animation_name(item : ItemType) -> String:
	if item == null:
		return ""
	
	var base_name := item.name.to_lower().replace(" ", "_").replace("-", "_")
	return base_name + "_roll"

func _trigger_roll_animation(item : ItemType, player : Player) -> void:
	if item == null or player == null:
		return
	
	# Pass the ItemType directly, NOT a string
	if player.kart and player.kart.has_method("play_item_roll_animation"):
		player.kart.play_item_roll_animation(item)  # Pass item, not animation_name
		return
	
	# Fallback: convert to animation name and play directly
	var animation_name := _get_roll_animation_name(item)
	if animation_name.is_empty():
		return
	
	if player.kart and player.kart.animation_player and player.kart.animation_player.has_animation(animation_name):
		player.kart.animation_player.play(animation_name)

func add_item(item : ItemType) -> bool:
	if items.size() >= MAX_ITEM_COUNT:
		return false
		
	items.append(item)
	_update_visual_item_slots()
	return true
	
func use_item(player : Player) -> bool:
	if items.size() <= 0:
		return false
	
	var item : ItemType = items.pop_front()
	_trigger_roll_animation(item, player)
	item.use(player)
	_update_visual_item_slots()
		
	return true
