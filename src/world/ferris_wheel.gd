class_name FerrisWheel
extends Node3D

## The big wheel: thirty metres to the top, turning slowly, with gondolas that
## stay upright as they go round.
##
## The rim and its spokes are scenery and simply rotate. The gondolas are not:
## each is an AnimatableBody3D moved to its own place on the rim every frame
## and never rotated, because a car on a wheel hangs level — and because a
## child standing in one is carried by it, which is what makes the ride a ride
## rather than a picture of one.

## The wheel's own size. The hub stands a little over its radius off the
## ground, so the top of the rim is thirty metres up.
## Fifty metres across, which puts the top of it at nearly fifty-three: the
## tallest thing in the valley by a long way, and visible from the camp, which
## is most of what a big wheel is for. A hundred was asked for and will not
## go — the fairground is forty metres across and a hundred-metre wheel turns
## in the same plane as the coaster runs in, so it would have swallowed it.
const RADIUS := 25.0
## High enough that the lowest gondola hangs clear of the sand: the hub is the
## wheel's radius, plus the length the cars hang, plus the step a child takes
## up into one. Set to the radius alone, the bottom of the ride was half a
## metre underground and the whole thing looked buried.
## The gondolas are half again as big as they were: a family fits in one, and
## on a fifty-metre wheel a small car looks like a bucket anyway. Everything
## about a car is built through this, including how far it hangs — a bigger
## car with the same hanger puts its roof through the pin it swings on.
const CAR_SCALE := 1.5
const HANGS_BELOW := 2.0 * CAR_SCALE
const BOARDING_HEIGHT := 0.9
const HUB_HEIGHT := RADIUS + HANGS_BELOW + BOARDING_HEIGHT
const GONDOLAS := 10
## A turn every two minutes: a whole ride is a long slow look at the valley.
const TURN_RATE := deg_to_rad(3.0)

## The boarding platform, the button on it, and how long a gondola waits when
## the button is pressed.
##
## The wheel turns all day and nobody can board a moving gondola: a child
## chased the doorway round and got a shin. So there is a platform level with
## the lowest car and a button on it, and the button is the whole of the
## mechanism — press it, the next gondola comes round to the boards and stands
## there for ten seconds, and if nobody presses it the wheel simply turns.
## Right up against the doorway: the boards reach to within a hand's breadth
## of the sill, because a gap between a platform and a car is the one place on
## a fairground a small foot goes down.
const PLATFORM_AT := Vector3(-(1.2 * CAR_SCALE + 0.14 + 1.5), 0.0, 0.0)
const PLATFORM_SIZE := Vector3(3.0, 0.24, 4.4)
const PLATFORM_STEPS := 4
const PLATFORM_RUN := 2.4
## Where the button stands, on the platform, by the doorway.
const BUTTON_AT := Vector3(PLATFORM_AT.x - 0.9, 0.0, 1.55)
const BUTTON_HEIGHT := 1.05
## How close a child has to be to press it.
const BUTTON_REACH := 1.9
## How long the gondola stands at the boards.
const HOLD := 10.0

const BUTTON := Color(0.86, 0.22, 0.20)
const BUTTON_LIT := Color(0.42, 0.86, 0.36)
const DECK := Color(0.58, 0.55, 0.52)

## The bar across a doorway: how high it sits, how long it takes to lift, and
## what colour it is painted.
const BAR_HEIGHT := 0.95
const BAR_TIME := 0.7
const BAR_COLOUR := Color(0.94, 0.78, 0.20)
## How far it rises out of the way.
const BAR_LIFT := 1.25

const STEEL := Color(0.72, 0.74, 0.78)
const HUB_COLOUR := Color(0.40, 0.43, 0.48)
## The lamps round the rim: the one thing on the wheel that is not steel.
const LAMP := Color(1.0, 0.92, 0.66)

