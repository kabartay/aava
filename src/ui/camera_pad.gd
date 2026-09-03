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

var _active_index := -1

func _init() -> void:
	# set_anchors_preset alone leaves a code-created Control at zero size, which
	# is the most common silent failure in an editor-less project: the node is
	# there, the input never arrives, and nothing warns you.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _active_index < 0:
			_active_index = event.index
		elif not event.pressed and event.index == _active_index:
			_active_index = -1
		accept_event()
	elif event is InputEventScreenDrag and event.index == _active_index:
		# screen_relative, not relative: inside _gui_input the latter is scaled
		# by the stretch transform, so camera speed would change with resolution.
		dragged.emit(event.screen_relative)
		accept_event()
