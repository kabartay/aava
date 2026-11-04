class_name PirateShip
extends Node3D

## A boat on a pendulum, swinging between two A-frames the way a playground
## swing does, built at the scale of a ride rather than a seat for one child.
##
## Runs on its own all day, the same as the carousel and the drop tower: no
## button, no queue. It hangs still for a while, long enough to climb aboard,
## then swings — growing wider with every pass rather than starting at full
## throw — holds there for a stretch, and eases back to still for the next
## child.
##
## The boat lies along x and swings along x, towards the river and away from
## it: bow first, then stern first, the way every real one does. The first
## build swung the hull about its own length, rolling it sideways like a
## hammock, with the frames standing inside its length rather than either side
## of it. The axle now runs along z, across the boat, and the two A-frames
## stand either side of the hull's width, where nothing that swings can reach
## them.

## How far the deck hangs below the axle. The ground is only so wide across:
## the ride now swings across the park rather than along it, and its whole
## sweep, keel to keel, has to land inside the fence.
const ARM_LENGTH := 12.0
## How deep the hull goes below the deck amidships.
const KEEL_DEPTH := 1.0
const HULL_LENGTH := 15.0
const HULL_HALF_WIDTH := 2.8
## The flat well riders sit in, from the middle out to each bulkhead. Past
## it the keel curves up towards bow and stern, along a circle about the
## axle, so the ends never dip lower than the middle does at any angle.
const DECK_HALF := 4.2
## The farthest any part of the hull ever gets from the axle: the keel at a
## bulkhead, and everywhere along the curve beyond it.
const REACH := sqrt((ARM_LENGTH + KEEL_DEPTH) * (ARM_LENGTH + KEEL_DEPTH) + DECK_HALF * DECK_HALF)
const GROUND_CLEARANCE := 0.5
const AXLE_HEIGHT := REACH + GROUND_CLEARANCE
## Where the deck stands at rest, and the boarding platform with it.
const DECK_REST := AXLE_HEIGHT - ARM_LENGTH

## The rows, measured out from the middle; one set towards each end, every
## seat facing back towards the middle, the way a real ship's rows face.
const ROWS: Array[float] = [1.5, 3.1]
## Where the two seats of a row stand across the boat, with a wide gap
## between them and room at each side.
const SEAT_ACROSS: Array[float] = [-1.1, 1.1]
const SEAT_WIDTH := 0.8
const SEAT_DEPTH := 0.6
## How high a seat's cushion stands off the deck: a step, not a climb.
const SEAT_TOP := 0.15
## The lap bar of a child's seat. It hinges at the back, 1.0 above the cushion,
## and comes down to rest 0.78 ahead of the hinge and 0.58 below it: over the
## thighs, and level with the solid that holds it (see `_bar_shapes`). The
## grown-up one that was here stood 1.15 up and swung 105 degrees, which left
## the bar at a child's chin, in front of the face.
const BAR_HINGE := 1.0
const BAR_AHEAD := 0.78
const BAR_BELOW := 0.58
const BAR_LENGTH := sqrt(BAR_AHEAD * BAR_AHEAD + BAR_BELOW * BAR_BELOW)
## How far it turns from standing up to lying across the lap, in radians.
const BAR_CLOSE := atan2(BAR_AHEAD, -BAR_BELOW)
## How far out from the seat's middle each side arm of the bar stands: flush
## with the cushion's edge (0.4) less the arm's own half-width. A child who
## glances round turns the head up to 0.75 radians, and the bear's, the widest
## skull of the five, came within 0.269 m of the arm when the arms stood 0.34
## out; 0.37 keeps every child at least 0.29 m clear (see seat_pose.gd for the
## hands, which hold the arms at the same distance).
const ARM_OUT := SEAT_WIDTH * 0.5 - 0.03
## Half the opening in the boat's side that faces the platform.
const GATE_HALF := 0.9

## How far the swing throws at its widest, and how long one swing takes there
## and back.
const MAX_ANGLE := deg_to_rad(60.0)
const SWING_PERIOD := 6.4

## A whole cycle: still long enough to climb aboard, swinging long enough to
## be worth it, easing out rather than stopping dead — the same minute-ish
## shape the drop tower's own cycle has.
const STILL_HOLD := 14.0
const SWING_TIME := 46.0
## How much of SWING_TIME is spent growing from nothing to full throw, and
## how much easing back down to nothing — the rest is held at full throw.
const RAMP_TIME := 10.0

## The two A-frames: their feet far out along x, the planes they stand in
## clear of the hull's width and of the hangers on each side of it.
const FRAME_Z := HULL_HALF_WIDTH + 1.1
const FRAME_SPREAD := 13.0
## How far above the axle the legs meet, on top of the bearing housing.
const BEARING_RISE := 0.9
## Where the hangers run, just outside the hull's own sides.
const HANGER_Z := HULL_HALF_WIDTH + 0.2

## The boarding platform, beside the hull's gate on the +z side, and the ramp
## down from it.
const PLATFORM_FROM := HULL_HALF_WIDTH + 0.45
const PLATFORM_DEPTH := 3.0
const PLATFORM_HALF_X := 2.5
const RAMP_RUN := 5.0
const RAMP_HALF_WIDTH := 0.9

const HULL := Color(0.80, 0.26, 0.20)
const HULL_DARK := Color(0.52, 0.16, 0.13)
const TRIM := Color(0.94, 0.82, 0.40)
const TIMBER := Color(0.52, 0.37, 0.22)
const DECK := Color(0.66, 0.50, 0.32)
## How far the side rails of the raised end decks stand above the gunwale.
const BULWARK := 0.6
const SEAT_COLOUR := Color(0.92, 0.84, 0.30)
const SHIELD := Color(0.22, 0.38, 0.64)
const STEEL := RollerCoaster.RAIL
const STEEL_DARK := Color(0.40, 0.16, 0.14)
const CONCRETE := Color(0.70, 0.69, 0.66)
const SAIL := Color(0.95, 0.92, 0.84)
const ROPE := Color(0.78, 0.68, 0.48)
const LAMP := Color(1.0, 0.82, 0.42)

enum Phase { STILL, SWINGING }

