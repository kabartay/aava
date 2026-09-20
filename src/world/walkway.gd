class_name Walkway
extends Node3D

## The two moving walkways: flat belts that carry you along, side by side and
## running opposite ways, so a child can ride up one and back down the other.
##
## Nothing about them moves. A belt is a static body with a constant velocity
## written on it, which is how a conveyor is made: Godot pushes whatever stands
## on it at that speed, and the slats only have to look like they are going
## somewhere. A belt built out of moving parts would be fifteen metres of
## physics for an effect that is one line.

## How long each belt is, how far apart they stand, and how fast they run. Two
## metres a second is a brisk walk — faster than that and a six-year-old cannot
## get off at the end.
const LENGTH := 15.0
const WIDTH := 1.7
const GAP := 0.9
const SPEED := 2.0
const TOP := 0.32

const TREAD := Color(0.26, 0.28, 0.32)
const SLAT := Color(0.34, 0.37, 0.42)
const SIDE := Color(0.58, 0.55, 0.52)
const ARROW := Color(0.95, 0.85, 0.35)

var _sides: StaticBody3D

func _init(at: Vector3) -> void:
	name = "Walkway"
	position = at

	_sides = StaticBody3D.new()
	_sides.name = "Sides"
	add_child(_sides)

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	for side in 2:
		# One each way: the left belt carries you north, the right one south.
		var heading := 1.0 if side == 0 else -1.0
		var offset := (WIDTH + GAP) * (float(side) - 0.5)
		_build_belt(tool, offset, heading)

	tool.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.7
	tool.set_material(material)
	var drawn := MeshInstance3D.new()
	drawn.name = "Belts"
	drawn.mesh = tool.commit()
	add_child(drawn)

func _build_belt(tool: SurfaceTool, offset: float, heading: float) -> void:
	# The tread, and the ramps at each end so a child walks on rather than
	# steps up.
	var tread := BoxMesh.new()
	tread.size = Vector3(WIDTH, 0.18, LENGTH)
	Park._add(tool, tread, Transform3D(Basis(), Vector3(offset, TOP - 0.09, 0.0)), TREAD)

	for end: float in [-1.0, 1.0]:
		var ramp := BoxMesh.new()
		ramp.size = Vector3(WIDTH, 0.10, 1.4)
		Park._add(
			tool, ramp,
			Transform3D(
				Basis(Vector3.RIGHT, end * deg_to_rad(9.0)),
				Vector3(offset, TOP * 0.45, end * (LENGTH * 0.5 + 0.7))
			),
			SIDE
		)

	# Slats across it, and a chevron every few metres pointing the way it
	# runs: which belt goes which way has to be legible before you step on.
	var slats := int(LENGTH / 0.55)
	for slat in slats:
		var along := -LENGTH * 0.5 + LENGTH * (float(slat) + 0.5) / float(slats)
		var bar := BoxMesh.new()
		bar.size = Vector3(WIDTH - 0.12, 0.04, 0.26)
		Park._add(tool, bar, Transform3D(Basis(), Vector3(offset, TOP + 0.01, along)), SLAT)
		if slat % 6 == 3:
			for wing: float in [-1.0, 1.0]:
				var chevron := BoxMesh.new()
				chevron.size = Vector3(0.62, 0.03, 0.14)
				Park._add(
					tool, chevron,
					Transform3D(
						Basis(Vector3.UP, wing * heading * deg_to_rad(38.0)),
						Vector3(offset + wing * 0.22, TOP + 0.04, along)
					),
					ARROW
				)

	# The sides, which are what makes it read as a walkway rather than a strip
	# of paint, and a handrail along each.
	for edge: float in [-1.0, 1.0]:
		var wall := BoxMesh.new()
		wall.size = Vector3(0.14, 0.72, LENGTH)
		Park._add(
			tool, wall,
			Transform3D(Basis(), Vector3(offset + edge * (WIDTH * 0.5 + 0.07), TOP + 0.36, 0.0)),
			SIDE
		)
		# Solid, so a child steps onto a belt at its ends rather than walking
		# in through its side onto the edge of a moving floor.
		Park._solid(
			_sides, Vector3(0.14, 0.72, LENGTH),
			Transform3D(Basis(), Vector3(offset + edge * (WIDTH * 0.5 + 0.07), TOP + 0.36, 0.0))
		)
		var rail := BoxMesh.new()
		rail.size = Vector3(0.10, 0.10, LENGTH)
		Park._add(
			tool, rail,
			Transform3D(Basis(), Vector3(offset + edge * (WIDTH * 0.5 + 0.07), TOP + 0.78, 0.0)),
			TREAD
		)

	# And the belt itself: a static body that pushes whatever stands on it.
	var belt := StaticBody3D.new()
	belt.name = "Belt%s" % ("North" if heading > 0.0 else "South")
	# Negative z is north in this valley, so a belt heading north runs -z.
	belt.constant_linear_velocity = Vector3(0.0, 0.0, -heading * SPEED)
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH, 0.18, LENGTH)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = Vector3(offset, TOP - 0.09, 0.0)
	belt.add_child(collider)
	add_child(belt)

## How far a belt moves whoever is standing on it, this frame.
##
## The static body's constant velocity does half the job — Godot pushes a
## character that is standing on it, but only while they are pressed into it,
## so a child who merely stands still creeps along at a third of the speed.
## The belt says plainly how far it has moved them instead.
func carry(at: Vector3, delta: float) -> Vector3:
	var local := at - global_position
	if absf(local.z) > LENGTH * 0.5 or local.y < TOP - 0.3 or local.y > TOP + 2.4:
		return Vector3.ZERO
	for side in 2:
		var offset := (WIDTH + GAP) * (float(side) - 0.5)
		if absf(local.x - offset) > WIDTH * 0.5:
			continue
		return carries(side) * delta
	return Vector3.ZERO

## How fast a belt carries a child, and which way. For the checks. Found by
## name rather than by position among the children, which is a fact about the
## order things were built in and changes the day something else is added.
func carries(which: int) -> Vector3:
	var belt := get_node_or_null("Belt%s" % ("North" if which == 0 else "South")) as StaticBody3D
	return belt.constant_linear_velocity if belt != null else Vector3.ZERO