var _rim: Node3D
var _cars: Array[AnimatableBody3D] = []
var _turned := 0.0
## A gondola has been called for, and how long the one at the boards has left
## to stand there.
var _called := false
var _holding := 0.0
## The safety bars across the doorways, and how far each is lifted.
var _gates: Array[Node3D] = []
var _gate_shapes: Array[CollisionShape3D] = []
var _gates_open: Array[float] = []

## The button's own cap, so it can be seen to go in and light up.
var _cap: MeshInstance3D
var _cap_paint: StandardMaterial3D

func _init(at: Vector3) -> void:
	name = "FerrisWheel"
	position = at

	var still := SurfaceTool.new()
	still.begin(Mesh.PRIMITIVE_TRIANGLES)
	var turning := SurfaceTool.new()
	turning.begin(Mesh.PRIMITIVE_TRIANGLES)

	_rim = Node3D.new()
	_rim.name = "Rim"
	# At the hub, not at the wheel's feet.
	#
	# The rim was built at its true height and then hung on a node standing on
	# the ground, and turning that node swung the whole wheel about a point in
	# the sand: half a turn put the rim under the fairground. It looked like
	# the wheel had come off its axle, because that is exactly what it was
	# doing. A thing that spins must be built about the point it spins on.
	_rim.position = Vector3(0.0, HUB_HEIGHT, 0.0)
	add_child(_rim)

	# Two A-frames carrying the axle, one on each side of the wheel.
	#
	# The wheel turns in the plane that runs along the river, parallel to the
	# coaster beside it: a big wheel set across a narrow fairground shows a
	# child its edge from most of the ground and its whole face from nowhere
	# they are likely to stand. So the gondolas travel in z and y, the axle
	# lies across in x, and the frames straddle the wheel in x while each
	# A leans apart in z.
	#
	# Each leg is cut to reach from the ground to the hub — its length and its
	# lean worked out from the two, rather than a height and an angle guessed
	# at. Guessed at, the feet went under the ground and the ride looked
	# buried.
	# The frame is solid. It was not, and a child walked straight through the
	# legs of a thirty-metre wheel as though it were painted on — the same
	# fault a tree with no trunk collider has, and just as plain to see.
	var frame := StaticBody3D.new()
	frame.name = "Frame"
	add_child(frame)

	# An A, not a V.
	#
	# The lean was applied the wrong way round, so every leg ran from a single
	# point on the sand up to a top splayed five metres away from the axle it
	# was supposed to be carrying: the whole wheel stood on one line of
	# contact, the foot plates sat five metres from any foot, and the boarding
	# platform was later put down exactly where that line was. A frame's feet
	# are apart and its top is at the hub.
	var spread := HUB_HEIGHT * 0.34
	var length := sqrt(HUB_HEIGHT * HUB_HEIGHT + spread * spread)
	for side: float in [-1.0, 1.0]:
		for lean: float in [-1.0, 1.0]:
			var leg := CylinderMesh.new()
			leg.top_radius = 0.16
			leg.bottom_radius = 0.26
			leg.height = length
			leg.radial_segments = 10
			leg.rings = 1
			Park._add(
				still, leg,
				Transform3D(
					Basis(Vector3.RIGHT, -lean * atan2(spread, HUB_HEIGHT)),
					Vector3(side * 2.6, HUB_HEIGHT * 0.5, lean * spread * 0.5)
				),
				STEEL
			)
			Park._solid(
				frame, Vector3(0.5, length, 0.5),
				Transform3D(
					Basis(Vector3.RIGHT, -lean * atan2(spread, HUB_HEIGHT)),
					Vector3(side * 2.6, HUB_HEIGHT * 0.5, lean * spread * 0.5)
				)
			)
			# A foot plate, so the leg meets the sand rather than ending in it.
			var plate := CylinderMesh.new()
			plate.top_radius = 0.44
			plate.bottom_radius = 0.54
			plate.height = 0.18
			plate.radial_segments = 10
			plate.rings = 1
			Park._add(
				still, plate,
				Transform3D(Basis(), Vector3(side * 2.6, 0.11, lean * spread)),
				HUB_COLOUR
			)
		# Ties across each A, and a diagonal in each bay: an A-frame without
		# them is two sticks leaning on one another.
		for rung in 2:
			var height := HUB_HEIGHT * (0.30 + 0.30 * float(rung))
			var across := spread * (1.0 - height / HUB_HEIGHT)
			var tie := BoxMesh.new()
			tie.size = Vector3(0.12, 0.12, across * 2.0)
			Park._add(
				still, tie,
				Transform3D(Basis(), Vector3(side * 2.6, height, 0.0)),
				STEEL
			)
		# And a tie between the two frames, under the hub.
		var span := BoxMesh.new()
		span.size = Vector3(5.2, 0.16, 0.16)
		Park._add(
			still, span,
			Transform3D(Basis(), Vector3(0.0, HUB_HEIGHT * 0.70, side * 0.0)),
			STEEL
		)

	var axle := CylinderMesh.new()
	axle.top_radius = 0.42
	axle.bottom_radius = 0.42
	axle.height = 6.0
	axle.radial_segments = 12
	axle.rings = 1
	Park._add(
		still, axle,
		Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.0, HUB_HEIGHT, 0.0)),
		HUB_COLOUR
	)

	# The hub itself: a drum with a ring of bolts, which is the detail that
	# makes the middle of a wheel read as engineering.
	for face: float in [-1.0, 1.0]:
		var drum := CylinderMesh.new()
		drum.top_radius = 1.15
		drum.bottom_radius = 1.15
		drum.height = 0.5
		drum.radial_segments = 16
		drum.rings = 1
		Park._add(
			still, drum,
			Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(face * 1.5, HUB_HEIGHT, 0.0)),
			HUB_COLOUR
		)

	# The rim: two hoops on either side of the wheel's plane, spokes between
	# the hub and the rim, and a lamp at every second spoke.
	for face: float in [-1.0, 1.0]:
		var hoop := TorusMesh.new()
		hoop.inner_radius = RADIUS - 0.26
		hoop.outer_radius = RADIUS + 0.26
		hoop.rings = 44
		hoop.ring_segments = 6
		Park._add(
			turning, hoop,
			Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(face * 1.9, 0.0, 0.0)),
			STEEL
		)
	for spoke in GONDOLAS * 2:
		var angle := TAU * float(spoke) / float(GONDOLAS * 2)
		var out := Vector3(0.0, cos(angle), sin(angle))
		for face: float in [-1.0, 1.0]:
			var bar := BoxMesh.new()
			bar.size = Vector3(0.12, RADIUS, 0.12)
			Park._add(
				turning, bar,
				Transform3D(
					Basis(Vector3.RIGHT, -angle),
					Vector3(face * 1.9, 0.0, 0.0) + out * (RADIUS * 0.5)
				),
				STEEL
			)
		# Cross-bracing between the two hoops, in the same triangles a real
		# wheel is braced with.
		var brace := BoxMesh.new()
		brace.size = Vector3(3.8, 0.10, 0.10)
		Park._add(
			turning, brace,
			Transform3D(Basis(Vector3.RIGHT, -angle), out * RADIUS),
			STEEL
		)
		if spoke % 2 == 0:
			var lamp := SphereMesh.new()
			lamp.radius = 0.24
			lamp.height = 0.48
			lamp.radial_segments = 8
			lamp.rings = 5
			Park._add(
				turning, lamp,
				Transform3D(Basis(), out * (RADIUS + 0.5)),
				LAMP
			)

	_build_platform(still)
	Park.commit(still, self, "Frame")
	Park.commit(turning, _rim, "Wheel")

	# The gondolas.
	for car in GONDOLAS:
		_cars.append(_build_car(car))
	_place_cars()

