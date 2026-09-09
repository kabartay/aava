class_name Places
extends Node3D

## The playground, the swimming pool and the café.
##
## These exist because the valley was large and evenly interesting, which means
## nowhere in particular was worth going. Everything a child could do, they
## could do wherever they happened to be standing. A destination is a place that
## offers something the rest of the valley does not.
##
## One file for all three because they are the same problem: a fixed structure
## standing on levelled ground, with a small rule about what happens when a
## child is inside it. What differs is only that rule.
##
## The playground is deliberately the simplest thing in the game. It is the
## two-year-old's entry point: he cannot work the stick reliably, but he can
## press a button and watch something happen.

signal basket(total: int)
signal used(place: StringName)

const PLAYGROUND := &"playground"
const POOL := &"pool"
const CAFE := &"cafe"

const ALL: Array[StringName] = [PLAYGROUND, POOL, CAFE]

## How close a child must be for a place to offer itself. The café is bigger
## than the others' reach: a child at a terrace table is at the café.
const REACH := 5.5
const CAFE_REACH := 7.5
## How long a served meal sits on the counter, steaming.
const MEAL_SHOWN := 8.0
## The café's shape, relative to its centre. It faces -Z: the door is in the
## front wall, the bar along the back wall, the terrace out in front.
const CAFE_WIDTH := 10.4
const CAFE_DEPTH := 7.6
const CAFE_HEIGHT := 3.5
const CAFE_MID_Z := 1.6
const CAFE_DOOR_HALF := 0.9
## Where the tables stand inside, and out on the terrace under umbrellas, and
## the two lamps that light the terrace at dusk like the playground's.
const CAFE_TABLES: Array[Vector3] = [
	Vector3(-3.2, 0.0, -0.4), Vector3(-3.2, 0.0, 2.6), Vector3(2.9, 0.0, -0.4),
]
const CAFE_TERRACE: Array[Vector3] = [Vector3(-3.6, 0.0, -4.8), Vector3(3.6, 0.0, -4.8)]
const CAFE_LAMPS: Array[Vector3] = [Vector3(-6.4, 0.0, -3.4), Vector3(6.4, 0.0, -3.4)]
## How far from a seat a child may be and still be sat down at it.
const CAFE_SEAT_REACH := 6.0

## What a plate of food at the café costs, and what it restores. Priced so that
## a hungry child can afford it from one round of looking after animals.
const MEAL_PRICE := 3
const MEAL_RESTORE := 0.55

## The pool's shape lives in PlaceSpec, because the height field digs the hole
## and cannot depend on this file. Mirrored here so callers have one name.
const POOL_DEPTH := PlaceSpec.POOL_DEPTH
const POOL_HALF := PlaceSpec.POOL_HALF
const POOL_HALF_X := PlaceSpec.POOL_HALF_X
const POOL_HALF_Z := PlaceSpec.POOL_HALF_Z
## The fence round the pool, how far out from the water, and the way in: a
## turnstile on the side facing the pitch, a ticket booth beside it, and what
## a ticket costs. Coins come from looking after the animals, so a swim is
## something a child earns.
const POOL_FENCE_X := POOL_HALF_X + 3.0
const POOL_FENCE_Z := POOL_HALF_Z + 3.0
const POOL_GATE_HALF := 0.8
const POOL_TICKET := 5
## How long the turnstile stays open once paid, and how near a child must be
## for it to offer a ticket.
const TURNSTILE_OPEN := 7.0
const TURNSTILE_REACH := 2.6
## The loungers: laid along the poolside rather than across it, in the three
## metres between the water's rim and the fence. Across it they were two
## metres long in a three-metre gap and stuck through the railings.
const POOL_LOUNGER_SIZE := Vector3(1.9, 0.55, 0.72)
const POOL_LOUNGERS: Array[Vector3] = [
	Vector3(-5.0, 0.0, -(POOL_HALF_Z + 1.5)), Vector3(5.0, 0.0, -(POOL_HALF_Z + 1.5)),
]
## How much clear ground every piece of poolside furniture leaves between
## itself and the fence.
const POOLSIDE_CLEARANCE := 0.6
const POOL_LAMPS: Array[Vector3] = [
	Vector3(-POOL_FENCE_X - 0.8, 0.0, -POOL_FENCE_Z - 0.8), Vector3(POOL_FENCE_X + 0.8, 0.0, POOL_FENCE_Z + 0.8),
]

## The swing, as a swing rather than as a wind-up toy.
##
## A push used to set a timer running: the arc it gave was the same however
## many times you pushed, and three seconds later the whole ride was over.
## From the phone that read as one shove and then nothing — which is what it
## was. A swing works the other way round: each push adds to what is already
## there, and what is there keeps going.
##
## So the seat is a pendulum now. It swings at its own pace — the pace a rope
## this long swings at, sqrt(g / length) — a push adds SWING_PUSH to the arc up
## to SWING_ARC, and the arc falls away over SWING_SETTLE rather than over a
## few seconds. Three pushes take a child from nothing to as high as the swing
## goes, and a fourth cannot send them over the bar.
const SWING_ARC := 0.95
const SWING_PUSH := 0.32
const SWING_SETTLE := 22.0
## Below this arc the seat is only stirring, and the child is put down.
const SWING_STOPS_AT := 0.06
## The gravity a swing falls under: the project's own, which is heavier than
## the world's. A check holds these two together.
const SWING_GRAVITY := 24.0

## Two frames side by side, two seats on each, so two children — or a child and
## a visitor from another phone — can swing together rather than take turns.
## A frame is SWING_WIDTH across between its posts and SWING_BAR high; the two
## frames stand a frame and a half apart so two pairs of children swinging are
## two swings, not one crowd. Seats hang so a child's feet just clear the
## ground.
const SWING_WIDTH := 4.3
const SWING_BAR := 3.72
const SWING_POST := 3.9
const SWING_ROPE := 2.75
const SWING_FRAMES: Array[float] = [-9.0, 1.75]
const SWING_SEATS: Array[float] = [-1.05, 1.05]
## How close a child has to be to a seat to be the one pushing it.
const SWING_REACH := 3.0

## The slide. A child who steps onto the top is carried down it, because a slide
## you can only stand next to is scenery.
const SLIDE_SPEED := 4.2
## How fast a child gathers speed down the slide, and how far past its foot
## they run out before stopping. A slide is not a lift: the first ride moved
## at one speed from top to bottom and stopped dead, and read as being
## lowered on a rope.
const SLIDE_ACCEL := 3.2
const SLIDE_RUN_OUT := 1.1
## Three metres up and nearly six along: a real slide, with a ladder to the top
## of it. The first one was a metre and a half of ramp and read as unfinished.
## A couple of paces from the nearer swing frame's post, so the slide belongs
## to the same playground without a child on the swing kicking someone on the
## ladder.
const SLIDE_TOP := Vector3(7.0, 3.0, -2.65)
const SLIDE_FOOT := Vector3(7.0, 0.22, 3.0)
## How close to the top of the slide a child has to be to start sliding.
const SLIDE_GRAB := 1.1
## Where the ladder's foot is, relative to its top: three metres up over this
## much ground is a slope of about forty-eight degrees, under the fifty-two the
## character can walk, so the ladder is climbed by walking at it.
const LADDER_RUN := Vector3(0.0, -SLIDE_TOP.y, -2.7)
## Where the benches stand: in front of the swings, one per frame, far enough
## forward that a child on a full swing does not reach them.
const BENCHES: Array[float] = [-9.0, 1.75]
const BENCH_Z := 7.5

## The pad is laid out in bands, all relative to its centre and all inside
## the flat footprint (PlaceSpec.FOOTPRINT, 14.4 m). The middle band, z from
## -3 to 3, is the swings and the slide. Behind them (-z) the trampoline, clear
## of the seats' arc, with a flower bed in each back corner. In front (+z) the
## benches face the swings, a bin beside each, and beyond them the fountain
## with a flower bed to either side. The hoop stands at the far -x edge with
## its balls, and three lamps stand round the rim. The first layout put all of
## this on a pad a fifth smaller and it read as a heap; the point of the
## bands is that a child sees one thing at a time.
const TRAMPOLINE := Vector3(-3.5, 0.0, -8.0)
## Twice the first size, then a fifth more: a trampoline a child can miss is
## not a trampoline.
const TRAMPOLINE_RADIUS := 3.5
const TRAMPOLINE_TOP := 0.78
## How much higher a jump from the mat goes, and how much of a landing comes
## back as a bounce.
const TRAMPOLINE_JUMP := 1.6
const TRAMPOLINE_REBOUND := 0.6
## The ring's height is the real one; the ring is wider than a real one, so a
## throw that is nearly right goes in. The net has a child under it, not a
## league.
const HOOP := Vector3(-13.0, 0.0, -3.0)
const HOOP_HEIGHT := 3.3
const HOOP_RING := 0.30
const HOOP_REACH := HOOP_RING + 0.22
const BASKETBALLS: Array[Vector3] = [
	Vector3(-11.0, 0.5, -4.4), Vector3(-10.2, 0.5, -5.8), Vector3(-11.8, 0.5, -6.0),
]
const BINS: Array[Vector3] = [Vector3(-11.5, 0.0, 7.5), Vector3(4.6, 0.0, 7.5)]
const FOUNTAIN := Vector3(-3.6, 0.0, 11.0)
const FOUNTAIN_REACH := 2.0
const FLOWER_BEDS: Array[Vector3] = [
	Vector3(-9.0, 0.0, 11.0), Vector3(3.5, 0.0, 11.5),
	Vector3(-9.5, 0.0, -10.5), Vector3(4.5, 0.0, -11.0),
]

## Three lamps round the pad, which come on as it gets dark. Not floodlights:
## a playground at night should be pools of warm light with dark between them,
## the way a real one is, so each lamp reaches about as far as the next one
## and no further. They light one after another rather than together, because
## nothing in a real street switches on all at once.
const LAMPS: Array[Vector3] = [
	Vector3(-13.0, 0.0, 9.0), Vector3(12.5, 0.0, 8.0), Vector3(0.5, 0.0, -13.0),
]
const LAMP_THRESHOLDS: Array[float] = [0.12, 0.18, 0.25]
const LAMP_HEIGHT := 3.6
const LAMP_RANGE := 13.0
const LAMP_ENERGY := 1.5
const LAMP_COLOUR := Color(1.0, 0.82, 0.55)
const LAMP_FADE := 2.4
## The football pitch's floodlights: four tall posts a little beyond the
## corners, heads tilted in over the pitch, brighter and further-reaching
## than a street lamp, so the pitch is lit for a game after dark.
const PITCH_LAMP_CLEARANCE := 2.5
const PITCH_LAMP_HEIGHT := 6.0
const PITCH_LAMP_RANGE := 34.0
const PITCH_LAMP_ENERGY := 2.4

## A clipped hedge round the lot — a green wall, the kind that fences a real
## playground — with an opening on the side the path arrives from and one
## opposite. It was a ring of broadleaf bushes first, which read as a ring of
## small trees, and could be walked through.
const HEDGE_RADIUS := 17.4
const HEDGE_SEGMENTS := 44
const HEDGE_HEIGHT := 1.35
const HEDGE_THICKNESS := 0.85
## Half-width of each opening, in radians of the ring.
const HEDGE_GAP := 0.21
const CORNER_TREES := 21.0

var field: HeightField

var _camp := Vector3.ZERO
var _spots: Dictionary = {}
## Every seat: where it hangs from, the node that swings, and how much swing is
## left in it. The local child rides at most one of them at a time.
var _seats: Array[Dictionary] = []
var _rider := -1
## The playground's collision and furniture, kept so a check can count them.
var _solid: StaticBody3D = null
var _benches := 0
var _balls: Array[Ball] = []
var _has_hoop := false
var _flower_beds := 0
var _hedge_segments := 0
## What an animal must walk round, grouped by place: each group is a centre,
## a reach beyond which nothing in it matters, a list of circles (x, radius,
## z) relative to the centre, and for the playground the hedge ring.
var _obstacles: Array[Dictionary] = []
var _jet: MeshInstance3D = null
var _lamps: Array[Dictionary] = []
## Meals on the café's counter, each a node and how long it has left.
var _meals: Array[Dictionary] = []
## The café's collision, kept so a check can count it, and every seat in it:
## where to sit, where on the table the meal goes, and which way to face.
var _cafe_solid: StaticBody3D = null
var _cafe_walls: StaticBody3D = null
var _pitch_solid: StaticBody3D = null
## The pool's furniture, its turnstile — solid until paid, and for a while
## after — and its arms, which turn while it is open.
var _pool_solid: StaticBody3D = null
var _turnstile: StaticBody3D = null
var _turnstile_arms: Node3D = null
var _turnstile_open := 0.0
var _cafe_seats: Array[Dictionary] = []
## Each ball's height last frame, to see one drop through the ring.
var _ball_heights: Array[float] = []
var baskets := 0

## How far an empty seat stirs in the wind, and how slowly. A swing that hangs
## perfectly still reads as a model of a swing; one that moves a hand's width
## every few seconds reads as a swing.
const IDLE_SWAY := 0.035
const IDLE_SWAY_SPEED := 0.8
var _wind_time := 0.0

func _init(height_field: HeightField) -> void:
	field = height_field

## Put the three places around the camp. Called once.
func stand_up(camp: Vector3) -> void:
	_camp = camp
	# Positions come from PlaceSpec, which is also what the height field levels
	# and excavates against. Repeating the offsets here would let the buildings
	# drift off their own flat ground the first time one was moved.
	for place in ALL:
		_place(place, PlaceSpec.centre_of(place, camp))
	_build_pitch_lamps()

func position_of(place: StringName) -> Vector3:
	return _spots.get(place, Vector3.ZERO)

func exists(place: StringName) -> bool:
	return _spots.has(place)

## The place a child is standing in, or an empty name.
func nearest(at: Vector3) -> StringName:
	var best := &""
	var best_distance := REACH
	for place in _spots:
		var distance: float
		if place == PLAYGROUND:
			# The playground is big now, and what it offers is a swing: the
			# button belongs beside the seats, not at the geometric middle of
			# the pad, where a child standing at the slide would be offered a
			# swing they cannot reach.
			distance = _nearest_seat_distance(at)
			if distance >= SWING_REACH:
				continue
		else:
			var flat: Vector3 = _spots[place] - at
			flat.y = 0.0
			distance = flat.length()
			if place == CAFE:
				# Measured against the café's own, longer reach, then put on
				# the common scale so the nearest place still wins.
				distance *= REACH / CAFE_REACH
		if distance < best_distance:
			best_distance = distance
			best = place
	return best

## How far the nearest swing seat is, on the ground.
func _nearest_seat_distance(at: Vector3) -> float:
	var nearest_seat := INF
	for seat in _seats:
		var pivot: Vector3 = seat["pivot"]
		nearest_seat = minf(nearest_seat, Vector2(pivot.x - at.x, pivot.z - at.z).length())
	return nearest_seat

## How deep the water is at a point, counting the pool. Zero everywhere else.
##
## The pool is a hole in the ground filled to the brim rather than a box of
## water sitting on it, so its surface is at ground level and a child walks in
## rather than climbing over a lip.
func water_depth_at(x: float, z: float) -> float:
	if not _spots.has(POOL):
		return 0.0
	# The same function the terrain used to dig the hole, so the water is
	# exactly as deep as the ground is low. Two separate formulas here would
	# drift, and a child would float above the floor or stand in the water.
	return PlaceSpec.excavation(x, z, _camp)

## How deep a body at `at` is submerged, counting the river and the pool.
##
## Deliberately not "how deep is the water here": those agree only while a child
## is standing on the bottom. Asking the wrong one ignores the player's own
## height, so a child who floats up and breaks the surface is still reported as
## being in water — buoyancy keeps pushing, gravity is never applied, and they
## rise for as long as the game is left running. A tablet found one 1,445 m up.
##
## Returns zero when the body is above the surface, which is what makes gravity
## start again.
func submersion(at: Vector3, body_height: float) -> float:
	var ground := field.height_at(at.x, at.z)
	var feet := at.y - body_height * 0.5

	var surface := -1e9
	# The river: its surface is the world's water line, wherever the bed is
	# below it.
	if ground < HeightField.WATER_LEVEL:
		surface = HeightField.WATER_LEVEL
	# The pool: filled to the brim of the ground it was dug from, so its surface
	# is that ground plus what was excavated out of it.
	var dug := water_depth_at(at.x, at.z)
	if dug > 0.0:
		surface = maxf(surface, ground + dug)

	if surface < -1e8:
		return 0.0
	return maxf(0.0, surface - feet)

