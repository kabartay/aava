class_name GuideBadge
extends Control

## The pointer a child follows once they have chosen a place on the map.
##
## A small sticker of the place, riding an invisible oval round the middle of
## the play screen, with a chevron on its outer side that turns to say which
## way to walk from where the camera is looking, and five little feet that
## fill up the further away it is. A number follows for the child who can read
## one. It is the place's own picture, so it needs no words; it sits round the
## edge of the screen, away from the stick and the buttons; and a tap on it
## puts it away.
##
## Hidden while the map itself is big (the map shows the way then), while a
## child builds, and when nothing is chosen.

const DIAMETER := 46.0
## The oval it rides, as a fraction of the screen. When a button is in the way
## it moves in along the same ray, which keeps the chevron honest.
const RIDE := Vector2(0.30, 0.27)
const WIDTH := 96.0
const HEIGHT := 112.0

var _guide: MapGuide
var _glyph: PlaceGlyph
var _shown_kind := -1
## Set by whoever knows the map is big, or the child is building.
var suppressed := false
## Asked for the rectangles of the buttons and panels the badge must not lie on,
## as an Array of Rect2 in screen coordinates. Optional.
var keep_clear := Callable()
var _pulse := 0.0

func _init() -> void:
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	size = Vector2(WIDTH, HEIGHT)
	# Only this small patch takes a touch, and only to put itself away.
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

func bind(guide: MapGuide) -> void:
	_guide = guide

func _gui_input(event: InputEvent) -> void:
	var tapped := false
	if event is InputEventScreenTouch:
		tapped = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		tapped = click.pressed and click.button_index == MOUSE_BUTTON_LEFT
	if tapped and _guide != null:
		_guide.clear()
		accept_event()

## Where the badge is for a direction (clockwise from up) on a screen this big:
## the point on the oval in that direction. The middle of the badge.
static func spot_for(angle: float, screen: Vector2) -> Vector2:
	var direction := Vector2(sin(angle), -cos(angle))
	var radii := Vector2(screen.x * RIDE.x, screen.y * RIDE.y)
	# The ray from the centre meets the oval at t where (dx t / rx)^2 + (dy t / ry)^2 = 1.
	var t := 1.0 / sqrt(pow(direction.x / radii.x, 2.0) + pow(direction.y / radii.y, 2.0))
	return screen * 0.5 + direction * t

## Where the badge sits for a direction: the point on the oval, or, if that
## would cover one of `clear`, the nearest point along the same ray from the
## middle that does not. The middle of the badge, as `spot_for`.
static func spot_clear_of(angle: float, screen: Vector2, clear: Array[Rect2]) -> Vector2:
	var rim := spot_for(angle, screen)
	var middle := screen * 0.5
	for scale: float in [1.0, 0.88, 0.76, 0.64, 1.1, 1.2]:
		var spot := middle + (rim - middle) * scale
		var box := Rect2(spot - Vector2(WIDTH * 0.5, DIAMETER * 0.5 + 8.0), Vector2(WIDTH, HEIGHT))
		var on_screen := Rect2(Vector2.ZERO, screen).encloses(box)
		var free := on_screen
		for rect in clear:
			if rect.intersects(box):
				free = false
				break
		if free:
			return spot
	return rim

func _process(delta: float) -> void:
	var showing := _guide != null and _guide.active and not suppressed
	if visible != showing:
		visible = showing
	if not showing:
		return
	_pulse += delta
	if _shown_kind != _guide.kind:
		_shown_kind = _guide.kind
		if _glyph != null:
			_glyph.queue_free()
		_glyph = PlaceGlyph.new(_guide.kind as PlaceGlyph.Kind, DIAMETER)
		add_child(_glyph)
	var screen := get_viewport_rect().size
	var clear: Array[Rect2] = []
	if keep_clear.is_valid():
		clear = keep_clear.call()
	position = spot_clear_of(_guide.angle, screen, clear) - Vector2(WIDTH * 0.5, DIAMETER * 0.5 + 8.0)
	_glyph.position = Vector2(WIDTH * 0.5 - DIAMETER * 0.5, 8.0)
	queue_redraw()

func _draw() -> void:
	if _guide == null or not _guide.active:
		return
	var centre := Vector2(WIDTH * 0.5, DIAMETER * 0.5 + 8.0)
	# The chevron, outside the sticker along the way to go. It breathes.
	var direction := Vector2(sin(_guide.angle), -cos(_guide.angle))
	var across := Vector2(-direction.y, direction.x)
	var breath := 1.0 + 0.12 * sin(_pulse * 4.0)
	var base := centre + direction * (DIAMETER * 0.5 + 3.0)
	var tip := base + direction * 15.0 * breath
	draw_colored_polygon(PackedVector2Array([
		base + across * 12.0, tip + direction * 2.0, base - across * 12.0,
	]), Color(0.0, 0.0, 0.0, 0.5))
	draw_colored_polygon(PackedVector2Array([
		base + across * 10.0, tip, base - across * 10.0,
	]), Color(1.0, 1.0, 1.0))
	# Five footprints under it, as many filled as it is far.
	var filled := MapGuide.pips_for(_guide.distance)
	var y := DIAMETER + 20.0
	for pip in MapGuide.PIPS:
		var x := WIDTH * 0.5 + (float(pip) - 2.0) * 13.0
		draw_circle(Vector2(x, y), 5.0, Color(0.0, 0.0, 0.0, 0.55))
		draw_circle(Vector2(x, y), 3.8, Color(1.0, 0.95, 0.7) if pip < filled else Color(1.0, 1.0, 1.0, 0.28))
	var font := ThemeDB.fallback_font
	var words := Text.format("map_metres", [MapGuide.rounded(_guide.distance)])
	var width := WIDTH
	draw_string_outline(font, Vector2(0.0, y + 20.0), words, HORIZONTAL_ALIGNMENT_CENTER, width, 17, 5, Color(0.0, 0.0, 0.0, 0.8))
	draw_string(font, Vector2(0.0, y + 20.0), words, HORIZONTAL_ALIGNMENT_CENTER, width, 17, Color(1.0, 1.0, 1.0))