## The boat has swung through the bottom of its arc, with how far it is
## swinging as a fraction of its widest, for the breath of air that goes with it.
signal passed_the_bottom(strength: float)

var _phase := Phase.STILL
var _phase_time := 0.0
var _swing_time := 0.0
var _hull: AnimatableBody3D
var _angle := 0.0
var _moved := Vector3.ZERO
var _held := false
## How long before it goes a held boat is kept, in seconds.
const HELD_LEAD := 3.0
## How the hull's own turn and shift this frame took every point of it: the
## world-space move from where a point was to where it is now.
var _swept := Transform3D.IDENTITY
var _harnesses: Array[Node3D] = []
## Which end each harness's row faces away from: +1 for the bow rows, -1 for
## the stern's, so a bar closes towards the middle on both.
var _harness_ends: Array[float] = []
var _harness_closed := 0.0
## Every seat in the hull's own frame: the top of the cushion, turned to face
## the middle.
var _seats: Array[Transform3D] = []
## What a lowered bar holds: a solid across the front of each seat, switched
## on only once the bars are down.
var _bar_shapes: Array[CollisionShape3D] = []

func _init(at: Vector3) -> void:
	name = "PirateShip"
	position = at

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var solid := StaticBody3D.new()
	solid.name = "Solid"
	add_child(solid)

	_build_frames(tool, solid)
	_build_platform(tool, solid)

	_hull = AnimatableBody3D.new()
	_hull.name = "Hull"
	_hull.sync_to_physics = false
	add_child(_hull)
	_build_hull(_hull)
	_place_hull()

	Park.commit(tool, self, "Structure")

## Two A-frames, one either side of the boat's width, with the axle across the
## top of both, side stays out past each, and a concrete footing under every
## foot.
func _build_frames(tool: SurfaceTool, solid: StaticBody3D) -> void:
	for side: float in [-1.0, 1.0]:
		var at_z := side * FRAME_Z
		var foot_a := Vector3(-FRAME_SPREAD, 0.0, at_z)
		var foot_b := Vector3(FRAME_SPREAD, 0.0, at_z)
		# Every leg on this side meets at one point, the top of the housing
		# the axle turns in. The legs used to stop at two shoulders either
		# side of the axle, joined by short bars, and the side stays met the
		# frame lower down again: from the ground nothing came together, and
		# the frame read as three structures leaning on one another.
		var apex := Vector3(0.0, AXLE_HEIGHT + BEARING_RISE, at_z)
		_strut(tool, solid, foot_a, apex, 0.4, STEEL)
		_strut(tool, solid, foot_b, apex, 0.4, STEEL)
		# Two braces across each frame, both well above a child on the
		# platform, and an X between them: what stops an A-frame racking
		# under a load that changes direction twice every swing.
		var low_a := foot_a.lerp(apex, 0.35)
		var low_b := foot_b.lerp(apex, 0.35)
		var high_a := foot_a.lerp(apex, 0.65)
		var high_b := foot_b.lerp(apex, 0.65)
		_beam(tool, low_a, low_b, 0.22, STEEL_DARK)
		_beam(tool, high_a, high_b, 0.22, STEEL_DARK)
		_beam(tool, low_a, high_b, 0.16, STEEL_DARK)
		_beam(tool, low_b, high_a, 0.16, STEEL_DARK)
		# The side stays: from the same apex out past the frame and down to
		# the ground, either side of the ramp rather than onto it, so each
		# side stands as one tripod-like trestle.
		for along: float in [-1.0, 1.0]:
			var stay_foot := Vector3(along * 3.0, 0.0, at_z + side * 6.0)
			_strut(tool, solid, apex + Vector3(0.0, -0.2, side * 0.1), stay_foot, 0.26, STEEL_DARK)
			_footing(tool, stay_foot)
			# A tie from the stay's foot back to the frame's own leg, low
			# down, so the stays are part of the frame rather than props.
			var tie_to := (foot_a if along < 0.0 else foot_b).lerp(apex, 0.12)
			_beam(tool, stay_foot + Vector3(0.0, 0.25, 0.0), tie_to, 0.14, STEEL_DARK)
		_footing(tool, foot_a)
		_footing(tool, foot_b)
		# The housing the axle turns in, rising from the axle to where the
		# legs meet, with a cap over the top.
		var housing := BoxMesh.new()
		housing.size = Vector3(1.1, BEARING_RISE + 0.7, 0.7)
		Park._add(
			tool, housing,
			Transform3D(Basis(), Vector3(0.0, AXLE_HEIGHT + (BEARING_RISE - 0.7) * 0.5 + 0.35, at_z)),
			STEEL_DARK
		)
		var cap := BoxMesh.new()
		cap.size = Vector3(1.4, 0.2, 0.9)
		Park._add(tool, cap, Transform3D(Basis(), apex + Vector3(0.0, 0.45, 0.0)), STEEL)
		var hub_cap := CylinderMesh.new()
		hub_cap.top_radius = 0.5
		hub_cap.bottom_radius = 0.5
		hub_cap.height = 0.2
		hub_cap.radial_segments = 14
		Park._add(
			tool, hub_cap,
			Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, AXLE_HEIGHT, at_z + side * 0.42)),
			STEEL
		)

	# Ground ties between the two frames' feet, far outside anything the hull
	# can reach.
	for along: float in [-1.0, 1.0]:
		_beam(
			tool, Vector3(along * FRAME_SPREAD, 0.2, -FRAME_Z), Vector3(along * FRAME_SPREAD, 0.2, FRAME_Z),
			0.24, STEEL_DARK
		)

	# The axle, across the boat from one frame's apex to the other's.
	var axle := CylinderMesh.new()
	axle.top_radius = 0.32
	axle.bottom_radius = 0.32
	axle.height = FRAME_Z * 2.0 + 0.6
	axle.radial_segments = 12
	Park._add(
		tool, axle, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, AXLE_HEIGHT, 0.0)), STEEL_DARK
	)

static func _footing(tool: SurfaceTool, at: Vector3) -> void:
	var block := BoxMesh.new()
	block.size = Vector3(1.3, 0.4, 1.3)
	Park._add(tool, block, Transform3D(Basis(), Vector3(at.x, 0.2, at.z)), CONCRETE)
	# A steel plate the leg is bolted to, so it stands on the footing rather
	# than disappearing into it.
	var plate := BoxMesh.new()
	plate.size = Vector3(0.8, 0.08, 0.8)
	Park._add(tool, plate, Transform3D(Basis(), Vector3(at.x, 0.44, at.z)), STEEL_DARK)