## Push the seat a child is standing at. Returns true if there was one in
## reach — a swing across the field cannot be pushed from here.
func push_swing(near: Vector3) -> bool:
	var best := -1
	var best_distance := SWING_REACH
	for i in _seats.size():
		var pivot: Vector3 = _seats[i]["pivot"]
		var flat := Vector2(pivot.x - near.x, pivot.z - near.z).length()
		if flat < best_distance:
			best_distance = flat
			best = i
	if best < 0:
		return false
	# Pushing while riding pushes the seat under you, never a neighbouring one:
	# leaning across to the next swing mid-arc is not a thing a child does.
	if _rider >= 0 and swinging():
		best = _rider
	var seat: Dictionary = _seats[best]
	var arc := float(seat["arc"])
	if arc <= 0.0:
		# Starting from rest: the first push is a kick off the ground, so the
		# swing begins at the bottom of its arc and rises from there.
		seat["phase"] = 0.0
	seat["arc"] = minf(arc + SWING_PUSH, SWING_ARC)
	_rider = best
	return true

## How wide the seat a child is on is swinging, in radians, or zero. Read by
## the game to tell a first push from a fourth, and by the checks.
func swing_arc() -> float:
	return 0.0 if _rider < 0 else float(_seats[_rider]["arc"])

## Get off. The seat keeps swinging — a child who jumps off does not stop it —
## but it is nobody's ride any more.
func step_off_swing() -> void:
	_rider = -1

## Is the local child on a moving swing?
func swinging() -> bool:
	return _rider >= 0 and float(_seats[_rider]["arc"]) > 0.0

## Where a child on the swing should be right now, or an empty vector when they
## are not on one. Returned rather than applied, because the player owns its own
## position and a node that moves the player from outside fights the character
## controller — the same reason a mount follows rather than carries.
func swing_rider_at() -> Vector3:
	if not swinging():
		return Vector3.ZERO
	var seat: Dictionary = _seats[_rider]
	var pivot: Vector3 = seat["pivot"]
	var hang := Vector3(0.0, -SWING_ROPE, 0.0)
	return pivot + hang.rotated(Vector3.RIGHT, _swing_angle(float(seat["arc"]), float(seat["phase"])))

## Where each seat hangs at rest, in world space. For the checks, and for
## anything that wants to send a child to a swing.
func seat_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for seat in _seats:
		var pivot: Vector3 = seat["pivot"]
		out.append(pivot + Vector3(0.0, -SWING_ROPE, 0.0))
	return out

## The circles an animal must not walk into at the playground, and the hedge
## ring round them. Coarse on purpose: a circle a little larger than each
## thing, so an animal gives it a respectful margin rather than brushing it.
func _note_playground_obstacles(at: Vector3) -> void:
	var circles: Array[Vector3] = []
	for frame_x in SWING_FRAMES:
		circles.append(Vector3(frame_x, 2.7, 0.0))
	for k in 6:
		var along := SLIDE_TOP.lerp(SLIDE_FOOT, float(k) / 5.0)
		circles.append(Vector3(along.x, 0.75, along.z))
	var ladder_top := Vector3(SLIDE_TOP.x, 0.0, SLIDE_TOP.z - 1.3)
	var ladder_foot := ladder_top + Vector3(0.0, 0.0, LADDER_RUN.z)
	for k in 3:
		var rung := ladder_top.lerp(ladder_foot, float(k) / 2.0)
		circles.append(Vector3(rung.x, 0.7, rung.z))
	circles.append(Vector3(TRAMPOLINE.x, TRAMPOLINE_RADIUS + 0.3, TRAMPOLINE.z))
	circles.append(Vector3(FOUNTAIN.x, 1.7, FOUNTAIN.z))
	for bench_x in BENCHES:
		circles.append(Vector3(bench_x, 1.2, BENCH_Z))
	for bin_at in BINS:
		circles.append(Vector3(bin_at.x, 0.5, bin_at.z))
	circles.append(Vector3(HOOP.x, 0.5, HOOP.z))
	for lamp in LAMPS:
		circles.append(Vector3(lamp.x, 0.45, lamp.z))
	for bed in FLOWER_BEDS:
		circles.append(Vector3(bed.x, 1.4, bed.z))
	for corner in 4:
		var angle := PI * 0.25 + PI * 0.5 * float(corner)
		circles.append(Vector3(cos(angle) * CORNER_TREES, 0.6, sin(angle) * CORNER_TREES))
	var group := _obstacle_group(at, circles)
	group["ring"] = HEDGE_RADIUS
	group["ring_half"] = HEDGE_THICKNESS * 0.5 + 0.25
	group["gap"] = HEDGE_GAP + 0.03
	group["reach"] = maxf(float(group["reach"]), HEDGE_RADIUS + 3.0)
	_obstacles.append(group)

static func _obstacle_group(centre: Vector3, circles: Array[Vector3]) -> Dictionary:
	var reach := 0.0
	for circle in circles:
		reach = maxf(reach, Vector2(circle.x, circle.z).length() + circle.y)
	return {"centre": centre, "reach": reach + 2.5, "circles": circles, "ring": 0.0}

## Is this point inside something an animal cannot walk through? `margin`
## widens everything by that much.
func obstructed(x: float, z: float, margin := 0.0) -> bool:
	for group in _obstacles:
		var centre: Vector3 = group["centre"]
		var dx := x - centre.x
		var dz := z - centre.z
		var away := sqrt(dx * dx + dz * dz)
		if away > float(group["reach"]) + margin:
			continue
		for circle: Vector3 in group["circles"]:
			if Vector2(dx - circle.x, dz - circle.z).length() < circle.y + margin:
				return true
		var ring := float(group["ring"])
		if ring > 0.0 and absf(away - ring) < float(group["ring_half"]) + margin:
			var angle := atan2(dz, dx)
			var to_gap := minf(absf(angle_difference(angle, 0.0)), absf(angle_difference(angle, PI)))
			if to_gap >= float(group["gap"]):
				return true
	return false

## Which way to lean to get round what is ahead: a push away from every
## obstacle within `look_ahead`, weighted by closeness, plus a nudge along its
## side in the direction already being travelled, so the animal flows round
## the thing rather than stopping at it. Things behind are ignored.
func steer_around(at: Vector3, heading: Vector3, toward: Vector3, look_ahead := 2.0) -> Vector3:
	var push := Vector3.ZERO
	for group in _obstacles:
		var centre: Vector3 = group["centre"]
		var flat := Vector2(at.x - centre.x, at.z - centre.z)
		var away := flat.length()
		if away > float(group["reach"]) + look_ahead:
			continue
		for circle: Vector3 in group["circles"]:
			var from_circle := Vector2(flat.x - circle.x, flat.y - circle.z)
			var gap := from_circle.length() - circle.y
			if gap > look_ahead:
				continue
			var out := Vector3(from_circle.x, 0.0, from_circle.y).normalized() if from_circle.length() > 0.001 else Vector3.RIGHT
			push += _steer_from(out, heading, toward, 1.0 - clampf(gap / look_ahead, 0.0, 1.0))
		var ring := float(group["ring"])
		if ring > 0.0 and away > 0.001:
			var band := absf(away - ring) - float(group["ring_half"])
			if band > look_ahead:
				continue
			var angle := atan2(flat.y, flat.x)
			var to_gap := minf(absf(angle_difference(angle, 0.0)), absf(angle_difference(angle, PI)))
			if to_gap < float(group["gap"]):
				continue
			var radial := Vector3(flat.x, 0.0, flat.y).normalized()
			push += _steer_from(radial if away > ring else -radial, heading, toward, 1.0 - clampf(band / look_ahead, 0.0, 1.0))
	return push

## The push from one obstacle whose outward normal is `out`: away from it, and
## along it — round the side nearer to where the animal wants to go, or,
## head-on, the side its body already leans to. Head-on was the failure: the
## first version chose the side from the heading alone, and an animal walking
## straight at the trampoline picked a different side every frame, went
## nowhere, and walked into it. Nothing for what is behind.
static func _steer_from(out: Vector3, heading: Vector3, toward: Vector3, weight: float) -> Vector3:
	var ahead := -out.dot(heading)
	if ahead < -0.2 or weight <= 0.0:
		return Vector3.ZERO
	var side := out.cross(Vector3.UP)
	var lean := side.dot(toward)
	if absf(lean) < 0.15:
		lean = side.dot(heading)
	if lean < -0.02:
		side = -side
	# Sharper the closer it gets: a wall a stride away must turn the body
	# hard, one three strides away should only bend the path.
	var urgency := weight * weight * (0.4 + 0.6 * maxf(ahead, 0.0))
	return (out * 2.2 + side * 1.8) * urgency

## How many things there are to walk round. For the checks.
func obstacle_count() -> int:
	var count := 0
	for group in _obstacles:
		count += (group["circles"] as Array).size()
	return count

## Where the top of the slide is, in world space.
func slide_top() -> Vector3:
	if not _spots.has(PLAYGROUND):
		return Vector3.ZERO
	return _spots[PLAYGROUND] + SLIDE_TOP

## Where the foot of the slide is.
func slide_foot() -> Vector3:
	if not _spots.has(PLAYGROUND):
		return Vector3.ZERO
	return _spots[PLAYGROUND] + SLIDE_FOOT

## Is a child standing at the top of the slide, ready to go down?
func at_slide_top(at: Vector3) -> bool:
	if not _spots.has(PLAYGROUND):
		return false
	return at.distance_to(slide_top()) < SLIDE_GRAB

## How fast the seat swings, in radians of phase per second: a pendulum on a
## rope this long. Nothing to tune — it falls out of the rope and the gravity.
static func swing_rate() -> float:
	return sqrt(SWING_GRAVITY / SWING_ROPE)

## Where the seat hangs, from how wide it is swinging and how far through the
## swing it is.
func _swing_angle(arc: float, phase: float) -> float:
	return sin(phase) * arc

func _process(delta: float) -> void:
	var stamp := PerfLog.stamp()
	_tick(delta)
	PerfLog.note("places", stamp)

func _tick(delta: float) -> void:
	_wind_time += delta
	_watch_balls()
	if _jet != null:
		# The jet breathes: a fountain that stands perfectly still is a statue
		# of a fountain.
		_jet.scale = Vector3(1.0, 1.0 + 0.10 * sin(_wind_time * 7.3), 1.0)
	_tick_meals(delta)
	_tick_turnstile(delta)
	for i in _seats.size():
		var seat: Dictionary = _seats[i]
		var node: Node3D = seat["node"]
		if not is_instance_valid(node):
			continue
		var arc := float(seat["arc"])
		if arc <= 0.0:
			# Stirring in the wind, each seat on its own phase so the four do not
			# swing in step like a metronome.
			node.rotation.x = sin(_wind_time * IDLE_SWAY_SPEED + float(i) * 1.7) * IDLE_SWAY
			continue
		# The seat keeps its own pace, and the arc falls away slowly: a swing
		# left alone is still swinging half a minute later, which is what a
		# swing does.
		var phase := fmod(float(seat["phase"]) + swing_rate() * delta, TAU)
		arc *= exp(-delta / SWING_SETTLE)
		if arc < SWING_STOPS_AT:
			arc = 0.0
			if _rider == i:
				_rider = -1
		seat["phase"] = phase
		seat["arc"] = arc
		node.rotation.x = _swing_angle(arc, phase)

func _place(place: StringName, at: Vector3) -> void:
	var spot := at
	spot.y = field.height_at(at.x, at.z)
	if place == POOL:
		# The pool's own spot is the brim it is filled to, not the floor of
		# the hole. `height_at` in the middle of a pool answers with the
		# bottom, and everything built from that — the water sheet, the tiled
		# rim, the fence, the booth — was put down there: from the bank there
		# was no fence and no water, only a dry hole. Adding back what was
		# excavated puts the brim back where a child stands.
		spot.y += PlaceSpec.excavation(at.x, at.z, _camp)
	_spots[place] = spot
	match place:
		PLAYGROUND:
			_build_playground(spot)
			_note_playground_obstacles(spot)
		POOL:
			_build_pool(spot)
			_obstacles.append(_obstacle_group(spot, [Vector3(0.0, POOL_FENCE_X + 1.5, 0.0)]))
		CAFE:
			_build_cafe(spot)
			_note_cafe_obstacles(spot)

