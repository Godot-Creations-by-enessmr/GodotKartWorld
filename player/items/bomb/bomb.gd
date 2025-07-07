extends BuoyantBody3D

@export var explosion_delay := 5.0


func _ready() -> void:
	super._ready()
	await get_tree().create_timer(explosion_delay).timeout
	_explode()

func _explode() -> void:
	queue_free()
	
	var ocean_node : Ocean = get_tree().get_first_node_in_group("ocean")
	if ocean_node: 
		ocean_node.add_wave(global_position, 0.5, 24)
