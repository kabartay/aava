class_name InputActions
extends RefCounted

## Input actions, registered in code.
##
## They live here rather than in project.godot because Godot's native
## VirtualJoystick drives InputMap *actions* — it calls Input.action_press() and
## has no vector getter — so the actions must exist before any UI is built. And
## because hand-authoring InputEvent objects into project.godot's text format is
## exactly the kind of silent misconfiguration this project cannot see.

const MOVE_LEFT := &"move_left"
const MOVE_RIGHT := &"move_right"
const MOVE_FORWARD := &"move_forward"
const MOVE_BACK := &"move_back"
const SPRINT := &"sprint"
const JUMP := &"jump"
const KICK := &"kick"

## Keyboard bindings exist for one reason: this game is developed on a desktop
## and played on a tablet, and the desktop has to be able to drive it.
const KEYS := {
	MOVE_LEFT: [KEY_A, KEY_LEFT],
	MOVE_RIGHT: [KEY_D, KEY_RIGHT],
	MOVE_FORWARD: [KEY_W, KEY_UP],
	MOVE_BACK: [KEY_S, KEY_DOWN],
	SPRINT: [KEY_SHIFT],
	JUMP: [KEY_SPACE],
	KICK: [KEY_E, KEY_ENTER],
}

static func register() -> void:
	for action in KEYS:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, 0.2)
		for keycode in KEYS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action, event)