## Two swing frames, a slide with a ladder, a hedge round the lot and a tree at
## each corner — a playground rather than a swing standing in a field.
func _build_playground(at: Vector3) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var timber := Color(0.62, 0.44, 0.28)
	var metal := Color(0.74, 0.76, 0.80)
	var paint := Color(0.94, 0.58, 0.26)

	for frame_x in SWING_FRAMES:
		# Two A-frames and a crossbar.
		for side in PackedFloat32Array([-1.0, 1.0]):
			for lean in PackedFloat32Array([-1.0, 1.0]):
				var post := CylinderMesh.new()
				post.top_radius = 0.07
				post.bottom_radius = 0.09
				post.height = SWING_POST
				post.radial_segments = 6
				post.rings = 1
				# Rotating about X by a positive angle tips a post's top towards
				# +Z, so a post standing at +Z and leaning +13° leans *outwards*:
				# both posts met at the ground and parted at the top, an upside-
				# down A that had been there since the first swing. The angle is
				# negated so the tops meet under the bar and the feet spread.
				_add(tool, post, Transform3D(
					Basis(Vector3.RIGHT, deg_to_rad(-lean * 13.0)),
					Vector3(frame_x + side * SWING_WIDTH * 0.5, SWING_POST * 0.485, lean * 0.44)
				), timber)
		var bar := CylinderMesh.new()
		bar.top_radius = 0.06
		bar.bottom_radius = 0.06
		bar.height = SWING_WIDTH
		bar.radial_segments = 6
		bar.rings = 1
		_add(tool, bar, Transform3D(
			Basis(Vector3.FORWARD, deg_to_rad(90.0)), Vector3(frame_x, SWING_BAR, 0.0)
		), timber)
		# Metal caps where the bar meets each A, and a foot beam holding each
		# pair of legs together at the ground — the joinery that makes it read
		# as built rather than as three cylinders leaning on each other.
		for side in PackedFloat32Array([-1.0, 1.0]):
			var cap := CylinderMesh.new()
			cap.top_radius = 0.085
			cap.bottom_radius = 0.085
			cap.height = 0.22
			cap.radial_segments = 8
			cap.rings = 1
			_add(tool, cap, Transform3D(
				Basis(Vector3.FORWARD, deg_to_rad(90.0)), Vector3(frame_x + side * SWING_WIDTH * 0.5, SWING_BAR, 0.0)
			), metal)
			var beam := BoxMesh.new()
			beam.size = Vector3(0.14, 0.10, 2.1)
			_add(tool, beam, Transform3D(Basis(), Vector3(frame_x + side * SWING_WIDTH * 0.5, 0.05, 0.0)), timber)

	# The slide. A platform on four legs at the top, a ladder up the back of
	# it, and a long shallow ramp with rails down the front.
	var top := SLIDE_TOP
	var foot := SLIDE_FOOT
	var platform := BoxMesh.new()
	platform.size = Vector3(1.3, 0.12, 1.3)
	var platform_at := Vector3(top.x, top.y, top.z - 0.65)
	_add(tool, platform, Transform3D(Basis(), platform_at), paint)
	for dx in PackedFloat32Array([-0.55, 0.55]):
		for dz in PackedFloat32Array([-0.55, 0.55]):
			var leg := CylinderMesh.new()
			leg.top_radius = 0.06
			leg.bottom_radius = 0.07
			leg.height = top.y
			leg.radial_segments = 6
			leg.rings = 1
			_add(tool, leg, Transform3D(
				Basis(), Vector3(platform_at.x + dx, top.y * 0.5, platform_at.z + dz)
			), metal)
	# The ladder leans up the back of the platform at an angle a child can
	# climb by walking — which is how climbing works here: a collider the shape
	# of the ladder lets the character walk up it, and the rails and rungs are
	# what that looks like.
	var climb_top := Vector3(top.x, top.y, platform_at.z - 0.65)
	var climb_foot := climb_top + LADDER_RUN
	var climb := climb_top - climb_foot
	var climb_basis := Basis.looking_at(climb.normalized(), Vector3.UP)
	for dx in PackedFloat32Array([-0.42, 0.42]):
		var rail := CylinderMesh.new()
		rail.top_radius = 0.035
		rail.bottom_radius = 0.035
		rail.height = climb.length() + 0.5
		rail.radial_segments = 5
		rail.rings = 1
		# A cylinder stands along Y; turned to lie along the climb.
		_add(tool, rail, Transform3D(
			climb_basis * Basis(Vector3.RIGHT, PI * 0.5),
			climb_foot + climb * 0.5 + Vector3(dx, 0.0, 0.0)
		), metal)
	var rungs := int(climb.length() / 0.4)
	for i in rungs:
		var rung := BoxMesh.new()
		rung.size = Vector3(0.84, 0.06, 0.07)
		var along := (float(i) + 0.5) / float(rungs)
		_add(tool, rung, Transform3D(Basis(), climb_foot + climb * along), metal)
	# The ramp, from the front of the platform to the foot.
	var run := Vector3(top.x, top.y - 0.02, top.z)
	var drop := foot - run
	var length := drop.length()
	var ramp := BoxMesh.new()
	ramp.size = Vector3(0.9, 0.09, length)
	var ramp_at := run + drop * 0.5
	# The box's own Z axis laid along the descent, from the platform down to
	# the foot. Built this way rather than from an angle because the first
	# version rotated by that angle with the wrong sign, and the slide went up
	# from its platform into the air — a mirror image that no check saw, since
	# the constants said one thing and the mesh did another.
	var ramp_basis := Basis.looking_at(drop.normalized(), Vector3.UP)
	_add(tool, ramp, Transform3D(ramp_basis, ramp_at), paint)
	for dx in PackedFloat32Array([-0.44, 0.44]):
		var side_rail := BoxMesh.new()
		side_rail.size = Vector3(0.07, 0.26, length)
		_add(tool, side_rail, Transform3D(ramp_basis, ramp_at + ramp_basis * Vector3(dx, 0.15, 0.0)), paint.darkened(0.18))
	# A flat lip at the foot to run out on, so the ramp does not simply end in
	# the ground.
	var lip := BoxMesh.new()
	lip.size = Vector3(0.9, 0.06, 0.7)
	_add(tool, lip, Transform3D(Basis(), foot + Vector3(0.0, 0.03, 0.35)), paint)
	# Railings along both sides of the platform: what a child holds at the top.
	# There was an arch across the ramp's start too, and from the platform it
	# read as a barrier you walked through, so it went.
	for dx in PackedFloat32Array([-0.65, 0.65]):
		for dz in PackedFloat32Array([-0.55, 0.55]):
			var upright := CylinderMesh.new()
			upright.top_radius = 0.03
			upright.bottom_radius = 0.03
			upright.height = 0.85
			upright.radial_segments = 5
			upright.rings = 1
			_add(tool, upright, Transform3D(Basis(), platform_at + Vector3(dx, 0.425, dz)), metal)
		var handrail := BoxMesh.new()
		handrail.size = Vector3(0.05, 0.05, 1.3)
		_add(tool, handrail, Transform3D(Basis(), platform_at + Vector3(dx, 0.85, 0.0)), metal)

	tool.generate_normals()
	tool.set_material(_material())

	var frame := MeshInstance3D.new()
	frame.mesh = tool.commit()
	frame.transform = Transform3D(Basis(), at)
	add_child(frame)

	# What a child bumps into and stands on. The posts and the platform's legs
	# are solid, the platform can be stood on, and the ladder is a slope to walk
	# up. The slide's ramp is deliberately not solid: the ride carries the child
	# along it, and a collider there would fight the carrying.
	var solid := StaticBody3D.new()
	solid.transform = Transform3D(Basis(), at)
	for frame_x in SWING_FRAMES:
		for side in PackedFloat32Array([-1.0, 1.0]):
			for lean in PackedFloat32Array([-1.0, 1.0]):
				var post_shape := CylinderShape3D.new()
				post_shape.radius = 0.11
				post_shape.height = SWING_POST
				_collide(solid, post_shape, Transform3D(
					Basis(Vector3.RIGHT, deg_to_rad(-lean * 13.0)),
					Vector3(frame_x + side * SWING_WIDTH * 0.5, SWING_POST * 0.485, lean * 0.44)
				))
	var deck := BoxShape3D.new()
	deck.size = Vector3(1.3, 0.12, 1.3)
	_collide(solid, deck, Transform3D(Basis(), platform_at))
	for dx in PackedFloat32Array([-0.55, 0.55]):
		for dz in PackedFloat32Array([-0.55, 0.55]):
			var leg_shape := CylinderShape3D.new()
			leg_shape.radius = 0.08
			leg_shape.height = top.y
			_collide(solid, leg_shape, Transform3D(
				Basis(), Vector3(platform_at.x + dx, top.y * 0.5, platform_at.z + dz)
			))
	var climb_shape := BoxShape3D.new()
	climb_shape.size = Vector3(1.0, 0.16, climb.length() + 0.3)
	_collide(solid, climb_shape, Transform3D(climb_basis, climb_foot + climb * 0.5))

	# Two benches facing the swings, for whoever is watching. A playground is
	# also where the grown-ups sit.
	for bench_x in BENCHES:
		_build_bench(at, Vector3(bench_x, 0.0, BENCH_Z), solid)
	_benches = BENCHES.size()

	_build_trampoline(at, solid)
	_build_lamps(at, solid)
	_build_hoop(at, solid)
	for bin_at in BINS:
		_build_bin(at, bin_at, solid)
	_build_fountain(at, solid)
	for bed in FLOWER_BEDS:
		_build_flower_bed(at, bed)
	_flower_beds = FLOWER_BEDS.size()

	_balls.clear()
	_ball_heights.clear()
	for local in BASKETBALLS:
		var ball := Ball.new(at + local, Ball.Look.BASKETBALL)
		add_child(ball)
		_balls.append(ball)
		_ball_heights.append(ball.position.y)

	solid.collision_layer = TerrainSpec.LAYER_PROPS
	add_child(solid)
	_solid = solid

	# Each seat is its own node so it can swing. Pivoted at the crossbar, so
	# rotating it arcs the seat rather than spinning it in place.
	_seats.clear()
	for frame_x in SWING_FRAMES:
		for seat_x in SWING_SEATS:
			var pivot_at := at + Vector3(frame_x + seat_x, SWING_BAR, 0.0)
			var pivot := Node3D.new()
			pivot.transform = Transform3D(Basis(), pivot_at)
			add_child(pivot)

			var seat_tool := SurfaceTool.new()
			seat_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			var chain := Color(0.46, 0.48, 0.52)
			for side in PackedFloat32Array([-0.34, 0.34]):
				# A chain: a thin dark line broken into links, hung from a ring
				# on the bar, so it reads as chain rather than as a rod.
				var links := 9
				for link in links:
					var piece := CylinderMesh.new()
					piece.top_radius = 0.018
					piece.bottom_radius = 0.018
					piece.height = SWING_ROPE / float(links) * 0.78
					piece.radial_segments = 5
					piece.rings = 1
					var y := -SWING_ROPE * (float(link) + 0.5) / float(links)
					_add(seat_tool, piece, Transform3D(Basis(), Vector3(side, y, 0.0)), chain)
				var ring := TorusMesh.new()
				ring.inner_radius = 0.03
				ring.outer_radius = 0.06
				ring.rings = 6
				ring.ring_segments = 8
				# A torus lies in XZ; turned about X to hang in the swing's plane.
				_add(seat_tool, ring, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(side, -0.03, 0.0)), metal)
			# A belt seat: two slabs meeting at a shallow angle, so it sags in the
			# middle the way rubber does under a child, in one of two colours so
			# two children on one frame each know which is theirs.
			var rubber := (
				Color(0.20, 0.22, 0.26) if int(seat_x * 10.0) < 0 else Color(0.62, 0.22, 0.20)
			)
			for half in PackedFloat32Array([-1.0, 1.0]):
				var slab := BoxMesh.new()
				slab.size = Vector3(0.44, 0.06, 0.30)
				# Rotating about FORWARD by a positive angle sends the +X end
				# *down* — worked out from n x v rather than assumed, after the
				# first version peaked in the middle like a little roof. The outer
				# edge of each half has to rise for the seat to sag.
				_add(seat_tool, slab, Transform3D(
					Basis(Vector3.FORWARD, -half * deg_to_rad(9.0)),
					Vector3(half * 0.21, -SWING_ROPE + 0.02, 0.0)
				), rubber)
			seat_tool.generate_normals()
			seat_tool.set_material(_material())

			var seat_node := MeshInstance3D.new()
			seat_node.mesh = seat_tool.commit()
			pivot.add_child(seat_node)
			_seats.append({"pivot": pivot_at, "node": seat_node, "arc": 0.0, "phase": 0.0})

	_plant_hedge(at, solid)

## The hedge: a ring of clipped blocks, each a box, so it reads as one green
## wall with a slightly uneven top, the way a real clipped hedge does. Solid,
## block by block, because a hedge you can walk through is a painting of a
## hedge. Four broadleaf trees stand outside the corners, with solid trunks.
func _plant_hedge(at: Vector3, solid: StaticBody3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Three greens: a dark base, the body, and the sunlit tops. One green made
	# the hedge a wall painted green; this is what makes it read as growing.
	var leaf_dark := Color(0.15, 0.33, 0.14)
	var leaf := Color(0.22, 0.46, 0.20)
	var leaf_light := Color(0.36, 0.60, 0.27)
	var length := TAU * HEDGE_RADIUS / float(HEDGE_SEGMENTS)
	# Blocks overlap a little, so the wall has no chinks; the collider is
	# taller than the block and sunk a little, so no gap opens at the ground
	# where the pad's edge starts to slope.
	var shape := BoxShape3D.new()
	shape.size = Vector3(length * 1.03, HEDGE_HEIGHT + 0.3, HEDGE_THICKNESS)
	_hedge_segments = 0
	for i in HEDGE_SEGMENTS:
		var angle := TAU * (float(i) + 0.5) / float(HEDGE_SEGMENTS)
		# Openings facing towards and away from the camp's side, so the path
		# arrives at a gap in the hedge rather than at the hedge.
		var to_gap := minf(absf(angle_difference(angle, 0.0)), absf(angle_difference(angle, PI)))
		if to_gap < HEDGE_GAP:
			continue
		var height := HEDGE_HEIGHT + rng.randf_range(-0.12, 0.14)
		# Each block a little in or out of the true ring and a little off the
		# tangent, so the line is a hedge's line and not a compass's.
		var radius := HEDGE_RADIUS + rng.randf_range(-0.12, 0.12)
		var spot := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var world := at + spot
		spot.y = field.height_at(world.x, world.z) - at.y - 0.05
		# A box lying along X, turned so that X runs along the ring's tangent.
		# Rotating about Y by θ sends +X to (cos θ, 0, -sin θ), and the tangent
		# at `angle` is (-sin, 0, cos), so θ is -angle - 90°. The first version
		# had the sign wrong, and every block on a diagonal stood radially, with
		# a gap either side of it.
		var turn := -angle - PI * 0.5
		var basis := Basis(Vector3.UP, turn + deg_to_rad(rng.randf_range(-3.0, 3.0)))
		var shade := leaf.lerp(leaf_light, rng.randf_range(0.0, 0.5))

		# The body in two bands: darker below, where a real hedge is all
		# stems and shadow, and the leafy green above.
		var base_height := height * 0.42
		var base := BoxMesh.new()
		base.size = Vector3(length * 1.03, base_height, HEDGE_THICKNESS - 0.06)
		_add(tool, base, Transform3D(basis, spot + Vector3(0.0, base_height * 0.5, 0.0)), leaf_dark.lerp(shade, 0.3))
		var block := BoxMesh.new()
		block.size = Vector3(length * 1.03, height - base_height, HEDGE_THICKNESS)
		_add(tool, block, Transform3D(basis, spot + Vector3(0.0, base_height + (height - base_height) * 0.5, 0.0)), shade)

		# Lumps of foliage along the top and bulging from the sides: a clipped
		# hedge is never quite flat, and the lumps are what make it foliage
		# rather than a painted plank.
		for lump in 3:
			var along := (float(lump) - 1.0) * length * 0.33 + rng.randf_range(-0.12, 0.12)
			var crown := SphereMesh.new()
			crown.radius = rng.randf_range(0.36, 0.5)
			crown.height = crown.radius * 1.3
			crown.radial_segments = 7
			crown.rings = 4
			var crown_at := basis * Vector3(along, 0.0, rng.randf_range(-0.12, 0.12))
			_add(tool, crown, Transform3D(basis, spot + crown_at + Vector3(0.0, height - crown.radius * 0.35, 0.0)),
				shade.lerp(leaf_light, rng.randf_range(0.2, 0.9)))
		for bulge in 2:
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var tuft := SphereMesh.new()
			tuft.radius = rng.randf_range(0.22, 0.32)
			tuft.height = tuft.radius * 1.6
			tuft.radial_segments = 6
			tuft.rings = 3
			var tuft_at := basis * Vector3(rng.randf_range(-length * 0.4, length * 0.4), 0.0, side * HEDGE_THICKNESS * 0.42)
			_add(tool, tuft, Transform3D(basis, spot + tuft_at + Vector3(0.0, rng.randf_range(0.5, height - 0.2), 0.0)),
				shade.lerp(leaf_dark if rng.randf() < 0.5 else leaf_light, 0.4))

		_collide(solid, shape, Transform3D(Basis(Vector3.UP, turn), spot + Vector3(0.0, (HEDGE_HEIGHT + 0.3) * 0.5 - 0.15, 0.0)))
		_hedge_segments += 1
	_finish_into(tool, at)

	var trunk := CylinderShape3D.new()
	trunk.radius = 0.36
	trunk.height = 4.0
	var trees: Array[Transform3D] = []
	for corner in 4:
		var angle := PI * 0.25 + PI * 0.5 * float(corner)
		var spot := Vector3(cos(angle), 0.0, sin(angle)) * CORNER_TREES
		var world := at + spot
		spot.y = field.height_at(world.x, world.z) - at.y - 0.15
		trees.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), spot))
		_collide(solid, trunk, Transform3D(Basis(), spot + Vector3(0.0, 2.0, 0.0)))
	_scatter(PlantMeshes.broadleaf(4.8), trees, at)

func _scatter(mesh: Mesh, transforms: Array[Transform3D], at: Vector3) -> void:
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = _material()
	instance.transform = Transform3D(Basis(), at)
	add_child(instance)

