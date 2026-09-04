class_name Visitors
extends Node3D

## The other children, drawn where they are standing.
##
## A visitor is a mesh and a name, not a physics body. They are told where to be
## twelve times a second and glide between those points; giving them a character
## controller would mean simulating someone else's movement locally and then
## disagreeing with the machine that actually knows.
##
## The name floats above them because that is the whole point of seeing someone
## in your valley — knowing which brother it is. It faces the camera, since a
## label seen edge-on is no label at all.

## How quickly a visitor catches up to the last position that arrived. Fast
## enough not to lag visibly behind, slow enough that a dropped packet reads as
## a stride rather than a jump.
const SMOOTHING := 12.0

## Colours, assigned in arrival order so two children are never the same shade.
const SHIRTS: Array[Color] = [
	Color(0.86, 0.36, 0.32),
	Color(0.42, 0.72, 0.44),
	Color(0.90, 0.66, 0.28),
	Color(0.62, 0.44, 0.80),
]

var _visitors: Dictionary = {}

func add(id: int, who: String) -> void:
	if _visitors.has(id):
		return
	var shirt := SHIRTS[_visitors.size() % SHIRTS.size()]

	var body := MeshInstance3D.new()
	body.mesh = _build_body(shirt)
	add_child(body)

	var label := Label3D.new()
	label.text = who
	label.font_size = 96
	label.pixel_size = 0.0022
	label.position = Vector3(0.0, 2.15, 0.0)
	# Always facing the reader, and drawn over the world: a name hidden behind a
	# tree is worse than no name, because it tells a child nobody is there.
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 18
	label.outline_modulate = Color(0.06, 0.08, 0.11, 0.85)
	body.add_child(label)

	_visitors[id] = {"node": body, "wanted": Vector3.ZERO, "facing": 0.0, "seen": false}

func remove(id: int) -> void:
	if not _visitors.has(id):
		return
	var node: Node3D = _visitors[id]["node"]
	if is_instance_valid(node):
		node.queue_free()
	_visitors.erase(id)

func clear() -> void:
	for id in _visitors.keys():
		remove(id)

func count() -> int:
	return _visitors.size()

## A position arrived from another machine.
func move(id: int, at: Vector3, facing: float) -> void:
	if not _visitors.has(id):
		return
	var record: Dictionary = _visitors[id]
	record["wanted"] = at
	record["facing"] = facing
	var node: Node3D = record["node"]
	# The first position is applied outright. Easing in from the origin would
	# send a visitor sprinting across the valley the moment they appeared.
	if not record["seen"]:
		record["seen"] = true
		node.position = at
		node.rotation.y = facing

func _process(delta: float) -> void:
	var weight := 1.0 - exp(-SMOOTHING * delta)
	for id in _visitors:
		var record: Dictionary = _visitors[id]
		var node: Node3D = record["node"]
		if not is_instance_valid(node):
			continue
		node.position = node.position.lerp(record["wanted"], weight)
		node.rotation.y = lerp_angle(node.rotation.y, float(record["facing"]), weight)

## The same shape as the player, in a different shirt, so that seeing someone
## across the valley reads as "another child" and not as a different kind of
## creature.
func _build_body(shirt: Color) -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var torso := CapsuleMesh.new()
	torso.radius = Player.RADIUS
	torso.height = Player.HEIGHT
	torso.radial_segments = 10
	torso.rings = 4
	_add(tool, torso, Transform3D(Basis(), Vector3(0.0, Player.HEIGHT * 0.5, 0.0)), shirt)

	var head := SphereMesh.new()
	head.radius = 0.21
	head.height = 0.42
	head.radial_segments = 10
	head.rings = 6
	_add(
		tool, head,
		Transform3D(Basis(), Vector3(0.0, Player.HEIGHT * 0.79, 0.0)),
		Color(0.93, 0.78, 0.62)
	)

	var nose := CylinderMesh.new()
	nose.top_radius = 0.0
	nose.bottom_radius = 0.06
	nose.height = 0.14
	nose.radial_segments = 5
	_add(
		tool, nose,
		Transform3D(
			Basis(Vector3.RIGHT, deg_to_rad(-90.0)),
			Vector3(0.0, Player.HEIGHT * 0.79, -0.20)
		),
		Color(0.93, 0.78, 0.62)
	)

	tool.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.82
	tool.set_material(material)
	return tool.commit()

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
