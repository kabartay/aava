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
signal snack_pressed()
signal lantern_pressed()
signal drink_pressed()
signal whistle_pressed()
signal chop_pressed()
signal ride_pressed()
signal shoot_started()
signal shoot_released()
signal place_used()
## The turnstile at the pool: pay and go in.
signal ticket_pressed()
## A question answered: the tick, or the cross.
## The parent's switch for talking, from the menu.
signal voice_allowed_changed(allowed: bool)

signal confirmed()
signal refused()
signal dam_stick()
signal fire_fed()
signal slept()
signal together_opened()
signal talk_started()
signal talk_released()

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
var _purse: PanelContainer
var _vitals: VitalsGauge
var _drink_button: Button
var _whistle_button: Button
var _chop_button: Button
var _ride_button: Button
var _shoot_button: Button
var _visit_button: Button
var _ticket_button: Button
var _asking: PanelContainer
var _question: Label
var _dam_button: Button
var _fire_button: Button
var _snack_button: Button
var _lantern_button: Button
var _sleep_button: Button
var together: TogetherPanel
var _talk_button: Button
var _voice_switch: Button
var _voice_allowed := true
var _shop: PanelContainer
## The shelf the stock sits on, which scrolls when there is more of it than
## fits, and how many pictures stand across it.
var _shop_shelf: ScrollContainer
## Five across. Three was two rows of pictures and a third row that would not
## come into view: the shelf scrolls, but a tile is a button and a button eats
## the drag before the shelf sees it, so the bottom row was unreachable and the
## bicycle could not be bought. Five columns puts ten things in two rows, and
## the question of scrolling does not arise.
const SHOP_COLUMNS := 5
## The picture a child has tapped, the two lines that answer them, and what is
## already theirs.
var _shop_chosen := &""
var _shop_owned: Dictionary = {}
var _shop_buy_button: Button
## What is in the purse, so the buying button can grey itself out.
var _shop_coins := 0
var _shop_name: Label
var _shop_heading: Label
var _shop_note: Label
var _shop_rows: Dictionary = {}