## A tiled rim around a hollow. The water itself is drawn by the water surface,
## which reads the depth from water_depth_at.
func _build_pool(at: Vector3) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var solid := StaticBody3D.new()
	solid.transform = Transform3D(Basis(), at)
	solid.collision_layer = TerrainSpec.LAYER_PROPS
	add_child(solid)
	_pool_solid = solid

	var tile := Color(0.88, 0.92, 0.94)
	var timber := Color(0.54, 0.38, 0.24)
	var iron := Color(0.20, 0.21, 0.23)
	var paint := Color(0.94, 0.58, 0.26)

	# No walls and no floor: the height field has already dug the hollow, and a
	# box of walls inside it would fight the terrain for the same pixels. A
	# tiled rim round the water, and a lane line down the middle under it.
	for i in 4:
		var along := i % 2 == 0
		var sign_of := 1.0 if i < 2 else -1.0
		var rim := BoxMesh.new()
		if along:
			rim.size = Vector3(POOL_HALF_X * 2.0 + 0.7, 0.14, 0.7)
		else:
			rim.size = Vector3(0.7, 0.14, POOL_HALF_Z * 2.0 + 0.7)
		var rim_at := Vector3(
			0.0 if along else sign_of * (POOL_HALF_X + 0.2),
			0.07,
			sign_of * (POOL_HALF_Z + 0.2) if along else 0.0
		)
		_add(tool, rim, Transform3D(Basis(), rim_at), tile)
	# Steps down into the shallow end, and a block to jump from at the deep.
	for step in 3:
		var tread := BoxMesh.new()
		tread.size = Vector3(1.6, 0.16, 0.6)
		_add(tool, tread, Transform3D(Basis(), Vector3(-POOL_HALF_X + 0.8, -0.1 - float(step) * 0.28, POOL_HALF_Z - 0.6 - float(step) * 0.6)), tile)
	var block := BoxMesh.new()
	block.size = Vector3(0.7, 0.5, 0.7)
	_add(tool, block, Transform3D(Basis(), Vector3(0.0, 0.25, -POOL_HALF_Z - 0.55)), paint)
	var block_shape := BoxShape3D.new()
	block_shape.size = block.size
	_collide(solid, block_shape, Transform3D(Basis(), Vector3(0.0, 0.25, -POOL_HALF_Z - 0.55)))
	# Two loungers along the far poolside, for the look of a place people lie
	# about: laid along it, head towards the water, with a raised back.
	for local in POOL_LOUNGERS:
		var seat := BoxMesh.new()
		seat.size = Vector3(POOL_LOUNGER_SIZE.x * 0.66, 0.08, POOL_LOUNGER_SIZE.z)
		_add(tool, seat, Transform3D(Basis(), local + Vector3(POOL_LOUNGER_SIZE.x * 0.17, 0.4, 0.0)), Color(0.30, 0.52, 0.86))
		# The back, tipped up at the end nearer the fence.
		var back := BoxMesh.new()
		back.size = Vector3(POOL_LOUNGER_SIZE.x * 0.34, 0.08, POOL_LOUNGER_SIZE.z)
		_add(tool, back, Transform3D(
			Basis(Vector3.FORWARD, deg_to_rad(34.0)),
			local + Vector3(-POOL_LOUNGER_SIZE.x * 0.36, 0.52, 0.0)
		), Color(0.30, 0.52, 0.86))
		for dx in PackedFloat32Array([-0.55, 0.75]):
			var leg := BoxMesh.new()
			leg.size = Vector3(0.06, 0.36, POOL_LOUNGER_SIZE.z)
			_add(tool, leg, Transform3D(Basis(), local + Vector3(dx, 0.18, 0.0)), iron)
		var lounger_shape := BoxShape3D.new()
		lounger_shape.size = POOL_LOUNGER_SIZE
		_collide(solid, lounger_shape, Transform3D(Basis(), local + Vector3(0.0, POOL_LOUNGER_SIZE.y * 0.5, 0.0)))

	# The fence: posts every two metres with two rails, a gap on the side
	# facing the pitch for the turnstile. Solid, or the fence is a suggestion.
	var rail_shape_x := BoxShape3D.new()
	rail_shape_x.size = Vector3(POOL_FENCE_X * 2.0, 1.3, 0.14)
	for sz in PackedFloat32Array([-1.0, 1.0]):
		_collide(solid, rail_shape_x, Transform3D(Basis(), Vector3(0.0, 0.65, sz * POOL_FENCE_Z)))
	var west := BoxShape3D.new()
	west.size = Vector3(0.14, 1.3, POOL_FENCE_Z * 2.0)
	_collide(solid, west, Transform3D(Basis(), Vector3(-POOL_FENCE_X, 0.65, 0.0)))
	var east_half := POOL_FENCE_Z - POOL_GATE_HALF
	var east := BoxShape3D.new()
	east.size = Vector3(0.14, 1.3, east_half)
	for sz in PackedFloat32Array([-1.0, 1.0]):
		_collide(solid, east, Transform3D(Basis(), Vector3(POOL_FENCE_X, 0.65, sz * (POOL_GATE_HALF + east_half * 0.5))))
	var perimeter := 2.0 * (POOL_FENCE_X + POOL_FENCE_Z) * 2.0
	var posts := int(perimeter / 2.0)
	for k in posts:
		var along := float(k) / float(posts) * perimeter
		var corner := _along_rectangle(along, POOL_FENCE_X, POOL_FENCE_Z)
		# No post in the gateway.
		if absf(corner.x - POOL_FENCE_X) < 0.01 and absf(corner.z) < POOL_GATE_HALF + 0.3:
			continue
		var post := CylinderMesh.new()
		post.top_radius = 0.05
		post.bottom_radius = 0.06
		post.height = 1.3
		post.radial_segments = 6
		post.rings = 1
		_add(tool, post, Transform3D(Basis(), corner + Vector3(0.0, 0.65, 0.0)), iron)
	for y in PackedFloat32Array([0.55, 1.15]):
		var long_rail := BoxMesh.new()
		long_rail.size = Vector3(POOL_FENCE_X * 2.0, 0.05, 0.05)
		for sz in PackedFloat32Array([-1.0, 1.0]):
			_add(tool, long_rail, Transform3D(Basis(), Vector3(0.0, y, sz * POOL_FENCE_Z)), tile)
		var short_rail := BoxMesh.new()
		short_rail.size = Vector3(0.05, 0.05, POOL_FENCE_Z * 2.0)
		_add(tool, short_rail, Transform3D(Basis(), Vector3(-POOL_FENCE_X, y, 0.0)), tile)
		var gate_rail := BoxMesh.new()
		gate_rail.size = Vector3(0.05, 0.05, east_half)
		for sz in PackedFloat32Array([-1.0, 1.0]):
			_add(tool, gate_rail, Transform3D(Basis(), Vector3(POOL_FENCE_X, y, sz * (POOL_GATE_HALF + east_half * 0.5))), tile)
	# A lifebuoy on the fence by the deep end.
	var buoy := TorusMesh.new()
	buoy.inner_radius = 0.18
	buoy.outer_radius = 0.32
	buoy.rings = 8
	buoy.ring_segments = 14
	_add(tool, buoy, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(2.0, 0.9, -POOL_FENCE_Z - 0.08)), Color(0.90, 0.28, 0.24))

	# The way in: gate posts, the turnstile itself (its own body, so it can
	# open), and a ticket booth beside it with a coin on the sign.
	for sz in PackedFloat32Array([-1.0, 1.0]):
		var gate_post := BoxMesh.new()
		gate_post.size = Vector3(0.14, 1.5, 0.14)
		_add(tool, gate_post, Transform3D(Basis(), Vector3(POOL_FENCE_X, 0.75, sz * POOL_GATE_HALF)), iron)
	var hub := CylinderMesh.new()
	hub.top_radius = 0.07
	hub.bottom_radius = 0.08
	hub.height = 1.0
	hub.radial_segments = 8
	hub.rings = 1
	_add(tool, hub, Transform3D(Basis(), Vector3(POOL_FENCE_X, 0.5, 0.0)), iron)
	_build_ticket_booth(tool, Vector3(POOL_FENCE_X + 0.9, 0.0, -POOL_GATE_HALF - 1.4), solid)
	for i in POOL_LAMPS.size():
		_build_lamp(tool, at, POOL_LAMPS[i], solid, 0.13 + 0.05 * float(i))
	_finish_into(tool, at)

	# The arms of the turnstile turn while it is open, so they are a node.
	_turnstile_arms = Node3D.new()
	_turnstile_arms.position = at + Vector3(POOL_FENCE_X, 0.95, 0.0)
	add_child(_turnstile_arms)
	var arms_tool := SurfaceTool.new()
	arms_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var angle := TAU * float(k) / 3.0
		var arm := CylinderMesh.new()
		arm.top_radius = 0.03
		arm.bottom_radius = 0.03
		arm.height = 0.7
		arm.radial_segments = 6
		arm.rings = 1
		# Arms out from the hub, tipped a little down, spaced round it.
		var lay := Basis(Vector3.UP, angle) * Basis(Vector3.FORWARD, deg_to_rad(80.0))
		_add(arms_tool, arm, Transform3D(lay, lay * Vector3(0.0, 0.35, 0.0)), Color(0.86, 0.88, 0.90))
	arms_tool.generate_normals()
	arms_tool.set_material(_material())
	var arms_mesh := MeshInstance3D.new()
	arms_mesh.mesh = arms_tool.commit()
	_turnstile_arms.add_child(arms_mesh)
	_turnstile = StaticBody3D.new()
	_turnstile.collision_layer = TerrainSpec.LAYER_PROPS
	var bar := CollisionShape3D.new()
	var bar_shape := BoxShape3D.new()
	bar_shape.size = Vector3(0.5, 1.3, POOL_GATE_HALF * 2.0)
	bar.shape = bar_shape
	bar.position = Vector3(0.0, 0.65, 0.0)
	_turnstile.add_child(bar)
	_turnstile.position = at + Vector3(POOL_FENCE_X, 0.0, 0.0)
	add_child(_turnstile)

	# The water in the pool: a flat pane at the brim, the same blue as the
	# river so the two read as the same substance.
	var pane := PlaneMesh.new()
	pane.size = Vector2(POOL_HALF_X * 2.0 - 0.1, POOL_HALF_Z * 2.0 - 0.1)
	var surface := StandardMaterial3D.new()
	surface.albedo_color = Color(0.36, 0.62, 0.78, 0.72)
	surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	surface.roughness = 0.16
	surface.metallic = 0.25
	var water := MeshInstance3D.new()
	water.mesh = pane
	water.material_override = surface
	water.transform = Transform3D(Basis(), at + Vector3(0.0, -0.04, 0.0))
	add_child(water)

## A point `along` metres round a rectangle of the given half-sizes, starting
## at the east side's middle and going clockwise seen from above.
static func _along_rectangle(along: float, half_x: float, half_z: float) -> Vector3:
	var edges: Array[float] = [half_z, half_x * 2.0, half_z * 2.0, half_x * 2.0, half_z]
	var left := along
	if left < edges[0]:
		return Vector3(half_x, 0.0, left)
	left -= edges[0]
	if left < edges[1]:
		return Vector3(half_x - left, 0.0, half_z)
	left -= edges[1]
	if left < edges[2]:
		return Vector3(-half_x, 0.0, half_z - left)
	left -= edges[2]
	if left < edges[3]:
		return Vector3(-half_x + left, 0.0, -half_z)
	left -= edges[3]
	return Vector3(half_x, 0.0, -half_z + left)

## The ticket booth: a little hut with a window, and a sign with a coin and
## as many pips as a ticket costs — a price a child who cannot read can read.
func _build_ticket_booth(tool: SurfaceTool, local: Vector3, solid: StaticBody3D) -> void:
	var wall := Color(0.92, 0.88, 0.78)
	var timber := Color(0.54, 0.38, 0.24)
	var hut := BoxMesh.new()
	hut.size = Vector3(1.5, 2.3, 1.5)
	_add(tool, hut, Transform3D(Basis(), local + Vector3(0.0, 1.15, 0.0)), wall)
	var roof := CylinderMesh.new()
	roof.top_radius = 0.0
	roof.bottom_radius = 1.25
	roof.height = 0.55
	roof.radial_segments = 4
	roof.rings = 1
	_add(tool, roof, Transform3D(Basis(Vector3.UP, PI * 0.25), local + Vector3(0.0, 2.55, 0.0)), Color(0.62, 0.30, 0.24))
	var window := BoxMesh.new()
	window.size = Vector3(0.06, 0.7, 0.9)
	_add(tool, window, Transform3D(Basis(), local + Vector3(-0.76, 1.4, 0.0)), Color(0.70, 0.84, 0.92))
	var counter := BoxMesh.new()
	counter.size = Vector3(0.3, 0.06, 1.0)
	_add(tool, counter, Transform3D(Basis(), local + Vector3(-0.85, 1.02, 0.0)), timber)
	var sign := BoxMesh.new()
	sign.size = Vector3(0.06, 0.5, 1.2)
	_add(tool, sign, Transform3D(Basis(), local + Vector3(-0.78, 2.0, 0.0)), Color(0.96, 0.94, 0.90))
	var coin := CylinderMesh.new()
	coin.top_radius = 0.14
	coin.bottom_radius = 0.14
	coin.height = 0.03
	coin.radial_segments = 12
	coin.rings = 1
	_add(tool, coin, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), local + Vector3(-0.82, 2.0, 0.38)), Color(0.96, 0.80, 0.24))
	for i in POOL_TICKET:
		var pip := SphereMesh.new()
		pip.radius = 0.045
		pip.height = 0.09
		pip.radial_segments = 6
		pip.rings = 3
		_add(tool, pip, Transform3D(Basis(), local + Vector3(-0.82, 2.0, 0.1 - float(i) * 0.14)), Color(0.14, 0.16, 0.15))
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.6, 2.4, 1.6)
	_collide(solid, shape, Transform3D(Basis(), local + Vector3(0.0, 1.2, 0.0)))

## Is a child at the turnstile, close enough to buy a ticket or to be let out?
func at_turnstile(at: Vector3) -> bool:
	if _turnstile == null:
		return false
	return Vector2(at.x - _turnstile.position.x, at.z - _turnstile.position.z).length() < TURNSTILE_REACH

## Is a child inside the pool's fence?
func inside_pool_fence(at: Vector3) -> bool:
	if not _spots.has(POOL):
		return false
	var spot: Vector3 = _spots[POOL]
	return absf(at.x - spot.x) < POOL_FENCE_X - 0.3 and absf(at.z - spot.z) < POOL_FENCE_Z - 0.3

## Let the turnstile turn for a while: paid for, or a child leaving.
func open_turnstile() -> void:
	_turnstile_open = TURNSTILE_OPEN
	if _turnstile != null:
		_turnstile.collision_layer = 0

func turnstile_open() -> bool:
	return _turnstile_open > 0.0

func _tick_turnstile(delta: float) -> void:
	if _turnstile_open <= 0.0:
		return
	_turnstile_open -= delta
	if _turnstile_arms != null:
		_turnstile_arms.rotation.y += delta * 2.4
	if _turnstile_open <= 0.0 and _turnstile != null:
		_turnstile.collision_layer = TerrainSpec.LAYER_PROPS

## How many solid pieces the pool has round it. For the checks.
func pool_solid_count() -> int:
	return 0 if _pool_solid == null else _pool_solid.get_child_count()

