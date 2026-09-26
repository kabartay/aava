class_name RollerCoaster
extends Node3D

## The big ride: a wooden coaster running the whole length of the fairground
## beside the river, twenty metres up at the top of its lift hill.
##
## The track is a stadium — two long straights with a half-circle at each end —
## and a height profile laid along it: the station, the climb, and then three
## drops that get smaller, the way a real one spends what the chain lift gave
## it. Everything else is worked out from that single line: the rails, the
## sleepers, the trestles down to the ground, and where a car is at any moment.
##
## The cars are AnimatableBody3D with a floor and high sides, so a child
## standing in one is carried by it rather than having to be told they are
## aboard. They move by arc length, and their speed comes from how far they
## have fallen — slow over the top, fast at the bottom — which is the whole
## feeling of the thing.

## The shape of the circuit. Half-length along the river, half-width across it;
## the ends are half-circles of that width.
const HALF_LENGTH := 68.0
const HALF_WIDTH := 6.5

## The height profile, as [fraction of the circuit, metres above the ground].
##
## Station, chain lift, and then the ride spends what the lift gave it: a first
## drop nearly to the sand, a big camelback, a second drop, a pair of small
## hills taken fast enough to lift a child off the seat, and a long swooping
## turn home into the brakes. Each crest is lower than the one before it,
## because a coaster cannot climb higher than it has fallen from and a profile
## that pretends otherwise is the one thing a ten-year-old will notice.
const PROFILE: Array = [
	[0.00, 1.30], [0.05, 1.30], [0.26, 28.0], [0.34, 26.4], [0.42, 10.0],
	[0.50, 2.20], [0.56, 2.20], [0.64, 2.40], [0.72, 12.6], [0.78, 4.20],
	[0.84, 8.40], [0.88, 3.60], [0.92, 5.20], [0.96, 2.00], [1.00, 1.30],
]

## The two loops, as [where on the base circuit they stand, their radius].
##
## A vertical loop is not a hill: the track leaves the base line, goes up and
## over backwards, and comes down onto the same spot it left. So it is not in
## the height profile at all — it is spliced into the circuit, and the base
## line underneath it is flat, which is what the long level stretch between
## 0.50 and 0.64 is for.
##
## Both stand on the river side of the circuit, where the train arrives at its
## fastest: the lift is twenty-eight metres, the drop and the bend spend it,
## and the train enters the first loop at over twenty metres a second.
##
## The radii are what the speed will carry, and that is a real sum rather than
## a guess. A car needs v² ≥ 5gR at the bottom of a loop or it leaves the rails
## at the top; at 22 m/s that is a radius of up to 9.9 m. Seven metres is taken
## for the first, so the train goes over the top at about three times its own
## weight — firmly held, not hanging — and the second is smaller again because
## by then the train has spent some of what it had.
const LOOPS: Array = [
	[0.53, 7.00],
	[0.60, 5.80],
]

## How far outside the rails the yellow hoop that carries a loop stands, and
## what colour it is: every looping coaster a child has seen has this, and it
## is what makes a loop read as a loop from across the fairground rather than
## as a bent rail.
const HOOP_OFFSET := 1.70
const HOOP := Color(0.96, 0.74, 0.16)

## Where the cars pull up, where the chain lift ends, and where the brakes
## take hold on the way back in.
const BOARDS_AT := 0.02
const LIFT_FOOT := 0.05
const LIFT_TOP := 0.26
const BRAKES_FROM := 0.94

## The button on the platform, and how close you have to be to press it.
##
## The train runs all day. It only pulls up if somebody has booked a ride at
## the button, which is also where the ticket is taken — so a child who has
## not paid never has a train standing in front of them to climb into, and
## the ride stops being a thing that happens to be there and becomes a thing
## you ask for.
const BUTTON_AT := Vector3(2.6, 0.0, 5.4)
const BUTTON_HEIGHT := 1.05
const BUTTON_REACH := 2.2
const BUTTON := Color(0.86, 0.22, 0.20)
const BUTTON_LIT := Color(0.42, 0.86, 0.36)

## How long the cars stand at the platform. Ten seconds: long enough to walk
## the length of it, pick a car and step in without hurrying a six-year-old,
## and long enough that missing the train is a choice rather than an accident.
const DWELL := 10.0

## How far the shoulder harnesses swing down, and how long they take.
const HARNESS_DROP := deg_to_rad(74.0)
const HARNESS_TIME := 1.1

## The physics.
##
## A real coaster is one number — how far it has fallen since the lift — and
## everything else follows. This integrates it properly rather than reading a
## speed off the height: gravity along the track's own slope, a little drag,
## the chain holding a steady pace up the lift, and brakes on the run home.
## What that buys is the feel of it — a car crests a hill still slowing and
## picks up over the brow rather than at it.
##
## Gravity is the real thing. It was scaled down to a third at first, out of a
## worry that a child could not be carried at speed, and what that produced was
## a train that ambled down a twenty-metre drop: the one moment the whole ride
## exists for, and it felt like a pushchair. Nothing about carrying a passenger
## cares how fast the car is going — the ride sets their position outright —
## so the drops are as fast as the height says they are, which for this one is
## about eighteen metres a second at the bottom of the first.
const GRAVITY := 9.8
const DRAG := 0.016
const LIFT_SPEED := 3.4
const LIFT_PULL := 2.6
const BRAKE := 7.5
const CRAWL := 1.6
const TOP_SPEED := 26.0

## How far the piles stand either side of the track's own line.
const PILE_OFFSET := 0.78

## How high a car's floor rides above the track's own line.
const CAR_FLOOR := 0.55

## The steps up onto the platform: how many treads, and how far the flight
## reaches out along the sand.
const STEPS := 6
const STEPS_RUN := 4.2

## Five cars, one seat each. A train of two-seaters is a train; five single
## cars is a fairground ride, and a child on their own is never sitting in the
## empty half of one.
const CARS := 5
const CAR_GAP := 2.15

const TIMBER := Color(0.55, 0.40, 0.26)
const TIMBER_DARK := Color(0.38, 0.28, 0.19)
const RAIL := Color(0.80, 0.34, 0.28)
## The seats, and the shoulder harnesses that come down over them. Yellow,
## because that is the colour every child has seen one in.
## How many seats a car carries.
const SEATS := 1

