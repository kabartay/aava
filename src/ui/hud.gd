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
## The size of a thumb target. project.godot stretches the 1280 by 720 base to
## the screen's height, so on a 360 dp tall phone one base pixel is half a dp and
## 96 of them are the 48 dp that Android asks of a touch target. Taller screens
## scale it up, never down: a 4:3 tablet is wider and shorter per pixel only in
## the other direction, so the phone is the case that sets this.
const BUTTON := 96.0
## The space kept between neighbouring thumb targets, 8 dp on that phone.
const TOP_GAP := 16.0
## The side of a target meant for a three-year-old's finger: about 9 mm on a
## 2400 by 1080 phone at 510 dpi (121 base pixels, scaled 1.5, at 0.0498 mm a
## pixel). The 96 above is the grown-up's 48 dp, 7.2 mm there; a toddler's aim
## needs more, so the look picker and the first-run tick are this size.
const CHILD_TARGET := 121.0
## Seconds an untouched first-run panel waits before it puts itself away.
const OFFER_IDLE := 45.0

## The purse: a coin, a gap, and four digits at font 26.
const PURSE_WIDTH := 132.0
const MARGIN := 26.0

signal camera_dragged(delta: Vector2)
signal camera_zoomed(amount: float)
## Press and release, not a single tap: the strength of a kick is how long the
## button is held, so the interface has to report both ends of it.
signal kick_started()
signal kick_released()
signal jump_pressed()
## Going under the water, or coming back up: one button, both ways.
signal dive_toggled()
signal build_toggled(enabled: bool)
signal build_selected(kind: StringName)
signal build_place()
signal build_remove()
## Take back the last piece put up, wherever the child now stands.
signal build_undo()
## Which group of the palette is showing: one of the ids in BUILD_GROUPS.
signal build_tab(group: StringName)
## The storey buttons: +1 up, -1 down.
signal storey_step(step: int)
## The button that changes what new walls are made of.
signal build_material()
## The price a child's own cafe asks was switched between free and a coin.
signal cafe_price_toggled(paid: bool)

## The palette, in the groups a house is made of, then everything else.
##
## Thirteen pieces on two tabs, "things" and "house", gave a child the whole
## house at once in no order: a bed first, then walls, floor, two roofs, stairs
## and a post, with nothing to say which go together. Grouped the way a house
## goes up — walls, then the floor, then the roof, then what goes inside — each
## tab is a picture of its group. The plans come first: a whole room in one tap
## is where a child who has never built anything starts.
const BUILD_GROUPS := [
	{"id": &"plans", "text": "ui_group_plans", "icon": Plans.HOUSE,
		"kinds": [Plans.ROOM, Plans.HOUSE, Plans.CAFE, Plans.SHOP]},
	{"id": &"walls", "text": "ui_group_walls", "icon": HouseParts.WALL_DOOR,
		"kinds": [
			HouseParts.WALL, HouseParts.WALL_DOOR, HouseParts.WALL_WINDOW,
			HouseParts.WALL_WIDE, HouseParts.WALL_HALF, HouseParts.WALL_ARCH, HouseParts.POST,
		]},
	{"id": &"floor", "text": "ui_group_floor", "icon": HouseParts.FLOOR,
		"kinds": [HouseParts.FLOOR, HouseParts.STAIRS]},
	{"id": &"roof", "text": "ui_group_roof", "icon": HouseParts.ROOF_PEAK,
		"kinds": [
			HouseParts.ROOF_ROOM, HouseParts.ROOF_PEAK, HouseParts.ROOF,
			HouseParts.ROOF_FLAT, HouseParts.CHIMNEY,
		]},
	{"id": &"furniture", "text": "ui_group_furniture", "icon": HouseParts.BED,
		"kinds": [
			HouseParts.BED, HouseParts.TABLE, HouseParts.CHAIR, HouseParts.COUNTER,
			HouseParts.SHELF, HouseParts.LAMP, HouseParts.SIGN, HouseParts.POT, HouseParts.RUG,
		]},
	{"id": &"things", "text": "ui_things", "icon": BuildKinds.SAPLING,
		"kinds": BuildKinds.ALL},
]

## How many pieces stand in a row of the palette before the next row starts.
## Nine pieces in one row ran off both edges of a phone.
const PALETTE_ROW := 6

## The size of one piece in the palette: its picture, its name under it, and
## what it costs under that.
const PIECE_SIZE := Vector2(BUTTON * 1.12, BUTTON * 1.3)
## A group's tab: a smaller picture with its name under it.
const TAB_SIZE := Vector2(BUTTON * 1.05, BUTTON * 0.82)

## The pieces in one group of the palette, or none for a group it has not got.
static func group_kinds(group: StringName) -> Array:
	for entry: Dictionary in BUILD_GROUPS:
		if entry["id"] == group:
			return entry["kinds"]
	return []

## The group a piece is in.
static func group_of(kind: StringName) -> StringName:
	for entry: Dictionary in BUILD_GROUPS:
		if (entry["kinds"] as Array).has(kind):
			return entry["id"]
	return &"things"
signal language_chosen(code: StringName)
signal reset_requested()
signal care_pressed()
signal shop_toggled()
## Something owned is being sold back to the shop.
signal shop_sold_back(item: StringName)
## The camera is being moved between over the shoulder and behind the eyes.
signal view_toggled()
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

## A grown-up changed the sound in the settings: the volume of the valley's
## ambience and of the interface's sounds (0 to Mix.FULL), and whether
## everything is muted. Sent when a slider is let go, not on every step of it.
signal sound_changed(ambience: int, effects: int, muted: bool)

## A child typed their name in the settings panel.
signal name_chosen(name: String)

## A child picked a shirt in the settings, as an index into Visitors.SHIRTS.
signal shirt_chosen(which: int)

## A child picked who they are in the settings: [character, skin, hair].
signal look_chosen(look: Array)

## The panel a first run opens on was closed.
signal look_offer_closed()
signal talk_started()
signal talk_released()

var _stick: VirtualJoystick
var _backpack: Backpack
var _minimap: Minimap
var _guide_badge: GuideBadge
var _build_button: Button
var _palette: HFlowContainer
var _palette_buttons: Dictionary = {}
var _material_button: Button
var _material_swatch: PartIcon
## The pictures on the wall buttons, which take on the material chosen.
var _wall_icons: Array[PartIcon] = []
var _wall_material: StringName = HouseParts.DEFAULT_MATERIAL
var _material_name: Label
## The button that sets what a child's own cafe asks, shown at one.
var _price_button: Button
## The café's menu: six tiles to tap, and the name and worth of the one tapped.
var _cafe_menu: PanelContainer
var _dish_tiles: Dictionary = {}
var _dish_prices: Dictionary = {}
var _dish_name: Label
var _dish_note: Label
var _dish_chosen: StringName = Dishes.USUAL
var _cafe_menu_state: Array = []
var _cafe_paid := false
var _tabs: HBoxContainer
var _place_button: Button
var _remove_button: Button
var _undo_button: Button
## Opens on the things, as it always has: the first thing the game asks a child
## to build is a path stone.
var _group: StringName = &"things"
var _storey_row: HBoxContainer
## The line telling a child who has not built a house yet what to put up next.
var _hint: Label
var _menu: VBoxContainer
var _danger: PanelContainer
var _menu_button: Button
var _map_button: Button
var _view_button: Button
var _voice_button: Button
var _together_button: Button
var _name_field: LineEdit
## The faces, colour dots and clothes of the settings panel, and of the panel a
## first run opens on while it is open.
var _menu_picker: LookPicker
## The settings' door to the same choice at full size: a face that looks like
## the child, which opens the panel a first run opens on.
var _me_button: Button
var _me_face: CharacterIcon
var _ambience_slider: HSlider
var _effects_slider: HSlider
var _mute_button: Button
var _sound_ambience := Mix.FULL
var _sound_effects := Mix.FULL
var _sound_muted := false
var _offer: PanelContainer
var _offer_picker: LookPicker
var _player_name := ""
## How long the reset must be held. Long enough that a child cannot do it by
## accident or by curiosity, short enough that a parent does not wonder whether
## it is working.
const RESET_HOLD := 5.0

var _reset_button: Button
var _visit_ring: HoldRing
var _reset_ring: HoldRing
var _status: Label
var _message: Label
var _message_timer := 0.0
var _building := false
var _kick_button: Button
## The finger that is holding the kick button, so a second finger turning the
## camera is not mistaken for aiming; -1 while none is.
var _kick_finger := -1
## How far the finger has slid since pressing: x is the turn in radians (right
## is positive), y is the loft from 0 (flat) to 1 (a high chip).
var _kick_aim := Vector2.ZERO
var _pulse := 0.0
const KICK_PULSE_RATE := 6.0
var _score: Panel
## Which side this child is, under the score, when two are playing.
var _score_side: Label
var _score_blue: Label
var _score_colon: Label
var _score_red: Label
## Whether the child is on or beside the pitch, which is when the chip shows.
var _at_the_pitch := false

