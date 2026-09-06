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
const BED := &"bed"

const ALL: Array[StringName] = [
	BED,
	WALL, WALL_DOOR, WALL_WINDOW, FLOOR, ROOF, ROOF_PEAK, STAIRS, POST,
]

## Wall geometry, shared between the mesh in _wall() and the collision built
## for it below — one set of numbers, so a door cut into the mesh is a door
## cut into the collision too.
const WALL_THICKNESS := 0.18
const WALL_POST := 0.16
const DOOR_WIDTH := 1.0
const DOOR_HEIGHT := 1.75
const WINDOW_OPENING := 0.9
const WINDOW_SILL := 0.95

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
	## The reason to build a house rather than to assemble one.
	##
	## Everything else here makes a shape; a bed makes a place you can be. A
	## child who sleeps in one wakes at dawn, rested — so a house is somewhere
	## to get through the night rather than something to look at afterwards.
	BED: {"label": "bed", "icon": "b", "cost": {&"stick": 3, &"reed": 3}, "footprint": MODULE, "height": 0.55},
}

static func label(kind: StringName) -> String:
	return Text.of("part_" + String(kind))

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

## A low frame with bedding on it. Deliberately plain: it has to read as a bed
## from above, at the distance a child stands, in a house with no lighting.
static func _bed() -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	_box(tool, Vector3(0.0, 0.20, 0.0), Vector3(MODULE * 0.82, 0.16, MODULE * 0.52), TIMBER)

	# Four stubby legs, so it stands rather than lies.
	for side in PackedFloat32Array([-1.0, 1.0]):
		for end in PackedFloat32Array([-1.0, 1.0]):
			_box(
				tool, Vector3(side * MODULE * 0.35, 0.10, end * MODULE * 0.20),
				Vector3(0.12, 0.20, 0.12), TIMBER.darkened(0.2)
			)

	_box(
		tool, Vector3(0.0, 0.35, 0.0),
		Vector3(MODULE * 0.78, 0.14, MODULE * 0.48), Color(0.86, 0.84, 0.78)
	)

	# A pillow at one end, which is most of what says which way round it is.
	_box(
		tool, Vector3(-MODULE * 0.22, 0.46, 0.0),
		Vector3(MODULE * 0.30, 0.12, MODULE * 0.40), Color(0.94, 0.93, 0.90)
	)

	tool.generate_normals()
	return tool.commit()

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

## Whether a piece should stop a body rather than let it pass through.
##
## Floors, roofs and stairs are left out: nothing here supports standing on an
## upper storey yet, and a solid floor with no way onto it would only trap a
## child under it. Walls, doors, windows and posts are the pieces a house is
## judged by at ground level, so those are the ones that need to be real.
static func is_solid(kind: StringName) -> bool:
	return kind == WALL or kind == WALL_DOOR or kind == WALL_WINDOW or kind == POST

## Add the collision a piece needs, as a child of the node its mesh lives on.
##
## A door cuts an opening into the collision the same way it cuts one into the
## mesh — two side pillars and a lintel, not one box across the whole panel —
## because a door a child cannot walk through is a wall wearing a costume.
static func add_collision(node: Node3D, kind: StringName) -> void:
	var body := StaticBody3D.new()
	node.add_child(body)
	match kind:
		WALL_DOOR:
			var inner := MODULE - WALL_POST * 2.0
			var side_width := (inner - DOOR_WIDTH) * 0.5
			var pillar_width := WALL_POST + side_width
			for side in PackedFloat32Array([-1.0, 1.0]):
				var centre := side * (MODULE * 0.5 - pillar_width * 0.5)
				_collision_box(
					body, Vector3(centre, STOREY * 0.5, 0.0),
					Vector3(pillar_width, STOREY, WALL_THICKNESS)
				)
			_collision_box(
				body, Vector3(0.0, (DOOR_HEIGHT + STOREY) * 0.5, 0.0),
				Vector3(DOOR_WIDTH, STOREY - DOOR_HEIGHT, WALL_THICKNESS)
			)
		WALL, WALL_WINDOW:
			_collision_box(
				body, Vector3(0.0, STOREY * 0.5, 0.0),
				Vector3(MODULE, STOREY, WALL_THICKNESS)
			)
		POST:
			_collision_box(body, Vector3(0.0, STOREY * 0.5, 0.0), Vector3(0.2, STOREY, 0.2))

static func _collision_box(body: StaticBody3D, at: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)

## A wall panel with a timber frame, optionally holed for a door or a window.
## Built as a frame plus panels rather than a box with a hole cut out, because
## a hole is a boolean operation and a frame is four slabs.
static func _wall(door: bool, window: bool) -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var thickness := WALL_THICKNESS
	var post := WALL_POST

	# Corner posts, which is what makes a row of walls read as timber framing
	# rather than as a flat fence.
	for side in PackedFloat32Array([-1.0, 1.0]):
		_box(tool, Vector3(side * (MODULE * 0.5 - post * 0.5), STOREY * 0.5, 0.0),
			Vector3(post, STOREY, thickness * 1.15), TIMBER_DARK)

	var inner := MODULE - post * 2.0

	if door:
		var door_width := DOOR_WIDTH
		var door_height := DOOR_HEIGHT
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
		var opening := WINDOW_OPENING
		var sill := WINDOW_SILL
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

## A roof: a ridge running along the module, or a single slope for a lean-to.
##
## Both sit with their lowest edge at y = 0, so a roof placed one storey up
## rests exactly on top of the walls below it. The earlier version was a tilted
## box whose centre was at the placement point, which left roofs hanging in the
## air at an angle over the walls they were meant to cover.
static func _roof(peak: bool) -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half := MODULE * 0.5
	# Slight overhang, because a roof flush with the wall reads as a lid.
	var eaves := half + 0.16
	var rise := 1.5 if peak else 1.0

	if peak:
		# A ridge along z: two slopes meeting over the middle of the square.
		var ridge_front := Vector3(0.0, rise, -eaves)
		var ridge_back := Vector3(0.0, rise, eaves)
		var left_front := Vector3(-eaves, 0.0, -eaves)
		var left_back := Vector3(-eaves, 0.0, eaves)
		var right_front := Vector3(eaves, 0.0, -eaves)
		var right_back := Vector3(eaves, 0.0, eaves)

		_quad(tool, left_front, left_back, ridge_back, ridge_front, TILE)
		_quad(tool, ridge_front, ridge_back, right_back, right_front, TILE)
		# Gable ends, so the roof is solid rather than an open tent.
		_tri(tool, left_front, ridge_front, right_front, PLASTER)
		_tri(tool, right_back, ridge_back, left_back, PLASTER)
		return _finish(tool)

	# A lean-to: one slope, high at the back.
	var low_front := Vector3(-eaves, 0.0, -eaves)
	var low_front_right := Vector3(eaves, 0.0, -eaves)
	var high_back := Vector3(-eaves, rise, eaves)
	var high_back_right := Vector3(eaves, rise, eaves)
	_quad(tool, low_front, low_front_right, high_back_right, high_back, TILE)
	_tri(tool, low_front, high_back, Vector3(-eaves, 0.0, eaves), PLASTER)
	_tri(tool, low_front_right, Vector3(eaves, 0.0, eaves), high_back_right, PLASTER)
	return _finish(tool)

static func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var winding: Array[Vector3] = [a, b, c]
	for vertex in winding:
		tool.set_color(color)
		tool.add_vertex(vertex)

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
	var winding: Array[Vector3] = [a, b, c, a, c, d]
	for vertex in winding:
		tool.set_color(color)
		tool.add_vertex(vertex)
