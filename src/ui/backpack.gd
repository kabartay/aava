class_name Backpack
extends PanelContainer

## What the player is carrying, shown as a small panel down the right-hand side.
##
## It replaces a row of numbers along the top, which was legible but told a
## child nothing: a number is a fact, whereas a bag with things in it is a
## possession. The distinction matters at six years old, and it costs the same
## to draw.
##
## Rows appear as items are first found and never disappear afterwards. A slot
## that empties stays, greyed, because "you had four of these" is useful and an
## interface that rearranges itself under a child's thumb is not.
##
## It folds shut. There are eight things to carry now — sticks, stones, reeds,
## seeds, cones, wood, chocolate, wool — and eight rows of bag pushed the purse,
## the gauges and the whole column of buttons down the screen until they drew on
## top of one another. What a child needs at a glance is whether they are
## carrying anything; what they need on demand is the list. So the title row is
## always there and says how many kinds are in it, and tapping it opens and
## shuts the rest.

## Width of the panel. Wide enough for a two-digit count without the number
## jumping about as it changes.
const WIDTH := 190.0
const ROW_HEIGHT := 46.0

var _rows: Dictionary = {}
var _column: VBoxContainer
var _seen: Dictionary = {}
var _title: Button
## Shut to begin with. A bag that hangs open takes a third of the screen to say
## what one line says.
var _open := false

func _init() -> void:
	# A dark translucent slab rather than a solid one, so the world still shows
	# through and the panel reads as an overlay rather than a wall.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.12, 0.62)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	style.border_color = Color(1.0, 1.0, 1.0, 0.12)
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)

	custom_minimum_size = Vector2(WIDTH, 0.0)
	# Over everything on that side of the screen, because the open list is an
	# overlay across the purse and the gauges rather than a thing they make
	# room for.
	z_index = 1
	# The panel itself passes touches through — except the title, which is a
	# button and takes its own.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 6)
	add_child(_column)

	# The title is a button: it is the thing a child taps to look inside.
	_title = Button.new()
	_title.flat = true
	_title.focus_mode = Control.FOCUS_NONE
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.62))
	_title.add_theme_color_override("font_hover_color", Color.WHITE)
	_title.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title.pressed.connect(toggle)
	_column.add_child(_title)
	_refresh_title()

	# Hidden until the first thing is picked up: an empty bag on screen from the
	# first second is clutter that explains nothing.
	visible = false

## Open the bag, or shut it.
func toggle() -> void:
	_open = not _open
	for kind in _rows:
		(_rows[kind] as Control).visible = _open
	# Open, the list lies across the purse and the gauges, so it is drawn
	# thinner than usual: a child watching their coins while they sort the bag
	# should still be able to read them through it.
	modulate.a = 0.86 if _open else 1.0
	_refresh_title()

## Is the bag open? For the checks.
func is_open() -> bool:
	return _open

## How tall the bag is with the list folded away: the title row and the panel's
## own margins, and nothing else.
##
## The screen below the bag is laid out against this number rather than against
## the bag's actual height, so opening the bag moves nothing. An open bag is
## eight rows tall, and anything that made room for it pushed the purse, the
## gauges and the buttons off the bottom of the screen — which is the crowding
## the fold was meant to cure. So the list unrolls *over* what is underneath
## instead, translucent, the way a held-up hand covers a page without moving it.
func shut_height() -> float:
	var style := get_theme_stylebox("panel")
	var margins := style.content_margin_top + style.content_margin_bottom
	return _title.get_combined_minimum_size().y + margins

## The title says what is in the bag without opening it: how many kinds, and
## which way tapping will take you.
func _refresh_title() -> void:
	if _title == null:
		return
	var kinds := 0
	for kind in _seen:
		kinds += 1
	_title.text = "%s  %d  %s" % [Text.of("ui_bag"), kinds, "▾" if _open else "▸"]

## One item's count changed.
func set_count(kind: StringName, total: int) -> void:
	if total > 0:
		_seen[kind] = true
		visible = true
	if not _seen.has(kind):
		return

	var row: HBoxContainer = _rows.get(kind)
	if row == null:
		row = _build_row(kind)
		_rows[kind] = row
		_column.add_child(row)

	var count := row.get_child(2) as Label
	count.text = str(total)
	# An emptied slot stays, dimmed, so the bag does not rearrange itself.
	row.modulate = Color.WHITE if total > 0 else Color(1.0, 1.0, 1.0, 0.32)
	row.visible = _open
	_refresh_title()

func _build_row(kind: StringName) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)

	# The thing itself, drawn in its own colour. It used to be a coloured disc
	# with a letter on it — "o" for a stone, "*" for a seed — which is writing,
	# in the one part of the interface that exists so a child need not read.
	var disc := Panel.new()
	disc.custom_minimum_size = Vector2(34.0, 34.0)
	var chip := StyleBoxFlat.new()
	chip.bg_color = Color(0.10, 0.11, 0.13, 0.55)
	chip.set_corner_radius_all(17)
	disc.add_theme_stylebox_override("panel", chip)
	row.add_child(disc)

	var shape := ItemChip.new(kind)
	shape.set_anchors_preset(Control.PRESET_FULL_RECT)
	disc.add_child(shape)

	var name := Label.new()
	name.text = ItemKinds.label(kind)
	name.add_theme_font_size_override("font_size", 18)
	name.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.78))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)

	var count := Label.new()
	count.text = "0"
	count.add_theme_font_size_override("font_size", 22)
	count.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86))
	# Tabular figures, so a count going from 9 to 10 does not shift the row.
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.custom_minimum_size = Vector2(34.0, 0.0)
	row.add_child(count)

	return row