func _init() -> void:
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
	# The bag changes height as it is opened and shut, and everything down the
	# right-hand edge is placed under it.
	add_child(_backpack)

	_palette = _build_palette()
	add_child(_palette)

	_tabs = _build_tabs()
	add_child(_tabs)

	_status = _label(22, Color(1.0, 0.86, 0.55))
	add_child(_status)

	_build_asking()

	_message = _label(30, Color(1.0, 1.0, 1.0))
	_message.modulate.a = 0.0
	add_child(_message)

	# The kick button only appears when there is a ball to kick, so it never
	# sits on screen as a control that does nothing.
	_kick_button = _icon_button(ActionIcon.Kind.KICK)
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
	_jump_button = _icon_button(ActionIcon.Kind.JUMP)
	_jump_button.pressed.connect(func() -> void: jump_pressed.emit())
	add_child(_jump_button)

	_build_button = _icon_button(ActionIcon.Kind.BUILD)
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
	# The purse: a slab like the bag above it, with a coin drawn on it and the
	# number beside it.
	#
	# It was a bare number in warm type floating over whatever the sky happened
	# to be doing, and it was missed — which matters, because knowing what you
	# have is what makes a child decide to go and look after another animal
	# before walking four hundred metres to the shop to find out they cannot
	# afford the thing. It is always there now, from the first coin and before
	# it, in the same kind of panel as everything else that says what you have.
	_purse = PanelContainer.new()
	var purse_style := StyleBoxFlat.new()
	purse_style.bg_color = Color(0.07, 0.09, 0.12, 0.62)
	purse_style.set_corner_radius_all(14)
	purse_style.content_margin_left = 14.0
	purse_style.content_margin_right = 14.0
	purse_style.content_margin_top = 6.0
	purse_style.content_margin_bottom = 6.0
	purse_style.border_color = Color(1.0, 0.90, 0.52, 0.30)
	purse_style.set_border_width_all(1)
	_purse.add_theme_stylebox_override("panel", purse_style)
	_purse.custom_minimum_size = Vector2(Backpack.WIDTH, 0.0)
	_purse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var purse_line := HBoxContainer.new()
	purse_line.add_theme_constant_override("separation", 10)
	purse_line.alignment = BoxContainer.ALIGNMENT_CENTER
	purse_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_purse.add_child(purse_line)
	var coin := CoinIcon.new()
	coin.custom_minimum_size = Vector2(28.0, 28.0)
	purse_line.add_child(coin)
	_coins_label = _label(26, Color(1.0, 0.92, 0.60))
	_coins_label.text = "0"
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_coins_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	purse_line.add_child(_coins_label)

	_vitals = VitalsGauge.new()
	add_child(_vitals)

	# Only shown when there is something to drink, so it never sits there
	# inert inviting a press that does nothing.
	_drink_button = _icon_button(ActionIcon.Kind.DRINK)
	_drink_button.visible = false
	_drink_button.pressed.connect(func() -> void: drink_pressed.emit())
	add_child(_drink_button)

	# Appears only once the whistle has been bought, so the interface grows with
	# what the child owns rather than showing controls that do nothing.
	_whistle_button = _icon_button(ActionIcon.Kind.WHISTLE)
	_whistle_button.visible = false
	_whistle_button.pressed.connect(func() -> void: whistle_pressed.emit())
	add_child(_whistle_button)

	# Shown only when the axe is owned and there is actually a tree in reach,
	# so it never invites a press that does nothing.
	_chop_button = _icon_button(ActionIcon.Kind.CHOP)
	_chop_button.visible = false
	_chop_button.pressed.connect(func() -> void: chop_pressed.emit())
	add_child(_chop_button)

	# The same button gets on and gets off, because they are the same thought.
	_ride_button = _icon_button(ActionIcon.Kind.RIDE)
	_ride_button.visible = false
	_ride_button.pressed.connect(func() -> void: ride_pressed.emit())
	add_child(_ride_button)

	# Held to draw and released to loose, the same gesture as the kick, so a
	# child who can shoot at goal can already shoot a bow.
	_shoot_button = _icon_button(ActionIcon.Kind.SHOOT)
	_shoot_button.visible = false
	_shoot_button.button_down.connect(func() -> void: shoot_started.emit())
	_shoot_button.button_up.connect(func() -> void: shoot_released.emit())
	add_child(_shoot_button)

	# One button for whatever the place a child is standing in offers, labelled
	# by the place. A separate control per destination would mean three buttons
	# of which two are always inert.
	_visit_button = _icon_button(ActionIcon.Kind.SWING)
	_visit_button.visible = false
	_visit_button.pressed.connect(func() -> void: place_used.emit())
	add_child(_visit_button)

	_ticket_button = _icon_button(ActionIcon.Kind.TICKET)
	_ticket_button.visible = false
	_ticket_button.pressed.connect(func() -> void: ticket_pressed.emit())
	add_child(_ticket_button)

	# Only shown at a dam site, with a stick in the bag.
	_dam_button = _icon_button(ActionIcon.Kind.GIVE_STICK)
	_dam_button.visible = false
	_dam_button.pressed.connect(func() -> void: dam_stick.emit())
	add_child(_dam_button)

	# Shown at a campfire, with wood in the bag.
	_lantern_button = _icon_button(ActionIcon.Kind.LANTERN)
	_lantern_button.visible = false
	_lantern_button.pressed.connect(func() -> void: lantern_pressed.emit())
	add_child(_lantern_button)

	_snack_button = _icon_button(ActionIcon.Kind.SNACK)
	_snack_button.visible = false
	_snack_button.pressed.connect(func() -> void: snack_pressed.emit())
	add_child(_snack_button)

	_fire_button = _icon_button(ActionIcon.Kind.FEED_FIRE)
	_fire_button.visible = false
	_fire_button.pressed.connect(func() -> void: fire_fed.emit())
	add_child(_fire_button)

	# Shown at a bed, and only when there is a night to sleep through.
	_sleep_button = _icon_button(ActionIcon.Kind.SLEEP)
	_sleep_button.visible = false
	_sleep_button.pressed.connect(func() -> void: slept.emit())
	add_child(_sleep_button)
	add_child(_purse)

	_shop = _build_shop()
	add_child(_shop)

	_menu_button = _button("≡", Color(0.86, 0.90, 0.96))
	_menu_button.custom_minimum_size = Vector2(BUTTON * 0.7, BUTTON * 0.7)
	_menu_button.pressed.connect(_toggle_menu)
	add_child(_menu_button)

	_menu = _build_menu()
	add_child(_menu)

	together = TogetherPanel.new()
	together.resized_page.connect(_relayout_next_frame)
	add_child(together)

	# Held to talk and released to stop, the same gesture as the kick and the
	# bow. Shown only when there is somebody in the valley to talk to, so it
	# never sits there inviting a child to speak to nobody.
	_talk_button = _icon_button(ActionIcon.Kind.TALK)
	_talk_button.visible = false
	_talk_button.button_down.connect(func() -> void: talk_started.emit())
	_talk_button.button_up.connect(func() -> void: talk_released.emit())
	add_child(_talk_button)

	_danger = _build_danger()
	add_child(_danger)

	# A toggle of its own, next to the menu, so the map can always be brought
	# back. It shows its state: filled when the map is open.
	_map_button = _button("▣", Color(0.86, 0.90, 0.96))
	_map_button.custom_minimum_size = Vector2(BUTTON * 0.7, BUTTON * 0.7)
	_map_button.pressed.connect(_toggle_map)
	add_child(_map_button)

