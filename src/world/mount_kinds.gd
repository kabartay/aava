class_name MountKinds
extends RefCounted

## The two things a child can ride, and how they differ.
##
## One file rather than two because a horse and a bicycle are the same problem:
## something that carries the player faster, turns more slowly, and changes what
## the camera should be doing. Writing that twice would mean fixing every bug in
## it twice.
##
## Where they differ is the interesting part. The horse can cross the river and
## climb; the bicycle is faster on the flat and refuses a steep slope. That is
## the whole reason to own both.

const HORSE := &"horse"
const BICYCLE := &"bicycle"
## A boat: the one mount that goes where the others cannot at all — across
## the pond — and nowhere else. Five of them wait at the big pond's shore.
const BOAT := &"boat"

const ALL: Array[StringName] = [HORSE, BICYCLE, BOAT]

## There is one horse and one bicycle, but several boats, so a mount is named
## by an id — "horse", or "boat:2" — and everything that wants to know what
## the thing *is* asks `kind_of`. Ids without a colon are their own kind.
static func kind_of(id: StringName) -> StringName:
	var text := String(id)
	var colon := text.find(":")
	return id if colon < 0 else StringName(text.substr(0, colon))

## The id of the n-th boat.
static func boat_id(index: int) -> StringName:
	return StringName("%s:%d" % [BOAT, index])

## Which boat an id is, or -1 for anything that is not one.
static func boat_index(id: StringName) -> int:
	var text := String(id)
	if not text.begins_with(String(BOAT) + ":"):
		return -1
	return text.substr(text.find(":") + 1).to_int()

## One hull colour per boat, so a child can say "the red one".
const BOAT_COLOURS: Array[Color] = [
	Color(0.84, 0.26, 0.22), Color(0.22, 0.44, 0.80), Color(0.30, 0.62, 0.32),
	Color(0.95, 0.78, 0.22), Color(0.92, 0.92, 0.88),
]
## How deep the hull sits, and how high above the water a child sits in it.
const BOAT_DRAFT := 0.3
const BOAT_SEAT := 0.25

const INFO := {
	HORSE: {
		# Fast, but the real reason to ride one is that it fords the river and
		# takes hills a bicycle cannot.
		"speed": 9.4,
		"turn": 2.6,
		"max_slope": 0.62,
		"fords": true,
		"floats": false,
		"eye": 1.05,
		"colour": Color(0.42, 0.29, 0.20),
	},
	BICYCLE: {
		# Faster than the horse on level ground and useless off it, which is
		# what a bicycle is.
		"speed": 11.2,
		"turn": 2.0,
		"max_slope": 0.28,
		"fords": false,
		"floats": false,
		"eye": 0.45,
		"colour": Color(0.90, 0.28, 0.24),
	},
	BOAT: {
		# Slower than a horse and much faster than swimming, which is the
		# whole comparison a boat is in. Turns like a boat: slowly.
		"speed": 6.0,
		"turn": 1.4,
		"max_slope": 9.0,
		"fords": true,
		"floats": true,
		"eye": 0.15,
		"colour": Color(0.84, 0.26, 0.22),
	},
}

static func speed(kind: StringName) -> float:
	return float(INFO[kind_of(kind)]["speed"])

static func turn_rate(kind: StringName) -> float:
	return float(INFO[kind_of(kind)]["turn"])

static func max_slope(kind: StringName) -> float:
	return float(INFO[kind_of(kind)]["max_slope"])

static func fords_water(kind: StringName) -> bool:
	return bool(INFO[kind_of(kind)]["fords"])

## Whether this mount rides on the water rather than the ground: a boat.
static func floats(kind: StringName) -> bool:
	return bool(INFO[kind_of(kind)]["floats"])

## How much higher the player sits than when standing.
static func eye_lift(kind: StringName) -> float:
	return float(INFO[kind_of(kind)]["eye"])

static func colour(kind: StringName) -> Color:
	var index := boat_index(kind)
	if index >= 0:
		return BOAT_COLOURS[index % BOAT_COLOURS.size()]
	return INFO[kind_of(kind)]["colour"]

static func label(kind: StringName) -> String:
	return Text.of("mount_%s" % kind_of(kind))

## A horse: a barrel body on four legs with a neck and a head, built from the
## same primitives as the animals so it belongs to the same world.
static func build_mesh(kind: StringName) -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind_of(kind):
		HORSE:
			_horse(tool)
		BOAT:
			_boat(tool, colour(kind))
		_:
			_bicycle(tool)
	tool.generate_normals()
	tool.set_material(AnimalKinds.fur_material())
	return tool.commit()

