class_name PlaceGlyph
extends Control

## A destination on the map: a coloured disc with a picture on it, and, when
## the place is off the edge of the map, a point on the rim showing which way.
##
## The map used to mark places with plain coloured squares, and only on the
## whole-valley view. Standing at the playground, a child wanting the football
## pitch had a green square somewhere on a map two taps away, and no idea
## which way to walk. Each place is a picture now — a house, a swing, a cup,
## waves, a ball, a target — because a six-year-old cannot read a label and
## a colour alone is a code to remember; and a place off the map sits on the
## map's edge pointing at itself, so the answer to "which way" is on the
## small map too, where a child actually looks.

enum Kind {HOME, PLAYGROUND, CAFE, POOL, PITCH, RANGE}

const SIZE := 28.0
const INK := Color(0.10, 0.08, 0.06)
const RIM := Color(0.0, 0.0, 0.0, 0.7)

const COLOURS := {
	Kind.HOME: Color(1.0, 0.88, 0.52),
	Kind.PLAYGROUND: Color(0.96, 0.62, 0.28),
	Kind.CAFE: Color(0.90, 0.40, 0.34),
	Kind.POOL: Color(0.42, 0.74, 0.94),
	Kind.PITCH: Color(0.46, 0.82, 0.44),
	Kind.RANGE: Color(0.80, 0.64, 0.90),
}

var kind: Kind = Kind.HOME
var pointing := false
var angle := 0.0

func _init(which: Kind) -> void:
	kind = which
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Say whether the place lies off the map, and in which direction (a screen
## angle) if so. Redraws only when that changes.
func point(off_map: bool, toward: float) -> void:
	if off_map == pointing and (not off_map or is_equal_approx(toward, angle)):
		return
	pointing = off_map
	angle = toward
	queue_redraw()

func _draw() -> void:
	var centre := size * 0.5
	var radius := SIZE * 0.40
	var colour: Color = COLOURS[kind]

	if pointing:
		# A tooth on the rim, aimed at the place, drawn under the disc.
		var direction := Vector2(cos(angle), sin(angle))
		var across := Vector2(-direction.y, direction.x)
		var tip := centre + direction * (radius + 7.0)
		draw_colored_polygon(PackedVector2Array([
			tip + direction * 1.5,
			centre + across * 7.0,
			centre - across * 7.0,
		]), RIM)
		draw_colored_polygon(PackedVector2Array([
			tip,
			centre + across * 5.0,
			centre - across * 5.0,
		]), colour)

	draw_circle(centre, radius + 1.8, RIM)
	draw_circle(centre, radius, colour)

	var unit := radius
	match kind:
		Kind.HOME:
			# A house: a box under a roof.
			draw_rect(Rect2(centre + Vector2(-unit * 0.42, -unit * 0.05), Vector2(unit * 0.84, unit * 0.62)), INK)
			draw_colored_polygon(PackedVector2Array([
				centre + Vector2(0.0, -unit * 0.7),
				centre + Vector2(unit * 0.62, -unit * 0.05),
				centre + Vector2(-unit * 0.62, -unit * 0.05),
			]), INK)
		Kind.PLAYGROUND:
			# A swing: an A-frame with a seat hanging in it.
			var w := maxf(1.5, unit * 0.14)
			draw_line(centre + Vector2(-unit * 0.6, unit * 0.6), centre + Vector2(-unit * 0.25, -unit * 0.6), INK, w)
			draw_line(centre + Vector2(unit * 0.6, unit * 0.6), centre + Vector2(unit * 0.25, -unit * 0.6), INK, w)
			draw_line(centre + Vector2(-unit * 0.4, -unit * 0.6), centre + Vector2(unit * 0.4, -unit * 0.6), INK, w)
			draw_line(centre + Vector2(-unit * 0.15, -unit * 0.6), centre + Vector2(-unit * 0.15, unit * 0.25), INK, w * 0.6)
			draw_line(centre + Vector2(unit * 0.15, -unit * 0.6), centre + Vector2(unit * 0.15, unit * 0.25), INK, w * 0.6)
			draw_line(centre + Vector2(-unit * 0.26, unit * 0.25), centre + Vector2(unit * 0.26, unit * 0.25), INK, w)
		Kind.CAFE:
			# A cup with a handle and a wisp of steam.
			draw_rect(Rect2(centre + Vector2(-unit * 0.45, -unit * 0.15), Vector2(unit * 0.7, unit * 0.62)), INK)
			draw_arc(centre + Vector2(unit * 0.28, unit * 0.15), unit * 0.3, -PI * 0.5, PI * 0.5, 8, INK, maxf(1.5, unit * 0.14))
			draw_line(centre + Vector2(-unit * 0.1, -unit * 0.3), centre + Vector2(-unit * 0.1, -unit * 0.62), INK, maxf(1.5, unit * 0.12))
		Kind.POOL:
			# Two waves.
			for row in 2:
				var y := centre.y + (float(row) - 0.5) * unit * 0.5
				var w := maxf(1.5, unit * 0.14)
				draw_arc(Vector2(centre.x - unit * 0.3, y), unit * 0.3, PI, TAU, 8, INK, w)
				draw_arc(Vector2(centre.x + unit * 0.3, y), unit * 0.3, 0.0, PI, 8, INK, w)
		Kind.PITCH:
			# A ball: a ring with a dark patch, the way the kick button draws it.
			draw_arc(centre, unit * 0.6, 0.0, TAU, 20, INK, maxf(1.5, unit * 0.14))
			draw_circle(centre, unit * 0.22, INK)
			for turn in 3:
				var a := TAU * float(turn) / 3.0 - PI * 0.5
				draw_circle(centre + Vector2(cos(a), sin(a)) * unit * 0.45, unit * 0.12, INK)
		Kind.RANGE:
			# A target: rings and a centre.
			draw_arc(centre, unit * 0.62, 0.0, TAU, 20, INK, maxf(1.5, unit * 0.14))
			draw_arc(centre, unit * 0.34, 0.0, TAU, 14, INK, maxf(1.5, unit * 0.14))
			draw_circle(centre, unit * 0.12, INK)