const SEAT := Color(0.24, 0.25, 0.30)
const HARNESS := Color(0.96, 0.80, 0.16)

const CAR_COLOURS: Array[Color] = [
	Color(0.88, 0.26, 0.24), Color(0.96, 0.78, 0.26), Color(0.28, 0.52, 0.84),
]

var _cars: Array[AnimatableBody3D] = []
var _frame: StaticBody3D
var _at_distance := 0.0
var _speed := 0.0
## How long is left of the wait at the platform, and whether anybody has
## booked the next one.
var _waiting := 0.0
var _booked := false
var _cap: MeshInstance3D
var _cap_paint: StandardMaterial3D

func _init(at: Vector3) -> void:
	name = "RollerCoaster"
	position = at

	# The timber is solid: a coaster you can walk through is scenery, and this
	# is the biggest thing on the fairground.
	_frame = StaticBody3D.new()
	_frame.name = "Frame"
	add_child(_frame)

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_build_track(tool)
	_build_hoops(tool)
	_lay_the_rails()
	_build_lift(tool)
	_build_station(tool)

	tool.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.86
	tool.set_material(material)
	var drawn := MeshInstance3D.new()
	drawn.name = "Track"
	drawn.mesh = tool.commit()
	add_child(drawn)

	for car in CARS:
		_cars.append(_build_car(car))
	_place_cars()

## How long the base circuit is — the stadium alone, with no loops in it.
static func base_circuit() -> float:
	return 4.0 * (HALF_LENGTH - HALF_WIDTH) + TAU * HALF_WIDTH

## How long the whole ride is, loops included. This is the length a car
## actually travels, and the length everything else is measured in.
static func circuit() -> float:
	var total := base_circuit()
	for loop: Array in LOOPS:
		total += TAU * float(loop[1])
	return total

## Where a distance along the ride falls: how far along the base circuit it
## is, which loop it is inside — -1 for none — and how far round that loop, in
## radians.
##
## This is the whole trick of the loops. The base stadium is left exactly as
## it was, and each loop is spliced into it as an extra stretch of track
## during which the base position does not advance at all: a car enters the
## loop, travels 2πR, and comes out on the rail it left. Everything else — the
## rails, the sleepers, the collision, the cars, the physics — reads the track
## through here and needs to know nothing about loops.
static func unwind(distance: float) -> Array:
	var along := fposmod(distance, circuit())
	var base := base_circuit()
	var cursor := 0.0
	var base_cursor := 0.0
	for index in LOOPS.size():
		var entry: float = base * float(LOOPS[index][0])
		var run := entry - base_cursor
		if along <= cursor + run:
			return [base_cursor + (along - cursor), -1, 0.0]
		cursor += run
		base_cursor = entry
		var radius: float = float(LOOPS[index][1])
		var round_it := TAU * radius
		if along <= cursor + round_it:
			return [entry, index, (along - cursor) / radius]
		cursor += round_it
	return [base_cursor + (along - cursor), -1, 0.0]

## Where the track is at a distance along it, loops and all.
func point_at(distance: float) -> Vector3:
	var at := unwind(distance)
	var here := base_point_at(float(at[0]))
	var loop := int(at[1])
	if loop < 0:
		return here
	# A circle in the vertical plane the track is already running in: it
	# leaves along the rail, rises, goes over the top backwards, and comes
	# down onto the point it left. Two radii up at the top, and no sideways
	# movement anywhere in it — which is why the hoop that carries it stands
	# directly over its own feet.
	var radius: float = float(LOOPS[loop][1])
	var angle := float(at[2])
	var forward := base_heading_at(float(at[0]))
	var up := (Vector3.UP - forward * forward.dot(Vector3.UP)).normalized()
	return here + forward * (sin(angle) * radius) + up * ((1.0 - cos(angle)) * radius)

## Which way the base track is heading here, as a unit vector.
func base_heading_at(base_distance: float) -> Vector3:
	return (base_point_at(base_distance + 1.0) - base_point_at(base_distance - 1.0)).normalized()

## Where the base stadium is at a distance along itself.
## The stadium is walked straight-round-straight-round, so that a car's speed
## can be worked out from distance rather than from an angle that means
## something different on every part of the shape.
func base_point_at(distance: float) -> Vector3:
	var straight := 2.0 * (HALF_LENGTH - HALF_WIDTH)
	var bend := PI * HALF_WIDTH
	var total := base_circuit()
	var along := fposmod(distance, total)
	var flat := Vector2.ZERO
	if along < straight:
		# Up the eastern side, heading north.
		flat = Vector2(HALF_WIDTH, (HALF_LENGTH - HALF_WIDTH) - along)
	elif along < straight + bend:
		var turn := (along - straight) / HALF_WIDTH
		flat = Vector2(
			cos(turn) * HALF_WIDTH,
			-(HALF_LENGTH - HALF_WIDTH) - sin(turn) * HALF_WIDTH
		)
	elif along < 2.0 * straight + bend:
		var back := along - straight - bend
		flat = Vector2(-HALF_WIDTH, -(HALF_LENGTH - HALF_WIDTH) + back)
	else:
		var turn := (along - 2.0 * straight - bend) / HALF_WIDTH
		flat = Vector2(
			-cos(turn) * HALF_WIDTH,
			(HALF_LENGTH - HALF_WIDTH) + sin(turn) * HALF_WIDTH
		)
	return Vector3(flat.x, height_at(along / total), flat.y)

## How high the track is at a fraction of the way round, read off the profile.
func height_at(fraction: float) -> float:
	var f := fposmod(fraction, 1.0)
	for key in PROFILE.size() - 1:
		var from: Array = PROFILE[key]
		var to: Array = PROFILE[key + 1]
		if f >= float(from[0]) and f <= float(to[0]):
			var along := (f - float(from[0])) / maxf(float(to[0]) - float(from[0]), 0.0001)
			# Smoothed, so the crest of a hill is a crest and not a corner.
			return lerpf(float(from[1]), float(to[1]), smoothstep(0.0, 1.0, along))
	return float(PROFILE[0][1])