## The score chip's size, in pixels.
const SCORE_CHIP := Vector2(168.0, 44.0)
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
var _dive_button: Button
var _whistle_button: Button
var _chop_button: Button
var _chop_ring: HoldRing
## What the axe is in reach of, and the coins in the purse: between them they
## decide whether the axe button must be held.
var _tree_is_planted := false
var _coin_count := 0
var _ride_button: Button
var _shoot_button: Button
var _visit_button: Button
var _ticket_button: Button
var _asking: PanelContainer
## The crossed microphone and what to do about it, shown when the phone refuses
## the microphone. See show_mic_refused.
var _mic_notice: PanelContainer
var _mic_words: Label
var _mic_seconds := 0.0
## How long the first-run panel has sat untouched. A child who cannot read, and
## has not understood that the picture is a choice, must not be left looking at
## a panel that covers the stick: after OFFER_IDLE seconds it puts itself away,
## counting as asked, and the settings still hold the way back to it.
var _offer_idle := 0.0
var _question: Label
var _dam_button: Button
var _fire_button: Button
var _snack_button: Button
var _lantern_button: Button
var _sleep_button: Button
var together: TogetherPanel
var _talk_button: Button
## Whether a finger is on the talk button, kept here because a button that is
## hidden under a finger forgets it was pressed and never says it was let go.
var _talk_held := false
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
## Six across, not five. The shelf holds everything at once — a tile is a
## button, and a button eats the drag before the scrolling shelf sees it, so
## anything below the fold is unreachable — and the quad made eleven things,
## which is three rows at five and two rows at six.
const SHOP_COLUMNS := 6
## How many buttons' height the shop panel takes besides its shelf: heading, the
## chosen thing's name and line, the buy and sell buttons and the way out, and the
## panel's own margins.
const SHOP_CHROME := 3.9
## The picture a child has tapped, the two lines that answer them, and what is
## already theirs.
var _shop_chosen := &""
var _shop_owned: Dictionary = {}
## How many of each thing the child already has, so the shelf can say so
## without hiding what it costs.
var _shop_have: Dictionary = {}
var _shop_sell_back: Button
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
	# right-hand edge is placed under it. It changes *width* too, and is pinned
	# to the edge of the screen by that width — so without laying out again on
	# the change, an opened bag kept the shut bag's position and the extra
	# width went off the side of the screen, taking the item names with it.
	_backpack.opened_changed.connect(_layout)
	add_child(_backpack)

	_palette = _build_palette()
	add_child(_palette)

	_tabs = _build_tabs()
	add_child(_tabs)

	_status = _label(22, Color(1.0, 0.86, 0.55))
	add_child(_status)

	# The next step of a first house, above the rest of the building controls,
	# in the voice of the storey line rather than the status line's, so the
	# two are not read as one sentence.
	_hint = _label(22, Color(0.72, 0.90, 1.0))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.visible = false
	add_child(_hint)

	_build_asking()
	_build_mic_notice()

	_message = _label(30, Color(1.0, 1.0, 1.0))
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.modulate.a = 0.0
	add_child(_message)

	# The kick button only appears when there is a ball to kick, so it never
	# sits on screen as a control that does nothing.
	_kick_button = _icon_button(ActionIcon.Kind.KICK)
	# button_down / button_up rather than pressed, because a kick is a hold.
	_kick_button.button_down.connect(func() -> void:
		_kick_aim = Vector2.ZERO
		kick_started.emit()
	)
	_kick_button.button_up.connect(func() -> void:
		kick_released.emit()
		# After the release has read it, so the next kick starts straight.
		_kick_aim = Vector2.ZERO
		_kick_finger = -1
	)
	# The finger may slide off the button to aim; letting go anywhere still kicks.
	_kick_button.keep_pressed_outside = true
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

	# The football score: blue's number, a colon, red's number, each in its
	# side's own colour on a small dark chip so it reads over any sky. Shown only
	# on or beside the pitch, where there is a game to count.
	_score = Panel.new()
	_score.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip := StyleBoxFlat.new()
	chip.bg_color = Color(0.06, 0.07, 0.10, 0.62)
	chip.set_corner_radius_all(14)
	_score.add_theme_stylebox_override("panel", chip)
	_score.size = SCORE_CHIP
	_score_blue = _label(34, Goal.SIDE_COLOURS[0].lightened(0.25))
	_score_colon = _label(34, Color(0.96, 0.96, 0.94))
	_score_red = _label(34, Goal.SIDE_COLOURS[1].lightened(0.25))
	_score_colon.text = ":"
	_score_blue.text = "0"
	_score_red.text = "0"
	var third := SCORE_CHIP.x / 3.0
	for part: Array in [[_score_blue, 0.0], [_score_colon, third], [_score_red, third * 2.0]]:
		var label: Label = part[0]
		label.position = Vector2(float(part[1]), 0.0)
		label.size = Vector2(third, SCORE_CHIP.y)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_score.add_child(label)
	_score_side = _label(22, Color(1.0, 1.0, 1.0))
	_score_side.position = Vector2(0.0, SCORE_CHIP.y - 4.0)
	_score_side.size = Vector2(SCORE_CHIP.x, SIDE_ROW)
	_score_side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_side.visible = false
	_score.add_child(_score_side)
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
	# Held, not tapped: one press takes down a whole piece with all that stands
	# on it, and a toddler's finger finds this button as readily as any.
	_hold(_remove_button, func() -> void: build_remove.emit())
	_remove_button.visible = false
	add_child(_remove_button)

	# Undo, beside the minus. The minus takes down whatever is nearest, which
	# after a wall went on the wrong edge may well be the floor underfoot; this
	# takes back the piece just put up, and refunds it the same way.
	_undo_button = _button("", Color(0.96, 0.86, 0.56))
	var undo_face := PartIcon.new(PartIcon.UNDO)
	undo_face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_undo_button.add_child(undo_face)
	# Held too: one undo takes back a whole plan, every piece that went up with it.
	_hold(_undo_button, func() -> void: build_undo.emit())
	_undo_button.visible = false
	add_child(_undo_button)

	# Which storey the ghost is on, with a button either side to change it,
	# shown only while a house piece is chosen. Walls stack and roofs find the
	# top of the walls by themselves; this is for a floor laid upstairs.
	_storey_row = HBoxContainer.new()
	_storey_row.add_theme_constant_override("separation", 10)
	_storey_row.alignment = BoxContainer.ALIGNMENT_CENTER
	# The row is as wide as the screen so its buttons can be centred; the row
	# itself must not swallow a drag meant for turning the view.
	_storey_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_storey_row.visible = false
	add_child(_storey_row)
	_storey_row.add_child(_storey_button(PartIcon.STOREY_DOWN, -1))
	_storey_label = _label(22, Color(0.72, 0.90, 1.0))
	_storey_label.custom_minimum_size = Vector2(170.0, 0.0)
	_storey_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_storey_row.add_child(_storey_label)
	_storey_row.add_child(_storey_button(PartIcon.STOREY_UP, 1))

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
	# Wide enough for the coin and four digits, which is the most a child can
	# have — see Wallet.MAX_COINS. Sized to the number rather than to the bag
	# below it, so the corner holds still instead of the purse growing as the
	# afternoon goes on.
	_purse.custom_minimum_size = Vector2(PURSE_WIDTH, 0.0)
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
	# A wild tree is a tap for a child with no coins; a tree a child planted and
	# grew is their work, and a felled wild tree is paid for in coins, so one
	# stray tap of a toddler's must not fell either. The ring is told which this
	# is by set_tree_in_reach, and by set_coins, which can change the answer.
	_chop_ring = _hold(_chop_button, func() -> void: chop_pressed.emit())
	_chop_ring.needed = false
	_chop_button.pressed.connect(func() -> void:
		if not _chop_ring.needed:
			chop_pressed.emit())
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
	# The bow is aimed the way the kick is: the finger slides on the held
	# button (see _input), sideways to turn, up to lift.
	_shoot_button.button_down.connect(func() -> void:
		_kick_aim = Vector2.ZERO
		shoot_started.emit()
	)
	_shoot_button.button_up.connect(func() -> void:
		shoot_released.emit()
		# After the release has read it, so the next draw starts straight.
		_kick_aim = Vector2.ZERO
		_kick_finger = -1
	)
	_shoot_button.keep_pressed_outside = true
	add_child(_shoot_button)

	# One button for whatever the place a child is standing in offers, labelled
	# by the place. A separate control per destination would mean three buttons
	# of which two are always inert.
	_visit_button = _icon_button(ActionIcon.Kind.SWING)
	_visit_button.visible = false
	# A swing is a tap; a meal, the shop's counter and a new game are not. The
	# ring is told which this place is by set_place_offer.
	_visit_ring = _hold(_visit_button, func() -> void: place_used.emit())
	_visit_button.pressed.connect(func() -> void:
		if not _visit_ring.needed:
			place_used.emit())
	add_child(_visit_button)

	# At a cafe the child built, what a meal costs is theirs to say: nothing for
	# half a meal's energy, or a coin for a whole one.
	_price_button = _button("", Color(1.0, 0.94, 0.72))
	_price_button.add_theme_font_size_override("font_size", 28)
	_price_button.visible = false
	_price_button.pressed.connect(func() -> void:
		_cafe_paid = not _cafe_paid
		_refresh_price_button()
		cafe_price_toggled.emit(_cafe_paid))
	add_child(_price_button)
	_refresh_price_button()

	_ticket_button = _icon_button(ActionIcon.Kind.TICKET)
	_ticket_button.visible = false
	# Held: a ticket spends coins, and a tap is not a decision.
	_hold(_ticket_button, func() -> void: ticket_pressed.emit())
	add_child(_ticket_button)

	# Only shown at a dam site, with a stick in the bag.
	_dam_button = _icon_button(ActionIcon.Kind.GIVE_STICK)
	_dam_button.visible = false
	# Held: a stick given to the dam is gone for good, and sticks are what a
	# child went into the forest for.
	_hold(_dam_button, func() -> void: dam_stick.emit())
	add_child(_dam_button)

	# Shown at a campfire, with wood in the bag.
	_lantern_button = _icon_button(ActionIcon.Kind.LANTERN)
	_lantern_button.visible = false
	_lantern_button.pressed.connect(func() -> void: lantern_pressed.emit())
	add_child(_lantern_button)

	_snack_button = _icon_button(ActionIcon.Kind.SNACK)
	_snack_button.visible = false
	# Held: a bar of chocolate eaten by a stray tap is coins eaten with it.
	_hold(_snack_button, func() -> void: snack_pressed.emit())
	add_child(_snack_button)

	_fire_button = _icon_button(ActionIcon.Kind.FEED_FIRE)
	_fire_button.visible = false
	# Held: a log on the fire is burnt, and a toddler beside a campfire presses
	# whatever is lit until the wood is gone.
	_hold(_fire_button, func() -> void: fire_fed.emit())
	add_child(_fire_button)

	# Shown at a bed, and only when there is a night to sleep through.
	_sleep_button = _icon_button(ActionIcon.Kind.SLEEP)
	_sleep_button.visible = false
	_sleep_button.pressed.connect(func() -> void: slept.emit())
	add_child(_sleep_button)

	# Only while swimming, and beside the jump button, because going down is
	# the other half of what that thumb already does in the water.
	_dive_button = _icon_button(ActionIcon.Kind.DIVE)
	_dive_button.visible = false
	_dive_button.pressed.connect(func() -> void: dive_toggled.emit())
	add_child(_dive_button)
	add_child(_purse)

	_shop = _build_shop()
	add_child(_shop)
	# Centred by its own size, which changes when a thing is tapped and the
	# buying and selling buttons appear under it. Nothing laid the screen out
	# again then, so the panel grew downwards from where it had been centred,
	# and tapping a bicycle a child already owned pushed "back" off the bottom
	# of the screen.
	_shop.resized.connect(_layout)

	_cafe_menu = _build_cafe_menu()
	add_child(_cafe_menu)
	_cafe_menu.resized.connect(_layout)

	_menu_button = _icon_button(ActionIcon.Kind.SETTINGS)
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
	_talk_button.button_down.connect(func() -> void:
		_talk_held = true
		talk_started.emit())
	_talk_button.button_up.connect(_let_go_of_talk)
	add_child(_talk_button)

	_danger = _build_danger()
	add_child(_danger)
	# The settings and the grown-ups' room open down the left side, over the
	# stick's corner: with the stick drawn on top, its ring covered the sound
	# rows. While either is open there is nothing to walk with anyway.
	_menu.visibility_changed.connect(_hide_the_stick_under_panels)
	_danger.visibility_changed.connect(_hide_the_stick_under_panels)

	# A toggle of its own, next to the menu, so the map can always be brought
	# back. It shows its state: filled when the map is open.
	_map_button = _icon_button(ActionIcon.Kind.MAP)
	_map_button.pressed.connect(_toggle_map)
	add_child(_map_button)

	# And the third: which way round the camera sits. Beside the menu and the
	# map because it belongs to the same family — things about looking at the
	# valley rather than things about doing something in it.
	_view_button = _icon_button(ActionIcon.Kind.VIEW_FIRST)
	_view_button.pressed.connect(func() -> void: view_toggled.emit())
	add_child(_view_button)

	# And the fourth: the microphone. It lived at the bottom of the menu, two
	# taps away behind a button a child does not open mid-game — which is no
	# use for the one control somebody wants the instant they decide they would
	# rather not be heard. Up here it is always in sight and always one tap,
	# and it shows its own state: barred means nobody can hear you.
	# Playing together, in the same family and for the same reason: deciding to
	# invite a brother in happens mid-game, and it used to be two taps down
	# inside the menu.
	_together_button = _icon_button(ActionIcon.Kind.TOGETHER)
	_together_button.pressed.connect(_open_together)
	add_child(_together_button)

	_voice_button = _icon_button(ActionIcon.Kind.MIC_ON)
	_voice_button.pressed.connect(func() -> void:
		set_voice_allowed(not _voice_allowed)
		voice_allowed_changed.emit(_voice_allowed))
	add_child(_voice_button)

func _ready() -> void:
	# Everything above is built in _init, so a caller can use this HUD's
	# buttons and labels on the very same line it adds the node to the tree.
	# Only get_viewport() needs the tree, so only this waits for _ready.
	_layout()
	get_viewport().size_changed.connect(_layout)

func _build_palette() -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 12)
	row.add_theme_constant_override("v_separation", 8)
	row.visible = false
	# A picture of the thing rather than a letter, for the objects as well as
	# the house parts: "T" for a sapling and "Y" for a bird feeder are as
	# unreadable as "z" was for stairs, and an icon a child has to be taught
	# is an icon that does not work.
	for entry: Dictionary in BUILD_GROUPS:
		for kind: StringName in entry["kinds"]:
			var named := HouseParts.label(kind) if HouseParts.is_house_part(kind) else BuildKinds.label(kind)
			row.add_child(_palette_button(kind, named, entry["id"] == _group))
	_material_button = _build_material_button()
	_material_button.visible = _group == &"walls"
	row.add_child(_material_button)
	return row

## The button that changes what walls are made of: a swatch of the colour they
## will be, with the material's name under it. One button, pressed round and
## round, because four more buttons would not fit beside seven wall pieces.
func _build_material_button() -> Button:
	var button := _button("", Color(0.86, 0.86, 0.90))
	_material_button = button
	button.custom_minimum_size = Vector2(PIECE_SIZE.x * 0.9, PIECE_SIZE.y)
	# A wall in the material, not a bare colour: the button says "walls will be
	# like this", in the picture the wall buttons beside it are drawn in.
	_material_swatch = PartIcon.new(HouseParts.WALL)
	var picture := PIECE_SIZE.y * 0.5
	_material_swatch.position = Vector2((button.custom_minimum_size.x - picture) * 0.5, 8.0)
	_material_swatch.size = Vector2(picture, picture)
	button.add_child(_material_swatch)
	_material_name = _label(15, Color(1.0, 0.97, 0.90))
	_material_name.clip_text = true
	_material_name.position = Vector2(2.0, picture + 8.0)
	_material_name.size = Vector2(button.custom_minimum_size.x - 4.0, 24.0)
	button.add_child(_material_name)
	button.pressed.connect(func() -> void: build_material.emit())
	set_material(HouseParts.DEFAULT_MATERIAL)
	return button

