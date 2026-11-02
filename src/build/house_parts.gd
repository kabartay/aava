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
## A whole roof in one tap: aimed into a room with walls all round it, it covers
## the room with one pitched roof. Laying a roof square by square, each one a
## storey up, was the step at which a child's house stopped being finished.
const ROOF_ROOM := &"roof_room"

const ALL: Array[StringName] = [
	BED,
	WALL, WALL_DOOR, WALL_WINDOW, FLOOR, ROOF, ROOF_PEAK, STAIRS, POST, ROOF_ROOM,
]

## Where on the grid a piece sits.
##
## A wall used to stand in the middle of a square, with the same footprint as a
## floor, so a room was a ring of walls with the floor squares *beside* them —
## and a wall and a floor could never share a square. A real wall stands on the
## line between two squares, so that is where walls, doors and windows go now;
## floors, stairs, beds and roofs fill the squares, and posts stand on the
## corners where four squares meet.
enum Seat { CELL, EDGE, CORNER }

## Half a module: cell centres, edges and corners all fall on whole multiples
## of it, so one integer pair names any of them.
const HALF := MODULE * 0.5

## How many storeys a house may have. Enough for a tower; few enough that a
## stack of walls a child keeps tapping on does not climb out of sight.
const MAX_STOREYS := 3

## The largest room one tap of the whole roof will cover, in squares a side.
## Sixteen metres is a barn; past that the search for walls is looking at the
## open valley, and stops.
const ROOM_LONGEST := 8

## How steep the whole roof is: rise over half the width. Three in four reads
## as a house roof at every size; flatter looked like a shed lid.
const ROOF_PITCH := 0.75
## How far the whole roof reaches past the walls, and how thick it is.
const ROOF_EAVES := 0.35
const ROOF_THICKNESS := 0.12

## How far a bed stands up off a floor laid under it, so its legs stand on the
## boards rather than in them.
const FLOOR_TOP := 0.17

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
	WALL: {"label": "wall", "cost": {&"stick": 2}, "footprint": MODULE, "height": STOREY},
	WALL_DOOR: {"label": "door", "cost": {&"stick": 3}, "footprint": MODULE, "height": STOREY},
	WALL_WINDOW: {"label": "window", "cost": {&"stick": 2, &"reed": 1}, "footprint": MODULE, "height": STOREY},
	FLOOR: {"label": "floor", "cost": {&"stick": 2}, "footprint": MODULE, "height": 0.16},
	ROOF: {"label": "roof", "cost": {&"reed": 2}, "footprint": MODULE, "height": 1.1},
	ROOF_PEAK: {"label": "peak", "cost": {&"reed": 3}, "footprint": MODULE, "height": 1.5},
	STAIRS: {"label": "stairs", "cost": {&"stone": 2}, "footprint": MODULE, "height": STOREY},
	POST: {"label": "post", "cost": {&"stick": 1}, "footprint": 0.4, "height": STOREY},
	## The reason to build a house rather than to assemble one.
	##
	## Everything else here makes a shape; a bed makes a place you can be. A
	## child who sleeps in one wakes at dawn, rested — so a house is somewhere
	## to get through the night rather than something to look at afterwards.
	BED: {"label": "bed", "cost": {&"stick": 3, &"reed": 3}, "footprint": MODULE, "height": 0.55},
	## Priced per square it covers, at what a single roof square costs, so a
	## whole roof is never dearer than the same roof laid by hand.
	ROOF_ROOM: {"label": "whole roof", "cost": {&"reed": 2}, "footprint": MODULE, "height": 1.5},
}

static func label(kind: StringName) -> String:
	return Text.of("part_" + String(kind))

static func cost(kind: StringName) -> Dictionary:
	return INFO[kind]["cost"]

static func footprint(kind: StringName) -> float:
	return INFO[kind]["footprint"]

static func height(kind: StringName) -> float:
	return INFO[kind]["height"]

static func is_house_part(kind: StringName) -> bool:
	return INFO.has(kind)

## What a piece costs when it covers this many squares. Only the whole roof
## covers more than one.
static func cost_for(kind: StringName, cells: int) -> Dictionary:
	var each := cost(kind)
	if kind != ROOF_ROOM or cells <= 1:
		return each
	var total := {}
	for item in each:
		total[item] = int(each[item]) * cells
	return total

static func seat(kind: StringName) -> Seat:
	match kind:
		WALL, WALL_DOOR, WALL_WINDOW:
			return Seat.EDGE
		POST:
			return Seat.CORNER
	return Seat.CELL

