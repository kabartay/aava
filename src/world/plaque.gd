class_name Plaque
extends RefCounted

## An enamel street plaque, of the kind screwed to a wall in Paris: a green
## border with a round top, a white keyline, a dark blue field, four bosses at
## the corners, and the name set across lines with the small words small.
##
## It lives on its own because two different things wear one — the signpost at
## the square and the bridge over the river — and a plaque drawn twice is two
## plaques that slowly stop matching. Everything about how one looks is here;
## what it says, how big it is and where it hangs is the caller's business.

const GREEN := Color(0.11, 0.26, 0.18)
const BLUE := Color(0.10, 0.20, 0.38)
const OFF_WHITE := Color(0.92, 0.93, 0.90)

## How proud of the green each inner layer sits, and how far the writing floats
## in front of the field.
const LAYER_STEP := 0.03
const WRITING_OUT := 0.09

## Add the enamel itself to a surface, facing along `yaw` with its middle at
## `centre`. `arch` is how far the round top rises above the body.
static func build(
	tool: SurfaceTool, yaw: float, centre: Vector3,
	width: float, body: float, arch: float, depth := 0.12
) -> void:
	var turn := Basis(Vector3.UP, yaw)
	# Three layers, each a little smaller across and a little prouder of the
	# face: green enamel, a white keyline, and the blue field. That is how the
	# real ones are painted; drawn any other way it is a board with a line on
	# it.
	var layers: Array = [
		[width, body, arch, depth, GREEN],
		[width - width * 0.053, body - body * 0.115, arch * 0.9, depth + LAYER_STEP, OFF_WHITE],
		[width - width * 0.10, body - body * 0.22, arch * 0.78, depth + LAYER_STEP * 2.0, BLUE],
	]
	for layer: Array in layers:
		var wide := float(layer[0])
		var tall := float(layer[1])
		var rise := float(layer[2])
		var deep := float(layer[3])
		var colour: Color = layer[4]

		var slab := BoxMesh.new()
		slab.size = Vector3(wide, tall, deep)
		Plaque._add(tool, slab, Transform3D(turn, turn * centre), colour)

		# The round top: a disc, squashed to the height of the arch and laid
		# on the body's top edge. A plaque with square corners is a notice.
		var cap := CylinderMesh.new()
		cap.top_radius = wide * 0.5
		cap.bottom_radius = wide * 0.5
		cap.height = deep
		cap.radial_segments = 20
		cap.rings = 1
		var lie := Basis(Vector3.RIGHT, PI * 0.5).scaled(
			Vector3(1.0, 1.0, rise / (wide * 0.5))
		)
		Plaque._add(
			tool, cap,
			Transform3D(turn * lie, turn * (centre + Vector3(0.0, tall * 0.5, 0.0))),
			colour
		)

	# The bosses: where a plaque like this is screwed up. Four of them, in the
	# green border, and they are most of why the thing reads as enamel on iron
	# rather than as a painted rectangle.
	var boss_radius := minf(0.10, width * 0.032)
	for corner: Vector2 in [
		Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(-1.0, 1.0), Vector2(1.0, 1.0)
	]:
		for face: float in [1.0, -1.0]:
			var boss := CylinderMesh.new()
			boss.top_radius = boss_radius
			boss.bottom_radius = boss_radius
			boss.height = 0.04
			boss.radial_segments = 10
			boss.rings = 1
			Plaque._add(
				tool, boss,
				Transform3D(turn * Basis(Vector3.RIGHT, PI * 0.5), turn * (centre + Vector3(
					corner.x * (width * 0.5 - boss_radius * 0.95),
					corner.y * (body * 0.5 - boss_radius * 0.95),
					face * (depth * 0.5 + LAYER_STEP * 2.0)
				))),
				GREEN.lightened(0.18)
			)

## Hang the writing on both faces. `lines` holds [text, height above centre,
## pixel size] for each line, and both faces get all of them, so the plaque
## reads from either side.
static func write(parent: Node3D, yaw: float, centre: Vector3, lines: Array) -> void:
	var turn := Basis(Vector3.UP, yaw)
	for face: float in [1.0, -1.0]:
		for line: Array in lines:
			var label := Label3D.new()
			label.text = str(line[0])
			label.font_size = 96
			label.pixel_size = float(line[2])
			label.modulate = OFF_WHITE
			label.rotation.y = yaw + (0.0 if face > 0.0 else PI)
			label.position = turn * (
				centre + Vector3(0.0, float(line[1]), face * WRITING_OUT)
			)
			parent.add_child(label)

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
