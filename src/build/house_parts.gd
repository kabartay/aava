class_name HouseParts
extends RefCounted

## The pieces a house is made of.
##
## Kept separate from BuildKinds because a house is a different kind of thing to
## a campfire: a campfire is one object placed on the ground, while a wall is
## meant to line up with the wall beside it and the roof on top of it. That
## difference is the whole design of this file — every piece is a whole number
## of grid squares in each direction, and every piece stands on a whole number
## of grid squares of height, so parts placed independently still meet.
##
## This is what lets a ten-year-old build a real house out of parts without ever
## being taught about alignment. He puts a wall down, puts another beside it,
## and they touch — not because he was careful, but because they cannot do
## anything else.

## The size of one building square, and one storey. Everything is a multiple.
const MODULE := 2.0
const STOREY := 2.4

const WALL := &"wall"
const WALL_DOOR := &"wall_door"
const WALL_WINDOW := &"wall_window"
const FLOOR := &"floor"
const ROOF := &"roof"
const ROOF_PEAK := &"roof_peak"
const STAIRS := &"stairs"
const POST := &"post"

const ALL: Array[StringName] = [
	WALL, WALL_DOOR, WALL_WINDOW, FLOOR, ROOF, ROOF_PEAK, STAIRS, POST,
]

const TIMBER := Color(0.62, 0.45, 0.28)
const TIMBER_DARK := Color(0.44, 0.31, 0.19)
const PLASTER := Color(0.88, 0.85, 0.78)
const TILE := Color(0.60, 0.30, 0.26)
const GLASS := Color(0.55, 0.75, 0.85)
const STONE := Color(0.58, 0.57, 0.56)

## Costs are small on purpose. A house is many pieces, and if each one were a
## chore the house would never be finished — which for a child means the whole
## idea was a waste of an afternoon.
const INFO := {
	WALL: {"label": "wall", "icon": "|", "cost": {&"stick": 2}, "footprint": MODULE, "height": STOREY},
	WALL_DOOR: {"label": "door", "icon": "n", "cost": {&"stick": 3}, "footprint": MODULE, "height": STOREY},
	WALL_WINDOW: {"label": "window", "icon": "o", "cost": {&"stick": 2, &"reed": 1}, "footprint": MODULE, "height": STOREY},
	FLOOR: {"label": "floor", "icon": "=", "cost": {&"stick": 2}, "footprint": MODULE, "height": 0.16},
	ROOF: {"label": "roof", "icon": "/", "cost": {&"reed": 2}, "footprint": MODULE, "height": 1.1},
	ROOF_PEAK: {"label": "peak", "icon": "^", "cost": {&"reed": 3}, "footprint": MODULE, "height": 1.5},
	STAIRS: {"label": "stairs", "icon": "z", "cost": {&"stone": 2}, "footprint": MODULE, "height": STOREY},
	POST: {"label": "post", "icon": "i", "cost": {&"stick": 1}, "footprint": 0.4, "height": STOREY},
}

static func label(kind: StringName) -> String:
	return INFO[kind]["label"]

static func icon(kind: StringName) -> String:
	return INFO[kind]["icon"]

static func cost(kind: StringName) -> Dictionary:
	return INFO[kind]["cost"]

static func footprint(kind: StringName) -> float:
	return INFO[kind]["footprint"]

static func height(kind: StringName) -> float:
	return INFO[kind]["height"]

static func is_house_part(kind: StringName) -> bool:
	return INFO.has(kind)

## Which storey a piece sits on, given how high above the ground it was placed.
static func storey_of(height_above_ground: float) -> int:
	return int(round(height_above_ground / STOREY))

## Snap a height to the nearest storey. This is what makes a first floor line up
## with the walls holding it.
static func snap_height(height_above_ground: float) -> float:
	return float(storey_of(height_above_ground)) * STOREY

static func build_mesh(kind: StringName) -> Mesh:
	match kind:
		WALL:
			return _wall(false, false)
		WALL_DOOR:
			return _wall(true, false)
		WALL_WINDOW:
			return _wall(false, true)
		FLOOR:
			return _floor()
		ROOF:
			return _roof(false)
		ROOF_PEAK:
			return _roof(true)
		STAIRS:
			return _stairs()
		_:
			return _post()

