class_name LookPicker
extends VBoxContainer

## Who a child is, chosen by pictures: a row of five faces, then skin tones and
## hair colours as colour dots, then the colour of the clothes.
##
## One thing in two places. The settings panel has one, and the panel that a
## first run opens on has another, and they must offer exactly the same
## choices in the same order, so both are this. Nothing here is a word: a
## six-year-old who cannot read sees a face that looks like them and taps it.
## (The tooltips are for the grown-up with a mouse.)

## A character, a skin tone or a hair colour was picked: the whole choice,
## [character, skin, hair], see Character.clean.
signal look_chosen(look: Array)

## A colour for the clothes was picked, as an index into Visitors.SHIRTS.
signal shirt_chosen(which: int)

const RING := Color(1.0, 1.0, 1.0, 0.95)

## The side of a colour dot, as a share of the unit: a thumb's width for a
## six-year-old, and a target a three-year-old tapping at random can hit.
const DOT := 0.62

## The row under the hairs in the wide layout, a unit tall and as wide as the
## faces above it: the room the first-run panel's tick goes in, so that the
## panel is exactly as tall as the colours beside it. Null in the stacked layout.
var footer: HBoxContainer = null

var _unit: float
var _look: Array = [Character.SIMPLE, 0, 0]
var _shirt := -1
## What a child who has picked no shirt is actually wearing: the palette's
## fallback for them, which the game works out. Empty until it has been told.
var _worn := Color(0.0, 0.0, 0.0, 0.0)
var _faces: Array[CharacterIcon] = []
var _face_buttons: Array[Button] = []
var _skin_buttons: Array[Button] = []
var _hair_buttons: Array[Button] = []
var _shirt_buttons: Array[Button] = []

## From this side a picker lays itself out wide: everything the same size, in
## two blocks side by side, so that a target a child hits is the same large
## square whatever it is the colour of. Below it, the older stacked layout
## with its smaller dots, which the settings of a very small panel still use.
const WIDE_FROM := 100.0

## `unit` is the side of a button, in pixels.
func _init(unit := 96.0) -> void:
	_unit = unit
	add_theme_constant_override("separation", 8)
	var wide := unit >= WIDE_FROM
	var dot := _unit * (1.0 if wide else DOT)

	var faces := HBoxContainer.new()
	faces.add_theme_constant_override("separation", 6)
	for i in Character.KEYS.size():
		var button := _button(Vector2(_unit * 1.0, _unit * 1.0), Color(1.0, 1.0, 1.0, 0.16), 12)
		button.tooltip_text = Text.of(Character.LABELS[i])
		var face := CharacterIcon.new(i)
		face.set_anchors_preset(Control.PRESET_FULL_RECT)
		# Inside the ring, which is drawn in the button's border.
		face.offset_left = 5.0
		face.offset_top = 5.0
		face.offset_right = -5.0
		face.offset_bottom = -5.0
		button.add_child(face)
		button.pressed.connect(func() -> void: _pick(0, i))
		faces.add_child(button)
		_faces.append(face)
		_face_buttons.append(button)

	# Skin and hair: on one line with a gap between in the stacked layout, one
	# line each in the wide one, where one line of ten would not fit a phone.
	var tones := HBoxContainer.new()
	tones.add_theme_constant_override("separation", 6)
	var hairs := tones if not wide else HBoxContainer.new()
	hairs.add_theme_constant_override("separation", 6)
	for i in Character.SKINS.size():
		var swatch := _button(Vector2(dot, dot), Character.SKINS[i], 100)
		swatch.tooltip_text = String(Character.SKIN_NAMES[i])
		swatch.pressed.connect(func() -> void: _pick(1, i))
		tones.add_child(swatch)
		_skin_buttons.append(swatch)
	if not wide:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(_unit * 0.4, 1.0)
		tones.add_child(gap)
	for i in Character.HAIRS.size():
		var swatch := _button(Vector2(dot, dot), Character.HAIRS[i], 6 if not wide else 14)
		swatch.tooltip_text = String(Character.HAIR_NAMES[i])
		swatch.pressed.connect(func() -> void: _pick(2, i))
		hairs.add_child(swatch)
		_hair_buttons.append(swatch)

	# Twelve colours in two rows of six rather than one of twelve: each is as big
	# as a skin dot, which a small finger can hit, and the panel does not grow
	# wider than the faces above it to make room. Wide, they are three across
	# and four down beside the faces, skin and hair, which with the row under
	# those three (the footer) are the same four rows tall.
	var shirts := GridContainer.new()
	shirts.columns = 3 if wide else 6
	shirts.add_theme_constant_override("h_separation", 6)
	shirts.add_theme_constant_override("v_separation", 6)
	for i in Visitors.SHIRTS.size():
		var swatch := _button(Vector2(dot, dot), Visitors.SHIRTS[i], 8 if not wide else 14)
		swatch.tooltip_text = String(Visitors.SHIRT_NAMES[i])
		swatch.pressed.connect(func() -> void: shirt_chosen.emit(i))
		shirts.add_child(swatch)
		_shirt_buttons.append(swatch)

	if wide:
		var block := HBoxContainer.new()
		block.add_theme_constant_override("separation", 16)
		var left := VBoxContainer.new()
		left.add_theme_constant_override("separation", 6)
		left.add_child(faces)
		left.add_child(tones)
		left.add_child(hairs)
		footer = HBoxContainer.new()
		left.add_child(footer)
		block.add_child(left)
		block.add_child(shirts)
		add_child(block)
	else:
		add_child(faces)
		add_child(tones)
		add_child(shirts)
	_refresh()

