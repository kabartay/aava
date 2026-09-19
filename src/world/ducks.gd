class_name Ducks
extends Node3D

## Ducks on the ponds.
##
## Decoration, and deliberately nothing else: they give no coins, want nothing,
## and cannot be stroked or fed. Every other living thing in this valley is a
## small errand — the squirrel wants a cone, the dog wants a stick — and a place
## where everything that moves is a task to be done is a place to work rather
## than a place to be. A duck paddling about is worth having for its own sake.
##
## They are not animals in the `Animals` sense for the same reason: that node
## is about wanting, cooling down and paying out, and none of it applies here.
## What they need is a pond, a heading, and something to stop them paddling up
## the bank.

## How many are on each pond. Four reads as "some ducks"; one reads as a duck
## that has lost the others.
const PER_POND := 5

## How fast they paddle and how sharply they turn. Slow: a duck that moves like
## a fish reads as a bath toy being pushed about.
const SPEED := 0.55
const TURN := 0.8
## How far out into the pond they keep, as a fraction of its basin. They turn
## back at this, so nobody watches a duck walk up a bank.
const KEEP_WITHIN := 0.78
## How wide a duck is to bump into. Small, but not nothing: swimming straight
## through one reads as the duck not being there, which is what it was.
const GIRTH := 0.22

## How far they bob, and how fast.
const BOB := 0.035
const BOB_SPEED := 1.4

var _ducks: Array[Dictionary] = []
var _material: StandardMaterial3D
var _drake: Mesh
var _hen: Mesh

func _init() -> void:
	name = "Ducks"
	# Built here rather than in _ready: a headless check uses this without ever
	# starting the scene tree. See LESSONS.md.
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.roughness = 0.7
	_drake = _build(true)
	_hen = _build(false)

## Put ducks on every pond. Called once, with the seed, so the same world has
## the same ducks in the same places on both children's phones.
func settle(world_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(world_seed, 7717, 41))
	for pond in Lakes.count():
		var centre := Vector2(
			Lakes.at(pond, Lakes.POND_X), Lakes.at(pond, Lakes.POND_Z)
		)
		var long_axis := Lakes.at(pond, Lakes.POND_LONG)
		var short_axis := Lakes.at(pond, Lakes.POND_SHORT)
		var angle := Lakes.at(pond, Lakes.POND_ANGLE)
		var level := Lakes.at(pond, Lakes.POND_LEVEL)
		for i in PER_POND:
			# Somewhere out on the open water, in the pond's own frame so that
			# an oval pond gets an oval spread rather than a circular one.
			var bearing := rng.randf() * TAU
			var out := sqrt(rng.randf()) * KEEP_WITHIN
			var local := Vector2(
				cos(bearing) * out * long_axis, sin(bearing) * out * short_axis
			).rotated(angle)
			var node := MeshInstance3D.new()
			node.mesh = _drake if i % 2 == 0 else _hen
			node.position = Vector3(centre.x + local.x, level, centre.y + local.y)
			node.rotation.y = rng.randf() * TAU
			# Solid, like everything else that is really there. A duck you swim
			# straight through is a picture of a duck.
			var body := StaticBody3D.new()
			body.collision_layer = TerrainSpec.LAYER_PROPS
			var shape := CapsuleShape3D.new()
			shape.radius = GIRTH
			shape.height = GIRTH * 2.6
			var collider := CollisionShape3D.new()
			collider.shape = shape
			collider.position = Vector3(0.0, GIRTH * 0.6, 0.0)
			body.add_child(collider)
			node.add_child(body)
			add_child(node)
			_ducks.append({
				"node": node,
				"pond": pond,
				"heading": node.rotation.y,
				"phase": rng.randf() * TAU,
			})

func _process(delta: float) -> void:
	var stamp := PerfLog.stamp()
	for duck in _ducks:
		_paddle(duck, delta)
	PerfLog.note("ducks", stamp)

