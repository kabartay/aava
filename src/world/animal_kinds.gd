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
## Sizes and colours are storybook, not zoological. At real proportions these
## read as four brown specks from five metres away on a tablet — the eldest
## could not tell the cat from the dog and the six-year-old could not see them
## at all. They are now half again as large, and each has a colour no other
## animal shares: ginger cat, dark dog, red squirrel, slate beaver.
const INFO := {
	CAT: {
		"want": &"", "coins": 2, "cooldown": 40.0,
		"colour": Color(0.92, 0.62, 0.24), "size": 0.46,
		"home": "meadow", "shy": 0.35,
	},
	DOG: {
		"want": &"stick", "coins": 3, "cooldown": 30.0,
		"colour": Color(0.40, 0.30, 0.24), "size": 0.62,
		"home": "meadow", "shy": 0.0,
	},
	SQUIRREL: {
		"want": &"cone", "coins": 4, "cooldown": 25.0,
		"colour": Color(0.86, 0.36, 0.14), "size": 0.30,
		"home": "forest", "shy": 0.75,
	},
	BEAVER: {
		"want": &"stick", "coins": 5, "cooldown": 35.0,
		"colour": Color(0.34, 0.26, 0.30), "size": 0.54,
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
	return Text.format("wish_give", [ItemKinds.label_object(wanted)])

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
	# How narrow the body is across the shoulders. A cat is a slighter animal
	# than the others by more than its size: narrow, long and low.
	var slim := 1.0
	match kind:
		CAT:
			long = 1.85
			tall = 0.64
			slim = 0.8
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
		Basis().scaled(Vector3(slim, tall, long)), Vector3(0.0, scale * 1.05, 0.0)
	), colour)

	# The neck lifts the head clear of the shoulders. Without it the head was
	# swallowed by the body and every animal was a single blob.
	var head_forward := -scale * (long * 0.92)
	var head_lift := scale * (1.85 if kind == SQUIRREL else (1.52 if kind == CAT else 1.45))

	var neck := CylinderMesh.new()
	neck.top_radius = scale * (0.24 if kind == CAT else 0.3)
	neck.bottom_radius = scale * (0.3 if kind == CAT else 0.36)
	neck.height = scale * (0.62 if kind == CAT else 0.5)
	neck.radial_segments = 6
	neck.rings = 1
	_add(tool, neck, Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(-32.0)),
		Vector3(0.0, head_lift - scale * 0.32, head_forward * 0.55)
	), colour)

	var head := SphereMesh.new()
	head.radius = scale * (0.55 if kind == CAT else 0.62)
	head.height = scale * (1.0 if kind == CAT else 1.1)
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
	# A cat and a squirrel get tall pointed ears standing straight up; a dog gets
	# long ones hanging down; a beaver gets almost none. Silhouette from behind
	# is what a child actually sees, and these are the only part of the head
	# that shows in it.
	var pricked := kind == CAT or kind == SQUIRREL
	for side in PackedFloat32Array([-1.0, 1.0]):
		if kind == DOG:
			var flop := BoxMesh.new()
			flop.size = Vector3(scale * 0.16, scale * 0.86, scale * 0.34)
			_add(tool, flop, Transform3D(
				Basis(Vector3.FORWARD, deg_to_rad(side * 18.0)),
				Vector3(side * scale * 0.52, head_lift - scale * 0.18, head_forward + scale * 0.1)
			), dark)
			continue
		var ear := CylinderMesh.new()
		ear.top_radius = 0.0
		ear.bottom_radius = scale * (0.24 if pricked else 0.16)
		ear.height = scale * (1.05 if pricked else 0.32)
		ear.radial_segments = 5
		ear.rings = 1
		_add(tool, ear, Transform3D(
			Basis(),
			Vector3(
				side * scale * 0.36,
				head_lift + scale * (0.86 if pricked else 0.3),
				head_forward + scale * 0.12
			)
		), dark)

	var leg_slim := 0.8 if kind == CAT else 1.0
	for side in PackedFloat32Array([-1.0, 1.0]):
		for front in PackedFloat32Array([-1.0, 1.0]):
			var leg := CylinderMesh.new()
			leg.top_radius = scale * 0.13 * leg_slim
			leg.bottom_radius = scale * 0.11 * leg_slim
			leg.height = scale * 1.0
			leg.radial_segments = 5
			leg.rings = 1
			_add(tool, leg, Transform3D(
				Basis(), Vector3(side * scale * 0.44 * slim, scale * 0.5, front * scale * long * 0.6)
			), dark)

	_add_paws(tool, scale, long, slim, dark)
	_add_belly(tool, scale, long, tall, slim, colour)
	_add_face(tool, kind, scale, head_lift, head_forward, snout_long, colour)
	if kind == DOG:
		_add_collar(tool, scale, head_lift, head_forward)
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

