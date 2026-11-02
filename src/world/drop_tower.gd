class_name DropTower
extends Node3D

## A lattice tower with a ring of seats that climbs it slowly and falls.
##
## Runs on its own, all day, the way the carousel does — there is no button
## and no ticket taken at a gate. A child steps onto the ring while it stands
## at the ground, it waits a few seconds for anyone still arriving, climbs to
## the top, holds there, and falls — fast at first, the way a real drop does,
## eased into a stop rather than hitting the ground at the speed it fell at.
## Then it stands at the ground again for the next child.

## Three times the big wheel's own height: doubled once, then half as high
## again — the wheel's height was the first measure taken, so it is kept as
## the thing multiplied rather than thrown away each time a bigger number is
## wanted.
const HEIGHT := (FerrisWheel.RADIUS * 2.0 + 2.9) * 3.0

## How far the ring actually travels. The crown of the tower stands clear
## above it at the top of the climb, the way the chimney stands clear of the
## café's own ceiling — a ride that reaches the very top of its own tower has
## nothing left above it to read as a tower at all.
const TRAVEL := HEIGHT - 9.0

## The boarding platform: a plain five-by-five deck at the foot of the tower,
## the way the wheel and the coaster each have their own. Without one there
## was only sand to stand on while the seats — now out past the edge of the
## ring rather than under it — swung in low over a child's head on their way
## down. Sixteen metres on a side: five left the seats, which hang 3.2 m out
## from the shaft, resting out over the sand; eight held them, and was then
## asked for four times over, which is room for a queue to stand round it.
const PLATFORM_SIZE := 16.0
const PLATFORM_HEIGHT := 0.3

## How far below the ring's own deck a seat's cushion lies: the arm drops the
## seat 0.55 m, the cushion sits 0.98 m below that, and is 0.1 m thick.
const SEAT_BELOW_RING := 0.55 + 0.98 - 0.05
## How far above the platform a seat's cushion comes to rest: a small step,
## the kind a child walks up without jumping. The ring used to rest so high
## that every cushion stood 0.7 m off the deck, and nobody could get into one.
const SEAT_STEP := 0.12
## How far above the cushion the harness hinges: the coaster's own height
## above the floor its riders stand on, so it swings down onto the
## shoulders rather than in front of the knees.
const HARNESS_HINGE := 1.42

## The ring's height off the ground at rest, set by where the seats have to
## land rather than by the ring itself.
const GROUND_Y := PLATFORM_HEIGHT + SEAT_STEP + SEAT_BELOW_RING

## One square shaft rather than four legs on a lattice. A lattice reads well
## from a distance and badly up close: a seat swept round it at a fixed
## radius is inside the frame wherever a leg happens to taper in to meet it,
## and clear of it everywhere else, which on this ride was everywhere a child
## was actually looking. Every real one of these is built the way this is —
## one slim column the ring climbs past on the outside, painted in bands
## rather than a visible lattice at all.
const SHAFT_HALF_WIDTH := 0.7
const BAND_COUNT := 26

const RING_RADIUS := 2.3
const SEATS := 6

## How long the ring waits at the ground for a child to step on, climbs,
## holds at the top, and falls. A whole cycle is close to a minute, the way
## the wheel's own turn is a whole slow look at the valley rather than a quick
## trip round it.
const GROUND_HOLD := 15.0
const ASCEND_TIME := 30.0
const TOP_HOLD := 5.0
const DROP_TIME := 8.0
## How much of the fall's opening speed is there from the first instant
## rather than gathered: nought is a plain drop from rest, one a constant
## speed all the way down.
const DROP_KICK := 0.5

## The same red-orange the coaster's own rail is painted, so the two rides at
## the far end of the ground read as a pair rather than as two unrelated
## things that happen to stand near each other.
const STEEL := RollerCoaster.RAIL
const STEEL_DARK := Color(0.52, 0.20, 0.16)
const DECK := Color(0.30, 0.30, 0.32)
const SEAT_COLOUR := RollerCoaster.HARNESS
const BEACON := Color(0.96, 0.24, 0.20)

