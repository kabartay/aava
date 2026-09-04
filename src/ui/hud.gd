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
signal camera_zoomed(amount: float)
## Press and release, not a single tap: the strength of a kick is how long the
## button is held, so the interface has to report both ends of it.
signal kick_started()
signal kick_released()
signal jump_pressed()
signal build_toggled(enabled: bool)
signal build_selected(kind: StringName)
signal build_place()
signal build_remove()
signal build_tab(house: bool)

var _stick: VirtualJoystick
var _backpack: Backpack
var _build_button: Button
var _palette: HBoxContainer
var _palette_buttons: Dictionary = {}
var _tabs: HBoxContainer
var _place_button: Button
var _remove_button: Button
var _showing_house := false
var _status: Label
var _message: Label
var _message_timer := 0.0
var _building := false
var _kick_button: Button
var _score: Label
var _jump_button: Button
var _power_bar: ColorRect
var _power_fill: ColorRect
var _aim_label: Label

func _ready() -> void:
	var pad := CameraPad.new()
	pad.name = "CameraPad"
	pad.dragged.connect(func(delta: Vector2) -> void: camera_dragged.emit(delta))
	pad.pinched.connect(func(amount: float) -> void:
		camera_zoomed.emit(amount * CameraRig.ZOOM_PER_PIXEL))
	pad.wheeled.connect(func(notches: float) -> void:
		camera_zoomed.emit(notches * CameraRig.ZOOM_PER_NOTCH))
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

	_backpack = Backpack.new()
	add_child(_backpack)

	_palette = _build_palette()
	add_child(_palette)

	_tabs = _build_tabs()
	add_child(_tabs)

	_status = _label(22, Color(1.0, 0.86, 0.55))
	add_child(_status)

	_message = _label(30, Color(1.0, 1.0, 1.0))
	_message.modulate.a = 0.0
	add_child(_message)

	# The kick button only appears when there is a ball to kick, so it never
	# sits on screen as a control that does nothing.
	_kick_button = _button("kick", Color(0.98, 0.84, 0.36))
	# button_down / button_up rather than pressed, because a kick is a hold.
	_kick_button.button_down.connect(func() -> void: kick_started.emit())
	_kick_button.button_up.connect(func() -> void: kick_released.emit())
	_kick_button.visible = false
	add_child(_kick_button)

	# A power bar that fills while the button is held. Without it, strength is
	# an invisible number a child has to guess at, and the same press produces
	# a different kick depending on how long the finger happened to rest.
	_power_bar = ColorRect.new()
	_power_bar.color = Color(0.0, 0.0, 0.0, 0.45)
	_power_bar.visible = false
	_power_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_power_bar)

	_power_fill = ColorRect.new()
	_power_fill.color = Color(0.98, 0.78, 0.28)
	_power_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power_bar.add_child(_power_fill)

	# And a word for where it will go, because "look up to chip it" is not
	# something a six-year-old will work out unaided.
	_aim_label = _label(24, Color(0.98, 0.90, 0.62))
	_aim_label.visible = false
	add_child(_aim_label)

	_score = _label(34, Color(1.0, 0.94, 0.72))
	_score.visible = false
	add_child(_score)

	# Jump is always available, unlike kick and build, so it sits at the bottom
	# of the stack where a thumb rests.
	_jump_button = _button("jump", Color(0.62, 0.90, 0.68))
	_jump_button.pressed.connect(func() -> void: jump_pressed.emit())
	add_child(_jump_button)

	_build_button = _button("build", Color(0.42, 0.72, 0.98))
	_build_button.pressed.connect(_on_build_pressed)
	add_child(_build_button)

	_place_button = _button("+", Color(0.48, 0.88, 0.52))
	_place_button.pressed.connect(func() -> void: build_place.emit())
	_place_button.visible = false
	add_child(_place_button)

	# Taking things down is as important as putting them up. A child who cannot
	# undo a misplaced wall stops experimenting, and experimenting is the game.
	_remove_button = _button("-", Color(0.96, 0.56, 0.46))
	_remove_button.pressed.connect(func() -> void: build_remove.emit())
	_remove_button.visible = false
	add_child(_remove_button)

	_layout()
	get_viewport().size_changed.connect(_layout)

func _build_palette() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.visible = false
	for kind in BuildKinds.ALL:
		var button := _button(BuildKinds.icon(kind), Color(0.86, 0.86, 0.90))
		button.pressed.connect(func() -> void: build_selected.emit(kind))
		row.add_child(button)
		_palette_buttons[kind] = button
	for kind in HouseParts.ALL:
		var button := _button(HouseParts.icon(kind), Color(0.86, 0.86, 0.90))
		button.pressed.connect(func() -> void: build_selected.emit(kind))
		button.visible = false
		row.add_child(button)
		_palette_buttons[kind] = button
	return row

## Two tabs, because eight house parts and five objects on one row is thirteen
## buttons and a six-year-old cannot find anything in thirteen buttons.
func _build_tabs() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.visible = false

	var things := _button("things", Color(0.86, 0.90, 0.96))
	things.custom_minimum_size = Vector2(BUTTON * 1.6, BUTTON * 0.7)
	things.add_theme_font_size_override("font_size", 22)
	things.pressed.connect(func() -> void: _show_house(false))
	row.add_child(things)

	var house := _button("house", Color(0.86, 0.90, 0.96))
	house.custom_minimum_size = Vector2(BUTTON * 1.6, BUTTON * 0.7)
	house.add_theme_font_size_override("font_size", 22)
	house.pressed.connect(func() -> void: _show_house(true))
	row.add_child(house)
	return row

