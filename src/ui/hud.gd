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
signal language_chosen(code: StringName)
signal reset_requested()
signal care_pressed()
signal shop_toggled()
signal shop_buy(item: StringName)
signal drink_pressed()
signal whistle_pressed()
signal chop_pressed()
signal ride_pressed()
signal shoot_started()
signal shoot_released()
signal place_used()
signal dam_stick()

var _stick: VirtualJoystick
var _backpack: Backpack
var _minimap: Minimap
var _build_button: Button
var _palette: HBoxContainer
var _palette_buttons: Dictionary = {}
var _tabs: HBoxContainer
var _place_button: Button
var _remove_button: Button
var _showing_house := false
var _menu: VBoxContainer
var _danger: PanelContainer
var _menu_button: Button
var _map_button: Button
## How long the reset must be held. Long enough that a child cannot do it by
## accident or by curiosity, short enough that a parent does not wonder whether
## it is working.
const RESET_HOLD := 5.0

var _reset_button: Button
var _reset_held := 0.0
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
var _storey_label: Label
var _task_label: Label
var _care_button: Button
var _coins_label: Label
var _vitals: VitalsGauge
var _drink_button: Button
var _whistle_button: Button
var _chop_button: Button
var _ride_button: Button
var _shoot_button: Button
var _visit_button: Button
var _dam_button: Button
var _shop: PanelContainer
var _shop_rows: Dictionary = {}

