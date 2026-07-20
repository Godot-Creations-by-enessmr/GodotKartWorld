extends Node3D

## Emitted when Gobot's feet hit the ground will running.
@warning_ignore("unused_signal")
signal foot_step
## Gobot's MeshInstance3D model.
@export var gobot_model: MeshInstance3D
## Determines whether blinking is enabled or disabled.
@export var _left_eye_mat_override: String
@export var _right_eye_mat_override: String
@export var _open_eye: CompressedTexture2D
@export var _close_eye: CompressedTexture2D

@onready var _animation_tree: AnimationTree = %AnimationTree
@onready var _state_machine: AnimationNodeStateMachinePlayback = _animation_tree.get(
		"parameters/StateMachine/playback"
)

@onready var _flip_shot_path: String = "parameters/FlipShot/request"
@onready var _hurt_shot_path: String = "parameters/HurtShot/request"

@onready var _blink_timer = %BlinkTimer
@onready var _closed_eyes_timer = %ClosedEyesTimer

@export var IKTargetLeftArm : Node3D
@export var IKTargetRightArm : Node3D


func _ready():
	pass

## Sets the model to a neutral, action-free state.
func idle():
	_state_machine.travel("Idle")
	
## Sets the model to a running animation or forward movement.
func run():
	_state_machine.travel("Run")

## Sets the model to an upward-leaping animation, simulating a jump.
func jump():
	_state_machine.travel("Jump")

## Sets the model to a downward animation, imitating a fall.
func fall():
	_state_machine.travel("Fall")

## Sets the model to an edge-grabbing animation.
func edge_grab():
	_state_machine.travel("EdgeGrab")

## Sets the model to a wall-sliding animation.
func wall_slide():
	_state_machine.travel("WallSlide")

## Plays a one-shot front-flip animation.
## This animation does not play in parallel with other states.
func flip():
	_animation_tree.set(_flip_shot_path, true)

## Makes a victory sign.
func victory_sign():
	_state_machine.travel("VictorySign")

## Plays a one-shot hurt animation.
## This animation plays in parallel with other states.
func hurt():
	_animation_tree.set(_hurt_shot_path, true)
	var tween := create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3(1.2, 0.8, 1.2), 0.1)
	tween.tween_property(self, "scale", Vector3.ONE, 0.2)