func _ready() -> void:
	# Everything above is built in _init, so a caller can use this HUD's
	# buttons and labels on the very same line it adds the node to the tree.
	# Only get_viewport() needs the tree, so only this waits for _ready.
	_layout()
	get_viewport().size_changed.connect(_layout)

func _build_palette() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.visible = false
	# A picture of the thing rather than a letter, for the objects as well as
	# the house parts: "T" for a sapling and "Y" for a bird feeder are as
	# unreadable as "z" was for stairs, and an icon a child has to be taught
	# is an icon that does not work.
	for kind in BuildKinds.ALL:
		row.add_child(_palette_button(kind, BuildKinds.label(kind), true))
	for kind in HouseParts.ALL:
		row.add_child(_palette_button(kind, HouseParts.label(kind), false))
	return row

## One button in the palette: a drawing of the piece, its name as a tooltip
## for whoever can read, and the piece's own name emitted when it is pressed.
func _palette_button(kind: StringName, named: String, shown: bool) -> Button:
	var button := _button("", Color(0.86, 0.86, 0.90))
	var icon := PartIcon.new(kind)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(icon)
	button.tooltip_text = named
	button.pressed.connect(func() -> void: build_selected.emit(kind))
	button.visible = shown
	_palette_buttons[kind] = button
	return button

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

	# The switch for talking. In the menu with the languages rather than behind
	# the quiet door, because it is a setting a parent may want on purpose and
	# not a thing to be warned about — but it is worded so it is plainly about
	# the microphone.
	_voice_switch = _button("", Color(0.90, 0.93, 0.97))
	_voice_switch.custom_minimum_size = Vector2(BUTTON * 2.2, BUTTON * 0.7)
	_voice_switch.add_theme_font_size_override("font_size", 19)
	_voice_switch.pressed.connect(func() -> void:
		set_voice_allowed(not _voice_allowed)
		voice_allowed_changed.emit(_voice_allowed))
	column.add_child(_voice_switch)
	_refresh_voice_switch()

	# Playing together is an ordinary thing to want, so it sits above the quiet
	# door and is coloured like something to press rather than something to
	# avoid.
	var share := _button(Text.of("ui_together"), Color(0.62, 0.88, 0.68))
	share.custom_minimum_size = Vector2(BUTTON * 2.2, BUTTON * 0.7)
	share.add_theme_font_size_override("font_size", 20)
	share.pressed.connect(_open_together)
	column.add_child(share)

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

	# The shop's name and, beside it, what is in the purse. The coin count
	# lives at the top right of the screen and the panel covers it, so a child
	# standing at the counter could not see what they had to spend.
	_shop_heading = Label.new()
	_shop_heading.add_theme_font_size_override("font_size", 24)
	_shop_heading.add_theme_color_override("font_color", Color(1.0, 0.90, 0.52))
	_shop_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_shop_heading)

	# Pictures and prices, three to a row, and no words at all.
	#
	# Each row used to be icon | name | what it does | price. That is four
	# columns of reading for a child who cannot read, in the one part of the
	# game that exists so they need not — the same mistake this file has
	# already made once and written down in LESSONS. The picture says what the
	# thing is; the number says what it costs; everything else was for adults.
	#
	# And the shelf scrolls. There were five things in the shop when the panel
	# was written and there are nine now, which ran off the bottom of the
	# screen with no way to reach them: a child could not buy what they could
	# not see, and nothing said so.
	_shop_shelf = ScrollContainer.new()
	_shop_shelf.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_shop_shelf.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_shop_shelf)

	var grid := GridContainer.new()
	grid.columns = SHOP_COLUMNS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_shelf.add_child(grid)

	# What the shop buys sits on the same shelf as what it sells, at the end:
	# a child with wool in their bag should find the place that turns it into
	# coins without being told where to look.
	var shelf: Array[StringName] = []
	shelf.append_array(ShopStock.ALL)
	for buying in ShopStock.BUYS:
		shelf.append(buying)
	for item in shelf:
		var tile := Button.new()
		tile.custom_minimum_size = Vector2(BUTTON * 1.5, BUTTON * 1.62)
		tile.focus_mode = Control.FOCUS_NONE
		# The shelf is scrolled with a thumb, and a button that swallows the
		# touch swallows the drag with it: the list could not be scrolled at
		# all. PASS lets the press work and the drag through to the shelf. It
		# is safe here only because a tap on a picture no longer buys anything.
		tile.mouse_filter = Control.MOUSE_FILTER_PASS
		# Tapping a picture asks what it is. It never buys: buying is a button
		# of its own, below, with the price written on it. Tap-twice-to-buy was
		# tried and is a trap — the second tap is how a child reads the words
		# again, and it was spending their coins.
		tile.pressed.connect(func() -> void: _shop_tapped(item))
		grid.add_child(tile)

		var stack := VBoxContainer.new()
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.add_theme_constant_override("separation", 2)
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		# The contents must not swallow the press, or the tile stops buying.
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(stack)

		if ShopStock.pays_for(item) > 0:
			var chip := ItemChip.new(item)
			chip.custom_minimum_size = Vector2(BUTTON * 1.0, BUTTON * 1.0)
			chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			stack.add_child(chip)
		else:
			var icon := ShopIcon.new(item)
			icon.custom_minimum_size = Vector2(BUTTON * 1.0, BUTTON * 1.0)
			icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			stack.add_child(icon)

		var price := Label.new()
		price.add_theme_font_size_override("font_size", 19)
		price.add_theme_color_override("font_color", Color(1.0, 0.90, 0.52))
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(price)

		_shop_rows[item] = {"button": tile, "price": price}

	# What the chosen thing is, under the shelf: its name, and one line saying
	# what it is for. Empty until a child taps something.
	_shop_name = Label.new()
	_shop_name.add_theme_font_size_override("font_size", 21)
	_shop_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_shop_name)

	_shop_note = Label.new()
	_shop_note.add_theme_font_size_override("font_size", 15)
	_shop_note.add_theme_color_override("font_color", Color(0.74, 0.78, 0.84))
	_shop_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shop_note.custom_minimum_size = Vector2(float(SHOP_COLUMNS) * (BUTTON * 1.5 + 10.0), 0.0)
	column.add_child(_shop_note)

	# The one thing here that spends coins, with the price on its face. Hidden
	# until a child has chosen something, so nothing can be bought by a tap
	# that was asking a question.
	_shop_buy_button = _button("", Color(1.0, 0.90, 0.52))
	_shop_buy_button.custom_minimum_size = Vector2(BUTTON * 3.0, BUTTON * 0.7)
	_shop_buy_button.add_theme_font_size_override("font_size", 20)
	_shop_buy_button.visible = false
	_shop_buy_button.pressed.connect(func() -> void:
		if _shop_chosen != &"" and not bool(_shop_owned.get(_shop_chosen, false)):
			shop_buy.emit(_shop_chosen)
	)
	column.add_child(_shop_buy_button)

	var close := _button(Text.of("ui_back"), Color(0.90, 0.93, 0.97))
	close.custom_minimum_size = Vector2(BUTTON * 4.6, BUTTON * 0.62)
	close.add_theme_font_size_override("font_size", 18)
	close.pressed.connect(func() -> void: shop_toggled.emit())
	column.add_child(close)
	return panel

