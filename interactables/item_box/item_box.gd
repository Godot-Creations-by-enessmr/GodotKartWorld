extends Node3D

@export var active : bool = true;
@onready var box_mesh : MeshInstance3D = $VisualParent/Visual/Box
@onready var visual_item_box : Node3D = $VisualParent/Visual
@onready var light : OmniLight3D = $OmniLight3D
@export var item_pool : ItemPool
var color : Color;

@onready var light_radius = light.omni_range;

func activate() -> void:
	active = true;
	visual_item_box.visible = true
	light.omni_range = light_radius

func deactivate() -> void:
	active = false;
	visual_item_box.visible = false
	light.omni_range = 0

func add_item_to_player(player : Player) -> void:	
	player.add_item(item_pool.get_item());
	
	deactivate()
	await get_tree().create_timer(1).timeout
	activate()


func _ready() -> void:
	pass # Replace with function body.


func _process(delta: float) -> void:
	var time : float = Time.get_ticks_msec() * 0.001;
	# vertical bobbing + rotation
	visual_item_box.position.y = 0.5 * sin(2 * PI * 0.5 * time);
	
	var rot_x := Quaternion(Vector3.RIGHT, time * 1.2)
	var rot_y := Quaternion(Vector3.UP, time * 0.8)
	var rot_z := Quaternion(Vector3.FORWARD, time * 1.5)
	visual_item_box.basis = Basis(rot_x * rot_y * rot_z)
	
	# cycle through the color for the light and the shader
	color = Color.from_hsv(time * 0.5, 0.8, 1.0);	
	light.light_color = color;
	box_mesh.set_instance_shader_parameter("box_color", Vector3(color.r, color.g, color.b));


func _on_area_3d_body_entered(body: Node3D) -> void:
	var parent = body.get_parent()
	if active and parent is Player:
		add_item_to_player(parent)
