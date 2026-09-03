class_name Hud
extends CanvasLayer

## On-screen controls.
##
## Two touch targets and nothing else. Every pixel of interface is a pixel of
## world a child is not looking at, so anything that is not needed to move and
## look is not here.

## Diameter of the thumbstick. Deliberately large: a six-year-old's thumb is
## imprecise and the stick has to be findable without looking down at it.
const STICK_SIZE := 250.0

signal camera_dragged(delta: Vector2)

var _stick: VirtualJoystick

func _ready() -> void:
	var pad := CameraPad.new()
	pad.name = "CameraPad"
	pad.dragged.connect(func(delta: Vector2) -> void: camera_dragged.emit(delta))
	add_child(pad)

	# Godot 4.7 ships this node; writing one by hand is both unnecessary and,
	# since the class name is now taken, actively broken.
	_stick = VirtualJoystick.new()
	_stick.name = "MoveStick"
	_stick.joystick_mode = VirtualJoystick.JOYSTICK_DYNAMIC
	_stick.joystick_size = STICK_SIZE
	_stick.tip_size = STICK_SIZE * 0.42
	_stick.deadzone_ratio = 0.12
	_stick.action_left = InputActions.MOVE_LEFT
	_stick.action_right = InputActions.MOVE_RIGHT
	_stick.action_up = InputActions.MOVE_FORWARD
	_stick.action_down = InputActions.MOVE_BACK
	add_child(_stick)

	_layout()
	get_viewport().size_changed.connect(_layout)

## The stick lives in the lower-left corner, inside the safe area so a notch or
## a rounded corner never swallows half of it.
func _layout() -> void:
	var viewport := get_viewport().get_visible_rect().size
	var safe := _safe_area()
	var margin := 26.0
	var side := STICK_SIZE * 1.25

	_stick.size = Vector2(side, side)
	_stick.position = Vector2(
		safe.position.x + margin,
		safe.position.y + safe.size.y - side - margin
	)
	_stick.position.y = minf(_stick.position.y, viewport.y - side - margin)

## The safe area comes back in physical screen pixels, so it has to be pulled
## through the stretch transform to mean anything in the coordinates the HUD
## actually uses.
func _safe_area() -> Rect2:
	var raw := DisplayServer.get_display_safe_area()
	var transform := get_viewport().get_stretch_transform().affine_inverse()
	var top_left := transform * Vector2(raw.position)
	var bottom_right := transform * Vector2(raw.position + raw.size)
	var area := Rect2(top_left, bottom_right - top_left)
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	return area