## A picture was tapped. The first tap on a thing says what it is; the next one
## buys it.
func _shop_tapped(item: StringName) -> void:
	_shop_chosen = item
	if ShopStock.pays_for(item) > 0:
		_shop_name.text = ItemKinds.label(item)
		_shop_note.text = Text.format("shop_buys", [ShopStock.pays_for(item)])
		_refresh_shop_buy()
		_shop_mark_chosen()
		return
	_shop_name.text = ShopStock.label(item)
	if bool(_shop_owned.get(item, false)):
		_shop_name.text += " ✓"
	_shop_note.text = ShopStock.description(item)
	_refresh_shop_buy()
	_shop_mark_chosen()

## The buying button: what it would cost, or that it is already yours.
func _refresh_shop_buy() -> void:
	if _shop_buy_button == null:
		return
	if _shop_chosen == &"":
		_shop_buy_button.visible = false
		return
	_shop_buy_button.visible = true
	if ShopStock.pays_for(_shop_chosen) > 0:
		var many: int = int(_shop_carried.get(_shop_chosen, 0))
		_shop_buy_button.text = "%s  %d ●" % [
			Text.of("ui_sell"), many * ShopStock.pays_for(_shop_chosen)
		]
		_shop_buy_button.disabled = many <= 0
	elif bool(_shop_owned.get(_shop_chosen, false)):
		_shop_buy_button.text = Text.of("ui_owned")
		_shop_buy_button.disabled = true
	else:
		_shop_buy_button.text = "%s  %d ●" % [
			Text.of("ui_buy"), ShopStock.price(_shop_chosen)
		]
		_shop_buy_button.disabled = _shop_coins < ShopStock.price(_shop_chosen)

