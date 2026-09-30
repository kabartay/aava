class_name ActionIcon
extends Control

## Every action button's face, drawn rather than written.
##
## Jump, kick and build were words. The build palette next to them has always
## been shapes, for the stated reason that a six-year-old cannot read — and
## then the buttons he presses most were labelled "jump", "kick" and "build",
## in a game that also speaks French and Russian, where the same three buttons
## said "прыжок", "тир" and "строить" and had to be re-measured to fit. Once
## those three were drawn, the ten contextual buttons beside them — drink,
## whistle, chop, ride, shoot, swing, eat, the stick for the dam, the log for
## the fire, sleep, talk — were the only words left on a child's screen, so
## they are drawn too.
##
## Drawn with the 2D primitives, like `part_icon.gd`, so there is no font to
## depend on: a glyph is only as portable as the font that happens to carry it,
## and the one thing worse than a word a child cannot read is an empty box
## where the word was.

enum Kind {
	JUMP, KICK, BUILD, CLOSE,
	DRINK, WHISTLE, CHOP, RIDE, GET_OFF, SHOOT,
	SWING, EAT, GIVE_STICK, FEED_FIRE, SLEEP, TALK, THROW, ROW, TICKET, SHOP,
	SNACK, LANTERN, RIDE_BICYCLE, RIDE_MOTORCYCLE, RIDE_QUAD,
	LEAVE_BICYCLE, LEAVE_MOTORCYCLE, LEAVE_QUAD,
	VIEW_FIRST, VIEW_THIRD,
	MIC_ON, MIC_OFF,
	MAP, TOGETHER, BAG, SETTINGS,
	DIVE, SURFACE,
}

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

## A second, dimmer tone for the part of a glyph that is "inside" — the water
## in the cup, the steam over the bowl — so a shape is not one flat blot.
const INK_SOFT := Color(0.94, 0.95, 0.96, 0.55)

## The dark of the button behind, for holes and facets cut into a glyph.
const HOLE := Color(0.16, 0.16, 0.18, 0.85)

var kind: Kind = Kind.JUMP
var tint := INK

func _init(which: Kind) -> void:
	kind = which
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Swap which action this draws — the build button becomes a close button while
## the palette is open, the ride button becomes get-off while mounted, the
## place button is a swing at the playground and a meal at the café.
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
		Kind.DRINK:
			_drink(box)
		Kind.WHISTLE:
			_whistle(box)
		Kind.CHOP:
			_chop(box)
		Kind.RIDE:
			_ride(box, false)
		Kind.GET_OFF:
			_ride(box, true)
		Kind.SHOOT:
			_shoot(box)
		Kind.SWING:
			_swing(box)
		Kind.EAT:
			_eat(box)
		Kind.GIVE_STICK:
			_give_stick(box)
		Kind.FEED_FIRE:
			_feed_fire(box)
		Kind.SLEEP:
			_sleep(box)
		Kind.TALK:
			_talk(box)
		Kind.THROW:
			_throw(box)
		Kind.ROW:
			_row(box)
		Kind.TICKET:
			_ticket(box)
		Kind.SHOP:
			_shop(box)
		Kind.SNACK:
			_snack(box)
		Kind.LANTERN:
			_lantern(box)
		Kind.RIDE_BICYCLE:
			_two_wheeler(box, false)
		Kind.RIDE_MOTORCYCLE:
			_two_wheeler(box, true)
		Kind.RIDE_QUAD:
			_quad_face(box)
		# Getting off says which thing you are getting off. It said the same
		# thing whatever you were on — a rider leaving a quad was shown a
		# horse — and the picture for leaving is the machine with somebody
		# stepping up off it.
		Kind.LEAVE_BICYCLE:
			_two_wheeler(box, false)
			_step_off(box)
		Kind.LEAVE_MOTORCYCLE:
			_two_wheeler(box, true)
			_step_off(box)
		Kind.LEAVE_QUAD:
			_quad_face(box)
			_step_off(box)
		Kind.VIEW_FIRST:
			_eye(box)
		Kind.VIEW_THIRD:
			_over_the_shoulder(box)
		Kind.MIC_ON:
			_microphone(box, true)
		Kind.MIC_OFF:
			_microphone(box, false)
		Kind.MAP:
			_globe(box)
		Kind.TOGETHER:
			_two_of_you(box)
		Kind.BAG:
			_satchel(box)
		Kind.DIVE:
			_across_the_water(box, true)
		Kind.SURFACE:
			_across_the_water(box, false)
		Kind.SETTINGS:
			_gear(box)

## The mark that turns a machine into "get off it": an arrow rising away from
## it, up and to the side, which is the way somebody actually leaves one.
func _step_off(box: Rect2) -> void:
	var unit := minf(box.size.x, box.size.y)
	var centre := box.get_center()
	var foot := centre + Vector2(unit * 0.3, -unit * 0.04)
	var head := foot + Vector2(unit * 0.12, -unit * 0.3)
	draw_line(foot, head, tint, maxf(2.0, unit * 0.08))
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(0.0, -unit * 0.09),
		head + Vector2(-unit * 0.09, unit * 0.04),
		head + Vector2(unit * 0.09, unit * 0.04),
	]), tint)

## An eye: looking out of your own head.
func _eye(box: Rect2) -> void:
	var unit := minf(box.size.x, box.size.y)
	var centre := box.get_center()
	var wide := unit * 0.36
	var tall := unit * 0.2
	var thick := maxf(2.0, unit * 0.07)
	# Two arcs meeting at the corners, which is an eye in four strokes.
	draw_arc(centre + Vector2(0.0, tall * 0.6), wide, PI * 1.15, PI * 1.85, 14, tint, thick)
	draw_arc(centre - Vector2(0.0, tall * 0.6), wide, PI * 0.15, PI * 0.85, 14, tint, thick)
	draw_circle(centre, unit * 0.1, tint)

