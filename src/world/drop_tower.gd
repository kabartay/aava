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
## Where the harness comes to rest when it is down, from the hinge: how far it
## swings (the arm is nearly upright, behind the head, when it is closed), the
## pad over each shoulder (forward of the hinge, below it), the rod and the lap
## bar (the same, and across from the middle). Measured on the five children
## seated, whose shoulders are 0.5 above the cushion and whose heads reach 1.2:
## the coaster's own, drawn for grown riders, came down across the face.
const HARNESS_CLOSE := deg_to_rad(70.0)
const HARNESS_ACROSS := 0.36
const HARNESS_PAD_BACK := 0.14
const HARNESS_PAD_DOWN := -0.77
const HARNESS_LAP_AHEAD := 0.44
const HARNESS_LAP_DOWN := -1.14

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
## The ring deck's thickness, drawn and collided alike.
const RING_THICKNESS := 0.18
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
const SAFETY := Color(0.92, 0.76, 0.22)
## The squat block the shaft stands on: a little wider than the shaft, and far
## inside the ring's own radius.
const PLINTH_SIZE := SHAFT_HALF_WIDTH * 2.0 + 0.7
const PLINTH_HEIGHT := 0.6
const SEAT_COLOUR := RollerCoaster.HARNESS
const BEACON := Color(0.96, 0.24, 0.20)

enum Phase { GROUND, ASCEND, TOP, DROP }

## The ring has been let go at the top, for the sound of it.
signal dropped