enum Phase { GROUND, ASCEND, TOP, DROP }

var _phase := Phase.GROUND
var _phase_time := 0.0
var _ring: AnimatableBody3D
var _beacon_light: OmniLight3D
var _moved := Vector3.ZERO
var _harnesses: Array[Node3D] = []
var _harness_closed := 0.0
var _harness_shapes: Array[CollisionShape3D] = []

func _init(at: Vector3) -> void:
	name = "DropTower"
	position = at

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var solid := StaticBody3D.new()
	solid.name = "Solid"
	add_child(solid)

	_build_tower(tool, solid)
	_build_platform(tool, solid)

	_ring = AnimatableBody3D.new()
	_ring.name = "Ring"
	_ring.sync_to_physics = false
	add_child(_ring)
	_build_ring(_ring)
	_ring.position = Vector3(0.0, GROUND_Y, 0.0)

	Park.commit(tool, self, "Structure")

## The four corner legs and the cross braces between them, in courses up the
## tower — the same vocabulary the shop's roof is laid in, courses rather
## than one tall slab, because courses are what a lattice actually is.
func _build_tower(tool: SurfaceTool, solid: StaticBody3D) -> void:
	var width := SHAFT_HALF_WIDTH * 2.0
	var shaft := BoxMesh.new()
	shaft.size = Vector3(width, HEIGHT, width)
	Park._add(tool, shaft, Transform3D(Basis(), Vector3(0.0, HEIGHT * 0.5, 0.0)), STEEL)
	Park._solid(
		solid, Vector3(width, HEIGHT, width), Transform3D(Basis(), Vector3(0.0, HEIGHT * 0.5, 0.0))
	)

	# The bands: alternating colour the height of the ladder rungs they stand
	# for, wrapped a fraction proud of the shaft's own face so they read as
	# paint rather than disappear into it.
	for band in BAND_COUNT:
		var y := HEIGHT * (float(band) + 0.5) / float(BAND_COUNT)
		var stripe := BoxMesh.new()
		stripe.size = Vector3(width + 0.04, HEIGHT / float(BAND_COUNT) * 0.45, width + 0.04)
		Park._add(
			tool, stripe, Transform3D(Basis(), Vector3(0.0, y, 0.0)),
			Color(0.96, 0.92, 0.88) if band % 2 == 0 else STEEL_DARK
		)

	# The crown: a small cap above where the ring ever reaches, with the
	# beacon a child looks for across the valley the way they look for the
	# wheel's own rim.
	var cap := CylinderMesh.new()
	cap.top_radius = 0.1
	cap.bottom_radius = SHAFT_HALF_WIDTH * 1.6
	cap.height = 1.6
	cap.radial_segments = 8
	Park._add(tool, cap, Transform3D(Basis(), Vector3(0.0, HEIGHT + 0.8, 0.0)), STEEL_DARK)
	var beacon := SphereMesh.new()
	beacon.radius = 0.22
	beacon.height = 0.4
	beacon.radial_segments = 8
	beacon.rings = 5
	Park._add(tool, beacon, Transform3D(Basis(), Vector3(0.0, HEIGHT + 1.7, 0.0)), BEACON)
	_beacon_light = OmniLight3D.new()
	_beacon_light.light_color = BEACON
	_beacon_light.omni_range = 6.0
	_beacon_light.light_energy = 1.4
	_beacon_light.shadow_enabled = false
	_beacon_light.position = Vector3(0.0, HEIGHT + 1.7, 0.0)
	add_child(_beacon_light)

