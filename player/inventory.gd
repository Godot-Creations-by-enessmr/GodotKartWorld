class_name Inventory extends Node

const MAX_ITEM_COUNT : int = 2

var items : Array[ItemType]
var is_roll_animation_active : bool = false
var queued_item : ItemType
var queued_player : Player
var queued_animation_name : StringName = &""
var active_animation_player : AnimationPlayer

@export var item_slots : Array[TextureRect]
@onready var inventory_control : Control = $GraphicalInventory

func _update_visual_item_slots() -> void:
	var item_count = items.size()

	# Show/hide the inventory UI
	if inventory_control:
		inventory_control.visible = item_count > 0

	# Update each slot
	for slot_index in range(item_slots.size()):
		if slot_index < item_count and items[slot_index]:
			# Show the item sprite
			item_slots[slot_index].texture = items[slot_index].sprite
			item_slots[slot_index].visible = true
		else:
			# Clear the slot
			item_slots[slot_index].texture = null
			item_slots[slot_index].visible = false

func _ready() -> void:
	_update_visual_item_slots()

func _get_roll_animation_name(item : ItemType) -> StringName:
	if item == null:
		return &""

	var base_name := item.name.to_lower().replace(" ", "_").replace("-", "_")
	return StringName(base_name + "_roll")

func _trigger_roll_animation(item : ItemType, player : Player) -> StringName:
	if item == null or player == null:
		return &""

	# Pass the ItemType directly to the kart
	if player.kart and player.kart.has_method("play_item_roll_animation"):
		var animation_name := player.kart.play_item_roll_animation(item)
		if animation_name != &"":
			return animation_name

	# Fallback: play directly on animation player
	var fallback_animation_name := _get_roll_animation_name(item)
	if fallback_animation_name != &"" and player.kart and player.kart.animation_player and player.kart.animation_player.has_animation(fallback_animation_name):
		player.kart.animation_player.play(fallback_animation_name)
		return fallback_animation_name

	return &""

func _queue_item_use(item : ItemType, player : Player, animation_name : StringName) -> void:
	if item == null or player == null:
		return

	if active_animation_player and active_animation_player.is_connected("animation_finished", Callable(self, "_on_roll_animation_finished")):
		active_animation_player.animation_finished.disconnect(_on_roll_animation_finished)

	queued_item = item
	queued_player = player
	queued_animation_name = animation_name
	is_roll_animation_active = true

	if player.kart and player.kart.animation_player:
		active_animation_player = player.kart.animation_player
		active_animation_player.animation_finished.connect(_on_roll_animation_finished)
	else:
		active_animation_player = null
		_finalize_item_use()

func _on_roll_animation_finished(_anim_name : StringName) -> void:
	if not is_roll_animation_active:
		return

	var item := queued_item
	var player := queued_player
	queued_item = null
	queued_player = null
	queued_animation_name = &""
	is_roll_animation_active = false

	if active_animation_player and active_animation_player.is_connected("animation_finished", Callable(self, "_on_roll_animation_finished")):
		active_animation_player.animation_finished.disconnect(_on_roll_animation_finished)

	active_animation_player = null

	if item != null and player != null:
		item.use(player)

func _finalize_item_use() -> void:
	if queued_item != null and queued_player != null:
		var item := queued_item
		var player := queued_player
		queued_item = null
		queued_player = null
		queued_animation_name = &""
		is_roll_animation_active = false
		item.use(player)

func add_item(item : ItemType) -> bool:
	if items.size() >= MAX_ITEM_COUNT:
		return false

	items.append(item)
	_update_visual_item_slots()
	return true

func use_item(player : Player) -> bool:
	if is_roll_animation_active:
		return false

	if items.size() <= 0:
		return false

	var item : ItemType = items.pop_front()
	_update_visual_item_slots()

	var animation_name := _trigger_roll_animation(item, player)
	if animation_name != &"":
		_queue_item_use(item, player, animation_name)
	else:
		item.use(player)

	return true
