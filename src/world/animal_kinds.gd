class_name AnimalKinds
extends RefCounted

## Who lives in the valley, what they want, and what they give back.
##
## A leaf script with no dependencies, so the spawning, the interface, the
## rewards and the checks all agree about what a squirrel is without any of them
## depending on one another.
##
## Every animal wants something found where that animal lives: a squirrel in the
## forest wants a cone that fell under the conifers, a beaver at the water wants
## a stick from the treeline. This is the whole teaching mechanism — a child
## learns where things are by learning who wants them, without a word of it
## being explained.

const CAT := &"cat"
const DOG := &"dog"
const SQUIRREL := &"squirrel"
const BEAVER := &"beaver"

const ALL: Array[StringName] = [CAT, DOG, SQUIRREL, BEAVER]

## What each one wants, where it lives, and what caring for it is worth.
##
## `want` of an empty name means it wants nothing but attention — a cat is
## stroked, not fed, which is true of cats and is also the one interaction a
## child with an empty bag can always perform.
const INFO := {
	CAT: {
		"want": &"", "coins": 2, "cooldown": 40.0,
		"colour": Color(0.86, 0.70, 0.45), "size": 0.34,
		"home": "meadow", "shy": 0.35,
	},
	DOG: {
		"want": &"stick", "coins": 3, "cooldown": 30.0,
		"colour": Color(0.62, 0.50, 0.38), "size": 0.46,
		"home": "meadow", "shy": 0.0,
	},
	SQUIRREL: {
		"want": &"cone", "coins": 4, "cooldown": 25.0,
		"colour": Color(0.72, 0.42, 0.22), "size": 0.22,
		"home": "forest", "shy": 0.75,
	},
	BEAVER: {
		"want": &"stick", "coins": 5, "cooldown": 35.0,
		"colour": Color(0.45, 0.32, 0.22), "size": 0.40,
		"home": "water", "shy": 0.2,
	},
}

static func want(kind: StringName) -> StringName:
	return INFO[kind]["want"]

static func coins(kind: StringName) -> int:
	return INFO[kind]["coins"]

static func cooldown(kind: StringName) -> float:
	return INFO[kind]["cooldown"]

static func colour(kind: StringName) -> Color:
	return INFO[kind]["colour"]

static func size_of(kind: StringName) -> float:
	return INFO[kind]["size"]

## How readily it runs from an approaching child, 0 to 1. A squirrel bolts, a
## dog does not. Shyness is what makes an animal feel alive rather than placed,
## and it is why catching a squirrel is worth more than greeting a dog.
static func shyness(kind: StringName) -> float:
	return INFO[kind]["shy"]

static func label(kind: StringName) -> String:
	return Text.of("animal_" + String(kind))

## What it wants, in words, for the prompt over its head.
static func wish(kind: StringName) -> String:
	var wanted := want(kind)
	if wanted == &"":
		return Text.of("wish_stroke")
	return Text.format("wish_give", [ItemKinds.label(wanted)])

