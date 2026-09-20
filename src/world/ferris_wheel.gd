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
const HUB_HEIGHT := 15.4
const GONDOLAS := 10
## A turn every two minutes: a whole ride is a long slow look at the valley.
const TURN_RATE := deg_to_rad(3.0)

const STEEL := Color(0.72, 0.74, 0.78)
const HUB_COLOUR := Color(0.40, 0.43, 0.48)
const CAR_COLOURS: Array[Color] = [
	Color(0.86, 0.28, 0.26), Color(0.95, 0.72, 0.24), Color(0.30, 0.56, 0.82),
	Color(0.36, 0.68, 0.40), Color(0.78, 0.42, 0.76),
]

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

	# Two A-frames, one each side, carrying the axle. A wheel on a single post
	# reads as a windmill.
	for side: float in [-1.0, 1.0]:
		for lean: float in [-1.0, 1.0]:
			var leg := CylinderMesh.new()
			leg.top_radius = 0.22
			leg.bottom_radius = 0.34
			leg.height = HUB_HEIGHT * 1.02
			leg.radial_segments = 8
			leg.rings = 1
			var foot := Vector3(side * 2.4, HUB_HEIGHT * 0.5, lean * HUB_HEIGHT * 0.30)
			Park._add(
				still, leg,
				Transform3D(Basis(Vector3.RIGHT, -lean * deg_to_rad(17.0)), foot),
				STEEL
			)
	var axle := CylinderMesh.new()
	axle.top_radius = 0.45
	axle.bottom_radius = 0.45
	axle.height = 5.4
	axle.radial_segments = 12
	axle.rings = 1
	Park._add(
		still, axle,
		Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0.0, HUB_HEIGHT, 0.0)),
		HUB_COLOUR
	)

	# The rim itself: two hoops with spokes between them, drawn about the hub
	# and turned as one.
	for face: float in [-1.0, 1.0]:
		var hoop := TorusMesh.new()
		hoop.inner_radius = RADIUS - 0.22
		hoop.outer_radius = RADIUS + 0.22
		hoop.rings = 40
		hoop.ring_segments = 6
		Park._add(
			turning, hoop,
			Transform3D(
				Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, HUB_HEIGHT, face * 1.9)
			),
			STEEL
		)
	for spoke in GONDOLAS * 2:
		var angle := TAU * float(spoke) / float(GONDOLAS * 2)
		var bar := BoxMesh.new()
		bar.size = Vector3(0.14, RADIUS, 0.14)
		Park._add(
			turning, bar,
			Transform3D(
				Basis(Vector3.FORWARD, angle),
				Vector3(sin(angle) * RADIUS * 0.5, HUB_HEIGHT + cos(angle) * RADIUS * 0.5, 0.0)
			),
			STEEL
		)

	Park.commit(still, self, "Frame")
	Park.commit(turning, _rim, "Wheel")

	# The gondolas.
	for car in GONDOLAS:
		_cars.append(_build_car(car))
	_place_cars()

## One gondola: a floor with a rail round it and a hood over the back, hung
## from the rim.
func _build_car(index: int) -> AnimatableBody3D:
	var car := AnimatableBody3D.new()
	car.name = "Gondola%d" % index
	# Carried by hand every frame, and physics told so — otherwise a child
	# standing in one is left in mid-air as it rises.
	car.sync_to_physics = true
	add_child(car)

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var colour: Color = CAR_COLOURS[index % CAR_COLOURS.size()]

	var floor_slab := BoxMesh.new()
	floor_slab.size = Vector3(2.4, 0.16, 2.0)
	Park._add(tool, floor_slab, Transform3D(Basis(), Vector3.ZERO), colour.darkened(0.35))
	_solid(car, floor_slab.size, Vector3.ZERO)

	# Walls all round, high enough that nobody steps out over the side of
	# something twenty metres up.
	for wall: Array in [
		[Vector3(2.4, 1.15, 0.14), Vector3(0.0, 0.58, 1.0)],
		[Vector3(2.4, 1.15, 0.14), Vector3(0.0, 0.58, -1.0)],
		[Vector3(0.14, 1.15, 2.0), Vector3(1.2, 0.58, 0.0)],
		[Vector3(0.14, 1.15, 2.0), Vector3(-1.2, 0.58, 0.0)],
	]:
		var size: Vector3 = wall[0]
		var where: Vector3 = wall[1]
		var panel := BoxMesh.new()
		panel.size = size
		Park._add(tool, panel, Transform3D(Basis(), where), colour)
		_solid(car, size, where)

	# The hanger: the arm it swings from, up to the rim.
	var arm := BoxMesh.new()
	arm.size = Vector3(0.12, 1.9, 0.12)
	for side: float in [-1.0, 1.0]:
		Park._add(tool, arm, Transform3D(Basis(), Vector3(side * 1.1, 1.6, 0.0)), STEEL)

	tool.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.7
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
			sin(angle) * RADIUS,
			HUB_HEIGHT + cos(angle) * RADIUS - 2.3,
			0.0
		))

func _physics_process(delta: float) -> void:
	_turned = fmod(_turned + TURN_RATE * delta, TAU)
	_rim.rotation.z = -_turned
	_place_cars()

## How high the topmost gondola rides, and how far round the wheel has gone.
## For the checks.
func top_of_the_ride() -> float:
	return HUB_HEIGHT + RADIUS

func turned() -> float:
	return _turned

func gondola(index: int) -> Node3D:
	return _cars[index]