## How far the track is banked here, and which way.
##
## A coaster does not go round a bend flat — it lays over into it, and the
## sight of the train tipped up on the turn is half of what makes one look
## fast. The bends are the two half-circles at the ends of the stadium, so the
## bank comes on where the straight ends and eases off where the next one
## begins; which way it leans is worked out from the track itself, by asking
## which way the tangent is swinging.
const BANK := deg_to_rad(24.0)
const BANK_EASE := 5.0

func bank_at(distance: float) -> float:
	# Read off the base line, not the track: inside a loop the track's heading
	# swings through a whole turn without going anywhere, and a bank worked
	# out from that would lay the car over on its side at the top of it.
	var at := unwind(distance)
	if int(at[1]) >= 0:
		return 0.0
	var base := float(at[0])
	var here := base_point_at(base)
	var ahead := base_point_at(base + 2.0)
	var behind := base_point_at(base - 2.0)
	var into := Vector2(ahead.x - here.x, ahead.z - here.z).normalized()
	var out_of := Vector2(here.x - behind.x, here.z - behind.z).normalized()
	# How far the heading swings over four metres: nothing on a straight, and
	# a steady amount all the way round a bend.
	var swing := out_of.angle_to(into)
	var lean := clampf(swing / (4.0 / HALF_WIDTH), -1.0, 1.0)
	return -lean * BANK

## The way a car sits at a point on the track: pointed along it, pitched with
## its slope, and laid over into its bend. Asked by the rails, the sleepers and
## the cars alike, so none of them can disagree about which way is up.
func frame_at(distance: float) -> Basis:
	var at := unwind(distance)
	var base := float(at[0])
	var here := base_point_at(base)
	var ahead := base_point_at(base + 1.0)
	var run := ahead - here
	var turn := Basis(Vector3.UP, atan2(-run.z, run.x))
	turn = turn * Basis(Vector3.BACK, atan2(run.y, Vector2(run.x, run.z).length()))
	turn = turn * Basis(Vector3.RIGHT, bank_at(distance))
	# In a loop the car rolls right the way over, about its own across-axis.
	# Built from an angle rather than from the direction of travel, because
	# straight up and straight down have no heading to read: a frame taken
	# from the run of the rail flips over at the top of every loop, and the
	# car — and whoever is in it — flips with it.
	var loop := int(at[1])
	if loop < 0:
		return turn
	return turn * Basis(Vector3.BACK, float(at[2]))

## How steeply the track falls or rises here: metres of height per metre along
## the rail, which is what gravity actually pulls on.
##
## Measured off the track itself rather than off the height profile, so that a
## loop is as real to the physics as a hill is: going up the inside of one the
## gradient reaches a clean 1.0 — straight up — and the car slows at the full
## pull of gravity, which is what decides whether it gets over the top at all.
func gradient_at(fraction: float) -> float:
	var total := circuit()
	var step := 0.4
	var behind := point_at(fraction * total - step)
	var ahead := point_at(fraction * total + step)
	return clampf((ahead.y - behind.y) / (2.0 * step), -1.0, 1.0)

## How fast a car would be going at a fraction of the way round if it had come
## straight from the top of the lift. Kept for the checks and for anything that
## wants the shape of the ride without running it.
func speed_at(fraction: float) -> float:
	var f := fposmod(fraction, 1.0)
	if base_fraction_at(f * circuit()) < LIFT_TOP:
		return LIFT_SPEED
	# Off the track's own height, so a loop counts: the top of one is fifteen
	# metres of climb like any other, and the train is slow there.
	var fallen := height_at(LIFT_TOP) - point_at(f * circuit()).y
	return clampf(sqrt(maxf(0.0, 2.0 * GRAVITY * fallen)), CRAWL, TOP_SPEED)

## The other way about: how far along the ride a mark on the base line is.
## The station, the lift foot and the brakes are all given as fractions of the
## base circuit, and a car is measured in ride distance.
static func distance_of(base_fraction: float) -> float:
	var base := base_circuit()
	var want := base_fraction * base
	var distance := want
	for loop: Array in LOOPS:
		if base * float(loop[0]) < want:
			distance += TAU * float(loop[1])
	return distance

## How far round the base circuit a distance along the ride is, as a fraction.
## The station, the lift and the brakes are all marked on the base line, so
## this is what they are compared against — a fraction of the whole ride means
## something different now there are eighty metres of loop in it.
static func base_fraction_at(distance: float) -> float:
	return float(unwind(distance)[0]) / base_circuit()

## How fast the train is actually going, this moment.
func speed() -> float:
	return _speed

## Told by the game: somebody has paid and is standing at the platform, and
## somebody is sitting in a car.
func clear_to_board(paid: bool) -> void:
	_cleared_to_board = paid

func rider_aboard(aboard: bool) -> void:
	_rider_aboard = aboard

## Is a child standing close enough to a car to get into it?
func car_within(at: Vector3, reach: float) -> bool:
	for car in _cars:
		if car.global_position.distance_to(at) < reach:
			return true
	return false

## How far down the harnesses are: nought at the platform, one on the ride.
## For the checks.
func locked() -> float:
	return _locked

## Is it standing at the platform?
func boarding() -> bool:
	return _waiting > 0.0

## Where the button is, in the world, and whether somebody is close enough to
## press it.
func button_at() -> Vector3:
	var at := point_at(distance_of(BOARDS_AT))
	return global_position + Vector3(
		at.x + BUTTON_AT.x,
		at.y + CAR_FLOOR + BUTTON_HEIGHT + 0.06,
		at.z + BUTTON_AT.z
	)

func at_the_button(at: Vector3) -> bool:
	return at.distance_to(button_at()) < BUTTON_REACH

## A ride has been paid for: the next time the train comes past the platform
## it pulls up, and stands there for as long as it takes a six-year-old to
## choose a car and get in.
func book() -> void:
	_booked = true

func booked() -> bool:
	return _booked