## The boarding platform, its steps, and the button.
##
## Level with the floor of the lowest gondola, on the side its doorway faces,
## and clear of the legs — which straddle the wheel across the axle while the
## platform stands along it.
func _build_platform(tool: SurfaceTool) -> void:
	var body := StaticBody3D.new()
	body.name = "Platform"
	add_child(body)

	var top := boarding_floor()
	var deck := BoxMesh.new()
	deck.size = PLATFORM_SIZE
	var where := PLATFORM_AT + Vector3(0.0, top - PLATFORM_SIZE.y * 0.5, 0.0)
	Park._add(tool, deck, Transform3D(Basis(), where), DECK)
	Park._solid(body, deck.size, Transform3D(Basis(), where))

	# Legs under it, and a rail along the back so nobody steps off it into the
	# wheel's own frame.
	for post in 4:
		var leg := BoxMesh.new()
		leg.size = Vector3(0.18, where.y, 0.18)
		Park._add(
			tool, leg,
			Transform3D(Basis(), Vector3(
				where.x + (-1.0 if post % 2 == 0 else 1.0) * (PLATFORM_SIZE.x * 0.4),
				where.y * 0.5,
				where.z + (-1.0 if post < 2 else 1.0) * (PLATFORM_SIZE.z * 0.4)
			)),
			DECK.darkened(0.3)
		)
	for side: float in [-1.0, 1.0]:
		var rail := BoxMesh.new()
		rail.size = Vector3(PLATFORM_SIZE.x, 0.10, 0.10)
		Park._add(
			tool, rail,
			Transform3D(Basis(), Vector3(
				where.x, top + 0.95, where.z + side * PLATFORM_SIZE.z * 0.5
			)),
			STEEL
		)
		for stanchion in 2:
			var post := BoxMesh.new()
			post.size = Vector3(0.10, 0.95, 0.10)
			Park._add(
				tool, post,
				Transform3D(Basis(), Vector3(
					where.x + (float(stanchion) - 0.5) * PLATFORM_SIZE.x * 0.8,
					top + 0.47,
					where.z + side * PLATFORM_SIZE.z * 0.5
				)),
				STEEL
			)

	# The way up: a flight drawn, a ramp walked. A character body climbs
	# slopes and stops dead at a riser, so a staircase of boxes is a wall with
	# a pattern on it.
	var foot := where.x - PLATFORM_SIZE.x * 0.5 - PLATFORM_RUN * 0.5
	for tread in PLATFORM_STEPS:
		var up := top * float(tread + 1) / float(PLATFORM_STEPS)
		var along := PLATFORM_RUN * ((float(tread) + 0.5) / float(PLATFORM_STEPS) - 0.5)
		var step := BoxMesh.new()
		step.size = Vector3(PLATFORM_RUN / float(PLATFORM_STEPS) + 0.04, 0.16, PLATFORM_SIZE.z * 0.6)
		Park._add(
			tool, step, Transform3D(Basis(), Vector3(foot + along, up, where.z)), DECK
		)
	Park._solid(
		body,
		Vector3(Vector2(PLATFORM_RUN, top).length(), 0.24, PLATFORM_SIZE.z * 0.6),
		Transform3D(
			Basis(Vector3.BACK, atan2(top, PLATFORM_RUN)),
			Vector3(foot, top * 0.5 - 0.06, where.z)
		)
	)

	# And the button: a post with a red cap on it, which is the only control
	# on this ride and has to look like one from across the fairground.
	var pillar := CylinderMesh.new()
	pillar.top_radius = 0.16
	pillar.bottom_radius = 0.20
	pillar.height = BUTTON_HEIGHT
	pillar.radial_segments = 10
	pillar.rings = 1
	var stand := BUTTON_AT + Vector3(0.0, top + BUTTON_HEIGHT * 0.5, 0.0)
	Park._add(tool, pillar, Transform3D(Basis(), stand), HUB_COLOUR)
	Park._solid(body, Vector3(0.34, BUTTON_HEIGHT, 0.34), Transform3D(Basis(), stand))

	var cap := SurfaceTool.new()
	cap.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dome := SphereMesh.new()
	dome.radius = 0.19
	dome.height = 0.26
	dome.radial_segments = 12
	dome.rings = 6
	Park._add(cap, dome, Transform3D(Basis(), Vector3.ZERO), BUTTON)
	_cap = Park.commit(cap, self, "Button")
	_cap.position = BUTTON_AT + Vector3(0.0, top + BUTTON_HEIGHT + 0.06, 0.0)
	_cap_paint = StandardMaterial3D.new()
	_cap_paint.albedo_color = BUTTON
	_cap.material_override = _cap_paint

