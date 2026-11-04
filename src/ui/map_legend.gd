class_name MapLegend
extends Control

## The key to the map: every picture on it, with its name beside it.
##
## Optional and closable: a small round "?" in the corner of the large and
## whole-valley maps opens it over the picture, and a tap anywhere on it (or on
## its cross) closes it. The pictures do the work for a child who cannot read;
## the words are for the grown-up beside them, and for the child who is
## learning to.

## What is on it, in the order it is read: a picture and the text key naming it.
## A kind of place, or one of the three marks that are not places.
const YOU := -1
const BUILT := -2
const PLANTED := -3

const ENTRIES: Array[Array] = [
	[PlaceGlyph.Kind.HOME, "map_home"],
	[PlaceGlyph.Kind.PLAYGROUND, "place_playground"],
	[PlaceGlyph.Kind.CAFE, "place_cafe"],
	[PlaceGlyph.Kind.POOL, "place_pool"],
	[PlaceGlyph.Kind.PITCH, "map_pitch"],
	[PlaceGlyph.Kind.RANGE, "map_range"],
	[PlaceGlyph.Kind.SHOP, "place_shop"],
	[PlaceGlyph.Kind.FAIRGROUND, "map_fairground"],
	[PlaceGlyph.Kind.BRIDGE, "map_bridge"],
	[PlaceGlyph.Kind.LAKE, "map_lake"],
	[PlaceGlyph.Kind.BOAT, "map_boats"],
	[PlaceGlyph.Kind.HORSE, "map_horse"],
	[PlaceGlyph.Kind.FRIEND, "map_friend"],
	[PlaceGlyph.Kind.MOUNTAIN, "map_mountain"],
	[YOU, "map_you"],
	[BUILT, "map_built"],
	[PLANTED, "map_planted"],
]

## The text key naming a kind of place, for the legend and for what is said
## when one is chosen.
static func name_key(kind: int) -> String:
	for entry in ENTRIES:
		if entry[0] == kind:
			return entry[1]
	return "map_home"

const FONT_SIZE := 14
const PAD := 8.0
const HEADER := 30.0
const BUTTON := 40.0

var _open := false
var _rows: Array[Dictionary] = []
var _built_for := Vector2.ZERO

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## The map is this big now. Lays the key out to fit it, whatever its size.
func fit(canvas: Vector2) -> void:
	if canvas == _built_for:
		return
	_built_for = canvas
	size = canvas
	position = Vector2.ZERO
	# Out of the tree at once, not at the end of the frame: a key that is laid
	# out twice in one frame would otherwise hold both.
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_rows.clear()
	var columns := 2
	var per_column := ceili(float(ENTRIES.size()) / float(columns))
	var column_w := (canvas.x - PAD * 4.0) / float(columns)
	var row_h := minf(32.0, (canvas.y - HEADER - PAD * 4.0) / float(per_column))
	var icon := minf(row_h - 2.0, 30.0)
	for i in ENTRIES.size():
		var entry := ENTRIES[i]
		var column := i / per_column
		var row := i % per_column
		var origin := Vector2(PAD * 2.0 + column_w * float(column), PAD * 2.0 + HEADER + row_h * float(row))
		var picture: Control
		var which: int = entry[0]
		if which >= 0:
			var glyph := PlaceGlyph.new(which as PlaceGlyph.Kind, icon)
			glyph.set_diameter(icon)
			picture = glyph
		elif which == YOU:
			picture = MapArrow.new()
		else:
			var swatch := ColorRect.new()
			swatch.color = Minimap.BUILT if which == BUILT else Minimap.PLANTED
			swatch.custom_minimum_size = Vector2(icon * 0.6, icon * 0.6)
			swatch.size = Vector2(icon * 0.6, icon * 0.6)
			swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
			picture = swatch
		picture.position = origin + (Vector2(icon, row_h) - picture.size) * 0.5
		add_child(picture)
		var label := Label.new()
		label.add_theme_font_size_override("font_size", FONT_SIZE)
		label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.size = Vector2(column_w - icon - 8.0, row_h)
		label.position = origin + Vector2(icon + 6.0, 0.0)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		_rows.append({"label": label, "key": entry[1], "width": label.size.x, "picture": picture})
	_retext()
	set_open(_open)

## Say it again, in whichever language the game speaks now.
func _retext() -> void:
	for row in _rows:
		(row["label"] as Label).text = Text.of(row["key"])

func is_open() -> bool:
	return _open

func set_open(open: bool) -> void:
	_open = open
	if open:
		_retext()
	for child in get_children():
		(child as CanvasItem).visible = open
	queue_redraw()

## The little "?" that opens it, in the map's own coordinates. At the top left:
## the top right is the compass's, and the buttons for zoom and close stand in a
## strip beside the picture.
func button_rect() -> Rect2:
	return Rect2(Vector2(5.0, 5.0), Vector2(BUTTON, BUTTON))

## The legend's own panel, over the whole map but for a margin.
func panel_rect() -> Rect2:
	return Rect2(Vector2(PAD, PAD), _built_for - Vector2(PAD, PAD) * 2.0)

## Whether the key's text fits its columns in the current language: for the
## checks, which look at every language rather than just the one on screen.
func widest_overrun(font: Font) -> float:
	var worst := -INF
	for row in _rows:
		for code: StringName in [Text.EN, Text.FR, Text.RU]:
			var was := Text.language()
			Text.set_language(code)
			var words := Text.of(row["key"])
			Text.set_language(was)
			worst = maxf(worst, font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x - float(row["width"]))
	return worst

func _draw() -> void:
	if _built_for == Vector2.ZERO:
		return
	if not _open:
		var button := button_rect()
		var middle := button.get_center()
		draw_circle(middle, BUTTON * 0.5 + 2.0, Color(0.0, 0.0, 0.0, 0.5))
		draw_circle(middle, BUTTON * 0.5, Color(1.0, 1.0, 1.0, 0.95))
		var font := ThemeDB.fallback_font
		draw_string(font, middle + Vector2(-BUTTON * 0.5, 9.0), "?", HORIZONTAL_ALIGNMENT_CENTER, BUTTON, 28, Color(0.1, 0.12, 0.16))
		return
	var panel := panel_rect()
	draw_rect(panel, Color(0.07, 0.09, 0.12, 0.97))
	draw_rect(panel, Color(1.0, 1.0, 1.0, 0.25), false, 1.5)
	# The cross, top right.
	var cross := Vector2(panel.end.x - 20.0, panel.position.y + 18.0)
	draw_circle(cross, 13.0, Color(1.0, 1.0, 1.0, 0.9))
	draw_line(cross + Vector2(-5.0, -5.0), cross + Vector2(5.0, 5.0), Color(0.1, 0.12, 0.16), 3.0)
	draw_line(cross + Vector2(5.0, -5.0), cross + Vector2(-5.0, 5.0), Color(0.1, 0.12, 0.16), 3.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(panel.position.x + 12.0, panel.position.y + 22.0), Text.of("map_legend"), HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 50.0, 16, Color(1.0, 0.94, 0.8))