func _build_track(tool: SurfaceTool) -> void:
	var total := circuit()
	# Fine enough that a seven-metre loop is a circle rather than a polygon:
	# a piece of track is about three quarters of a metre long.
	var steps := 480
	var step := total / float(steps)
	for piece in steps:
		var here := point_at(step * float(piece))
		var next := point_at(step * float(piece + 1))
		var run := next - here
		var middle := (here + next) * 0.5
		var turn := frame_at(step * (float(piece) + 0.5))
		var length := run.length()

		# Two rails, and a sleeper under them.
		for side: float in [-1.0, 1.0]:
			var rail := BoxMesh.new()
			rail.size = Vector3(length * 1.05, 0.14, 0.12)
			Park._add(
				tool, rail,
				Transform3D(turn, middle + turn * Vector3(0.0, 0.10, side * 0.62)),
				RAIL
			)
		var sleeper := BoxMesh.new()
		sleeper.size = Vector3(length * 0.5, 0.10, 1.7)
		Park._add(tool, sleeper, Transform3D(turn, middle), TIMBER)
		# The track's own collision is not built here. One tilted box per piece
		# is the fault the bridge's deck had: two boxes turned differently
		# cannot be laid flush, their corners cross, and a child standing on
		# the result is wedged between them and shaken. It is swept as one
		# surface below.

		# The trestle under it, where there is any height to hold up.
		#
		# Upright, and measured from the ground. They used to be turned with
		# the track and offset in the track's own frame, so on every slope the
		# legs leaned with the rails and their feet stopped short of the sand:
		# a coaster standing on piles that touch nothing. A post holds a track
		# up; it does not lie along it.
		# Every fifth piece rather than every fourth: at three metres apart the
		# bents closed into a thicket and the shape of the ride was lost inside
		# its own scaffolding. Eleven metres is what a wooden coaster actually
		# stands on, and it is still close enough that no span is unsupported.
		# No trestles inside a loop: it is carried by its own hoop, and a post
		# dropped from the top of one would stand in the middle of the ride.
		if int(unwind(step * (float(piece) + 0.5))[1]) >= 0:
			continue
		if piece % 16 != 0 or middle.y < 1.6:
			continue
		var across := Vector3(-run.z, 0.0, run.x).normalized() * PILE_OFFSET
		var foot_height := middle.y
		for side: float in [-1.0, 1.0]:
			var leg := BoxMesh.new()
			leg.size = Vector3(0.18, foot_height, 0.18)
			Park._add(
				tool, leg,
				Transform3D(
					Basis(),
					Vector3(middle.x, foot_height * 0.5, middle.z) + across * side
				),
				TIMBER_DARK
			)
			Park._solid(
				_frame, Vector3(0.45, foot_height, 0.45),
				Transform3D(
					Basis(),
					Vector3(middle.x, foot_height * 0.5, middle.z) + across * side
				)
			)
		# Rungs across the bent, and a diagonal in every bay: the lattice is
		# most of what a wooden coaster looks like from the ground.
		var bays := maxi(1, int(foot_height / 4.5))
		for rung in bays + 1:
			var at := foot_height * float(rung) / float(bays + 1)
			var rail_across := BoxMesh.new()
			rail_across.size = Vector3(0.10, 0.10, across.length() * 2.0 + 0.2)
			Park._add(
				tool, rail_across,
				Transform3D(
					Basis(Vector3.UP, atan2(across.x, across.z)),
					Vector3(middle.x, at, middle.z)
				),
				TIMBER_DARK
			)
		for bay in bays:
			var low := foot_height * float(bay) / float(bays + 1)
			var high := foot_height * float(bay + 1) / float(bays + 1)
			var rise := high - low
			var diagonal := BoxMesh.new()
			diagonal.size = Vector3(0.09, sqrt(rise * rise + across.length() * across.length() * 4.0), 0.09)
			Park._add(
				tool, diagonal,
				Transform3D(
					Basis(Vector3.UP, atan2(across.x, across.z))
					* Basis(Vector3.RIGHT, atan2(across.length() * 2.0, rise)),
					Vector3(middle.x, (low + high) * 0.5, middle.z)
				),
				TIMBER
			)

## The yellow hoop that carries each loop.
##
## A loop is the one part of a coaster that cannot be held up by posts from
## below — there is nothing under the top of it but the bottom of it — so it is
## hung inside a ring of steel that stands on its own two feet. Every looping
## coaster a child has ever seen has this ring, painted, and it is what makes a
## loop read as a loop from the other side of the fairground rather than as a
## rail that happens to bend.
##
## It is drawn just outside the rails, in the same plane, and carried down to
## the sand on two legs at the foot of the loop — which is directly under its
## own top, because a loop comes back to the point it left.
func _build_hoops(tool: SurfaceTool) -> void:
	for index in LOOPS.size():
		var loop: Array = LOOPS[index]
		var radius: float = float(loop[1])
		var entry := base_point_at(base_circuit() * float(loop[0]))
		var forward := base_heading_at(base_circuit() * float(loop[0]))
		var up := (Vector3.UP - forward * forward.dot(Vector3.UP)).normalized()
		var across := forward.cross(up).normalized()
		var centre := entry + up * radius
		var hoop_radius := radius + HOOP_OFFSET
		# Most of a circle: it stops short at the bottom, where the legs take
		# over, so the ring does not cut through its own entrance.
		var arcs := 64
		var from := deg_to_rad(28.0)
		var to := TAU - deg_to_rad(28.0)
		for piece in arcs:
			var a := lerpf(from, to, float(piece) / float(arcs))
			var b := lerpf(from, to, float(piece + 1) / float(arcs))
			var here := centre + (forward * sin(a) - up * cos(a)) * hoop_radius
			var next := centre + (forward * sin(b) - up * cos(b)) * hoop_radius
			var run := next - here
			# A flat band rather than a bar: wide in the plane of the loop and
			# thin across it, which is how these are actually built and what
			# makes them read as one piece of steel from a distance.
			var band := BoxMesh.new()
			band.size = Vector3(run.length() * 1.2, 0.95, 0.34)
			var turn := Basis(Vector3.UP, atan2(-run.z, run.x))
			turn = turn * Basis(Vector3.BACK, atan2(run.y, Vector2(run.x, run.z).length()))
			Park._add(tool, band, Transform3D(turn, (here + next) * 0.5), HOOP)

		# And down to the sand from each end of the ring. Short, because the
		# ring itself comes within half a metre of the ground — a loop that
		# starts two metres up does not need stilts.
		for end: float in [from, to]:
			var head := centre + (forward * sin(end) - up * cos(end)) * hoop_radius
			var post := BoxMesh.new()
			post.size = Vector3(0.62, head.y, 0.40)
			var stand := Transform3D(
				Basis(Vector3.UP, atan2(forward.x, forward.z)),
				Vector3(head.x, head.y * 0.5, head.z)
			)
			Park._add(tool, post, stand, HOOP)
			Park._solid(_frame, Vector3(0.62, head.y, 0.40), stand)