## A deck at the height the hull's own deck rests at, beside its gate, with a
## ramp down to the sand and rails round the drop. The hull swings past its
## edge, never over it.
func _build_platform(tool: SurfaceTool, solid: StaticBody3D) -> void:
	var middle_z := PLATFORM_FROM + PLATFORM_DEPTH * 0.5
	var deck := BoxMesh.new()
	deck.size = Vector3(PLATFORM_HALF_X * 2.0, DECK_REST, PLATFORM_DEPTH)
	var deck_at := Transform3D(Basis(), Vector3(0.0, DECK_REST * 0.5, middle_z))
	Park._add(tool, deck, deck_at, TIMBER)
	Park._solid(solid, deck.size, deck_at)
	var top := BoxMesh.new()
	top.size = Vector3(PLATFORM_HALF_X * 2.0 + 0.1, 0.08, PLATFORM_DEPTH + 0.1)
	Park._add(tool, top, Transform3D(Basis(), Vector3(0.0, DECK_REST - 0.02, middle_z)), DECK)

	# The deck stands as a bare brown block otherwise, which reads as a crate
	# rather than a jetty. Planking is drawn as upright battens a few
	# centimetres proud of the three open faces, with a dark skirting at the
	# foot and a pale fascia under the edge. The gate side is left bare: the
	# hull swings past that face, and nothing may stand out into its sweep.
	var far_face := PLATFORM_FROM + PLATFORM_DEPTH
	for side: float in [-1.0, 1.0]:
		var face_x := side * (PLATFORM_HALF_X + 0.02)
		for batten in int(PLATFORM_DEPTH / 0.5):
			var batten_z := PLATFORM_FROM + (float(batten) + 0.5) * 0.5
			var plank := BoxMesh.new()
			plank.size = Vector3(0.04, DECK_REST - 0.3, 0.07)
			Park._add(tool, plank, Transform3D(Basis(), Vector3(face_x, DECK_REST * 0.5 - 0.05, batten_z)), TIMBER.darkened(0.2))
		var skirt := BoxMesh.new()
		skirt.size = Vector3(0.08, 0.2, PLATFORM_DEPTH)
		Park._add(tool, skirt, Transform3D(Basis(), Vector3(side * (PLATFORM_HALF_X + 0.03), 0.1, middle_z)), TIMBER.darkened(0.4))
		var fascia := BoxMesh.new()
		fascia.size = Vector3(0.08, 0.12, PLATFORM_DEPTH)
		Park._add(tool, fascia, Transform3D(Basis(), Vector3(side * (PLATFORM_HALF_X + 0.03), DECK_REST - 0.1, middle_z)), DECK)
	for batten in int(PLATFORM_HALF_X * 2.0 / 0.5):
		var batten_x := -PLATFORM_HALF_X + (float(batten) + 0.5) * 0.5
		var plank := BoxMesh.new()
		plank.size = Vector3(0.07, DECK_REST - 0.3, 0.04)
		Park._add(tool, plank, Transform3D(Basis(), Vector3(batten_x, DECK_REST * 0.5 - 0.05, far_face + 0.02)), TIMBER.darkened(0.2))
	var far_skirt := BoxMesh.new()
	far_skirt.size = Vector3(PLATFORM_HALF_X * 2.0 + 0.16, 0.2, 0.08)
	Park._add(tool, far_skirt, Transform3D(Basis(), Vector3(0.0, 0.1, far_face + 0.03)), TIMBER.darkened(0.4))
	var far_fascia := BoxMesh.new()
	far_fascia.size = Vector3(PLATFORM_HALF_X * 2.0 + 0.16, 0.12, 0.08)
	Park._add(tool, far_fascia, Transform3D(Basis(), Vector3(0.0, DECK_REST - 0.1, far_face + 0.03)), DECK)

	# The ramp: steep enough to be short, gentle enough to walk up.
	var far_z := PLATFORM_FROM + PLATFORM_DEPTH
	var ramp_top := Vector3(0.0, DECK_REST, far_z)
	var ramp_foot := Vector3(0.0, 0.0, far_z + RAMP_RUN)
	var slope := atan2(DECK_REST, RAMP_RUN)
	var ramp_basis := Basis(Vector3.RIGHT, slope)
	var ramp_length := ramp_top.distance_to(ramp_foot)
	var ramp_at := Transform3D(ramp_basis, ramp_top.lerp(ramp_foot, 0.5) + ramp_basis * Vector3(0.0, -0.1, 0.0))
	var ramp := BoxMesh.new()
	ramp.size = Vector3(RAMP_HALF_WIDTH * 2.0, 0.2, ramp_length)
	Park._add(tool, ramp, ramp_at, DECK)
	Park._solid(solid, ramp.size, ramp_at)
	for cleat in int(ramp_length / 0.5):
		var along := (float(cleat) + 0.5) / float(int(ramp_length / 0.5))
		var strip := BoxMesh.new()
		strip.size = Vector3(RAMP_HALF_WIDTH * 2.0, 0.04, 0.06)
		Park._add(tool, strip, Transform3D(ramp_basis, ramp_top.lerp(ramp_foot, along)), TIMBER.darkened(0.25))
	for side: float in [-1.0, 1.0]:
		var rail_x := side * (RAMP_HALF_WIDTH + 0.05)
		_beam(tool, Vector3(rail_x, DECK_REST + 0.9, far_z), Vector3(rail_x, 0.9, far_z + RAMP_RUN), 0.07, TRIM)
		for post in 4:
			var u := float(post) / 3.0
			var foot := Vector3(rail_x, DECK_REST * (1.0 - u), far_z + RAMP_RUN * u)
			_beam(tool, foot, foot + Vector3(0.0, 0.9, 0.0), 0.07, TIMBER.darkened(0.2))

	# Rails round the platform's three open edges — it stands well over a
	# child's height — solid, so nobody walks off one. The fourth edge is the
	# hull's gate, and the far edge leaves room for the ramp.
	for side: float in [-1.0, 1.0]:
		var x := side * PLATFORM_HALF_X
		_railing(tool, solid, Vector3(x, DECK_REST, PLATFORM_FROM), Vector3(x, DECK_REST, far_z))
		_railing(
			tool, solid, Vector3(side * RAMP_HALF_WIDTH, DECK_REST, far_z), Vector3(x, DECK_REST, far_z)
		)