## How high the floor of the gondola at the bottom of the wheel is, in the
## wheel's own frame: what the platform has to be level with.
func boarding_floor() -> float:
	return HUB_HEIGHT - RADIUS - HANGS_BELOW + 0.08 * CAR_SCALE

## Where the button is, in the world.
func button_at() -> Vector3:
	return global_position + BUTTON_AT + Vector3(
		0.0, boarding_floor() + BUTTON_HEIGHT + 0.06, 0.0
	)

## Is somebody standing at the button, with anything to ask for? A gondola
## already on its way, or one standing at the boards, needs nothing.
func at_the_button(at: Vector3) -> bool:
	if at.distance_to(button_at()) > BUTTON_REACH:
		return false
	return not _called and _holding <= 0.0

## A ride has been paid for: the next gondola comes round to the boards and
## stands there. The paying happens at the button now rather than when a child
## steps into a car — see the note on the coaster's, which works the same way,
## and which this was made to match after a report that there was no way to
## buy a ride at the wheel at all.
func book() -> void:
	if _called or _holding > 0.0:
		return
	_called = true

## How far the bar on one gondola is lifted: nought closed, one open. For the
## checks.
func bar_open(index: int) -> float:
	if index >= _gates_open.size():
		return 0.0
	return float(_gates_open[index])

