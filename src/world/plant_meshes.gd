class_name PlantMeshes
extends RefCounted

## The plants themselves, built from primitives in code.
##
## These are placeholders for CC0 model kits, but they are honest placeholders:
## the same silhouettes, the same vertex-colour scheme and the same wind shader
## the real models will use, so swapping the mesh later changes nothing else.
##
## Everything is vertex-coloured and merged into a single surface per plant. That
## matters more than it looks: a MultiMesh draws one mesh with one material, so a
## tree made of three differently coloured parts has to be one surface or it
## cannot be instanced at all.

const TRUNK_COLOR := Color(0.35, 0.25, 0.17)
const LEAF_DARK := Color(0.16, 0.35, 0.16)
const LEAF_LIGHT := Color(0.36, 0.58, 0.24)
const GRASS_BASE := Color(0.24, 0.40, 0.18)
const GRASS_TIP := Color(0.55, 0.72, 0.32)

## A conifer: a trunk that tapers the whole way up, four skirts of branches
## that shorten towards the top, and a leader above them.
##
## It was two stacked cones on a stump, which reads as a tree at two hundred
## metres and as a paper hat at five. Four tiers give the silhouette the
## stepped edge a spruce has, and the colours run darker at the bottom, where
## a real one is in its own shade.
static func conifer(height := 6.0, seed_value := 0) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var trunk := CylinderMesh.new()
	trunk.top_radius = height * 0.012
	trunk.bottom_radius = height * 0.05
	trunk.height = height * 0.92
	trunk.radial_segments = 6
	trunk.rings = 1
	_append(tool, trunk, Transform3D(Basis(), Vector3(0.0, height * 0.46, 0.0)), TRUNK_COLOR)
	# The flare where the trunk meets the ground: a tree grows out of the
	# earth rather than being pushed into it.
	var flare := CylinderMesh.new()
	flare.top_radius = height * 0.05
	flare.bottom_radius = height * 0.09
	flare.height = height * 0.08
	flare.radial_segments = 6
	flare.rings = 1
	_append(tool, flare, Transform3D(Basis(), Vector3(0.0, height * 0.04, 0.0)), TRUNK_COLOR.darkened(0.15))

	# Four skirts, each narrower and shorter than the one below it, each
	# turned a little so the edges do not line up into a ridge.
	var tiers := 4
	for i in tiers:
		var t := float(i) / float(tiers - 1)
		var skirt := CylinderMesh.new()
		skirt.top_radius = height * lerpf(0.10, 0.02, t)
		skirt.bottom_radius = height * lerpf(0.27, 0.10, t)
		skirt.height = height * lerpf(0.30, 0.20, t)
		skirt.radial_segments = 8
		skirt.rings = 1
		var at := height * lerpf(0.34, 0.84, t)
		_append(
			tool, skirt,
			Transform3D(
				Basis(Vector3.UP, rng.randf_range(0.0, TAU)),
				Vector3(rng.randf_range(-0.02, 0.02) * height, at, rng.randf_range(-0.02, 0.02) * height)
			),
			LEAF_DARK.lerp(LEAF_LIGHT, t * 0.8)
		)
	# The leader: the thin spire a spruce ends in.
	var leader := CylinderMesh.new()
	leader.top_radius = 0.0
	leader.bottom_radius = height * 0.06
	leader.height = height * 0.22
	leader.radial_segments = 6
	leader.rings = 1
	_append(tool, leader, Transform3D(Basis(), Vector3(0.0, height * 1.0, 0.0)), LEAF_LIGHT)

	tool.generate_normals()
	return tool.commit()

## A broadleaf: a trunk that forks into two limbs, and a crown of four
## overlapping masses of leaf rather than one ball.
##
## One sphere on a stick is a lollipop. What makes a broadleaf read is that
## its crown has lumps and gaps in it and is not centred on the trunk.
static func broadleaf(height := 5.0, seed_value := 0) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 977

	var trunk := CylinderMesh.new()
	trunk.top_radius = height * 0.035
	trunk.bottom_radius = height * 0.07
	trunk.height = height * 0.52
	trunk.radial_segments = 6
	trunk.rings = 1
	_append(tool, trunk, Transform3D(Basis(), Vector3(0.0, height * 0.26, 0.0)), TRUNK_COLOR)
	var flare := CylinderMesh.new()
	flare.top_radius = height * 0.07
	flare.bottom_radius = height * 0.12
	flare.height = height * 0.08
	flare.radial_segments = 6
	flare.rings = 1
	_append(tool, flare, Transform3D(Basis(), Vector3(0.0, height * 0.04, 0.0)), TRUNK_COLOR.darkened(0.15))

	# Two limbs out of the fork, leaning opposite ways into the crown.
	for side in PackedFloat32Array([-1.0, 1.0]):
		var limb := CylinderMesh.new()
		limb.top_radius = height * 0.018
		limb.bottom_radius = height * 0.035
		limb.height = height * 0.34
		limb.radial_segments = 5
		limb.rings = 1
		var lean := deg_to_rad(side * rng.randf_range(20.0, 32.0))
		_append(
			tool, limb,
			Transform3D(Basis(Vector3.FORWARD, lean), Vector3(side * height * 0.06, height * 0.66, 0.0)),
			TRUNK_COLOR
		)

	# The crown: four masses, the biggest low and off to one side.
	var lumps := 4
	for i in lumps:
		var mass := SphereMesh.new()
		var size := height * lerpf(0.27, 0.17, float(i) / float(lumps - 1))
		mass.radius = size
		mass.height = size * 1.7
		mass.radial_segments = 9
		mass.rings = 5
		var angle := TAU * float(i) / float(lumps) + rng.randf_range(-0.4, 0.4)
		var out := height * rng.randf_range(0.08, 0.17)
		_append(
			tool, mass,
			Transform3D(Basis(), Vector3(
				cos(angle) * out,
				height * lerpf(0.74, 0.94, float(i) / float(lumps - 1)),
				sin(angle) * out
			)),
			LEAF_DARK.lerp(LEAF_LIGHT, rng.randf_range(0.1, 0.9))
		)

	tool.generate_normals()
	return tool.commit()