## A straight bar between two points, as a box rather than a cylinder — the
## same trick the café's rib bones use, since a lattice beam reads from one
## side only and a box is cheaper than a cylinder for something nobody walks
## round.
static func _beam(tool: SurfaceTool, a: Vector3, b: Vector3, thickness: float, colour: Color) -> void:
	var mid := a.lerp(b, 0.5)
	var length := a.distance_to(b)
	if length < 0.001:
		return
	var beam := BoxMesh.new()
	beam.size = Vector3(thickness, length, thickness)
	var up := (b - a).normalized()
	var axis := Vector3.UP.cross(up)
	var basis := Basis()
	if axis.length_squared() > 0.0001:
		basis = Basis(axis.normalized(), Vector3.UP.angle_to(up))
	elif up.y < 0.0:
		basis = Basis(Vector3.RIGHT, PI)
	Park._add(tool, beam, Transform3D(basis, mid), colour)


## A plain deck at the foot of the tower, five metres on a side, with a short
## step up from the sand — the same thing the wheel and the coaster each stand
## a boarding platform on, built here because this ride never had one and
## stood on bare sand instead.
func _build_platform(tool: SurfaceTool, solid: StaticBody3D) -> void:
	var deck := BoxMesh.new()
	deck.size = Vector3(PLATFORM_SIZE, PLATFORM_HEIGHT, PLATFORM_SIZE)
	Park._add(tool, deck, Transform3D(Basis(), Vector3(0.0, PLATFORM_HEIGHT * 0.5, 0.0)), DECK)
	Park._solid(
		solid, Vector3(PLATFORM_SIZE, PLATFORM_HEIGHT, PLATFORM_SIZE),
		Transform3D(Basis(), Vector3(0.0, PLATFORM_HEIGHT * 0.5, 0.0))
	)
	var step := BoxMesh.new()
	step.size = Vector3(1.6, PLATFORM_HEIGHT * 0.5, 0.6)
	Park._add(
		tool, step,
		Transform3D(Basis(), Vector3(PLATFORM_SIZE * 0.5 + 0.3, PLATFORM_HEIGHT * 0.25, 0.0)), DECK
	)
	Park._solid(
		solid, Vector3(1.6, PLATFORM_HEIGHT * 0.5, 0.6),
		Transform3D(Basis(), Vector3(PLATFORM_SIZE * 0.5 + 0.3, PLATFORM_HEIGHT * 0.25, 0.0))
	)