## Show what walls are made of now, on the material button.
func set_material(material: StringName) -> void:
	_wall_material = material
	if _material_swatch == null:
		return
	_material_swatch.set_wall_material(material)
	for icon in _wall_icons:
		icon.set_wall_material(material)
	_material_name.text = HouseParts.material_label(material)
	_material_button.tooltip_text = _material_name.text

## One button in the palette: a drawing of the piece, its name under it for
## whoever can read, what it costs under that — so a child can see before
## choosing that a window needs a reed — and the piece's own name emitted when
## it is pressed.
func _palette_button(kind: StringName, named: String, shown: bool) -> Button:
	var button := _button("", Color(0.86, 0.86, 0.90))
	button.custom_minimum_size = PIECE_SIZE
	var picture := PIECE_SIZE.y * 0.62
	var icon := PartIcon.new(kind)
	icon.position = Vector2((PIECE_SIZE.x - picture) * 0.5, 0.0)
	icon.size = Vector2(picture, picture)
	button.add_child(icon)
	if HouseParts.is_wall(kind):
		icon.set_wall_material(_wall_material)
		_wall_icons.append(icon)

	var name_label := _label(17, Color(1.0, 0.97, 0.90))
	name_label.text = named
	name_label.clip_text = true
	name_label.position = Vector2(2.0, picture - 6.0)
	name_label.size = Vector2(PIECE_SIZE.x - 4.0, 24.0)
	# A name wider than the button gets smaller type rather than losing both
	# ends of itself: "низкая стена" was read as "изкая стена".
	var font := name_label.get_theme_font("font")
	var type_size := 17
	while type_size > 12 and font.get_string_size(
		named, HORIZONTAL_ALIGNMENT_LEFT, -1, type_size
	).x > PIECE_SIZE.x - 8.0:
		type_size -= 1
	name_label.add_theme_font_size_override("font_size", type_size)
	button.add_child(name_label)

	var cost := HBoxContainer.new()
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost.alignment = BoxContainer.ALIGNMENT_CENTER
	cost.add_theme_constant_override("separation", 2)
	cost.position = Vector2(0.0, picture + 18.0)
	cost.size = Vector2(PIECE_SIZE.x, 24.0)
	# A plan is dozens of pieces: its price does not fit under a picture, and is
	# read off the status line once it is chosen. So is a whole roof's, which is
	# charged by the squares it covers: two reeds on its button was the price of
	# one square, and a room of four paid eight.
	var price := {}
	if HouseParts.is_house_part(kind):
		if kind != HouseParts.ROOF_ROOM:
			price = HouseParts.cost(kind)
	elif not Plans.is_plan(kind):
		price = BuildKinds.cost(kind)
	for item: StringName in price:
		var amount := _label(18, Color(1.0, 0.94, 0.72))
		amount.text = str(int(price[item]))
		cost.add_child(amount)
		var chip := ItemChip.new(item)
		chip.custom_minimum_size = Vector2(22.0, 22.0)
		cost.add_child(chip)
	button.add_child(cost)

	button.tooltip_text = named
	button.pressed.connect(func() -> void: build_selected.emit(kind))
	button.visible = shown
	_palette_buttons[kind] = button
	return button

## One of the two storey buttons: an arrow, and a step up or down.
func _storey_button(arrow: StringName, step: int) -> Button:
	var button := _button("", Color(0.72, 0.90, 1.0))
	# The same size as every other thumb target: at 0.66 of it these were 63
	# pixels, about 32 dp on a phone, and a three-year-old's fingertip is wider.
	button.custom_minimum_size = Vector2(BUTTON, BUTTON)
	var face := PartIcon.new(arrow)
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(face)
	button.pressed.connect(func() -> void: storey_step.emit(step))
	return button

## The group tabs: a picture of each group, its name small underneath.
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

	# Who they are: a big picture of them, which opens the panel of faces, skin,
	# hair and colours at full size — the same panel a first run opens on, with
	# the same large targets — and the name beside it.
	#
	# The choices used to be listed here, in a row of small dots, in the one
	# panel a child opens by tapping a gear. Four millimetres across, they were
	# a game of chance for a small finger, and there was no room on a phone's
	# height to make them bigger *and* keep the language, the volume and the
	# parents' door in the same place. So the panel of choices has one home, and
	# here is a door to it.
	var who_row := HBoxContainer.new()
	who_row.add_theme_constant_override("separation", int(TOP_GAP))
	_me_button = Button.new()
	_me_button.focus_mode = Control.FOCUS_NONE
	_me_button.custom_minimum_size = Vector2(CHILD_TARGET, CHILD_TARGET)
	_me_face = CharacterIcon.new(Character.SIMPLE)
	_me_face.set_anchors_preset(Control.PRESET_FULL_RECT)
	_me_face.offset_left = 5.0
	_me_face.offset_top = 5.0
	_me_face.offset_right = -5.0
	_me_face.offset_bottom = -5.0
	_me_button.add_child(_me_face)
	_me_button.pressed.connect(offer_look)
	who_row.add_child(_me_button)

	var who_column := VBoxContainer.new()
	who_column.add_theme_constant_override("separation", 4)
	who_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who_row.add_child(who_column)
	var who := Label.new()
	who.text = Text.of("ui_your_name")
	who.add_theme_font_size_override("font_size", 20)
	who.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.55))
	who_column.add_child(who)

	# The one place in this game with a keyboard in it.
	#
	# Everything else a child touches is a button or a keypad, because a
	# six-year-old cannot type — but a name has to be typed once by somebody,
	# and the alternative is that every brother in the valley is called
	# "Игрок". Typed once, in the settings, and then never again: what the
	# join screen asks for afterwards is a tap on a name that already exists.
	_name_field = LineEdit.new()
	_name_field.placeholder_text = Text.of("ui_name_hint")
	_name_field.max_length = Profiles.MAX_NAME
	_name_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_field.custom_minimum_size = Vector2(BUTTON * 3.4, BUTTON * 0.7)
	_name_field.add_theme_font_size_override("font_size", 22)
	# Tapping it has to be made to work by hand.
	#
	# `pointing/emulate_mouse_from_touch` is off in project.godot — deliberately,
	# because it fires a synthetic click before the real touch and every tap
	# arrives twice — and a LineEdit only takes focus from a *mouse* button.
	# Buttons handle a touch themselves, so every other control on this panel
	# worked and this one did nothing at all: a child tapped "tap to type it"
	# and no keyboard came up.
	_name_field.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
			# Only the tap that takes focus opens the keyboard. Showing it again
			# on every later tap — such as one placing the caret in the middle of
			# the name to delete part of it — hands the virtual keyboard the
			# field's text once more and it answers by putting the caret back at
			# the end: a child aiming a tap between two words to erase the first
			# one always landed back after the last letter, and could never erase
			# anything but the whole name.
			var already_focused := _name_field.has_focus()
			_name_field.grab_focus()
			if not already_focused and DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
				DisplayServer.virtual_keyboard_show(
					_name_field.text, Rect2(), DisplayServer.KEYBOARD_TYPE_DEFAULT,
					Profiles.MAX_NAME
				)
			# A LineEdit places its caret from a mouse click, which nothing on
			# Android ever sends it — a synthetic one raised through
			# Input.parse_input_event() was tried first and never arrived either,
			# measured by printing the caret before and after: it held the
			# field's caret wherever typing had last left it, the start or the
			# end, so a tap meant to land between two words — to erase the first
			# and keep the second — did nothing at all. The column is placed by
			# hand instead, measured in the same font this field is drawn in.
			_place_caret_at(event.position.x)
	)
	_name_field.text_submitted.connect(func(typed: String) -> void:
		# An empty field is a child who rubbed the name out and changed their
		# mind, not a name: it keeps the old one, and says nothing.
		if not typed.strip_edges().is_empty():
			name_chosen.emit(typed)
		_name_field.release_focus()
		# Put back whatever was accepted. Dismissing the on-screen keyboard
		# leaves the field empty, so a child who typed their name, pressed the
		# tick and looked back saw "tap to type it" again and no reason to
		# believe it had worked.
		_name_field.text = _player_name)
	# Leaving the field counts as finishing with it: a child who types their
	# name and then taps the map has still told us their name.
	_name_field.focus_exited.connect(func() -> void:
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
			DisplayServer.virtual_keyboard_hide()
		# Left empty it was once sent as a name, and the game answered a child
		# who had typed nothing with "letters, numbers and spaces". The old
		# name stays, and goes back into the field.
		if _name_field.text.strip_edges().is_empty():
			_name_field.text = _player_name
		elif _name_field.text.strip_edges() != _player_name:
			name_chosen.emit(_name_field.text))
	who_column.add_child(_name_field)
	column.add_child(who_row)

	# What the panel of choices starts from, and holds the child's choice for
	# the checks and for the panel that opens: never shown, its faces are the
	# panel's.
	_menu_picker = LookPicker.new(BUTTON * 0.8)
	_menu_picker.look_chosen.connect(func(look: Array) -> void: look_chosen.emit(look))
	_menu_picker.shirt_chosen.connect(func(which: int) -> void: shirt_chosen.emit(which))
	_menu_picker.visible = false
	column.add_child(_menu_picker)

	var heading := Label.new()
	heading.text = Text.of("ui_language")
	heading.add_theme_font_size_override("font_size", 20)
	heading.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.55))
	column.add_child(heading)

	# Flags rather than the names of the languages. "English", "Français",
	# "Русский" is a reading task standing in front of the button that makes
	# the game readable — and a child who cannot yet read "Русский" can pick
	# the white-blue-red one out of a row without being taught.
	var flags := HBoxContainer.new()
	flags.add_theme_constant_override("separation", int(TOP_GAP))
	for code: StringName in Text.LANGUAGES:
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		# Bigger than the first attempt. Three of these are three stripes and
		# survive being tiny; the Circassian one is twelve stars and three
		# arrows over a green field, and at fifty pixels across it was a green
		# rectangle with nothing on it at all.
		# Half as wide and half as tall as a thumb button (owner, 2026-11-04: the
		# full-size row was the loudest thing in the settings). Changing language
		# is a hold and a grown-up's job, so a smaller target costs a child
		# nothing; the flags keep their own three-to-two shape.
		button.custom_minimum_size = Vector2(BUTTON * 0.7, BUTTON * 0.5)
		button.tooltip_text = Text.ENDONYM[code]
		var flag := FlagIcon.new(FlagIcon.for_language(code))
		flag.set_anchors_preset(Control.PRESET_FULL_RECT)
		flag.offset_left = 3.0
		flag.offset_top = 3.0
		flag.offset_right = -3.0
		flag.offset_bottom = -3.0
		button.add_child(flag)
		# Held: a change of language rebuilds the whole interface under a
		# child who did not mean it, in words they may not read.
		_hold(button, func() -> void: language_chosen.emit(code))
		flags.add_child(button)
	column.add_child(flags)

	# The volume, for a grown-up: two sliders, one for the valley's ambience
	# (a note) and one for the interface's own sounds (a coin), and
	# a speaker that silences everything. Slim, like the volume bar on any
	# phone: the owner found the old rows of tall bars far too big.
	#
	# The speaker is a hold: a game gone silent under a finger that was only
	# exploring is a game a parent thinks is broken. A slider has to be dragged
	# or pressed on its track, which a passing tap rarely does, and the change
	# is only kept when it is let go.
	_mute_button = _icon_button(ActionIcon.Kind.SPEAKER_ON)
	_mute_button.custom_minimum_size = Vector2(VOLUME_ROW, VOLUME_ROW)
	_hold(_mute_button, func() -> void: _sound_edited(_sound_ambience, _sound_effects, not _sound_muted))
	_ambience_slider = _build_volume_row(ActionIcon.new(ActionIcon.Kind.SOUND_AMBIENCE), _mute_button)
	column.add_child(_volume_row_of(_ambience_slider))
	# A coin for the interface's sounds: the coin is the one everybody knows,
	# and the burst of sparks drawn this small read as a plus.
	_effects_slider = _build_volume_row(CoinIcon.new(), null)
	column.add_child(_volume_row_of(_effects_slider))

	# Playing together used to have a row here. It has its own button in the top
	# bar now, beside the map and the microphone, and a second way in from two
	# taps down inside the settings is just somewhere else for it to be.

	# A quiet way through to the dangerous room, worded so an adult knows it is
	# for them and a child has no reason to want it.
	var door := _button(Text.of("ui_danger"), Color(1.0, 1.0, 1.0, 0.42))
	door.custom_minimum_size = Vector2(BUTTON * 2.2, BUTTON * 0.62)
	door.add_theme_font_size_override("font_size", 17)
	door.pressed.connect(func() -> void:
		_menu.visible = false
		_danger.visible = true
		# Over the map, for the reason the menu is: this room opens in the same
		# corner as the map, and came up underneath it with half of the warning
		# and the button to hold covered — and holding there grew the map
		# over the rest of it.
		_danger.move_to_front()
		_layout())
	column.add_child(door)
	return column