## Which pieces compete for the same place. One wall per edge per storey, one
## floor per square per storey — but a wall and the floor beside it, or a bed
## on a floor, are different layers and never clash. Empty for anything that
## is not a house part.
static func layer(kind: StringName) -> StringName:
	match kind:
		WALL, WALL_DOOR, WALL_WINDOW:
			return &"wall"
		FLOOR, STAIRS:
			return &"floor"
		ROOF, ROOF_PEAK, ROOF_ROOM:
			return &"roof"
		POST:
			return &"post"
		BED:
			return &"furniture"
	return &""

static func is_roof(kind: StringName) -> bool:
	return kind == ROOF or kind == ROOF_PEAK or kind == ROOF_ROOM

## The grid point a position stands on, in half-modules: both even for a
## square, one odd for an edge, both odd for a corner. A wall saved before
## walls moved onto edges stands on a square's centre, and keeps that key —
## it stays exactly where it was, and only clashes with another such wall.
static func key_of(at: Vector3) -> Vector2i:
	return Vector2i(roundi(at.x / HALF), roundi(at.z / HALF))

## How many squares a whole roof spans along x and along z. Its extent is kept
## as (across, along) the ridge, and the ridge runs along z until it is turned.
static func world_span(spin: float, extent: Vector2i) -> Vector2i:
	if posmod(roundi(spin / (PI * 0.5)), 2) == 1:
		return Vector2i(extent.y, extent.x)
	return extent

## Every grid point a piece occupies: one for every piece but the whole roof,
## which holds every square under it.
static func keys_of(kind: StringName, at: Vector3, spin: float, extent := Vector2i.ONE) -> Array[Vector2i]:
	var centre := key_of(at)
	var keys: Array[Vector2i] = []
	if kind != ROOF_ROOM:
		keys.append(centre)
		return keys
	var span := world_span(spin, extent)
	for i in span.x:
		for j in span.y:
			keys.append(Vector2i(centre.x - (span.x - 1) + 2 * i, centre.y - (span.y - 1) + 2 * j))
	return keys

## The nearest square centre to a point.
static func snap_cell(x: float, z: float) -> Vector2:
	return Vector2(snappedf(x, MODULE), snappedf(z, MODULE))

## The nearest edge running along x (the line between a square and the one
## north or south of it) or along z.
static func snap_edge(x: float, z: float, runs_along_x: bool) -> Vector2:
	if runs_along_x:
		return Vector2(snappedf(x, MODULE), snappedf(z - HALF, MODULE) + HALF)
	return Vector2(snappedf(x - HALF, MODULE) + HALF, snappedf(z, MODULE))

static func snap_corner(x: float, z: float) -> Vector2:
	return Vector2(snappedf(x - HALF, MODULE) + HALF, snappedf(z - HALF, MODULE) + HALF)

## The mesh for a placed piece. Only the whole roof depends on more than its
## kind: it is as big as the room it covers.
static func mesh_for(kind: StringName, extent := Vector2i.ONE) -> Mesh:
	if kind == ROOF_ROOM:
		return roof_mesh(extent)
	return build_mesh(kind)

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
		ROOF_ROOM:
			# A one-square room, for the palette and anything that asks without
			# a room to measure.
			return roof_mesh(Vector2i.ONE)
		STAIRS:
			return _stairs()
		BED:
			# _bed() has been sitting here unreferenced since it was written.
			# Without this branch a bed fell through to `_post()`, so three
			# sticks and three reeds — spent on the one piece that turns a
			# shelter into somewhere to spend the night — bought a two-metre
			# dark fence post standing in the middle of the room.
			return _bed()
		_:
			return _post()

## Whether a piece should stop a body rather than let it pass through.
##
## Floors and stairs are left out: nothing here supports standing on an upper
## storey yet, and a solid floor with no way onto it would only trap a child
## under it. Walls, doors, windows and posts are the pieces a house is judged by
## at ground level, so those are the ones that need to be real.
##
## Roofs are solid too, now that a roof always sits on top of walls or a storey
## up rather than wherever a child happened to be standing: nobody is trapped
## under one, and a roof the camera and the rain can pass through is a picture.
static func is_solid(kind: StringName) -> bool:
	return (
		kind == WALL or kind == WALL_DOOR or kind == WALL_WINDOW or kind == POST
		or is_roof(kind)
	)

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
		ROOF, ROOF_PEAK, ROOF_ROOM:
			# The roof's own faces, so what stops a body is exactly the shape
			# that is drawn — slopes, gables and all — whatever size the room.
			var drawn := node as MeshInstance3D
			if drawn != null and drawn.mesh != null:
				var faces := drawn.mesh.create_trimesh_shape()
				# Solid from underneath as well as from above: the ceiling is
				# what a head, a camera or a ray from inside the room meets.
				faces.backface_collision = true
				var shape := CollisionShape3D.new()
				shape.shape = faces
				body.add_child(shape)

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

		# Wound clockwise seen from outside, which is what Godot calls the
		# front of a face. The other way round the slopes faced into the roof,
		# and a peaked roof was invisible from the street and showed only from
		# underneath.
		_quad(tool, left_front, ridge_front, ridge_back, left_back, TILE)
		_quad(tool, ridge_front, right_front, right_back, ridge_back, TILE)
		# Gable ends, so the roof is solid rather than an open tent.
		_tri(tool, left_front, right_front, ridge_front, PLASTER)
		_tri(tool, right_back, left_back, ridge_back, PLASTER)
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