## Feet, so the legs end in something rather than stopping in the grass.
static func _add_paws(tool: SurfaceTool, scale: float, long: float, slim: float, dark: Color) -> void:
	for side in PackedFloat32Array([-1.0, 1.0]):
		for front in PackedFloat32Array([-1.0, 1.0]):
			var paw := SphereMesh.new()
			paw.radius = scale * 0.15 * (0.5 + 0.5 * slim)
			paw.height = scale * 0.2
			paw.radial_segments = 6
			paw.rings = 3
			_add(tool, paw, Transform3D(
				Basis(), Vector3(side * scale * 0.44 * slim, scale * 0.09, front * scale * long * 0.6 - scale * 0.05)
			), dark)

## A paler underside. Every animal has one, and it is most of what makes a
## body read as a body rather than a coloured egg.
static func _add_belly(tool: SurfaceTool, scale: float, long: float, tall: float, slim: float, colour: Color) -> void:
	var belly := SphereMesh.new()
	belly.radius = scale * 0.62
	belly.height = scale * 0.9
	belly.radial_segments = 8
	belly.rings = 4
	# Just proud of the body's underside, whatever the body's height.
	var underside := scale * (1.05 - 0.85 * tall)
	_add(tool, belly, Transform3D(
		Basis().scaled(Vector3(0.8 * slim, 0.55, long * 0.62)),
		Vector3(0.0, underside + scale * 0.16, -scale * long * 0.08)
	), colour.lightened(0.3))

## Eyes and a nose. Without eyes an animal is a toy; with them it is looking
## at you, which is the whole of what a child wants from it. The cat has big
## green eyes and whiskers; the others, dark eyes with a catchlight.
static func _add_face(
	tool: SurfaceTool, kind: StringName, scale: float, head_lift: float, head_forward: float,
	snout_long: float, colour: Color
) -> void:
	var iris := Color(0.62, 0.78, 0.30) if kind == CAT else Color(0.08, 0.06, 0.05)
	var pupil := Color(0.05, 0.05, 0.05)
	var shine := Color(0.95, 0.95, 0.95)
	for side in PackedFloat32Array([-1.0, 1.0]):
		var eye_at := Vector3(side * scale * 0.27, head_lift + scale * 0.1, head_forward - scale * 0.5)
		var eye := SphereMesh.new()
		eye.radius = scale * (0.12 if kind == CAT else 0.1)
		eye.height = eye.radius * 2.0
		eye.radial_segments = 6
		eye.rings = 3
		_add(tool, eye, Transform3D(Basis(), eye_at), iris)
		if kind == CAT:
			var slit := SphereMesh.new()
			slit.radius = scale * 0.05
			slit.height = scale * 0.16
			slit.radial_segments = 4
			slit.rings = 3
			_add(tool, slit, Transform3D(Basis(), eye_at + Vector3(0.0, 0.0, -scale * 0.08)), pupil)
		var glint := SphereMesh.new()
		glint.radius = scale * 0.03
		glint.height = scale * 0.06
		glint.radial_segments = 4
		glint.rings = 2
		_add(tool, glint, Transform3D(Basis(), eye_at + Vector3(side * scale * 0.03, scale * 0.04, -scale * 0.09)), shine)

	var nose := SphereMesh.new()
	nose.radius = scale * 0.08
	nose.height = scale * 0.13
	nose.radial_segments = 5
	nose.rings = 3
	var nose_at := Vector3(0.0, head_lift - scale * 0.1, head_forward - scale * 0.5 - scale * 0.26 * snout_long)
	_add(tool, nose, Transform3D(Basis(), nose_at), Color(0.75, 0.45, 0.45) if kind == CAT else pupil)

	if kind == CAT:
		# Whiskers: two each side, drooping a little.
		for side in PackedFloat32Array([-1.0, 1.0]):
			for row in 2:
				var whisker := CylinderMesh.new()
				whisker.top_radius = scale * 0.012
				whisker.bottom_radius = scale * 0.012
				whisker.height = scale * 0.7
				whisker.radial_segments = 3
				whisker.rings = 1
				# Rotating +Y about FORWARD by 105° lays it along +X and a
				# little downwards; the other side is the mirror.
				_add(tool, whisker, Transform3D(
					Basis(Vector3.FORWARD, deg_to_rad(side * 105.0)),
					nose_at + Vector3(side * scale * 0.42, scale * 0.02 - float(row) * scale * 0.07, scale * 0.18 + float(row) * scale * 0.06)
				), colour.lightened(0.5))

