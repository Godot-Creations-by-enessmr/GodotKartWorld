extends Node3D

@export var anim: AnimationPlayer
@export var follow_speed : float = 10.0  # How fast it follows
@export var smooth_follow : bool = true  # If false, teleports directly

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	anim.play("rotation")
	
	# Find the player by group
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if smooth_follow:
			# Smooth follow with lerp
			global_position = global_position.lerp(player.global_position, follow_speed * delta)
		else:
			# Direct follow (teleport)
			global_position = player.global_position