## A flat coloured button. The ring round the chosen one is drawn in its
## border, the only part of it that is not the colour itself.
func _button(minimum: Vector2, colour: Color, corner: int) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = minimum
	var face := StyleBoxFlat.new()
	face.bg_color = colour
	face.set_corner_radius_all(corner)
	face.border_color = RING
	face.set_border_width_all(0)
	button.add_theme_stylebox_override("normal", face)
	button.add_theme_stylebox_override("hover", face)
	button.add_theme_stylebox_override("pressed", face)
	return button

func _pick(part: int, value: int) -> void:
	var next := _look.duplicate()
	next[part] = value
	look_chosen.emit(next)

## Show this choice: ring what is chosen, and dress every face in it.
func set_look(look: Array) -> void:
	_look = Character.clean(look)
	_refresh()

## Show this clothes colour, an index into Visitors.SHIRTS or -1 for none.
func set_shirt(which: int) -> void:
	_shirt = which
	_refresh()

## The colour the child's own body is really drawn in. With no shirt picked the
## faces showed the old default, a colour the child is not wearing, so the face
## that was meant to look like them did not.
func set_worn(colour: Color) -> void:
	_worn = colour
	_refresh()

func worn() -> Color:
	return _worn

## The colour of the clothes the faces are drawn in: the picked shirt, else what
## the child's body really wears, else the old default.
func cloth() -> Color:
	var colour: Color = Visitors.SHIRTS[_shirt] if _shirt >= 0 else Player.DEFAULT_SHIRT
	if _shirt < 0 and _worn.a > 0.0:
		colour = _worn
	return colour

## What is shown as chosen, for a second picker to start from and for the checks.
func look() -> Array:
	return _look

func shirt() -> int:
	return _shirt

func _refresh() -> void:
	var dressed := cloth()
	for i in _faces.size():
		_faces[i].dress(Character.SKINS[_look[1]], Character.HAIRS[_look[2]], dressed)
		_ring(_face_buttons[i], i == _look[0])
	for i in _skin_buttons.size():
		_ring(_skin_buttons[i], i == _look[1])
	for i in _hair_buttons.size():
		_ring(_hair_buttons[i], i == _look[2])
	for i in _shirt_buttons.size():
		_ring(_shirt_buttons[i], i == _shirt)

## The chosen one is ringed in white and haloed in dark, so that it stands out
## from the others whatever it is itself the colour of: a white ring alone is
## lost on the white shirt and the palest skin.
static func _ring(button: Button, chosen: bool) -> void:
	var face := button.get_theme_stylebox("normal") as StyleBoxFlat
	face.set_border_width_all(5 if chosen else 0)
	face.shadow_color = Color(0.0, 0.0, 0.0, 0.75) if chosen else Color(0.0, 0.0, 0.0, 0.0)
	face.shadow_size = 5 if chosen else 0