## A tuft of grass. Colour runs dark at the root to light at the tip, which is
## what stops a field of these reading as flat carpet.
##
## Blades are bundled into one tuft rather than instanced individually: a tuft
## of five costs one instance instead of five, and with no per-instance culling
## in a MultiMesh the instance count is the thing that has to stay small.
## What is left where a tree was cut down. Without it a felled tree simply
## vanishes, and a clearing reads as a place trees never grew rather than as
## something a child made.
static func stump(radius := 0.22) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var trunk := CylinderMesh.new()
	trunk.top_radius = radius
	trunk.bottom_radius = radius * 1.25
	trunk.height = radius * 2.0
	trunk.radial_segments = 8
	trunk.rings = 1
	_append(tool, trunk, Transform3D(Basis(), Vector3(0.0, radius, 0.0)), TRUNK_COLOR)

	# The pale cut face on top, which is the whole reason a stump reads as a
	# stump rather than as a rock.
	var top := CylinderMesh.new()
	top.top_radius = radius
	top.bottom_radius = radius
	top.height = radius * 0.14
	top.radial_segments = 8
	top.rings = 1
	_append(
		tool, top, Transform3D(Basis(), Vector3(0.0, radius * 2.0, 0.0)),
		Color(0.82, 0.68, 0.46)
	)

	tool.generate_normals()
	return tool.commit()

static func grass_tuft(height := 0.3, blades := 5) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	for blade in blades:
		var angle := TAU * float(blade) / float(blades) + float(blade) * 0.7
		var spread := 0.18 + 0.22 * float(blade % 3)
		var right := Vector3(cos(angle), 0.0, sin(angle)) * height * 0.085
		var lean := Vector3(cos(angle + 0.6), 0.0, sin(angle + 0.6)) * height * spread * 2.4
		var root := Vector3(cos(angle) * height * spread * 0.5, 0.0, sin(angle) * height * spread * 0.5)
		var tip := root + Vector3(0.0, height * (0.75 + 0.35 * float(blade % 2)), 0.0) + lean
		right += root

		# Two triangles per blade, drawn double-sided by the material so a blade
		# is visible from both sides without doubling the geometry.
		_blade(tool, root - (right - root), right, tip)

	tool.generate_normals()
	return tool.commit()

static func _blade(tool: SurfaceTool, left: Vector3, right: Vector3, tip: Vector3) -> void:
	var mid_left := left * 0.45 + tip * 0.5
	var mid_right := right * 0.45 + tip * 0.5
	_triangle(tool, left, right, mid_right, GRASS_BASE, GRASS_BASE, GRASS_TIP.lerp(GRASS_BASE, 0.5))
	_triangle(tool, left, mid_right, mid_left, GRASS_BASE, GRASS_TIP.lerp(GRASS_BASE, 0.5), GRASS_TIP.lerp(GRASS_BASE, 0.5))
	_triangle(tool, mid_left, mid_right, tip, GRASS_TIP.lerp(GRASS_BASE, 0.5), GRASS_TIP.lerp(GRASS_BASE, 0.5), GRASS_TIP)

static func _triangle(
	tool: SurfaceTool,
	a: Vector3, b: Vector3, c: Vector3,
	color_a: Color, color_b: Color, color_c: Color
) -> void:
	tool.set_color(color_a)
	tool.add_vertex(a)
	tool.set_color(color_b)
	tool.add_vertex(b)
	tool.set_color(color_c)
	tool.add_vertex(c)

## Copies a primitive's vertices into the shared surface, tinted. Done by hand
## rather than with append_from because that carries no way to set a colour, and
## a single surface with per-vertex colour is what makes instancing possible.
static func _append(tool: SurfaceTool, source: PrimitiveMesh, transform: Transform3D, color: Color) -> void:
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