## A railing between two points on a deck: posts, a top rail, and a solid box
## so it actually stops somebody.
static func _railing(tool: SurfaceTool, solid: StaticBody3D, a: Vector3, b: Vector3) -> void:
	var height := 1.0
	_beam(tool, a + Vector3(0.0, height, 0.0), b + Vector3(0.0, height, 0.0), 0.08, TRIM)
	_beam(tool, a + Vector3(0.0, height * 0.5, 0.0), b + Vector3(0.0, height * 0.5, 0.0), 0.05, TRIM)
	var posts := maxi(2, int(a.distance_to(b) / 0.8) + 1)
	for post in posts:
		var at := a.lerp(b, float(post) / float(posts - 1))
		_beam(tool, at, at + Vector3(0.0, height, 0.0), 0.07, TIMBER.darkened(0.2))
	var length := a.distance_to(b)
	var along := (b - a).normalized()
	var basis := Basis(Vector3.UP, atan2(along.x, along.z))
	Park._solid(solid, Vector3(0.1, height, length), Transform3D(basis, a.lerp(b, 0.5) + Vector3(0.0, height * 0.5, 0.0)))

## Where the keel runs at a point x along the hull: flat under the riders'
## well, then curving up along a circle about the axle towards each end.
static func _keel(x: float) -> float:
	if absf(x) <= DECK_HALF:
		return -KEEL_DEPTH
	return ARM_LENGTH - sqrt(REACH * REACH - x * x)

## How high the hull's side rides at a point x along it: a boat's sheer, low
## amidships and sweeping up into bow and stern.
static func _gunwale(x: float) -> float:
	return 1.0 + 1.6 * pow(absf(x) / (HULL_LENGTH * 0.5), 3.0)