## The height of a volume row, and the width of its slider: a finger-sized
## knob on a slim track, the shape of a phone's own volume bar.
const VOLUME_ROW := 64.0
const VOLUME_WIDTH := 300.0
const VOLUME_KNOB := 34

## One row of the volume: (on the first row) the mute, then a pill with a small
## picture of what it turns and its slider. The slider is returned; the pill
## is _volume_pill_of it, and the whole row _volume_row_of it.
func _build_volume_row(face: Control, lead: Button) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(TOP_GAP * 0.5))
	if lead != null:
		row.add_child(lead)
	else:
		# The mute's width, left empty, so the two pills line up.
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(VOLUME_ROW, VOLUME_ROW)
		row.add_child(spacer)
	var pill := PanelContainer.new()
	var ground := StyleBoxFlat.new()
	ground.bg_color = Color(1.0, 1.0, 1.0, 0.1)
	ground.set_corner_radius_all(int(VOLUME_ROW * 0.5))
	ground.content_margin_left = 14.0
	ground.content_margin_right = 22.0
	pill.add_theme_stylebox_override("panel", ground)
	pill.custom_minimum_size = Vector2(0.0, VOLUME_ROW)
	row.add_child(pill)
	var inside := HBoxContainer.new()
	inside.add_theme_constant_override("separation", 12)
	pill.add_child(inside)
	var picture := Control.new()
	picture.custom_minimum_size = Vector2(VOLUME_ROW * 0.62, VOLUME_ROW * 0.62)
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	picture.add_child(face)
	inside.add_child(picture)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = Mix.FULL
	slider.step = 1.0
	slider.value = Mix.FULL
	slider.focus_mode = Control.FOCUS_NONE
	slider.custom_minimum_size = Vector2(VOLUME_WIDTH, VOLUME_ROW)
	slider.size_flags_vertical = Control.SIZE_FILL
	_style_volume_slider(slider)
	# Heard while it moves, so the grown-up can find the level by ear; kept
	# (and saved, with a chime) once it is let go.
	slider.value_changed.connect(func(_value: float) -> void: _volume_moved())
	slider.drag_ended.connect(func(_changed: bool) -> void: _volume_let_go())
	inside.add_child(slider)
	return slider

## The rounded ground a volume slider sits in, with its picture.
static func _volume_pill_of(slider: HSlider) -> PanelContainer:
	return slider.get_parent().get_parent() as PanelContainer

## The whole row a volume slider is in, the mute or its space included.
static func _volume_row_of(slider: HSlider) -> HBoxContainer:
	return _volume_pill_of(slider).get_parent() as HBoxContainer

## A slim track, lit up to the knob, and a round knob: the look of a phone's
## own volume bar.
func _style_volume_slider(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1.0, 1.0, 1.0, 0.22)
	track.set_corner_radius_all(4)
	track.content_margin_top = 4.0
	track.content_margin_bottom = 4.0
	slider.add_theme_stylebox_override("slider", track)
	var lit := track.duplicate() as StyleBoxFlat
	lit.bg_color = VolumeLook.LIT
	slider.add_theme_stylebox_override("grabber_area", lit)
	slider.add_theme_stylebox_override("grabber_area_highlight", lit)
	var knob := VolumeLook.knob(VOLUME_KNOB)
	slider.add_theme_icon_override("grabber", knob)
	slider.add_theme_icon_override("grabber_highlight", knob)

## A slider is moving: the mixer follows it at once, nobody is told yet.
func _volume_moved() -> void:
	_sound_ambience = int(_ambience_slider.value)
	_sound_effects = int(_effects_slider.value)
	Mix.set_volume(_sound_ambience, _sound_effects)

## A slider was let go: what it shows is the grown-up's choice.
func _volume_let_go() -> void:
	_sound_edited(int(_ambience_slider.value), int(_effects_slider.value), _sound_muted)

## A grown-up let go of a slider or held the speaker: take it, show it, tell
## the game.
func _sound_edited(ambience: int, effects: int, muted: bool) -> void:
	set_sound(ambience, effects, muted)
	sound_changed.emit(_sound_ambience, _sound_effects, _sound_muted)

## Show this sound setting, without telling anybody: the game's saved choice
## on start, and again whenever the interface is rebuilt.
func set_sound(ambience: int, effects: int, muted: bool) -> void:
	_sound_ambience = clampi(ambience, 0, Mix.FULL)
	_sound_effects = clampi(effects, 0, Mix.FULL)
	_sound_muted = muted
	if _ambience_slider != null:
		_ambience_slider.set_value_no_signal(_sound_ambience)
		_effects_slider.set_value_no_signal(_sound_effects)
		var face := _face_of(_mute_button)
		if face != null:
			face.show_kind(ActionIcon.Kind.SPEAKER_OFF if muted else ActionIcon.Kind.SPEAKER_ON)
		# A muted game dims the pills that no longer do anything; the speaker
		# itself stays bright, it is the way back.
		var shade := Color(1.0, 1.0, 1.0, 0.45 if muted else 1.0)
		for slider: HSlider in [_ambience_slider, _effects_slider]:
			_volume_pill_of(slider).modulate = shade

func sound_state() -> Array:
	return [_sound_ambience, _sound_effects, _sound_muted]

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
	# The same ring as every other hold, so a finger that slides off, a call
	# that pauses the game or a menu that closes stops the count; the count
	# used to run on until a button_up that might never come.
	_reset_ring = _hold(_reset_button, func() -> void:
		_reset_button.text = Text.of("ui_reset_hold")
		reset_requested.emit())
	_reset_ring.seconds = RESET_HOLD
	column.add_child(_reset_button)

	var back := _button(Text.of("ui_back"), Color(0.90, 0.93, 0.97))
	back.custom_minimum_size = Vector2(BUTTON * 3.4, BUTTON * 0.62)
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(func() -> void:
		_danger.visible = false
		_reset_ring.cancel()
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
	# A second one may always be bought: what a child pays for is the thing,
	# not the right to have one, and the shop refuses only when they have as
	# many as they are allowed.
	#
	# Held, as is selling back: both move coins, and selling wool empties the
	# bag in one go.
	_hold(_shop_buy_button, func() -> void:
		if _shop_chosen != &"":
			shop_buy.emit(_shop_chosen)
	)
	column.add_child(_shop_buy_button)

	# And the way back out of a purchase: the shop takes a thing back for half
	# what it charged. A child who saved ninety-nine coins for a bicycle and
	# finds they wanted the quad should not be stuck with the bicycle.
	_shop_sell_back = _button("", Color(0.62, 0.92, 0.66))
	_shop_sell_back.custom_minimum_size = Vector2(BUTTON * 3.0, BUTTON * 0.62)
	_shop_sell_back.add_theme_font_size_override("font_size", 19)
	_shop_sell_back.visible = false
	_hold(_shop_sell_back, func() -> void:
		if _shop_chosen != &"":
			shop_sold_back.emit(_shop_chosen)
	)
	column.add_child(_shop_sell_back)

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
		# Not left showing what the last thing tapped could be sold back for:
		# its button would go on saying so under the name of something else.
		_refresh_shop_sell_back()
		_shop_mark_chosen()
		return
	_shop_name.text = ShopStock.label(item)
	var have := int(_shop_have.get(item, 0))
	if have > 0:
		_shop_name.text += "   ×%d" % have
	_shop_note.text = ShopStock.description(item)
	_refresh_shop_buy()
	_refresh_shop_sell_back()
	_shop_mark_chosen()

## The buying button: what it would cost, or that it is already yours.
## The button for selling a thing back. Shown only when there is one to sell,
## because an empty offer is a question a child has to answer for no reason.
func _refresh_shop_sell_back() -> void:
	if _shop_sell_back == null:
		return
	var many := int(_shop_have.get(_shop_chosen, 0))
	var wanted := _shop_chosen != &"" and many > 0 and ShopStock.pays_for(_shop_chosen) <= 0
	_shop_sell_back.visible = wanted
	if wanted:
		_shop_sell_back.text = "%s  %d ●" % [
			Text.of("ui_sell"), ShopStock.sells_back(_shop_chosen)
		]

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
	else:
		# Just "buy". The price is on the shelf beside the thing, where it can
		# be read while choosing rather than only after choosing — and a second
		# one may always be bought, because what a child pays for is the thing
		# and not the right to have one.
		_shop_buy_button.text = Text.of("ui_buy")
		# Greyed for too dear and for as many as the child may have; the tap on
		# the picture still says what it is, and "×2" beside it says why.
		_shop_buy_button.disabled = (
			_shop_coins < ShopStock.price(_shop_chosen)
			or int(_shop_have.get(_shop_chosen, 0)) >= ShopStock.limit(_shop_chosen)
		)

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
	if int(_shop_carried.get(item, 0)) == many:
		return
	_shop_carried[item] = many
	# Told while the shelf is open as well as before it: a child who has just
	# sold their wool was left looking at "sell 12" on a button that was still
	# lit, and a tap on it was refused with nothing said.
	if _shop.visible and _shop_rows.has(item):
		var row: Button = _shop_rows[item]["button"]
		row.modulate = Color.WHITE if many > 0 else Color(1.0, 1.0, 1.0, 0.45)
		_refresh_shop_buy()

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
		# Over the map, as the settings are: the map is added last so that it
		# draws above everything, and its corner sat across the first picture
		# on the shelf, the chocolate, taking the taps meant for it.
		_shop.move_to_front()
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
			var many := int(owned.get(item, 0))
			# The price is always shown, with the coin beside the number: a
			# bare "12" does not say what it is asking for, and a tick in place
			# of a price left a child unable to see what the thing costs the
			# moment they had one. What they have is said beside it instead.
			price_label.text = "%d ●" % price
			price_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.52))
			if many > 0:
				price_label.text = "%d ●   ×%d" % [price, many]
			# Dim for too dear, and dim for as many as they may have: a quad
			# already bought looked as buyable as ever, and the hold on "buy"
			# ended in a refusal.
			row.modulate = (
				Color.WHITE if coins >= price and many < ShopStock.limit(item)
				else Color(1.0, 1.0, 1.0, 0.45)
			)
			# Never disabled. A bought thing still has to answer "what is this"
			# when a child taps it — that was the whole point of the words —
			# and a disabled button answers nothing at all.
			_shop_owned[item] = many > 0
			_shop_have[item] = many
		# The purse may have changed since the words went up — a child has just
		# bought something, or earned a coin — so the buttons say so.
		# The words under the pictures too, for the same reason: "×1" stayed
		# on the name of a thing after a second one was bought.
		if not opening and _shop_chosen != &"":
			_shop_tapped(_shop_chosen)
		else:
			_refresh_shop_buy()
			_refresh_shop_sell_back()
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
		if not wanted:
			_let_go_of_talk()
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

## Whether the child is in water deep enough to swim down in, and whether they
## are already going down.
##
## One button rather than two, showing the way they are about to travel: a
## child who is on the surface sees an arrow going under, and a child who is
## under sees one coming up. Two buttons would mean one of them is always the
## wrong one to press, which on a phone is a button pressed by mistake.
func set_dive_offer(offered: bool, going_down: bool) -> void:
	var face := _face_of(_dive_button)
	if face != null:
		face.show_kind(ActionIcon.Kind.SURFACE if going_down else ActionIcon.Kind.DIVE)
	if _dive_button.visible != offered:
		_dive_button.visible = offered
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
	# Everything but the swing spends coins, sells or starts the score again.
	_visit_ring.needed = place != Places.PLAYGROUND
	if wanted:
		var face := _face_of(_visit_button)
		if face != null:
			var which := ActionIcon.Kind.SWING
			if place == Places.CAFE:
				which = ActionIcon.Kind.EAT
			elif place == Places.SHOP:
				which = ActionIcon.Kind.SHOP
			elif place == Pitch.SCOREBOARD:
				which = ActionIcon.Kind.NEW_GAME
			face.show_kind(which)
	if _visit_button.visible != wanted:
		_visit_button.visible = wanted
		_layout()