func _ready() -> void:
	var pad := CameraPad.new()
	pad.name = "CameraPad"
	pad.dragged.connect(func(delta: Vector2) -> void: camera_dragged.emit(delta))
	pad.pinched.connect(func(amount: float) -> void:
		camera_zoomed.emit(amount * CameraRig.ZOOM_PER_PIXEL))
	pad.wheeled.connect(func(notches: float) -> void:
		camera_zoomed.emit(notches * CameraRig.ZOOM_PER_NOTCH))
	# Only while building, so a tap in the world means nothing the rest of the
	# time and cannot place something by accident.
	pad.tapped.connect(func() -> void:
		if _building:
			build_place.emit())
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
	_kick_button = _button(Text.of("ui_kick"), Color(0.98, 0.84, 0.36))
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
	_jump_button = _button(Text.of("ui_jump"), Color(0.62, 0.90, 0.68))
	_jump_button.pressed.connect(func() -> void: jump_pressed.emit())
	add_child(_jump_button)

	_build_button = _button(Text.of("ui_build"), Color(0.42, 0.72, 0.98))
	_build_button.pressed.connect(_on_build_pressed)
	add_child(_build_button)

	# Kept as a second way in, for a child who has not discovered that tapping
	# the ghost works, and for a thumb already resting in that corner.
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

	# Which storey the ghost is on, shown only while building a house. The rule
	# that you build where you stand is invisible otherwise, and a child cannot
	# be expected to infer it from a wall appearing at his feet.
	_storey_label = _label(22, Color(0.72, 0.90, 1.0))
	_storey_label.visible = false
	add_child(_storey_label)

	# The current instruction, centred near the top where the eye lands first
	# and nothing else lives. One line, always, or it stops being an
	# instruction and becomes a paragraph.
	_task_label = _label(26, Color(1.0, 0.94, 0.74))
	_task_label.visible = false
	add_child(_task_label)

	# Appears only with an animal in reach, like the kick button — a control
	# that does nothing is a control a child learns to ignore.
	_care_button = _button("", Color(0.96, 0.82, 0.52))
	_care_button.pressed.connect(func() -> void: care_pressed.emit())
	_care_button.visible = false
	add_child(_care_button)

	# Coins sit beside the bag, because they are the other thing you have.
	_coins_label = _label(26, Color(1.0, 0.90, 0.52))
	_coins_label.visible = false

	_vitals = VitalsGauge.new()
	add_child(_vitals)

	# Only shown when there is something to drink, so it never sits there
	# inert inviting a press that does nothing.
	_drink_button = _button(Text.of("ui_drink"), Color(0.58, 0.82, 0.96))
	_drink_button.visible = false
	_drink_button.pressed.connect(func() -> void: drink_pressed.emit())
	add_child(_drink_button)

	# Appears only once the whistle has been bought, so the interface grows with
	# what the child owns rather than showing controls that do nothing.
	_whistle_button = _button(Text.of("ui_whistle"), Color(0.98, 0.84, 0.52))
	_whistle_button.visible = false
	_whistle_button.pressed.connect(func() -> void: whistle_pressed.emit())
	add_child(_whistle_button)

	# Shown only when the axe is owned and there is actually a tree in reach,
	# so it never invites a press that does nothing.
	_chop_button = _button(Text.of("ui_chop"), Color(0.86, 0.72, 0.52))
	_chop_button.visible = false
	_chop_button.pressed.connect(func() -> void: chop_pressed.emit())
	add_child(_chop_button)

	# The same button gets on and gets off, because they are the same thought.
	_ride_button = _button(Text.of("ui_ride"), Color(0.82, 0.88, 0.98))
	_ride_button.visible = false
	_ride_button.pressed.connect(func() -> void: ride_pressed.emit())
	add_child(_ride_button)

	# Held to draw and released to loose, the same gesture as the kick, so a
	# child who can shoot at goal can already shoot a bow.
	_shoot_button = _button(Text.of("ui_shoot"), Color(0.96, 0.86, 0.62))
	_shoot_button.visible = false
	_shoot_button.button_down.connect(func() -> void: shoot_started.emit())
	_shoot_button.button_up.connect(func() -> void: shoot_released.emit())
	add_child(_shoot_button)

	# One button for whatever the place a child is standing in offers, labelled
	# by the place. A separate control per destination would mean three buttons
	# of which two are always inert.
	_visit_button = _button(Text.of("ui_swing"), Color(0.72, 0.92, 0.78))
	_visit_button.visible = false
	_visit_button.pressed.connect(func() -> void: place_used.emit())
	add_child(_visit_button)

	# Only shown at a dam site, with a stick in the bag.
	_dam_button = _button(Text.of("ui_give_stick"), Color(0.78, 0.86, 0.70))
	_dam_button.visible = false
	_dam_button.pressed.connect(func() -> void: dam_stick.emit())
	add_child(_dam_button)
	add_child(_coins_label)

	_shop = _build_shop()
	add_child(_shop)

	_menu_button = _button("≡", Color(0.86, 0.90, 0.96))
	_menu_button.custom_minimum_size = Vector2(BUTTON * 0.7, BUTTON * 0.7)
	_menu_button.pressed.connect(_toggle_menu)
	add_child(_menu_button)

	_menu = _build_menu()
	add_child(_menu)

	_danger = _build_danger()
	add_child(_danger)

	# A toggle of its own, next to the menu, so the map can always be brought
	# back. It shows its state: filled when the map is open.
	_map_button = _button("▣", Color(0.86, 0.90, 0.96))
	_map_button.custom_minimum_size = Vector2(BUTTON * 0.7, BUTTON * 0.7)
	_map_button.pressed.connect(_toggle_map)
	add_child(_map_button)

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
		# A picture of the piece rather than a letter. "z" for stairs and "n"
		# for a door are unreadable, and an icon a child has to be taught is an
		# icon that does not work.
		var button := _button("", Color(0.86, 0.86, 0.90))
		var icon := PartIcon.new(kind)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.add_child(icon)
		button.tooltip_text = HouseParts.label(kind)
		button.pressed.connect(func() -> void: build_selected.emit(kind))
		button.visible = false
		row.add_child(button)
		_palette_buttons[kind] = button
	return row

## Two tabs, because eight house parts and five objects on one row is thirteen
## buttons and a six-year-old cannot find anything in thirteen buttons.
## The settings panel: a language for each child who reads a different one.
##
## Erasing the world is NOT here. It used to be, and that was wrong: children
## open this panel to change language, and a button that deletes both brothers'
## work should not sit a thumb's width from one they press often. It lives
## behind its own door instead.
func _build_menu() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.visible = false

	var heading := Label.new()
	heading.text = Text.of("ui_language")
	heading.add_theme_font_size_override("font_size", 20)
	heading.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.55))
	column.add_child(heading)

	for code in Text.LANGUAGES:
		var button := _button(Text.ENDONYM[code], Color(0.90, 0.93, 0.97))
		button.custom_minimum_size = Vector2(BUTTON * 2.2, BUTTON * 0.7)
		button.add_theme_font_size_override("font_size", 22)
		button.pressed.connect(func() -> void: language_chosen.emit(code))
		column.add_child(button)

	# A quiet way through to the dangerous room, worded so an adult knows it is
	# for them and a child has no reason to want it.
	var door := _button(Text.of("ui_danger"), Color(1.0, 1.0, 1.0, 0.42))
	door.custom_minimum_size = Vector2(BUTTON * 2.2, BUTTON * 0.62)
	door.add_theme_font_size_override("font_size", 17)
	door.pressed.connect(func() -> void:
		_menu.visible = false
		_danger.visible = true
		_layout())
	column.add_child(door)
	return column