## Going under, and coming back up: a waterline with a ripple in it and an
## arrow crossing it, pointing down to dive and up to surface.
##
## The waterline is what carries the meaning — an arrow on its own is the
## build palette scrolling — so it is drawn as the wave it is, and the arrow
## starts on the side of it the child is on now and ends on the side they are
## going to.
func _across_the_water(box: Rect2, down: bool) -> void:
	var unit := minf(box.size.x, box.size.y)
	var centre := box.get_center()
	var thick := maxf(2.0, unit * 0.075)

	# A short run of wave through the middle of the button.
	var wave := PackedVector2Array()
	var half := unit * 0.34
	for step in 17:
		var t := float(step) / 16.0
		var x := -half + half * 2.0 * t
		wave.append(centre + Vector2(x, sin(t * TAU) * unit * 0.055))
	draw_polyline(wave, tint, thick)

	# The arrow, crossing it. It reaches further on the side being travelled to
	# than the side being left, so the picture reads before the arrowhead does.
	var from := centre + Vector2(0.0, unit * (-0.2 if down else 0.24))
	var to := centre + Vector2(0.0, unit * (0.3 if down else -0.28))
	draw_line(from, to, tint, thick)
	var point := unit * (0.11 if down else -0.11)
	draw_colored_polygon(PackedVector2Array([
		to,
		to + Vector2(-unit * 0.1, -point),
		to + Vector2(unit * 0.1, -point),
	]), tint)

## The far view: the same eye, barred.
##
## It was a figure with a camera framed behind it, which is an accurate picture
## of a third-person camera and a poor one at thumbnail size on a phone — three
## shapes in the space the eye uses one. The eye and its barred twin read at a
## glance and, being the same drawing, read as two settings of one thing.
func _over_the_shoulder(box: Rect2) -> void:
	_eye(box)
	_barred(box)

## A quad seen from the front: four fat tyres at the corners, a body between
## them and bars across the top. Head-on rather than from the side, because
## from the side it is a motorcycle with extra wheels, and the whole job of
## this picture is to be the one thing it cannot be mistaken for.
func _quad_face(box: Rect2) -> void:
	var unit := minf(box.size.x, box.size.y)
	var centre := box.get_center()
	var across := unit * 0.3
	var down := unit * 0.22
	var tyre := unit * 0.15
	for side: float in [-1.0, 1.0]:
		# The near pair, drawn solid, and the far pair behind them as rings:
		# that is what gives it depth in twenty pixels.
		draw_rect(
			Rect2(
				centre + Vector2(side * across - tyre * 0.5, down - tyre),
				Vector2(tyre, tyre * 1.9)
			),
			tint
		)
		draw_arc(
			centre + Vector2(side * across * 0.72, down - tyre * 0.9),
			tyre * 0.55, 0.0, TAU, 12, tint, maxf(1.5, unit * 0.05)
		)
	# The body: a wedge between the wheels.
	draw_colored_polygon(PackedVector2Array([
		centre + Vector2(-across * 0.78, down - tyre * 0.2),
		centre + Vector2(-across * 0.5, -down * 0.5),
		centre + Vector2(across * 0.5, -down * 0.5),
		centre + Vector2(across * 0.78, down - tyre * 0.2),
	]), tint)
	# The bars across the top, with grips at the ends.
	var bar_y := -down * 0.86
	draw_line(
		centre + Vector2(-across * 0.82, bar_y),
		centre + Vector2(across * 0.82, bar_y),
		tint, maxf(2.0, unit * 0.07)
	)
	draw_line(
		centre + Vector2(0.0, bar_y),
		centre + Vector2(0.0, -down * 0.5),
		tint, maxf(2.0, unit * 0.06)
	)

## A two-wheeler seen from the side: thin wheels and a diamond frame for the
## bicycle, fat wheels and a body between them for the motorcycle.
##
## The button to get on something used to show a horseshoe whatever it was, so
## the picture for getting on a motorcycle was a hoof. A child reads the
## silhouette, and these two silhouettes are the difference between the two
## machines.
func _two_wheeler(box: Rect2, engine: bool) -> void:
	var unit := minf(box.size.x, box.size.y)
	var centre := box.get_center()
	var axle := unit * 0.28
	var wheel := unit * 0.2 if engine else unit * 0.22
	var thick := maxf(2.0, unit * (0.085 if engine else 0.055))
	for side: float in [-1.0, 1.0]:
		draw_arc(centre + Vector2(side * axle, unit * 0.2), wheel, 0.0, TAU, 20, tint, thick)
	if engine:
		# Tank and seat as one slab, bars rising at the front, a plume behind.
		var body := PackedVector2Array([
			centre + Vector2(-axle - unit * 0.04, unit * 0.04),
			centre + Vector2(-axle * 0.2, -unit * 0.12),
			centre + Vector2(axle * 0.5, -unit * 0.1),
			centre + Vector2(axle + unit * 0.02, unit * 0.04),
		])
		draw_colored_polygon(body, tint)
		draw_line(
			centre + Vector2(-axle * 0.15, -unit * 0.12),
			centre + Vector2(-axle * 0.55, -unit * 0.3), tint, thick * 0.7
		)
		for puff in 2:
			draw_circle(
				centre + Vector2(axle + unit * (0.12 + 0.09 * float(puff)), unit * (0.02 - 0.05 * float(puff))),
				unit * (0.045 + 0.02 * float(puff)),
				Color(tint.r, tint.g, tint.b, 0.45 - 0.14 * float(puff))
			)
		return
	# The bicycle: a diamond of thin tubes, bars and a saddle.
	var bracket := centre + Vector2(0.0, unit * 0.12)
	var seat := centre + Vector2(axle * 0.42, -unit * 0.16)
	var head := centre + Vector2(-axle * 0.55, -unit * 0.1)
	draw_line(bracket, head, tint, thick)
	draw_line(bracket, seat, tint, thick)
	draw_line(head, seat, tint, thick)
	draw_line(bracket, centre + Vector2(axle, unit * 0.2), tint, thick)
	draw_line(seat, centre + Vector2(axle, unit * 0.2), tint, thick)
	draw_line(head, centre + Vector2(-axle, unit * 0.2), tint, thick)
	draw_line(head, head + Vector2(-unit * 0.12, -unit * 0.1), tint, thick)
	draw_line(
		seat + Vector2(-unit * 0.06, -unit * 0.04),
		seat + Vector2(unit * 0.08, -unit * 0.04), tint, thick * 1.4
	)

