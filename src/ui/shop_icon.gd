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
		ShopStock.MOTORCYCLE:
			_motorcycle(box)
		ShopStock.SADDLE:
			_saddle(box)
		ShopStock.SHEARS:
			_shears(box)
		ShopStock.CHOCOLATE:
			_chocolate(box)
		ShopStock.WHISTLE:
			_whistle(box)

## A bar of chocolate, scored into squares with the foil turned back.
func _chocolate(box: Rect2) -> void:
	var unit := minf(box.size.x, box.size.y)
	var centre := box.get_center()
	var cocoa := ShopStock.colour(ShopStock.CHOCOLATE)
	var wide := unit * 0.3
	var tall := unit * 0.22
	draw_rect(Rect2(centre - Vector2(wide, tall), Vector2(wide * 1.6, tall * 2.0)), cocoa)
	var score := Color(0.0, 0.0, 0.0, 0.4)
	draw_line(Vector2(centre.x - wide, centre.y), Vector2(centre.x + wide * 0.6, centre.y), score, maxf(1.5, unit * 0.04))
	for column in 2:
		var x := centre.x - wide + wide * 1.6 * (float(column) + 1.0) / 3.0
		draw_line(Vector2(x, centre.y - tall), Vector2(x, centre.y + tall), score, maxf(1.5, unit * 0.04))
	var foil := PackedVector2Array([
		centre + Vector2(wide * 0.6, -tall),
		centre + Vector2(wide * 1.15, -tall * 1.3),
		centre + Vector2(wide * 1.15, tall * 1.3),
		centre + Vector2(wide * 0.6, tall),
	])
	draw_colored_polygon(foil, Color(0.86, 0.87, 0.90))

## Shears: two blades crossed, with the bow handles behind them. Open rather
## than closed, because closed they are a knife.
func _shears(box: Rect2) -> void:
	var unit := minf(box.size.x, box.size.y)
	var centre := box.get_center()
	var thick := maxf(2.5, unit * 0.075)
	var pivot := centre + Vector2(0.0, unit * 0.04)
	for side: float in [-1.0, 1.0]:
		# The blade, forward and out.
		draw_line(pivot, pivot + Vector2(side * unit * 0.22, -unit * 0.38), METAL, thick)
		# The handle, back and out the other way.
		draw_line(pivot, pivot + Vector2(side * -unit * 0.1, unit * 0.22), DARK, thick * 0.8)
		draw_arc(
			pivot + Vector2(side * -unit * 0.14, unit * 0.3), unit * 0.1,
			0.0, TAU, 12, DARK, thick * 0.7
		)
	draw_circle(pivot, unit * 0.05, DARK)

## A saddle, seen from the side: the seat curving up at the cantle, the skirt
## below it, and the girth hanging under. A child who has seen a horse knows it
## at once.
func _saddle(box: Rect2) -> void:
	var unit := minf(box.size.x, box.size.y)
	var centre := box.get_center()
	var leather := ShopStock.colour(ShopStock.SADDLE)
	var seat := PackedVector2Array([
		centre + Vector2(-unit * 0.34, -unit * 0.02),
		centre + Vector2(-unit * 0.26, -unit * 0.22),
		centre + Vector2(unit * 0.14, -unit * 0.26),
		centre + Vector2(unit * 0.34, -unit * 0.04),
		centre + Vector2(unit * 0.2, unit * 0.12),
		centre + Vector2(-unit * 0.2, unit * 0.12),
	])
	draw_colored_polygon(seat, leather)
	# The skirt, a shade darker so the two read apart.
	var skirt := PackedVector2Array([
		centre + Vector2(-unit * 0.2, unit * 0.1),
		centre + Vector2(unit * 0.2, unit * 0.1),
		centre + Vector2(unit * 0.12, unit * 0.3),
		centre + Vector2(-unit * 0.12, unit * 0.3),
	])
	draw_colored_polygon(skirt, leather.darkened(0.25))
	# The stirrup on its leather.
	draw_line(
		centre + Vector2(unit * 0.02, unit * 0.1),
		centre + Vector2(unit * 0.02, unit * 0.34), DARK, maxf(2.0, unit * 0.05)
	)
	draw_arc(centre + Vector2(unit * 0.02, unit * 0.4), unit * 0.08, 0.0, TAU, 12, METAL, maxf(2.0, unit * 0.05))

## A motorcycle: the bicycle's two wheels, fattened, with a body between them
## and a plume off the back. The plume is the point — it is what tells a child
## this is the loud one before they have ever ridden it.
func _motorcycle(box: Rect2) -> void:
	var unit := minf(box.size.x, box.size.y)
	var centre := box.get_center()
	var wheel := unit * 0.2
	var axle := unit * 0.3
	var thick := maxf(2.5, unit * 0.09)
	for side: float in [-1.0, 1.0]:
		draw_arc(centre + Vector2(side * axle, unit * 0.22), wheel, 0.0, TAU, 18, DARK, thick)
	# The body: tank and seat as one slab, with the bars rising at the front.
	var body := PackedVector2Array([
		centre + Vector2(-axle - unit * 0.06, unit * 0.06),
		centre + Vector2(-axle * 0.2, -unit * 0.12),
		centre + Vector2(axle * 0.55, -unit * 0.1),
		centre + Vector2(axle + unit * 0.02, unit * 0.06),
	])
	draw_colored_polygon(body, ShopStock.colour(ShopStock.MOTORCYCLE))
	draw_line(
		centre + Vector2(-axle * 0.1, -unit * 0.12),
		centre + Vector2(-axle * 0.5, -unit * 0.3), DARK, thick * 0.8
	)
	# The plume out of the pipe.
	for puff in 3:
		var at := centre + Vector2(axle + unit * (0.14 + 0.1 * float(puff)), unit * (0.02 - 0.06 * float(puff)))
		draw_circle(at, unit * (0.05 + 0.02 * float(puff)), Color(0.78, 0.78, 0.80, 0.5 - 0.12 * float(puff)))

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