## A red collar, which is the one thing that says "dog" from any distance.
static func _add_collar(tool: SurfaceTool, scale: float, head_lift: float, head_forward: float) -> void:
	var collar := TorusMesh.new()
	collar.inner_radius = scale * 0.31
	collar.outer_radius = scale * 0.50
	collar.rings = 6
	collar.ring_segments = 12
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(-32.0))
	var neck_at := Vector3(0.0, head_lift - scale * 0.32, head_forward * 0.55)
	# Up the neck a little, towards the head: at the shoulders the body's
	# curve swallowed it, and the first collar was there and invisible.
	var along := tilt * Vector3.UP
	_add(tool, collar, Transform3D(tilt, neck_at + along * scale * 0.06), Color(0.80, 0.18, 0.16))

## The tail carries the identity: a squirrel's plume, a beaver's paddle, a
## dog's curl, a cat's raised question mark. It is the cheapest possible
## characterisation and the most legible.
static func _add_tail(tool: SurfaceTool, kind: StringName, scale: float, colour: Color, long: float) -> void:
	match kind:
		SQUIRREL:
			# Two plumes in an S: up from the rump, then curling forward over
			# the back, which is how a squirrel actually carries it.
			var lower := SphereMesh.new()
			lower.radius = scale * 0.42
			lower.height = scale * 1.5
			lower.radial_segments = 7
			lower.rings = 4
			_add(tool, lower, Transform3D(
				Basis(Vector3.RIGHT, deg_to_rad(15.0)),
				Vector3(0.0, scale * 1.55, scale * long * 0.95)
			), colour.lightened(0.15))
			var upper := SphereMesh.new()
			upper.radius = scale * 0.52
			upper.height = scale * 1.6
			upper.radial_segments = 7
			upper.rings = 4
			_add(tool, upper, Transform3D(
				Basis(Vector3.RIGHT, deg_to_rad(-35.0)),
				Vector3(0.0, scale * 2.55, scale * long * 0.75)
			), colour.lightened(0.25))
		BEAVER:
			var paddle := BoxMesh.new()
			paddle.size = Vector3(scale * 0.9, scale * 0.16, scale * 1.5)
			_add(tool, paddle, Transform3D(
				Basis(Vector3.RIGHT, deg_to_rad(12.0)),
				Vector3(0.0, scale * 0.55, scale * long * 1.35)
			), colour.darkened(0.35))
		CAT:
			# Starts inside the rump and curves up in three pieces, tip
			# forward: a cat pleased to see you. The first tail was one
			# straight cylinder set at the body's edge, and floated beside it.
			_add_tail_curve(
				tool, Vector3(0.0, scale * 1.0, scale * long * 0.82),
				PackedFloat32Array([72.0, 38.0, 8.0]),
				PackedFloat32Array([scale * 0.5, scale * 0.5, scale * 0.45]),
				scale * 0.13, scale * 0.06, colour.darkened(0.1)
			)
		_:
			# A dog's tail: up and over in a curl, with a tuft at the end.
			var tip := _add_tail_curve(
				tool, Vector3(0.0, scale * 1.15, scale * long * 0.85),
				PackedFloat32Array([50.0, 12.0]),
				PackedFloat32Array([scale * 0.45, scale * 0.4]),
				scale * 0.11, scale * 0.07, colour
			)
			var tuft := SphereMesh.new()
			tuft.radius = scale * 0.13
			tuft.height = scale * 0.26
			tuft.radial_segments = 6
			tuft.rings = 3
			_add(tool, tuft, Transform3D(Basis(), tip), colour.lightened(0.2))

## A tail in pieces: each piece a tapering cylinder tipped by its angle from
## straight up, laid end to end from `start`, with a ball at each joint to
## hide the seam. Returns where the tip ends up.
static func _add_tail_curve(
	tool: SurfaceTool, start: Vector3, tilts: PackedFloat32Array, lengths: PackedFloat32Array,
	radius_from: float, radius_to: float, colour: Color
) -> Vector3:
	var at := start
	var count := tilts.size()
	for i in count:
		var tilt := deg_to_rad(tilts[i])
		# Rotating +Y about X by a positive angle tips it towards +Z, which is
		# backwards on these animals: 90° is a tail held straight out behind,
		# 0° one held straight up.
		var direction := Vector3(0.0, cos(tilt), sin(tilt))
		var thick := lerpf(radius_from, radius_to, float(i) / float(count))
		var thin := lerpf(radius_from, radius_to, float(i + 1) / float(count))
		var piece := CylinderMesh.new()
		piece.top_radius = thin
		piece.bottom_radius = thick
		piece.height = lengths[i]
		piece.radial_segments = 5
		piece.rings = 1
		_add(tool, piece, Transform3D(Basis(Vector3.RIGHT, tilt), at + direction * lengths[i] * 0.5), colour)
		at += direction * lengths[i]
		var joint := SphereMesh.new()
		joint.radius = thin * 1.05
		joint.height = thin * 2.1
		joint.radial_segments = 5
		joint.rings = 3
		_add(tool, joint, Transform3D(Basis(), at), colour)
	return at

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
