class_name WaterBuoyancySensor extends Marker3D

@export var height: float = 1.0
@export var buoyancy_multiplier: float = 1.0

var ocean_node : Ocean

func _ready() -> void:
	if !ocean_node:
		ocean_node = get_tree().get_first_node_in_group("ocean")

var water_height: float = 0.0
var water_normal: Vector3 = Vector3.UP
var water_force: Vector3 = Vector3.ZERO


func is_in_water() -> bool:
	return water_height >= global_position.y    

func is_under_water() -> bool:
	return water_height >= global_position.y + height

func is_on_water() -> bool:
	return is_in_water() and not is_under_water()


func get_water_height() -> float:
	return water_height
	
func get_water_depth() -> float:
	return global_position.y - water_height 

func _physics_process(_delta: float) -> void:
	if ocean_node:
		water_height = ocean_node.get_wave_height(global_position, 3, 5)
		
func compute_normal() -> Vector3:
	if ocean_node:
		var offset = 0.1
		var dx = (ocean_node.get_wave_height(global_position + Vector3(offset,0,0), 3, 5) - water_height) / offset;
		var dz = (ocean_node.get_wave_height(global_position + Vector3(0,0,offset), 3, 5) - water_height) / offset;
		return Vector3(-dx, 1.0, -dz).normalized();
		
	else: 
		return Vector3(0, 1, 0)