## Ring the chosen picture, so it is plain which one the words belong to and
## which one a second tap would buy.
func _shop_mark_chosen() -> void:
	for item in _shop_rows:
		var parts: Dictionary = _shop_rows[item]
		var tile: Button = parts["button"]
		var picked: bool = item == _shop_chosen
		tile.add_theme_constant_override("outline_size", 2 if picked else 0)
		var mark := StyleBoxFlat.new()
		mark.bg_color = Color(1.0, 0.90, 0.52, 0.18) if picked else Color(1.0, 1.0, 1.0, 0.06)
		mark.set_corner_radius_all(12)
		if picked:
			mark.border_color = Color(1.0, 0.90, 0.52, 0.85)
			mark.set_border_width_all(2)
		tile.add_theme_stylebox_override("normal", mark)

## Show or hide the shop, and refresh every row against the current purse.
## What the child is carrying of the things the shop buys, so a row can say
## whether there is anything to sell.
var _shop_carried: Dictionary = {}

func set_carried_for_sale(item: StringName, many: int) -> void:
	_shop_carried[item] = many

func set_shop_open(open: bool, coins: int, owned: Dictionary) -> void:
	var opening := open and not _shop.visible
	_shop.visible = open
	if opening:
		# A shop just opened has nothing chosen: otherwise the first tap after
		# walking in buys whatever was tapped last time.
		_shop_chosen = &""
		_shop_name.text = ""
		_shop_note.text = ""
		_shop_mark_chosen()
	if open:
		_shop_coins = coins
		# Just the name. What is in the purse is on the screen at all times now,
		# in its own panel beside the bag, which is where a child needs it —
		# before the four-hundred-metre walk, not after it.
		_shop_heading.text = Text.of("ui_shop")
		for item in _shop_rows:
			var parts: Dictionary = _shop_rows[item]
			var row: Button = parts["button"]
			var price_label: Label = parts["price"]
			# The things the shop buys read the other way round: what it pays,
			# and how many you have to sell.
			if ShopStock.pays_for(item) > 0:
				price_label.text = "+%d ●" % ShopStock.pays_for(item)
				price_label.add_theme_color_override("font_color", Color(0.62, 0.92, 0.66))
				row.modulate = Color.WHITE if _shop_carried.get(item, 0) > 0 else Color(1.0, 1.0, 1.0, 0.45)
				continue
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
			# Never disabled. A bought thing still has to answer "what is this"
			# when a child taps it — that was the whole point of the words —
			# and a disabled button answers nothing at all.
			_shop_owned[item] = mine
		# The purse may have changed since the words went up — a child has just
		# bought something, or earned a coin — so the button says so.
		_refresh_shop_buy()
	_layout()

## Energy and water, and whether a drink is worth offering.
func set_vitals(energy: float, water: float, carries_bottle: bool) -> void:
	_vitals.set_energy(energy)
	_vitals.set_water(water, carries_bottle)
	var can_drink := carries_bottle and water > 0.0
	if _drink_button.visible != can_drink:
		_drink_button.visible = can_drink
		_layout()

## Whether there is anyone to talk to, and whether the microphone is live.
func set_voice(offered: bool, speaking: bool) -> void:
	# Only when talking is allowed at all: the switch in the menu takes the
	# button away as well as silencing the microphone.
	var wanted := offered and _voice_allowed
	if _talk_button.visible != wanted:
		_talk_button.visible = wanted
		_layout()
	# Lit while the microphone is actually running, so a child can always see
	# whether they are being heard.
	_talk_button.modulate = Color(1.25, 1.1, 0.7) if speaking else Color.WHITE

## Whether there is a bed here worth lying down in.
func set_sleep_offer(offered: bool) -> void:
	if _sleep_button.visible != offered:
		_sleep_button.visible = offered
		_layout()

## Whether there is a fire here that would take a log.
func set_fire_offer(offered: bool) -> void:
	if _fire_button.visible != offered:
		_fire_button.visible = offered
		_layout()