## One duck: forward along its heading, turning away from the bank when it gets
## near one, bobbing as it goes.
func _paddle(duck: Dictionary, delta: float) -> void:
	var node: Node3D = duck["node"]
	if not is_instance_valid(node):
		return
	var pond: int = duck["pond"]
	var centre := Vector2(
		Lakes.at(pond, Lakes.POND_X), Lakes.at(pond, Lakes.POND_Z)
	)
	var heading: float = duck["heading"]
	var here := Vector2(node.position.x, node.position.z)

	# How far out it is, in the pond's own frame: 1.0 is the water's edge.
	var reach := _reach_of(here - centre, pond)
	if reach > KEEP_WITHIN:
		# Turn towards the middle rather than snapping round: a duck that
		# reverses on the spot reads as a duck hitting a wall.
		var inward := (centre - here).angle()
		# Headings here are the node's own rotation about Y, where zero faces
		# -Z; the bearing above is measured in the XZ plane from +X. The
		# quarter turn between them is the difference, and leaving it out sent
		# every duck round the shore rather than into the middle.
		var wanted := -inward - PI * 0.5
		heading = lerp_angle(heading, wanted, 1.0 - exp(-TURN * 2.5 * delta))
	else:
		# A slow wander, each duck on its own clock.
		duck["phase"] = float(duck["phase"]) + delta * 0.6
		heading += sin(float(duck["phase"])) * TURN * delta

	duck["heading"] = heading
	node.rotation.y = heading
	var forward := Vector3(-sin(heading), 0.0, -cos(heading))
	node.position += forward * SPEED * delta
	node.position.y = (
		Lakes.at(pond, Lakes.POND_LEVEL)
		+ sin(float(duck["phase"]) * BOB_SPEED + node.position.x) * BOB
	)

## How far out a point is in a pond's frame, where 1.0 is the water's edge.
func _reach_of(offset: Vector2, pond: int) -> float:
	var turned := offset.rotated(-Lakes.at(pond, Lakes.POND_ANGLE))
	var along := turned.x / Lakes.at(pond, Lakes.POND_LONG)
	var across := turned.y / Lakes.at(pond, Lakes.POND_SHORT)
	return sqrt(along * along + across * across)

## A duck: a body sitting low in the water, a raised tail, a neck and a head
## with a bill. The drake has the green head and the white collar; the hen is
## brown all over, which is what tells the two apart at any distance.
func _build(drake: bool) -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var brown := Color(0.52, 0.40, 0.28)
	var body_colour := Color(0.62, 0.56, 0.48) if drake else brown
	var head_colour := Color(0.16, 0.44, 0.24) if drake else brown.darkened(0.12)
	var bill := Color(0.92, 0.78, 0.30)

	# The body: an ellipsoid sitting half in the water, so what shows is the
	# back and not a floating egg.
	var body := SphereMesh.new()
	body.radius = 0.19
	body.height = 0.3
	body.radial_segments = 10
	body.rings = 6
	_add(tool, body, Transform3D(
		Basis().scaled(Vector3(0.82, 1.0, 1.5)), Vector3(0.0, 0.04, 0.0)
	), body_colour)
	# The tail, cocked up at the back the way a duck's is.
	var tail := BoxMesh.new()
	tail.size = Vector3(0.1, 0.05, 0.18)
	_add(tool, tail, Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(-24.0)), Vector3(0.0, 0.1, 0.26)
	), body_colour.darkened(0.2))
	# The neck and head, forward and up.
	var neck := CylinderMesh.new()
	neck.top_radius = 0.052
	neck.bottom_radius = 0.07
	neck.height = 0.17
	neck.radial_segments = 8
	_add(tool, neck, Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(12.0)), Vector3(0.0, 0.16, -0.16)
	), head_colour)
	var head := SphereMesh.new()
	head.radius = 0.075
	head.height = 0.14
	head.radial_segments = 8
	head.rings = 5
	_add(tool, head, Transform3D(Basis(), Vector3(0.0, 0.26, -0.19)), head_colour)
	if drake:
		var collar := CylinderMesh.new()
		collar.top_radius = 0.062
		collar.bottom_radius = 0.062
		collar.height = 0.028
		collar.radial_segments = 8
		_add(tool, collar, Transform3D(Basis(), Vector3(0.0, 0.185, -0.172)), Color(0.94, 0.93, 0.90))
	var beak := BoxMesh.new()
	beak.size = Vector3(0.055, 0.03, 0.09)
	_add(tool, beak, Transform3D(Basis(), Vector3(0.0, 0.255, -0.27)), bill)

	tool.generate_normals()
	tool.set_material(_material)
	return tool.commit()

static func _add(tool: SurfaceTool, mesh: Mesh, where: Transform3D, colour: Color) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for index in indices:
		tool.set_color(colour)
		tool.add_vertex(where * vertices[index])

## How many ducks are afloat. For the checks.
func count() -> int:
	return _ducks.size()

## Where one is, and which pond it belongs to. For the checks.
func duck_position(index: int) -> Vector3:
	return (_ducks[index]["node"] as Node3D).position

func duck_pond(index: int) -> int:
	return _ducks[index]["pond"]

## Whether a duck is something a child bumps into. For the checks.
func is_solid(index: int) -> bool:
	var node: Node3D = _ducks[index]["node"]
	for child in node.get_children():
		var body := child as StaticBody3D
		if body != null and body.collision_layer == TerrainSpec.LAYER_PROPS:
			return body.get_child_count() > 0
	return false
