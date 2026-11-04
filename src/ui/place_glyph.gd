class_name PlaceGlyph
extends Control

## A destination on the map, drawn as a sticker: a coloured disc with a thick
## white edge and a dark picture on it, and, when the place is off the edge of
## the map, a real chevron on the rim showing which way.
##
## The map used to mark places with plain coloured squares, and only on the
## whole-valley view. Standing at the playground, a child wanting the football
## pitch had a green square somewhere on a map two taps away, and no idea
## which way to walk. Each place is a picture now — a house, a swing, a cup,
## waves, a ball, a target, a wheel — because a six-year-old cannot read a label
## and a colour alone is a code to remember. Every picture has its own
## silhouette as well as its own colour, so neither is the only cue.
##
## The sticker is as big as the map allows (see `set_diameter`): the first
## version was 28 pixels, under three millimetres on the phone, which is not
## something a small finger can find, let alone press.

enum Kind {
	HOME, PLAYGROUND, CAFE, POOL, PITCH, RANGE, SHOP, BRIDGE, MOUNTAIN,
	FAIRGROUND, LAKE, BOAT, HORSE, FRIEND,
}

## The default diameter, and the largest and smallest the map asks for.
const SIZE := 36.0
const MIN_SIZE := 30.0
const MAX_SIZE := 60.0

const INK := Color(0.10, 0.08, 0.06)
const RIM := Color(0.0, 0.0, 0.0, 0.55)
const STICKER := Color(1.0, 1.0, 1.0)
const FAR_STICKER := Color(0.74, 0.80, 0.90)
const FAR_INK := Color(0.35, 0.42, 0.58)

const COLOURS := {
	Kind.HOME: Color(1.0, 0.90, 0.55),
	Kind.PLAYGROUND: Color(0.98, 0.62, 0.26),
	Kind.CAFE: Color(0.92, 0.38, 0.34),
	Kind.POOL: Color(0.42, 0.74, 0.94),
	Kind.PITCH: Color(0.46, 0.82, 0.44),
	Kind.RANGE: Color(0.80, 0.64, 0.90),
	Kind.SHOP: Color(0.98, 0.72, 0.82),
	# Timber, against the blue of the river it stands over.
	Kind.BRIDGE: Color(0.78, 0.58, 0.36),
	# Snow, because that is what the thing itself is.
	Kind.MOUNTAIN: Color(0.78, 0.82, 0.90),
	Kind.FAIRGROUND: Color(0.62, 0.60, 0.98),
	Kind.LAKE: Color(0.36, 0.82, 0.78),
	Kind.BOAT: Color(0.30, 0.55, 0.90),
	Kind.HORSE: Color(0.86, 0.70, 0.52),
	Kind.FRIEND: Color(1.0, 1.0, 1.0),
}

var kind: Kind = Kind.HOME
var pointing := false
var angle := 0.0

func _init(which: Kind, diameter := SIZE) -> void:
	kind = which
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_diameter(diameter)

## How big the sticker is. The map is small on the corner of the screen and
## large in the middle of it, and a sticker that suits one is a smudge or a
## blanket on the other.
func set_diameter(diameter: float) -> void:
	var wanted := clampf(diameter, MIN_SIZE, MAX_SIZE)
	if is_equal_approx(size.x, wanted):
		return
	custom_minimum_size = Vector2(wanted, wanted)
	size = Vector2(wanted, wanted)
	queue_redraw()

## Say whether the place lies off the map, and in which direction (a screen
## angle) if so. Redraws only when that changes.
func point(off_map: bool, toward: float) -> void:
	if off_map == pointing and (not off_map or is_equal_approx(toward, angle)):
		return
	pointing = off_map
	angle = toward
	queue_redraw()

## Whether a child may choose this place as where to go. The great mountain
## stands a kilometre past the valley: it is something to look at, not
## somewhere to walk to, and a guide to it could never end.
func is_destination() -> bool:
	return kind != Kind.MOUNTAIN

