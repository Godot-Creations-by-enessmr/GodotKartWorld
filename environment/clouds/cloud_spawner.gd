extends Node3D

@export var cloud_count := 20
@export var cloud_scene : PackedScene

@onready var box : CSGBox3D = $"CSGBox3D"
@onready var rng = RandomNumberGenerator.new()

func _ready():
	spawn_clouds()
	
	
func spawn_clouds():
	for i in range(cloud_count):
		var spawn_pos =\
			 Vector3(rng.randf() * box.size.x, rng.randf() * box.size.y, rng.randf() * box.size.z)
		spawn_pos -= box.size / 2
		
		var c = cloud_scene.instantiate()
		add_child(c)
		c.global_position = spawn_pos + global_position
