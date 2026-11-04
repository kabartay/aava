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

## How far an action must be pushed before it counts, as a share of its range.
## The touch stick has a dead zone of its own (the HUD sets 0.12), so a second
## one of 0.2 on top of it made the first third of the stick do almost nothing:
## a three-year-old's small push at 0.3 of the way out walked at 0.21 m/s. The
## keys are all or nothing, so they do not care.
const DEADZONE := 0.05

static func register() -> void:
	for action in KEYS:
		if InputMap.has_action(action):
			InputMap.action_set_deadzone(action, DEADZONE)
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, DEADZONE)
		for keycode in KEYS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action, event)
