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

var _active_index := -1

## Every finger currently down on this pad, by index. A pinch needs two, and the
## viewport routes each finger back to the control it landed on, so tracking
## them here is enough — no global input state.
var _fingers: Dictionary = {}
var _pinch_gap := -1.0

func _init() -> void:
	# set_anchors_preset alone leaves a code-created Control at zero size, which
	# is the most common silent failure in an editor-less project: the node is
	# there, the input never arrives, and nothing warns you.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_fingers[event.index] = event.position
			if _active_index < 0:
				_active_index = event.index
		else:
			_fingers.erase(event.index)
			if event.index == _active_index:
				_active_index = -1
			# A pinch ends the moment either finger lifts, so the next one
			# starts from a fresh gap instead of jumping.
			_pinch_gap = -1.0
		accept_event()
		return

	if event is InputEventScreenDrag:
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