## The room where the world can be erased. Separate, plainly labelled, and still
## held rather than pressed: two doors and five seconds between a curious child
## and his brother's afternoon.
func _build_danger() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.07, 0.07, 0.94)
	style.set_corner_radius_all(14)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 16.0
	style.border_color = Color(0.98, 0.56, 0.46, 0.5)
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	panel.visible = false

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var warning := Label.new()
	warning.text = Text.of("ui_reset_warning")
	warning.add_theme_font_size_override("font_size", 19)
	warning.add_theme_color_override("font_color", Color(1.0, 0.86, 0.82))
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.custom_minimum_size = Vector2(BUTTON * 3.4, 0.0)
	column.add_child(warning)

	_reset_button = _button(Text.of("ui_reset_hold"), Color(0.98, 0.66, 0.56))
	_reset_button.custom_minimum_size = Vector2(BUTTON * 3.4, BUTTON * 0.7)
	_reset_button.add_theme_font_size_override("font_size", 18)
	_reset_button.button_down.connect(func() -> void: _reset_held = 0.001)
	_reset_button.button_up.connect(func() -> void:
		_reset_held = 0.0
		_reset_button.text = Text.of("ui_reset_hold"))
	column.add_child(_reset_button)

	var back := _button(Text.of("ui_back"), Color(0.90, 0.93, 0.97))
	back.custom_minimum_size = Vector2(BUTTON * 3.4, BUTTON * 0.62)
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(func() -> void:
		_danger.visible = false
		_reset_held = 0.0
		_reset_button.text = Text.of("ui_reset_hold")
		_layout())
	column.add_child(back)
	return panel

## The shop: one row per thing, showing what it does and what it costs.
##
## Everything is visible from the first coin, including what cannot yet be
## afforded. Hiding the bicycle until a child can buy it removes the only reason
## to keep going; showing it greyed with its price is the reason.
func _build_shop() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.13, 0.94)
	style.set_corner_radius_all(16)
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 16.0
	style.border_color = Color(1.0, 0.90, 0.52, 0.35)
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	panel.visible = false

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var heading := Label.new()
	heading.text = Text.of("ui_shop")
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", Color(1.0, 0.90, 0.52))
	column.add_child(heading)

	# Each row is icon | name and description | price, in fixed columns, so the
	# prices line up and can be compared down the list. Centred text in one
	# blob made "which of these can I afford" a reading exercise.
	for item in ShopStock.ALL:
		var row := Button.new()
		row.custom_minimum_size = Vector2(BUTTON * 4.8, BUTTON * 0.86)
		row.focus_mode = Control.FOCUS_NONE
		row.pressed.connect(func() -> void: shop_buy.emit(item))
		column.add_child(row)

		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		line.offset_left = 14.0
		line.offset_right = -14.0
		# The label must not swallow the press, or the row stops buying.
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(line)

		var icon := ShopIcon.new(item)
		icon.custom_minimum_size = Vector2(BUTTON * 0.62, BUTTON * 0.62)
		line.add_child(icon)

		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_theme_constant_override("separation", 0)
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(words)

		var name_label := Label.new()
		name_label.text = ShopStock.label(item)
		name_label.add_theme_font_size_override("font_size", 19)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.add_child(name_label)

		var note := Label.new()
		note.text = ShopStock.description(item)
		note.add_theme_font_size_override("font_size", 14)
		note.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82))
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.add_child(note)

		var price := Label.new()
		price.add_theme_font_size_override("font_size", 20)
		price.add_theme_color_override("font_color", Color(1.0, 0.90, 0.52))
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		price.custom_minimum_size = Vector2(BUTTON * 0.86, 0.0)
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(price)

		_shop_rows[item] = {"button": row, "price": price, "icon": icon}

	var close := _button(Text.of("ui_back"), Color(0.90, 0.93, 0.97))
	close.custom_minimum_size = Vector2(BUTTON * 4.6, BUTTON * 0.62)
	close.add_theme_font_size_override("font_size", 18)
	close.pressed.connect(func() -> void: shop_toggled.emit())
	column.add_child(close)
	return panel