func _show_house(house: bool) -> void:
	_showing_house = house
	for kind in _palette_buttons:
		var is_house := HouseParts.is_house_part(kind)
		(_palette_buttons[kind] as Button).visible = is_house == house
	for i in _tabs.get_child_count():
		(_tabs.get_child(i) as Button).modulate = (
			Color.WHITE if (i == 1) == house else Color(1.0, 1.0, 1.0, 0.5)
		)
	build_tab.emit(house)
	_layout()

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
	_tabs.visible = enabled
	_place_button.visible = enabled
	_remove_button.visible = enabled
	if enabled:
		_show_house(_showing_house)
	_build_button.text = "x" if enabled else "build"
	_status.text = ""
	build_toggled.emit(enabled)
	_layout()

## The count of one item changed.
func set_item_count(kind: StringName, total: int) -> void:
	_backpack.set_count(kind, total)

## Which piece is selected, whether it can go where it is aimed, and why not.
func set_build_state(kind: StringName, valid: bool, reason: String) -> void:
	for other in _palette_buttons:
		var button: Button = _palette_buttons[other]
		button.modulate = Color.WHITE if other == kind else Color(1.0, 1.0, 1.0, 0.45)
	_place_button.disabled = not valid
	_place_button.modulate = Color.WHITE if valid else Color(1.0, 1.0, 1.0, 0.4)
	var name := (
		HouseParts.label(kind) if HouseParts.is_house_part(kind)
		else BuildKinds.label(kind)
	)
	_status.text = name if valid else "%s — %s" % [name, reason]
	_layout()

## Show or hide the kick button. Driven by whether a ball is actually in reach.
func set_ball_in_reach(in_reach: bool) -> void:
	if _kick_button.visible == in_reach:
		return
	_kick_button.visible = in_reach
	_layout()

## Show the kick strength and where it is aimed, while the button is held.
##
## Both numbers run 0 to 1. The words matter more than the bar for the younger
## child: "low", "along the ground", "high" is something he can act on, where a
## bar is only something to watch fill.
func set_kick_preview(charging: bool, strength: float, loft: float) -> void:
	_power_bar.visible = charging
	_aim_label.visible = charging
	if not charging:
		return

	var width := _power_bar.size.x - 8.0
	_power_fill.position = Vector2(4.0, 4.0)
	_power_fill.size = Vector2(maxf(0.0, width * clampf(strength, 0.0, 1.0)), _power_bar.size.y - 8.0)
	# Yellow through to red, so a full-power shot looks like one.
	_power_fill.color = Color(0.98, 0.78, 0.28).lerp(Color(0.96, 0.38, 0.26), strength)

	var aim := "along the ground"
	if loft > 0.66:
		aim = "high over the top"
	elif loft > 0.3:
		aim = "up and over"
	_aim_label.text = aim

## The running total of goals. Hidden until the first one, because a scoreboard
## reading zero before anyone has played is just clutter.
func set_score(goals: int) -> void:
	_score.text = "%d" % goals
	if not _score.visible and goals > 0:
		_score.visible = true
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

	# Down the right-hand side, under the score, clear of the build buttons in
	# the corner below it.
	_backpack.position = Vector2(
		safe.position.x + safe.size.x - Backpack.WIDTH - MARGIN,
		safe.position.y + MARGIN + 52.0
	)

	_build_button.position = Vector2(
		safe.position.x + safe.size.x - BUTTON - MARGIN,
		safe.position.y + safe.size.y - BUTTON - MARGIN
	)

	# Left of build, so the right thumb reaches jump without leaving the corner.
	_jump_button.position = _build_button.position - Vector2(BUTTON + 16.0, 0.0)

	_place_button.position = _build_button.position - Vector2(0.0, BUTTON + 16.0)
	_remove_button.position = _place_button.position - Vector2(BUTTON + 16.0, 0.0)

	# Above the build button when build mode is closed, above the place button
	# when it is open, so the two never overlap.
	var kick_stack := 1 if not _building else 2
	_kick_button.position = _build_button.position - Vector2(0.0, (BUTTON + 16.0) * float(kick_stack))

	# The bar sits above the kick button, wide enough to read at a glance from
	# the far side of a tablet.
	var bar_width := 300.0
	_power_bar.size = Vector2(bar_width, 34.0)
	_power_bar.position = Vector2(
		view.x * 0.5 - bar_width * 0.5,
		_kick_button.position.y - 58.0
	)
	_aim_label.size.x = view.x
	_aim_label.position = Vector2(0.0, _power_bar.position.y - 36.0)

	_score.size.x = view.x
	_score.position = Vector2(0.0, safe.position.y + MARGIN)

	var shown := HouseParts.ALL.size() if _showing_house else BuildKinds.ALL.size()
	var palette_width := float(shown) * (BUTTON + 12.0)
	_palette.position = Vector2(
		safe.position.x + safe.size.x * 0.5 - palette_width * 0.5,
		safe.position.y + safe.size.y - BUTTON - MARGIN
	)

	var tabs_width := BUTTON * 3.2 + 10.0
	_tabs.position = Vector2(
		safe.position.x + safe.size.x * 0.5 - tabs_width * 0.5,
		_palette.position.y - BUTTON * 0.7 - 12.0
	)

	_status.size.x = view.x
	_status.position = Vector2(0.0, _tabs.position.y - 42.0)

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