## The café, which a child can walk into. Twice the width and depth of the
## hut it replaced and a fifth taller: four walls with a door in the front
## and windows all round, a floor and a ceiling under a pitched roof; inside,
## a bar along the back with what is on offer laid out along it, shelves of
## jars behind, a menu board on the wall, three stools, three round tables
## with chairs, a sofa with cushions and a low table, three pendant lights,
## plants in the corners; outside, a striped awning and a sign over the door,
## two tables under umbrellas, flower pots, a menu board, two lamps that
## light at dusk, and a bin. Every wall and every piece of furniture is
## solid — the first café was a shed you could walk through — and every
## seat is a place a child can be sat at to eat.
func _build_cafe(at: Vector3) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var solid := StaticBody3D.new()
	solid.transform = Transform3D(Basis(), at)
	solid.collision_layer = TerrainSpec.LAYER_PROPS
	add_child(solid)
	_cafe_solid = solid
	# The walls and ceiling are on a layer the camera respects too, so that
	# turning round inside does not put the camera outside the building.
	var walls := StaticBody3D.new()
	walls.transform = Transform3D(Basis(), at)
	walls.collision_layer = TerrainSpec.LAYER_PROPS | TerrainSpec.LAYER_WALLS
	add_child(walls)
	_cafe_walls = walls
	_cafe_seats.clear()

	var wall := Color(0.92, 0.88, 0.78)
	var inner_wall := Color(0.96, 0.90, 0.80)
	var timber := Color(0.54, 0.38, 0.24)
	var boards := Color(0.66, 0.50, 0.32)
	var tiles := Color(0.62, 0.30, 0.24)
	var stripe_a := Color(0.88, 0.34, 0.30)
	var stripe_b := Color(0.96, 0.94, 0.90)
	var glass := Color(0.70, 0.84, 0.92)

	var w := CAFE_WIDTH
	var d := CAFE_DEPTH
	var h := CAFE_HEIGHT
	var mid := CAFE_MID_Z
	var front := mid - d * 0.5
	var back := mid + d * 0.5
	var thick := 0.2

	# --- The shell: walls with a door and windows, floor, ceiling, roof.
	_wall(tool, walls, Vector3(w, h, thick), Vector3(0.0, h * 0.5, back - thick * 0.5), wall)
	for side in PackedFloat32Array([-1.0, 1.0]):
		_wall(tool, walls, Vector3(thick, h, d), Vector3(side * (w * 0.5 - thick * 0.5), h * 0.5, mid), wall)
		for wz in PackedFloat32Array([mid - 1.9, mid + 1.5]):
			var pane := BoxMesh.new()
			pane.size = Vector3(0.06, 1.2, 1.6)
			_add(tool, pane, Transform3D(Basis(), Vector3(side * (w * 0.5 + 0.02), 1.9, wz)), glass)
			var sill := BoxMesh.new()
			sill.size = Vector3(0.14, 0.06, 1.8)
			_add(tool, sill, Transform3D(Basis(), Vector3(side * (w * 0.5 + 0.03), 1.28, wz)), timber)
		# The front wall, either side of the door, with a shop window.
		var segment_w := w * 0.5 - CAFE_DOOR_HALF
		var segment_x := side * (CAFE_DOOR_HALF + segment_w * 0.5)
		_wall(tool, walls, Vector3(segment_w, h, thick), Vector3(segment_x, h * 0.5, front + thick * 0.5), wall)
		var shop_window := BoxMesh.new()
		shop_window.size = Vector3(2.2, 1.4, 0.06)
		_add(tool, shop_window, Transform3D(Basis(), Vector3(side * 3.0, 1.85, front - 0.02)), glass)
		var frame := BoxMesh.new()
		frame.size = Vector3(2.4, 0.08, 0.12)
		_add(tool, frame, Transform3D(Basis(), Vector3(side * 3.0, 1.11, front - 0.02)), timber)
		var post := BoxMesh.new()
		post.size = Vector3(0.14, 2.55, 0.3)
		_add(tool, post, Transform3D(Basis(), Vector3(side * (CAFE_DOOR_HALF + 0.07), 1.275, front)), timber)
	_wall(tool, walls, Vector3(CAFE_DOOR_HALF * 2.0 + 0.3, h - 2.55, thick), Vector3(0.0, (2.55 + h) * 0.5, front + thick * 0.5), wall)
	var mat := BoxMesh.new()
	mat.size = Vector3(1.8, 0.03, 0.9)
	_add(tool, mat, Transform3D(Basis(), Vector3(0.0, 0.015, front - 0.5)), Color(0.36, 0.30, 0.24))
	var floor_slab := BoxMesh.new()
	floor_slab.size = Vector3(w - thick, 0.06, d - thick)
	_add(tool, floor_slab, Transform3D(Basis(), Vector3(0.0, 0.03, mid)), boards)
	var ceiling := BoxMesh.new()
	ceiling.size = Vector3(w, 0.08, d)
	_add(tool, ceiling, Transform3D(Basis(), Vector3(0.0, h - 0.04, mid)), inner_wall)
	# The ceiling stops the camera too, or looking down at the table lifts
	# it through the roof.
	var lid := BoxShape3D.new()
	lid.size = Vector3(w, 0.1, d)
	_collide(walls, lid, Transform3D(Basis(), Vector3(0.0, h - 0.04, mid)))
	var roof := PrismMesh.new()
	roof.size = Vector3(d + 0.9, 2.0, w + 0.9)
	_add(tool, roof, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.0, h + 1.0, mid)), tiles)
	var ridge := BoxMesh.new()
	ridge.size = Vector3(w + 1.0, 0.14, 0.24)
	_add(tool, ridge, Transform3D(Basis(), Vector3(0.0, h + 2.0, mid)), tiles.darkened(0.25))
	var chimney := BoxMesh.new()
	chimney.size = Vector3(0.5, 1.1, 0.5)
	_add(tool, chimney, Transform3D(Basis(), Vector3(3.4, h + 2.0, mid + 1.6)), Color(0.55, 0.42, 0.36))

	# The awning over the door, and the sign above it.
	for i in 7:
		var band := BoxMesh.new()
		band.size = Vector3(0.6, 0.07, 1.4)
		_add(tool, band, Transform3D(
			Basis(Vector3.RIGHT, deg_to_rad(-16.0)),
			Vector3(-1.8 + float(i) * 0.6, 2.75, front - 0.62)
		), stripe_a if i % 2 == 0 else stripe_b)
	var sign := BoxMesh.new()
	sign.size = Vector3(1.8, 0.66, 0.08)
	_add(tool, sign, Transform3D(Basis(), Vector3(0.0, h + 0.5, front - 0.4)), stripe_b)
	var sign_cup := CylinderMesh.new()
	sign_cup.top_radius = 0.17
	sign_cup.bottom_radius = 0.13
	sign_cup.height = 0.32
	sign_cup.radial_segments = 8
	sign_cup.rings = 1
	_add(tool, sign_cup, Transform3D(Basis(), Vector3(-0.1, h + 0.48, front - 0.46)), stripe_a)
	var sign_handle := TorusMesh.new()
	sign_handle.inner_radius = 0.06
	sign_handle.outer_radius = 0.12
	sign_handle.rings = 6
	sign_handle.ring_segments = 10
	_add(tool, sign_handle, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.16, h + 0.48, front - 0.46)), stripe_a)

	# --- Inside: the bar along the back wall, and what is on it.
	var bar_x := 1.0
	var bar_z := back - thick - 0.9
	var bar := BoxMesh.new()
	bar.size = Vector3(6.0, 0.16, 0.9)
	_add(tool, bar, Transform3D(Basis(), Vector3(bar_x, 1.02, bar_z)), timber)
	var panel := BoxMesh.new()
	panel.size = Vector3(6.0, 0.96, 0.12)
	_add(tool, panel, Transform3D(Basis(), Vector3(bar_x, 0.48, bar_z - 0.39)), timber.darkened(0.15))
	var bar_shape := BoxShape3D.new()
	bar_shape.size = Vector3(6.0, 1.15, 1.0)
	_collide(solid, bar_shape, Transform3D(Basis(), Vector3(bar_x, 0.575, bar_z)))
	_lay_the_counter(tool, Vector3(bar_x, 1.1, bar_z))
	# Shelves of jars and cups behind it, and the menu board above them.
	var jar_colours: Array[Color] = [
		Color(0.86, 0.36, 0.30), Color(0.96, 0.78, 0.24), Color(0.38, 0.62, 0.86),
		Color(0.46, 0.74, 0.40), Color(0.92, 0.92, 0.88), Color(0.70, 0.46, 0.72),
	]
	for level in 2:
		var shelf := BoxMesh.new()
		shelf.size = Vector3(5.6, 0.06, 0.34)
		var shelf_y := 1.55 + float(level) * 0.55
		_add(tool, shelf, Transform3D(Basis(), Vector3(bar_x, shelf_y, back - thick - 0.17)), timber)
		for i in 7:
			var jar := CylinderMesh.new()
			jar.top_radius = 0.1 if level == 0 else 0.06
			jar.bottom_radius = jar.top_radius
			jar.height = 0.26 if level == 0 else 0.12
			jar.radial_segments = 8
			jar.rings = 1
			_add(tool, jar, Transform3D(Basis(), Vector3(bar_x - 2.4 + float(i) * 0.8, shelf_y + 0.03 + jar.height * 0.5, back - thick - 0.17)), jar_colours[(i + level) % jar_colours.size()])
	_build_menu_board_on_wall(tool, Vector3(bar_x - 0.4, 2.85, back - thick - 0.03))
	for x in PackedFloat32Array([-0.5, 1.0, 2.5]):
		var stool_at := Vector3(x, 0.0, bar_z - 1.15)
		var stool := CylinderMesh.new()
		stool.top_radius = 0.24
		stool.bottom_radius = 0.20
		stool.height = 0.62
		stool.radial_segments = 8
		stool.rings = 1
		_add(tool, stool, Transform3D(Basis(), stool_at + Vector3(0.0, 0.31, 0.0)), timber)
		var stool_shape := CylinderShape3D.new()
		stool_shape.radius = 0.24
		stool_shape.height = 0.62
		_collide(solid, stool_shape, Transform3D(Basis(), stool_at + Vector3(0.0, 0.31, 0.0)))
		# Facing the bar (+Z): a body faces -Z at rotation 0, so PI.
		_cafe_seats.append({"seat": stool_at + Vector3(0.0, 0.62, 0.0), "table": Vector3(x, 1.1, bar_z - 0.3), "facing": PI})

	# Tables and chairs inside, and the sofa corner.
	for table_at in CAFE_TABLES:
		_build_table(tool, table_at, Color.WHITE, solid, false)
	_build_sofa(tool, Vector3(4.55, 0.0, 2.9), solid)
	for pot_at: Vector3 in [Vector3(-4.6, 0.0, back - 0.7), Vector3(4.6, 0.0, front + 0.7)]:
		_build_pot(tool, pot_at)
	for light_at: Vector3 in [Vector3(-3.2, 0.0, 1.1), Vector3(bar_x, 0.0, bar_z - 0.6), Vector3(3.2, 0.0, 0.6)]:
		_hang_light(tool, at, light_at)

	# --- Outside: the terrace.
	var canopies: Array[Color] = [stripe_a, Color(0.30, 0.52, 0.86)]
	for i in CAFE_TERRACE.size():
		_build_table(tool, CAFE_TERRACE[i], canopies[i % canopies.size()], solid, true)
	for pot_at: Vector3 in [Vector3(-1.5, 0.0, front - 0.6), Vector3(1.5, 0.0, front - 0.6), Vector3(-5.6, 0.0, front - 0.8), Vector3(5.6, 0.0, front - 0.8)]:
		_build_pot(tool, pot_at)
	_build_menu_board(tool, Vector3(2.6, 0.0, front - 1.6), solid)
	for lamp_at in CAFE_LAMPS:
		_build_lamp(tool, at, lamp_at, solid, 0.16)
	_build_bin(at, Vector3(-6.6, 0.0, front - 1.6), solid)
	_finish_into(tool, at)

## One wall: drawn and solid.
func _wall(tool: SurfaceTool, solid: StaticBody3D, size: Vector3, centre: Vector3, colour: Color) -> void:
	var slab := BoxMesh.new()
	slab.size = size
	_add(tool, slab, Transform3D(Basis(), centre), colour)
	var shape := BoxShape3D.new()
	shape.size = size
	_collide(solid, shape, Transform3D(Basis(), centre))

## What is on offer, laid along the bar: a cake on a stand, a bun on a plate,
## a teapot with two cups, a coffee on a saucer, a jug of water and glasses.
## The café said "tasty" and showed nothing; this is what a child sees before
## deciding to spend three coins.
func _lay_the_counter(tool: SurfaceTool, on: Vector3) -> void:
	var china := Color(0.96, 0.96, 0.94)
	var cream := Color(0.98, 0.92, 0.80)
	var crust := Color(0.72, 0.48, 0.26)
	var tea := Color(0.62, 0.40, 0.18)
	var coffee := Color(0.30, 0.18, 0.10)
	var water := Color(0.62, 0.80, 0.92)
	var teapot_blue := Color(0.30, 0.50, 0.82)

	var stand := CylinderMesh.new()
	stand.top_radius = 0.24
	stand.bottom_radius = 0.06
	stand.height = 0.12
	stand.radial_segments = 10
	stand.rings = 1
	_add(tool, stand, Transform3D(Basis(), on + Vector3(-2.2, 0.06, 0.0)), china)
	var cake := CylinderMesh.new()
	cake.top_radius = 0.19
	cake.bottom_radius = 0.19
	cake.height = 0.14
	cake.radial_segments = 12
	cake.rings = 1
	_add(tool, cake, Transform3D(Basis(), on + Vector3(-2.2, 0.19, 0.0)), cream)
	var icing := CylinderMesh.new()
	icing.top_radius = 0.2
	icing.bottom_radius = 0.2
	icing.height = 0.03
	icing.radial_segments = 12
	icing.rings = 1
	_add(tool, icing, Transform3D(Basis(), on + Vector3(-2.2, 0.275, 0.0)), Color(0.90, 0.40, 0.48))
	var cherry := SphereMesh.new()
	cherry.radius = 0.035
	cherry.height = 0.07
	cherry.radial_segments = 6
	cherry.rings = 3
	_add(tool, cherry, Transform3D(Basis(), on + Vector3(-2.2, 0.32, 0.0)), Color(0.80, 0.12, 0.14))

	var plate := CylinderMesh.new()
	plate.top_radius = 0.17
	plate.bottom_radius = 0.14
	plate.height = 0.02
	plate.radial_segments = 12
	plate.rings = 1
	_add(tool, plate, Transform3D(Basis(), on + Vector3(-1.3, 0.01, 0.0)), china)
	var bun := SphereMesh.new()
	bun.radius = 0.11
	bun.height = 0.14
	bun.radial_segments = 8
	bun.rings = 4
	_add(tool, bun, Transform3D(Basis(), on + Vector3(-1.3, 0.08, 0.0)), crust)

	var pot := SphereMesh.new()
	pot.radius = 0.16
	pot.height = 0.26
	pot.radial_segments = 10
	pot.rings = 5
	_add(tool, pot, Transform3D(Basis(), on + Vector3(-0.3, 0.14, 0.05)), teapot_blue)
	var spout := CylinderMesh.new()
	spout.top_radius = 0.02
	spout.bottom_radius = 0.035
	spout.height = 0.22
	spout.radial_segments = 6
	spout.rings = 1
	_add(tool, spout, Transform3D(Basis(Vector3.FORWARD, deg_to_rad(-50.0)), on + Vector3(-0.48, 0.2, 0.05)), teapot_blue)
	var knob := SphereMesh.new()
	knob.radius = 0.03
	knob.height = 0.06
	knob.radial_segments = 6
	knob.rings = 3
	_add(tool, knob, Transform3D(Basis(), on + Vector3(-0.3, 0.29, 0.05)), teapot_blue)
	for dx in PackedFloat32Array([0.1, 0.36]):
		_add_cup(tool, on + Vector3(dx, 0.0, -0.15), 0.055, 0.075, china, tea)

	var saucer := CylinderMesh.new()
	saucer.top_radius = 0.1
	saucer.bottom_radius = 0.08
	saucer.height = 0.015
	saucer.radial_segments = 10
	saucer.rings = 1
	_add(tool, saucer, Transform3D(Basis(), on + Vector3(0.9, 0.01, 0.0)), china)
	_add_cup(tool, on + Vector3(0.9, 0.015, 0.0), 0.05, 0.1, china, coffee)

	var jug := CylinderMesh.new()
	jug.top_radius = 0.09
	jug.bottom_radius = 0.11
	jug.height = 0.3
	jug.radial_segments = 10
	jug.rings = 1
	_add(tool, jug, Transform3D(Basis(), on + Vector3(1.6, 0.15, 0.05)), water)
	var jug_handle := TorusMesh.new()
	jug_handle.inner_radius = 0.04
	jug_handle.outer_radius = 0.07
	jug_handle.rings = 6
	jug_handle.ring_segments = 8
	_add(tool, jug_handle, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), on + Vector3(1.73, 0.18, 0.05)), water)
	for dx in PackedFloat32Array([2.0, 2.25]):
		var tumbler := CylinderMesh.new()
		tumbler.top_radius = 0.045
		tumbler.bottom_radius = 0.04
		tumbler.height = 0.12
		tumbler.radial_segments = 8
		tumbler.rings = 1
		_add(tool, tumbler, Transform3D(Basis(), on + Vector3(dx, 0.06, -0.12)), water)