var _phase := Phase.GROUND
var _phase_time := 0.0
var _ring: AnimatableBody3D
var _beacon_light: OmniLight3D
var _moved := Vector3.ZERO
var _held := false
## How long before it goes a held ring is kept, in seconds.
const HELD_LEAD := 3.0
var _harnesses: Array[Node3D] = []
var _harness_closed := 0.0
var _harness_shapes: Array[CollisionShape3D] = []
## Every seat, in the ring's own frame: the top of the cushion, facing out.
var _seats: Array[Transform3D] = []
## The wait at the ground is over and the harnesses are coming down. The ring
## does not leave until they are down: it used to start climbing on the same
## frame they began to close, so for the first second of the ascent a child sat
## under a bar that was still on its way.
var _closing := false
## The seat the rider is held to while the ring moves, and where in that seat
## they sit (in the seat's own frame, so a child is held where they were and
## not snapped to a point).
var _strap_seat := -1
var _strap_local := Vector3.ZERO

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
	# A bare dark slab reads as a sheet of tarmac, not a deck. A yellow safety
	# border is painted along each edge (flush, a hair above the surface, so
	# the collider still describes what is drawn) and the tower stands on a
	# squat plinth with its own collider, well inside the ring's 2.3 m sweep.
	var border := 0.35
	var edge := PLATFORM_SIZE * 0.5 - border * 0.5
	for side: float in [-1.0, 1.0]:
		var along_x := BoxMesh.new()
		along_x.size = Vector3(PLATFORM_SIZE, 0.02, border)
		Park._add(tool, along_x, Transform3D(Basis(), Vector3(0.0, PLATFORM_HEIGHT + 0.01, side * edge)), SAFETY)
		var along_z := BoxMesh.new()
		along_z.size = Vector3(border, 0.02, PLATFORM_SIZE - border * 2.0)
		Park._add(tool, along_z, Transform3D(Basis(), Vector3(side * edge, PLATFORM_HEIGHT + 0.01, 0.0)), SAFETY)
	var plinth := BoxMesh.new()
	plinth.size = Vector3(PLINTH_SIZE, PLINTH_HEIGHT, PLINTH_SIZE)
	var plinth_at := Transform3D(Basis(), Vector3(0.0, PLATFORM_HEIGHT + PLINTH_HEIGHT * 0.5, 0.0))
	Park._add(tool, plinth, plinth_at, STEEL_DARK)
	Park._solid(solid, plinth.size, plinth_at)
	var collar := BoxMesh.new()
	collar.size = Vector3(PLINTH_SIZE * 0.8, 0.08, PLINTH_SIZE * 0.8)
	Park._add(tool, collar, Transform3D(Basis(), Vector3(0.0, PLATFORM_HEIGHT + PLINTH_HEIGHT + 0.04, 0.0)), DECK)
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
	deck.height = RING_THICKNESS
	deck.radial_segments = 20
	Park._add(tool, deck, Transform3D(Basis(), Vector3.ZERO), DECK)
	var pad := CylinderShape3D.new()
	pad.radius = RING_RADIUS
	pad.height = RING_THICKNESS
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
	_seats.clear()
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
		# Where a child sits, on the ring's own frame: the top of the cushion,
		# turned to face out (a child's -z is the seat's +x).
		_seats.append(Transform3D(
			facing * Basis(Vector3.UP, -PI * 0.5),
			spot + facing * Vector3(0.02, cushion_top, 0.0)
		))

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

		# What carries the seat: a stout upright behind its back, from the
		# ring down to under the cushion, bolted to the rim by a deep bracket
		# at the top and a gusset below. Two thin rods from the rim used to
		# hold it, and the seats read as hung off the ring on wires rather
		# than fixed to it.
		var post_x := -0.44
		var post_top := -spot.y + 0.12
		var post_bottom := cushion_top - 0.12
		var post := BoxMesh.new()
		post.size = Vector3(0.24, post_top - post_bottom, 0.34)
		Park._add(
			tool, post,
			Transform3D(facing, spot + facing * Vector3(post_x, (post_top + post_bottom) * 0.5, 0.0)),
			STEEL_DARK
		)
		var bracket_from := RING_RADIUS - 0.15
		var bracket_to := RING_RADIUS + 0.9 + post_x
		var bracket := BoxMesh.new()
		bracket.size = Vector3(bracket_to - bracket_from, 0.26, 0.3)
		Park._add(
			tool, bracket,
			Transform3D(facing, out * ((bracket_from + bracket_to) * 0.5) + Vector3(0.0, -0.02, 0.0)),
			STEEL_DARK
		)
		_beam(
			tool, rim_at + Vector3(0.0, -0.1, 0.0),
			spot + facing * Vector3(post_x, cushion_top + 0.35, 0.0), 0.16, STEEL_DARK
		)
		# Bolted to the back, top and bottom, so the seat is part of the post.
		for clamp_y: float in [cushion_top + 0.3, cushion_top + back_height - 0.25]:
			var clamp := BoxMesh.new()
			clamp.size = Vector3(0.14, 0.12, 0.42)
			Park._add(
				tool, clamp,
				Transform3D(facing, spot + facing * Vector3(-0.33, clamp_y, 0.0)),
				STEEL
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
		# The coaster's own harness was drawn for a grown rider and, swung down
		# on a child, ran from above the head to a metre in front of the chest:
		# a bar across the face. A child sits a head lower, so this one is drawn
		# as it lies CLOSED, from where it must come to rest (a pad over each
		# shoulder, a rod in front of the chest down to a bar over the lap),
		# and turned back about the hinge into the position it opens to. The
		# positions below are (forward, up, across) from the hinge, closed.
		var undo := Basis(Vector3.BACK, HARNESS_CLOSE)
		for shoulder: float in [-1.0, 1.0]:
			var across := shoulder * HARNESS_ACROSS
			var arm_foot := undo * Vector3(HARNESS_PAD_BACK, HARNESS_PAD_DOWN + 0.07, across)
			var pad_back := undo * Vector3(HARNESS_PAD_BACK, HARNESS_PAD_DOWN, across)
			var pad_front := undo * Vector3(HARNESS_LAP_AHEAD, HARNESS_PAD_DOWN - 0.07, across)
			var lap_end := undo * Vector3(HARNESS_LAP_AHEAD, HARNESS_LAP_DOWN, across)
			# The arm from the hinge, the pad lying on the shoulder, and the
			# rod down to the lap bar.
			_beam(harness, undo * Vector3(0.0, 0.0, across), arm_foot, 0.07, RollerCoaster.HARNESS)
			_beam(harness, pad_back, pad_front, 0.1, RollerCoaster.HARNESS.darkened(0.2))
			_beam(harness, pad_front, lap_end, 0.06, RollerCoaster.HARNESS)
		_beam(
			harness, undo * Vector3(0.0, 0.0, -HARNESS_ACROSS), undo * Vector3(0.0, 0.0, HARNESS_ACROSS),
			0.08, RollerCoaster.HARNESS
		)
		_beam(
			harness, undo * Vector3(HARNESS_LAP_AHEAD, HARNESS_LAP_DOWN, -HARNESS_ACROSS),
			undo * Vector3(HARNESS_LAP_AHEAD, HARNESS_LAP_DOWN, HARNESS_ACROSS),
			0.07, RollerCoaster.HARNESS
		)
		var clasp := BoxMesh.new()
		clasp.size = Vector3(0.12, 0.1, 0.12)
		Park._add(
			harness, clasp, Transform3D(undo, undo * Vector3(HARNESS_LAP_AHEAD, HARNESS_LAP_DOWN, 0.0)),
			RollerCoaster.HARNESS.darkened(0.45)
		)
		Park.commit(harness, hinge, "Pads")

		# And a closed harness holds, the way the coaster's does: a solid
		# where the lowered pads are, switched on only once they are down so
		# it never closes on somebody stepping in. Ninety metres up is not
		# the place to find a harness is only a drawing.
		# It is the rods and the lap bar, which is where a child would walk
		# out: the first thing in front of the seat is 0.34 m out, the width of
		# the player's own body, so it is drawn no further in than that.
		var held_down := (HARNESS_PAD_DOWN - 0.07 + HARNESS_LAP_DOWN) * 0.5
		var pad_shape := BoxShape3D.new()
		pad_shape.size = Vector3(0.14, absf(HARNESS_PAD_DOWN - 0.07 - HARNESS_LAP_DOWN) + 0.12, HARNESS_ACROSS * 2.0 + 0.1)
		var pads := CollisionShape3D.new()
		pads.shape = pad_shape
		pads.basis = facing
		pads.position = spot + facing * Vector3(
			-0.14 + HARNESS_LAP_AHEAD + 0.07,
			cushion_top + HARNESS_HINGE + held_down,
			0.0
		)
		pads.disabled = true
		body.add_child(pads)
		_harness_shapes.append(pads)

	Park.commit(tool, body, "Deck")

## The game says whether somebody sits on the ring who has not paid for this
## go. While they do, it stays at the ground with its harnesses up, which is
## also the way off: nobody is ever shut in by it.
func hold_at_ground(held: bool) -> void:
	_held = held

## Whether this phone's own child, or (on the host) a child on another phone,
## is sitting on the ring without a ticket for this go.
func _is_held() -> bool:
	if _held:
		return true
	for peer: Variant in _sync_holds:
		if bool(_sync_holds[peer]):
			return true
	return false

## Whether this phone's own child is the one keeping the ring down. For the
## sync, which tells the host.
func held() -> bool:
	return _held

func _physics_process(delta: float) -> void:
	var before := _ring.position.y
	_phase_time += _sync_step(delta)
	match _phase:
		Phase.GROUND:
			# Somebody is in a seat who has not paid: the ring waits for them
			# rather than carrying them. It is moved by hand but its seats are
			# solid, and the engine lifts a child standing on one whether or not
			# the game carries them, so "no" was a free climb. Kept a few
			# seconds short of going, so a yes is not then a quarter-minute wait.
			if _is_held():
				_phase_time = minf(_phase_time, GROUND_HOLD - HELD_LEAD)
				# Somebody has stepped on while the bars were coming down:
				# they come up again, and the ring waits for the answer.
				_closing = false
			elif sync_following:
				# Another phone's ring is the ring: this one closes its bars
				# when that one does and goes when that one goes, and not
				# before its own bars are down.
				_phase_time = minf(_phase_time, GROUND_HOLD)
				_closing = _sync_closing or _sync_go
				if _sync_go and _harness_closed >= 0.99:
					_closing = false
					_sync_go = false
					_phase = Phase.ASCEND
					_phase_time = _sync_since_go
			elif _phase_time >= GROUND_HOLD:
				# The harnesses come down first; the ring goes when they are
				# down, and not a frame before.
				_closing = true
				_phase_time = GROUND_HOLD
				if _harness_closed >= 0.99:
					_closing = false
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
				dropped.emit()
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
	var wanted := 0.0 if _phase == Phase.GROUND and not _closing else 1.0
	_harness_closed = move_toward(_harness_closed, wanted, delta / RollerCoaster.HARNESS_TIME)
	for hinge in _harnesses:
		hinge.rotation.z = -HARNESS_CLOSE * _harness_closed
	for pads in _harness_shapes:
		pads.disabled = _harness_closed < 0.99

## Are the harnesses down and holding? Down all the way, or still coming up
## from a ride that has just ended: a rider is let go when the bars are most of
## the way up, not on the frame the ring touches the ground while they are still
## across the lap.
func restrained() -> bool:
	return _harness_closed >= 0.99 or (_strap_seat >= 0 and _harness_closed >= 0.25)

## Is the ring clear to go: harnesses down, or about to be? For the checks.
func closing() -> bool:
	return _closing

## Fasten whoever is sitting here to the seat they are in, if they are in one.
## False if they are not on a seat. From then on `strap_place` says where they
## are, outright, every frame: a ring that drops from the top at thirty metres
## a second leaves a child who is only nudged by how far it moved behind it by
## up to a metre, and a child who is pushing the stick or jumping walked off it.
func strap(at: Vector3) -> bool:
	for index in _seats.size():
		var here := _ring.global_transform * _seats[index]
		var local := here.affine_inverse() * at
		if absf(local.x) < 0.4 and absf(local.z) < 0.4 and local.y > -0.2 and local.y < 0.4:
			_strap_seat = index
			_strap_local = local
			return true
	return false

func unstrap() -> void:
	_strap_seat = -1

func strapped() -> bool:
	return _strap_seat >= 0

## Where the strapped rider is, in the world, and the way they face.
func strap_place() -> Transform3D:
	var here := _ring.global_transform * _seats[_strap_seat]
	return Transform3D(here.basis, here * _strap_local)

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

## Every seat as the ring stands now, in the world. For the checks and the
## viewer.
func seats() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for seat in _seats:
		out.append(_ring.global_transform * seat)
	return out

## The seat a child is standing on, or a point of NANs. The footing under a seat
## is 0.7 across, topped at the cushion; the platform and the deck are not seats.
func seat_near(at: Vector3) -> Transform3D:
	for seat in _seats:
		var here := _ring.global_transform * seat
		var local := here.affine_inverse() * at
		if absf(local.x) < 0.4 and absf(local.z) < 0.4 and local.y > -0.2 and local.y < 0.4:
			return here
	return Transform3D(Basis(), Vector3(NAN, NAN, NAN))

## Whether the ring is standing at the ground waiting for its next climb. A
## ticket paid on a ring that has not yet gone has bought nothing yet, so the
## game gives it back to a child who steps off.
func at_rest() -> bool:
	return _phase == Phase.GROUND

## How high the ring has climbed right now. For the checks.
func ring_height() -> float:
	return _ring.position.y


# --- one ring on two phones -----------------------------------------------
#
# The host's ring is the ring. A guest's phone runs the same ring on the same
# timetable, but its clock is steered by what the host says (`sync_apply`): a
# little faster when it is behind, a little slower when it is ahead, never a
# jump in the middle of a climb. Its own safety rules stay its own: the bars
# are down before it moves and a rider is strapped until they are up.

## Is this ring following another phone's? Set by RideSync.
var sync_following := false
## Seconds this ring's clock is behind (positive) or ahead of the host's, still
## to be made up.
var _sync_err := 0.0
## The host has set off from the ground and this ring may too, once its own bars
## are down; and how long ago it did, so the climb begins where theirs is.
var _sync_go := false
var _sync_since_go := 0.0
var _sync_closing := false
## Whether a child on another phone keeps the ring at the ground, by peer id.
## Only the host holds these.
var _sync_holds: Dictionary = {}

## The phase and the clock and the state of the bars: the whole of what a
## guest needs to run the same ring.
const SYNC_LOOP := GROUND_HOLD + ASCEND_TIME + TOP_HOLD + DROP_TIME
## Further out than this and a ring nobody is held in is set to the host's
## outright (on arriving, say); nearer it is only ever steered.
const SYNC_SNAP := 4.0
## How soon after the host sets off a guest's ring may still go with it.
const SYNC_GO_WINDOW := 2.0

static func _sync_clock_of(phase: int, time: float) -> float:
	match phase:
		Phase.GROUND:
			return minf(time, GROUND_HOLD)
		Phase.ASCEND:
			return GROUND_HOLD + minf(time, ASCEND_TIME)
		Phase.TOP:
			return GROUND_HOLD + ASCEND_TIME + minf(time, TOP_HOLD)
	return GROUND_HOLD + ASCEND_TIME + TOP_HOLD + minf(time, DROP_TIME)

## Where in its round the ring is, in seconds.
func sync_clock() -> float:
	return _sync_clock_of(_phase, _phase_time)

func sync_state() -> PackedFloat32Array:
	return PackedFloat32Array([float(_phase), _phase_time, 1.0 if _closing else 0.0])

## The host's state has arrived, `age` seconds old.
func sync_apply(state: PackedFloat32Array, age: float) -> void:
	if state.size() < 3:
		return
	var phase := clampi(int(state[0]), 0, Phase.DROP)
	var time := maxf(state[1], 0.0)
	_sync_closing = state[2] > 0.5
	# A ring waiting at the ground does not age; the others do.
	var now := time if phase == Phase.GROUND else time + age
	_sync_go = phase == Phase.ASCEND and now < SYNC_GO_WINDOW
	_sync_since_go = now
	var err := fposmod(_sync_clock_of(phase, now) - sync_clock() + SYNC_LOOP * 0.5, SYNC_LOOP) - SYNC_LOOP * 0.5
	if absf(err) > SYNC_SNAP and _strap_seat < 0 and not _held:
		_phase = phase as Phase
		_phase_time = now
		_closing = _sync_closing and phase == Phase.GROUND
		if phase != Phase.GROUND:
			_harness_closed = 1.0
		else:
			# The ground branch leaves the ring where it is: set it down.
			_ring.position.y = GROUND_Y
		_sync_go = false
		err = 0.0
	_sync_err = err

## This frame's time: the real one, plus or minus a share of what the ring is
## out by, so the clocks meet without a jump.
func _sync_step(delta: float) -> float:
	if not sync_following or _phase == Phase.GROUND:
		return delta
	var room := delta * clampf(absf(_sync_err), 1.0, 3.0)
	var extra := clampf(_sync_err, -0.5 * delta, room)
	_sync_err -= extra
	return delta + extra

## A child on another phone says whether it keeps the ring at the ground.
func sync_set_hold(peer: int, held: bool) -> void:
	if held:
		_sync_holds[peer] = true
	else:
		_sync_holds.erase(peer)

## That phone has gone.
func sync_forget(peer: int) -> void:
	_sync_holds.erase(peer)

## The seat this phone's own child is in (strapped to, or sitting on), as
## (index, 0, 0), or index -1.
func sync_seat_of(at: Vector3) -> Vector3:
	if _strap_seat >= 0:
		return Vector3(_strap_seat, 0.0, 0.0)
	for index in _seats.size():
		var local := (_ring.global_transform * _seats[index]).affine_inverse() * at
		if absf(local.x) < 0.4 and absf(local.z) < 0.4 and local.y > -0.2 and local.y < 0.4:
			return Vector3(index, 0.0, 0.0)
	return Vector3(-1.0, 0.0, 0.0)

## A seat as it stands now, in the world.
func seat_world(index: int, _along := Vector2.ZERO) -> Transform3D:
	return _ring.global_transform * _seats[clampi(index, 0, _seats.size() - 1)]

## What this phone's own child is doing to the ride, packed for the host.
func sync_flags() -> int:
	return 1 if _held else 0

## A child on another phone's flags, on the host.
func sync_set_flags(peer: int, flags: int) -> void:
	sync_set_hold(peer, flags & 1 != 0)

## What would make the host tell its guests this ride's state at once rather
## than at the next beat.
func sync_signature() -> int:
	return int(_phase) * 2 + (1 if _closing else 0)

## Back to running by itself: the host has gone, or this phone left.
func sync_release() -> void:
	sync_following = false
	_sync_err = 0.0
	_sync_go = false
	_sync_closing = false
	_sync_holds.clear()