## The ring itself: a deck, a rim, and seats facing out, built onto the body
## that climbs — drawn once here rather than in _init, since this is the one
## part of the ride that is not scenery.
func _build_ring(body: AnimatableBody3D) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var deck := CylinderMesh.new()
	deck.top_radius = RING_RADIUS
	deck.bottom_radius = RING_RADIUS
	deck.height = 0.18
	deck.radial_segments = 20
	Park._add(tool, deck, Transform3D(Basis(), Vector3.ZERO), DECK)
	var pad := CylinderShape3D.new()
	pad.radius = RING_RADIUS
	pad.height = 0.2
	var collider := CollisionShape3D.new()
	collider.shape = pad
	body.add_child(collider)

	var rim := TorusMesh.new()
	rim.inner_radius = RING_RADIUS - 0.08
	rim.outer_radius = RING_RADIUS + 0.08
	rim.rings = 20
	rim.ring_segments = 8
	Park._add(tool, rim, Transform3D(Basis(), Vector3(0.0, 0.09, 0.0)), STEEL)

	_harnesses.clear()
	_harness_shapes.clear()
	for seat in SEATS:
		var angle := TAU * float(seat) / float(SEATS)
		var out := Vector3(cos(angle), 0.0, sin(angle))
		# The rim, where the arm starts, and the seat itself, well past the
		# edge of the deck rather than tucked under it — a seat hung straight
		# down from the middle of the ring sits under the disc and reads as a
		# cluster of legs beneath a roof; swung out past the rim on its own
		# arm, it reads the way every reference photo of the real ride does,
		# as a row of seats round the *outside* of it.
		var rim_at := out * RING_RADIUS
		var spot := out * (RING_RADIUS + 0.9) + Vector3(0.0, -0.55, 0.0)
		# Local +x is straight out from the shaft, so a rider faces the valley
		# with their back to the tower. It used to point along the ring, which
		# turned every seat sideways to the way it was drawn.
		var facing := Basis(Vector3.UP, -angle)
		var cushion_top := -SEAT_BELOW_RING + 0.55

		# A stand-up seat, the way the real ones are: a tall back from the
		# cushion to above a child's head, with a headrest and side bolsters.
		# The back used to stop at the chest, and the harness hinged on it came
		# down in front of the knees and hung there.
		var back_height := HARNESS_HINGE + 0.12
		var seat_back := BoxMesh.new()
		seat_back.size = Vector3(0.16, back_height, 0.56)
		Park._add(
			tool, seat_back,
			Transform3D(facing, spot + facing * Vector3(-0.24, cushion_top + back_height * 0.5, 0.0)),
			SEAT_COLOUR.darkened(0.3)
		)
		var headrest := BoxMesh.new()
		headrest.size = Vector3(0.14, 0.3, 0.36)
		Park._add(
			tool, headrest,
			Transform3D(facing, spot + facing * Vector3(-0.12, cushion_top + 1.38, 0.0)),
			SEAT_COLOUR.darkened(0.15)
		)
		for shoulder: float in [-1.0, 1.0]:
			var bolster := BoxMesh.new()
			bolster.size = Vector3(0.22, 0.9, 0.1)
			Park._add(
				tool, bolster,
				Transform3D(facing, spot + facing * Vector3(-0.12, cushion_top + 0.7, shoulder * 0.28)),
				SEAT_COLOUR.darkened(0.2)
			)

		# The arm: from the rim out to the top of the seat's back, which is
		# where a seat like this is carried from.
		_beam(
			tool, rim_at + Vector3(0.0, -0.04, 0.0),
			spot + facing * Vector3(-0.3, cushion_top + back_height - 0.1, 0.0), 0.12, STEEL_DARK
		)
		_beam(
			tool, rim_at + Vector3(0.0, -0.04, 0.0),
			spot + facing * Vector3(-0.3, cushion_top + 0.2, 0.0), 0.08, STEEL_DARK
		)

		var seat_base := BoxMesh.new()
		seat_base.size = Vector3(0.46, 0.1, 0.5)
		var seat_base_at := spot + facing * Vector3(0.02, cushion_top - 0.05, 0.0)
		Park._add(tool, seat_base, Transform3D(facing, seat_base_at), SEAT_COLOUR.darkened(0.3))
		# A seat drawn with nothing to stand on is a picture of a seat, not
		# one: the deck's own collision pad reaches only to the rim, and every
		# seat hangs well past it on its own arm. Each seat gets a footing of
		# its own, generous enough to step onto and topped exactly at the
		# cushion.
		var seat_shape := BoxShape3D.new()
		seat_shape.size = Vector3(0.7, 0.3, 0.7)
		var seat_collider := CollisionShape3D.new()
		seat_collider.shape = seat_shape
		seat_collider.position = seat_base_at + Vector3(0.0, 0.05 - 0.15, 0.0)
		body.add_child(seat_collider)

		# The restraint: the coaster's own over-the-shoulder harness, hinged
		# at the same height above the rider's feet as the coaster's is, above
		# the head. Open, the pads stand out level over the seat; closed, they
		# swing down onto the shoulders with the lap bar across the front.
		var hinge := Node3D.new()
		hinge.name = "Harness"
		hinge.position = spot + facing * Vector3(-0.14, cushion_top + HARNESS_HINGE, 0.0)
		hinge.basis = facing
		body.add_child(hinge)
		_harnesses.append(hinge)

		# Drawn as slim tubes, not the coaster's chunky pads: the rider looks
		# out through this harness for the whole ride, and the solid slabs it
		# used to be filled the view in front of the camera. What holds is the
		# collision box below, not the thickness of the drawing.
		var harness := SurfaceTool.new()
		harness.begin(Mesh.PRIMITIVE_TRIANGLES)
		var tip := RollerCoaster.HARNESS_REACH + RollerCoaster.HARNESS_PAD * 0.5
		for shoulder: float in [-1.0, 1.0]:
			var shoulder_bar := BoxMesh.new()
			shoulder_bar.size = Vector3(RollerCoaster.HARNESS_PAD, 0.07, 0.07)
			Park._add(
				harness, shoulder_bar,
				Transform3D(Basis(), Vector3(RollerCoaster.HARNESS_REACH, -0.06, shoulder * 0.26)),
				RollerCoaster.HARNESS
			)
			# A short soft sleeve where the bar meets the shoulder.
			var sleeve := BoxMesh.new()
			sleeve.size = Vector3(0.26, 0.1, 0.1)
			Park._add(
				harness, sleeve,
				Transform3D(Basis(), Vector3(RollerCoaster.HARNESS_REACH - 0.1, -0.08, shoulder * 0.26)),
				RollerCoaster.HARNESS.darkened(0.2)
			)
			var drop_rod := BoxMesh.new()
			drop_rod.size = Vector3(0.06, 0.5, 0.06)
			Park._add(
				harness, drop_rod,
				Transform3D(Basis(Vector3.BACK, deg_to_rad(18.0)), Vector3(tip + 0.04, -0.30, shoulder * 0.26)),
				RollerCoaster.HARNESS
			)
		var yoke := BoxMesh.new()
		yoke.size = Vector3(0.08, 0.07, 0.6)
		Park._add(harness, yoke, Transform3D(Basis(), Vector3(0.14, -0.06, 0.0)), RollerCoaster.HARNESS)
		var lap_bar := BoxMesh.new()
		lap_bar.size = Vector3(0.07, 0.07, 0.6)
		Park._add(harness, lap_bar, Transform3D(Basis(), Vector3(tip + 0.12, -0.54, 0.0)), RollerCoaster.HARNESS)
		var clasp := BoxMesh.new()
		clasp.size = Vector3(0.1, 0.12, 0.12)
		Park._add(
			harness, clasp, Transform3D(Basis(), Vector3(tip + 0.13, -0.6, 0.0)),
			RollerCoaster.HARNESS.darkened(0.45)
		)
		Park.commit(harness, hinge, "Pads")

		# And a closed harness holds, the way the coaster's does: a solid
		# where the lowered pads are, switched on only once they are down so
		# it never closes on somebody stepping in. Ninety metres up is not
		# the place to find a harness is only a drawing.
		var reach := RollerCoaster.HARNESS_REACH + RollerCoaster.HARNESS_PAD * 0.5
		var pad_shape := BoxShape3D.new()
		pad_shape.size = Vector3(0.5, 0.42, 0.9)
		var pads := CollisionShape3D.new()
		pads.shape = pad_shape
		pads.basis = facing
		pads.position = spot + facing * Vector3(
			-0.14 + cos(RollerCoaster.HARNESS_DROP) * reach,
			cushion_top + HARNESS_HINGE - sin(RollerCoaster.HARNESS_DROP) * reach,
			0.0
		)
		pads.disabled = true
		body.add_child(pads)
		_harness_shapes.append(pads)

	Park.commit(tool, body, "Deck")

