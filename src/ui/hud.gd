class_name Hud
extends CanvasLayer

## On-screen controls.
##
## Every pixel of interface is a pixel of world a child is not looking at, so
## what is here is only what is needed to move, look, gather and build. There
## are no menus, no numbers that are not a count of something you are carrying,
## and no text a six-year-old has to read to play: the item icons are shapes and
## the build palette is shapes.

## Diameter of the thumbstick. Deliberately large: a small thumb is imprecise
## and the stick has to be findable without looking down at it.
const STICK_SIZE := 250.0
const BUTTON := 96.0
const MARGIN := 26.0

signal camera_dragged(delta: Vector2)
signal build_toggled(enabled: bool)
signal build_selected(kind: StringName)
signal build_place()

var _stick: VirtualJoystick
var _items: HBoxContainer
var _item_labels: Dictionary = {}
var _build_button: Button
var _palette: HBoxContainer
var _palette_buttons: Dictionary = {}
var _place_button: Button
var _status: Label
var _message: Label
var _message_timer := 0.0
var _building := false

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

	_items = _build_item_strip()
	add_child(_items)

	_palette = _build_palette()
	add_child(_palette)

	_status = _label(22, Color(1.0, 0.86, 0.55))
	add_child(_status)

	_message = _label(30, Color(1.0, 1.0, 1.0))
	_message.modulate.a = 0.0
	add_child(_message)

	_build_button = _button("build", Color(0.42, 0.72, 0.98))
	_build_button.pressed.connect(_on_build_pressed)
	add_child(_build_button)

	_place_button = _button("+", Color(0.48, 0.88, 0.52))
	_place_button.pressed.connect(func() -> void: build_place.emit())
	_place_button.visible = false
	add_child(_place_button)

	_layout()
	get_viewport().size_changed.connect(_layout)

func _build_item_strip() -> HBoxContainer:
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 18)
	for kind in ItemKinds.ALL:
		var entry := Label.new()
		entry.text = "%s 0" % ItemKinds.icon(kind)
		entry.add_theme_font_size_override("font_size", 30)
		entry.add_theme_color_override("font_color", ItemKinds.color(kind))
		entry.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
		entry.add_theme_constant_override("outline_size", 6)
		# Hidden until the player has one. An empty row of zeroes tells a child
		# nothing except that there is a lot he does not have.
		entry.visible = false
		strip.add_child(entry)
		_item_labels[kind] = entry
	return strip

func _build_palette() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.visible = false
	for kind in BuildKinds.ALL:
		var button := _button(BuildKinds.icon(kind), Color(0.86, 0.86, 0.90))
		button.pressed.connect(func() -> void: build_selected.emit(kind))
		row.add_child(button)
		_palette_buttons[kind] = button
	return row

func _button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(BUTTON, BUTTON)
	button.add_theme_font_size_override("font_size", 34)
	button.add_theme_color_override("font_color", color)
	button.focus_mode = Control.FOCUS_NONE
	return button

func _label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.75))
	label.add_theme_constant_override("outline_size", 7)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func _on_build_pressed() -> void:
	set_building(not _building)

## Enter or leave build mode. Public because the button is not the only thing
## that needs to drive it: the screenshot tool opens build mode too, and a tool
## that reaches into a private method is a tool that breaks silently when the
## method is renamed.
func set_building(enabled: bool) -> void:
	if enabled == _building:
		return
	_building = enabled
	_palette.visible = enabled
	_place_button.visible = enabled
	_build_button.text = "x" if enabled else "build"
	_status.text = ""
	build_toggled.emit(enabled)
	_layout()

## The count of one item changed.
func set_item_count(kind: StringName, total: int) -> void:
	var entry: Label = _item_labels.get(kind)
	if entry == null:
		return
	entry.text = "%s %d" % [ItemKinds.icon(kind), total]
	entry.visible = total > 0

## Which piece is selected, whether it can go where it is aimed, and why not.
func set_build_state(kind: StringName, valid: bool, reason: String) -> void:
	for other in _palette_buttons:
		var button: Button = _palette_buttons[other]
		button.modulate = Color.WHITE if other == kind else Color(1.0, 1.0, 1.0, 0.45)
	_place_button.disabled = not valid
	_place_button.modulate = Color.WHITE if valid else Color(1.0, 1.0, 1.0, 0.4)
	_status.text = BuildKinds.label(kind) if valid else "%s — %s" % [BuildKinds.label(kind), reason]
	_layout()

## A short, centred announcement. Used for the things the world does in reply.
func announce(text: String, seconds := 3.2) -> void:
	_message.text = text
	_message_timer = seconds
	_layout()

func _process(delta: float) -> void:
	if _message_timer <= 0.0:
		return
	_message_timer -= delta
	# Fade out over the last second rather than vanishing, so a child who looked
	# away still catches that something happened.
	_message.modulate.a = clampf(_message_timer, 0.0, 1.0)

## Everything is positioned in code against the safe area, so a notch or a
## rounded corner never swallows a control.
func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var safe := _safe_area()
	var side := STICK_SIZE * 1.25

	_stick.size = Vector2(side, side)
	_stick.position = Vector2(
		safe.position.x + MARGIN,
		minf(safe.position.y + safe.size.y - side - MARGIN, view.y - side - MARGIN)
	)

	_items.position = Vector2(safe.position.x + MARGIN, safe.position.y + MARGIN)

	_build_button.position = Vector2(
		safe.position.x + safe.size.x - BUTTON - MARGIN,
		safe.position.y + safe.size.y - BUTTON - MARGIN
	)

	_place_button.position = _build_button.position - Vector2(0.0, BUTTON + 16.0)

	var palette_width := float(BuildKinds.ALL.size()) * (BUTTON + 12.0)
	_palette.position = Vector2(
		safe.position.x + safe.size.x * 0.5 - palette_width * 0.5,
		safe.position.y + safe.size.y - BUTTON - MARGIN
	)

	_status.size.x = view.x
	_status.position = Vector2(0.0, _palette.position.y - 46.0)

	_message.size.x = view.x
	_message.position = Vector2(0.0, safe.position.y + safe.size.y * 0.26)

## The safe area arrives in physical screen pixels, so it has to be pulled
## through the stretch transform to mean anything in the HUD's coordinates —
## and then clipped to the viewport.
##
## The clipping is not defensive tidiness. The display's safe area describes the
## whole screen, which on a windowed desktop is larger than the window and on a
## device may not line up with it either; used unclipped, every control is
## positioned relative to a rectangle bigger than the one being drawn, and the
## entire interface sits just off the edge of the screen. It disappears in
## silence, which is the worst way for a control to fail.
func _safe_area() -> Rect2:
	var viewport := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var raw := DisplayServer.get_display_safe_area()
	if raw.size.x <= 0 or raw.size.y <= 0:
		return viewport

	var transform := get_viewport().get_stretch_transform().affine_inverse()
	var top_left := transform * Vector2(raw.position)
	var bottom_right := transform * Vector2(raw.position + raw.size)
	var area := Rect2(top_left, bottom_right - top_left).intersection(viewport)

	# Anything smaller than a usable strip means the two rectangles do not
	# describe the same thing, so trust the one that is definitely being drawn.
	if area.size.x < 240.0 or area.size.y < 200.0:
		return viewport
	return area
