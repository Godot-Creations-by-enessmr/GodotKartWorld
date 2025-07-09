@tool
extends Node3D


@export var duration : float = 5.0

@export_tool_button("Play Particles")
var play_button := func (): _play()

func _play() -> void:
	for child in get_children():
		if child is GPUParticles3D:
			child.restart()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_play()
			
	if duration > 0.0:
		await get_tree().create_timer(duration).timeout
		queue_free()
