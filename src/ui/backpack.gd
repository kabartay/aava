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

## Width of the panel. Wide enough for a two-digit count without the number
## jumping about as it changes.
const WIDTH := 190.0
const ROW_HEIGHT := 46.0

var _rows: Dictionary = {}
var _column: VBoxContainer
var _seen: Dictionary = {}

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
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 6)
	add_child(_column)

	var title := Label.new()
	title.text = Text.of("ui_bag")
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.45))
	_column.add_child(title)

	# Hidden until the first thing is picked up: an empty bag on screen from the
	# first second is clutter that explains nothing.
	visible = false

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

func _build_row(kind: StringName) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)

	# A coloured disc behind the icon, which is what makes a list of characters
	# read as a row of objects rather than as text.
	var disc := Panel.new()
	disc.custom_minimum_size = Vector2(34.0, 34.0)
	var chip := StyleBoxFlat.new()
	chip.bg_color = ItemKinds.color(kind)
	chip.bg_color.a = 0.85
	chip.set_corner_radius_all(17)
	disc.add_theme_stylebox_override("panel", chip)
	row.add_child(disc)

	var icon := Label.new()
	icon.text = ItemKinds.icon(kind)
	icon.add_theme_font_size_override("font_size", 22)
	icon.add_theme_color_override("font_color", Color(0.06, 0.07, 0.09))
	icon.position = Vector2(11.0, 4.0)
	disc.add_child(icon)

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