## The café's menu: a picture of each dish with its price under it, and below
## them the name of the one chosen and what it gives. A tap on a picture only
## chooses — it spends nothing, so a stray finger loses nothing — and what is
## bought is bought by holding the eat button, as it always was.
func _build_cafe_menu() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.13, 0.9)
	style.set_corner_radius_all(16)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	style.border_color = Color(1.0, 0.90, 0.52, 0.35)
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	panel.visible = false

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	for dish in Dishes.ALL:
		var tile := Button.new()
		# A dish is a picture a three-year-old points at: nine millimetres each way.
		tile.custom_minimum_size = Vector2(CHILD_TARGET, CHILD_TARGET * 1.1)
		tile.focus_mode = Control.FOCUS_NONE
		tile.pressed.connect(func() -> void: _dish_tapped(dish))
		row.add_child(tile)
		var stack := VBoxContainer.new()
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.add_theme_constant_override("separation", 0)
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(stack)
		var icon := DishIcon.new(dish)
		icon.custom_minimum_size = Vector2(BUTTON * 0.66, BUTTON * 0.66)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stack.add_child(icon)
		var price := Label.new()
		price.add_theme_font_size_override("font_size", 19)
		price.add_theme_color_override("font_color", Color(1.0, 0.90, 0.52))
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(price)
		_dish_tiles[dish] = tile
		_dish_prices[dish] = price

	_dish_name = Label.new()
	_dish_name.add_theme_font_size_override("font_size", 21)
	_dish_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_dish_name)
	_dish_note = Label.new()
	_dish_note.add_theme_font_size_override("font_size", 15)
	_dish_note.add_theme_color_override("font_color", Color(0.74, 0.78, 0.84))
	_dish_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_dish_note)
	return panel

## A picture on the menu was tapped: it is chosen, and nothing is spent.
func _dish_tapped(dish: StringName) -> void:
	_dish_chosen = dish
	_refresh_cafe_menu()

## What is chosen from the menu, which is the soup until a child has chosen.
func chosen_dish() -> StringName:
	return _dish_chosen

## Hand a new interface the café choices the old one held. They live here and
## nowhere else, so a change of language — which rebuilds the whole interface —
## put the price of a child's own café back to nothing and the dish back to the
## usual one, without a word, and the next meal was served on those.
func restore_cafe_choices(paid: bool, dish: StringName) -> void:
	_cafe_paid = paid
	if Dishes.ALL.has(dish):
		_dish_chosen = dish
	_refresh_price_button()
	# Redrawn on the next frame's offer: the menu's state includes the price.
	_cafe_menu_state = []

## What the chosen dish costs at the café the child is in: the valley's price,
## or the child's own café's, which is nothing when they ask nothing.
func _dish_price_text(dish: StringName, at_home: bool) -> String:
	if not at_home:
		return "%d ●" % Dishes.price(dish)
	return ("%d ●" % Venues.price_of(dish)) if _cafe_paid else Text.of("ui_cafe_free")

func _refresh_cafe_menu() -> void:
	var at_home: bool = _cafe_menu_state[1] if _cafe_menu_state.size() > 1 else false
	var coins: int = _cafe_menu_state[2] if _cafe_menu_state.size() > 2 else 0
	for dish: StringName in Dishes.ALL:
		var tile: Button = _dish_tiles[dish]
		var price: Label = _dish_prices[dish]
		price.text = _dish_price_text(dish, at_home)
		var cost := Venues.price_of(dish) if at_home else Dishes.price(dish)
		# Dimmed, never disabled: a dish that cannot be bought yet can still be
		# asked about, as in the shop.
		tile.modulate = Color.WHITE if (coins >= cost or (at_home and not _cafe_paid)) else Color(1.0, 1.0, 1.0, 0.5)
		var picked := dish == _dish_chosen
		var mark := StyleBoxFlat.new()
		mark.bg_color = Color(1.0, 0.90, 0.52, 0.18) if picked else Color(1.0, 1.0, 1.0, 0.06)
		mark.set_corner_radius_all(12)
		if picked:
			mark.border_color = Color(1.0, 0.90, 0.52, 0.85)
			mark.set_border_width_all(2)
		tile.add_theme_stylebox_override("normal", mark)
	_dish_name.text = Text.of(Dishes.name_key(_dish_chosen))
	var note := Text.format("dish_gives", [Dishes.percent(_dish_chosen)])
	if Dishes.cools(_dish_chosen):
		note += " " + Text.of("dish_cools")
	_dish_note.text = note

## Show the menu while a child is inside a café — the valley's, or one of their
## own with `at_home` — and say how many coins are in the purse so that what
## cannot be afforded yet is dimmed.
##
## Never while building. A child decorating their own café is inside it, and the
## menu stands exactly where the palette and its tabs do: it lay over both, took
## the taps meant for the pieces, and left the top of the palette unreachable.
func set_cafe_menu_open(open: bool, at_home: bool, coins: int) -> void:
	var shown := open and not _building
	var state := [shown, at_home, coins, _cafe_paid, Text.language()]
	if state == _cafe_menu_state:
		return
	var was_open: bool = _cafe_menu_state.size() > 0 and _cafe_menu_state[0]
	_cafe_menu_state = state
	_cafe_menu.visible = shown
	if shown:
		_refresh_cafe_menu()
		if not was_open:
			_cafe_menu.move_to_front()
	_layout()

func is_cafe_menu_open() -> bool:
	return _cafe_menu.visible

## Whether the price button is on show, which it is beside a cafe the child
## built.
func set_cafe_price_offer(wanted: bool) -> void:
	if _price_button.visible != wanted:
		_price_button.visible = wanted
		_layout()

## Set from the saved setting, without announcing it as a change.
func set_cafe_paid(paid: bool) -> void:
	_cafe_paid = paid
	_refresh_price_button()

## Whether the child's own cafe is asking a coin for a meal.
func cafe_is_paid() -> bool:
	return _cafe_paid

func _refresh_price_button() -> void:
	# What each dish costs is under its picture on the menu; this says only
	# whether the café asks coins at all.
	_price_button.text = ("● %s" % Text.of("ui_cafe_paid")) if _cafe_paid else Text.of("ui_cafe_free")
	_price_button.custom_minimum_size.x = maxf(BUTTON, float(_price_button.text.length()) * 17.0 + 34.0)
	_price_button.size.x = _price_button.custom_minimum_size.x

## Which way round the camera is sitting.
##
## The button shows the view you are *in*, not the one pressing it would give
## you. It used to show the other one — a picture of what the press does — but
## it now sits beside the microphone, which shows its own state, and two
## neighbouring buttons that answer opposite questions is worse than either
## rule on its own. An open eye is the near view; a barred one is the far one.
func set_first_person(on: bool) -> void:
	var face := _face_of(_view_button)
	if face != null:
		face.show_kind(
			ActionIcon.Kind.VIEW_FIRST if on else ActionIcon.Kind.VIEW_THIRD
		)

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
			# Which thing you are getting off, not merely that you are getting
			# off something: it showed a horse whatever was underneath.
			kind = ActionIcon.Kind.GET_OFF
			if kind_of == MountKinds.BICYCLE:
				kind = ActionIcon.Kind.LEAVE_BICYCLE
			elif kind_of == MountKinds.MOTORCYCLE:
				kind = ActionIcon.Kind.LEAVE_MOTORCYCLE
			elif kind_of == MountKinds.QUAD:
				kind = ActionIcon.Kind.LEAVE_QUAD
		elif boat:
			# A horseshoe on a jetty would be a riddle; a boat says "row".
			kind = ActionIcon.Kind.ROW
		elif kind_of == MountKinds.BICYCLE:
			kind = ActionIcon.Kind.RIDE_BICYCLE
		elif kind_of == MountKinds.MOTORCYCLE:
			kind = ActionIcon.Kind.RIDE_MOTORCYCLE
		elif kind_of == MountKinds.QUAD:
			# It showed a horseshoe, which is what every mount showed before
			# the machines had faces of their own.
			kind = ActionIcon.Kind.RIDE_QUAD
		face.show_kind(kind)
	if _ride_button.visible != wanted:
		_ride_button.visible = wanted
		_layout()

## Whether a tree is close enough to cut, given that the axe is owned.
##
## `planted` is whether the axe would fall on a tree a child planted, which has
## to be held rather than tapped.
func set_tree_in_reach(within_reach: bool, planted := false) -> void:
	_tree_is_planted = planted
	_chop_needs_a_hold()
	if _chop_button.visible != within_reach:
		_chop_button.visible = within_reach
		_layout()

## A tree is felled by a hold when it was planted, or when felling it would
## take coins from the purse (the game charges for a wild tree too). With nothing
## to lose, a wild tree is still a tap.
func _chop_needs_a_hold() -> void:
	_chop_ring.needed = _tree_is_planted or _coin_count > 0

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

## The purse is a fixed width sized for four digits, so four digits is what it
## is allowed to print. Wallet caps what a child can hold at the same number;
## this is the panel keeping its own promise rather than trusting the caller.
func set_coins(total: int) -> void:
	_coins_label.text = str(clampi(total, 0, Wallet.MAX_COINS))
	_coin_count = total
	_chop_needs_a_hold()
	_layout()

func _toggle_map() -> void:
	if _minimap == null:
		return
	if _minimap.is_showing():
		_minimap.hide_map()
	else:
		_minimap.show_map()
	_map_button.modulate = Color.WHITE if _minimap.is_showing() else Color(1.0, 1.0, 1.0, 0.5)
	_refresh_guide_badge()
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

## Android's back button: put away the panel that is on top, and say whether
## there was one. Nothing open means the caller may leave the game. One panel
## per press, the one drawn last first, so a child who pressed back twice by
## accident does not lose the screen under it as well.
func close_top_panel() -> bool:
	if _mic_notice != null and _mic_notice.visible:
		hide_mic_refused()
		return true
	if _offer != null:
		close_look_offer()
		return true
	if _danger.visible:
		_danger.visible = false
		_reset_ring.cancel()
		_reset_button.text = Text.of("ui_reset_hold")
		_layout()
		return true
	if _menu.visible:
		_toggle_menu()
		return true
	if together.visible:
		together.close()
		_layout()
		return true
	if _shop.visible:
		shop_toggled.emit()
		return true
	return false

func _toggle_menu() -> void:
	_menu.visible = not _menu.visible
	# Over the map rather than under it. The minimap is added last so that it
	# draws above the rest of the interface, which is right until something
	# opens underneath it: settings came up behind the open map, and the name
	# field and half the colours were simply not there to be tapped.
	if _menu.visible:
		_menu.move_to_front()
	# Opening or closing the menu always shuts the dangerous room behind it.
	_danger.visible = false
	_reset_ring.cancel()
	_reset_button.text = Text.of("ui_reset_hold")
	_layout()

func _build_tabs() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.visible = false

	for entry: Dictionary in BUILD_GROUPS:
		var group: StringName = entry["id"]
		var tab := _button("", Color(0.86, 0.90, 0.96))
		tab.custom_minimum_size = TAB_SIZE
		var picture := TAB_SIZE.y * 0.72
		var icon := PartIcon.new(entry["icon"])
		icon.position = Vector2((TAB_SIZE.x - picture) * 0.5, -2.0)
		icon.size = Vector2(picture, picture)
		tab.add_child(icon)
		var name_label := _label(15, Color(0.92, 0.95, 1.0))
		name_label.text = Text.of(entry["text"])
		name_label.clip_text = true
		name_label.position = Vector2(2.0, TAB_SIZE.y - 24.0)
		name_label.size = Vector2(TAB_SIZE.x - 4.0, 22.0)
		tab.add_child(name_label)
		tab.tooltip_text = name_label.text
		tab.pressed.connect(func() -> void: _show_group(group))
		row.add_child(tab)
	return row

## Show one group of the palette, and say so, so the piece being built follows
## the tab being looked at.
func _show_group(group: StringName) -> void:
	_group = group
	var kinds := group_kinds(group)
	for kind in _palette_buttons:
		(_palette_buttons[kind] as Button).visible = kinds.has(kind)
	_material_button.visible = group == &"walls"
	for i in _tabs.get_child_count():
		(_tabs.get_child(i) as Button).modulate = (
			Color.WHITE if BUILD_GROUPS[i]["id"] == group else Color(1.0, 1.0, 1.0, 0.5)
		)
	build_tab.emit(group)
	_layout()

## Open the palette on the group a piece is in, without choosing anything. A
## new interface opens on "things", and the game builds one while a child is
## in the middle of building (a change of language does), so it has to be told
## which tab their piece is on or the tab it lands on takes their choice away.
func show_group_of(kind: StringName) -> void:
	_group = group_of(kind)

## The house or the things, for callers that only know the two — the
## screenshot tool, and the layout check. The house opens on its walls, which
## is where a house starts.
func _show_house(house: bool) -> void:
	_show_group(&"walls" if house else &"things")