## Whether the beavers will take a stick right now.
func set_dam_offer(offered: bool) -> void:
	if _dam_button.visible != offered:
		_dam_button.visible = offered
		_layout()

## What the place a child is standing in offers, or nothing at all.
## Which place the child is standing in, or the empty name for none. The
## button draws what that place offers — a swing at the playground, a meal at
## the café — rather than being told a word to show.
func set_place_offer(place: StringName) -> void:
	var wanted := place != &""
	if wanted:
		var face := _face_of(_visit_button)
		if face != null:
			var which := ActionIcon.Kind.SWING
			if place == Places.CAFE:
				which = ActionIcon.Kind.EAT
			elif place == Places.SHOP:
				which = ActionIcon.Kind.SHOP
			face.show_kind(which)
	if _visit_button.visible != wanted:
		_visit_button.visible = wanted
		_layout()

## Whether a lantern is owned, and whether it is alight. The button appears
## once there is one to switch, and dims while it is out.
func set_lantern(owned: bool, alight: bool) -> void:
	if _lantern_button.visible != owned:
		_lantern_button.visible = owned
		_layout()
	_lantern_button.modulate = Color.WHITE if alight else Color(1.0, 1.0, 1.0, 0.45)

## Whether there is chocolate in the bag to eat.
func set_snack_offer(wanted: bool) -> void:
	if _snack_button.visible != wanted:
		_snack_button.visible = wanted
		_layout()

## Whether the pool's turnstile is close enough to buy a ticket at.
func set_ticket_offer(wanted: bool) -> void:
	if _ticket_button.visible != wanted:
		_ticket_button.visible = wanted
		_layout()

## Whether the bow is on offer right now — that is, whether the child is
## standing at the shooting line. Read by the game, which shows the bow in
## their hands only there: the same button draws a bow at the range and
## kicks a ball on the pitch.
func is_shooting() -> bool:
	return _shoot_button.visible

## Whether the shooting line is close enough to draw a bow.
func set_on_shooting_line(within: bool) -> void:
	if _shoot_button.visible != within:
		_shoot_button.visible = within
		_layout()

## Offer to get on when a mount is in reach, and to get off while riding.
func set_mount_in_reach(
	available: bool, riding: bool, boat := false, kind_of := &""
) -> void:
	var wanted := available or riding
	var face := _face_of(_ride_button)
	if face != null:
		# The picture is of the thing being got on. It was a horseshoe whatever
		# was standing there, so the button for getting on a motorcycle showed
		# a hoof.
		var kind := ActionIcon.Kind.RIDE
		if riding:
			kind = ActionIcon.Kind.GET_OFF
		elif boat:
			# A horseshoe on a jetty would be a riddle; a boat says "row".
			kind = ActionIcon.Kind.ROW
		elif kind_of == MountKinds.BICYCLE:
			kind = ActionIcon.Kind.RIDE_BICYCLE
		elif kind_of == MountKinds.MOTORCYCLE:
			kind = ActionIcon.Kind.RIDE_MOTORCYCLE
		face.show_kind(kind)
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
	_coins_label.text = str(total)
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

## Opens on whichever page matches what is already happening, so a child who
## is hosting and reopens this sees their number rather than being asked again.
## Lay out again once the tree has actually removed the previous page's
## controls, since until then they still count towards the panel's size.
func _relayout_next_frame() -> void:
	await get_tree().process_frame
	if is_instance_valid(self):
		_layout()

func _open_together() -> void:
	_menu.visible = false
	together_opened.emit()
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

## A button whose face is drawn, not written. Square, because there is no word
## to make room for — which is also why these three stopped changing width
## between English, French and Russian.
func _icon_button(which: ActionIcon.Kind) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(BUTTON, BUTTON)
	button.focus_mode = Control.FOCUS_NONE

	var icon := ActionIcon.new(which)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(icon)
	return button

## The panel that asks a question: the words, a cross and a tick.
func _build_asking() -> void:
	_asking = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.12, 0.88)
	style.set_corner_radius_all(16)
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 16.0
	style.border_color = Color(1.0, 1.0, 1.0, 0.18)
	style.set_border_width_all(1)
	_asking.add_theme_stylebox_override("panel", style)
	_asking.visible = false
	add_child(_asking)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	_asking.add_child(column)

	_question = Label.new()
	_question.add_theme_font_size_override("font_size", 26)
	_question.add_theme_color_override("font_color", Color(1.0, 0.97, 0.90))
	_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_question)

	var answers := HBoxContainer.new()
	answers.add_theme_constant_override("separation", 26)
	answers.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(answers)

	answers.add_child(_answer_button("✗", Color(0.92, 0.36, 0.32), func() -> void:
		stop_asking()
		refused.emit()))
	answers.add_child(_answer_button("✓", Color(0.42, 0.82, 0.46), func() -> void:
		stop_asking()
		confirmed.emit()))