## Show or hide the shop, and refresh every row against the current purse.
func set_shop_open(open: bool, coins: int, owned: Dictionary) -> void:
	_shop.visible = open
	if open:
		for item in ShopStock.ALL:
			var parts: Dictionary = _shop_rows[item]
			var row: Button = parts["button"]
			var price_label: Label = parts["price"]
			var price := ShopStock.price(item)
			var mine: bool = owned.has(item)
			if mine:
				price_label.text = "✓"
				price_label.add_theme_color_override("font_color", Color(0.62, 0.92, 0.66))
				row.modulate = Color(0.80, 0.96, 0.82)
			else:
				# The coin is drawn next to the number, because a bare "12" does
				# not say what it is asking for.
				price_label.text = "%d ●" % price
				price_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.52))
				# Affordable rows stand out; the rest stay legible so the price
				# of the next thing is always readable.
				row.modulate = (
					Color.WHITE if coins >= price else Color(1.0, 1.0, 1.0, 0.45)
				)
			row.disabled = mine
	_layout()

## Energy and water, and whether a drink is worth offering.
func set_vitals(energy: float, water: float, carries_bottle: bool) -> void:
	_vitals.set_energy(energy)
	_vitals.set_water(water, carries_bottle)
	var can_drink := carries_bottle and water > 0.0
	if _drink_button.visible != can_drink:
		_drink_button.visible = can_drink
		_layout()

## Whether the beavers will take a stick right now.
func set_dam_offer(offered: bool) -> void:
	if _dam_button.visible != offered:
		_dam_button.visible = offered
		_layout()

## What the place a child is standing in offers, or nothing at all.
func set_place_offer(label: String) -> void:
	var wanted := not label.is_empty()
	if wanted and _visit_button.text != label:
		_visit_button.text = label
	if _visit_button.visible != wanted:
		_visit_button.visible = wanted
		_layout()

## Whether the shooting line is close enough to draw a bow.
func set_on_shooting_line(within: bool) -> void:
	if _shoot_button.visible != within:
		_shoot_button.visible = within
		_layout()

## Offer to get on when a mount is in reach, and to get off while riding.
func set_mount_in_reach(available: bool, riding: bool) -> void:
	var wanted := available or riding
	var label := Text.of("ui_getoff") if riding else Text.of("ui_ride")
	if _ride_button.text != label:
		_ride_button.text = label
	if _ride_button.visible != wanted:
		_ride_button.visible = wanted
		_layout()

## Whether a tree is close enough to cut, given that the axe is owned.
func set_tree_in_reach(within_reach: bool) -> void:
	if _chop_button.visible != within_reach:
		_chop_button.visible = within_reach
		_layout()

## Show the controls that only exist once bought.
func set_owned(owned: Dictionary) -> void:
	var has_whistle: bool = owned.has(ShopStock.WHISTLE)
	if _whistle_button.visible != has_whistle:
		_whistle_button.visible = has_whistle
		_layout()

func is_shop_open() -> bool:
	return _shop.visible

## Show the care button when an animal is within reach, labelled with what it
## wants, so the child is told the answer at the moment he can act on it.
func set_animal_in_reach(wish: String) -> void:
	var showing := not wish.is_empty()
	if _care_button.visible == showing and _care_button.text == wish:
		return
	_care_button.visible = showing
	_care_button.text = wish
	_layout()

func set_coins(total: int) -> void:
	_coins_label.text = "%d ●" % total
	if not _coins_label.visible and total > 0:
		_coins_label.visible = true
	_layout()

func _toggle_map() -> void:
	if _minimap == null:
		return
	if _minimap.is_showing():
		_minimap.hide_map()
	else:
		_minimap.show_map()
	_map_button.modulate = Color.WHITE if _minimap.is_showing() else Color(1.0, 1.0, 1.0, 0.5)
	_layout()

func _toggle_menu() -> void:
	_menu.visible = not _menu.visible
	# Opening or closing the menu always shuts the dangerous room behind it.
	_danger.visible = false
	_reset_held = 0.0
	_reset_button.text = Text.of("ui_reset_hold")
	_layout()

