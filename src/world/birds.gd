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
var _body: Mesh
var _wing: Mesh

func _init() -> void:
	# Built here, not in _ready, for the same reason as everywhere else in this
	# project: a resource does not need a scene tree, and waiting for one makes
	# the node unusable from a headless check.
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.roughness = 0.85
	_body = _build_body()
	_wing = _build_wing()

func _build_body() -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := SphereMesh.new()
	body.radius = 0.10
	body.height = 0.22
	body.radial_segments = 6
	body.rings = 4
	_add(tool, body, Transform3D(Basis().scaled(Vector3(1.0, 0.8, 1.6)), Vector3.ZERO), Color(0.24, 0.26, 0.32))
	var head := SphereMesh.new()
	head.radius = 0.06
	head.height = 0.12
	head.radial_segments = 6
	head.rings = 3
	_add(tool, head, Transform3D(Basis(), Vector3(0.0, 0.05, -0.15)), Color(0.30, 0.32, 0.38))
	var beak := CylinderMesh.new()
	beak.top_radius = 0.0
	beak.bottom_radius = 0.025
	beak.height = 0.09
	beak.radial_segments = 4
	beak.rings = 1
	_add(tool, beak, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-90.0)), Vector3(0.0, 0.04, -0.23)), Color(0.85, 0.66, 0.24))
	tool.generate_normals()
	return tool.commit()

func _build_wing() -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wing := BoxMesh.new()
	wing.size = Vector3(0.34, 0.02, 0.14)
	_add(tool, wing, Transform3D(Basis(), Vector3(0.17, 0.0, 0.0)), Color(0.28, 0.30, 0.36))
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
	body.mesh = _body
	body.material_override = _material
	node.add_child(body)

	var wings: Array[MeshInstance3D] = []
	var sides := PackedFloat32Array([-1.0, 1.0])
	for side in sides:
		var wing := MeshInstance3D.new()
		wing.mesh = _wing
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