func _answer_button(face: String, colour: Color, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = face
	button.custom_minimum_size = Vector2(BUTTON * 1.5, BUTTON)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 40)
	button.add_theme_color_override("font_color", colour)
	button.add_theme_color_override("font_hover_color", colour.lightened(0.2))
	button.pressed.connect(pressed)
	return button

## The drawn face of a button made by _icon_button.
func _face_of(button: Button) -> ActionIcon:
	for child in button.get_children():
		if child is ActionIcon:
			return child
	return null

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
	var face := _face_of(_build_button)
	if face != null:
		face.show_kind(ActionIcon.Kind.CLOSE if enabled else ActionIcon.Kind.BUILD)
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

## Show or hide the kick button, and give it the right face: a kick for a
## ball on the ground, a throw for a basketball within range of the ring.
func set_ball_in_reach(in_reach: bool, throwing := false) -> void:
	var face := _face_of(_kick_button)
	if face != null:
		face.show_kind(ActionIcon.Kind.THROW if throwing else ActionIcon.Kind.KICK)
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
## Whether a child may talk at all. Set from the saved settings when the game
## opens, and by the switch in the menu after that.
func set_voice_allowed(allowed: bool) -> void:
	_voice_allowed = allowed
	_refresh_voice_switch()
	if not allowed and _talk_button.visible:
		_talk_button.visible = false
		_layout()

func voice_allowed() -> bool:
	return _voice_allowed

func _refresh_voice_switch() -> void:
	if _voice_switch == null:
		return
	_voice_switch.text = Text.of("ui_talk_on" if _voice_allowed else "ui_talk_off")
	_voice_switch.add_theme_color_override(
		"font_color",
		Color(0.62, 0.88, 0.68) if _voice_allowed else Color(1.0, 1.0, 1.0, 0.45)
	)

## Ask a yes-or-no question, with a cross and a tick under it.
##
## Nothing here takes a child's coins without being asked. Money is the record
## of everything they have done — fed an animal, sheared a sheep, grown a tree
## — and a ride that helps itself to a ticket because somebody walked too near
## it is the game taking that away by accident. So it asks, and it asks in
## pictures: a red cross and a green tick, which need no reading.
func ask(question: String) -> void:
	_question.text = question
	_asking.visible = true
	_layout()

func stop_asking() -> void:
	if not _asking.visible:
		return
	_asking.visible = false
	_layout()