func _build_tabs() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.visible = false

	var things := _button(Text.of("ui_things"), Color(0.86, 0.90, 0.96))
	things.custom_minimum_size = Vector2(BUTTON * 1.6, BUTTON * 0.7)
	things.add_theme_font_size_override("font_size", 22)
	things.pressed.connect(func() -> void: _show_house(false))
	row.add_child(things)

	var house := _button(Text.of("ui_house"), Color(0.86, 0.90, 0.96))
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
	# Wide enough for the word it holds, never narrower than a thumb. A fixed
	# width fitted the English and overlapped as soon as the same buttons said
	# "прыжок" and "строить".
	var wide := maxf(BUTTON, float(text.length()) * 17.0 + 34.0)
	button.custom_minimum_size = Vector2(wide, BUTTON)
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
	_build_button.text = Text.of("ui_close") if enabled else Text.of("ui_build")
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

## The map is built by whoever owns the world, because it needs the height
## field, and the HUD is not the place to know about terrain.
func attach_minimap(minimap: Minimap) -> void:
	_minimap = minimap
	add_child(minimap)
	_layout()

func track_map(world_position: Vector3, yaw: float, built: Array[Vector3]) -> void:
	if _minimap != null:
		_minimap.track(world_position, yaw, built)

## The one thing the game is currently asking for. Empty hides it, which is
## what happens when the opening thread is finished and the valley is handed
## over for good.
func set_task(instruction: String) -> void:
	_task_label.text = instruction
	_task_label.visible = not instruction.is_empty()
	_layout()