## The hull: a planked shell, a flat well of seats facing the middle, decked
## ends with a mast on each, a dragon's head and tail, and the hangers that
## carry the whole thing up to the axle.
func _build_hull(body: AnimatableBody3D) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := HULL_LENGTH * 0.5

	var segments := 16
	for seg in segments:
		var x0 := lerpf(-half, half, float(seg) / float(segments))
		var x1 := lerpf(-half, half, float(seg + 1) / float(segments))
		var k0 := _keel(x0)
		var k1 := _keel(x1)
		var g0 := _gunwale(x0)
		var g1 := _gunwale(x1)
		var mid_x := (x0 + x1) * 0.5
		var length := x1 - x0
		var keel_mid := (k0 + k1) * 0.5
		var top_mid := (g0 + g1) * 0.5
		var in_gate := absf(mid_x) < GATE_HALF

		# The bottom, laid along the keel's own slope.
		_slab(tool, Vector2(x0, k0), Vector2(x1, k1), 0.0, HULL_HALF_WIDTH * 2.0, 0.16, HULL_DARK)

		for side: float in [-1.0, 1.0]:
			var z := side * HULL_HALF_WIDTH
			# The gate is a gap in the side above the deck, on the platform's
			# side only.
			var gate_here := in_gate and side > 0.0
			var top := 0.0 if gate_here else top_mid
			var panel := BoxMesh.new()
			panel.size = Vector3(length + 0.04, top - keel_mid, 0.14)
			Park._add(
				tool, panel, Transform3D(Basis(), Vector3(mid_x, (top + keel_mid) * 0.5, z)),
				HULL if seg % 2 == 0 else HULL.darkened(0.07)
			)
			# A dark band along the waterline, and the gold one under the
			# rail, so the side reads as painted planking.
			_slab(
				tool, Vector2(x0, k0 + 0.3), Vector2(x1, k1 + 0.3), side * (HULL_HALF_WIDTH + 0.06), 0.04, 0.2,
				HULL_DARK.darkened(0.3)
			)
			if gate_here:
				continue
			_slab(
				tool, Vector2(x0, g0 - 0.3), Vector2(x1, g1 - 0.3), side * (HULL_HALF_WIDTH + 0.06), 0.04, 0.16,
				TRIM
			)
			_slab(tool, Vector2(x0, g0), Vector2(x1, g1), z, 0.32, 0.12, TRIM)

	# The ends: a transom closing each, a bulkhead closing the riders' well,
	# and a deck laid over the space between.
	for end: float in [-1.0, 1.0]:
		var end_x := end * half
		var k := _keel(end_x)
		var g := _gunwale(end_x)
		var transom := BoxMesh.new()
		transom.size = Vector3(0.16, g - k, HULL_HALF_WIDTH * 2.0)
		Park._add(tool, transom, Transform3D(Basis(), Vector3(end_x, (g + k) * 0.5, 0.0)), HULL_DARK)
		var bulkhead := BoxMesh.new()
		bulkhead.size = Vector3(0.14, 1.0, HULL_HALF_WIDTH * 2.0 - 0.1)
		var bulkhead_at := Transform3D(Basis(), Vector3(end * DECK_HALF, 0.5, 0.0))
		Park._add(tool, bulkhead, bulkhead_at, TIMBER.darkened(0.15))
		_hull_solid(body, bulkhead.size, bulkhead_at)
		_slab(
			tool, Vector2(end * DECK_HALF, 1.0), Vector2(end_x, g - 0.15), 0.0, HULL_HALF_WIDTH * 2.0 - 0.1,
			0.12, DECK
		)
		# The deck is drawn over the raised end, so it is a floor too: a child who
		# jumped onto the bulkhead (a metre up) and on over it came down through
		# planking with nothing under it, and fell out of the boat.
		var end_from := Vector2(end * DECK_HALF, 1.0)
		var end_to := Vector2(end_x, g - 0.15)
		var end_mid := (end_from + end_to) * 0.5
		_hull_solid(
			body, Vector3(end_from.distance_to(end_to) + 0.04, 0.12, HULL_HALF_WIDTH * 2.0 - 0.1),
			Transform3D(
				Basis(Vector3.BACK, atan2(end_to.y - end_from.y, end_to.x - end_from.x)),
				Vector3(end_mid.x, end_mid.y, 0.0)
			)
		)

		# A bulwark along each side of the raised deck, drawn and solid. The
		# deck is a floor now, and its sides were only painted planking up to
		# the gunwale, so a child could walk straight off the edge of it. It
		# stands above the gunwale line, so it is a rail to the knee and a
		# little over rather than a second hull.
		for side: float in [-1.0, 1.0]:
			var rail_from := Vector2(end * DECK_HALF, _gunwale(DECK_HALF))
			var rail_to := Vector2(end_x, g)
			var rail_z := side * HULL_HALF_WIDTH
			_slab(
				tool, rail_from + Vector2(0.0, BULWARK * 0.5), rail_to + Vector2(0.0, BULWARK * 0.5),
				rail_z, 0.14, BULWARK,
				HULL if end > 0.0 else HULL.darkened(0.07)
			)
			_slab(
				tool, rail_from + Vector2(0.0, BULWARK), rail_to + Vector2(0.0, BULWARK),
				rail_z, 0.3, 0.1, TRIM
			)
			# Solid from a little below the gunwale, hidden behind the painted
			# side, to the top of the rail.
			var rail_mid := (rail_from + rail_to) * 0.5 + Vector2(0.0, BULWARK * 0.5 - 0.15)
			_hull_solid(
				body, Vector3(rail_from.distance_to(rail_to) + 0.04, BULWARK + 0.3, 0.14),
				Transform3D(
					Basis(Vector3.BACK, atan2(rail_to.y - rail_from.y, rail_to.x - rail_from.x)),
					Vector3(rail_mid.x, rail_mid.y, rail_z)
				)
			)

		# A mast on each end deck, with a yard and a sail across the boat.
		var mast_x := end * (DECK_HALF + 1.4)
		var mast_foot := lerpf(1.0, g - 0.15, (absf(mast_x) - DECK_HALF) / (half - DECK_HALF))
		var mast := CylinderMesh.new()
		mast.top_radius = 0.08
		mast.bottom_radius = 0.13
		mast.height = 4.4
		mast.radial_segments = 8
		Park._add(tool, mast, Transform3D(Basis(), Vector3(mast_x, mast_foot + 2.2, 0.0)), TIMBER.darkened(0.2))
		var yard := BoxMesh.new()
		yard.size = Vector3(0.12, 0.12, HULL_HALF_WIDTH * 1.8)
		Park._add(tool, yard, Transform3D(Basis(), Vector3(mast_x, mast_foot + 4.0, 0.0)), TIMBER.darkened(0.2))
		# The sail is a node of its own, so it can belly with the wind.
		var sail := Sail.new()
		sail.name = "Sail%d" % int(end)
		sail.position = Vector3(mast_x - end * 0.14, mast_foot + 2.85, 0.0)
		sail.build(HULL_HALF_WIDTH * 1.7, 2.1, SAIL, HULL)
		body.add_child(sail)
		# A swallow-tailed flag at the masthead, its two tails splayed. It is a
		# node of its own, not part of the baked hull, so it can fly the wind.
		var pennant := Flag.new()
		pennant.name = "Pennant%d" % int(end)
		pennant.position = Vector3(mast_x, mast_foot + 4.42, 0.0)
		for tail: float in [-1.0, 1.0]:
			pennant.add_cloth(Vector3(0.8, 0.16, 0.04), HULL if tail > 0.0 else TRIM, tail * deg_to_rad(10.0), tail * 0.08)
		body.add_child(pennant)
		# Shrouds: two ropes each side from the masthead down to the rail,
		# which is what makes a pole with a sheet on it read as a mast.
		var mast_head := Vector3(mast_x, mast_foot + 3.9, 0.0)
		for side: float in [-1.0, 1.0]:
			for lean: float in [-0.7, 0.7]:
				var rail_x := mast_x + lean
				_beam(
					tool, mast_head,
					Vector3(rail_x, _gunwale(clampf(rail_x, -half, half)) + BULWARK, side * (HULL_HALF_WIDTH - 0.1)), 0.035, ROPE
				)
		# A lookout's barrel on the bow mast, above the sail.
		if end > 0.0:
			var nest := CylinderMesh.new()
			nest.top_radius = 0.42
			nest.bottom_radius = 0.34
			nest.height = 0.4
			nest.radial_segments = 10
			Park._add(tool, nest, Transform3D(Basis(), Vector3(mast_x, mast_foot + 4.15, 0.0)), TIMBER)
		# A lantern on a short post at each end of the deck.
		var lantern_x := end * (half - 0.5)
		var lantern_y := _gunwale(lantern_x)
		var post := BoxMesh.new()
		post.size = Vector3(0.06, 0.4, 0.06)
		Park._add(tool, post, Transform3D(Basis(), Vector3(lantern_x, lantern_y + 0.2, 0.0)), STEEL_DARK)
		var lamp := BoxMesh.new()
		lamp.size = Vector3(0.22, 0.28, 0.22)
		Park._add(tool, lamp, Transform3D(Basis(), Vector3(lantern_x, lantern_y + 0.52, 0.0)), LAMP)
		var lamp_cap := BoxMesh.new()
		lamp_cap.size = Vector3(0.28, 0.06, 0.28)
		Park._add(tool, lamp_cap, Transform3D(Basis(), Vector3(lantern_x, lantern_y + 0.69, 0.0)), STEEL_DARK)

		# Portholes along the raised ends, past the shields, with a gold rim.
		for hole in 2:
			var hole_x := end * (DECK_HALF + 0.9 + 1.0 * float(hole))
			var hole_y := (_keel(hole_x) + _gunwale(hole_x)) * 0.5 + 0.2
			for side: float in [-1.0, 1.0]:
				var rim := CylinderMesh.new()
				rim.top_radius = 0.24
				rim.bottom_radius = 0.24
				rim.height = 0.04
				rim.radial_segments = 12
				Park._add(
					tool, rim, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(hole_x, hole_y, side * (HULL_HALF_WIDTH + 0.08))),
					TRIM
				)
				var glass := CylinderMesh.new()
				glass.top_radius = 0.17
				glass.bottom_radius = 0.17
				glass.height = 0.04
				glass.radial_segments = 12
				Park._add(
					tool, glass,
					Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(hole_x, hole_y, side * (HULL_HALF_WIDTH + 0.11))),
					SHIELD.darkened(0.45)
				)

	# The dragon at the bow: a neck curling up and out, and a head with eyes.
	var bow_top := _gunwale(half)
	var neck_at := Vector3.ZERO
	for step in 6:
		var u := float(step) / 5.0
		neck_at = Vector3(half + 0.9 * sin(u * PI * 0.5), bow_top + 1.7 * u, 0.0)
		var piece := BoxMesh.new()
		piece.size = Vector3(0.55, 0.55, 0.5 - 0.08 * u)
		Park._add(tool, piece, Transform3D(Basis(), neck_at), HULL_DARK)
	var head := BoxMesh.new()
	head.size = Vector3(1.0, 0.5, 0.5)
	var head_at := neck_at + Vector3(0.45, 0.15, 0.0)
	Park._add(tool, head, Transform3D(Basis(), head_at), HULL_DARK)
	var jaw := BoxMesh.new()
	jaw.size = Vector3(0.7, 0.14, 0.42)
	Park._add(tool, jaw, Transform3D(Basis(Vector3.BACK, deg_to_rad(-14.0)), head_at + Vector3(0.3, -0.32, 0.0)), HULL_DARK.darkened(0.2))
	for eye_side: float in [-1.0, 1.0]:
		var eye := SphereMesh.new()
		eye.radius = 0.09
		eye.height = 0.18
		eye.radial_segments = 8
		eye.rings = 4
		Park._add(tool, eye, Transform3D(Basis(), head_at + Vector3(0.1, 0.12, eye_side * 0.25)), TRIM)
		var horn := CylinderMesh.new()
		horn.top_radius = 0.0
		horn.bottom_radius = 0.08
		horn.height = 0.4
		horn.radial_segments = 6
		Park._add(
			tool, horn, Transform3D(Basis(Vector3.BACK, deg_to_rad(40.0)), head_at + Vector3(-0.3, 0.4, eye_side * 0.15)),
			TRIM
		)
	# And its tail at the stern, curled back over on itself.
	for step in 7:
		var u := float(step) / 6.0
		var curl := u * PI * 1.2
		var tail_at := Vector3(-half - 0.5 * sin(curl), bow_top + 1.0 * (1.0 - cos(curl)) * 0.8 + u * 0.6, 0.0)
		var piece := BoxMesh.new()
		piece.size = Vector3(0.45, 0.45, 0.42 - 0.05 * u)
		Park._add(tool, piece, Transform3D(Basis(), tail_at), HULL_DARK)

	# Round shields along both sides, the one detail that says "ship" from
	# across the ground, kept off the gate.
	for slot in 7:
		var shield_x := lerpf(-DECK_HALF + 0.4, DECK_HALF - 0.4, float(slot) / 6.0)
		for side: float in [-1.0, 1.0]:
			if side > 0.0 and absf(shield_x) < GATE_HALF + 0.4:
				continue
			var disc := CylinderMesh.new()
			disc.top_radius = 0.3
			disc.bottom_radius = 0.3
			disc.height = 0.06
			disc.radial_segments = 12
			var shield_at := Vector3(shield_x, _gunwale(shield_x) - 0.6, side * (HULL_HALF_WIDTH + 0.1))
			Park._add(
				tool, disc, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), shield_at),
				SHIELD if slot % 2 == 0 else TRIM
			)
			var boss := SphereMesh.new()
			boss.radius = 0.08
			boss.height = 0.12
			boss.radial_segments = 8
			boss.rings = 4
			Park._add(tool, boss, Transform3D(Basis(), shield_at + Vector3(0.0, 0.0, side * 0.05)), STEEL_DARK)

	# The riders' well: a planked floor, solid, with the sides and bulkheads
	# round it solid too.
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(DECK_HALF * 2.0, 0.2, HULL_HALF_WIDTH * 2.0 - 0.1)
	var floor_at := Transform3D(Basis(), Vector3(0.0, -0.1, 0.0))
	Park._add(tool, floor_mesh, floor_at, DECK)
	_hull_solid(body, floor_mesh.size, floor_at)
	for plank in 9:
		var seam := BoxMesh.new()
		seam.size = Vector3(DECK_HALF * 2.0, 0.01, 0.03)
		var seam_z := lerpf(-HULL_HALF_WIDTH + 0.3, HULL_HALF_WIDTH - 0.3, float(plank) / 8.0)
		Park._add(tool, seam, Transform3D(Basis(), Vector3(0.0, 0.005, seam_z)), DECK.darkened(0.25))
	var wall := Vector3(DECK_HALF * 2.0, 1.1, 0.14)
	_hull_solid(body, wall, Transform3D(Basis(), Vector3(0.0, 0.55, -HULL_HALF_WIDTH)))
	var beside_gate := DECK_HALF - GATE_HALF
	for end: float in [-1.0, 1.0]:
		_hull_solid(
			body, Vector3(beside_gate, 1.1, 0.14),
			Transform3D(Basis(), Vector3(end * (GATE_HALF + beside_gate * 0.5), 0.55, HULL_HALF_WIDTH))
		)

	# The seats: a few single seats rather than benches packed edge to edge,
	# two rows towards each end, two seats to a row with room between them,
	# every one facing the middle. Each is solid — a cushion a small step up
	# from the deck, a tall back — so a child stands in a seat rather than
	# through one, the way they could walk through the benches.
	_harnesses.clear()
	_harness_ends.clear()
	_seats.clear()
	_bar_shapes.clear()
	for end: float in [-1.0, 1.0]:
		for row: float in ROWS:
			var x := end * row
			for across: float in SEAT_ACROSS:
				var seat_at := Vector3(x, SEAT_TOP, across)
				# A child sits facing the middle, which is along the hull
				# towards the other end: their -z is the hull's -end x.
				_seats.append(Transform3D(Basis(Vector3.UP, end * PI * 0.5), seat_at))
				var cushion := BoxMesh.new()
				cushion.size = Vector3(SEAT_DEPTH, SEAT_TOP, SEAT_WIDTH)
				var cushion_at := Transform3D(Basis(), Vector3(x, SEAT_TOP * 0.5, across))
				Park._add(tool, cushion, cushion_at, SEAT_COLOUR)
				_hull_solid(body, cushion.size, cushion_at)
				var back := BoxMesh.new()
				back.size = Vector3(0.1, 1.2, SEAT_WIDTH)
				var back_at := Transform3D(
					Basis(), Vector3(x + end * (SEAT_DEPTH * 0.5 + 0.05), SEAT_TOP + 0.6, across)
				)
				Park._add(tool, back, back_at, SEAT_COLOUR.darkened(0.15))
				_hull_solid(body, back.size, back_at)
				for arm_side: float in [-1.0, 1.0]:
					var armrest := BoxMesh.new()
					armrest.size = Vector3(SEAT_DEPTH, 0.08, 0.08)
					Park._add(
						tool, armrest,
						Transform3D(Basis(), seat_at + Vector3(0.0, 0.55, arm_side * (SEAT_WIDTH * 0.5 - 0.04))),
						SEAT_COLOUR.darkened(0.3)
					)

				# The bar hinges at the top of the back and, open, stands up
				# out of the way; closed, it comes down in front of the rider.
				var hinge := Node3D.new()
				hinge.name = "Harness"
				hinge.position = Vector3(x + end * (SEAT_DEPTH * 0.5), SEAT_TOP + BAR_HINGE, across)
				body.add_child(hinge)
				_harnesses.append(hinge)
				_harness_ends.append(end)
				var bar_tool := SurfaceTool.new()
				bar_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				for arm_side: float in [-1.0, 1.0]:
					var arm := BoxMesh.new()
					arm.size = Vector3(0.06, BAR_LENGTH, 0.06)
					Park._add(
						bar_tool, arm, Transform3D(Basis(), Vector3(0.0, BAR_LENGTH * 0.5, arm_side * ARM_OUT)),
						RollerCoaster.HARNESS.darkened(0.3)
					)
				var bar := BoxMesh.new()
				bar.size = Vector3(0.12, 0.12, SEAT_WIDTH - 0.06)
				Park._add(bar_tool, bar, Transform3D(Basis(), Vector3(0.0, BAR_LENGTH, 0.0)), RollerCoaster.HARNESS)
				Park.commit(bar_tool, hinge, "Bar")

				# And a lowered bar holds. It used to be only a drawing: it came
				# down in front of the rider and they could walk straight out
				# through it at the top of a swing. A solid across the front of
				# the seat, clear of the cushion by more than a child is deep so
				# it never squeezes one, switched on once the bars are down.
				var hold := BoxShape3D.new()
				hold.size = Vector3(0.12, 1.0, SEAT_WIDTH)
				var held := CollisionShape3D.new()
				held.shape = hold
				held.position = Vector3(x - end * (SEAT_DEPTH * 0.5 + 0.18), SEAT_TOP + 0.5, across)
				held.disabled = true
				body.add_child(held)
				_bar_shapes.append(held)

	# The hangers: on each side, a V of steel from two points on a stringer
	# bolted along the hull up to a hub that turns on the axle, with ties
	# across it — the hull hangs from four points, not from one rod at its
	# middle. All of it rises from the hull; nothing hangs below the keel.
	for side: float in [-1.0, 1.0]:
		var z := side * HANGER_Z
		var stringer_y := 1.05
		if side > 0.0:
			# Split round the gate, so walking in is not walking into it.
			for end: float in [-1.0, 1.0]:
				_beam(
					tool, Vector3(end * GATE_HALF, stringer_y, z), Vector3(end * 3.2, stringer_y, z), 0.18, STEEL_DARK
				)
		else:
			_beam(tool, Vector3(-3.2, stringer_y, z), Vector3(3.2, stringer_y, z), 0.18, STEEL_DARK)
		var hub_at := Vector3(0.0, ARM_LENGTH, z)
		var feet: Array[Vector3] = [Vector3(-2.8, stringer_y, z), Vector3(2.8, stringer_y, z)]
		for foot in feet:
			_beam(tool, foot, hub_at, 0.26, STEEL)
		for level: float in [0.3, 0.55, 0.8]:
			_beam(tool, feet[0].lerp(hub_at, level), feet[1].lerp(hub_at, level), 0.14, STEEL_DARK)
		_beam(tool, feet[0].lerp(hub_at, 0.3), feet[1].lerp(hub_at, 0.55), 0.1, STEEL_DARK)
		_beam(tool, feet[1].lerp(hub_at, 0.3), feet[0].lerp(hub_at, 0.55), 0.1, STEEL_DARK)
		var hub := CylinderMesh.new()
		hub.top_radius = 0.6
		hub.bottom_radius = 0.6
		hub.height = 0.3
		hub.radial_segments = 14
		Park._add(tool, hub, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), hub_at), STEEL_DARK)

	Park.commit(tool, body, "Deck")

