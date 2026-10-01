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

## The shirts a child can choose from, and the fallback for anyone who has not.
##
## The plain colours by name — red is red — so that "I am the blue one" is a
## thing a six-year-old can say and be right about. Black and white are pulled
## a little off the ends of the range: a pure black shirt disappears entirely
## in a valley at night, and a pure white one blows out to a flat shape in
## sunlight, and in both cases what a child loses is the person they were
## looking for.
const SHIRTS: Array[Color] = [
	Color8(220, 50, 47),
	Color8(60, 180, 75),
	Color8(60, 110, 220),
	Color8(240, 200, 50),
	Color8(245, 150, 40),
	Color8(150, 70, 190),
	Color8(245, 160, 190),
	Color8(60, 200, 210),
	Color8(40, 40, 46),
	Color8(238, 238, 240),
	Color8(140, 140, 146),
	# Burgundy. Dark enough to be its own colour beside the red and not a
	# shade of it, light enough that it is still a colour at dusk rather than
	# a second black — which is the same line the black and white are drawn
	# just inside of, for the same reason.
	Color8(142, 32, 58),
]

## What the shirts are called, so a child picks "blue" and not a swatch.
## New colours go on the end of both lists and nowhere else: a child's choice
## is saved as a position in them, and inserting one in the middle would hand
## every brother a different shirt the next time they opened the game.
const SHIRT_NAMES: Array[StringName] = [
	&"red", &"green", &"blue", &"yellow", &"orange",
	&"purple", &"pink", &"cyan", &"black", &"white", &"grey",
	&"burgundy",
]

var _visitors: Dictionary = {}

## `chose` is the shirt that child picked for themselves, or -1 if they are
## playing on a version that never asked them.
func add(id: int, who: String, chose := -1) -> void:
	if _visitors.has(id):
		return
	var shirt := shirt_for(id, chose)

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

	_visitors[id] = {
		"node": body, "wanted": Vector3.ZERO, "facing": 0.0, "seen": false,
		"shirt": shirt,
	}

## Which shirt to draw somebody in.
##
## Their own choice, when they have made one. Failing that, one keyed off the
## peer id rather than off how many are already here — the count goes down when
## somebody leaves, so the next to join took a colour already being worn, and
## arrival order differs per machine, so a brother was green on one phone and
## orange on the other.
func shirt_for(id: int, chose: int) -> Color:
	if chose >= 0 and chose < SHIRTS.size():
		return SHIRTS[chose]
	# Everyone else's shirt, and deliberately not this child's own. Counting
	# their current colour as taken meant that asking again — which is what
	# happens when they type their name, because the name and the shirt travel
	# together — was guaranteed to hand back a different one, and a brother
	# changed colour every time he renamed himself.
	var worn := {}
	for other_id: int in _visitors:
		if other_id == id:
			continue
		worn[_visitors[other_id]["shirt"]] = true
	for step in SHIRTS.size():
		var candidate := SHIRTS[(absi(id) + step) % SHIRTS.size()]
		if not worn.has(candidate):
			return candidate
	return SHIRTS[absi(id) % SHIRTS.size()]

## What somebody is actually wearing, as opposed to what they would be given if
## they arrived now — those differ, because the second depends on who else is
## already here.
func shirt_of(id: int) -> Color:
	if not _visitors.has(id):
		return Color.BLACK
	return _visitors[id]["shirt"]

## Somebody changed their name, or their shirt, while standing in the valley.
func reshirt(id: int, chose: int) -> void:
	if not _visitors.has(id):
		return
	var record: Dictionary = _visitors[id]
	var node: Node3D = record["node"]
	if not is_instance_valid(node) or not (node is MeshInstance3D):
		return
	var shirt := shirt_for(id, chose)
	record["shirt"] = shirt
	(node as MeshInstance3D).mesh = _build_body(shirt)

## Somebody changed their name while standing in the valley.
func rename(id: int, who: String) -> void:
	if not _visitors.has(id):
		return
	var node: Node3D = _visitors[id]["node"]
	if not is_instance_valid(node):
		return
	for child in node.get_children():
		if child is Label3D:
			(child as Label3D).text = who
			return

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

	# Height and vertical offset copied from Player._build_visual() rather than
	# derived independently: a torso the full collision height tall (instead of
	# the shorter visible capsule the player actually draws), centred a sixth
	# higher than the player's is, swallowed the head sphere entirely and left
	# only the shirt-coloured torso visible — "red, no head, wrong size" was one
	# bug, not three.
	var torso := CapsuleMesh.new()
	torso.radius = Player.RADIUS
	torso.height = Player.HEIGHT * 0.66
	torso.radial_segments = 10
	torso.rings = 4
	_add(tool, torso, Transform3D(Basis(), Vector3(0.0, Player.HEIGHT * 0.33, 0.0)), shirt)

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