## Which storey the next piece will land on, or nothing if it is not a house
## part. Includes the hint the first time a player is on the ground floor, since
## that is when knowing you can go up is useful.
func set_storey(storey: int, showing: bool) -> void:
	_storey_label.visible = showing
	if not showing:
		return
	if storey <= 0:
		_storey_label.text = "%s  ·  %s" % [
			Text.of("ui_ground_floor"), Text.of("ui_go_up_hint")
		]
	else:
		_storey_label.text = Text.format("ui_upper_floor", [storey + 1])
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

	var aim := Text.of("aim_ground")
	if loft > 0.66:
		aim = Text.of("aim_high")
	elif loft > 0.3:
		aim = Text.of("aim_over")
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
	if _reset_held > 0.0:
		_reset_held += delta
		if _reset_held >= RESET_HOLD:
			_reset_held = 0.0
			_reset_button.text = Text.of("ui_reset_hold")
			reset_requested.emit()
		else:
			# Counting down out loud, so a parent holding it knows it is
			# working and a child watching gets bored before it finishes.
			_reset_button.text = "%s %d" % [
				Text.of("ui_reset_holding"),
				int(ceil(RESET_HOLD - _reset_held))
			]

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
	_menu_button.position = Vector2(
		safe.position.x + MARGIN,
		safe.position.y + MARGIN
	)

	# The map sits under the menu button, top left, where a child's eye goes
	# first and where nothing else competes for the corner.
	if _minimap != null:
		_minimap.position = Vector2(
			safe.position.x + MARGIN,
			safe.position.y + MARGIN + BUTTON * 0.7 + 10.0
		)
		_map_button.modulate = (
			Color.WHITE if _minimap.is_showing() else Color(1.0, 1.0, 1.0, 0.5)
		)
	_map_button.position = _menu_button.position + Vector2(BUTTON * 0.7 + 10.0, 0.0)
	_menu.position = _menu_button.position + Vector2(0.0, BUTTON * 0.7 + 10.0)
	_danger.position = _menu.position

	_backpack.position = Vector2(
		safe.position.x + safe.size.x - Backpack.WIDTH - MARGIN,
		safe.position.y + MARGIN + 52.0
	)

	_build_button.position = Vector2(
		safe.position.x + safe.size.x - _build_button.size.x - MARGIN,
		safe.position.y + safe.size.y - BUTTON - MARGIN
	)

	# Left of build, so the right thumb reaches jump without leaving the corner.
	# Jump keeps its place beside build. Stacking it upwards while building put
	# it straight through the bag, which is anchored to the same corner.
	_jump_button.position = _build_button.position - Vector2(_jump_button.size.x + 16.0, 0.0)

	_place_button.position = Vector2(
		safe.position.x + safe.size.x - _place_button.size.x - MARGIN,
		_build_button.position.y - BUTTON - 16.0
	)
	_remove_button.position = _place_button.position - Vector2(_remove_button.size.x + 16.0, 0.0)

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

	_storey_label.size.x = view.x
	_storey_label.position = Vector2(0.0, _status.position.y - 36.0)

	_score.size.x = view.x
	_score.position = Vector2(0.0, safe.position.y + MARGIN)

	_task_label.size.x = view.x
	_task_label.position = Vector2(0.0, safe.position.y + MARGIN + 44.0)

	# Under the bag, aligned to its right edge.
	_coins_label.size.x = Backpack.WIDTH
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_coins_label.position = Vector2(
		safe.position.x + safe.size.x - Backpack.WIDTH - MARGIN,
		_backpack.position.y + _backpack.size.y + 8.0
	)

	# Under the coins, at the same right edge as the bag above it.
	_vitals.size = _vitals.custom_minimum_size
	_vitals.position = Vector2(
		safe.position.x + safe.size.x - VitalsGauge.WIDTH - MARGIN,
		_coins_label.position.y + _coins_label.size.y + 10.0
	)

	_drink_button.position = Vector2(
		safe.position.x + safe.size.x - _drink_button.size.x - MARGIN,
		_vitals.position.y + _vitals.size.y + 10.0
	)

	# Below the drink button when both are shown, in its place when it is not.
	var whistle_top := _vitals.position.y + _vitals.size.y + 10.0
	if _drink_button.visible:
		whistle_top = _drink_button.position.y + _drink_button.size.y + 10.0
	_whistle_button.position = Vector2(
		safe.position.x + safe.size.x - _whistle_button.size.x - MARGIN, whistle_top
	)

	var chop_top := whistle_top
	if _whistle_button.visible:
		chop_top = _whistle_button.position.y + _whistle_button.size.y + 10.0
	_chop_button.position = Vector2(
		safe.position.x + safe.size.x - _chop_button.size.x - MARGIN, chop_top
	)

	var ride_top := chop_top
	if _chop_button.visible:
		ride_top = _chop_button.position.y + _chop_button.size.y + 10.0
	_ride_button.position = Vector2(
		safe.position.x + safe.size.x - _ride_button.size.x - MARGIN, ride_top
	)

	# Low and centre-left of the kick button, since drawing a bow and striking a
	# ball are the same gesture and never both apply.
	_shoot_button.position = Vector2(
		safe.position.x + safe.size.x * 0.5 - _shoot_button.size.x * 0.5,
		safe.position.y + safe.size.y - BUTTON - MARGIN
	)

	# Above the centre buttons, so it never lands under a thumb already busy
	# with the kick.
	_visit_button.position = Vector2(
		safe.position.x + safe.size.x * 0.5 - _visit_button.size.x * 0.5,
		safe.position.y + safe.size.y - BUTTON * 2.0 - MARGIN * 2.0
	)

	# Beside the place button, since a child is never at a dam and in the café
	# at the same time.
	_dam_button.position = _visit_button.position

	# Centred low, where the kick button sits, since the two never both apply.
	_care_button.position = Vector2(
		safe.position.x + safe.size.x * 0.5 - _care_button.size.x * 0.5,
		safe.position.y + safe.size.y - BUTTON - MARGIN
	)

	_shop.position = Vector2(
		safe.position.x + safe.size.x * 0.5 - _shop.size.x * 0.5,
		safe.position.y + safe.size.y * 0.5 - _shop.size.y * 0.5
	)

	var shown := HouseParts.ALL.size() if _showing_house else BuildKinds.ALL.size()
	var palette_width := float(shown) * (BUTTON + 12.0)
	# Centred, but never allowed to reach the buttons stacked on the right.
	# Eight parts plus Russian words met "прыжок" in the middle otherwise.
	var right_edge := minf(
		_jump_button.position.x,
		_remove_button.position.x if _building else _build_button.position.x
	) - 20.0
	var left := safe.position.x + safe.size.x * 0.5 - palette_width * 0.5
	left = minf(left, right_edge - palette_width)
	var left_edge := _stick.position.x + _stick.size.x * 0.62
	left = maxf(left, left_edge)
	_palette.position = Vector2(left, safe.position.y + safe.size.y - BUTTON - MARGIN)

	# If the row cannot fit between the stick and the buttons, it sits above
	# them instead of over them. Eight parts in Russian on a phone is exactly
	# that case, and an overlapping palette is a palette a child mis-taps.
	if left + palette_width > right_edge:
		_palette.position = Vector2(
			maxf(left_edge, safe.position.x + safe.size.x * 0.5 - palette_width * 0.5),
			_tabs.position.y - BUTTON - 12.0
		)
		_tabs.position.y = _palette.position.y - BUTTON * 0.7 - 12.0
		_status.position.y = _tabs.position.y - 42.0
		_storey_label.position.y = _status.position.y - 36.0

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
