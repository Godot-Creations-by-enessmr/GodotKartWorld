extends BuoyantBody3D

@export var explosion_delay := 5.0
@export var explosion_effect : PackedScene
@onready var bouyancy_sensor : WaterBuoyancySensor = $WaterBuoyancySensor


func _ready() -> void:		
	
	super._ready()
	await get_tree().create_timer(explosion_delay).timeout
	_explode()

func _explode() -> void:
	var effect = explosion_effect.instantiate() as Node3D
	get_tree().root.add_child(effect)
	effect.global_position = global_position
	queue_free()

	if bouyancy_sensor.is_in_water() and bouyancy_sensor.ocean_node:
		bouyancy_sensor.ocean_node.add_wave(global_position, 0.5, 24)
