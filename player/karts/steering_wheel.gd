extends MeshInstance3D

@export var character : Node3D
@onready var left_hand_grip : Node3D = $LeftHandGrip
@onready var right_hand_grip : Node3D = $RightHandGrip


func _ready() -> void:
	character.IKTargetLeftArm.reparent(left_hand_grip)
	character.IKTargetLeftArm.position = Vector3.ZERO
	
	character.IKTargetRightArm.reparent(right_hand_grip)
	character.IKTargetRightArm.position = Vector3.ZERO
