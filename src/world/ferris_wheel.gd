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
const RADIUS := 13.6
## High enough that the lowest gondola hangs clear of the sand: the hub is the
## wheel's radius, plus the length the cars hang, plus the step a child takes
## up into one. Set to the radius alone, the bottom of the ride was half a
## metre underground and the whole thing looked buried.
const HANGS_BELOW := 2.0
const BOARDING_HEIGHT := 0.9
const HUB_HEIGHT := RADIUS + HANGS_BELOW + BOARDING_HEIGHT
const GONDOLAS := 10
## A turn every two minutes: a whole ride is a long slow look at the valley.
const TURN_RATE := deg_to_rad(3.0)

const STEEL := Color(0.72, 0.74, 0.78)
const HUB_COLOUR := Color(0.40, 0.43, 0.48)
## The lamps round the rim: the one thing on the wheel that is not steel.
const LAMP := Color(1.0, 0.92, 0.66)

var _rim: Node3D
var _cars: Array[AnimatableBody3D] = []
var _turned := 0.0

func _init(at: Vector3) -> void:
	name = "FerrisWheel"
	position = at

	var still := SurfaceTool.new()
	still.begin(Mesh.PRIMITIVE_TRIANGLES)
	var turning := SurfaceTool.new()
	turning.begin(Mesh.PRIMITIVE_TRIANGLES)

	_rim = Node3D.new()
	_rim.name = "Rim"
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
					Basis(Vector3.RIGHT, lean * atan2(spread, HUB_HEIGHT)),
					Vector3(side * 2.6, HUB_HEIGHT * 0.5, lean * spread * 0.5)
				),
				STEEL
			)
			Park._solid(
				frame, Vector3(0.5, length, 0.5),
				Transform3D(
					Basis(Vector3.RIGHT, lean * atan2(spread, HUB_HEIGHT)),
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
			Transform3D(
				Basis(Vector3.BACK, PI * 0.5), Vector3(face * 1.9, HUB_HEIGHT, 0.0)
			),
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
					Vector3(face * 1.9, HUB_HEIGHT, 0.0) + out * (RADIUS * 0.5)
				),
				STEEL
			)
		# Cross-bracing between the two hoops, in the same triangles a real
		# wheel is braced with.
		var brace := BoxMesh.new()
		brace.size = Vector3(3.8, 0.10, 0.10)
		Park._add(
			turning, brace,
			Transform3D(
				Basis(Vector3.RIGHT, -angle),
				Vector3(0.0, HUB_HEIGHT, 0.0) + out * RADIUS
			),
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
				Transform3D(Basis(), Vector3(0.0, HUB_HEIGHT, 0.0) + out * (RADIUS + 0.5)),
				LAMP
			)

	Park.commit(still, self, "Frame")
	Park.commit(turning, _rim, "Wheel")

	# The gondolas.
	for car in GONDOLAS:
		_cars.append(_build_car(car))
	_place_cars()

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
	floor_slab.size = Vector3(2.4, 0.16, 2.0)
	Park._add(tool, floor_slab, Transform3D(Basis(), Vector3.ZERO), HUB_COLOUR)
	_solid(car, floor_slab.size, Vector3.ZERO)

	# Waist-high sides, and open above them: a gondola is a thing you look out
	# of. High enough that nobody steps out over the side of something twenty
	# metres up.
	for wall: Array in [
		[Vector3(2.4, 1.10, 0.14), Vector3(0.0, 0.55, 1.0)],
		[Vector3(2.4, 1.10, 0.14), Vector3(0.0, 0.55, -1.0)],
		[Vector3(0.14, 1.10, 2.0), Vector3(1.2, 0.55, 0.0)],
		[Vector3(0.14, 1.10, 2.0), Vector3(-1.2, 0.55, 0.0)],
	]:
		var size: Vector3 = wall[0]
		var where: Vector3 = wall[1]
		var panel := BoxMesh.new()
		panel.size = size
		Park._add(tool, panel, Transform3D(Basis(), where), STEEL)
		_solid(car, size, where)

	# Corner posts and a roof, which is what turns a box into a car.
	for corner: Vector2 in [
		Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(-1.0, 1.0), Vector2(1.0, 1.0)
	]:
		var post := BoxMesh.new()
		post.size = Vector3(0.08, 0.85, 0.08)
		Park._add(
			tool, post,
			Transform3D(Basis(), Vector3(corner.x * 1.15, 1.48, corner.y * 0.95)),
			STEEL
		)
	var roof := BoxMesh.new()
	roof.size = Vector3(2.5, 0.10, 2.1)
	Park._add(tool, roof, Transform3D(Basis(), Vector3(0.0, 1.95, 0.0)), HUB_COLOUR)

	# The hanger: two arms up to the rim, and the pin they swing on.
	# From the top of the car's own side up to the pin, and no further: they
	# used to start at the roof and end above the rim, so the gondolas looked
	# hung on nothing at all.
	for side: float in [-1.0, 1.0]:
		var arm := BoxMesh.new()
		arm.size = Vector3(0.14, HANGS_BELOW - 0.55, 0.14)
		Park._add(
			tool, arm,
			Transform3D(
				Basis(),
				Vector3(side * 1.55, 0.55 + (HANGS_BELOW - 0.55) * 0.5, 0.0)
			),
			STEEL
		)
		# The bracket where the arm meets the car, which is what says the two
		# are bolted together rather than passing one another.
		var bracket := BoxMesh.new()
		bracket.size = Vector3(0.34, 0.26, 0.5)
		Park._add(
			tool, bracket, Transform3D(Basis(), Vector3(side * 1.4, 0.62, 0.0)), HUB_COLOUR
		)
	var pin := CylinderMesh.new()
	pin.top_radius = 0.16
	pin.bottom_radius = 0.16
	pin.height = 3.6
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
	_turned = fmod(_turned + TURN_RATE * delta, TAU)
	_rim.rotation.x = -_turned
	_place_cars()
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
		var local := at - _cars[index].global_position
		if absf(local.x) < 1.2 and absf(local.z) < 1.0 and local.y > -0.4 and local.y < 2.2:
			return _moved[index]
	return Vector3.ZERO

## How high the topmost gondola rides, and how far round the wheel has gone.
## For the checks.
func top_of_the_ride() -> float:
	return HUB_HEIGHT + RADIUS

func turned() -> float:
	return _turned

func gondola(index: int) -> Node3D:
	return _cars[index]