## A lantern: a body with a handle over it and light coming out. The same shape
## as the one on the shop's shelf, so the thing bought and the thing switched
## read as one object.
func _lantern(box: Rect2) -> void:
	var unit := minf(box.size.x, box.size.y)
	var centre := box.get_center()
	var thick := maxf(2.0, unit * 0.06)
	var body := Rect2(
		centre + Vector2(-unit * 0.17, -unit * 0.14), Vector2(unit * 0.34, unit * 0.36)
	)
	draw_rect(body, tint, false, thick)
	# The flame inside.
	draw_circle(centre + Vector2(0.0, unit * 0.05), unit * 0.08, tint)
	# The handle.
	draw_arc(centre + Vector2(0.0, -unit * 0.14), unit * 0.13, PI, TAU, 12, tint, thick)
	# A cap and a foot, so it is a lantern rather than a window.
	draw_line(
		centre + Vector2(-unit * 0.21, -unit * 0.14),
		centre + Vector2(unit * 0.21, -unit * 0.14), tint, thick
	)
	draw_line(
		centre + Vector2(-unit * 0.21, unit * 0.22),
		centre + Vector2(unit * 0.21, unit * 0.22), tint, thick
	)

## A bar of chocolate, half unwrapped: the squares showing at one end and the
## foil turned back at the other.
func _snack(box: Rect2) -> void:
	var unit := minf(box.size.x, box.size.y)
	var centre := box.get_center()
	var wide := unit * 0.34
	var tall := unit * 0.2
	draw_rect(Rect2(centre - Vector2(wide, tall), Vector2(wide * 1.5, tall * 2.0)), tint)
	# The squares.
	for line in 2:
		var y := centre.y - tall + tall * (float(line) + 1.0) * 0.67
		draw_line(Vector2(centre.x - wide, y), Vector2(centre.x + wide * 0.5, y), HOLE, maxf(1.5, unit * 0.03))
	for column in 2:
		var x := centre.x - wide + wide * 1.5 * (float(column) + 1.0) / 3.0
		draw_line(Vector2(x, centre.y - tall), Vector2(x, centre.y + tall), HOLE, maxf(1.5, unit * 0.03))
	# The foil, turned back.
	var foil := PackedVector2Array([
		centre + Vector2(wide * 0.5, -tall),
		centre + Vector2(wide * 1.1, -tall * 1.35),
		centre + Vector2(wide * 1.1, tall * 1.35),
		centre + Vector2(wide * 0.5, tall),
	])
	draw_colored_polygon(foil, Color(tint.r, tint.g, tint.b, 0.5))

## A shopping basket with a coin over it: the button that opens the shop, shown
## while a child is standing at its counter. A basket alone could be a bin; the
## coin says what the basket is for.
func _shop(box: Rect2) -> void:
	var unit := minf(box.size.x, box.size.y)
	var centre := box.get_center()
	var thick := maxf(2.0, unit * 0.06)
	# The basket: a tapered body, its rim, and the handle over it.
	var rim_y := centre.y - unit * 0.02
	var foot_y := centre.y + unit * 0.3
	var half := unit * 0.3
	draw_line(Vector2(centre.x - half, rim_y), Vector2(centre.x + half, rim_y), tint, thick)
	draw_line(Vector2(centre.x - half, rim_y), Vector2(centre.x - half * 0.66, foot_y), tint, thick)
	draw_line(Vector2(centre.x + half, rim_y), Vector2(centre.x + half * 0.66, foot_y), tint, thick)
	draw_line(Vector2(centre.x - half * 0.66, foot_y), Vector2(centre.x + half * 0.66, foot_y), tint, thick)
	draw_arc(Vector2(centre.x, rim_y), unit * 0.17, PI, TAU, 14, tint, thick)
	# The coin, dropping in.
	var coin_at := Vector2(centre.x + unit * 0.22, centre.y - unit * 0.3)
	draw_circle(coin_at, unit * 0.13, tint)
	draw_arc(coin_at, unit * 0.06, 0.0, TAU, 12, HOLE, maxf(1.5, unit * 0.03))

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
	var thick := maxf(2.5, unit * 0.095)
	var ground := centre.y + unit * 0.35

	# The ground, and a shadow on it with daylight in between. The shadow is
	# what makes this icon work: an arrow over a line — which is what it was —
	# is the picture every other application on the phone uses for "upload",
	# and a child hunting for the button that makes them jump was shown one of
	# those. A body clear of its own shadow can only be off the ground.
	draw_line(
		Vector2(centre.x - unit * 0.34, ground),
		Vector2(centre.x + unit * 0.34, ground),
		tint, thick * 0.8
	)
	var shadow := PackedVector2Array()
	for i in 20:
		var angle := TAU * float(i) / 20.0
		shadow.append(
			Vector2(centre.x + unit * 0.02, ground - thick * 1.5)
			+ Vector2(cos(angle) * unit * 0.15, sin(angle) * unit * 0.04)
		)
	draw_colored_polygon(shadow, INK_SOFT)

	# Seen from the side, mid-leap: leading knee up, trailing leg stretched
	# behind, arms swinging through. A figure drawn square-on with both arms up
	# and both knees tucked reads as a star-jump or a dance; in profile there is
	# only one thing it can be doing.
	var hips := centre + Vector2(-unit * 0.03, -unit * 0.05)
	var shoulders := hips + Vector2(unit * 0.04, -unit * 0.17)

	draw_line(hips, shoulders, tint, thick)
	draw_circle(shoulders + Vector2(unit * 0.03, -unit * 0.11), unit * 0.1, tint)

	# The leading arm, thrown forward and up; the other swings back.
	draw_polyline(PackedVector2Array([
		shoulders,
		shoulders + Vector2(unit * 0.13, -unit * 0.07),
		shoulders + Vector2(unit * 0.21, -unit * 0.19),
	]), tint, thick * 0.8)
	draw_polyline(PackedVector2Array([
		shoulders,
		shoulders + Vector2(-unit * 0.13, unit * 0.01),
		shoulders + Vector2(-unit * 0.21, -unit * 0.06),
	]), tint, thick * 0.8)

	# The leading leg, knee high and shin forward.
	draw_polyline(PackedVector2Array([
		hips,
		hips + Vector2(unit * 0.15, unit * 0.02),
		hips + Vector2(unit * 0.21, unit * 0.16),
	]), tint, thick * 0.8)
	# And the trailing leg, straight out behind.
	draw_polyline(PackedVector2Array([
		hips,
		hips + Vector2(-unit * 0.13, unit * 0.13),
		hips + Vector2(-unit * 0.24, unit * 0.19),
	]), tint, thick * 0.8)