## A collision box on the hull's own body.
static func _hull_solid(body: AnimatableBody3D, size: Vector3, where: Transform3D) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.transform = where
	body.add_child(collider)

## A flat board between two points in the hull's own length-and-height plane,
## centred at depth z across the boat — the keel, the rails, the painted
## bands, each following the curve of the hull rather than stepping along it.
static func _slab(
	tool: SurfaceTool, a: Vector2, b: Vector2, z: float, depth: float, thickness: float, colour: Color
) -> void:
	var length := a.distance_to(b)
	if length < 0.001:
		return
	var board := BoxMesh.new()
	board.size = Vector3(length + 0.04, thickness, depth)
	var tilt := atan2(b.y - a.y, b.x - a.x)
	var mid := (a + b) * 0.5
	Park._add(tool, board, Transform3D(Basis(Vector3.BACK, tilt), Vector3(mid.x, mid.y, z)), colour)

## The turn that stands a box's own height along the line from a to b.
static func _beam_basis(a: Vector3, b: Vector3) -> Basis:
	var up := (b - a).normalized()
	var axis := Vector3.UP.cross(up)
	if axis.length_squared() > 0.0001:
		return Basis(axis.normalized(), Vector3.UP.angle_to(up))
	if up.y < 0.0:
		return Basis(Vector3.RIGHT, PI)
	return Basis()