static func _horse(tool: SurfaceTool) -> void:
	var hide: Color = colour(HORSE)
	var dark := hide.darkened(0.3)

	var body := SphereMesh.new()
	body.radius = 0.52
	body.height = 1.0
	body.radial_segments = 10
	body.rings = 6
	_add(tool, body, Transform3D(
		Basis().scaled(Vector3(1.0, 0.92, 1.75)), Vector3(0.0, 1.32, 0.0)
	), hide)

	# The neck rises forward; without it a horse is a barrel with a ball on it.
	var neck := CylinderMesh.new()
	neck.top_radius = 0.19
	neck.bottom_radius = 0.28
	neck.height = 0.82
	neck.radial_segments = 8
	_add(tool, neck, Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(-38.0)), Vector3(0.0, 1.76, -0.72)
	), hide)

	var head := SphereMesh.new()
	head.radius = 0.21
	head.height = 0.5
	head.radial_segments = 8
	head.rings = 5
	_add(tool, head, Transform3D(
		Basis().scaled(Vector3(1.0, 1.0, 1.5)), Vector3(0.0, 2.06, -1.08)
	), hide)

	for side in PackedFloat32Array([-1.0, 1.0]):
		var ear := SphereMesh.new()
		ear.radius = 0.06
		ear.height = 0.2
		ear.radial_segments = 5
		ear.rings = 3
		_add(tool, ear, Transform3D(Basis(), Vector3(side * 0.09, 2.24, -1.0)), dark)

		for front in PackedFloat32Array([-1.0, 1.0]):
			var leg := CylinderMesh.new()
			leg.top_radius = 0.11
			leg.bottom_radius = 0.08
			leg.height = 1.3
			leg.radial_segments = 6
			_add(tool, leg, Transform3D(
				Basis(), Vector3(side * 0.3, 0.65, front * 0.62)
			), dark)

	# Mane and tail, which is most of what makes it read as a horse rather than
	# as a very large dog.
	var mane := BoxMesh.new()
	mane.size = Vector3(0.08, 0.34, 0.9)
	_add(tool, mane, Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(-38.0)), Vector3(0.0, 1.94, -0.76)
	), dark)

	var tail := CylinderMesh.new()
	tail.top_radius = 0.05
	tail.bottom_radius = 0.13
	tail.height = 0.78
	tail.radial_segments = 6
	_add(tool, tail, Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(28.0)), Vector3(0.0, 1.32, 1.0)
	), dark)

## A rowing boat, facing -Z like everything else that is ridden: a hull with a
## pointed bow and a flat stern, a pale wooden inside with two thwarts to sit
## on, and a pair of oars lying across the gunwales. The waterline is the
## node's origin, so the hull sits BOAT_DRAFT deep.
static func _boat(tool: SurfaceTool, hull: Color) -> void:
	var wood := Color(0.78, 0.64, 0.42)
	var dark := hull.darkened(0.3)
	var top := 0.5 - BOAT_DRAFT
	var middle := top - 0.25

	# An open hull — a bottom, two sides and a transom, with two boards angled
	# in to a point for the bow — rather than a solid block: the first version
	# was a box, whose top face hid the inside, and the boat read as a red
	# brick with oars on it.
	var bottom := BoxMesh.new()
	bottom.size = Vector3(1.24, 0.1, 2.0)
	_add(tool, bottom, Transform3D(Basis(), Vector3(0.0, middle - 0.2, 0.25)), hull)
	for side in PackedFloat32Array([-1.0, 1.0]):
		var wall := BoxMesh.new()
		wall.size = Vector3(0.08, 0.5, 2.0)
		_add(tool, wall, Transform3D(Basis(), Vector3(side * 0.6, middle, 0.25)), hull)
		var board := BoxMesh.new()
		board.size = Vector3(0.08, 0.5, 1.22)
		_add(tool, board, Transform3D(
			Basis(Vector3.UP, side * deg_to_rad(-30.6)),
			Vector3(side * 0.31, middle, -1.275)
		), hull)
	var stern := BoxMesh.new()
	stern.size = Vector3(1.28, 0.5, 0.08)
	_add(tool, stern, Transform3D(Basis(), Vector3(0.0, middle, 1.21)), hull)
	# The bow's bottom: a wedge, made of a box turned to lie along each board.
	var bow_bottom := BoxMesh.new()
	bow_bottom.size = Vector3(0.7, 0.1, 1.05)
	_add(tool, bow_bottom, Transform3D(Basis(), Vector3(0.0, middle - 0.2, -1.2)), hull)
	# The pale inside: a floor you can see between the thwarts.
	var floor_board := BoxMesh.new()
	floor_board.size = Vector3(1.1, 0.04, 1.95)
	_add(tool, floor_board, Transform3D(Basis(), Vector3(0.0, middle - 0.14, 0.25)), wood)
	var bow_floor := BoxMesh.new()
	bow_floor.size = Vector3(0.55, 0.04, 0.9)
	_add(tool, bow_floor, Transform3D(Basis(), Vector3(0.0, middle - 0.14, -1.1)), wood)
	var stem := CylinderMesh.new()
	stem.top_radius = 0.05
	stem.bottom_radius = 0.05
	stem.height = 0.62
	stem.radial_segments = 6
	_add(tool, stem, Transform3D(Basis(), Vector3(0.0, middle + 0.06, -1.76)), dark)

	# Gunwales, a shade darker, along both sides and across the stern.
	for side in PackedFloat32Array([-1.0, 1.0]):
		var rail := BoxMesh.new()
		rail.size = Vector3(0.1, 0.07, 2.0)
		_add(tool, rail, Transform3D(Basis(), Vector3(side * 0.62, top, 0.25)), dark)
	var transom := BoxMesh.new()
	transom.size = Vector3(1.3, 0.07, 0.1)
	_add(tool, transom, Transform3D(Basis(), Vector3(0.0, top, 1.25)), dark)

	# Two thwarts to sit on.
	for z in PackedFloat32Array([-0.35, 0.65]):
		var thwart := BoxMesh.new()
		thwart.size = Vector3(1.2, 0.06, 0.3)
		_add(tool, thwart, Transform3D(Basis(), Vector3(0.0, top - 0.12, z)), wood)

	# Oars across the gunwales, blades out over the water.
	for side in PackedFloat32Array([-1.0, 1.0]):
		var oar := CylinderMesh.new()
		oar.top_radius = 0.03
		oar.bottom_radius = 0.03
		oar.height = 2.3
		oar.radial_segments = 5
		# A cylinder stands along Y; laid across the boat and tipped down a
		# little on the outboard side.
		var lay := Basis(Vector3.FORWARD, side * deg_to_rad(90.0 + 12.0))
		_add(tool, oar, Transform3D(lay, Vector3(side * 0.75, top + 0.08, 0.1)), wood)
		var blade := BoxMesh.new()
		blade.size = Vector3(0.5, 0.03, 0.16)
		_add(tool, blade, Transform3D(lay * Basis(Vector3.FORWARD, deg_to_rad(-90.0)), Vector3(side * 1.75, top - 0.14, 0.1)), wood)