func _physics_process(delta: float) -> void:
	var before := _ring.position.y
	_phase_time += delta
	match _phase:
		Phase.GROUND:
			if _phase_time >= GROUND_HOLD:
				_phase = Phase.ASCEND
				_phase_time = 0.0
		Phase.ASCEND:
			var t := clampf(_phase_time / ASCEND_TIME, 0.0, 1.0)
			_ring.position.y = GROUND_Y + TRAVEL * smoothstep(0.0, 1.0, t)
			if t >= 1.0:
				_phase = Phase.TOP
				_phase_time = 0.0
		Phase.TOP:
			_ring.position.y = GROUND_Y + TRAVEL
			if _phase_time >= TOP_HOLD:
				_phase = Phase.DROP
				_phase_time = 0.0
		Phase.DROP:
			var u := clampf(_phase_time / DROP_TIME, 0.0, 1.0)
			# Not let go of but thrown down: the ring leaves the top already
			# moving fast, the kick a launched drop gives, and keeps gathering
			# speed from there; then it is eased into a stop over the last
			# fifth rather than arriving at the ground at the speed it fell
			# at, which a real ride brakes for and this one has to fake.
			var fallen: float
			if u < 0.8:
				var v := u / 0.8
				fallen = (DROP_KICK * v + (1.0 - DROP_KICK) * v * v) * 0.92
			else:
				var v := (u - 0.8) / 0.2
				fallen = 0.92 + 0.08 * smoothstep(0.0, 1.0, v)
			_ring.position.y = GROUND_Y + TRAVEL * (1.0 - fallen)
			if u >= 1.0:
				_ring.position.y = GROUND_Y
				_phase = Phase.GROUND
				_phase_time = 0.0
	_moved = Vector3(0.0, _ring.position.y - before, 0.0)
	_beacon_light.light_energy = 1.0 + 0.6 * sin(Time.get_ticks_msec() * 0.004)

	# Down the moment the ring leaves the ground, up again once it is back —
	# "bars down, we are going" is the one cue a child already knows from the
	# coaster, and a harness that is always down teaches nothing.
	var wanted := 0.0 if _phase == Phase.GROUND else 1.0
	_harness_closed = move_toward(_harness_closed, wanted, delta / RollerCoaster.HARNESS_TIME)
	for hinge in _harnesses:
		hinge.rotation.z = -RollerCoaster.HARNESS_DROP * _harness_closed
	for pads in _harness_shapes:
		pads.disabled = _harness_closed < 0.99

