class_name Wheel extends VehicleWheel3D

@onready var wheel_visual : Node3D = $WheelVisual
var compression : float
var previous_compression: float = 0.0
var compression_velocity: float = 0.0

	
