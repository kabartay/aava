class_name Birds
extends Node3D

## The world answering.
##
## Birds appear where the player has changed something: at a feeder, or over a
## grove of trees they planted and waited for. They are the first and simplest
## proof of the game's one promise — that building makes the place more alive —
## and they are deliberately the reward for the slowest thing in the game.

const MAX_BIRDS := 14
const BIRDS_PER_POINT := 4

const CIRCLE_RADIUS := 4.6
const CIRCLE_SPEED := 0.55
const FLAP_SPEED := 9.0

var _birds: Array[Dictionary] = []
var _points: Array = []
var _material: StandardMaterial3D
## Three plumages — slate, sparrow-brown and a pale grey — each with its own
## wing, so a flock is not fourteen copies of one bird.
const PLUMAGES: Array[Color] = [
	Color(0.24, 0.26, 0.32), Color(0.45, 0.34, 0.24), Color(0.58, 0.60, 0.64),
]
## How far a circling bird leans into the turn, in radians.
const BANK := 0.3

var _bodies: Array[Mesh] = []
var _wings: Array[Mesh] = []

func _init() -> void:
	# Animated in _process, so the engine's physics interpolation must not
	# touch it. See LESSONS.md: with interpolation on, a node's transform is
	# sampled once a physics tick and drawn a tick late, which throws away
	# everything moved between ticks — sixty-hertz motion on a hundred-and-
	# twenty-hertz screen, which is the flicker a child described as the world
	# coming in frames.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# Built here, not in _ready, for the same reason as everywhere else in this
	# project: a resource does not need a scene tree, and waiting for one makes
	# the node unusable from a headless check.
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.roughness = 0.85
	for plumage in PLUMAGES:
		_bodies.append(_build_body(plumage))
		_wings.append(_build_wing(plumage))

func _build_body(plumage: Color) -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := SphereMesh.new()
	body.radius = 0.10
	body.height = 0.22
	body.radial_segments = 6
	body.rings = 4
	_add(tool, body, Transform3D(Basis().scaled(Vector3(1.0, 0.8, 1.6)), Vector3.ZERO), plumage)
	var head := SphereMesh.new()
	head.radius = 0.06
	head.height = 0.12
	head.radial_segments = 6
	head.rings = 3
	_add(tool, head, Transform3D(Basis(), Vector3(0.0, 0.05, -0.15)), plumage.lightened(0.12))
	var beak := CylinderMesh.new()
	beak.top_radius = 0.0
	beak.bottom_radius = 0.025
	beak.height = 0.09
	beak.radial_segments = 4
	beak.rings = 1
	_add(tool, beak, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-90.0)), Vector3(0.0, 0.04, -0.23)), Color(0.85, 0.66, 0.24))
	# A tail, flat behind: without one the bird is an egg with a beak.
	var tail := BoxMesh.new()
	tail.size = Vector3(0.09, 0.015, 0.13)
	_add(tool, tail, Transform3D(Basis(), Vector3(0.0, 0.0, 0.2)), plumage.darkened(0.15))
	tool.generate_normals()
	return tool.commit()

func _build_wing(plumage: Color) -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wing := BoxMesh.new()
	wing.size = Vector3(0.34, 0.02, 0.14)
	_add(tool, wing, Transform3D(Basis(), Vector3(0.17, 0.0, 0.0)), plumage.darkened(0.1))
	tool.generate_normals()
	return tool.commit()

## Where the birds should be. Called whenever the player finishes a feeder or a
## grove comes of age.
func set_points(points: Array) -> void:
	_points = points
	var wanted := mini(MAX_BIRDS, points.size() * BIRDS_PER_POINT)

	while _birds.size() > wanted:
		var doomed: Dictionary = _birds.pop_back()
		var node: Node3D = doomed["node"]
		if is_instance_valid(node):
			node.queue_free()
	while _birds.size() < wanted:
		_birds.append(_spawn_bird(_birds.size()))

	for i in _birds.size():
		_birds[i]["point"] = i % maxi(1, points.size())

func _spawn_bird(index: int) -> Dictionary:
	var node := Node3D.new()
	var body := MeshInstance3D.new()
	body.mesh = _bodies[index % _bodies.size()]
	body.material_override = _material
	node.add_child(body)

	var wings: Array[MeshInstance3D] = []
	var sides := PackedFloat32Array([-1.0, 1.0])
	for side in sides:
		var wing := MeshInstance3D.new()
		wing.mesh = _wings[index % _wings.size()]
		wing.material_override = _material
		wing.scale.x = side
		node.add_child(wing)
		wings.append(wing)

	add_child(node)
	return {
		"node": node,
		"wings": wings,
		"point": 0,
		# A phase offset per bird, or a flock beats its wings in unison and reads
		# as one object rather than several.
		"phase": float(index) * 1.37,
		"height": 0.6 + float(index % 3) * 0.9,
		"radius": CIRCLE_RADIUS + float(index % 4) * 0.7,
	}

func _process(delta: float) -> void:
	if _points.is_empty():
		return
	var time := Time.get_ticks_msec() / 1000.0
	for bird in _birds:
		var centre: Vector3 = _points[int(bird["point"]) % _points.size()]
		var angle := time * CIRCLE_SPEED + float(bird["phase"])
		var radius: float = bird["radius"]
		var position := centre + Vector3(
			cos(angle) * radius,
			float(bird["height"]) + sin(angle * 2.1 + float(bird["phase"])) * 0.35,
			sin(angle) * radius
		)
		var node: Node3D = bird["node"]
		var heading := (position - node.position).normalized() if node.position != Vector3.ZERO else Vector3.FORWARD
		node.position = position
		if heading.length_squared() > 0.001:
			node.look_at(position + heading, Vector3.UP)
			# The centre of the circle is on the bird's right, so the right
			# wing dips; a positive turn about Z would lift it.
			node.rotate_object_local(Vector3.BACK, -BANK)

		var flap := sin(time * FLAP_SPEED + float(bird["phase"])) * deg_to_rad(38.0)
		var wings: Array = bird["wings"]
		wings[0].rotation.z = -flap
		wings[1].rotation.z = flap
	# delta is unused: circling is driven from absolute time so that a bird's
	# path does not drift when a frame is slow.
	pass

static func _add(tool: SurfaceTool, source: PrimitiveMesh, transform: Transform3D, color: Color) -> void:
	var arrays := source.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for i in vertices.size():
			tool.set_color(color)
			tool.add_vertex(transform * vertices[i])
		return
	for i in indices.size():
		tool.set_color(color)
		tool.add_vertex(transform * vertices[indices[i]])