## Is a gondola standing at the boards, and for how much longer?
func waiting() -> float:
	return _holding

## Has one been called for?
func called() -> bool:
	return _called

## One gondola: a floor with a rail round it and a hood over the back, hung
## from the rim.
## One gondola: a floor with a rail round it, a roof over it and the hanger it
## swings from.
##
## In the wheel's own steel rather than a colour of its own. Painted a
## different colour each, ten of them read as ten boxes flying in formation
## near a wheel rather than as part of it — and the thing that says a gondola
## belongs to the wheel is that it is made of the same metal.
func _build_car(index: int) -> AnimatableBody3D:
	var car := AnimatableBody3D.new()
	car.name = "Gondola%d" % index
	# Not a moving platform as far as physics is concerned: the ride moves its
	# passengers itself, and letting Godot move them as well carried them half
	# again as far as the car they were standing in.
	car.sync_to_physics = false
	add_child(car)

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var floor_slab := BoxMesh.new()
	floor_slab.size = Vector3(2.4, 0.16, 2.0) * CAR_SCALE
	Park._add(tool, floor_slab, Transform3D(Basis(), Vector3.ZERO), HUB_COLOUR)
	_solid(car, floor_slab.size, Vector3.ZERO)

	# Waist-high sides, and open above them: a gondola is a thing you look out
	# of. High enough that nobody steps out over the side of something twenty
	# metres up — except on one side, which is the doorway.
	#
	# It had four walls and no way in: a child could stand on the roof of one
	# and never sit in it. The open side faces along the axle, which is the
	# side you walk up to the wheel from; the other three are closed, because
	# those are the sides that are over nothing.
	for wall: Array in [
		[Vector3(2.4, 1.10, 0.14) * CAR_SCALE, Vector3(0.0, 0.55, 1.0) * CAR_SCALE],
		[Vector3(2.4, 1.10, 0.14) * CAR_SCALE, Vector3(0.0, 0.55, -1.0) * CAR_SCALE],
		[Vector3(0.14, 1.10, 2.0) * CAR_SCALE, Vector3(1.2, 0.55, 0.0) * CAR_SCALE],
	]:
		var size: Vector3 = wall[0]
		var where: Vector3 = wall[1]
		var panel := BoxMesh.new()
		panel.size = size
		Park._add(tool, panel, Transform3D(Basis(), where), STEEL)
		_solid(car, size, where)

	# The doorway: a sill across the floor and a post at each jamb, so the way
	# in reads as a way in rather than as a missing wall.
	var sill := BoxMesh.new()
	sill.size = Vector3(0.14, 0.22, 2.0) * CAR_SCALE
	# Drawn, not solid.
	#
	# A character body climbs slopes and steps over nothing whatever, so a
	# sill a foot high across the way in is a wall with a threshold painted on
	# it: getting into a gondola meant finding the one gap in it. What keeps a
	# child in is the bar that comes down over the doorway, not a lip on the
	# floor — see the note on the bar below.
	var sill_at := Vector3(-1.2, 0.06, 0.0) * CAR_SCALE
	sill.size = Vector3(0.14, 0.10, 2.0) * CAR_SCALE
	Park._add(tool, sill, Transform3D(Basis(), sill_at), HUB_COLOUR)
	for jamb: float in [-1.0, 1.0]:
		var post := BoxMesh.new()
		post.size = Vector3(0.16, 1.10, 0.18) * CAR_SCALE
		var jamb_at := Vector3(-1.2, 0.55, jamb * 0.91) * CAR_SCALE
		Park._add(tool, post, Transform3D(Basis(), jamb_at), STEEL)
		_solid(car, post.size, jamb_at)

	# A bench across the back, which is what you came up here to sit on.
	var bench := BoxMesh.new()
	bench.size = Vector3(1.0, 0.16, 1.7) * CAR_SCALE
	var bench_at := Vector3(0.62, 0.52, 0.0) * CAR_SCALE
	Park._add(tool, bench, Transform3D(Basis(), bench_at), HUB_COLOUR)
	_solid(car, bench.size, bench_at)
	var back := BoxMesh.new()
	back.size = Vector3(0.14, 0.52, 1.7) * CAR_SCALE
	Park._add(tool, back, Transform3D(Basis(), Vector3(1.06, 0.86, 0.0) * CAR_SCALE), HUB_COLOUR)

	# Corner posts and a roof, which is what turns a box into a car.
	for corner: Vector2 in [
		Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(-1.0, 1.0), Vector2(1.0, 1.0)
	]:
		var post := BoxMesh.new()
		post.size = Vector3(0.08, 0.85, 0.08) * CAR_SCALE
		Park._add(
			tool, post,
			Transform3D(Basis(), Vector3(corner.x * 1.15, 1.48, corner.y * 0.95) * CAR_SCALE),
			STEEL
		)
	var roof := BoxMesh.new()
	roof.size = Vector3(2.5, 0.10, 2.1) * CAR_SCALE
	Park._add(tool, roof, Transform3D(Basis(), Vector3(0.0, 1.95, 0.0) * CAR_SCALE), HUB_COLOUR)

	# The hanger: two arms up to the rim, and the pin they swing on.
	# From the top of the car's own side up to the pin, and no further: they
	# used to start at the roof and end above the rim, so the gondolas looked
	# hung on nothing at all.
	for side: float in [-1.0, 1.0]:
		var arm := BoxMesh.new()
		arm.size = Vector3(0.14, HANGS_BELOW - 0.55 * CAR_SCALE, 0.14)
		Park._add(
			tool, arm,
			Transform3D(
				Basis(),
				Vector3(
					side * 1.55 * CAR_SCALE,
					0.55 * CAR_SCALE + (HANGS_BELOW - 0.55 * CAR_SCALE) * 0.5,
					0.0
				)
			),
			STEEL
		)
		# The bracket where the arm meets the car, which is what says the two
		# are bolted together rather than passing one another.
		var bracket := BoxMesh.new()
		bracket.size = Vector3(0.34, 0.26, 0.5) * CAR_SCALE
		Park._add(
			tool, bracket,
			Transform3D(Basis(), Vector3(side * 1.4, 0.62, 0.0) * CAR_SCALE),
			HUB_COLOUR
		)
	var pin := CylinderMesh.new()
	pin.top_radius = 0.16
	pin.bottom_radius = 0.16
	pin.height = 3.6 * CAR_SCALE
	pin.radial_segments = 8
	pin.rings = 1
	Park._add(
		tool, pin,
		Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.0, HANGS_BELOW, 0.0)),
		HUB_COLOUR
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

	# The safety bar: a П across the doorway at waist height, which lifts like
	# a level-crossing gate while the gondola is standing at the boards and
	# drops as soon as the wheel turns again.
	#
	# The doorway needs something across it — a gondola forty metres up with
	# an open side is not a thing to put a six-year-old in — and it must not be
	# something to climb over on the way in, which is what the sill was.
	var gate := Node3D.new()
	gate.name = "Bar"
	gate.position = Vector3(-1.2 * CAR_SCALE, 0.0, 0.0)
	car.add_child(gate)

	var rail_tool := SurfaceTool.new()
	rail_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var crossbar := BoxMesh.new()
	crossbar.size = Vector3(0.14, 0.14, 2.0 * CAR_SCALE)
	Park._add(
		rail_tool, crossbar,
		Transform3D(Basis(), Vector3(0.0, BAR_HEIGHT, 0.0)), BAR_COLOUR
	)
	for end: float in [-1.0, 1.0]:
		var stile := BoxMesh.new()
		stile.size = Vector3(0.12, BAR_HEIGHT * 0.5, 0.12)
		Park._add(
			rail_tool, stile,
			Transform3D(Basis(), Vector3(
				0.0, BAR_HEIGHT * 0.75, end * (0.92 * CAR_SCALE)
			)),
			BAR_COLOUR
		)
	Park.commit(rail_tool, gate, "Rail")

	# The collider hangs on the car, not on the gate.
	#
	# A CollisionShape3D only counts as part of the body it is a direct child
	# of. Hung under the plain node that lifts the bar, it was ignored
	# outright — the bar was drawn, it went up and down, and a child walked
	# straight through it. So the shape is the car's own, and it is moved by
	# hand alongside the drawn one.
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.24, BAR_HEIGHT * 0.8, 2.0 * CAR_SCALE)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = gate.position + Vector3(0.0, BAR_HEIGHT * 0.7, 0.0)
	car.add_child(collider)

	_gates.append(gate)
	_gate_shapes.append(collider)
	_gates_open.append(0.0)
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
		var angle := _turned + TAU * float(index) / float(_cars.size())
		# Hung below the rim, and never turned: a gondola stays level however
		# far round the wheel it has gone.
		_cars[index].transform = Transform3D(Basis(), Vector3(
			0.0,
			HUB_HEIGHT + cos(angle) * RADIUS - HANGS_BELOW,
			sin(angle) * RADIUS
		))

