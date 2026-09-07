class_name ItemChip
extends Control

## What a thing in the bag looks like: its own shape, in its own colour.
##
## The bag used to show a coloured disc with a character sitting on it — "o"
## for a stone, "*" for a seed, "A" for a cone. The letters were meant as
## pictures and were not: a stone and a seed both came out as a circle with
## something written on it, and the something was a letter in a game whose
## whole interface exists so that a six-year-old does not have to read.
##
## Shape carries it now, and colour agrees with it. Two signals rather than
## one, which also means the row still reads for a child who cannot tell the
## brown of a stick from the brown of a cone.

var kind: StringName = &""
var tint := Color(1.0, 1.0, 1.0)

func _init(item: StringName) -> void:
	kind = item
	tint = ItemKinds.color(item)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	match kind:
		ItemKinds.STICK:
			_stick(box)
		ItemKinds.STONE:
			_stone(box)
		ItemKinds.REED:
			_reed(box)
		ItemKinds.SEED:
			_seed(box)
		ItemKinds.CONE:
			_cone(box)
		_:
			draw_circle(box.get_center(), minf(box.size.x, box.size.y) * 0.32, tint)

## A length of wood, lying at an angle with a stub of a branch on it.
func _stick(box: Rect2) -> void:
	var centre := box.get_center()
	var unit := minf(box.size.x, box.size.y)
	var reach := unit * 0.34
	var lean := Vector2(cos(-0.6), sin(-0.6))
	draw_line(centre - lean * reach, centre + lean * reach, tint, unit * 0.13)
	# The stub, which is what stops it reading as a plain diagonal line.
	var fork := Vector2(cos(0.5), sin(0.5))
	draw_line(centre + lean * reach * 0.15, centre + lean * reach * 0.15 + fork * reach * 0.5, tint, unit * 0.09)

## A pebble: not a circle, because a circle is a ball. Flat-bottomed and
## lopsided, the way a stone lies.
func _stone(box: Rect2) -> void:
	var centre := box.get_center()
	var unit := minf(box.size.x, box.size.y)
	var r := unit * 0.33
	var outline := PackedVector2Array([
		centre + Vector2(-r, r * 0.42),
		centre + Vector2(-r * 0.86, -r * 0.22),
		centre + Vector2(-r * 0.24, -r * 0.62),
		centre + Vector2(r * 0.55, -r * 0.5),
		centre + Vector2(r, r * 0.08),
		centre + Vector2(r * 0.72, r * 0.42),
	])
	draw_colored_polygon(outline, tint)

## A blade of reed: tall, narrow, and bent at the top the way a reed leans.
func _reed(box: Rect2) -> void:
	var centre := box.get_center()
	var unit := minf(box.size.x, box.size.y)
	var height := unit * 0.36
	var foot := centre + Vector2(-unit * 0.04, height)
	draw_line(foot, foot + Vector2(unit * 0.10, -height * 1.5), tint, unit * 0.10)
	# A second, shorter blade, so it is a clump rather than a stick.
	draw_line(
		foot + Vector2(unit * 0.13, 0.0),
		foot + Vector2(unit * 0.26, -height * 1.05), tint, unit * 0.08
	)

## A seed: a small teardrop, fat at the bottom and pointed at the top.
func _seed(box: Rect2) -> void:
	var centre := box.get_center()
	var unit := minf(box.size.x, box.size.y)
	var r := unit * 0.22
	draw_circle(centre + Vector2(0.0, r * 0.45), r, tint)
	draw_colored_polygon(PackedVector2Array([
		centre + Vector2(-r * 0.92, r * 0.35),
		centre + Vector2(0.0, -r * 1.5),
		centre + Vector2(r * 0.92, r * 0.35),
	]), tint)

## A pine cone: an egg-shaped body covered in staggered scales, with a stalk.
## The first version was a triangle with two stripes across it, and read as a
## triangle. Scales are what make a cone a cone.
func _cone(box: Rect2) -> void:
	var centre := box.get_center() + Vector2(0.0, minf(box.size.x, box.size.y) * 0.04)
	var unit := minf(box.size.x, box.size.y)
	var half_h := unit * 0.32
	var half_w := unit * 0.22

	# The body: fuller below the middle, tapering to a rounded top.
	var body := PackedVector2Array()
	var steps := 24
	for i in steps:
		var a := TAU * float(i) / float(steps)
		var y := sin(a)
		# Wider towards the bottom (positive y is down on screen).
		var w := half_w * (0.72 + 0.28 * clampf(y, -1.0, 1.0))
		body.append(centre + Vector2(cos(a) * w, y * half_h))
	draw_colored_polygon(body, tint)

	# The stalk.
	draw_line(
		centre + Vector2(0.0, -half_h),
		centre + Vector2(unit * 0.03, -half_h - unit * 0.09),
		tint.darkened(0.25), maxf(2.0, unit * 0.05)
	)

	# Scales: rows of small dark half-discs, each row offset by half a scale,
	# which is the one thing a triangle can never look like.
	var scale := Color(tint.darkened(0.45), 0.9)
	var rows := 4
	for row in rows:
		var y := centre.y - half_h * 0.55 + float(row) * half_h * 0.42
		var count := 2 if row % 2 == 0 else 3
		var w_here := half_w * (0.72 + 0.28 * clampf((y - centre.y) / half_h, -1.0, 1.0))
		for k in count:
			var x := centre.x + (float(k) - float(count - 1) * 0.5) * w_here * 0.9
			draw_arc(Vector2(x, y), unit * 0.055, PI, TAU, 8, scale, maxf(1.5, unit * 0.035))
