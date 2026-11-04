class_name MapGesture
extends RefCounted

## Reads touches, the mouse and trackpad gestures on the map and says what they
## mean: `moved` (a drag, a pinch or a wheel turn, as a MapView.grab) or `tapped`.
##
## A tap is decided when the finger lifts, and only if it never travelled past
## TAP_SLOP and never had company: a drag or a pinch is not a tap, so panning the
## map never cycles its size. Positions are in the picture's own pixels.

## Emitted for every step of a drag, pinch or wheel turn.
signal moved(from: Vector2, to: Vector2, factor: float)
## Emitted when a single finger (or the left mouse button) goes down and up in
## place, with where it was, in the picture's own pixels.
signal tapped(at: Vector2)

## How far a finger may wander and still be a tap, in pixels of the 1280-wide
## layout: a child's thumb rolls about this much when pressing.
const TAP_SLOP := 14.0
## One notch of a mouse wheel changes the range by this factor.
const WHEEL_STEP := 1.18
const MOUSE_ID := 100

var _points: Dictionary = {}
var _starts: Dictionary = {}
var _tap_possible := false

## Whether anything is held down. After the map closes this must be false again.
func is_active() -> bool:
	return not _points.is_empty()

## Forget everything held: the map closed or changed under the fingers.
func cancel() -> void:
	_points.clear()
	_starts.clear()
	_tap_possible = false

## Feed one event; `origin` is the picture's top-left in the event's coordinates.
## Returns whether the map took it.
func feed(event: InputEvent, origin: Vector2) -> bool:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		_button(touch.index, touch.pressed, touch.position - origin)
		return true
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_move(drag.index, drag.position - origin)
		return true
	# The mouse events that Godot makes out of a touch are the same finger again.
	if event is InputEventMouse and (event as InputEventMouse).device == InputEvent.DEVICE_ID_EMULATION:
		return true
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		var at := click.position - origin
		if click.button_index == MOUSE_BUTTON_LEFT:
			_button(MOUSE_ID, click.pressed, at)
			return true
		if click.pressed and (
			click.button_index == MOUSE_BUTTON_WHEEL_UP
			or click.button_index == MOUSE_BUTTON_WHEEL_DOWN
		):
			var notches := click.factor if click.factor > 0.0 else 1.0
			var factor := pow(WHEEL_STEP, notches)
			if click.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				factor = 1.0 / factor
			moved.emit(at, at, factor)
			return true
		return false
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _points.has(MOUSE_ID) and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_move(MOUSE_ID, motion.position - origin)
			return true
		return false
	if event is InputEventMagnifyGesture:
		var magnify := event as InputEventMagnifyGesture
		var where := magnify.position - origin
		moved.emit(where, where, magnify.factor)
		return true
	return false

func _button(id: int, down: bool, at: Vector2) -> void:
	if down:
		# The same finger going down again means its release was lost (the app
		# was put away under it). Left in the table it made the next lone finger
		# half a pinch, so the map zoomed instead of panning.
		if _points.has(id):
			_points.erase(id)
			_starts.erase(id)
		_points[id] = at
		_starts[id] = at
		_tap_possible = _points.size() == 1
		return
	if not _points.has(id):
		return
	var was_tap := _tap_possible and _points.size() == 1
	var start: Vector2 = _starts[id]
	_points.erase(id)
	_starts.erase(id)
	if _points.is_empty():
		_tap_possible = false
	if was_tap:
		tapped.emit(start)

func _move(id: int, at: Vector2) -> void:
	if not _points.has(id):
		return
	var before: Vector2 = _points[id]
	if _points.size() == 1:
		if _tap_possible:
			var start: Vector2 = _starts[id]
			if at.distance_to(start) <= TAP_SLOP:
				return
			_tap_possible = false
		_points[id] = at
		moved.emit(before, at, 1.0)
		return
	_tap_possible = false
	# Two or more: the pinch is between the two lowest ids, and any others are
	# ignored until they lift.
	var ids: Array = _points.keys()
	ids.sort()
	var pair: Array = ids.slice(0, 2)
	if not pair.has(id):
		_points[id] = at
		return
	var other_id: int = pair[1] if pair[0] == id else pair[0]
	var other: Vector2 = _points[other_id]
	var old_gap := before.distance_to(other)
	var new_gap := at.distance_to(other)
	var factor := new_gap / old_gap if old_gap > 1.0 and new_gap > 1.0 else 1.0
	_points[id] = at
	moved.emit((before + other) * 0.5, (at + other) * 0.5, factor)