func _physics_process(delta: float) -> void:
	var before: Array[Vector3] = []
	for car in _cars:
		before.append(car.position)

	if _holding > 0.0:
		# Standing at the boards. Nothing turns, which is the point: this is
		# the only ten seconds in which a six-year-old can get into a gondola.
		_holding = maxf(0.0, _holding - delta)
	else:
		# A gondola arrives at the boards every tenth of a turn. Whether one
		# has just arrived is asked by watching how far the wheel is from the
		# next arrival: that distance shrinks as it turns and jumps back up
		# the moment it passes one.
		var step := TAU / float(GONDOLAS)
		var was := fposmod(PI - _turned, step)
		_turned = fmod(_turned + TURN_RATE * delta, TAU)
		var now := fposmod(PI - _turned, step)
		if _called and now > was:
			# Wound back the hair it overshot by, so the doorway is square
			# with the platform rather than nearly square with it.
			_turned = fposmod(_turned - (step - now), TAU)
			_called = false
			_holding = HOLD
	_rim.rotation.x = -_turned
	_place_cars()

	# The bar over the doorway of whichever gondola is standing at the boards
	# is lifted; every other one is down. Which car that is is asked of the
	# cars themselves — the one nearest the platform — rather than worked out
	# from the angle a second time.
	var boarding_car := -1
	if _holding > 0.0:
		boarding_car = 0
		for index in _cars.size():
			if absf(_cars[index].position.z) < absf(_cars[boarding_car].position.z):
				boarding_car = index
	for index in _gates.size():
		var wanted := 1.0 if index == boarding_car else 0.0
		_gates_open[index] = move_toward(
			float(_gates_open[index]), wanted, delta / BAR_TIME
		)
		var open := float(_gates_open[index])
		_gates[index].position.y = open * BAR_LIFT
		_gate_shapes[index].position.y = BAR_HEIGHT * 0.7 + open * BAR_LIFT
		# Solid until it is most of the way up, so nobody walks through a bar
		# that is still coming down.
		_gate_shapes[index].disabled = open > 0.6

	if _cap != null:
		# The button goes in while a gondola is on its way and lights up while
		# one is standing there — a control that does nothing visible when it
		# is pressed is a control a child presses again and again.
		_cap.position.y = (
			boarding_floor() + BUTTON_HEIGHT + (0.0 if _called else 0.06)
		)
		# Green from the moment a ride is bought, not only once the gondola is
		# standing there: what a child wants to know is that the button
		# worked, and the gondola takes up to twelve seconds to come round.
		_cap_paint.albedo_color = (
			BUTTON_LIT if (_called or _holding > 0.0) else BUTTON
		)
	_moved.clear()
	for index in _cars.size():
		_moved.append(_cars[index].position - before[index])

