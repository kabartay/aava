class_name Park
extends Node3D

## The fairground east of the river: a fenced sandy ground with five rides on
## it.
##
## Where it stands and how its floor is made flat is ParkSpec's business, the
## way the pitch's is Pitch's. This builds what stands on that floor: the
## fence and its gateway, and the rides themselves, each of which is its own
## class because each one moves in its own way.
##
## Everything a child can stand on that moves is an AnimatableBody3D. Godot
## carries a character body standing on one of those, so a child on the
## carousel goes round with it and a child in a gondola goes up with it,
## without the game having to know they are there.

## Where each ride stands. Written here rather than inside the rides, so the
## fairground's plan can be read in one place — and checked against the fence
## and against one another.
const CAROUSEL_AT := Vector3(84.0, 0.0, 2.0)
const WALKWAY_AT := Vector3(78.0, 0.0, -22.0)
const TRAMPOLINE_AT := Vector3(86.0, 0.0, -48.0)
const WHEEL_AT := Vector3(82.0, 0.0, -84.0)
## The coaster runs down the western side, along the river, the whole length of
## the ground.
const COASTER_AT := Vector3(64.0, 0.0, -70.0)

## The big trampoline: twice the one on the playground, which is 3.5 m across.
const TRAMPOLINE_RADIUS := 7.0
const TRAMPOLINE_TOP := 1.05
## How much of a fall it gives back, and the least bounce it will give a child
## who merely steps onto it.
const TRAMPOLINE_REBOUND := 0.72
const TRAMPOLINE_JUMP := 2.1

const FENCE_HEIGHT := 1.5
const FENCE_STEP := 4.0
const FENCE_COLOUR := Color(0.36, 0.30, 0.26)
const FENCE_CAP := Color(0.62, 0.24, 0.22)

## What the gateway says.
const PARK_NAME_TOP := "PARC"
const PARK_NAME := "DES MERVEILLES"

var _field: HeightField
var carousel: Carousel
var walkway: Walkway
var wheel: FerrisWheel
var coaster: RollerCoaster

func _init(height_field: HeightField) -> void:
	name = "Park"
	_field = height_field

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var solid := StaticBody3D.new()
	solid.name = "Solid"
	add_child(solid)

	_build_fence(tool, solid)
	_build_trampoline(tool, solid)

	tool.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.85
	tool.set_material(material)
	var built := MeshInstance3D.new()
	built.name = "Ground"
	built.mesh = tool.commit()
	add_child(built)

	carousel = Carousel.new(_at(CAROUSEL_AT))
	add_child(carousel)
	walkway = Walkway.new(_at(WALKWAY_AT))
	add_child(walkway)
	wheel = FerrisWheel.new(_at(WHEEL_AT))
	add_child(wheel)
	coaster = RollerCoaster.new(_at(COASTER_AT))
	add_child(coaster)

## A spot on the fairground's own floor.
func _at(spot: Vector3) -> Vector3:
	return Vector3(spot.x, ParkSpec.LEVEL, spot.z)

## Where the big trampoline's mat is.
func trampoline_mat() -> Vector3:
	return _at(TRAMPOLINE_AT) + Vector3(0.0, TRAMPOLINE_TOP, 0.0)

## Is a child standing on the mat? The playground's trampoline answers the same
## question for its own; this is the big one.
func on_trampoline(at: Vector3) -> bool:
	var mat := trampoline_mat()
	var flat := Vector2(at.x - mat.x, at.z - mat.z).length()
	return flat < TRAMPOLINE_RADIUS and absf(at.y - mat.y) < 0.8

## The fence: posts and two rails all the way round, with a gap in the southern
## side for the way in. A fairground with no edge is a field with rides in it.
func _build_fence(tool: SurfaceTool, solid: StaticBody3D) -> void:
	var corners: Array[Vector2] = [
		Vector2(ParkSpec.WEST, ParkSpec.SOUTH),
		Vector2(ParkSpec.WEST, ParkSpec.NORTH),
		Vector2(ParkSpec.EAST, ParkSpec.NORTH),
		Vector2(ParkSpec.EAST, ParkSpec.SOUTH),
	]
	var gate := ParkSpec.gate()
	for side in corners.size():
		var from := corners[side]
		var to := corners[(side + 1) % corners.size()]
		var run := to - from
		var steps := maxi(2, int(run.length() / FENCE_STEP))
		for step in steps + 1:
			var along := float(step) / float(steps)
			var here := from + run * along
			# The gateway: no fence across the way in.
			if absf(here.y - ParkSpec.SOUTH) < 0.01 and absf(here.x - gate.x) < ParkSpec.GATE_WIDTH * 0.5:
				continue
			_post(tool, solid, here, FENCE_HEIGHT, 0.12)
		# The rails, in the same pieces as the posts so they follow the line.
		for rail: float in [FENCE_HEIGHT * 0.92, FENCE_HEIGHT * 0.52]:
			for step in steps:
				var a := from + run * (float(step) / float(steps))
				var b := from + run * (float(step + 1) / float(steps))
				var middle := (a + b) * 0.5
				if absf(middle.y - ParkSpec.SOUTH) < 0.01 and absf(middle.x - gate.x) < ParkSpec.GATE_WIDTH * 0.5 + FENCE_STEP * 0.5:
					continue
				_rail(tool, solid, a, b, rail)

	_build_gateway(tool, solid, gate)