## The track a foot actually meets: one closed prism swept along the whole
## circuit, top, underside and both sides.
##
## The same lesson as the bridge, learnt twice. A box per piece, each turned to
## its own part of the arch, cannot be flush with the next: the upper corner of
## each stands proud of its neighbour, and what a child standing on it gets is
## a floor that pushes them sideways every frame — they sink a little into it,
## catch, and shake. Swept as one surface there are no corners at all.
func _lay_the_rails() -> void:
	var faces := PackedVector3Array()
	var total := circuit()
	var pieces := 480
	var step := total / float(pieces)
	var half_wide := 0.85
	var deep := 0.36
	for piece in pieces:
		var here := point_at(step * float(piece))
		var next := point_at(step * float(piece + 1))
		var frame_here := frame_at(step * float(piece))
		var frame_next := frame_at(step * float(piece + 1))
		# The four corners of the cross-section at each end, in the track's own
		# frame, so the prism banks with the rails.
		var corners: Array[Vector3] = [
			Vector3(0.0, 0.0, -half_wide), Vector3(0.0, 0.0, half_wide),
			Vector3(0.0, -deep, half_wide), Vector3(0.0, -deep, -half_wide),
		]
		for corner in 4:
			var a := here + frame_here * corners[corner]
			var b := next + frame_next * corners[corner]
			var c := next + frame_next * corners[(corner + 1) % 4]
			var d := here + frame_here * corners[(corner + 1) % 4]
			RollerCoaster._quad(faces, a, b, c, d)

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	_frame.add_child(collider)