## How far out from the axle a seat's own reach goes, and how far below the
## deck its lowest point hangs. The seats stand well clear of the ring itself
## now, on their own arms — this is what lets carry() and aboard() find
## somebody actually sitting in one rather than only somebody standing on the
## bare deck at the middle, which a seat built to hang outside of leaves
## nobody ever sitting in by this measure.
const SEAT_REACH := RING_RADIUS + 1.7
const SEAT_DROP := 1.9

## How far the ring moved whoever is standing on it, this frame. Mirrors
## FerrisWheel.carry() — the ring is moved by hand, not by the engine, so a
## passenger has to be moved with it by hand too.
func carry(at: Vector3, _delta: float) -> Vector3:
	if _on_the_ring(at):
		return _moved
	return Vector3.ZERO

## Whether a point is aboard the ring at all, moving or not — for the
## fairground's own ride_under(), which asks this and not carry() because a
## ring waiting at the ground between climbs is still a ride somebody is on.
func aboard(at: Vector3) -> bool:
	return _on_the_ring(at)

## Whether a point is on the ring or in one of its seats, rather than on the
## platform under it.
##
## The reach alone could not tell them apart: at rest the ring hangs only
## 1.6 m over the deck, so a child walking about on the platform within four
## metres of the shaft — under the ring, or beside a seat — stood inside the
## box SEAT_DROP below it, was asked for a ticket and, once they had paid,
## was lifted off the deck with the seats. A rider's feet are on the cushion,
## SEAT_BELOW_RING under the ring; a child on the platform is a step lower
## again. The ring is moved after the child is, so a rider is up to one
## frame's climb below where they are about to be put, and that much is
## allowed for.
func _on_the_ring(at: Vector3) -> bool:
	var local := at - _ring.global_position
	var lowest := -SEAT_BELOW_RING - SEAT_STEP * 0.5 - absf(_moved.y)
	return (
		absf(local.x) < SEAT_REACH and absf(local.z) < SEAT_REACH
		and local.y > maxf(lowest, -SEAT_DROP) and local.y < 2.2
	)

## How high the ring has climbed right now. For the checks.
func ring_height() -> float:
	return _ring.position.y