## The whole roof over a room `extent` squares across by `extent.y` along: two
## slopes meeting at a ridge down the middle of the long way, a gable at each
## end, and a timber ceiling under it so it is a roof from inside as well.
##
## Local y = 0 is the top of the walls it stands on, and the underside of each
## slope passes through y = 0 exactly over the wall line, so the roof rests on
## the walls — no gap of sky above them and no slope sunk into them — and only
## its eaves reach out past them and down a little, as eaves do.
static func roof_mesh(extent: Vector2i) -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half := float(maxi(extent.x, 1)) * MODULE * 0.5
	var end := float(maxi(extent.y, 1)) * MODULE * 0.5
	var rise := half * ROOF_PITCH
	var drop := ROOF_EAVES * ROOF_PITCH
	var reach := end + ROOF_EAVES
	var lift := Vector3(0.0, ROOF_THICKNESS, 0.0)

	for side in PackedFloat32Array([-1.0, 1.0]):
		var eave := Vector3(side * (half + ROOF_EAVES), -drop, 0.0)
		var ridge := Vector3(0.0, rise, 0.0)
		var front := Vector3(0.0, 0.0, -reach)
		var back := Vector3(0.0, 0.0, reach)
		var up_and_out := Vector3(side * rise, half, 0.0).normalized()
		# The tiles on top, and the ceiling boards under them.
		_face(tool, [eave + lift + front, ridge + lift + front, ridge + lift + back, eave + lift + back], up_and_out, TILE)
		_face(tool, [eave + front, ridge + front, ridge + back, eave + back], -up_and_out, TIMBER)
		# The edge of the eaves, so the slope reads as a thickness and not a
		# sheet of paper.
		_face(tool, [eave + front, eave + back, eave + lift + back, eave + lift + front], Vector3(side, 0.0, 0.0), TIMBER_DARK)
		# The ends of each slope, past the gables.
		for edge in PackedFloat32Array([-1.0, 1.0]):
			var at := Vector3(0.0, 0.0, edge * reach)
			_face(tool, [eave + at, ridge + at, ridge + lift + at, eave + lift + at], Vector3(0.0, 0.0, edge), TIMBER_DARK)

	# The gables: a triangle of plaster standing on each end wall, as thick as
	# the wall, faced both ways so it is a wall from inside the room too.
	var thick := WALL_THICKNESS * 0.5
	for edge in PackedFloat32Array([-1.0, 1.0]):
		for face in PackedFloat32Array([-1.0, 1.0]):
			var z := edge * end + face * thick
			_face(tool, [
				Vector3(-half, 0.0, z), Vector3(half, 0.0, z), Vector3(0.0, rise, z),
			], Vector3(0.0, 0.0, edge * face), PLASTER)

	# A ridge board along the top.
	_box(tool, Vector3(0.0, rise + ROOF_THICKNESS, 0.0), Vector3(0.18, 0.14, reach * 2.0), TIMBER_DARK)
	return _finish(tool)

## A flat polygon (three or four corners) wound so its front looks along
## `outward`. Winding by hand is how the peaked roof ended up visible only from
## underneath; asking which way a face should look and turning it to suit
## cannot get that wrong.
static func _face(tool: SurfaceTool, corners: Array, outward: Vector3, color: Color) -> void:
	var points: Array[Vector3] = []
	for corner: Vector3 in corners:
		points.append(corner)
	var front := -(points[1] - points[0]).cross(points[2] - points[0])
	if front.dot(outward) < 0.0:
		points.reverse()
	var winding: Array[Vector3] = [points[0], points[1], points[2]]
	if points.size() == 4:
		winding.append_array([points[0], points[2], points[3]])
	for vertex in winding:
		tool.set_color(color)
		tool.add_vertex(vertex)

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