## A ball, already moving. The ball alone reads as "a ball"; the three lines
## behind it are what make it "kick".
func _kick(box: Rect2) -> void:
	var unit := minf(box.size.x, box.size.y)
	var radius := unit * 0.24
	var centre := box.get_center() + Vector2(unit * 0.10, 0.0)

	draw_circle(centre, radius, tint)
	# A couple of dark facets, so it is a football rather than a dot.
	draw_circle(centre, radius * 0.30, HOLE)
	for turn in 3:
		var angle := TAU * float(turn) / 3.0 - PI * 0.5
		draw_circle(
			centre + Vector2(cos(angle), sin(angle)) * radius * 0.66,
			radius * 0.17, HOLE
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

## A cup with water in it. The waterline is what makes it a drink rather than
## a bucket.
func _drink(box: Rect2) -> void:
	var unit := minf(box.size.x, box.size.y)
	var centre := box.get_center()
	var top := centre.y - unit * 0.30
	var bottom := centre.y + unit * 0.28
	var half_top := unit * 0.24
	var half_bottom := unit * 0.17

	var cup := PackedVector2Array([
		Vector2(centre.x - half_top, top),
		Vector2(centre.x + half_top, top),
		Vector2(centre.x + half_bottom, bottom),
		Vector2(centre.x - half_bottom, bottom),
		Vector2(centre.x - half_top, top),
	])
	draw_polyline(cup, tint, unit * 0.07)

	# The water, a little below the rim.
	var level := lerpf(top, bottom, 0.38)
	var half_level := lerpf(half_top, half_bottom, 0.38) - unit * 0.035
	draw_colored_polygon(PackedVector2Array([
		Vector2(centre.x - half_level, level),
		Vector2(centre.x + half_level, level),
		Vector2(centre.x + half_bottom - unit * 0.035, bottom - unit * 0.035),
		Vector2(centre.x - half_bottom + unit * 0.035, bottom - unit * 0.035),
	]), INK_SOFT)

## A referee's whistle: a round body with a barrel out the side.
func _whistle(box: Rect2) -> void:
	var unit := minf(box.size.x, box.size.y)
	var centre := box.get_center() + Vector2(-unit * 0.08, unit * 0.04)
	var radius := unit * 0.20

	draw_circle(centre, radius, tint)
	# The barrel, reaching up and to the right.
	draw_rect(Rect2(
		Vector2(centre.x, centre.y - radius * 0.62),
		Vector2(radius * 2.1, radius * 0.72)
	), tint)
	# The hole a whistle has, which is what stops it reading as a lollipop.
	draw_circle(centre + Vector2(-radius * 0.05, radius * 0.12), radius * 0.30, HOLE)

## An axe, head up. Different enough from the hammer beside it: a wedge on a
## long handle rather than a block on a short one.
func _chop(box: Rect2) -> void:
	var unit := minf(box.size.x, box.size.y)
	var centre := box.get_center()
	var lean := Vector2(cos(-1.05), sin(-1.05))
	var across := Vector2(-lean.y, lean.x)
	var head_at := centre + lean * unit * 0.20

	draw_line(head_at, head_at - lean * unit * 0.60, tint, unit * 0.09)

	# The blade: a wedge on one side of the shaft only, curved edge outward.
	draw_colored_polygon(PackedVector2Array([
		head_at + lean * unit * 0.08,
		head_at + lean * unit * 0.14 + across * unit * 0.28,
		head_at - lean * unit * 0.02 + across * unit * 0.32,
		head_at - lean * unit * 0.16 + across * unit * 0.22,
		head_at - lean * unit * 0.10,
	]), tint)

## A horseshoe, which is how games have said "horse" for a long time. When
## already riding, an arrow points down out of it: get off.
func _ride(box: Rect2, dismount: bool) -> void:
	var unit := minf(box.size.x, box.size.y)
	var centre := box.get_center() + Vector2(0.0, -unit * 0.04)
	var radius := unit * 0.22
	# Open at the bottom, the way a shoe hangs on a nail.
	draw_arc(centre, radius, PI * 0.72, PI * 2.28, 28, tint, unit * 0.09)
	# Nail holes, two a side.
	for side in PackedFloat32Array([-1.0, 1.0]):
		for hole in 2:
			var angle := PI * (1.22 + 0.34 * float(hole))
			var at := centre + Vector2(cos(angle) * side, sin(angle)) * radius
			draw_circle(at, unit * 0.028, HOLE)

	if dismount:
		var top := centre + Vector2(0.0, radius * 0.05)
		var tip := centre + Vector2(0.0, radius * 1.55)
		draw_line(top, tip - Vector2(0.0, unit * 0.06), tint, unit * 0.07)
		draw_colored_polygon(PackedVector2Array([
			tip,
			tip + Vector2(-unit * 0.10, -unit * 0.13),
			tip + Vector2(unit * 0.10, -unit * 0.13),
		]), tint)

## A bow with an arrow on the string, drawn.
func _shoot(box: Rect2) -> void:
	var unit := minf(box.size.x, box.size.y)
	var centre := box.get_center()
	var radius := unit * 0.30
	# The bow's belly faces right; the string runs down the left.
	var bow_centre := centre + Vector2(-radius * 0.55, 0.0)
	draw_arc(bow_centre, radius, -PI * 0.42, PI * 0.42, 24, tint, unit * 0.075)
	var top := bow_centre + Vector2(cos(-PI * 0.42), sin(-PI * 0.42)) * radius
	var bottom := bow_centre + Vector2(cos(PI * 0.42), sin(PI * 0.42)) * radius
	var nock := centre + Vector2(-radius * 0.95, 0.0)
	draw_line(top, nock, tint, unit * 0.04)
	draw_line(nock, bottom, tint, unit * 0.04)

	# The arrow, from the string out past the bow.
	var tip := centre + Vector2(radius * 1.05, 0.0)
	draw_line(nock, tip - Vector2(unit * 0.08, 0.0), tint, unit * 0.06)
	draw_colored_polygon(PackedVector2Array([
		tip,
		tip + Vector2(-unit * 0.14, -unit * 0.09),
		tip + Vector2(-unit * 0.14, unit * 0.09),
	]), tint)

## A throw: a ball at the bottom left, an arc up and over, and a hoop with
## its net at the top right, backboard behind it. Shown in place of the kick
## when a basketball is close enough to the ring to be thrown at it.
func _throw(box: Rect2) -> void:
	var unit := minf(box.size.x, box.size.y)
	var centre := box.get_center()
	var ball_at := centre + Vector2(-unit * 0.28, unit * 0.20)
	draw_circle(ball_at, unit * 0.11, tint)

	# The arc, dashed, so it reads as a path rather than a rope.
	var hoop_at := centre + Vector2(unit * 0.22, -unit * 0.14)
	var control := Vector2((ball_at.x + hoop_at.x) * 0.5, centre.y - unit * 0.46)
	var steps := 10
	for i in steps:
		if i % 2 == 1:
			continue
		var t0 := float(i) / float(steps)
		var t1 := float(i + 1) / float(steps)
		var from := ball_at.lerp(control, t0).lerp(control.lerp(hoop_at, t0), t0)
		var to := ball_at.lerp(control, t1).lerp(control.lerp(hoop_at, t1), t1)
		draw_line(from, to, tint, maxf(2.0, unit * 0.05))

	# The ring, seen edge-on, with the net hanging from it.
	draw_line(hoop_at + Vector2(-unit * 0.17, 0.0), hoop_at + Vector2(unit * 0.17, 0.0), tint, unit * 0.07)
	var net_depth := unit * 0.22
	draw_line(hoop_at + Vector2(-unit * 0.14, 0.0), hoop_at + Vector2(-unit * 0.08, net_depth), tint, unit * 0.04)
	draw_line(hoop_at + Vector2(unit * 0.14, 0.0), hoop_at + Vector2(unit * 0.08, net_depth), tint, unit * 0.04)
	draw_line(hoop_at + Vector2(-unit * 0.08, net_depth), hoop_at + Vector2(unit * 0.08, net_depth), tint, unit * 0.04)
	# The backboard, standing behind the ring.
	draw_line(hoop_at + Vector2(unit * 0.21, -unit * 0.22), hoop_at + Vector2(unit * 0.21, unit * 0.06), tint, unit * 0.06)

## A boat on water: a hull seen from the side with an oar out, on a wave.
## Shown in place of the horseshoe when the thing to get into is a boat.
func _row(box: Rect2) -> void:
	var unit := minf(box.size.x, box.size.y)
	var centre := box.get_center()
	# The hull: a shallow bowl, flat across the top.
	var hull := PackedVector2Array([
		centre + Vector2(-unit * 0.36, -unit * 0.02),
		centre + Vector2(unit * 0.36, -unit * 0.02),
		centre + Vector2(unit * 0.24, unit * 0.18),
		centre + Vector2(-unit * 0.24, unit * 0.18),
	])
	draw_colored_polygon(hull, tint)
	# The oar, from inside the hull down into the water on the right.
	draw_line(centre + Vector2(unit * 0.02, -unit * 0.2), centre + Vector2(unit * 0.34, unit * 0.3), tint, maxf(2.0, unit * 0.06))
	# Water: a wave under the hull.
	var w := maxf(2.0, unit * 0.06)
	for i in 3:
		var x := centre.x + (float(i) - 1.0) * unit * 0.26
		draw_arc(Vector2(x, centre.y + unit * 0.34), unit * 0.13, PI, TAU, 8, tint, w)

## A ticket: a coin going into a turnstile — the coin on the left, the
## turnstile's post and three arms on the right.
func _ticket(box: Rect2) -> void:
	var unit := minf(box.size.x, box.size.y)
	var centre := box.get_center()
	var coin_at := centre + Vector2(-unit * 0.22, -unit * 0.02)
	draw_circle(coin_at, unit * 0.17, tint)
	draw_arc(coin_at, unit * 0.1, 0.0, TAU, 16, HOLE, maxf(1.5, unit * 0.035))
	# The post, and three arms coming off its top.
	var post_x := centre.x + unit * 0.2
	draw_line(Vector2(post_x, centre.y - unit * 0.1), Vector2(post_x, centre.y + unit * 0.36), tint, maxf(2.0, unit * 0.07))
	var hub := Vector2(post_x, centre.y - unit * 0.1)
	for k in 3:
		var angle := -PI * 0.5 + (float(k) - 1.0) * PI * 0.62
		draw_line(hub, hub + Vector2(cos(angle), sin(angle)) * unit * 0.26, tint, maxf(2.0, unit * 0.06))
	# An arrow from the coin to the slot.
	draw_line(coin_at + Vector2(unit * 0.2, 0.0), Vector2(post_x - unit * 0.08, hub.y + unit * 0.02), tint, maxf(1.5, unit * 0.04))

## A swing: two ropes from a bar and a seat between them, already leaning.
func _swing(box: Rect2) -> void:
	var unit := minf(box.size.x, box.size.y)
	var centre := box.get_center()
	var bar_y := centre.y - unit * 0.32
	draw_line(
		Vector2(centre.x - unit * 0.34, bar_y), Vector2(centre.x + unit * 0.34, bar_y),
		tint, unit * 0.07
	)
	# Ropes, swung a little to one side so it is moving.
	var lean := unit * 0.10
	var seat_y := centre.y + unit * 0.22
	var left := Vector2(centre.x - unit * 0.16 + lean, seat_y)
	var right := Vector2(centre.x + unit * 0.16 + lean, seat_y)
	draw_line(Vector2(centre.x - unit * 0.16, bar_y), left, tint, unit * 0.04)
	draw_line(Vector2(centre.x + unit * 0.16, bar_y), right, tint, unit * 0.04)
	draw_line(left - Vector2(unit * 0.05, 0.0), right + Vector2(unit * 0.05, 0.0), tint, unit * 0.08)

## A bowl with steam over it. Spoon-and-fork was considered and at button size
## would read as two sticks; a bowl reads as food at any size.
func _eat(box: Rect2) -> void:
	var unit := minf(box.size.x, box.size.y)
	var centre := box.get_center() + Vector2(0.0, unit * 0.10)
	var radius := unit * 0.27
	# The bowl: the lower half of a circle, with a foot.
	draw_arc(centre, radius, 0.0, PI, 24, tint, unit * 0.075)
	draw_line(
		centre + Vector2(-radius, 0.0), centre + Vector2(radius, 0.0), tint, unit * 0.075
	)
	draw_line(
		centre + Vector2(-radius * 0.35, radius * 0.98),
		centre + Vector2(radius * 0.35, radius * 0.98), tint, unit * 0.07
	)
	# Three wisps of steam.
	for wisp in 3:
		var x := centre.x + (float(wisp) - 1.0) * radius * 0.5
		var base := Vector2(x, centre.y - radius * 0.25)
		draw_polyline(PackedVector2Array([
			base,
			base + Vector2(unit * 0.03, -unit * 0.07),
			base + Vector2(-unit * 0.03, -unit * 0.14),
			base + Vector2(unit * 0.02, -unit * 0.21),
		]), INK_SOFT, unit * 0.035)

## Three sticks laid across each other: the start of a dam, which is what the
## stick a child is holding is for at this button.
func _give_stick(box: Rect2) -> void:
	var unit := minf(box.size.x, box.size.y)
	var centre := box.get_center()
	var reach := unit * 0.30
	for i in 3:
		var angle := -0.25 + float(i) * 0.28
		var lean := Vector2(cos(angle), sin(angle))
		var at := centre + Vector2(0.0, (float(i) - 1.0) * unit * 0.11)
		draw_line(at - lean * reach, at + lean * reach, tint, unit * 0.085)

## A flame: a pointed body with a darker tongue inside it.
func _feed_fire(box: Rect2) -> void:
	var unit := minf(box.size.x, box.size.y)
	var centre := box.get_center() + Vector2(0.0, unit * 0.04)
	var h := unit * 0.34
	var w := unit * 0.24
	draw_colored_polygon(PackedVector2Array([
		centre + Vector2(0.0, -h),
		centre + Vector2(w * 0.55, -h * 0.35),
		centre + Vector2(w, h * 0.30),
		centre + Vector2(w * 0.55, h),
		centre + Vector2(-w * 0.55, h),
		centre + Vector2(-w, h * 0.30),
		centre + Vector2(-w * 0.45, -h * 0.30),
	]), tint)
	draw_colored_polygon(PackedVector2Array([
		centre + Vector2(0.0, -h * 0.25),
		centre + Vector2(w * 0.38, h * 0.42),
		centre + Vector2(0.0, h),
		centre + Vector2(-w * 0.38, h * 0.42),
	]), HOLE)

## A crescent moon with a star: sleep, the way every clock and phone draws it.
func _sleep(box: Rect2) -> void:
	var unit := minf(box.size.x, box.size.y)
	var centre := box.get_center() + Vector2(-unit * 0.04, 0.0)
	var radius := unit * 0.27
	# The crescent: the outer arc, then back along an inner arc offset to one
	# side, as one polygon.
	var points := PackedVector2Array()
	var steps := 22
	for i in steps + 1:
		var angle := lerpf(-PI * 0.55, PI * 0.55, float(i) / float(steps)) + PI
		points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	var inner_centre := centre + Vector2(radius * 0.42, 0.0)
	var inner_radius := radius * 0.78
	for i in steps + 1:
		var angle := lerpf(PI * 0.62, -PI * 0.62, float(i) / float(steps)) + PI
		points.append(inner_centre + Vector2(cos(angle), sin(angle)) * inner_radius)
	draw_colored_polygon(points, tint)
	# The star, four-pointed and small.
	var star_at := centre + Vector2(radius * 0.95, -radius * 0.70)
	var s := unit * 0.07
	draw_colored_polygon(PackedVector2Array([
		star_at + Vector2(0.0, -s), star_at + Vector2(s * 0.3, -s * 0.3),
		star_at + Vector2(s, 0.0), star_at + Vector2(s * 0.3, s * 0.3),
		star_at + Vector2(0.0, s), star_at + Vector2(-s * 0.3, s * 0.3),
		star_at + Vector2(-s, 0.0), star_at + Vector2(-s * 0.3, -s * 0.3),
	]), tint)

## A speech bubble with three dots: someone is saying something. Lit up while
## the microphone is actually running — that part is done by the HUD, on the
## button as a whole.
## The bag: a satchel with a flap and two straps over the shoulders.
##
## The word "рюкзак" with a count beside it was doing this job, which is a
## reading task in the corner of a game played by a six-year-old who cannot
## read yet. The shape is the label now and the count sits on it.
func _satchel(box: Rect2) -> void:
	var unit := minf(box.size.x, box.size.y)
	var centre := box.get_center()
	var half_width := unit * 0.23
	var top := centre.y - unit * 0.14
	var bottom := centre.y + unit * 0.3
	var thick := maxf(2.0, unit * 0.07)

	# The grab handle, one loop at the top. This was a strap over each shoulder
	# and the pair of them read as a ribbon: the bag came out a wrapped present.
	draw_arc(
		Vector2(centre.x, top + thick * 0.5),
		unit * 0.11, PI, TAU, 14, tint, thick
	)

	# The body, with its corners taken off so it is a bag and not a crate.
	var body := PackedVector2Array()
	var round_by := unit * 0.07
	for corner: Vector4 in [
		Vector4(centre.x + half_width - round_by, bottom - round_by, 0.0, 1.0),
		Vector4(centre.x - half_width + round_by, bottom - round_by, 1.0, 2.0),
		Vector4(centre.x - half_width + round_by, top + round_by, 2.0, 3.0),
		Vector4(centre.x + half_width - round_by, top + round_by, 3.0, 4.0),
	]:
		for i in 5:
			var angle := (corner.z + float(i) / 4.0) * PI * 0.5
			body.append(Vector2(corner.x, corner.y) + Vector2(cos(angle), sin(angle)) * round_by)
	draw_colored_polygon(body, tint)

	# The flap across the top and the buckle under it, cut out of the bag
	# rather than laid over it, so the whole thing stays one silhouette.
	draw_rect(
		Rect2(
			Vector2(centre.x - half_width, top + unit * 0.15),
			Vector2(half_width * 2.0, thick * 0.9)
		),
		HOLE
	)
	draw_rect(
		Rect2(
			Vector2(centre.x - unit * 0.045, top + unit * 0.19),
			Vector2(unit * 0.09, unit * 0.07)
		),
		HOLE
	)

## Two children, one behind the other: playing together.
##
## Up beside the map and the eye, because inviting a brother into the valley is
## something a child decides to do mid-game, and it used to be two taps down
## inside the menu — the same objection as the microphone had.
func _two_of_you(box: Rect2) -> void:
	var unit := minf(box.size.x, box.size.y)
	var centre := box.get_center()
	# The one behind is drawn first, smaller and offset, then the one in front
	# is drawn over a dark outline of itself so the two do not merge into one
	# lumpy shape at the size a thumb actually sees.
	_person(centre + Vector2(-unit * 0.15, -unit * 0.04), unit * 0.82, tint)
	_person(centre + Vector2(unit * 0.14, unit * 0.03), unit * 1.06, HOLE)
	_person(centre + Vector2(unit * 0.14, unit * 0.03), unit * 0.94, tint)

## One head and a pair of shoulders, sized to `unit`.
func _person(at: Vector2, unit: float, colour: Color) -> void:
	draw_circle(at + Vector2(0.0, -unit * 0.16), unit * 0.13, colour)
	# The shoulders: a half-disc, which reads as a body without needing arms.
	var shoulders := PackedVector2Array()
	var width := unit * 0.22
	for i in 17:
		var angle := PI + PI * float(i) / 16.0
		shoulders.append(at + Vector2(cos(angle) * width, unit * 0.22 + sin(angle) * unit * 0.2))
	shoulders.append(at + Vector2(width, unit * 0.24))
	shoulders.append(at + Vector2(-width, unit * 0.24))
	draw_colored_polygon(shoulders, colour)

## A gear: settings.
##
## It was "≡", which says "more things behind this" — and behind it is a
## child's name, the colour they wear and the language the game speaks, which
## is not a list of more things but how the game is set up. It was also the
## last letter left in a row where everything else is drawn.
func _gear(box: Rect2) -> void:
	var unit := minf(box.size.x, box.size.y)
	var centre := box.get_center()
	var teeth := 8
	var inner := unit * 0.23
	var outer := unit * 0.33

	# The rim, as one polygon that steps in and out: a ring with separate teeth
	# laid on it leaves seams wherever a tooth meets the ring.
	var rim := PackedVector2Array()
	var steps := teeth * 4
	for i in steps:
		var angle := TAU * float(i) / float(steps)
		# Two of every four samples sit on the tooth, two in the gap, with the
		# change happening between them — which is what makes a square tooth
		# rather than a wavy one.
		var reach := outer if (i % 4) < 2 else inner
		rim.append(centre + Vector2(cos(angle), sin(angle)) * reach)
	draw_colored_polygon(rim, tint)

	# And the hole through the middle, cut in the button's own dark rather than
	# drawn in the ink, so the gear reads as a ring.
	draw_circle(centre, unit * 0.115, HOLE)

## The valley, as a globe: a circle with a meridian down it and two parallels
## across. It was the character "▣" set in the interface font — the one button
## in this family that was a letter rather than a drawing, which meant it was
## also the one whose weight and size came from a font rather than from the
## same hand as its neighbours.
func _globe(box: Rect2) -> void:
	var unit := minf(box.size.x, box.size.y)
	var centre := box.get_center()
	var radius := unit * 0.34
	var thick := maxf(2.0, unit * 0.07)
	draw_arc(centre, radius, 0.0, TAU, 32, tint, thick)
	# The meridian: an ellipse narrow enough to read as a sphere turned towards
	# you rather than as a second circle drawn inside the first.
	var meridian := PackedVector2Array()
	for i in 33:
		var angle := TAU * float(i) / 32.0
		meridian.append(centre + Vector2(cos(angle) * radius * 0.42, sin(angle) * radius))
	draw_polyline(meridian, tint, thick * 0.8)
	# Two parallels, above and below the equator, bowed the way lines of
	# latitude bow on a ball.
	for side: float in [-1.0, 1.0]:
		var parallel := PackedVector2Array()
		for i in 13:
			var t := float(i) / 12.0
			var x := lerpf(-radius * 0.93, radius * 0.93, t)
			var bow := sin(t * PI) * radius * 0.12 * side
			parallel.append(centre + Vector2(x, radius * 0.42 * side + bow))
		draw_polyline(parallel, tint, thick * 0.8)

## The stroke that turns a picture into its own negative, drawn with a dark
## edge under it so it reads against whatever it crosses instead of merging
## into it. Shared by the microphone and the eye, which sit next to each other
## and must cancel themselves out the same way.
func _barred(box: Rect2) -> void:
	var unit := minf(box.size.x, box.size.y)
	var centre := box.get_center()
	var from := centre + Vector2(-unit * 0.28, unit * 0.28)
	var to := centre + Vector2(unit * 0.28, -unit * 0.28)
	draw_line(from, to, HOLE, unit * 0.12)
	draw_line(from, to, tint, unit * 0.06)

## The microphone, with a stroke through it when it is switched off.
##
## A microphone rather than a loudspeaker, though a speaker is the more familiar
## picture: this switch has only ever controlled what this phone *sends*, and
## drawing it as a speaker would say it controls what this phone *hears*. That
## exact misreading is why the wording beside it was changed from "talking" to
## "my mic" — a child turned it off expecting quiet and instead went silent to
## everybody else.
func _microphone(box: Rect2, on: bool) -> void:
	var unit := minf(box.size.x, box.size.y)
	var centre := box.get_center()
	var capsule := centre + Vector2(0.0, -unit * 0.08)
	var half_width := unit * 0.12
	var half_height := unit * 0.2

	# The barrel: a rounded upright, drawn as a ring of points so its top and
	# bottom are domed rather than cut off square.
	var points := PackedVector2Array()
	for i in 28:
		var angle := TAU * float(i) / 28.0
		var x := cos(angle) * half_width
		var y := sin(angle) * half_width
		# Stretched in the middle, so the circle becomes a capsule.
		y += half_height - half_width if sin(angle) > 0.0 else -(half_height - half_width)
		points.append(capsule + Vector2(x, y))
	draw_colored_polygon(points, tint)

	# The cradle it hangs in, and the stem down to a foot.
	var cradle := capsule + Vector2(0.0, half_height * 0.25)
	draw_arc(cradle, unit * 0.2, 0.0, PI, 24, tint, unit * 0.045)
	draw_line(
		cradle + Vector2(0.0, unit * 0.2),
		cradle + Vector2(0.0, unit * 0.31),
		tint, unit * 0.045
	)
	draw_line(
		cradle + Vector2(-unit * 0.11, unit * 0.31),
		cradle + Vector2(unit * 0.11, unit * 0.31),
		tint, unit * 0.045
	)

	if not on:
		_barred(box)

func _talk(box: Rect2) -> void:
	var unit := minf(box.size.x, box.size.y)
	var centre := box.get_center() + Vector2(0.0, -unit * 0.05)
	var w := unit * 0.32
	var h := unit * 0.22
	var points := PackedVector2Array()
	for i in 32:
		var angle := TAU * float(i) / 32.0
		points.append(centre + Vector2(cos(angle) * w, sin(angle) * h))
	draw_colored_polygon(points, tint)
	# The tail, down and to the left.
	draw_colored_polygon(PackedVector2Array([
		centre + Vector2(-w * 0.35, h * 0.75),
		centre + Vector2(-w * 0.55, h * 1.75),
		centre + Vector2(w * 0.05, h * 0.9),
	]), tint)
	for dot in 3:
		draw_circle(centre + Vector2((float(dot) - 1.0) * w * 0.42, 0.0), unit * 0.035, HOLE)