## The way in: two tall posts with a beam across them and the park's name on
## it, so arriving at the fairground is arriving somewhere.
func _build_gateway(tool: SurfaceTool, solid: StaticBody3D, gate: Vector3) -> void:
	var half := ParkSpec.GATE_WIDTH * 0.5
	var height := 5.2
	for side: float in [-1.0, 1.0]:
		_post(
			tool, solid, Vector2(gate.x + side * half, gate.z), height, 0.3, FENCE_CAP
		)
	var beam := BoxMesh.new()
	beam.size = Vector3(ParkSpec.GATE_WIDTH + 0.6, 0.55, 0.36)
	Park._add(
		tool, beam,
		Transform3D(Basis(), Vector3(gate.x, ParkSpec.LEVEL + height - 0.3, gate.z)),
		FENCE_CAP
	)
	# The name, on an enamel plate over the gate — the same plate the square
	# and the bridge wear, because one valley has one signwriter.
	var centre := Vector3(gate.x, ParkSpec.LEVEL + height + 0.85, gate.z)
	Plaque.build(tool, 0.0, centre, 5.0, 1.35, 0.52)
	Plaque.write(self, 0.0, centre, [
		[PARK_NAME_TOP, 0.30, 0.0046],
		[PARK_NAME, -0.28, 0.0030],
	])

func _post(
	tool: SurfaceTool, solid: StaticBody3D, at: Vector2, height: float, width: float,
	colour := FENCE_COLOUR
) -> void:
	var post := BoxMesh.new()
	post.size = Vector3(width, height, width)
	var middle := Vector3(at.x, ParkSpec.LEVEL + height * 0.5, at.y)
	Park._add(tool, post, Transform3D(Basis(), middle), colour)
	Park._solid(solid, post.size, Transform3D(Basis(), middle))

func _rail(tool: SurfaceTool, solid: StaticBody3D, a: Vector2, b: Vector2, at: float) -> void:
	var run := b - a
	var turn := Basis(Vector3.UP, atan2(-run.y, run.x))
	var rail := BoxMesh.new()
	rail.size = Vector3(run.length() + 0.1, 0.12, 0.08)
	var middle := Vector3((a.x + b.x) * 0.5, ParkSpec.LEVEL + at, (a.y + b.y) * 0.5)
	Park._add(tool, rail, Transform3D(turn, middle), FENCE_COLOUR)
	Park._solid(solid, rail.size, Transform3D(turn, middle))

## The big trampoline: the playground's, at twice the size. A frame on legs
## with a dark mat stretched across it, and springs round the rim.
func _build_trampoline(tool: SurfaceTool, solid: StaticBody3D) -> void:
	var at := _at(TRAMPOLINE_AT)
	var frame := TorusMesh.new()
	frame.inner_radius = TRAMPOLINE_RADIUS - 0.12
	frame.outer_radius = TRAMPOLINE_RADIUS + 0.10
	frame.rings = 28
	frame.ring_segments = 8
	Park._add(
		tool, frame,
		Transform3D(Basis(), at + Vector3(0.0, TRAMPOLINE_TOP, 0.0)),
		Color(0.24, 0.26, 0.30)
	)

	var mat := CylinderMesh.new()
	mat.top_radius = TRAMPOLINE_RADIUS - 0.10
	mat.bottom_radius = TRAMPOLINE_RADIUS - 0.10
	mat.height = 0.08
	mat.radial_segments = 28
	mat.rings = 1
	Park._add(
		tool, mat,
		Transform3D(Basis(), at + Vector3(0.0, TRAMPOLINE_TOP - 0.05, 0.0)),
		Color(0.13, 0.15, 0.20)
	)
	# The mat is solid, so a child stands on it; the bounce is the game's
	# business, in exactly the way the playground's is.
	var pad := CylinderShape3D.new()
	pad.radius = TRAMPOLINE_RADIUS - 0.10
	pad.height = 0.16
	var collider := CollisionShape3D.new()
	collider.shape = pad
	collider.position = at + Vector3(0.0, TRAMPOLINE_TOP - 0.05, 0.0)
	solid.add_child(collider)

	# Legs, and a safety net of uprights round it: the only thing here a child
	# can fall off, at this size, is this.
	for leg in 8:
		var angle := TAU * float(leg) / 8.0
		var spot := Vector2(cos(angle), sin(angle)) * (TRAMPOLINE_RADIUS - 0.25)
		var post := CylinderMesh.new()
		post.top_radius = 0.09
		post.bottom_radius = 0.11
		post.height = TRAMPOLINE_TOP
		post.radial_segments = 7
		post.rings = 1
		Park._add(
			tool, post,
			Transform3D(Basis(), at + Vector3(spot.x, TRAMPOLINE_TOP * 0.5, spot.y)),
			Color(0.24, 0.26, 0.30)
		)

## Finish a surface and hang it on a node. Every ride builds its still parts
## and its moving parts into separate tools and then calls this, so the whole
## fairground is a handful of meshes rather than a hundred.
static func commit(tool: SurfaceTool, parent: Node3D, drawn_name: String) -> void:
	tool.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.8
	tool.set_material(material)
	var mesh := tool.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		return
	var drawn := MeshInstance3D.new()
	drawn.name = drawn_name
	drawn.mesh = mesh
	parent.add_child(drawn)

static func _solid(body: StaticBody3D, size: Vector3, where: Transform3D) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.transform = where
	body.add_child(collider)

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