## A straight bar between two points — the same helper the drop tower's own
## frame uses.
static func _beam(tool: SurfaceTool, a: Vector3, b: Vector3, thickness: float, colour: Color) -> void:
	var length := a.distance_to(b)
	if length < 0.001:
		return
	var beam := BoxMesh.new()
	beam.size = Vector3(thickness, length, thickness)
	Park._add(tool, beam, Transform3D(_beam_basis(a, b), a.lerp(b, 0.5)), colour)

## A bar that is also solid, so a child walks round a frame's leg rather than
## through it.
static func _strut(tool: SurfaceTool, solid: StaticBody3D, a: Vector3, b: Vector3, thickness: float, colour: Color) -> void:
	_beam(tool, a, b, thickness, colour)
	Park._solid(solid, Vector3(thickness, a.distance_to(b), thickness), Transform3D(_beam_basis(a, b), a.lerp(b, 0.5)))

## Where the hull sits for the angle it is swung to right now.
func _place_hull() -> void:
	# A swing turns about the axle, not about its own middle: the hull hangs
	# ARM_LENGTH below the axle when upright and, tipped by _angle, is still
	# that far from it, swung round it. The axle runs along z, across the
	# boat, so the boat swings along its own length.
	var hung := Vector3(0.0, -ARM_LENGTH, 0.0).rotated(Vector3.BACK, _angle)
	_hull.position = Vector3(0.0, AXLE_HEIGHT, 0.0) + hung
	_hull.rotation = Vector3(0.0, 0.0, _angle)