## How far each gondola moved on the last frame, so that whoever is standing in
## one can be moved with it.
var _moved: Array[Vector3] = []

## How far the ride moves whoever is aboard, this frame.
##
## Godot leaves a character standing in a body that is being moved by hand: the
## gondola rises out from under them and they drop back onto its floor, over
## and over, which is a ride that shakes rather than one that lifts.
func carry(at: Vector3, _delta: float) -> Vector3:
	for index in _cars.size():
		if index >= _moved.size():
			break
		if inside_a_gondola(at - _cars[index].global_position):
			return _moved[index]
	return Vector3.ZERO

## Is this point, measured from a gondola's own middle, inside it? Asked by
## the ride and by the fairground alike, so a car that grows does not leave
## one of them testing the old box.
static func inside_a_gondola(local: Vector3) -> bool:
	return (
		absf(local.x) < 1.2 * CAR_SCALE and absf(local.z) < 1.0 * CAR_SCALE
		and local.y > -0.4 and local.y < 2.2 * CAR_SCALE
	)

## How high the topmost gondola rides, and how far round the wheel has gone.
## For the checks.
func top_of_the_ride() -> float:
	return HUB_HEIGHT + RADIUS

func turned() -> float:
	return _turned

## Where a point on the rim is, once the wheel has turned. For the checks:
## this is the thing that was wrong, and it cannot be seen from the constants.
func rim_point(angle: float) -> Vector3:
	return _rim.transform * Vector3(0.0, cos(angle) * RADIUS, sin(angle) * RADIUS)

func gondola(index: int) -> Node3D:
	return _cars[index]