## A cup with a handle and something in it.
func _add_cup(tool: SurfaceTool, at: Vector3, radius: float, height: float, china: Color, drink: Color) -> void:
	var cup := CylinderMesh.new()
	cup.top_radius = radius
	cup.bottom_radius = radius * 0.8
	cup.height = height
	cup.radial_segments = 8
	cup.rings = 1
	_add(tool, cup, Transform3D(Basis(), at + Vector3(0.0, height * 0.5, 0.0)), china)
	var drink_top := CylinderMesh.new()
	drink_top.top_radius = radius * 0.85
	drink_top.bottom_radius = radius * 0.85
	drink_top.height = 0.01
	drink_top.radial_segments = 8
	drink_top.rings = 1
	_add(tool, drink_top, Transform3D(Basis(), at + Vector3(0.0, height - 0.005, 0.0)), drink)
	var handle := TorusMesh.new()
	handle.inner_radius = radius * 0.35
	handle.outer_radius = radius * 0.6
	handle.rings = 5
	handle.ring_segments = 8
	_add(tool, handle, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), at + Vector3(radius * 1.05, height * 0.5, 0.0)), china)

## A round table with a chair either side, all solid, and — outside — an
## umbrella over it. Each chair is a seat a child can be sat at.
func _build_table(tool: SurfaceTool, local: Vector3, canopy: Color, solid: StaticBody3D, umbrella: bool) -> void:
	var timber := Color(0.54, 0.38, 0.24)
	var iron := Color(0.20, 0.21, 0.23)
	var top := CylinderMesh.new()
	top.top_radius = 0.6
	top.bottom_radius = 0.6
	top.height = 0.05
	top.radial_segments = 14
	top.rings = 1
	_add(tool, top, Transform3D(Basis(), local + Vector3(0.0, 0.75, 0.0)), timber)
	var stem := CylinderMesh.new()
	stem.top_radius = 0.04
	stem.bottom_radius = 0.04
	stem.height = 2.4 if umbrella else 0.72
	stem.radial_segments = 6
	stem.rings = 1
	_add(tool, stem, Transform3D(Basis(), local + Vector3(0.0, stem.height * 0.5, 0.0)), iron)
	var foot := CylinderMesh.new()
	foot.top_radius = 0.25
	foot.bottom_radius = 0.3
	foot.height = 0.05
	foot.radial_segments = 10
	foot.rings = 1
	_add(tool, foot, Transform3D(Basis(), local + Vector3(0.0, 0.025, 0.0)), iron)
	if umbrella:
		var shade := CylinderMesh.new()
		shade.top_radius = 0.0
		shade.bottom_radius = 1.35
		shade.height = 0.5
		shade.radial_segments = 8
		shade.rings = 1
		_add(tool, shade, Transform3D(Basis(), local + Vector3(0.0, 2.25, 0.0)), canopy)
	var table_shape := CylinderShape3D.new()
	table_shape.radius = 0.6
	table_shape.height = 0.8
	_collide(solid, table_shape, Transform3D(Basis(), local + Vector3(0.0, 0.4, 0.0)))
	for side in PackedFloat32Array([-1.0, 1.0]):
		var seat_at := local + Vector3(side * 1.05, 0.0, 0.0)
		var seat := BoxMesh.new()
		seat.size = Vector3(0.42, 0.05, 0.42)
		_add(tool, seat, Transform3D(Basis(), seat_at + Vector3(0.0, 0.45, 0.0)), timber)
		var back := BoxMesh.new()
		back.size = Vector3(0.05, 0.45, 0.42)
		_add(tool, back, Transform3D(Basis(), seat_at + Vector3(side * 0.19, 0.7, 0.0)), timber)
		for dx in PackedFloat32Array([-0.17, 0.17]):
			for dz in PackedFloat32Array([-0.17, 0.17]):
				var leg := BoxMesh.new()
				leg.size = Vector3(0.04, 0.45, 0.04)
				_add(tool, leg, Transform3D(Basis(), seat_at + Vector3(dx, 0.225, dz)), iron)
		var chair_shape := BoxShape3D.new()
		chair_shape.size = Vector3(0.45, 0.95, 0.45)
		_collide(solid, chair_shape, Transform3D(Basis(), seat_at + Vector3(0.0, 0.475, 0.0)))
		# Facing the table: from +X the body looks along -X, which is rotation
		# atan2(-(-1), 0) = +PI/2; from -X, -PI/2.
		_cafe_seats.append({
			"seat": seat_at + Vector3(0.0, 0.45, 0.0),
			"table": local + Vector3(side * 0.42, 0.78, 0.0),
			"facing": side * PI * 0.5,
		})

## A sofa against the wall, facing -X, with cushions and a low table in front
## of it. Two seats.
func _build_sofa(tool: SurfaceTool, local: Vector3, solid: StaticBody3D) -> void:
	var fabric := Color(0.22, 0.42, 0.46)
	var cushion_a := Color(0.92, 0.72, 0.30)
	var cushion_b := Color(0.86, 0.40, 0.36)
	var timber := Color(0.54, 0.38, 0.24)
	var seat := BoxMesh.new()
	seat.size = Vector3(0.8, 0.42, 3.0)
	_add(tool, seat, Transform3D(Basis(), local + Vector3(0.0, 0.21, 0.0)), fabric)
	var back := BoxMesh.new()
	back.size = Vector3(0.22, 0.95, 3.0)
	_add(tool, back, Transform3D(Basis(), local + Vector3(0.36, 0.475, 0.0)), fabric)
	for dz in PackedFloat32Array([-1.55, 1.55]):
		var arm := BoxMesh.new()
		arm.size = Vector3(0.8, 0.58, 0.2)
		_add(tool, arm, Transform3D(Basis(), local + Vector3(0.0, 0.29, dz)), fabric.darkened(0.15))
	for i in 3:
		var cushion := BoxMesh.new()
		cushion.size = Vector3(0.24, 0.42, 0.7)
		_add(tool, cushion, Transform3D(Basis(Vector3.FORWARD, deg_to_rad(-8.0)), local + Vector3(0.2, 0.68, -1.0 + float(i) * 1.0)), cushion_a if i % 2 == 0 else cushion_b)
	var sofa_shape := BoxShape3D.new()
	sofa_shape.size = Vector3(0.95, 1.1, 3.4)
	_collide(solid, sofa_shape, Transform3D(Basis(), local + Vector3(0.1, 0.55, 0.0)))
	# The low table in front, with a little vase.
	var table_at := local + Vector3(-1.1, 0.0, 0.0)
	var top := BoxMesh.new()
	top.size = Vector3(0.9, 0.05, 1.8)
	_add(tool, top, Transform3D(Basis(), table_at + Vector3(0.0, 0.475, 0.0)), timber)
	for dx in PackedFloat32Array([-0.38, 0.38]):
		for dz in PackedFloat32Array([-0.82, 0.82]):
			var leg := BoxMesh.new()
			leg.size = Vector3(0.06, 0.45, 0.06)
			_add(tool, leg, Transform3D(Basis(), table_at + Vector3(dx, 0.225, dz)), timber)
	var vase := CylinderMesh.new()
	vase.top_radius = 0.05
	vase.bottom_radius = 0.08
	vase.height = 0.2
	vase.radial_segments = 8
	vase.rings = 1
	_add(tool, vase, Transform3D(Basis(), table_at + Vector3(0.0, 0.6, 0.0)), Color(0.30, 0.50, 0.82))
	var flower := SphereMesh.new()
	flower.radius = 0.06
	flower.height = 0.12
	flower.radial_segments = 6
	flower.rings = 3
	_add(tool, flower, Transform3D(Basis(), table_at + Vector3(0.0, 0.76, 0.0)), Color(0.92, 0.30, 0.34))
	var table_shape := BoxShape3D.new()
	table_shape.size = Vector3(0.9, 0.5, 1.8)
	_collide(solid, table_shape, Transform3D(Basis(), table_at + Vector3(0.0, 0.25, 0.0)))
	for dz in PackedFloat32Array([-0.75, 0.75]):
		_cafe_seats.append({
			"seat": local + Vector3(0.0, 0.42, dz),
			"table": table_at + Vector3(0.3, 0.5, dz),
			"facing": PI * 0.5,
		})

## A pendant light: a cord from the ceiling, a shade, a bulb that glows and
## a warm light under it, always on — a café is lit.
func _hang_light(tool: SurfaceTool, at: Vector3, local: Vector3) -> void:
	var iron := Color(0.20, 0.21, 0.23)
	var cord := CylinderMesh.new()
	cord.top_radius = 0.012
	cord.bottom_radius = 0.012
	cord.height = 0.6
	cord.radial_segments = 4
	cord.rings = 1
	_add(tool, cord, Transform3D(Basis(), local + Vector3(0.0, CAFE_HEIGHT - 0.38, 0.0)), iron)
	var shade := CylinderMesh.new()
	shade.top_radius = 0.06
	shade.bottom_radius = 0.32
	shade.height = 0.26
	shade.radial_segments = 10
	shade.rings = 1
	_add(tool, shade, Transform3D(Basis(), local + Vector3(0.0, CAFE_HEIGHT - 0.8, 0.0)), Color(0.86, 0.34, 0.30))
	var bulb := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.07
	ball.height = 0.14
	ball.radial_segments = 8
	ball.rings = 4
	bulb.mesh = ball
	var glow := StandardMaterial3D.new()
	glow.albedo_color = LAMP_COLOUR
	glow.emission_enabled = true
	glow.emission = LAMP_COLOUR
	glow.emission_energy_multiplier = 1.6
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bulb.material_override = glow
	bulb.position = at + local + Vector3(0.0, CAFE_HEIGHT - 0.92, 0.0)
	add_child(bulb)
	var light := OmniLight3D.new()
	light.omni_range = 7.0
	light.light_color = LAMP_COLOUR
	light.light_energy = 0.9
	light.shadow_enabled = false
	light.position = at + local + Vector3(0.0, CAFE_HEIGHT - 1.0, 0.0)
	add_child(light)

## A terracotta pot with a bush of flowers in it.
func _build_pot(tool: SurfaceTool, local: Vector3) -> void:
	var pot := CylinderMesh.new()
	pot.top_radius = 0.24
	pot.bottom_radius = 0.18
	pot.height = 0.32
	pot.radial_segments = 10
	pot.rings = 1
	_add(tool, pot, Transform3D(Basis(), local + Vector3(0.0, 0.16, 0.0)), Color(0.72, 0.42, 0.30))
	var bush := SphereMesh.new()
	bush.radius = 0.28
	bush.height = 0.44
	bush.radial_segments = 8
	bush.rings = 4
	_add(tool, bush, Transform3D(Basis(), local + Vector3(0.0, 0.46, 0.0)), Color(0.30, 0.56, 0.26))
	var blooms: Array[Color] = [Color(0.92, 0.30, 0.34), Color(0.98, 0.80, 0.26), Color(0.92, 0.92, 0.96), Color(0.72, 0.42, 0.84)]
	for i in 5:
		var angle := TAU * float(i) / 5.0
		var bloom := SphereMesh.new()
		bloom.radius = 0.05
		bloom.height = 0.1
		bloom.radial_segments = 5
		bloom.rings = 3
		_add(tool, bloom, Transform3D(Basis(), local + Vector3(cos(angle) * 0.2, 0.6 + 0.04 * float(i % 2), sin(angle) * 0.2)), blooms[i % blooms.size()])

## A chalkboard on an easel, with three pale lines of "writing", solid.
func _build_menu_board(tool: SurfaceTool, local: Vector3, solid: StaticBody3D) -> void:
	var timber := Color(0.54, 0.38, 0.24)
	var lean := Basis(Vector3.RIGHT, deg_to_rad(12.0))
	var board := BoxMesh.new()
	board.size = Vector3(0.7, 0.9, 0.05)
	_add(tool, board, Transform3D(lean, local + Vector3(0.0, 0.7, 0.0)), Color(0.14, 0.16, 0.15))
	var frame := BoxMesh.new()
	frame.size = Vector3(0.78, 0.98, 0.04)
	_add(tool, frame, Transform3D(lean, local + Vector3(0.0, 0.7, 0.01)), timber)
	for i in 3:
		var line := BoxMesh.new()
		line.size = Vector3(0.44 - float(i) * 0.08, 0.04, 0.01)
		_add(tool, line, Transform3D(lean, lean * Vector3(-0.06 + float(i) * 0.03, 0.9 - float(i) * 0.2, -0.03) + local), Color(0.94, 0.94, 0.90))
	for side in PackedFloat32Array([-1.0, 1.0]):
		var leg := BoxMesh.new()
		leg.size = Vector3(0.04, 1.2, 0.04)
		_add(tool, leg, Transform3D(lean, local + Vector3(side * 0.34, 0.6, -0.02)), timber)
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.8, 1.2, 0.4)
	_collide(solid, shape, Transform3D(Basis(), local + Vector3(0.0, 0.6, 0.0)))

## The menu on the wall behind the bar: a board with lines of writing and a
## little picture beside each — a cup, a cake, a bun, a glass — because the
## reader is six.
func _build_menu_board_on_wall(tool: SurfaceTool, centre: Vector3) -> void:
	var board := BoxMesh.new()
	board.size = Vector3(3.2, 1.1, 0.05)
	_add(tool, board, Transform3D(Basis(), centre), Color(0.14, 0.16, 0.15))
	var frame := BoxMesh.new()
	frame.size = Vector3(3.3, 1.2, 0.03)
	_add(tool, frame, Transform3D(Basis(), centre + Vector3(0.0, 0.0, 0.01)), Color(0.54, 0.38, 0.24))
	var pictures: Array[Color] = [Color(0.62, 0.40, 0.18), Color(0.90, 0.40, 0.48), Color(0.72, 0.48, 0.26), Color(0.62, 0.80, 0.92)]
	for i in 4:
		var y := centre.y + 0.36 - float(i) * 0.24
		var picture := SphereMesh.new()
		picture.radius = 0.07
		picture.height = 0.14
		picture.radial_segments = 6
		picture.rings = 3
		_add(tool, picture, Transform3D(Basis(), Vector3(centre.x - 1.3, y, centre.z - 0.05)), pictures[i])
		var line := BoxMesh.new()
		line.size = Vector3(1.4 - float(i) * 0.15, 0.05, 0.01)
		_add(tool, line, Transform3D(Basis(), Vector3(centre.x - 0.3, y, centre.z - 0.035)), Color(0.94, 0.94, 0.90))
		var price := BoxMesh.new()
		price.size = Vector3(0.3, 0.05, 0.01)
		_add(tool, price, Transform3D(Basis(), Vector3(centre.x + 1.15, y, centre.z - 0.035)), Color(0.96, 0.82, 0.30))

## Put a meal in front of whoever ordered it: the nearest seat within reach is
## theirs, and the tray — a plate of food, a steaming cup and a glass of water
## — goes on that seat's table. Returns the seat, with which way to face, so
## the game can sit the child down; empty if no seat is near, in which case
## the tray goes on the bar. The tray sits there for a while and is cleared.
## Before this, three coins bought a number and a word.
func serve_meal(near: Vector3) -> Dictionary:
	if not _spots.has(CAFE):
		return {}
	var spot: Vector3 = _spots[CAFE]
	var chosen: Dictionary = {}
	var best := CAFE_SEAT_REACH
	for seat in _cafe_seats:
		var world_seat: Vector3 = spot + seat["seat"]
		var distance := Vector2(world_seat.x - near.x, world_seat.z - near.z).length()
		if distance < best:
			best = distance
			chosen = seat
	var on: Vector3
	if chosen.is_empty():
		on = spot + Vector3(clampf(near.x - spot.x - 1.0, -2.6, 2.6) + 1.0, 1.1, CAFE_MID_Z + CAFE_DEPTH * 0.5 - 0.2 - 0.9 - 0.3)
	else:
		on = spot + chosen["table"]
	_place_tray(on)
	if chosen.is_empty():
		return {}
	return {"seat": spot + chosen["seat"], "facing": float(chosen["facing"])}