static func _bicycle(tool: SurfaceTool) -> void:
	# Tubes are deliberately thicker than a real bicycle's. At the distance a
	# child sees it across a valley, 4 cm of steel is one pixel and the whole
	# machine reads as a discarded toy; 7 cm reads as a bicycle.
	var frame: Color = colour(BICYCLE)
	var rubber := Color(0.16, 0.16, 0.18)

	# A TorusMesh lies in the XZ plane, so a wheel needs rotating about X to
	# stand upright — not about Y, which merely spins a flat ring and leaves the
	# bicycle looking like two hoops dropped on the grass.
	for front in PackedFloat32Array([-1.0, 1.0]):
		var wheel := TorusMesh.new()
		wheel.inner_radius = 0.28
		wheel.outer_radius = 0.38
		wheel.rings = 14
		wheel.ring_segments = 7
		_add(tool, wheel, Transform3D(
			Basis(Vector3.RIGHT, deg_to_rad(90.0)), Vector3(0.0, 0.38, front * 0.62)
		), rubber)

	# Frame: two bars from the wheels up to the saddle, and the handlebars.
	var down_tube := CylinderMesh.new()
	down_tube.top_radius = 0.075
	down_tube.bottom_radius = 0.075
	down_tube.height = 1.05
	down_tube.radial_segments = 6
	_add(tool, down_tube, Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(58.0)), Vector3(0.0, 0.62, -0.28)
	), frame)

	var seat_tube := CylinderMesh.new()
	seat_tube.top_radius = 0.075
	seat_tube.bottom_radius = 0.075
	seat_tube.height = 0.86
	seat_tube.radial_segments = 6
	_add(tool, seat_tube, Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(-22.0)), Vector3(0.0, 0.68, 0.34)
	), frame)

	var top_tube := CylinderMesh.new()
	top_tube.top_radius = 0.07
	top_tube.bottom_radius = 0.07
	top_tube.height = 0.92
	top_tube.radial_segments = 6
	_add(tool, top_tube, Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(90.0)), Vector3(0.0, 0.94, 0.0)
	), frame)

	var bars := CylinderMesh.new()
	bars.top_radius = 0.06
	bars.bottom_radius = 0.06
	bars.height = 0.52
	bars.radial_segments = 6
	_add(tool, bars, Transform3D(
		Basis(Vector3.FORWARD, deg_to_rad(90.0)), Vector3(0.0, 1.06, -0.52)
	), rubber)

	var saddle := BoxMesh.new()
	saddle.size = Vector3(0.20, 0.10, 0.40)
	_add(tool, saddle, Transform3D(Basis(), Vector3(0.0, 1.12, 0.42)), rubber)

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