## Make a button need a press-and-hold, with a ring filling on it, and say how
## when a finger lifts too soon. For what loses something that is hard to get
## back; the everyday buttons stay a tap.
func _hold(button: Button, action: Callable) -> HoldRing:
	var ring := HoldRing.attach(button, action)
	ring.too_short.connect(func() -> void: announce(Text.of("ui_hold_hint"), 1.8))
	return ring

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
	_question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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

## The panel for a refused microphone: a crossed microphone for a child who
## cannot read yet, and the words for the parent standing behind them.
func _build_mic_notice() -> void:
	_mic_notice = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.12, 0.92)
	style.set_corner_radius_all(16)
	style.content_margin_left = 16.0
	style.content_margin_right = 20.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	style.border_color = Color(1.0, 0.6, 0.5, 0.5)
	style.set_border_width_all(2)
	_mic_notice.add_theme_stylebox_override("panel", style)
	_mic_notice.visible = false
	# A tap puts it away, so it never sits over the game for somebody who has
	# read it. A touch as well as a click: emulate_mouse_from_touch is off, so
	# on a phone only the touch arrives, and the notice sat there for fourteen
	# seconds under a finger that had already tapped it.
	_mic_notice.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventMouseButton and event.pressed) or (
				event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
			hide_mic_refused())
	add_child(_mic_notice)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_mic_notice.add_child(row)

	var picture := ActionIcon.new(ActionIcon.Kind.MIC_OFF)
	picture.custom_minimum_size = Vector2(BUTTON, BUTTON)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(picture)

	_mic_words = Label.new()
	_mic_words.add_theme_font_size_override("font_size", 22)
	_mic_words.add_theme_color_override("font_color", Color(1.0, 0.97, 0.90))
	_mic_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mic_words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_mic_words)

## The phone would not let the game listen. Told once, plainly, and left up
## long enough to read aloud.
func show_mic_refused() -> void:
	_mic_words.text = Text.of("say_mic_refused")
	_mic_seconds = 14.0
	_mic_notice.visible = true
	_layout()

func hide_mic_refused() -> void:
	_mic_seconds = 0.0
	_mic_notice.visible = false

func is_mic_refused_shown() -> bool:
	return _mic_notice.visible

func _answer_button(face: String, colour: Color, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = face
	# The cross and the tick under every question, the ones a small finger is
	# asked to choose between: nine millimetres tall.
	button.custom_minimum_size = Vector2(BUTTON * 1.5, CHILD_TARGET)
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
	if _minimap != null:
		_minimap.keep_small(enabled)
	_refresh_guide_badge()
	_palette.visible = enabled
	_tabs.visible = enabled
	_place_button.visible = enabled
	_remove_button.visible = enabled
	_undo_button.visible = enabled
	# The café's menu gives way at once, rather than at the next frame's offer.
	if enabled and _cafe_menu != null and _cafe_menu.visible:
		_cafe_menu.visible = false
		_cafe_menu_state = []
	if not enabled:
		_storey_row.visible = false
		_hint.visible = false
	if enabled:
		_show_group(_group)
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
	# A reason is not always a refusal: a whole roof says what the room it is
	# aimed at will cost, because that depends on the room.
	_status.text = name if reason.is_empty() else "%s — %s" % [name, reason]
	_layout()

## How far across the screen, as a fraction of its height, the finger slides to
## turn the shot all the way to KICK_TURN_MAX, and how far up to lift it from a
## flat drive to the highest chip. Fractions of the height so the feel is the
## same on a phone at any resolution. A third of the screen's height is an easy
## reach for a thumb in landscape.
const KICK_TURN_MAX := deg_to_rad(60.0)
const KICK_TURN_REACH := 0.33
const KICK_LOFT_REACH := 0.30

## Slide the aim by `relative` pixels of finger travel on a screen `height`
## pixels tall: sideways turns the line, up lifts it, down flattens it. Each is
## clamped as it accumulates, so a finger that has gone past the end of the range
## comes back the moment it reverses instead of having to unwind.
func slide_kick_aim(relative: Vector2, height: float) -> void:
	if height <= 0.0:
		return
	var fraction := relative / height
	_kick_aim.x = clampf(_kick_aim.x + fraction.x / KICK_TURN_REACH * KICK_TURN_MAX, -KICK_TURN_MAX, KICK_TURN_MAX)
	_kick_aim.y = clampf(_kick_aim.y - fraction.y / KICK_LOFT_REACH, 0.0, 1.0)

## The aim the finger has slid to on the kick button: x the turn in radians,
## positive to the right; y the loft, 0 to 1. Zero for a tap and for a key.
func kick_aim() -> Vector2:
	return _kick_aim

## Which finger is on the kick button, for the checks.
func kick_finger() -> int:
	return _kick_finger

## The slide that aims a kick. Read here, before the screen gets it, so that the
## drag that began on the kick button never also turns the camera, and from the
## one finger that is on the button. Touch drags only: with touch emulated from
## the mouse a mouse drag arrives as a touch drag too, and reading the mouse
## motion as well would count every slide twice.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _kick_finger < 0 and (
				(_kick_button.is_visible_in_tree() and _kick_button.get_global_rect().has_point(touch.position))
				or (_shoot_button.is_visible_in_tree() and _shoot_button.get_global_rect().has_point(touch.position))
			):
				_kick_finger = touch.index
		elif touch.index == _kick_finger:
			if touch.canceled:
				_kick_aim = Vector2.ZERO
			# Not at once: the button's own release, which reads the aim, comes
			# after this. Whatever it did, the finger is no longer ours.
			_forget_kick_finger.call_deferred()
		return
	if event is InputEventScreenDrag and _kick_finger >= 0:
		var drag := event as InputEventScreenDrag
		if drag.index != _kick_finger:
			return
		# screen_relative, not relative: the latter is scaled by the stretch.
		slide_kick_aim(drag.screen_relative, get_viewport().get_visible_rect().size.y)
		get_viewport().set_input_as_handled()

func _forget_kick_finger() -> void:
	_kick_finger = -1

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

## The map, for the screenshot tool and the checks.
func minimap() -> Minimap:
	return _minimap

## The map is built by whoever owns the world, because it needs the height
## field, and the HUD is not the place to know about terrain.
func attach_minimap(minimap: Minimap) -> void:
	_minimap = minimap
	minimap.keep_small(_building)
	add_child(minimap)
	# Where the map goes depends on how big it is, and it changes size by
	# itself when tapped.
	minimap.resized.connect(_layout)
	minimap.close_requested.connect(_toggle_map)
	# The pointer to a place chosen on the map. Under everything else the
	# interface draws, so that no panel ever opens beneath it.
	_guide_badge = GuideBadge.new()
	_guide_badge.bind(minimap.guide())
	_guide_badge.keep_clear = _rects_under_the_badge
	add_child(_guide_badge)
	move_child(_guide_badge, 0)
	minimap.resized.connect(_refresh_guide_badge)
	minimap.place_tapped.connect(_on_place_tapped)
	minimap.guide().arrived.connect(_on_guide_arrived)
	_refresh_guide_badge()
	_layout()

## Where the buttons, the stick and the map are, so that the pointer to a chosen
## place never lies on one: every visible control of the play screen that takes a
## touch, in screen coordinates.
func _rects_under_the_badge() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for child in get_children():
		var control := child as Control
		if control == null or control == _guide_badge or not control.visible:
			continue
		if control is BaseButton or control is VirtualJoystick or control is Minimap:
			rects.append(control.get_global_rect().grow(6.0))
	return rects

## The pointer to the chosen place, for the checks.
func guide_badge() -> GuideBadge:
	return _guide_badge

## The pointer hides while the map is big (the map shows the way then) and
## while a child builds, when nothing may lie over the play field.
func _refresh_guide_badge() -> void:
	if _guide_badge != null:
		_guide_badge.suppressed = _building or (_minimap != null and _minimap.is_big())

func _on_place_tapped(kind: int, going: bool) -> void:
	var named := Text.of(MapLegend.name_key(kind))
	if going:
		announce(Text.format("say_map_going", [named]), 2.4)
	elif kind == PlaceGlyph.Kind.MOUNTAIN:
		announce(Text.format("say_map_far", [named]), 2.4)

func _on_guide_arrived(kind: int) -> void:
	announce(Text.format("say_map_arrived", [Text.of(MapLegend.name_key(kind))]), 3.0)

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

## Which storey the next piece will land on, between the buttons that change
## it, or nothing if it is not a house part.
func set_storey(storey: int, showing: bool) -> void:
	var text := ""
	if showing:
		if storey <= 0:
			text = Text.of("ui_ground_floor")
		else:
			text = Text.format("ui_upper_floor", [storey + 1])
	# Called every frame while building. Laying out the whole screen every
	# frame to say the same floor again was what turned a layout fault into a
	# palette that climbed off the screen in three frames, and it was a whole
	# screen's layout spent on nothing besides.
	if _storey_row.visible == showing and _storey_label.text == text:
		return
	_storey_row.visible = showing
	_storey_label.text = text
	_layout()

## The line for each step Structures.house_step can name.
const HOUSE_HINTS := {
	&"walls": "hint_build_walls", &"floor": "hint_build_floor",
	&"roof": "hint_build_roof", &"bed": "hint_build_bed",
}

## The step of a first house to say, as Structures.house_step names it, or
## nothing once the child has built one. Said only while building is open, and
## asked every frame, so it is only laid out again when the words change.
func set_house_hint(step: StringName) -> void:
	var text := Text.of(HOUSE_HINTS[step]) if HOUSE_HINTS.has(step) else ""
	var showing := _building and not text.is_empty()
	if _hint.visible == showing and _hint.text == text:
		return
	_hint.text = text
	_hint.visible = showing
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
	if _kick_aim == Vector2.ZERO:
		# Nothing slid yet: say that sliding is how, in words a six-year-old has.
		aim = Text.of("aim_slide")
	elif loft > 0.66:
		aim = Text.of("aim_high")
	elif loft > 0.3:
		aim = Text.of("aim_over")
	_aim_label.text = aim

## The two scores, blue's then red's, in their own colours.
func set_score(blue: int, red: int) -> void:
	_score_blue.text = "%d" % blue
	_score_red.text = "%d" % red

## Say which side this child plays, 0 blue or 1 red, under the score and in that
## side's colour; -1, alone, says nothing and the chip is as small as it was.
func set_side(side: int) -> void:
	if side >= 0:
		# Read again every time, so a change of language is followed.
		_score_side.text = Text.of("you_blue" if side == 0 else "you_red")
	if side == _side_shown:
		return
	_side_shown = side
	_score_side.visible = side >= 0
	_score.size.y = SCORE_CHIP.y + (SIDE_ROW if side >= 0 else 0.0)
	if side >= 0:
		_score_side.add_theme_color_override("font_color", Goal.SIDE_COLOURS[side].lightened(0.25))
	_layout()

var _side_shown := -1
## Room under the chip for "you: red".
const SIDE_ROW := 26.0

## Where the instruction line sits, and where the score chip ends, for the checks.
func task_label_top() -> float:
	return _task_label.position.y

func score_bottom() -> float:
	return _score.position.y + _score.size.y

## What the chip says about the side, for the checks.
func side_text() -> String:
	return _score_side.text if _score_side.visible else ""

## Show the score chip while the child is on or beside the pitch, and hide it
## everywhere else: a reading of 0 : 0 across the valley is only clutter.
func set_at_the_pitch(near: bool) -> void:
	if _at_the_pitch == near and _score.visible == near:
		return
	_at_the_pitch = near
	_score.visible = near
	_layout()

## What the chip reads, for the checks.
func score_text() -> String:
	return "%s:%s" % [_score_blue.text, _score_red.text]

func score_is_shown() -> bool:
	return _score.visible

## A short, centred announcement. Used for the things the world does in reply.
## Whether a child may talk at all. Set from the saved settings when the game
## opens, and by the switch in the menu after that.
func set_voice_allowed(allowed: bool) -> void:
	_voice_allowed = allowed
	_refresh_voice_switch()
	if not allowed:
		# Switching voice off while a finger is on talk took the button away
		# and left the microphone running: nothing was left to be released.
		_let_go_of_talk()
		if _talk_button.visible:
			_talk_button.visible = false
			_layout()

## The finger came off the talk button, or the button went from under it.
func _let_go_of_talk() -> void:
	if not _talk_held:
		return
	_talk_held = false
	talk_released.emit()