func _place_tray(on: Vector3) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var china := Color(0.96, 0.96, 0.94)
	var tray := BoxMesh.new()
	tray.size = Vector3(0.7, 0.03, 0.42)
	_add(tool, tray, Transform3D(Basis(), Vector3(0.0, 0.015, 0.0)), Color(0.54, 0.38, 0.24))
	var plate := CylinderMesh.new()
	plate.top_radius = 0.15
	plate.bottom_radius = 0.12
	plate.height = 0.02
	plate.radial_segments = 12
	plate.rings = 1
	_add(tool, plate, Transform3D(Basis(), Vector3(-0.17, 0.04, 0.0)), china)
	# The food: a sandwich — two slices with green between — and two tomatoes.
	for layer in 2:
		var bread := BoxMesh.new()
		bread.size = Vector3(0.18, 0.035, 0.18)
		_add(tool, bread, Transform3D(Basis(Vector3.UP, 0.3), Vector3(-0.17, 0.065 + float(layer) * 0.06, 0.0)), Color(0.86, 0.68, 0.40))
	var leaf := BoxMesh.new()
	leaf.size = Vector3(0.22, 0.02, 0.22)
	_add(tool, leaf, Transform3D(Basis(Vector3.UP, 0.3), Vector3(-0.17, 0.095, 0.0)), Color(0.40, 0.70, 0.30))
	for i in 2:
		var tomato := SphereMesh.new()
		tomato.radius = 0.03
		tomato.height = 0.06
		tomato.radial_segments = 6
		tomato.rings = 3
		_add(tool, tomato, Transform3D(Basis(), Vector3(-0.02 + float(i) * 0.07, 0.06, 0.1)), Color(0.88, 0.22, 0.18))
	_add_cup(tool, Vector3(0.12, 0.03, -0.08), 0.055, 0.075, china, Color(0.62, 0.40, 0.18))
	var tumbler := CylinderMesh.new()
	tumbler.top_radius = 0.045
	tumbler.bottom_radius = 0.04
	tumbler.height = 0.12
	tumbler.radial_segments = 8
	tumbler.rings = 1
	_add(tool, tumbler, Transform3D(Basis(), Vector3(0.27, 0.09, 0.08)), Color(0.62, 0.80, 0.92))
	tool.generate_normals()
	tool.set_material(_material())
	var meal := MeshInstance3D.new()
	meal.mesh = tool.commit()
	meal.transform = Transform3D(Basis(), on)
	add_child(meal)
	# Three puffs of steam over the cup, moved each frame.
	var puffs: Array[MeshInstance3D] = []
	for i in 3:
		var puff := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.03
		ball.height = 0.06
		ball.radial_segments = 6
		ball.rings = 3
		puff.mesh = ball
		var mist := StandardMaterial3D.new()
		mist.albedo_color = Color(1.0, 1.0, 1.0, 0.55)
		mist.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mist.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		puff.material_override = mist
		meal.add_child(puff)
		puff.position = Vector3(0.12, 0.12 + float(i) * 0.06, -0.08)
		puffs.append(puff)
	_meals.append({"node": meal, "puffs": puffs, "left": MEAL_SHOWN, "age": 0.0})

## How many meals are on the tables right now, and how many seats there are.
## For the checks.
func meals_served() -> int:
	return _meals.size()

func cafe_seat_count() -> int:
	return _cafe_seats.size()

func cafe_solid_count() -> int:
	var count := 0 if _cafe_solid == null else _cafe_solid.get_child_count()
	if _cafe_walls != null:
		count += _cafe_walls.get_child_count()
	return count

## How many of the café's solids also stop the camera. For the checks.
func cafe_wall_count() -> int:
	return 0 if _cafe_walls == null else _cafe_walls.get_child_count()

func _tick_meals(delta: float) -> void:
	for i in range(_meals.size() - 1, -1, -1):
		var meal: Dictionary = _meals[i]
		var node: Node3D = meal["node"]
		meal["left"] = float(meal["left"]) - delta
		meal["age"] = float(meal["age"]) + delta
		if float(meal["left"]) <= 0.0 or not is_instance_valid(node):
			if is_instance_valid(node):
				node.queue_free()
			_meals.remove_at(i)
			continue
		var age := float(meal["age"])
		var puffs: Array[MeshInstance3D] = meal["puffs"]
		for k in puffs.size():
			var puff := puffs[k]
			var phase := fmod(age * 0.6 + float(k) * 0.33, 1.0)
			puff.position = Vector3(0.12 + sin(age * 3.0 + float(k)) * 0.02, 0.12 + phase * 0.3, -0.08)
			puff.scale = Vector3.ONE * (0.6 + phase * 0.8) * (1.0 - phase * 0.7)
		# Cleared away over the last second.
		var left := float(meal["left"])
		if left < 1.0:
			node.scale = Vector3.ONE * maxf(left, 0.01)

## The café's circles, for the animals: the building, the terrace tables, the
## lamps, the board and the bin. Animals stay outside.
func _note_cafe_obstacles(at: Vector3) -> void:
	var circles: Array[Vector3] = [
		Vector3(0.0, 6.6, CAFE_MID_Z),
		Vector3(2.6, 0.6, CAFE_MID_Z - CAFE_DEPTH * 0.5 - 1.6), Vector3(-6.6, 0.5, CAFE_MID_Z - CAFE_DEPTH * 0.5 - 1.6),
	]
	for table in CAFE_TERRACE:
		circles.append(Vector3(table.x, 1.8, table.z))
	for lamp in CAFE_LAMPS:
		circles.append(Vector3(lamp.x, 0.45, lamp.z))
	_obstacles.append(_obstacle_group(at, circles))

## One material for every place, vertex-coloured and shipped with the mesh so
## nothing can attach the geometry without it — see LESSONS.md.
## The basketball nearest a child, within kicking reach, or null. Mirrors the
## football ground's version so the same kick serves both.
func ball_near(from: Vector3) -> Ball:
	var best: Ball = null
	var best_distance := Ball.KICK_REACH + Ball.RADIUS
	for ball in _balls:
		var offset := ball.position - from
		offset.y = 0.0
		if offset.length() <= best_distance:
			best_distance = offset.length()
			best = ball
	return best

func ball_count() -> int:
	return _balls.size()

func has_hoop() -> bool:
	return _has_hoop

func flower_bed_count() -> int:
	return _flower_beds

## Where the ring is, in the world: what a thrown ball is aimed at.
func ring_position() -> Vector3:
	if not _spots.has(PLAYGROUND):
		return Vector3.ZERO
	return _spots[PLAYGROUND] + HOOP + Vector3(HOOP_REACH, HOOP_HEIGHT, 0.0)

## Is a ball here close enough to the ring to be thrown at it rather than
## kicked along the ground?
func hoop_in_range(from: Vector3) -> bool:
	if not _has_hoop or not _spots.has(PLAYGROUND):
		return false
	var ring := ring_position()
	return Vector2(from.x - ring.x, from.z - ring.z).length() < Ball.THROW_RANGE

## Does the fountain actually run? True once its jet exists. For the checks.
func fountain_plays() -> bool:
	return _jet != null

func hedge_segment_count() -> int:
	return _hedge_segments

func lamp_count() -> int:
	return _lamps.size()

## How many lamps are giving light right now.
func lamps_lit() -> int:
	var count := 0
	for lamp in _lamps:
		if (lamp["light"] as OmniLight3D).visible:
			count += 1
	return count

## Called every frame with how dark it is; the lamps decide for themselves,
## the way the child's lantern does. Each has its own threshold, so dusk
## lights them one by one, and each fades up over a couple of seconds rather
## than snapping on.
func light_lamps(darkness: float, delta: float) -> void:
	for i in _lamps.size():
		var lamp: Dictionary = _lamps[i]
		var threshold := float(lamp["threshold"])
		var lit := move_toward(float(lamp["lit"]), 1.0 if darkness > threshold else 0.0, delta / LAMP_FADE)
		lamp["lit"] = lit
		var strength := lit * smoothstep(threshold, threshold + 0.3, darkness)
		# The faintest slow breathing. Electric light is steady, but a value
		# that never changes at all reads as painted on.
		var breathe := 1.0 + 0.025 * sin(_wind_time * 2.3 + float(i) * 2.1)
		var light: OmniLight3D = lamp["light"]
		light.light_energy = float(lamp.get("energy", LAMP_ENERGY)) * strength * breathe
		# Switched off outright when dark enough not to matter: an omni light
		# at zero energy still costs the phone its share of the frame.
		light.visible = strength > 0.01
		(lamp["glass"] as MeshInstance3D).visible = strength > 0.05

## Is a child standing on the trampoline's mat?
func on_trampoline(at: Vector3) -> bool:
	if not _spots.has(PLAYGROUND):
		return false
	var mat: Vector3 = _spots[PLAYGROUND] + TRAMPOLINE
	var flat := Vector2(at.x - mat.x, at.z - mat.z).length()
	# The player's origin is at its feet — the capsule is lifted half its own
	# height above it — so standing on the mat puts the origin at the mat's top.
	# The first version added the capsule's half-height here, expecting the
	# origin in the middle of the body, and the trampoline never bounced anyone.
	return flat < TRAMPOLINE_RADIUS and absf(at.y - (mat.y + TRAMPOLINE_TOP)) < 0.6

## Is a child close enough to the fountain to fill a bottle?
func at_fountain(at: Vector3) -> bool:
	if not _spots.has(PLAYGROUND):
		return false
	var spout: Vector3 = _spots[PLAYGROUND] + FOUNTAIN
	return Vector2(at.x - spout.x, at.z - spout.z).length() < FOUNTAIN_REACH

## A ball that drops through the ring scores; a ball that rolls off into the
## trees comes back to where it started.
func _watch_balls() -> void:
	if not _spots.has(PLAYGROUND):
		return
	var ring := ring_position()
	for i in _balls.size():
		var ball := _balls[i]
		var now := ball.position.y
		var before := _ball_heights[i]
		_ball_heights[i] = now
		var flat := Vector2(ball.position.x - ring.x, ball.position.z - ring.z).length()
		if flat < HOOP_RING and before > ring.y and now <= ring.y:
			baskets += 1
			basket.emit(baskets)
		var home_distance := Vector2(ball.position.x - ball.home.x, ball.position.z - ball.home.z).length()
		if home_distance > 28.0 and ball.at_rest():
			ball.reset_to(ball.home)

## A round trampoline: a frame on legs and a dark mat stretched across it. The
## mat is solid to stand on; the bounce is the game's business.
func _build_trampoline(at: Vector3, solid: StaticBody3D) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var frame_colour := Color(0.20, 0.32, 0.62)
	var frame := TorusMesh.new()
	frame.inner_radius = TRAMPOLINE_RADIUS - 0.08
	frame.outer_radius = TRAMPOLINE_RADIUS + 0.06
	frame.rings = 8
	frame.ring_segments = 28
	_add(tool, frame, Transform3D(Basis(), TRAMPOLINE + Vector3(0.0, TRAMPOLINE_TOP, 0.0)), frame_colour)
	for i in 12:
		var angle := TAU * float(i) / 12.0
		var leg := CylinderMesh.new()
		leg.top_radius = 0.04
		leg.bottom_radius = 0.045
		leg.height = TRAMPOLINE_TOP
		leg.radial_segments = 6
		leg.rings = 1
		_add(tool, leg, Transform3D(Basis(),
			TRAMPOLINE + Vector3(cos(angle) * TRAMPOLINE_RADIUS, TRAMPOLINE_TOP * 0.5, sin(angle) * TRAMPOLINE_RADIUS)
		), frame_colour)
	var mat := CylinderMesh.new()
	mat.top_radius = TRAMPOLINE_RADIUS - 0.06
	mat.bottom_radius = TRAMPOLINE_RADIUS - 0.06
	mat.height = 0.05
	mat.radial_segments = 28
	mat.rings = 1
	_add(tool, mat, Transform3D(Basis(), TRAMPOLINE + Vector3(0.0, TRAMPOLINE_TOP - 0.03, 0.0)), Color(0.12, 0.12, 0.14))
	_finish_into(tool, at)
	var stand := CylinderShape3D.new()
	stand.radius = TRAMPOLINE_RADIUS
	stand.height = 0.12
	_collide(solid, stand, Transform3D(Basis(), TRAMPOLINE + Vector3(0.0, TRAMPOLINE_TOP - 0.06, 0.0)))

## A basketball hoop: pole, backboard, ring. The ring counts what falls
## through it; the balls beside it are ordinary balls with an orange coat.
func _build_hoop(at: Vector3, solid: StaticBody3D) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var metal := Color(0.40, 0.42, 0.46)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.06
	pole.bottom_radius = 0.07
	pole.height = HOOP_HEIGHT + 0.5
	pole.radial_segments = 8
	pole.rings = 1
	_add(tool, pole, Transform3D(Basis(), HOOP + Vector3(0.0, (HOOP_HEIGHT + 0.5) * 0.5, 0.0)), metal)
	var pole_shape := CylinderShape3D.new()
	pole_shape.radius = 0.08
	pole_shape.height = HOOP_HEIGHT + 0.5
	_collide(solid, pole_shape, Transform3D(Basis(), HOOP + Vector3(0.0, (HOOP_HEIGHT + 0.5) * 0.5, 0.0)))
	# The board faces +X, into the playground.
	var board := BoxMesh.new()
	board.size = Vector3(0.08, 1.15, 1.8)
	var board_at := HOOP + Vector3(0.12, HOOP_HEIGHT + 0.35, 0.0)
	_add(tool, board, Transform3D(Basis(), board_at), Color(0.95, 0.95, 0.92))
	var board_shape := BoxShape3D.new()
	board_shape.size = board.size
	_collide(solid, board_shape, Transform3D(Basis(), board_at))
	var target := BoxMesh.new()
	target.size = Vector3(0.02, 0.50, 0.70)
	_add(tool, target, Transform3D(Basis(), board_at + Vector3(0.05, -0.2, 0.0)), Color(0.86, 0.30, 0.26))
	var ring := TorusMesh.new()
	ring.inner_radius = HOOP_RING - 0.02
	ring.outer_radius = HOOP_RING + 0.02
	ring.rings = 6
	ring.ring_segments = 20
	_add(tool, ring, Transform3D(Basis(), HOOP + Vector3(HOOP_REACH, HOOP_HEIGHT, 0.0)), Color(0.90, 0.42, 0.14))
	# A few strands of net, so it reads as a hoop from the far side of the pad.
	for i in 8:
		var angle := TAU * float(i) / 8.0
		var strand := CylinderMesh.new()
		strand.top_radius = 0.012
		strand.bottom_radius = 0.012
		strand.height = 0.42
		strand.radial_segments = 4
		strand.rings = 1
		var rim := HOOP + Vector3(HOOP_REACH + cos(angle) * HOOP_RING, HOOP_HEIGHT - 0.21, sin(angle) * HOOP_RING * 0.8)
		_add(tool, strand, Transform3D(Basis(), rim), Color(0.92, 0.92, 0.90))
	_finish_into(tool, at)
	_has_hoop = true

## A bin: a dark green drum with a rim, solid.
func _build_bin(at: Vector3, local: Vector3, solid: StaticBody3D) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var drum := CylinderMesh.new()
	drum.top_radius = 0.22
	drum.bottom_radius = 0.20
	drum.height = 0.72
	drum.radial_segments = 10
	drum.rings = 1
	_add(tool, drum, Transform3D(Basis(), local + Vector3(0.0, 0.36, 0.0)), Color(0.18, 0.36, 0.22))
	var rim := TorusMesh.new()
	rim.inner_radius = 0.19
	rim.outer_radius = 0.25
	rim.rings = 6
	rim.ring_segments = 12
	_add(tool, rim, Transform3D(Basis(), local + Vector3(0.0, 0.72, 0.0)), Color(0.30, 0.31, 0.34))
	_finish_into(tool, at)
	var shape := CylinderShape3D.new()
	shape.radius = 0.24
	shape.height = 0.75
	_collide(solid, shape, Transform3D(Basis(), local + Vector3(0.0, 0.375, 0.0)))