## The game says whether somebody aboard has not paid for this swing. While
## they have, the boat stays still with its bars up, so it never shuts anyone in.
func hold_still(held: bool) -> void:
	_held = held

func _physics_process(delta: float) -> void:
	var before := _hull.position
	var before_at := _hull.transform
	_phase_time += delta
	match _phase:
		Phase.STILL:
			_angle = 0.0
			# An unpaid child aboard keeps it still (see the drop tower's
			# note): the solid hull lifts and swings them whether or not the
			# game carries them, so answering "no" was a free ride.
			if _held:
				_phase_time = minf(_phase_time, STILL_HOLD - HELD_LEAD)
			elif _phase_time >= STILL_HOLD:
				_phase = Phase.SWINGING
				_phase_time = 0.0
				_swing_time = 0.0
		Phase.SWINGING:
			_swing_time += delta
			var envelope := 1.0
			if _swing_time < RAMP_TIME:
				envelope = smoothstep(0.0, 1.0, _swing_time / RAMP_TIME)
			elif _swing_time > SWING_TIME - RAMP_TIME:
				envelope = smoothstep(0.0, 1.0, (SWING_TIME - _swing_time) / RAMP_TIME)
			var before_angle := _angle
			_angle = MAX_ANGLE * envelope * sin(TAU / SWING_PERIOD * _swing_time)
			# Through the bottom is a change of side. Only once it is swinging
			# enough to feel: the first, barely-moving passes are no breeze.
			if before_angle * _angle < 0.0 and envelope > 0.25:
				passed_the_bottom.emit(envelope)
			if _phase_time >= SWING_TIME:
				_phase = Phase.STILL
				_phase_time = 0.0
				_angle = 0.0
	_place_hull()
	_moved = _hull.position - before
	# A swing turns the boat as well as shifting it, so a child standing out at
	# the bulkhead rises and falls by more than the hull's middle does. Carried
	# only by how far the middle moved, they were left behind by the deck under
	# them and had to fall onto it, or be shoved off it, every frame.
	if _hull.transform == before_at:
		_swept = Transform3D.IDENTITY
	else:
		_swept = (
			global_transform * _hull.transform * before_at.affine_inverse()
			* global_transform.affine_inverse()
		)

	# The bars: down while the boat is swinging, up again at rest — the same
	# cue the coaster and the drop tower both give.
	var wanted := 0.0 if _phase == Phase.STILL else 1.0
	_harness_closed = move_toward(_harness_closed, wanted, delta / RollerCoaster.HARNESS_TIME)
	for index in _harnesses.size():
		_harnesses[index].rotation.z = _harness_ends[index] * BAR_CLOSE * _harness_closed
	for held in _bar_shapes:
		held.disabled = _harness_closed < 0.99

## How far the hull moved whoever is standing in it, this frame. Mirrors
## FerrisWheel.carry() and DropTower.carry() — the hull is moved by hand, not
## by the engine, so a passenger standing in it has to be moved by hand too.
func carry(at: Vector3, _delta: float) -> Vector3:
	if not _inside_hull(at):
		return Vector3.ZERO
	return _swept * at - at

## Every seat as the hull stands now, in the world: the top of the cushion,
## facing the middle and tipping with the boat. For the checks and the viewer.
func seats() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for seat in _seats:
		out.append(_hull.global_transform * seat)
	return out

## The seat a child is standing on, or a point of NANs: a cushion a small step
## up from the deck, 0.6 deep and 0.8 across.
func seat_near(at: Vector3) -> Transform3D:
	for seat in _seats:
		var here := _hull.global_transform * seat
		var local := here.affine_inverse() * at
		if absf(local.x) < 0.5 and absf(local.z) < 0.4 and local.y > -0.2 and local.y < 0.4:
			return here
	return Transform3D(Basis(), Vector3(NAN, NAN, NAN))

## Whether the boat is standing still, waiting for its next swing. A ticket
## paid before it goes has bought nothing yet, so the game gives it back to a
## child who steps off.
func at_rest() -> bool:
	return _phase == Phase.STILL

## Whether a point is aboard the hull at all, swinging or not.
func aboard(at: Vector3) -> bool:
	return _inside_hull(at)

func _inside_hull(at: Vector3) -> bool:
	var local := _hull.global_transform.affine_inverse() * at
	return absf(local.x) < DECK_HALF and absf(local.z) < HULL_HALF_WIDTH and local.y > -0.6 and local.y < 2.2

## How far the swing has thrown, in radians either side of hanging straight
## down. For the checks.
func angle() -> float:
	return _angle
