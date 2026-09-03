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

## A conifer: straight trunk, two stacked cones. Reads clearly at any distance,
## which is what a tree seen across a valley has to do.
static func conifer(height := 6.0) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var trunk := CylinderMesh.new()
	trunk.top_radius = height * 0.026
	trunk.bottom_radius = height * 0.045
	trunk.height = height * 0.42
	trunk.radial_segments = 6
	trunk.rings = 1
	_append(tool, trunk, Transform3D(Basis(), Vector3(0.0, height * 0.21, 0.0)), TRUNK_COLOR)

	var lower := CylinderMesh.new()
	lower.top_radius = 0.0
	lower.bottom_radius = height * 0.24
	lower.height = height * 0.46
	lower.radial_segments = 7
	lower.rings = 1
	_append(tool, lower, Transform3D(Basis(), Vector3(0.0, height * 0.56, 0.0)), LEAF_DARK)

	var upper := CylinderMesh.new()
	upper.top_radius = 0.0
	upper.bottom_radius = height * 0.16
	upper.height = height * 0.38
	upper.radial_segments = 7
	upper.rings = 1
	_append(tool, upper, Transform3D(Basis(), Vector3(0.0, height * 0.81, 0.0)), LEAF_LIGHT)

	tool.generate_normals()
	return tool.commit()

## A broadleaf: shorter trunk, one rounded crown. Present so a forest is not one
## shape repeated, which is the thing that makes procedural planting look fake.
static func broadleaf(height := 5.0) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var trunk := CylinderMesh.new()
	trunk.top_radius = height * 0.04
	trunk.bottom_radius = height * 0.06
	trunk.height = height * 0.5
	trunk.radial_segments = 6
	trunk.rings = 1
	_append(tool, trunk, Transform3D(Basis(), Vector3(0.0, height * 0.25, 0.0)), TRUNK_COLOR)

	var crown := SphereMesh.new()
	crown.radius = height * 0.30
	crown.height = height * 0.52
	crown.radial_segments = 9
	crown.rings = 5
	_append(tool, crown, Transform3D(Basis(), Vector3(0.0, height * 0.72, 0.0)), LEAF_DARK)

	var highlight := SphereMesh.new()
	highlight.radius = height * 0.22
	highlight.height = height * 0.34
	highlight.radial_segments = 8
	highlight.rings = 4
	_append(tool, highlight, Transform3D(Basis(), Vector3(height * 0.08, height * 0.86, -height * 0.06)), LEAF_LIGHT)

	tool.generate_normals()
	return tool.commit()

## A tuft of grass. Colour runs dark at the root to light at the tip, which is
## what stops a field of these reading as flat carpet.
##
## Blades are bundled into one tuft rather than instanced individually: a tuft
## of five costs one instance instead of five, and with no per-instance culling
## in a MultiMesh the instance count is the thing that has to stay small.
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