## A wall panel with a timber frame, optionally holed for a door or a window.
## Built as a frame plus panels rather than a box with a hole cut out, because
## a hole is a boolean operation and a frame is four slabs.
static func _wall(door: bool, window: bool) -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var thickness := 0.18
	var post := 0.16

	# Corner posts, which is what makes a row of walls read as timber framing
	# rather than as a flat fence.
	for side in PackedFloat32Array([-1.0, 1.0]):
		_box(tool, Vector3(side * (MODULE * 0.5 - post * 0.5), STOREY * 0.5, 0.0),
			Vector3(post, STOREY, thickness * 1.15), TIMBER_DARK)

	var inner := MODULE - post * 2.0

	if door:
		var door_width := 1.0
		var door_height := 1.75
		var side_width := (inner - door_width) * 0.5
		for side in PackedFloat32Array([-1.0, 1.0]):
			_box(tool, Vector3(side * (door_width + side_width) * 0.5, STOREY * 0.5, 0.0),
				Vector3(side_width, STOREY, thickness), PLASTER)
		# Lintel over the opening.
		_box(tool, Vector3(0.0, (door_height + STOREY) * 0.5, 0.0),
			Vector3(door_width, STOREY - door_height, thickness), PLASTER)
		_box(tool, Vector3(0.0, door_height, 0.0),
			Vector3(door_width + 0.12, 0.14, thickness * 1.3), TIMBER_DARK)
		return _finish(tool)

	if window:
		var opening := 0.9
		var sill := 0.95
		var side_width := (inner - opening) * 0.5
		for side in PackedFloat32Array([-1.0, 1.0]):
			_box(tool, Vector3(side * (opening + side_width) * 0.5, STOREY * 0.5, 0.0),
				Vector3(side_width, STOREY, thickness), PLASTER)
		_box(tool, Vector3(0.0, sill * 0.5, 0.0), Vector3(opening, sill, thickness), PLASTER)
		var head := sill + opening
		_box(tool, Vector3(0.0, (head + STOREY) * 0.5, 0.0),
			Vector3(opening, STOREY - head, thickness), PLASTER)
		# The pane itself, set back so it reads as glass in a reveal.
		_box(tool, Vector3(0.0, sill + opening * 0.5, 0.0),
			Vector3(opening, opening, thickness * 0.35), GLASS)
		return _finish(tool)

	_box(tool, Vector3(0.0, STOREY * 0.5, 0.0), Vector3(inner, STOREY, thickness), PLASTER)
	# A brace across the panel, which is what makes it look built rather than
	# extruded.
	_box(tool, Vector3(0.0, STOREY * 0.55, 0.0), Vector3(inner, 0.13, thickness * 1.2), TIMBER)
	return _finish(tool)

static func _floor() -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(tool, Vector3(0.0, 0.08, 0.0), Vector3(MODULE, 0.16, MODULE), TIMBER)
	# Boards, so a floor is not one flat slab of colour.
	for i in 4:
		var offset := (float(i) - 1.5) * (MODULE / 4.0)
		_box(tool, Vector3(0.0, 0.17, offset), Vector3(MODULE, 0.03, 0.06), TIMBER_DARK)
	return _finish(tool)

## A roof slope, or the ridge piece that caps two of them.
static func _roof(peak: bool) -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	if peak:
		# A prism: two slopes meeting at a ridge, for the top of the house.
		var half := MODULE * 0.5
		var rise := 1.5
		var points: Array[Vector3] = [
			Vector3(-half, 0.0, -half), Vector3(half, 0.0, -half),
			Vector3(half, 0.0, half), Vector3(-half, 0.0, half),
			Vector3(0.0, rise, -half), Vector3(0.0, rise, half),
		]
		_quad(tool, points[0], points[1], points[4], points[4], TILE)
		_quad(tool, points[3], points[2], points[5], points[5], TILE)
		_quad(tool, points[0], points[4], points[5], points[3], TILE)
		_quad(tool, points[1], points[2], points[5], points[4], TILE)
		return _finish(tool)

	# A single sloping panel, thick enough to have an edge.
	var slope := 1.1
	_box(tool, Vector3(0.0, slope * 0.5, 0.0), Vector3(MODULE, 0.16, MODULE * 1.18), TILE, deg_to_rad(-28.0))
	return _finish(tool)

static func _stairs() -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 6
	for i in steps:
		var t := float(i) / float(steps)
		var rise := STOREY * (t + 1.0 / float(steps))
		var depth := MODULE / float(steps)
		_box(
			tool,
			Vector3(0.0, rise * 0.5, MODULE * 0.5 - depth * (float(i) + 0.5)),
			Vector3(MODULE * 0.8, rise, depth),
			STONE
		)
	return _finish(tool)

static func _post() -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(tool, Vector3(0.0, STOREY * 0.5, 0.0), Vector3(0.2, STOREY, 0.2), TIMBER_DARK)
	return _finish(tool)

static func _finish(tool: SurfaceTool) -> Mesh:
	tool.generate_normals()
	return tool.commit()

static func _box(
	tool: SurfaceTool, at: Vector3, size: Vector3, color: Color, tilt := 0.0
) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var basis := Basis(Vector3.RIGHT, tilt) if not is_zero_approx(tilt) else Basis()
	var arrays := mesh.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var transform := Transform3D(basis, at)
	for i in indices.size():
		tool.set_color(color)
		tool.add_vertex(transform * vertices[indices[i]])

static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	for vertex in [a, b, c]:
		tool.set_color(color)
		tool.add_vertex(vertex)
	for vertex in [a, c, d]:
		tool.set_color(color)
		tool.add_vertex(vertex)