## Where in the name a tap at this local x falls, measured letter by letter in
## the field's own font — the field is centred and never scrolls, since the
## longest name it holds is sixteen letters wide and the field is wider than
## that, so a straight sum of letter widths lines up with what is drawn.
func _column_at(local_x: float) -> int:
	var font := _name_field.get_theme_font("font")
	var font_size := _name_field.get_theme_font_size("font_size")
	var text := _name_field.text
	var total := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var left := (_name_field.size.x - total) * 0.5
	var at := left
	for i in text.length():
		var glyph := font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if local_x < at + glyph * 0.5:
			return i
		at += glyph
	return text.length()

## Put the caret where a tap landed. See `_column_at` for why the position can
## be measured instead of asked of the engine.
func _place_caret_at(local_x: float) -> void:
	_name_field.caret_column = _column_at(local_x)

## The name this child is known by, shown in the settings field.
func set_player_name(name: String) -> void:
	_player_name = name
	if _name_field != null:
		_name_field.text = name

## Ring the shirt this child is wearing, and unring the rest.
func set_shirt(which: int) -> void:
	_menu_picker.set_shirt(which)
	_refresh_me()
	if _offer_picker != null:
		_offer_picker.set_shirt(which)

## The settings' picture of the child, drawn as they are drawn.
func _refresh_me() -> void:
	if _me_face == null:
		return
	var look := _menu_picker.look()
	_me_face.which = look[0]
	_me_face.dress(Character.SKINS[look[1]], Character.HAIRS[look[2]], _menu_picker.cloth())

## The colour this child's body really is, for the faces in the pickers to wear
## when no shirt has been picked.
func set_worn_shirt(colour: Color) -> void:
	_menu_picker.set_worn(colour)
	_refresh_me()
	if _offer_picker != null:
		_offer_picker.set_worn(colour)

## Ring who this child is drawn as, in the settings and in the first-run panel.
func set_look(look: Array) -> void:
	_menu_picker.set_look(look)
	_refresh_me()
	if _offer_picker != null:
		_offer_picker.set_look(look)

## The panel a first run opens on, before the child plays: who to be, by
## pictures, with a tick to go on. Nothing in it has to be touched, which is how
## it is skipped: the tick alone keeps the defaults.
func offer_look() -> void:
	if _offer != null:
		return
	_offer = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.12, 0.92)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(18.0)
	style.border_color = Color(1.0, 1.0, 1.0, 0.18)
	style.set_border_width_all(1)
	_offer.add_theme_stylebox_override("panel", style)
	# A finger anywhere on the panel is a child still here.
	_offer.gui_input.connect(func(_event: InputEvent) -> void: _offer_idle = 0.0)
	add_child(_offer)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_offer.add_child(column)
	var title := Label.new()
	title.text = Text.of("ui_who_are_you")
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.97, 0.90))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	# Every target on this panel is a three-year-old's: CHILD_TARGET, about nine
	# millimetres. Four rows of them, with the colours of the clothes beside
	# them, and a tick the width of the faces where the fifth row would be.
	_offer_idle = 0.0
	_offer_picker = LookPicker.new(CHILD_TARGET)
	_offer_picker.look_chosen.connect(func(look: Array) -> void:
		_offer_idle = 0.0
		look_chosen.emit(look))
	_offer_picker.shirt_chosen.connect(func(which: int) -> void:
		_offer_idle = 0.0
		shirt_chosen.emit(which))
	column.add_child(_offer_picker)
	_offer_picker.set_look(_menu_picker.look())
	_offer_picker.set_shirt(_menu_picker.shirt())
	_offer_picker.set_worn(_menu_picker.worn())
	var go := Button.new()
	go.focus_mode = Control.FOCUS_NONE
	go.custom_minimum_size = Vector2(CHILD_TARGET * 2.0, CHILD_TARGET)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var go_face := StyleBoxFlat.new()
	go_face.bg_color = Color(0.20, 0.52, 0.28, 0.95)
	go_face.set_corner_radius_all(14)
	go.add_theme_stylebox_override("normal", go_face)
	go.add_theme_stylebox_override("hover", go_face)
	var go_pressed := go_face.duplicate() as StyleBoxFlat
	go_pressed.bg_color = Color(0.30, 0.66, 0.38)
	go.add_theme_stylebox_override("pressed", go_pressed)
	var tick := ActionIcon.new(ActionIcon.Kind.TICK)
	tick.tint = Color(1.0, 1.0, 1.0)
	tick.set_anchors_preset(Control.PRESET_FULL_RECT)
	go.add_child(tick)
	go.pressed.connect(close_look_offer)
	_offer_picker.footer.add_child(go)
	# Over everything that opened before it: the settings, when it was opened
	# from there, and the map, which is always added last.
	_offer.move_to_front()
	_layout()

## Put the first-run panel away. A child who has seen it has been asked.
func close_look_offer() -> void:
	if _offer == null:
		return
	_offer.queue_free()
	_offer = null
	_offer_picker = null
	look_offer_closed.emit()

## Is the first-run panel open? For the checks.
func look_offer_open() -> bool:
	return _offer != null

func player_name() -> String:
	return _player_name

func voice_allowed() -> bool:
	return _voice_allowed

func _refresh_voice_switch() -> void:
	var face := _face_of(_voice_button) if _voice_button != null else null
	if face != null:
		face.show_kind(ActionIcon.Kind.MIC_ON if _voice_allowed else ActionIcon.Kind.MIC_OFF)

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

func announce(text: String, seconds := 3.2, colour := Color(1.0, 1.0, 1.0)) -> void:
	_message.text = text
	# Set every time, so a win in blue does not leave the next message blue.
	_message.add_theme_color_override("font_color", colour)
	_message_timer = seconds
	_layout()

## The colour the current announcement is written in, for the checks.
func message_colour() -> Color:
	return _message.get_theme_color("font_color")

## The kick button breathes while a ball is in reach, so that it is the thing to
## press and not one of several buttons that happen to be lit.
func _pulse_the_kick_button(delta: float) -> void:
	if not _kick_button.visible:
		return
	_pulse += delta
	_kick_button.pivot_offset = _kick_button.size * 0.5
	var swell := 0.5 + 0.5 * sin(_pulse * KICK_PULSE_RATE)
	_kick_button.scale = Vector2.ONE * (1.0 + 0.10 * swell)
	_kick_button.modulate = Color(1.0, 1.0, 1.0).lerp(Color(1.0, 0.95, 0.55), swell)