## A drinking fountain, in two tiers: a plinth and basin, a column with a
## smaller bowl on top, a jet rising from the bowl and water spilling from its
## rim back into the basin. The first one was a tub with a ball on a stick —
## the parts a fountain is made of, not what one looks like; the water in
## motion is the fountain. Standing beside it fills the bottle, the way the
## river's shallows do.
func _build_fountain(at: Vector3, solid: StaticBody3D) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stone := Color(0.62, 0.60, 0.56)
	var pale := Color(0.70, 0.68, 0.63)
	var water := Color(0.36, 0.64, 0.80)
	var spray := Color(0.70, 0.86, 0.95)

	# An octagonal step to stand on, then the basin with a rounded lip.
	var plinth := CylinderMesh.new()
	plinth.top_radius = 1.35
	plinth.bottom_radius = 1.42
	plinth.height = 0.14
	plinth.radial_segments = 8
	plinth.rings = 1
	_add(tool, plinth, Transform3D(Basis(), FOUNTAIN + Vector3(0.0, 0.07, 0.0)), pale)
	var basin := CylinderMesh.new()
	basin.top_radius = 1.10
	basin.bottom_radius = 0.98
	basin.height = 0.42
	basin.radial_segments = 18
	basin.rings = 1
	_add(tool, basin, Transform3D(Basis(), FOUNTAIN + Vector3(0.0, 0.35, 0.0)), stone)
	var lip := TorusMesh.new()
	lip.inner_radius = 0.96
	lip.outer_radius = 1.20
	lip.rings = 8
	lip.ring_segments = 24
	_add(tool, lip, Transform3D(Basis(), FOUNTAIN + Vector3(0.0, 0.56, 0.0)), pale)
	var pool := CylinderMesh.new()
	pool.top_radius = 1.0
	pool.bottom_radius = 1.0
	pool.height = 0.03
	pool.radial_segments = 18
	pool.rings = 1
	_add(tool, pool, Transform3D(Basis(), FOUNTAIN + Vector3(0.0, 0.53, 0.0)), water)

	# The upper tier: a column out of the water and a bowl on it.
	var column := CylinderMesh.new()
	column.top_radius = 0.11
	column.bottom_radius = 0.16
	column.height = 0.78
	column.radial_segments = 10
	column.rings = 1
	_add(tool, column, Transform3D(Basis(), FOUNTAIN + Vector3(0.0, 0.92, 0.0)), stone)
	var bowl := CylinderMesh.new()
	bowl.top_radius = 0.52
	bowl.bottom_radius = 0.26
	bowl.height = 0.22
	bowl.radial_segments = 14
	bowl.rings = 1
	_add(tool, bowl, Transform3D(Basis(), FOUNTAIN + Vector3(0.0, 1.42, 0.0)), stone)
	var bowl_water := CylinderMesh.new()
	bowl_water.top_radius = 0.46
	bowl_water.bottom_radius = 0.46
	bowl_water.height = 0.02
	bowl_water.radial_segments = 14
	bowl_water.rings = 1
	_add(tool, bowl_water, Transform3D(Basis(), FOUNTAIN + Vector3(0.0, 1.535, 0.0)), water)

	# Water spilling over the bowl's rim in thin streams to the basin. Six
	# still lines, but they read as falling water, which is what sells it.
	for i in 6:
		var angle := TAU * float(i) / 6.0
		var stream := CylinderMesh.new()
		stream.top_radius = 0.022
		stream.bottom_radius = 0.032
		stream.height = 1.0
		stream.radial_segments = 4
		stream.rings = 1
		_add(tool, stream, Transform3D(
			Basis(), FOUNTAIN + Vector3(cos(angle) * 0.56, 1.03, sin(angle) * 0.56)
		), spray)
	_finish_into(tool, at)

	# The jet is its own node so that it can move: _process scales it up and
	# down a little, and a fountain that moves is a fountain.
	var jet_tool := SurfaceTool.new()
	jet_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var jet := CylinderMesh.new()
	jet.top_radius = 0.03
	jet.bottom_radius = 0.055
	jet.height = 0.6
	jet.radial_segments = 6
	jet.rings = 1
	_add(jet_tool, jet, Transform3D(Basis(), Vector3(0.0, 0.3, 0.0)), spray)
	var crown := SphereMesh.new()
	crown.radius = 0.11
	crown.height = 0.09
	crown.radial_segments = 8
	crown.rings = 3
	_add(jet_tool, crown, Transform3D(Basis(), Vector3(0.0, 0.6, 0.0)), spray)
	jet_tool.generate_normals()
	jet_tool.set_material(_material())
	_jet = MeshInstance3D.new()
	_jet.mesh = jet_tool.commit()
	_jet.transform = Transform3D(Basis(), at + FOUNTAIN + Vector3(0.0, 1.545, 0.0))
	add_child(_jet)

	var shape := CylinderShape3D.new()
	shape.radius = 1.2
	shape.height = 0.56
	_collide(solid, shape, Transform3D(Basis(), FOUNTAIN + Vector3(0.0, 0.28, 0.0)))

## Three lamp posts round the pad. The lights start dark; `light_lamps`
## brings them up with dusk.
func _build_lamps(at: Vector3, solid: StaticBody3D) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in LAMPS.size():
		_build_lamp(tool, at, LAMPS[i], solid, LAMP_THRESHOLDS[i % LAMP_THRESHOLDS.size()])
	_finish_into(tool, at)

## One lamp post: a post with a lantern head, a pane that glows when lit, and
## an omni light with no shadows — three shadowed lights over five thousand
## blades of grass would cost more than the rest of the frame. Its mesh goes
## into the caller's tool; its light and glowing pane are nodes of their own.
## Shared by the playground and the café.
func _build_lamp(
	tool: SurfaceTool, at: Vector3, where: Vector3, solid: StaticBody3D, threshold: float,
	height := LAMP_HEIGHT, reach := LAMP_RANGE, energy := LAMP_ENERGY
) -> void:
	var iron := Color(0.16, 0.18, 0.19)
	var pane := Color(0.78, 0.80, 0.82)
	var local := where
	var world := at + local
	# The rim of a pad is where the level ground starts to fall away, so each
	# post is footed on the ground it actually stands on.
	local.y = field.height_at(world.x, world.z) - at.y - 0.05

	var base := CylinderMesh.new()
	base.top_radius = 0.13
	base.bottom_radius = 0.19
	base.height = 0.28
	base.radial_segments = 8
	base.rings = 1
	_add(tool, base, Transform3D(Basis(), local + Vector3(0.0, 0.14, 0.0)), iron)
	var post := CylinderMesh.new()
	post.top_radius = 0.06
	post.bottom_radius = 0.085 + (height - LAMP_HEIGHT) * 0.02
	post.height = height
	post.radial_segments = 8
	post.rings = 1
	_add(tool, post, Transform3D(Basis(), local + Vector3(0.0, height * 0.5, 0.0)), iron)
	var post_shape := CylinderShape3D.new()
	post_shape.radius = 0.10
	post_shape.height = height
	_collide(solid, post_shape, Transform3D(Basis(), local + Vector3(0.0, height * 0.5, 0.0)))

	# The lantern: a pale pane in an iron frame, with a little roof.
	var head_at := local + Vector3(0.0, height + 0.17, 0.0)
	var glass := BoxMesh.new()
	glass.size = Vector3(0.26, 0.24, 0.26)
	_add(tool, glass, Transform3D(Basis(), head_at), pane)
	for corner in 4:
		var angle := PI * 0.25 + PI * 0.5 * float(corner)
		var rib := BoxMesh.new()
		rib.size = Vector3(0.035, 0.3, 0.035)
		_add(tool, rib, Transform3D(Basis(), head_at + Vector3(cos(angle) * 0.185, 0.0, sin(angle) * 0.185)), iron)
	var roof := CylinderMesh.new()
	roof.top_radius = 0.0
	roof.bottom_radius = 0.27
	roof.height = 0.17
	roof.radial_segments = 4
	roof.rings = 1
	_add(tool, roof, Transform3D(Basis(Vector3.UP, PI * 0.25), head_at + Vector3(0.0, 0.23, 0.0)), iron)

	# What glows: a slightly larger pane in an unshaded, emissive material,
	# shown only while the lamp is lit.
	var glow_mesh := BoxMesh.new()
	glow_mesh.size = Vector3(0.28, 0.26, 0.28)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = LAMP_COLOUR
	glow.emission_enabled = true
	glow.emission = LAMP_COLOUR
	glow.emission_energy_multiplier = 1.8
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var lit_pane := MeshInstance3D.new()
	lit_pane.mesh = glow_mesh
	lit_pane.material_override = glow
	lit_pane.position = at + head_at
	lit_pane.visible = false
	add_child(lit_pane)

	var light := OmniLight3D.new()
	light.omni_range = reach
	light.light_color = LAMP_COLOUR
	light.light_energy = 0.0
	light.shadow_enabled = false
	light.visible = false
	light.position = at + head_at + Vector3(0.0, -0.1, 0.0)
	add_child(light)

	_lamps.append({"light": light, "glass": lit_pane, "threshold": threshold, "lit": 0.0, "energy": energy})

## Four floodlights round the football pitch, a little beyond its corners,
## which come on with dusk like the lamps at the playground and light the
## pitch for a game after dark. Taller and brighter than a street lamp; not a
## stadium, so the meadow round the pitch stays night.
func _build_pitch_lamps() -> void:
	var centre := Pitch.centre()
	centre.y = field.height_at(centre.x, centre.z)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var solid := StaticBody3D.new()
	solid.transform = Transform3D(Basis(), centre)
	solid.collision_layer = TerrainSpec.LAYER_PROPS
	add_child(solid)
	_pitch_solid = solid
	var corner := 0
	for sx in PackedFloat32Array([-1.0, 1.0]):
		for sz in PackedFloat32Array([-1.0, 1.0]):
			var where := Vector3(
				sx * (Pitch.HALF_LENGTH + PITCH_LAMP_CLEARANCE), 0.0,
				sz * (Pitch.HALF_WIDTH + PITCH_LAMP_CLEARANCE)
			)
			_build_lamp(tool, centre, where, solid, 0.10 + 0.03 * float(corner), PITCH_LAMP_HEIGHT, PITCH_LAMP_RANGE, PITCH_LAMP_ENERGY)
			corner += 1
	_finish_into(tool, centre)

## How many floodlights the pitch has. For the checks.
func pitch_lamp_count() -> int:
	return 0 if _pitch_solid == null else _pitch_solid.get_child_count()

## A flower bed: a ring of turned earth with flowers standing in it. The valley
## has almost no flowers; this is where a few are.
func _build_flower_bed(at: Vector3, local: Vector3) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(local)
	var earth := TorusMesh.new()
	earth.inner_radius = 0.72
	earth.outer_radius = 0.98
	earth.rings = 6
	earth.ring_segments = 18
	_add(tool, earth, Transform3D(Basis(), local + Vector3(0.0, 0.06, 0.0)), Color(0.40, 0.28, 0.18))
	var petals: Array[Color] = [
		Color(0.90, 0.24, 0.30), Color(0.98, 0.82, 0.22), Color(0.94, 0.52, 0.72),
		Color(0.96, 0.96, 0.92), Color(0.58, 0.36, 0.82), Color(0.98, 0.56, 0.20),
	]
	# Knee-high and thick: twelve short stems read as a few weeds in a ring of
	# dirt, which is what the first version looked like. Two dozen taller ones
	# with bigger heads and a leaf each read as a bed in flower.
	var leaf := Color(0.30, 0.56, 0.26)
	for i in 26:
		var r := sqrt(rng.randf()) * 0.72
		var angle := rng.randf() * TAU
		var spot := local + Vector3(cos(angle) * r, 0.0, sin(angle) * r)
		var stem_height := rng.randf_range(0.48, 0.72)
		var lean := Basis(Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized(), rng.randf_range(0.0, 0.16))
		var stem := CylinderMesh.new()
		stem.top_radius = 0.014
		stem.bottom_radius = 0.02
		stem.height = stem_height
		stem.radial_segments = 4
		stem.rings = 1
		_add(tool, stem, Transform3D(lean, spot + lean * Vector3(0.0, stem_height * 0.5, 0.0)), leaf)
		var blade := BoxMesh.new()
		blade.size = Vector3(0.05, 0.012, 0.16)
		_add(tool, blade, Transform3D(
			lean * Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, -0.5),
			spot + lean * Vector3(0.0, stem_height * 0.45, 0.0)
		), leaf)
		var head := SphereMesh.new()
		head.radius = rng.randf_range(0.075, 0.115)
		head.height = head.radius * 1.6
		head.radial_segments = 7
		head.rings = 4
		_add(tool, head, Transform3D(lean, spot + lean * Vector3(0.0, stem_height + 0.02, 0.0)), petals[rng.randi_range(0, petals.size() - 1)])
		# A dark centre, so a head is a flower and not a coloured ball.
		var eye := SphereMesh.new()
		eye.radius = head.radius * 0.36
		eye.height = eye.radius * 2.0
		eye.radial_segments = 5
		eye.rings = 3
		_add(tool, eye, Transform3D(lean, spot + lean * Vector3(0.0, stem_height + 0.02 + head.radius * 0.72, 0.0)), Color(0.28, 0.20, 0.10))
	_finish_into(tool, at)

## Commit a tool's geometry as one mesh node at the playground's origin.
func _finish_into(tool: SurfaceTool, at: Vector3) -> void:
	tool.generate_normals()
	tool.set_material(_material())
	var mesh := MeshInstance3D.new()
	mesh.mesh = tool.commit()
	mesh.transform = Transform3D(Basis(), at)
	add_child(mesh)

## A bench: plank seat, plank back, two end frames. Faces -Z, towards the
## swings, and is solid, so it can be walked round but not through.
func _build_bench(at: Vector3, local: Vector3, solid: StaticBody3D) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wood := Color(0.58, 0.42, 0.26)
	var iron := Color(0.30, 0.31, 0.34)
	var seat := BoxMesh.new()
	seat.size = Vector3(1.7, 0.07, 0.42)
	_add(tool, seat, Transform3D(Basis(), local + Vector3(0.0, 0.46, 0.0)), wood)
	var back := BoxMesh.new()
	back.size = Vector3(1.7, 0.36, 0.06)
	_add(tool, back, Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(-12.0)), local + Vector3(0.0, 0.74, 0.24)
	), wood)
	for side in PackedFloat32Array([-0.75, 0.75]):
		var leg := BoxMesh.new()
		leg.size = Vector3(0.06, 0.46, 0.40)
		_add(tool, leg, Transform3D(Basis(), local + Vector3(side, 0.23, 0.0)), iron)
		var upright := BoxMesh.new()
		upright.size = Vector3(0.06, 0.44, 0.06)
		_add(tool, upright, Transform3D(
			Basis(Vector3.RIGHT, deg_to_rad(-12.0)), local + Vector3(side, 0.70, 0.24)
		), iron)
	tool.generate_normals()
	tool.set_material(_material())
	var mesh := MeshInstance3D.new()
	mesh.mesh = tool.commit()
	mesh.transform = Transform3D(Basis(), at)
	add_child(mesh)

	var block := BoxShape3D.new()
	block.size = Vector3(1.7, 0.95, 0.5)
	_collide(solid, block, Transform3D(Basis(), local + Vector3(0.0, 0.475, 0.08)))

## How many benches stand at the playground, and how many solid pieces there
## are to bump into. For the checks.
func bench_count() -> int:
	return _benches

func solid_shape_count() -> int:
	return 0 if _solid == null else _solid.get_child_count()

static func _collide(body: StaticBody3D, shape: Shape3D, where: Transform3D) -> void:
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.transform = where
	body.add_child(collider)

static func _material() -> StandardMaterial3D:
	if _shared == null:
		_shared = StandardMaterial3D.new()
		_shared.vertex_color_use_as_albedo = true
		_shared.vertex_color_is_srgb = true
		_shared.roughness = 0.84
	return _shared

static var _shared: StandardMaterial3D = null

static func _add(tool: SurfaceTool, source: PrimitiveMesh, transform: Transform3D, colour: Color) -> void:
	var arrays := source.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for i in vertices.size():
			tool.set_color(colour)
			tool.add_vertex(transform * vertices[i])
		return
	for i in indices.size():
		tool.set_color(colour)
		tool.add_vertex(transform * vertices[indices[i]])
