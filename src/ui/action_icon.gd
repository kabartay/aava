class_name ActionIcon
extends Control

## The three main actions, drawn rather than written.
##
## Jump, kick and build were words. The build palette next to them has always
## been shapes, for the stated reason that a six-year-old cannot read — and
## then the buttons he presses most were labelled "jump", "kick" and "build",
## in a game that also speaks French and Russian, where the same three buttons
## said "прыжок", "тир" and "строить" and had to be re-measured to fit.
##
## Drawn with the 2D primitives, like `part_icon.gd`, so there is no font to
## depend on: a glyph is only as portable as the font that happens to carry it,
## and the one thing worse than a word a child cannot read is an empty box
## where the word was.

enum Kind {JUMP, KICK, BUILD, CLOSE}

## One colour for all of them, near-white and slightly warm, matching the ring
## of the movement stick.
##
## They were green, blue and yellow at first — a colour each, chosen to tell
## them apart. But the stick a child's other thumb rests on is a plain pale
## ring, and three traffic-light buttons beside it read as a control panel
## rather than as part of the same game. Shape tells them apart; colour is
## spent where it carries meaning instead, on the things in the bag and on the
## pieces in the build palette.
const INK := Color(0.94, 0.95, 0.96)

var kind: Kind = Kind.JUMP
var tint := INK

func _init(which: Kind) -> void:
	kind = which
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Swap which action this draws — the build button becomes a close button while
## the palette is open.
func show_kind(which: Kind) -> void:
	if kind == which:
		return
	kind = which
	queue_redraw()

func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	match kind:
		Kind.JUMP:
			_jump(box)
		Kind.KICK:
			_kick(box)
		Kind.BUILD:
			_build(box)
		Kind.CLOSE:
			_close(box)

## A cross. The build button turns into this while the palette is open, which
## is the same button saying "shut this" — it used to say it in words, and the
## word changed length in every language.
func _close(box: Rect2) -> void:
	var centre := box.get_center()
	var arm := minf(box.size.x, box.size.y) * 0.22
	var thick := maxf(3.0, arm * 0.32)
	draw_line(centre + Vector2(-arm, -arm), centre + Vector2(arm, arm), tint, thick)
	draw_line(centre + Vector2(-arm, arm), centre + Vector2(arm, -arm), tint, thick)

## An arrow leaving the ground. The line underneath is what makes it "up from
## here" rather than "north" — a bare arrow on a map means a direction, and
## this button is not about direction.
func _jump(box: Rect2) -> void:
	var centre := box.get_center()
	var unit := minf(box.size.x, box.size.y)
	var half := unit * 0.30

	var head := PackedVector2Array([
		centre + Vector2(0.0, -half * 1.15),
		centre + Vector2(-half * 0.78, -half * 0.10),
		centre + Vector2(half * 0.78, -half * 0.10),
	])
	draw_colored_polygon(head, tint)

	var shaft := Rect2(
		centre + Vector2(-half * 0.26, -half * 0.10),
		Vector2(half * 0.52, half * 0.72)
	)
	draw_rect(shaft, tint)

	# The ground it leaves.
	draw_line(
		centre + Vector2(-half * 0.95, half * 0.95),
		centre + Vector2(half * 0.95, half * 0.95),
		tint, maxf(2.0, unit * 0.07)
	)

## A ball, already moving. The ball alone reads as "a ball"; the three lines
## behind it are what make it "kick".
func _kick(box: Rect2) -> void:
	var unit := minf(box.size.x, box.size.y)
	var radius := unit * 0.24
	var centre := box.get_center() + Vector2(unit * 0.10, 0.0)

	draw_circle(centre, radius, tint)
	# A couple of dark facets, so it is a football rather than a dot.
	var dark := Color(0.16, 0.16, 0.18, 0.85)
	draw_circle(centre, radius * 0.30, dark)
	for turn in 3:
		var angle := TAU * float(turn) / 3.0 - PI * 0.5
		draw_circle(
			centre + Vector2(cos(angle), sin(angle)) * radius * 0.66,
			radius * 0.17, dark
		)

	for line in 3:
		var y := centre.y + (float(line) - 1.0) * radius * 0.72
		var length := radius * (1.25 if line == 1 else 0.85)
		draw_line(
			Vector2(centre.x - radius * 1.35 - length, y),
			Vector2(centre.x - radius * 1.35, y),
			tint, maxf(2.0, unit * 0.06)
		)

## A hammer, held at an angle. Brickwork was tried first and read as "a wall"
## — the thing, not the doing — while a hammer is what games have meant by
## "build" for as long as they have had a button for it.
func _build(box: Rect2) -> void:
	var unit := minf(box.size.x, box.size.y)
	var centre := box.get_center()

	var lean := Vector2(cos(-0.5), sin(-0.5))
	var across := Vector2(-lean.y, lean.x)
	var head_at := centre + lean * unit * 0.16

	# The handle, running down and back from under the head.
	draw_line(
		head_at - lean * unit * 0.02,
		head_at - lean * unit * 0.56,
		tint, unit * 0.11
	)

	# The head: a bar across the shaft, deeper on the claw side so it reads as
	# a hammer rather than a mallet.
	var half_head := unit * 0.21
	var thickness := unit * 0.12
	draw_colored_polygon(PackedVector2Array([
		head_at - across * half_head - lean * thickness,
		head_at + across * half_head - lean * thickness * 0.7,
		head_at + across * half_head + lean * thickness * 0.7,
		head_at - across * half_head + lean * thickness * 1.5,
	]), tint)
