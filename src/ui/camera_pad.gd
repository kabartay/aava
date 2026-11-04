class_name CameraPad
extends Control

## The whole screen, listening for a finger that wants to look around.
##
## Input is handled in _gui_input rather than _unhandled_input for a specific
## reason: the Viewport records which Control a finger landed on and keeps
## routing that finger's drags there even after it leaves the rectangle, so the
## look-around finger and the movement finger never fight over each other. That
## capture is what makes multitouch work with no index bookkeeping of our own.
##
## This pad sits first among the HUD's children, because children are hit-tested
## last-to-first: anything added after it — the thumbstick — is on top and eats
## its own touches before they reach here.

signal dragged(delta: Vector2)

## Positive pinches in, negative spreads out. Emitted in pixels of change in the
## gap between two fingers, so the rig can scale it however it likes.
signal pinched(amount: float)

## Mouse wheel, in notches. Separate from the pinch because the two have
## completely different units and pretending otherwise makes one of them wrong.
signal wheeled(notches: float)

## A tap on the world: pressed and released without dragging.
##
## While building, the player is looking at the ghost, so this is where a tap
## belongs. Making him look away to a button in the corner to confirm what he is
## already looking at is one step too many — and it is the step a six-year-old
## forgets every time.
signal tapped()

var _active_index := -1

## Every finger currently down on this pad, by index. A pinch needs two, and the
## viewport routes each finger back to the control it landed on, so tracking
## them here is enough — no global input state.
var _fingers: Dictionary = {}
var _pinch_gap := -1.0

## Whether a second finger has joined since the pad was last empty. The gap
## alone cannot say so: it resets when either finger lifts, so lifting the
## second finger first and the first one after looked like a plain tap, and
## ended every pinch while building by placing a piece.
var _was_pinching := false

## How far a finger may travel and still count as a tap rather than a drag.
## Generous, because a child's finger always moves a little.
const TAP_SLOP := 26.0

var _press_at := Vector2.ZERO
var _travelled := 0.0

func _init() -> void:
	# set_anchors_preset alone leaves a code-created Control at zero size, which
	# is the most common silent failure in an editor-less project: the node is
	# there, the input never arrives, and nothing warns you.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

## Forget every finger. For when releases will never arrive: the app was put
## away, a call came in, the window lost focus. A finger left in the table made
## the next single finger the second of a pinch, so the view zoomed instead of
## turning, and a stale look finger refused every new one.
func release_all() -> void:
	_fingers.clear()
	_active_index = -1
	_pinch_gap = -1.0
	_was_pinching = false
	_travelled = 0.0

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			# The same index going down again means its release was lost. It is
			# a new finger, not a second one, and not the look finger it was.
			if _fingers.has(event.index):
				_fingers.erase(event.index)
				if event.index == _active_index:
					_active_index = -1
				if _fingers.is_empty():
					_was_pinching = false
			_fingers[event.index] = event.position
			if _fingers.size() >= 2:
				_was_pinching = true
			if _active_index < 0:
				_active_index = event.index
				_press_at = event.position
				_travelled = 0.0
		else:
			_fingers.erase(event.index)
			if event.index == _active_index:
				# A single finger that went down and came up without going
				# anywhere is a tap, not a look-around.
				#
				# Not one the system took away. Android cancels a finger when
				# a gesture such as the swipe up from the bottom edge claims
				# it, and that arrives as a release too — which, being short,
				# counted as a tap and put a piece down while building.
				if _travelled <= TAP_SLOP and not _was_pinching and not event.canceled:
					tapped.emit()
				_active_index = -1
				# A finger still down after the first one lifted — the look
				# finger of a pinch — carries on turning the view. It was
				# ignored until it was lifted and put down again, which to a
				# child is the camera freezing. Not a tap when it lifts: it
				# has been down a while and is not where it started.
				for remaining: int in _fingers:
					_active_index = remaining
					_press_at = _fingers[remaining]
					_travelled = TAP_SLOP + 1.0
					break
			# A pinch ends the moment either finger lifts, so the next one
			# starts from a fresh gap instead of jumping.
			_pinch_gap = -1.0
			if _fingers.is_empty():
				_was_pinching = false
		accept_event()
		return

	if event is InputEventScreenDrag:
		# A finger this pad never saw go down (its press came before a release_all)
		# is not counted: a stray one would make the next finger half a pinch.
		if not _fingers.has(event.index):
			accept_event()
			return
		_fingers[event.index] = event.position

		# Two fingers down means the player is sizing the view, not turning it.
		# Turning is suppressed entirely while pinching, because a pinch always
		# carries some rotation and the camera would spin as it zoomed.
		if _fingers.size() >= 2:
			var points := _fingers.values()
			var gap: float = (points[0] as Vector2).distance_to(points[1] as Vector2)
			if _pinch_gap >= 0.0:
				pinched.emit(gap - _pinch_gap)
			_pinch_gap = gap
			accept_event()
			return

		if event.index == _active_index:
			_travelled += event.screen_relative.length()
			# screen_relative, not relative: inside _gui_input the latter is
			# scaled by the stretch transform, so camera speed would change
			# with resolution.
			dragged.emit(event.screen_relative)
		accept_event()
		return

	# The desktop equivalent, so the game can be developed and played with a
	# mouse without a second code path.
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			wheeled.emit(1.0)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			wheeled.emit(-1.0)
			accept_event()