## Two triangles, wound the same way round.
static func _quad(faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	faces.append(a)
	faces.append(b)
	faces.append(c)
	faces.append(a)
	faces.append(c)
	faces.append(d)

## The chain lift: the ratchet strip a car is dragged up on, laid between the
## rails from the station to the top. It is the one part of a coaster a child
## hears before they see, and the part that says which way the ride goes.
func _build_lift(tool: SurfaceTool) -> void:
	var total := circuit()
	var from := distance_of(LIFT_FOOT)
	var to := distance_of(LIFT_TOP)
	var teeth := int((to - from) / 1.1)
	for tooth in teeth:
		var along := lerpf(from, to, float(tooth) / float(teeth))
		var here := point_at(along)
		var next := point_at(along + 0.6)
		var run := next - here
		var turn := Basis(Vector3.UP, atan2(-run.z, run.x))
		turn = turn * Basis(Vector3.BACK, atan2(run.y, Vector2(run.x, run.z).length()))
		var rung := BoxMesh.new()
		rung.size = Vector3(0.14, 0.16, 0.5)
		Park._add(
			tool, rung,
			Transform3D(turn, here + turn * Vector3(0.0, 0.16, 0.0)),
			TIMBER_DARK
		)

## The station: a platform beside the track at the start, where the cars come
## slowly past and a child can step into one.
func _build_station(tool: SurfaceTool) -> void:
	var at := point_at(distance_of(BOARDS_AT))
	# Beside where the cars stand, and level with their floors: a platform a
	# metre below the car is one you cannot step across from.
	var deck := BoxMesh.new()
	deck.size = Vector3(3.2, 0.24, 16.0)
	var where := Vector3(at.x + 2.6, at.y + CAR_FLOOR - 0.12, at.z)
	Park._add(tool, deck, Transform3D(Basis(), where), TIMBER)

	var body := StaticBody3D.new()
	body.name = "Platform"
	Park._solid(body, deck.size, Transform3D(Basis(), where))
	add_child(body)

	# The legs under it, and they are solid: a child walked through the ones
	# holding up the platform they were about to stand on.
	for post in 5:
		var leg := BoxMesh.new()
		leg.size = Vector3(0.26, where.y, 0.26)
		var spot := Vector3(
			where.x + 1.2, where.y * 0.5, where.z - 6.0 + 3.0 * float(post)
		)
		Park._add(tool, leg, Transform3D(Basis(), spot), TIMBER_DARK)
		Park._solid(_frame, leg.size, Transform3D(Basis(), spot))

	# Steps up at each end. The platform stands level with the car floor, which
	# is nearly two metres over the sand, and there was no way up onto it.
	#
	# Drawn as a flight and walked as a ramp. A character body climbs slopes
	# and stops dead at a riser, however shallow, so a staircase built out of
	# boxes is a wall with a pattern on it: the treads are what a child sees
	# and the ramp under them is what they walk up.
	for end: float in [-1.0, 1.0]:
		var foot := where + Vector3(0.0, 0.0, end * (deck.size.z * 0.5 + STEPS_RUN * 0.5))
		var rise := where.y + deck.size.y * 0.5
		for tread in STEPS:
			var up := rise * float(tread + 1) / float(STEPS)
			var along := STEPS_RUN * (0.5 - (float(tread) + 0.5) / float(STEPS))
			var step := BoxMesh.new()
			step.size = Vector3(deck.size.x * 0.55, 0.16, STEPS_RUN / float(STEPS) + 0.04)
			Park._add(
				tool, step,
				Transform3D(Basis(), Vector3(where.x, up, foot.z + end * along)),
				TIMBER
			)
			# The riser under each tread, so the flight is not a row of
			# floating boards.
			var riser := BoxMesh.new()
			riser.size = Vector3(deck.size.x * 0.55, up, 0.10)
			Park._add(
				tool, riser,
				Transform3D(
					Basis(),
					Vector3(where.x, up * 0.5, foot.z + end * (along + STEPS_RUN / float(STEPS) * 0.5))
				),
				TIMBER_DARK
			)
		# The ramp a child actually walks on, hidden inside the flight.
		var slope := atan2(rise, STEPS_RUN)
		Park._solid(
			_frame,
			Vector3(deck.size.x * 0.55, 0.24, Vector2(STEPS_RUN, rise).length()),
			Transform3D(
				Basis(Vector3.RIGHT, end * slope),
				Vector3(where.x, rise * 0.5 - 0.06, foot.z)
			)
		)

	# The button, at the head of the platform: the only control on the ride.
	var pillar := CylinderMesh.new()
	pillar.top_radius = 0.16
	pillar.bottom_radius = 0.20
	pillar.height = BUTTON_HEIGHT
	pillar.radial_segments = 10
	pillar.rings = 1
	var pedestal := Vector3(
		at.x + BUTTON_AT.x, where.y + deck.size.y * 0.5 + BUTTON_HEIGHT * 0.5,
		at.z + BUTTON_AT.z
	)
	Park._add(tool, pillar, Transform3D(Basis(), pedestal), TIMBER_DARK)
	Park._solid(body, Vector3(0.34, BUTTON_HEIGHT, 0.34), Transform3D(Basis(), pedestal))
	var cap := SurfaceTool.new()
	cap.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dome := SphereMesh.new()
	dome.radius = 0.19
	dome.height = 0.26
	dome.radial_segments = 12
	dome.rings = 6
	Park._add(cap, dome, Transform3D(Basis(), Vector3.ZERO), BUTTON)
	_cap = Park.commit(cap, self, "Button")
	_cap.position = pedestal + Vector3(0.0, BUTTON_HEIGHT * 0.5 + 0.06, 0.0)
	_cap_paint = StandardMaterial3D.new()
	_cap_paint.albedo_color = BUTTON
	_cap.material_override = _cap_paint

	# A roof over it, because a station is a shelter and because it is what
	# tells a child from across the fairground that this is where you get on.
	var roof := BoxMesh.new()
	roof.size = Vector3(4.2, 0.18, 15.0)
	Park._add(
		tool, roof, Transform3D(Basis(), where + Vector3(0.3, 3.2, 0.0)), RAIL
	)
	for post in 4:
		var mast := BoxMesh.new()
		mast.size = Vector3(0.18, 3.2, 0.18)
		var stand := Transform3D(
			Basis(), where + Vector3(1.3, 1.6, -6.0 + 4.0 * float(post))
		)
		Park._add(tool, mast, stand, TIMBER_DARK)
		Park._solid(_frame, mast.size, stand)

func _build_car(index: int) -> AnimatableBody3D:
	var car := AnimatableBody3D.new()
	car.name = "Car%d" % index
	# Not a moving platform as far as physics is concerned: the ride moves its
	# passengers itself, and letting Godot move them as well carried them half
	# again as far as the car they were standing in.
	car.sync_to_physics = false
	add_child(car)

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var colour: Color = CAR_COLOURS[index % CAR_COLOURS.size()]

	# Longer along the track than across it, and the seat faces the way the car
	# is going. It was the other way about: a rider sat sideways, looking out
	# of the doorway, which is how a funfair carriage is built and not how a
	# coaster is — the whole point of a coaster is the drop coming at you.
	var floor_slab := BoxMesh.new()
	floor_slab.size = Vector3(1.9, 0.18, 1.3)
	Park._add(tool, floor_slab, Transform3D(Basis(), Vector3.ZERO), colour.darkened(0.4))
	_solid(car, floor_slab.size, Vector3.ZERO)

	# Closed at both ends and down the far side; the doorway is the near side,
	# which is the local +z — at the station the track runs north and a car's
	# own left hand faces the boards.
	#
	# The doorway is open all the way to the floor. A character body climbs
	# slopes and steps over nothing at all, so even a low sill across the way
	# in is a wall to a child trying to get aboard.
	for wall: Array in [
		[Vector3(0.16, 1.05, 1.3), Vector3(0.95, 0.53, 0.0)],
		[Vector3(0.16, 1.05, 1.3), Vector3(-0.95, 0.53, 0.0)],
		[Vector3(1.9, 1.05, 0.16), Vector3(0.0, 0.53, -0.65)],
	]:
		var size: Vector3 = wall[0]
		var where: Vector3 = wall[1]
		var panel := BoxMesh.new()
		panel.size = size
		Park._add(tool, panel, Transform3D(Basis(), where), colour)
		_solid(car, size, where)

	# A nose on the front and a fin at the back, so a car has a way round to
	# it standing still. A coaster car is not a crate: the front is drawn out
	# to a point and the tail carries the number.
	var nose := CylinderMesh.new()
	nose.top_radius = 0.10
	nose.bottom_radius = 0.62
	nose.height = 0.85
	nose.radial_segments = 10
	nose.rings = 1
	Park._add(
		tool, nose,
		Transform3D(
			Basis(Vector3.BACK, deg_to_rad(-90.0)).scaled(Vector3(1.0, 1.0, 1.15)),
			Vector3(1.38, 0.42, 0.0)
		),
		colour
	)
	var fin := BoxMesh.new()
	fin.size = Vector3(0.5, 0.42, 0.14)
	Park._add(
		tool, fin,
		Transform3D(Basis(Vector3.BACK, deg_to_rad(16.0)), Vector3(-1.12, 1.24, 0.0)),
		colour.darkened(0.25)
	)

	# The running gear: four road wheels and the upstops under them, which is
	# the part that tells a child the car is held onto the rail rather than
	# resting on it — and the honest answer to how it stays on through a loop.
	for end: float in [-1.0, 1.0]:
		for side: float in [-1.0, 1.0]:
			var wheel := CylinderMesh.new()
			wheel.top_radius = 0.20
			wheel.bottom_radius = 0.20
			wheel.height = 0.12
			wheel.radial_segments = 10
			wheel.rings = 1
			Park._add(
				tool, wheel,
				Transform3D(
					Basis(Vector3.RIGHT, deg_to_rad(90.0)),
					Vector3(end * 0.66, -0.16, side * 0.62)
				),
				Color(0.20, 0.20, 0.23)
			)
			var upstop := BoxMesh.new()
			upstop.size = Vector3(0.46, 0.10, 0.10)
			Park._add(
				tool, upstop,
				Transform3D(Basis(), Vector3(end * 0.66, -0.40, side * 0.62)),
				Color(0.30, 0.31, 0.34)
			)

	# A rail over the doorway, which is what you hold while you step in.
	var rail := BoxMesh.new()
	rail.size = Vector3(1.9, 0.12, 0.12)
	Park._add(
		tool, rail, Transform3D(Basis(), Vector3(0.0, 1.02, 0.61)), colour.darkened(0.25)
	)
	for post in 2:
		var stanchion := BoxMesh.new()
		stanchion.size = Vector3(0.12, 1.02, 0.12)
		Park._add(
			tool, stanchion,
			Transform3D(Basis(), Vector3((float(post) - 0.5) * 1.7, 0.51, 0.61)),
			colour.darkened(0.25)
		)

	# The seat: back to the rear of the car, facing forward.
	for _seat in SEATS:
		var cushion := BoxMesh.new()
		cushion.size = Vector3(0.9, 0.16, 0.95)
		Park._add(tool, cushion, Transform3D(Basis(), Vector3(0.06, 0.52, 0.0)), SEAT)
		var back := BoxMesh.new()
		back.size = Vector3(0.18, 1.05, 0.95)
		Park._add(tool, back, Transform3D(Basis(), Vector3(-0.52, 1.0, 0.0)), SEAT)
		# A headrest over it, and the bolsters either side of the shoulders
		# that the harness closes against. A seat that holds you through a loop
		# looks like this; a flat bench does not.
		var headrest := BoxMesh.new()
		headrest.size = Vector3(0.22, 0.44, 0.52)
		Park._add(
			tool, headrest, Transform3D(Basis(), Vector3(-0.50, 1.66, 0.0)), SEAT.lightened(0.1)
		)
		for shoulder: float in [-1.0, 1.0]:
			var bolster := BoxMesh.new()
			bolster.size = Vector3(0.22, 0.62, 0.16)
			Park._add(
				tool, bolster,
				Transform3D(Basis(), Vector3(-0.44, 1.30, shoulder * 0.40)),
				SEAT.lightened(0.1)
			)
		var plinth := BoxMesh.new()
		plinth.size = Vector3(0.75, 0.44, 0.78)
		Park._add(
			tool, plinth, Transform3D(Basis(), Vector3(0.06, 0.30, 0.0)), colour.darkened(0.3)
		)

	tool.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.62
	tool.set_material(material)
	var drawn := MeshInstance3D.new()
	drawn.mesh = tool.commit()
	car.add_child(drawn)

	# The restraints: a shoulder harness over each seat, hinged behind the
	# head. Up while the train stands at the platform, and down as soon as it
	# leaves — which is what makes a coaster feel like a coaster even before it
	# moves, and is the one part of the ride a child recognises from real life.
	for _seat in SEATS:
		var hinge := Node3D.new()
		hinge.name = "Harness"
		hinge.position = Vector3(-0.46, 1.42, 0.0)
		car.add_child(hinge)
		_harnesses.append(hinge)

		var harness := SurfaceTool.new()
		harness.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Two shoulder pads reaching forward over the seat, and the yoke across
		# them: everything forward of the hinge, so that swinging it down
		# brings the pads over whoever is sitting there.
		for shoulder: float in [-1.0, 1.0]:
			var pad := BoxMesh.new()
			pad.size = Vector3(0.85, 0.22, 0.30)
			Park._add(
				harness, pad,
				Transform3D(Basis(), Vector3(0.42, -0.06, shoulder * 0.28)),
				HARNESS
			)
		var yoke := BoxMesh.new()
		yoke.size = Vector3(0.20, 0.18, 0.76)
		Park._add(harness, yoke, Transform3D(Basis(), Vector3(0.06, -0.06, 0.0)), HARNESS)
		# The lap bar, hanging off the front of the yoke, and the buckle that
		# closes on it. Swinging the pads down brings the bar across the lap,
		# which is the movement a child watches for: bars down, we are going.
		var bar := BoxMesh.new()
		bar.size = Vector3(0.18, 0.62, 0.70)
		Park._add(
			harness, bar,
			Transform3D(Basis(Vector3.BACK, deg_to_rad(18.0)), Vector3(0.86, -0.34, 0.0)),
			HARNESS
		)
		var clasp := BoxMesh.new()
		clasp.size = Vector3(0.26, 0.26, 0.30)
		Park._add(
			harness, clasp,
			Transform3D(Basis(), Vector3(0.92, -0.62, 0.0)), HARNESS.darkened(0.45)
		)
		# And a belt from the buckle back down to the seat: the thing that is
		# actually holding, drawn so it can be seen to be there.
		for shoulder: float in [-1.0, 1.0]:
			var strap := BoxMesh.new()
			strap.size = Vector3(0.09, 0.70, 0.13)
			Park._add(
				harness, strap,
				Transform3D(
					Basis(Vector3.BACK, deg_to_rad(-26.0)),
					Vector3(0.52, -0.40, shoulder * 0.30)
				),
				HARNESS.darkened(0.2)
			)
		Park.commit(harness, hinge, "Pads")
	return car

func _solid(car: AnimatableBody3D, size: Vector3, where: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = where
	car.add_child(collider)

func _place_cars() -> void:
	for index in _cars.size():
		var along := _at_distance - float(index) * CAR_GAP
		var here := point_at(along)
		var turn := frame_at(along)
		# Lifted along the car's own up, so a car on a banked bend sits on its
		# track rather than hovering beside it.
		_cars[index].transform = Transform3D(
			turn, here + turn * Vector3(0.0, CAR_FLOOR, 0.0)
		)

func _physics_process(delta: float) -> void:
	var before: Array[Vector3] = []
	for car in _cars:
		before.append(car.position)

	_roll(delta)
	_place_cars()

	if _cap != null:
		# Lit while a train is standing there, pressed in while one is on its
		# way: a button that does nothing visible is a button a child presses
		# again and again.
		_cap_paint.albedo_color = (
			BUTTON_LIT if (_booked or boarding()) else BUTTON
		)
		_cap.position.y = (
			point_at(distance_of(BOARDS_AT)).y + CAR_FLOOR + BUTTON_HEIGHT
			+ (0.0 if _booked else 0.06)
		)

	# The harnesses come down as the train leaves and go up as it stops, over
	# about a second, which is how long the real ones take.
	var wanted := 0.0 if boarding() else 1.0
	_locked = move_toward(_locked, wanted, delta / HARNESS_TIME)
	for hinge in _harnesses:
		# About the car's own across-axis, so the pads swing down in front of
		# the rider rather than out of the side of the car.
		hinge.rotation.z = -HARNESS_DROP * _locked
	_moved.clear()
	for index in _cars.size():
		_moved.append(_cars[index].position - before[index])

## Where a rider stands in a car, in the car's own frame: on the floor, in
## front of the seat back, under the harness.
const SEAT_SPOT := Vector3(0.06, 0.12, 0.0)

## Where the rider of the car this point is in belongs, in the world — or a
## point of NANs if it is in no car at all.
##
## This is what holds a child in through a loop. Everywhere else on the
## fairground a ride says how far it has moved somebody and the game moves
## them by that much, which is right for a floor that slides along under their
## feet. It is useless in a loop: the car is turning as well as travelling, so
## "how far the car moved" and "how far the rider should move" stop being the
## same number the moment the track leaves the horizontal, and the difference
## is a child left behind in mid-air. A seat is a place, so the ride names the
## place.
## The seat carries a facing as well as a place. A rider goes over the top of
## a loop the way the car does — upside down — and a child held at the right
## point but kept resolutely upright is the one thing about the ride that
## looked wrong from the phone.
func seat_under(at: Vector3) -> Transform3D:
	for index in _cars.size():
		var frame := _cars[index].global_transform
		var local := frame.affine_inverse() * at
		if absf(local.x) < 0.95 and absf(local.z) < 0.65 and local.y > -0.4 and local.y < 2.0:
			# A car's forward is its own +x and a child's is their own -z, so
			# the seat's facing is the car's turned a quarter.
			return Transform3D(
				frame.basis * Basis(Vector3.UP, -PI * 0.5), frame * SEAT_SPOT
			)
	return Transform3D(Basis(), Vector3(NAN, NAN, NAN))

## Where a child is put down if they have to leave a car: on the platform,
## level with its boards, beside the door they got in by.
func platform_spot() -> Vector3:
	var at := point_at(distance_of(BOARDS_AT))
	return global_position + Vector3(at.x + 2.6, at.y + CAR_FLOOR + 0.15, at.z)

## Should whoever is standing here be put off?
##
## Anybody in a car once the train has left the platform who is not strapped
## in is somebody who did not pay: the bars come down for a ticket and for
## nothing else. Riding a coaster unrestrained is the one thing on this
## fairground that must not be possible, and until now it was — stand in a car
## without paying, wait, and it set off with you.
func must_get_off(at: Vector3, strapped: bool) -> bool:
	if boarding() or strapped:
		return false
	return not is_nan(seat_under(at).origin.x)

## How far each car moved on the last frame, for whoever is riding in it.
var _moved: Array[Vector3] = []
## Every shoulder harness on the train, and how far down they are: nought at
## the platform, one on the ride.
var _harnesses: Array[Node3D] = []
var _locked := 1.0
var _cleared_to_board := false
var _rider_aboard := false

## How far the ride moves whoever is aboard, this frame.
##
## Godot leaves a character standing in a body that is moved by hand: the car
## goes out from under them and they drop back onto its floor, over and over.
## So the ride says how far it has taken them and the game moves them by that.
func carry(at: Vector3, _delta: float) -> Vector3:
	for index in _cars.size():
		if index >= _moved.size():
			break
		var local := _cars[index].global_transform.affine_inverse() * at
		if absf(local.x) < 0.95 and absf(local.z) < 0.65 and local.y > -0.4 and local.y < 2.0:
			return _moved[index]
	return Vector3.ZERO

## Move the train along by one frame of physics.
##
## Four regimes, and the whole ride is in them: standing at the platform, being
## dragged up the chain at a steady pace, running free under gravity and drag,
## and being brought to a stand by the brakes on the way in.
func _roll(delta: float) -> void:
	var total := circuit()
	if _waiting > 0.0:
		_waiting -= delta
		_speed = 0.0
		return

	var fraction := base_fraction_at(_at_distance)
	if fraction < LIFT_TOP:
		# Out of the station and up the chain: a steady pull, whatever the
		# hill does. This has to cover the station itself as well as the lift,
		# or the brakes that stopped the train there hold it there for ever —
		# which is exactly what they did.
		_speed = move_toward(_speed, LIFT_SPEED, LIFT_PULL * delta)
	elif fraction >= BRAKES_FROM:
		# In the brakes on the run home. Down to a crawl rather than to a
		# stand: it has to reach the platform to stop at it.
		_speed = move_toward(_speed, CRAWL, BRAKE * delta)
	else:
		# Free running: gravity along the slope, and a little drag. A crest
		# taken slowly is a car still slowing as it goes over, which is the
		# part of a coaster that makes a child hold their breath.
		var grade := gradient_at(_at_distance / total)
		_speed += (-GRAVITY * grade - DRAG * _speed) * delta
		_speed = clampf(_speed, CRAWL * 0.4, TOP_SPEED)

	var was := _at_distance
	_at_distance = fposmod(_at_distance + _speed * delta, total)

	# Pull up at the platform once a lap, on the way past it.
	var stop_at := distance_of(BOARDS_AT)
	var passed := was < stop_at and _at_distance >= stop_at
	if was > _at_distance:
		# Round the end of the lap.
		passed = passed or stop_at >= was or stop_at <= _at_distance
	if passed and _booked:
		_at_distance = stop_at
		_speed = 0.0
		_waiting = DWELL
		_booked = false

## How high the ride goes, and where the leading car is. For the checks.
func highest() -> float:
	var top := 0.0
	for key: Array in PROFILE:
		top = maxf(top, float(key[1]))
	return top

## How many cars the train has, and where one of them is. For the game, which
## has to know whether somebody is sitting in one, and for the checks.
func car_count() -> int:
	return _cars.size()

func car_at(index: int) -> Node3D:
	return _cars[index]

func car_distance() -> float:
	return _at_distance