func _process(delta: float) -> void:
	_pulse_the_kick_button(delta)
	if _offer != null:
		_offer_idle += delta
		if _offer_idle >= OFFER_IDLE:
			close_look_offer()
	if _mic_seconds > 0.0:
		_mic_seconds -= delta
		if _mic_seconds <= 0.0:
			hide_mic_refused()
	if _reset_ring.is_holding() and _reset_ring.progress < 1.0:
		# Counting down out loud, so a parent holding it knows it is
		# working and a child watching gets bored before it finishes.
		_reset_button.text = "%s %d" % [
			Text.of("ui_reset_holding"),
			int(ceil(RESET_HOLD * (1.0 - _reset_ring.progress)))
		]
	elif _reset_button.text != Text.of("ui_reset_hold"):
		_reset_button.text = Text.of("ui_reset_hold")

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
	#
	# Small, that is. Opened up it was still pinned to the corner and grew
	# down over everything below it: the large map lay on the talk button, so
	# pressing talk made the map bigger instead, and the whole valley lay on
	# the stick, so a child who opened it to see where to go could not go
	# anywhere. Larger than small, it is centred between the stick and the
	# buttons, where it covers neither thumb.
	if _minimap != null:
		# Under the top row, which is a full thumb target tall now.
		var map_top := safe.position.y + MARGIN + BUTTON + TOP_GAP
		# The small map is its picture plus the panel's margins all round, so it
		# is wider than SMALL_PIXELS by those: compared with the picture alone,
		# every map counted as opened up and the small one sat in the middle of
		# the screen, over the storey buttons and the line saying why not.
		# Never taller than the room under the instruction line: the whole-valley
		# map used to run off the bottom of the screen.
		_minimap.fit_to(safe.end.y - MARGIN - (map_top + 44.0 + 10.0) - Minimap.PANEL_MARGINS)
		var opened_up := _minimap.size.x > Minimap.SMALL_PIXELS + Minimap.PANEL_MARGINS + 1.0
		_minimap.position = Vector2(
			(
				safe.position.x + safe.size.x * 0.5 - _minimap.size.x * 0.5
				if opened_up else safe.position.x + MARGIN
			),
			# Opened up it is centred and would cover the instruction line, so it
			# starts under that instead.
			map_top + 44.0 + 10.0 if opened_up else map_top
		)
		_map_button.modulate = (
			Color.WHITE if _minimap.is_showing() else Color(1.0, 1.0, 1.0, 0.5)
		)
	_map_button.position = _menu_button.position + Vector2(BUTTON + TOP_GAP, 0.0)
	_view_button.position = _map_button.position + Vector2(BUTTON + TOP_GAP, 0.0)
	_voice_button.position = _view_button.position + Vector2(BUTTON + TOP_GAP, 0.0)
	_together_button.position = _voice_button.position + Vector2(BUTTON + TOP_GAP, 0.0)
	# Bottom left, above the stick, where a thumb already rests — and far from
	# the buttons on the right that a child presses while playing.
	# Right of the small map, not under it: the top row is a full thumb target
	# tall now, so the map hangs down to y 344 and the old spot, at 332, was
	# under its bottom edge.
	_talk_button.position = Vector2(
		safe.position.x + MARGIN + Minimap.SMALL_PIXELS + Minimap.PANEL_MARGINS + TOP_GAP,
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
		# A wrapping label has no width of its own, so it is given one: the
		# line as it would be written out, or what the safe area leaves after
		# the panel's margins, whichever is less. A normal phone therefore
		# sees the same one-line panel as before.
		var font := _question.get_theme_font("font")
		var line := font.get_string_size(
			_question.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			_question.get_theme_font_size("font_size")
		).x
		var room_for_text := maxf(safe.size.x - 40.0 - 24.0, 120.0)
		_question.custom_minimum_size.x = minf(ceilf(line) + 2.0, room_for_text)
		_question.size = Vector2(_question.custom_minimum_size.x, 0.0)
		_asking.size = Vector2.ZERO
		_asking.size = _asking.get_combined_minimum_size()
		_asking.position = Vector2(
			safe.position.x + (safe.size.x - _asking.size.x) * 0.5,
			safe.position.y + safe.size.y * 0.42 - _asking.size.y * 0.5
		)

	# The refused microphone, in the middle and a little above the question's
	# place, with its words wrapped to what the safe area leaves.
	if _mic_notice.visible:
		_mic_words.custom_minimum_size.x = minf(560.0, maxf(safe.size.x - BUTTON - 40.0 - 36.0, 120.0))
		_mic_words.size = Vector2(_mic_words.custom_minimum_size.x, 0.0)
		_mic_notice.size = Vector2.ZERO
		_mic_notice.size = _mic_notice.get_combined_minimum_size()
		_mic_notice.position = Vector2(
			safe.position.x + (safe.size.x - _mic_notice.size.x) * 0.5,
			safe.position.y + safe.size.y * 0.30 - _mic_notice.size.y * 0.5
		)

	# Under the button that opened it. A phone whose bottom edge is taken by a
	# gesture bar leaves the settings, the tallest panel, hanging off the
	# bottom of the safe area with its last row out of reach, so the panel then
	# moves up beside the top row's first button instead, which stays uncovered
	# and can still close it.
	_menu.position = _menu_button.position + Vector2(0.0, BUTTON + TOP_GAP)
	var panel_height := maxf(
		_menu.get_combined_minimum_size().y, _danger.get_combined_minimum_size().y
	)
	var bottom_limit := safe.position.y + safe.size.y - 8.0
	if _menu.position.y + panel_height > bottom_limit:
		_menu.position = Vector2(
			_menu_button.position.x + BUTTON + TOP_GAP,
			maxf(safe.position.y + MARGIN, bottom_limit - panel_height)
		)
	_danger.position = _menu.position
	if _offer != null:
		_offer.size = Vector2.ZERO
		_offer.size = _offer.get_combined_minimum_size()
		_offer.position = Vector2(
			safe.position.x + (safe.size.x - _offer.size.x) * 0.5,
			safe.position.y + (safe.size.y - _offer.size.y) * 0.5
		)

	# The corner opposite the menu: how you are, then what you have, on the one
	# line and level with the buttons on the left. These used to run down the
	# right-hand edge under the bag — bag, then purse, then health — so the two
	# numbers a child actually watches were third and fourth in a stack, and
	# the whole column shifted down the moment the bag appeared.
	_purse.size = Vector2(PURSE_WIDTH, _purse.get_combined_minimum_size().y)
	_purse.position = Vector2(
		safe.position.x + safe.size.x - PURSE_WIDTH - MARGIN,
		safe.position.y + MARGIN
	)

	_vitals.size = _vitals.custom_minimum_size
	_vitals.position = Vector2(
		_purse.position.x - VitalsGauge.WIDTH - 10.0,
		# Centred on the purse rather than sharing its top edge, because the
		# two are different heights and a shared top reads as a mistake.
		_purse.position.y + (_purse.size.y - _vitals.size.y) * 0.5
	)
	# Below the purse and the health, with a clear gap: the bag is something a
	# child opens now and then, and those two are read at a glance.
	# Aligned by its own width rather than by the open one: the bag is narrower
	# while it is shut, and pinning it to the wide measurement left it hanging
	# a hand's breadth off the edge of the screen.
	_backpack.position = Vector2(
		safe.position.x + safe.size.x - _backpack.custom_minimum_size.x - MARGIN,
		_purse.position.y + _purse.size.y + 26.0
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
	# Undo above the minus: the two ways of taking something back, together,
	# and clear of the palette's row.
	_undo_button.position = _remove_button.position - Vector2(0.0, BUTTON + 16.0)

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

	# Centred, unless the five top buttons reach it: on a 1280 wide screen they
	# end at 570 and a centred chip would start at 556, so it steps right.
	var top_row_end := _together_button.position.x + _together_button.size.x
	_score.position = Vector2(
		maxf(view.x * 0.5 - SCORE_CHIP.x * 0.5, top_row_end + TOP_GAP),
		safe.position.y + MARGIN
	)

	# Under the chip, which is a row taller while a side is shown: the
	# instruction was written over "you: red" when two were playing. And under
	# the top row of buttons, which is taller than the chip: the line used to
	# share their height and the buttons stood over its first words.
	#
	# Between the small map's width and the same distance from the right edge,
	# so a long line in Russian cannot run over the map, which hangs under the
	# buttons on the left; wrapped in that width if it is ever longer still.
	var task_edge := safe.position.x + MARGIN + Minimap.SMALL_PIXELS + Minimap.PANEL_MARGINS + TOP_GAP
	_task_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_task_label.size = Vector2(maxf(view.x - task_edge * 2.0, 120.0), 0.0)
	_task_label.position = Vector2(
		task_edge,
		maxf(
			safe.position.y + MARGIN + 44.0 + (SIDE_ROW if _side_shown >= 0 else 0.0),
			safe.position.y + MARGIN + BUTTON + 6.0
		)
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
	var column_top := _backpack.position.y + _backpack.shut_height() + 10.0
	var column_x := safe.position.x + safe.size.x - BUTTON - MARGIN
	var floor_y := safe.position.y + safe.size.y - BUTTON * 2.0 - MARGIN
	# Nor into whatever is stacked above build in this same column: the kick
	# button, and while building the plus. The kick stands two places up then,
	# so a third carried thing was drawn straight through it.
	if _kick_button.visible:
		floor_y = minf(floor_y, _kick_button.position.y - 10.0)
	if _building:
		floor_y = minf(floor_y, _place_button.position.y - 10.0)
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
	for button: Button in [
		_dive_button, _visit_button, _price_button, _ticket_button, _dam_button,
		_fire_button, _sleep_button,
	]:
		if not button.visible:
			continue
		context_x -= button.size.x + 16.0
		button.position = Vector2(context_x, _jump_button.position.y)

	# Centred low along the bottom edge, the spot the bow's button shares (see
	# below); the kick button is in the right-hand stack, not here.
	#
	# Sized by hand first. The button is made with no text and grows to fit the
	# animal's wish, but a control only takes its new minimum size at the end
	# of the frame — so centring on its old, ninety-six-pixel width put the
	# left edge where a narrow button's would be, and a wish like "wants a
	# stroke" then hung out to the right over the jump button. Nothing laid
	# the screen out again once it had grown.
	# Unwrapped and at its natural width to start with; the end of this function
	# wraps it again when it has to while building.
	_care_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	_care_button.custom_minimum_size.x = BUTTON
	_care_button.size = _care_button.get_combined_minimum_size()
	# Not on the palette's row while building. The palette is centred on that
	# very row, so an animal wandering up to a child laying walls put the
	# button across the pieces, and whichever was added later took every touch.
	# While building it hangs under the task line instead, where nothing is.
	var thumb_row := safe.position.y + safe.size.y - BUTTON - MARGIN
	if _building:
		thumb_row = _task_label.position.y + 44.0
	_care_button.position = Vector2(
		safe.position.x + safe.size.x * 0.5 - _care_button.size.x * 0.5,
		thumb_row
	)

	# The bow's button shares that spot, and the two do meet: nothing keeps the
	# animals off the shooting line, so a sheep wandering up while a child is
	# there put the care button exactly over the bow's, and whichever was added
	# later took every touch. With both showing, the bow steps out to the right
	# of the care button.
	var shoot_x := safe.position.x + safe.size.x * 0.5 - _shoot_button.size.x * 0.5
	if _care_button.visible:
		shoot_x = _care_button.position.x + _care_button.size.x + 16.0
	_shoot_button.position = Vector2(shoot_x, thumb_row)

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
		#
		# Measured, then, with both the buying and the selling button showing:
		# the panel's other parts come to about 3.8 buttons' height (367 px
		# against the 3.9 allowed here), and the old figure of 4.6 was never
		# used at all, so the panel simply asked for 710 px of a 720 px screen.
		# Where the safe area is shorter than that (a phone with a notch or a
		# gesture bar) the panel ran off the bottom and hid the way out; now the
		# shelf takes what is left and scrolls, which it was built to do.
		var shelf_room := safe.size.y - BUTTON * SHOP_CHROME
		_shop_shelf.custom_minimum_size = Vector2(
			float(SHOP_COLUMNS) * (BUTTON * 1.5 + 10.0),
			clampf(float(rows) * tile_height + 12.0, BUTTON * 1.7, maxf(shelf_room, BUTTON * 1.7))
		)
	_shop.position = Vector2(
		safe.position.x + safe.size.x * 0.5 - _shop.size.x * 0.5,
		safe.position.y + safe.size.y * 0.5 - _shop.size.y * 0.5
	)
	# The café's menu sits above the row of buttons at the bottom, in the middle
	# of the screen, so that neither the stick nor the thumb's buttons are under
	# it. Sized by hand first, as the care button is, since a control only takes
	# its new size at the end of the frame.
	if _cafe_menu != null:
		_cafe_menu.size = _cafe_menu.get_combined_minimum_size()
		# Centred, unless the dishes (nine millimetres each) are wide enough to
		# reach the stick, in which case they stand clear of it on the right.
		var clear_of_stick := safe.position.x + MARGIN + side + 12.0
		var cafe_left := maxf(
			safe.position.x + safe.size.x * 0.5 - _cafe_menu.size.x * 0.5, clear_of_stick
		)
		_cafe_menu.position = Vector2(
			minf(cafe_left, safe.end.x - MARGIN - _cafe_menu.size.x),
			safe.position.y + safe.size.y - BUTTON - MARGIN - _cafe_menu.size.y - 12.0
		)

	# The walls carry the material button as well as their pieces. A group of
	# more than PALETTE_ROW goes on a second row, above the first.
	var shown := group_kinds(_group).size() + (1 if _group == &"walls" else 0)
	var palette_rows := ceili(float(shown) / float(PALETTE_ROW))
	var palette_width := float(mini(shown, PALETTE_ROW)) * (PIECE_SIZE.x + 12.0) - 12.0
	_palette.size = Vector2(
		palette_width, float(palette_rows) * (PIECE_SIZE.y + 8.0) - 8.0
	)
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
	var bottom_row := safe.position.y + safe.size.y - PIECE_SIZE.y - MARGIN
	_palette.position = Vector2(left, bottom_row)

	# If the row cannot fit between the stick and the buttons, it sits above
	# them instead of over them. Eight parts in Russian on a phone is exactly
	# that case, and an overlapping palette is a palette a child mis-taps.
	#
	# One row up from the bottom of the screen — measured from the screen, not
	# from where the tabs were left by the last layout. It was measured from
	# the tabs, which are then placed above the palette: so every layout moved
	# both up another row, and since the floor indicator lays the screen out
	# every frame while a house part is chosen, on a sixteen-by-nine phone the
	# house parts were off the top of the screen within three frames of
	# opening that tab.
	#
	# Above the row of jump and build, and still clear of the place, minus and
	# undo buttons stacked over them. It used to go up into the *same* row as
	# place and minus and only be centred, so on a phone the house parts lay
	# under those two buttons and the post could not be pressed at all.
	if left + palette_width > right_edge:
		var stack_edge := minf(_remove_button.position.x, _undo_button.position.x) - 20.0
		_palette.position = Vector2(
			maxf(left_edge, minf(
				safe.position.x + safe.size.x * 0.5 - palette_width * 0.5,
				stack_edge - palette_width
			)),
			safe.position.y + safe.size.y - MARGIN - BUTTON - 12.0 - PIECE_SIZE.y
		)

	# The second row grows upwards from the first, so the bottom of the palette
	# stays where it was and the tabs above it move up with its top.
	_palette.position.y -= float(palette_rows - 1) * (PIECE_SIZE.y + 8.0)

	var tabs_width := float(BUILD_GROUPS.size()) * (TAB_SIZE.x + 10.0) - 10.0
	_tabs.position = Vector2(
		safe.position.x + safe.size.x * 0.5 - tabs_width * 0.5,
		_palette.position.y - TAB_SIZE.y - 12.0
	)

	_status.size.x = view.x
	_status.position = Vector2(0.0, _tabs.position.y - 42.0)
	# Above the status line, once the status line is where it is going to be.
	# It was placed from the status line's position before that was worked out
	# for this layout, so it trailed one layout behind.
	_storey_row.size = Vector2(view.x, BUTTON)
	_storey_row.position = Vector2(0.0, _status.position.y - BUTTON - 4.0)
	# Above the storey buttons, whether or not they are showing, so it stays
	# where the eye found it when a plan is chosen and they appear.
	_hint.size = Vector2(view.x, 32.0)
	_hint.position = Vector2(0.0, _storey_row.position.y - 36.0)

	# Wrapped inside the safe area, so a long line in Russian runs onto a
	# second row instead of off both edges of a narrow phone. The height is
	# let go first: a label keeps the tall size it was given for a long
	# announcement, and would go on being tall for a short one.
	_message.size = Vector2(safe.size.x, 0.0)
	_message.position = Vector2(safe.position.x, safe.position.y + safe.size.y * 0.26)

	# While building, the care and bow buttons stand level with the storey
	# buttons instead of under the task line, where they were put to keep them
	# off the palette: the storey buttons are a full thumb target tall now and
	# fill the rows below the task line, so the two met there.
	#
	# The care button takes the room to the right of the storey buttons, up to
	# the column of carried things; a wish that is longer than that, which in
	# Russian it is, wraps onto a second line rather than run into the column.
	# The bow's button, when both show, goes to the left of the storey buttons,
	# where the small map ends well short of it.
	if _building:
		var row_width := _storey_row.get_combined_minimum_size().x
		var right_start := view.x * 0.5 + row_width * 0.5 + TOP_GAP
		var right_limit := safe.position.x + safe.size.x - MARGIN - BUTTON - TOP_GAP
		var care_room := right_limit - right_start
		_care_button.autowrap_mode = TextServer.AUTOWRAP_OFF
		_care_button.custom_minimum_size.x = BUTTON
		_care_button.size = _care_button.get_combined_minimum_size()
		if _care_button.visible and _care_button.size.x > care_room:
			_care_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_care_button.custom_minimum_size.x = care_room
			_care_button.size = Vector2(care_room, _care_button.get_combined_minimum_size().y)
		_care_button.position = Vector2(right_start, _storey_row.position.y)
		if _care_button.visible:
			_shoot_button.position = Vector2(
				view.x * 0.5 - row_width * 0.5 - TOP_GAP - _shoot_button.size.x,
				_storey_row.position.y
			)
		else:
			_shoot_button.position = Vector2(right_start, _storey_row.position.y)

## Set by the checks to stand in for a phone's cutout (HUD coordinates);
## empty means "ask the display".
var safe_area_override := Rect2()

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
	# A cutout dictated by the checks, in HUD coordinates.
	if safe_area_override.size.x > 0.0:
		return safe_area_override.intersection(viewport)
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

## The stick is hidden while the settings or the grown-ups' room is open, so its
## ring is not drawn over their controls and a press there cannot walk the child.
func _hide_the_stick_under_panels() -> void:
	_stick.visible = not (_menu.visible or _danger.visible)
