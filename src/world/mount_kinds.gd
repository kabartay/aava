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

const ALL: Array[StringName] = [HORSE, BICYCLE]

const INFO := {
	HORSE: {
		# Fast, but the real reason to ride one is that it fords the river and
		# takes hills a bicycle cannot.
		"speed": 9.4,
		"turn": 2.6,
		"max_slope": 0.62,
		"fords": true,
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
		"eye": 0.45,
		"colour": Color(0.90, 0.28, 0.24),
	},
}

static func speed(kind: StringName) -> float:
	return float(INFO[kind]["speed"])

static func turn_rate(kind: StringName) -> float:
	return float(INFO[kind]["turn"])

static func max_slope(kind: StringName) -> float:
	return float(INFO[kind]["max_slope"])

static func fords_water(kind: StringName) -> bool:
	return bool(INFO[kind]["fords"])

## How much higher the player sits than when standing.
static func eye_lift(kind: StringName) -> float:
	return float(INFO[kind]["eye"])

static func colour(kind: StringName) -> Color:
	return INFO[kind]["colour"]

static func label(kind: StringName) -> String:
	return Text.of("mount_%s" % kind)

## A horse: a barrel body on four legs with a neck and a head, built from the
## same primitives as the animals so it belongs to the same world.
static func build_mesh(kind: StringName) -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	if kind == HORSE:
		_horse(tool)
	else:
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