func is_asking() -> bool:
	return _asking.visible

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
	# Bottom left, above the stick, where a thumb already rests — and far from
	# the buttons on the right that a child presses while playing.
	_talk_button.position = Vector2(
		safe.position.x + MARGIN,
		safe.position.y + safe.size.y - STICK_SIZE - BUTTON - MARGIN * 1.6
	)

	# Centred, because it is the only screen that takes the whole attention.
	#
	# Its height is not known until the page inside it has been laid out, and
	# _layout runs before that — so the first version ran off the bottom of the
	# screen. Clamped into the safe area rather than trusted to fit.
	together.size = together.get_combined_minimum_size()
	var room := safe.size - together.size
	together.position = Vector2(
		safe.position.x + maxf(room.x, 0.0) * 0.5,
		safe.position.y + maxf(room.y, 0.0) * 0.5
	)

	# The question, in the middle of the screen and a little above centre:
	# where a child is already looking, and clear of both thumbs.
	if _asking.visible:
		_asking.size = _asking.get_combined_minimum_size()
		_asking.position = Vector2(
			safe.position.x + (safe.size.x - _asking.size.x) * 0.5,
			safe.position.y + safe.size.y * 0.42 - _asking.size.y * 0.5
		)

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
	# The purse sits between the bag and the health, at the same right edge.
	_purse.size = Vector2(Backpack.WIDTH, _purse.get_combined_minimum_size().y)
	_purse.position = Vector2(
		safe.position.x + safe.size.x - Backpack.WIDTH - MARGIN,
		# Against the folded height, not the real one: the open bag is an overlay
		# that covers the purse rather than something the purse moves for.
		_backpack.position.y + _backpack.shut_height() + 8.0
	)

	# Under the purse, at the same right edge as the bag above it.
	_vitals.size = _vitals.custom_minimum_size
	_vitals.position = Vector2(
		safe.position.x + safe.size.x - VitalsGauge.WIDTH - MARGIN,
		_purse.position.y + _purse.size.y + 10.0
	)

	# The things you carry, down the right-hand edge under the gauges.
	#
	# This was a hand-written chain: each button worked out its own top from
	# whether the one above it happened to be showing. Adding a button meant
	# adding a link, and the two newest — the chocolate and the lantern — were
	# never given one, so they sat at the top left corner of the screen on top
	# of everything else. It also had no idea where the bottom of the screen
	# was, so a long column walked down into the jump and build buttons and the
	# three drew on top of one another.
	#
	# Now the column lays itself out: every button that is showing takes the
	# next slot, and when the next slot would reach the row along the bottom it
	# starts a second column inwards instead.
	var column_top := _vitals.position.y + _vitals.size.y + 10.0
	var column_x := safe.position.x + safe.size.x - BUTTON - MARGIN
	var floor_y := safe.position.y + safe.size.y - BUTTON * 2.0 - MARGIN
	var next_y := column_top
	for button: Button in [
		_drink_button, _snack_button, _lantern_button,
		_whistle_button, _chop_button, _ride_button,
	]:
		if not button.visible:
			continue
		if next_y + button.size.y > floor_y:
			# Out of room downwards: start again at the top, one column in.
			column_x -= BUTTON + 12.0
			next_y = column_top
		button.position = Vector2(column_x + BUTTON - button.size.x, next_y)
		next_y += button.size.y + 10.0

	# Low and centre-left of the kick button, since drawing a bow and striking a
	# ball are the same gesture and never both apply.
	_shoot_button.position = Vector2(
		safe.position.x + safe.size.x * 0.5 - _shoot_button.size.x * 0.5,
		safe.position.y + safe.size.y - BUTTON - MARGIN
	)

	# In a row to the left of jump, on the same line as the thumb's own buttons,
	# nearest first. They used to float centred above the bottom of the screen,
	# which put the swing button somewhere off to one side of the swing a child
	# was looking at; a contextual action belongs beside the thumb that will
	# press it, where every game a child has played puts it.
	#
	# One slot each, only for the ones currently showing. These used to share
	# one position on the assumption that a child is never at a dam, a café, a
	# fire and a bed simultaneously — false for a fire and a bed, which are both
	# ordinary house pieces built side by side. Two buttons on one spot means
	# one is invisible and unpressable.
	var context_x := _jump_button.position.x
	for button: Button in [_visit_button, _ticket_button, _dam_button, _fire_button, _sleep_button]:
		if not button.visible:
			continue
		context_x -= button.size.x + 16.0
		button.position = Vector2(context_x, _jump_button.position.y)

	# Centred low, where the kick button sits, since the two never both apply.
	_care_button.position = Vector2(
		safe.position.x + safe.size.x * 0.5 - _care_button.size.x * 0.5,
		safe.position.y + safe.size.y - BUTTON - MARGIN
	)

	# The shelf takes what is left of the screen after everything that has to be
	# on it: the heading above, and the name, the line about it, the buying
	# button and the way out below. Measured in rows of pictures rather than in
	# pictures — nine things in three columns is three rows, not nine — because
	# the first version asked for nine rows' worth of room, ran off the bottom
	# of the screen, and hid its own last row behind the way out.
	if _shop_shelf != null:
		# Everything on the shelf, not everything for sale: the things the shop
		# buys stand there too, and counting only the stock left the wool below
		# the fold with nothing to say it was there. A child who had just cut a
		# fleece could not find where to sell it.
		var rows := ceili(float(_shop_rows.size()) / float(SHOP_COLUMNS))
		var tile_height := BUTTON * 1.62 + 10.0
		# Always room for every row there is. A shelf that clips its last row
		# hides things a child has no way of knowing are there.
		# What is left of the screen after everything that has to be on it with
		# the shelf: the heading above, and the chosen thing's name, the line
		# about it, the buying button and the way out below. Measured generously
		# — the bottom row was being clipped by a hair, which reads as a row
		# that is not there.
		var shelf_room := safe.size.y - BUTTON * 4.6
		_shop_shelf.custom_minimum_size = Vector2(
			float(SHOP_COLUMNS) * (BUTTON * 1.5 + 10.0),
			maxf(float(rows) * tile_height + 12.0, BUTTON * 2.0)
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