func _draw() -> void:
	var centre := size * 0.5
	var radius := size.x * 0.40
	var edge := maxf(2.5, size.x * 0.075)
	var far := kind == Kind.MOUNTAIN
	var colour: Color = COLOURS[kind]

	if pointing:
		_draw_chevrons(centre, radius + edge, colour, far)

	draw_circle(centre + Vector2(0.0, 1.5), radius + edge + 1.5, RIM)
	draw_circle(centre, radius + edge, FAR_STICKER if far else STICKER)
	draw_circle(centre, radius, colour)
	if far:
		# Dashed ring: not a place you can walk to.
		for dash in 14:
			var from := TAU * float(dash) / 14.0
			draw_arc(centre, radius + edge * 0.5, from, from + TAU / 28.0, 3, FAR_INK, edge * 0.6)

	var unit := radius
	var w := maxf(2.0, unit * 0.17)
	match kind:
		Kind.HOME:
			# A house: a box under a roof, with a door.
			draw_rect(Rect2(centre + Vector2(-unit * 0.46, -unit * 0.05), Vector2(unit * 0.92, unit * 0.68)), INK)
			draw_colored_polygon(PackedVector2Array([
				centre + Vector2(0.0, -unit * 0.78),
				centre + Vector2(unit * 0.7, 0.0),
				centre + Vector2(-unit * 0.7, 0.0),
			]), INK)
			draw_rect(Rect2(centre + Vector2(-unit * 0.13, unit * 0.2), Vector2(unit * 0.26, unit * 0.43)), colour)
		Kind.PLAYGROUND:
			# A swing: an A-frame with a seat hanging in it.
			draw_line(centre + Vector2(-unit * 0.62, unit * 0.65), centre + Vector2(-unit * 0.25, -unit * 0.6), INK, w)
			draw_line(centre + Vector2(unit * 0.62, unit * 0.65), centre + Vector2(unit * 0.25, -unit * 0.6), INK, w)
			draw_line(centre + Vector2(-unit * 0.4, -unit * 0.6), centre + Vector2(unit * 0.4, -unit * 0.6), INK, w)
			draw_line(centre + Vector2(-unit * 0.17, -unit * 0.6), centre + Vector2(-unit * 0.17, unit * 0.25), INK, w * 0.6)
			draw_line(centre + Vector2(unit * 0.17, -unit * 0.6), centre + Vector2(unit * 0.17, unit * 0.25), INK, w * 0.6)
			draw_line(centre + Vector2(-unit * 0.3, unit * 0.27), centre + Vector2(unit * 0.3, unit * 0.27), INK, w * 1.2)
		Kind.CAFE:
			# A cup with a handle and a wisp of steam.
			draw_rect(Rect2(centre + Vector2(-unit * 0.5, -unit * 0.15), Vector2(unit * 0.78, unit * 0.7)), INK)
			draw_arc(centre + Vector2(unit * 0.3, unit * 0.18), unit * 0.3, -PI * 0.5, PI * 0.5, 8, INK, w)
			draw_line(centre + Vector2(-unit * 0.12, -unit * 0.32), centre + Vector2(-unit * 0.12, -unit * 0.68), INK, w * 0.8)
			draw_line(centre + Vector2(unit * 0.12, -unit * 0.32), centre + Vector2(unit * 0.12, -unit * 0.6), INK, w * 0.8)
		Kind.POOL:
			# Two waves.
			for row in 2:
				var y := centre.y + (float(row) - 0.5) * unit * 0.58
				draw_arc(Vector2(centre.x - unit * 0.32, y), unit * 0.32, PI, TAU, 8, INK, w)
				draw_arc(Vector2(centre.x + unit * 0.32, y), unit * 0.32, 0.0, PI, 8, INK, w)
		Kind.PITCH:
			# A ball: a ring with a dark patch, the way the kick button draws it.
			draw_arc(centre, unit * 0.64, 0.0, TAU, 20, INK, w)
			draw_circle(centre, unit * 0.24, INK)
			for turn in 3:
				var a := TAU * float(turn) / 3.0 - PI * 0.5
				draw_circle(centre + Vector2(cos(a), sin(a)) * unit * 0.48, unit * 0.13, INK)
		Kind.RANGE:
			# A target: rings and a centre.
			draw_arc(centre, unit * 0.66, 0.0, TAU, 20, INK, w)
			draw_arc(centre, unit * 0.36, 0.0, TAU, 14, INK, w)
			draw_circle(centre, unit * 0.13, INK)
		Kind.MOUNTAIN:
			# Two summits with a saddle between them: the mountain's own
			# outline, so that the mark on the rim of the map and the thing on
			# the skyline are recognisably each other.
			draw_colored_polygon(PackedVector2Array([
				centre + Vector2(-unit * 0.78, unit * 0.46),
				centre + Vector2(-unit * 0.22, -unit * 0.52),
				centre + Vector2(unit * 0.06, -unit * 0.02),
				centre + Vector2(unit * 0.30, -unit * 0.38),
				centre + Vector2(unit * 0.78, unit * 0.46),
			]), Color(0.28, 0.34, 0.48))
		Kind.BRIDGE:
			# An arch over water: the shape of the thing itself.
			draw_arc(centre + Vector2(0.0, unit * 0.34), unit * 0.62, PI, TAU, 14, INK, w)
			draw_line(centre + Vector2(-unit * 0.62, unit * 0.34), centre + Vector2(unit * 0.62, unit * 0.34), INK, w)
			draw_line(centre + Vector2(-unit * 0.5, unit * 0.68), centre + Vector2(unit * 0.5, unit * 0.68), INK, w * 0.7)
		Kind.SHOP:
			# An awning over a counter: the front of a shop.
			var wide := unit * 0.64
			draw_line(centre + Vector2(-wide, -unit * 0.18), centre + Vector2(wide, -unit * 0.18), INK, w * 1.1)
			for scallop in 3:
				var x := -wide + wide * (float(scallop) + 0.5) * 2.0 / 3.0
				draw_arc(centre + Vector2(x, -unit * 0.1), unit * 0.21, 0.0, PI, 8, INK, w * 0.8)
			draw_line(centre + Vector2(-wide * 0.7, unit * 0.28), centre + Vector2(wide * 0.7, unit * 0.28), INK, w)
		Kind.FAIRGROUND:
			# A big wheel on its stand: the one thing at a fair you can see
			# from the other side of the valley.
			var hub := centre + Vector2(0.0, -unit * 0.1)
			draw_arc(hub, unit * 0.56, 0.0, TAU, 24, INK, w * 0.9)
			for spoke in 4:
				var a := PI * float(spoke) / 4.0
				var d := Vector2(cos(a), sin(a)) * unit * 0.56
				draw_line(hub - d, hub + d, INK, w * 0.5)
			draw_circle(hub, unit * 0.14, INK)
			draw_line(hub, centre + Vector2(-unit * 0.45, unit * 0.74), INK, w * 0.8)
			draw_line(hub, centre + Vector2(unit * 0.45, unit * 0.74), INK, w * 0.8)
		Kind.LAKE:
			# A fish: something that lives in a lake and nowhere else on the map.
			var body := PackedVector2Array()
			for step in 17:
				var a := TAU * float(step) / 17.0
				body.append(centre + Vector2(-unit * 0.12 + cos(a) * unit * 0.56, sin(a) * unit * 0.34))
			draw_colored_polygon(body, INK)
			draw_colored_polygon(PackedVector2Array([
				centre + Vector2(unit * 0.34, 0.0),
				centre + Vector2(unit * 0.8, -unit * 0.36),
				centre + Vector2(unit * 0.8, unit * 0.36),
			]), INK)
			draw_circle(centre + Vector2(-unit * 0.4, -unit * 0.07), unit * 0.09, colour)
		Kind.BOAT:
			# A sailing boat: hull, mast and two sails.
			draw_colored_polygon(PackedVector2Array([
				centre + Vector2(-unit * 0.72, unit * 0.22),
				centre + Vector2(unit * 0.72, unit * 0.22),
				centre + Vector2(unit * 0.46, unit * 0.62),
				centre + Vector2(-unit * 0.46, unit * 0.62),
			]), INK)
			draw_line(centre + Vector2(0.0, unit * 0.22), centre + Vector2(0.0, -unit * 0.74), INK, w * 0.7)
			draw_colored_polygon(PackedVector2Array([
				centre + Vector2(unit * 0.08, -unit * 0.7),
				centre + Vector2(unit * 0.62, unit * 0.12),
				centre + Vector2(unit * 0.08, unit * 0.12),
			]), INK)
			draw_colored_polygon(PackedVector2Array([
				centre + Vector2(-unit * 0.08, -unit * 0.42),
				centre + Vector2(-unit * 0.5, unit * 0.12),
				centre + Vector2(-unit * 0.08, unit * 0.12),
			]), INK)
		Kind.HORSE:
			# A horseshoe, open end up, with its nail holes.
			var middle := centre + Vector2(0.0, unit * 0.08)
			draw_arc(middle, unit * 0.5, -PI * 0.5 + 0.7, PI * 1.5 - 0.7, 24, INK, unit * 0.36)
			for nail in 3:
				var a := PI * 0.5 + (float(nail) - 1.0) * 0.8
				draw_circle(middle + Vector2(cos(a), sin(a)) * unit * 0.5, unit * 0.07, colour)
		Kind.FRIEND:
			# A person: a head over a pair of shoulders — a face rather than
			# a building.
			draw_circle(centre + Vector2(0.0, -unit * 0.28), unit * 0.28, INK)
			var shoulders := PackedVector2Array()
			for step in 13:
				var a := PI + PI * float(step) / 12.0
				shoulders.append(centre + Vector2(cos(a) * unit * 0.62, unit * 0.7 + sin(a) * unit * 0.58))
			draw_colored_polygon(shoulders, INK)
			draw_circle(centre + Vector2(-unit * 0.1, -unit * 0.31), unit * 0.045, colour)
			draw_circle(centre + Vector2(unit * 0.1, -unit * 0.31), unit * 0.045, colour)

## One chevron on the rim, or two for something far beyond the valley, aimed
## at the place. Big enough to see: the tooth it replaces was under a
## millimetre long.
func _draw_chevrons(centre: Vector2, from: float, colour: Color, double: bool) -> void:
	var direction := Vector2(cos(angle), sin(angle))
	var across := Vector2(-direction.y, direction.x)
	var length := size.x * 0.30
	var spread := size.x * 0.30
	for index in (2 if double else 1):
		var base := centre + direction * (from + 1.0 + float(index) * length * 0.8)
		var tip := base + direction * length
		var outer := PackedVector2Array([base + across * spread, tip, base - across * spread])
		var inner := PackedVector2Array([
			base + across * spread * 0.55 + direction * 1.0,
			tip - direction * 3.0,
			base - across * spread * 0.55 + direction * 1.0,
		])
		# A dark edge first, so that it reads on the river and the snow alike.
		draw_colored_polygon(PackedVector2Array([
			base + across * (spread + 2.5) - direction * 1.5,
			tip + direction * 3.0,
			base - across * (spread + 2.5) - direction * 1.5,
		]), RIM)
		draw_colored_polygon(outer, FAR_STICKER if double else STICKER)
		draw_colored_polygon(inner, FAR_INK if double else colour)