## A body built from primitives: four legs, a body, a head, a tail. Different
## proportions per animal are enough to tell them apart at a glance, which is
## all a child needs and all a silhouette can carry at this size.
static func build_mesh(kind: StringName) -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var scale := size_of(kind)
	var colour := colour(kind)
	var dark := colour.darkened(0.25)

	# Proportions are per-species, because size and tint alone did not tell a
	# cat from a beaver: on screen all four read as the same rounded lump. The
	# silhouette has to differ — a long low body for the cat, a stocky one for
	# the beaver, an upright one for the squirrel.
	var long := 1.55
	var tall := 0.80
	match kind:
		CAT:
			long = 1.75
			tall = 0.70
		SQUIRREL:
			long = 1.15
			tall = 1.05
		BEAVER:
			long = 1.45
			tall = 0.92

	var body := SphereMesh.new()
	body.radius = scale
	body.height = scale * 1.7
	body.radial_segments = 9
	body.rings = 5
	_add(tool, body, Transform3D(
		Basis().scaled(Vector3(1.0, tall, long)), Vector3(0.0, scale * 1.05, 0.0)
	), colour)

	# The neck lifts the head clear of the shoulders. Without it the head was
	# swallowed by the body and every animal was a single blob.
	var head_forward := -scale * (long * 0.92)
	var head_lift := scale * (1.85 if kind == SQUIRREL else 1.45)

	var neck := CylinderMesh.new()
	neck.top_radius = scale * 0.3
	neck.bottom_radius = scale * 0.36
	neck.height = scale * 0.5
	neck.radial_segments = 6
	neck.rings = 1
	_add(tool, neck, Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(-32.0)),
		Vector3(0.0, head_lift - scale * 0.32, head_forward * 0.55)
	), colour)

	var head := SphereMesh.new()
	head.radius = scale * 0.62
	head.height = scale * 1.1
	head.radial_segments = 8
	head.rings = 4
	_add(tool, head, Transform3D(Basis(), Vector3(0.0, head_lift, head_forward)), colour)

	# A muzzle, so there is a front. Longer on the dog, blunt on the beaver.
	var snout := SphereMesh.new()
	snout.radius = scale * 0.26
	snout.height = scale * 0.52
	snout.radial_segments = 6
	snout.rings = 3
	var snout_long := 1.5 if kind == DOG else 1.0
	_add(tool, snout, Transform3D(
		Basis().scaled(Vector3(0.8, 0.8, snout_long)),
		Vector3(0.0, head_lift - scale * 0.12, head_forward - scale * 0.5)
	), colour.darkened(0.12))

	# Ears, which is most of what separates a cat from a beaver at ten metres.
	var ear_lift := scale * (0.62 if kind == CAT or kind == SQUIRREL else 0.34)
	for side in PackedFloat32Array([-1.0, 1.0]):
		var ear := SphereMesh.new()
		ear.radius = scale * 0.2
		ear.height = scale * (0.7 if kind == CAT or kind == SQUIRREL else 0.34)
		ear.radial_segments = 6
		ear.rings = 3
		_add(tool, ear, Transform3D(
			Basis(), Vector3(side * scale * 0.34, head_lift + ear_lift, head_forward + scale * 0.12)
		), dark)

	for side in PackedFloat32Array([-1.0, 1.0]):
		for front in PackedFloat32Array([-1.0, 1.0]):
			var leg := CylinderMesh.new()
			leg.top_radius = scale * 0.13
			leg.bottom_radius = scale * 0.11
			leg.height = scale * 1.0
			leg.radial_segments = 5
			leg.rings = 1
			_add(tool, leg, Transform3D(
				Basis(), Vector3(side * scale * 0.44, scale * 0.5, front * scale * long * 0.6)
			), dark)

	_add_tail(tool, kind, scale, colour, long)
	tool.generate_normals()
	# The material travels with the mesh. These meshes are built from vertex
	# colours alone, so a caller that attaches the mesh without also knowing to
	# set vertex_color_use_as_albedo gets four identical white animals — which
	# is exactly what happened the first time the screenshot tool used them.
	tool.set_material(fur_material())
	return tool.commit()

## Shared by every animal: one material, vertex-coloured, slightly rough.
static func fur_material() -> StandardMaterial3D:
	if _fur == null:
		_fur = StandardMaterial3D.new()
		_fur.vertex_color_use_as_albedo = true
		_fur.vertex_color_is_srgb = true
		_fur.roughness = 0.85
	return _fur

static var _fur: StandardMaterial3D = null

## The tail carries the identity: a squirrel's plume, a beaver's paddle, a dog's
## stub. It is the cheapest possible characterisation and the most legible.
static func _add_tail(tool: SurfaceTool, kind: StringName, scale: float, colour: Color, long: float) -> void:
	match kind:
		SQUIRREL:
			var plume := SphereMesh.new()
			plume.radius = scale * 0.55
			plume.height = scale * 1.9
			plume.radial_segments = 7
			plume.rings = 4
			_add(tool, plume, Transform3D(
				Basis(Vector3.RIGHT, deg_to_rad(-38.0)),
				Vector3(0.0, scale * 2.05, scale * long * 0.95)
			), colour.lightened(0.15))
		BEAVER:
			var paddle := BoxMesh.new()
			paddle.size = Vector3(scale * 0.9, scale * 0.16, scale * 1.5)
			_add(tool, paddle, Transform3D(
				Basis(Vector3.RIGHT, deg_to_rad(12.0)),
				Vector3(0.0, scale * 0.55, scale * long * 1.35)
			), colour.darkened(0.35))
		CAT:
			var tail := CylinderMesh.new()
			tail.top_radius = scale * 0.09
			tail.bottom_radius = scale * 0.13
			tail.height = scale * 1.5
			tail.radial_segments = 5
			tail.rings = 1
			_add(tool, tail, Transform3D(
				Basis(Vector3.RIGHT, deg_to_rad(-55.0)),
				Vector3(0.0, scale * 1.55, scale * long * 1.0)
			), colour.darkened(0.15))
		_:
			var stub := SphereMesh.new()
			stub.radius = scale * 0.24
			stub.height = scale * 0.6
			stub.radial_segments = 6
			stub.rings = 3
			_add(tool, stub, Transform3D(Basis(), Vector3(0.0, scale * 1.3, scale * long * 1.02)), colour)

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
