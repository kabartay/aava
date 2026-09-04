class_name ShopIcon
extends Control

## A tiny drawing of a thing for sale, for the shop.
##
## The shop listed five rows of words. The eldest can read them; the six-year-old
## cannot, and he is the one most likely to be saving up for the bicycle. An
## icon is the only part of a shop row that works before you can read, so it
## carries the meaning and the words merely confirm it.
##
## Drawn with 2D primitives, matching PartIcon — see that file for why a
## viewport per row is not worth eight render passes.

const METAL := Color(0.72, 0.75, 0.80)
const DARK := Color(0.22, 0.20, 0.18)
const TIMBER := Color(0.52, 0.37, 0.22)
const WATER := Color(0.38, 0.66, 0.86)
const GLASS := Color(0.80, 0.88, 0.94)
const FLAME := Color(1.0, 0.82, 0.36)
const BRASS := Color(0.85, 0.68, 0.30)

var kind: StringName

func _init(item_kind: StringName) -> void:
	kind = item_kind
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	# custom_minimum_size, not size: inside a container the laid-out size is
	# still zero when _draw first runs, so drawing against it produces nothing
	# and never redraws. The caller always sets a minimum, so it is the reliable
	# one. (Connecting resized to queue_redraw instead causes an endless
	# redraw/relayout loop that hangs the process.)
	var extent := custom_minimum_size if custom_minimum_size.x > 0.0 else size
	var box := Rect2(extent * 0.16, extent * 0.68)
	match kind:
		ShopStock.BOTTLE:
			_bottle(box)
		ShopStock.AXE:
			_axe(box)
		ShopStock.LANTERN:
			_lantern(box)
		ShopStock.BICYCLE:
			_bicycle(box)
		ShopStock.WHISTLE:
			_whistle(box)

## A bottle reads by its neck and its waterline — the two things that say
## "this holds a drink" rather than "this is a box".
func _bottle(box: Rect2) -> void:
	var neck_w := box.size.x * 0.28
	var neck := Rect2(
		box.position.x + (box.size.x - neck_w) * 0.5, box.position.y,
		neck_w, box.size.y * 0.22
	)
	draw_rect(neck, GLASS)

	var body := Rect2(
		box.position.x + box.size.x * 0.18, box.position.y + box.size.y * 0.22,
		box.size.x * 0.64, box.size.y * 0.78
	)
	draw_rect(body, GLASS)
	# Filled to just over half, so the icon shows what the bottle is for.
	var fill := Rect2(
		body.position.x, body.position.y + body.size.y * 0.42,
		body.size.x, body.size.y * 0.58
	)
	draw_rect(fill, WATER)
	draw_rect(body, DARK, false, 1.5)

func _axe(box: Rect2) -> void:
	var haft_w := box.size.x * 0.16
	draw_rect(Rect2(
		box.position.x + box.size.x * 0.42, box.position.y + box.size.y * 0.12,
		haft_w, box.size.y * 0.88
	), TIMBER)

	# The head is a wedge, because a rectangle on a stick is a hammer. It is
	# anchored well inside the box: the first version started at the very top
	# edge and the whole head fell outside the icon, leaving a bare stick.
	var top := box.position.y + box.size.y * 0.14
	var head := PackedVector2Array([
		Vector2(box.position.x + box.size.x * 0.46, top),
		Vector2(box.position.x + box.size.x * 0.04, top + box.size.y * 0.10),
		Vector2(box.position.x + box.size.x * 0.04, top + box.size.y * 0.34),
		Vector2(box.position.x + box.size.x * 0.46, top + box.size.y * 0.44),
	])
	draw_colored_polygon(head, METAL)
	draw_polyline(head + PackedVector2Array([head[0]]), DARK, 1.5)

func _lantern(box: Rect2) -> void:
	var centre_x := box.position.x + box.size.x * 0.5
	# The hoop handle is most of what makes a lantern a lantern.
	draw_arc(
		Vector2(centre_x, box.position.y + box.size.y * 0.26),
		box.size.x * 0.22, PI, TAU, 16, DARK, 2.5
	)
	var housing := Rect2(
		box.position.x + box.size.x * 0.22, box.position.y + box.size.y * 0.26,
		box.size.x * 0.56, box.size.y * 0.62
	)
	draw_rect(housing, DARK)
	draw_rect(housing.grow(-housing.size.x * 0.18), FLAME)

func _bicycle(box: Rect2) -> void:
	# Two wheels is the whole point of the icon, so they are drawn first and
	# sized to the box rather than to the frame. An earlier version used a
	# radius that put them outside the icon and only the frame survived.
	var radius := box.size.x * 0.26
	var y := box.position.y + box.size.y * 0.62
	var left := Vector2(box.position.x + radius + box.size.x * 0.02, y)
	var right := Vector2(box.position.x + box.size.x - radius - box.size.x * 0.02, y)
	# draw_circle with filled=false, not draw_arc: at this size the arc was
	# producing nothing at all and the bicycle had no wheels.
	draw_circle(left, radius, DARK, false, 3.0)
	draw_circle(right, radius, DARK, false, 3.0)

	# The frame triangle and the handlebars, which is the rest of it.
	var top := Vector2((left.x + right.x) * 0.5, box.position.y + box.size.y * 0.22)
	draw_line(left, top, METAL, 3.0)
	draw_line(right, top, METAL, 3.0)
	draw_line(left, right, METAL, 3.0)
	draw_line(top, Vector2(right.x, box.position.y + box.size.y * 0.14), METAL, 3.0)

func _whistle(box: Rect2) -> void:
	var body := Rect2(
		box.position.x + box.size.x * 0.10, box.position.y + box.size.y * 0.36,
		box.size.x * 0.62, box.size.y * 0.30
	)
	draw_rect(body, BRASS)
	draw_rect(body, DARK, false, 1.5)
	# The mouthpiece tapers away to the right, and the ring hangs at the left.
	draw_colored_polygon(PackedVector2Array([
		Vector2(body.position.x + body.size.x, body.position.y),
		Vector2(box.position.x + box.size.x * 0.96, body.position.y + body.size.y * 0.30),
		Vector2(box.position.x + box.size.x * 0.96, body.position.y + body.size.y * 0.70),
		Vector2(body.position.x + body.size.x, body.position.y + body.size.y),
	]), BRASS)
	draw_circle(
		Vector2(body.position.x, body.position.y + body.size.y * 0.5),
		box.size.x * 0.10, DARK, false, 2.0
	)
