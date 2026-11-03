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
## A shop front: a window nearly the width of the square, with the sill at
## counter height.
const WALL_WIDE := &"wall_wide"
## Waist high, for the front of a counter or the rail of a porch.
const WALL_HALF := &"wall_half"
## A doorway with no door in it.
const WALL_ARCH := &"wall_arch"
## A flat roof for a square: a lean-to's lid, or the top of a shed.
const ROOF_FLAT := &"roof_flat"
const CHIMNEY := &"chimney"
const TABLE := &"table"
const CHAIR := &"chair"
const COUNTER := &"counter"
const SHELF := &"shelf"
const LAMP := &"lamp"
const SIGN := &"sign"
const POT := &"pot"
const RUG := &"rug"

const ALL: Array[StringName] = [
	BED,
	WALL, WALL_DOOR, WALL_WINDOW, WALL_WIDE, WALL_HALF, WALL_ARCH,
	FLOOR, ROOF, ROOF_PEAK, STAIRS, POST, ROOF_ROOM, ROOF_FLAT, CHIMNEY,
	TABLE, CHAIR, COUNTER, SHELF, LAMP, SIGN, POT, RUG,
]

## What a wall is made of. The first is the look every wall had before there
## was a choice, so a wall with no material saved with it is read as that one.
const PLASTER_WALL := &"plaster"
const STONE_WALL := &"stone"
const BLUE_WALL := &"blue"
const RED_WALL := &"red"
const MATERIALS: Array[StringName] = [PLASTER_WALL, STONE_WALL, BLUE_WALL, RED_WALL]
const DEFAULT_MATERIAL := PLASTER_WALL

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
## How thick a floor slab is, and how high the first step of a flight of stairs
## stands off the ground: low enough for a foot to clear.
const FLOOR_THICKNESS := 0.16
## How thick the floor is to a body: a little less than it is drawn. The top of
## the stairs' ramp passes over the near edge of a floor laid beside it, and a
## sphere rolling over an edge that lies exactly on its path is stopped by it as
## if it were a wall; an edge eight centimetres under the path is not touched.
## The feet sink that far into the boards, which no one can see.
const FLOOR_STANDS := 0.08
const STAIRS_FOOT := 0.12
## How far the top of the stairs' ramp carries on, level, past the top step.
const STAIRS_LANDING := 0.4

## Wall geometry, shared between the mesh in _wall() and the collision built
## for it below — one set of numbers, so a door cut into the mesh is a door
## cut into the collision too.
const WALL_THICKNESS := 0.18
const WALL_POST := 0.16
const DOOR_WIDTH := 1.0
const DOOR_HEIGHT := 1.75
const WINDOW_OPENING := 0.9
const WINDOW_SILL := 0.95
## The shop-front window, and the arch.
const WIDE_OPENING := 1.4
const WIDE_SILL := 0.85
const WIDE_HEIGHT := 1.05
const ARCH_WIDTH := 1.2
const ARCH_HEIGHT := 1.95
## The waist-high wall, and how far each wall reaches past the end of its
## square: half its own thickness, which is what fills the corner where two
## walls meet at right angles. Each wall ended exactly on the line of its
## square, so the outside of every corner was a notch half a wall wide.
const ARCH_SHOULDER := 0.25
const CHIMNEY_AT := 0.5
const HALF_WALL_HEIGHT := 1.0
const CORNER_FILL := WALL_THICKNESS * 0.5

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
	WALL_WIDE: {"label": "wide window", "cost": {&"stick": 3, &"reed": 2}, "footprint": MODULE, "height": STOREY},
	WALL_HALF: {"label": "half wall", "cost": {&"stick": 1}, "footprint": MODULE, "height": HALF_WALL_HEIGHT},
	WALL_ARCH: {"label": "arch", "cost": {&"stick": 2, &"stone": 1}, "footprint": MODULE, "height": STOREY},
	ROOF_FLAT: {"label": "flat roof", "cost": {&"reed": 1, &"stick": 1}, "footprint": MODULE, "height": 0.3},
	CHIMNEY: {"label": "chimney", "cost": {&"stone": 3}, "footprint": MODULE, "height": 2.7},
	TABLE: {"label": "table", "cost": {&"stick": 3}, "footprint": MODULE, "height": 0.76},
	CHAIR: {"label": "chair", "cost": {&"stick": 2}, "footprint": MODULE, "height": 0.9},
	COUNTER: {"label": "counter", "cost": {&"stick": 4}, "footprint": MODULE, "height": 1.0},
	SHELF: {"label": "shelf", "cost": {&"stick": 3, &"reed": 1}, "footprint": MODULE, "height": 1.9},
	LAMP: {"label": "lamp", "cost": {&"stick": 1, &"stone": 1}, "footprint": MODULE, "height": 1.7},
	SIGN: {"label": "sign", "cost": {&"stick": 2}, "footprint": MODULE, "height": 1.3},
	POT: {"label": "flower pot", "cost": {&"stone": 1, &"seed": 1}, "footprint": MODULE, "height": 0.76},
	RUG: {"label": "rug", "cost": {&"wool": 1, &"reed": 1}, "footprint": MODULE, "height": 0.03},
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
	if is_wall(kind):
		return Seat.EDGE
	if kind == POST:
		return Seat.CORNER
	return Seat.CELL

## Every piece that stands on an edge: all the kinds of wall.
static func is_wall(kind: StringName) -> bool:
	return (
		kind == WALL or kind == WALL_DOOR or kind == WALL_WINDOW
		or kind == WALL_WIDE or kind == WALL_HALF or kind == WALL_ARCH
	)

## The look of a wall in each material: the panel, the frame round it and the
## brace across it. Painted wood is a flat colour in a pale frame, which is
## what paint on boards looks like from across a meadow.
static func wall_look(material: StringName) -> Dictionary:
	match material:
		STONE_WALL:
			return {"panel": Color(0.62, 0.61, 0.59), "frame": Color(0.42, 0.41, 0.40), "brace": Color(0.50, 0.49, 0.48)}
		BLUE_WALL:
			return {"panel": Color(0.42, 0.62, 0.82), "frame": Color(0.92, 0.92, 0.88), "brace": Color(0.92, 0.92, 0.88)}
		RED_WALL:
			return {"panel": Color(0.78, 0.34, 0.30), "frame": Color(0.92, 0.90, 0.84), "brace": Color(0.92, 0.90, 0.84)}
	return {"panel": PLASTER, "frame": TIMBER_DARK, "brace": TIMBER}

## A material read out of a saved or sent value, which may be anything:
## the plaster look for whatever is not one of ours.
static func material_from(value: Variant) -> StringName:
	var named := StringName(str(value))
	return named if MATERIALS.has(named) else DEFAULT_MATERIAL

const MATERIAL_TEXT := {
	PLASTER_WALL: "ui_material_plaster",
	STONE_WALL: "ui_material_stone",
	BLUE_WALL: "ui_material_blue",
	RED_WALL: "ui_material_red",
}

static func material_label(material: StringName) -> String:
	return Text.of(MATERIAL_TEXT[material] if MATERIAL_TEXT.has(material) else "ui_material_plaster")

## Which pieces compete for the same place. One wall per edge per storey, one
## floor per square per storey — but a wall and the floor beside it, or a bed
## on a floor, are different layers and never clash. Empty for anything that
## is not a house part.
static func layer(kind: StringName) -> StringName:
	match kind:
		WALL, WALL_DOOR, WALL_WINDOW, WALL_WIDE, WALL_HALF, WALL_ARCH:
			return &"wall"
		FLOOR, STAIRS:
			return &"floor"
		ROOF, ROOF_PEAK, ROOF_ROOM, ROOF_FLAT:
			return &"roof"
		POST:
			return &"post"
		# A table and the chair pulled up to it share a square, and so does a
		# rug under either: each of those is a layer of its own.
		BED, TABLE, COUNTER, SHELF, LAMP, POT:
			return &"furniture"
		CHAIR:
			return &"seat"
		RUG:
			return &"rug"
		SIGN:
			return &"sign"
		CHIMNEY:
			return &"chimney"
	return &""

## What stands on the floor of a room: the bed, table, counter, shelf, lamp and
## pot, the chair, the rug.
static func is_furniture(kind: StringName) -> bool:
	var on := layer(kind)
	return on == &"furniture" or on == &"seat" or on == &"rug"

static func is_roof(kind: StringName) -> bool:
	return kind == ROOF or kind == ROOF_PEAK or kind == ROOF_ROOM or kind == ROOF_FLAT

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
static func mesh_for(kind: StringName, extent := Vector2i.ONE, material := DEFAULT_MATERIAL) -> Mesh:
	if kind == ROOF_ROOM:
		return roof_mesh(extent)
	return build_mesh(kind, material)

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

static func build_mesh(kind: StringName, material := DEFAULT_MATERIAL) -> Mesh:
	if is_wall(kind):
		return _wall(kind, material)
	match kind:
		ROOF_FLAT:
			return _flat_roof()
		CHIMNEY:
			return _chimney()
		TABLE:
			return _table()
		CHAIR:
			return _chair()
		COUNTER:
			return _counter()
		SHELF:
			return _shelf()
		LAMP:
			return _lamp()
		SIGN:
			return _sign()
		POT:
			return _pot()
		RUG:
			return _rug()
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
		is_wall(kind) or kind == POST or is_roof(kind) or kind == CHIMNEY
		or not furniture_boxes(kind).is_empty()
	)

## The solid parts of a piece of furniture, as (centre, size) pairs in the
## piece's own space. The same measurements the mesh is built from, so what
## stops a body is what is drawn.
static func furniture_boxes(kind: StringName) -> Array:
	match kind:
		TABLE:
			return [[Vector3(0.0, 0.38, 0.0), Vector3(1.0, 0.76, 0.7)]]
		CHAIR:
			# Not solid: a chair stands in the square of its table, on the side a
			# child walks up to it, and a body that catches on it never reaches
			# the table. Sitting down is the cafe's doing, not the chair's.
			return []
		COUNTER:
			return [[Vector3(0.0, 0.5, 0.0), Vector3(1.9, 1.0, 0.7)]]
		SHELF:
			return [[Vector3(0.0, 0.95, -0.72), Vector3(1.8, 1.9, 0.4)]]
		LAMP:
			return [[Vector3(0.0, 0.85, 0.0), Vector3(0.34, 1.7, 0.34)]]
		SIGN:
			return [
				[Vector3(0.7, 0.325, 0.0), Vector3(0.08, 0.65, 0.08)],
				[Vector3(0.7, 1.1, 0.0), Vector3(0.56, 0.42, 0.08)],
			]
		POT:
			return [[Vector3(0.0, 0.38, 0.0), Vector3(0.38, 0.76, 0.38)]]
	return []

## Add the collision a piece needs, as a child of the node its mesh lives on.
##
## A door cuts an opening into the collision the same way it cuts one into the
## mesh — two side pillars and a lintel, not one box across the whole panel —
## because a door a child cannot walk through is a wall wearing a costume.
static func add_collision(node: Node3D, kind: StringName) -> void:
	var body := StaticBody3D.new()
	# A thin thing — a post, a lamp, a table, a counter — is on the props layer,
	# as the cafe's furniture and the signpost are: the child bumps it and the
	# camera's arm does not. On the ground layer the arm caught on every table
	# and post in a house a child built, and the view rattled the way it once
	# did at the slide. Walls, roofs, floors and stairs stay on the ground
	# layer, which is what keeps the camera inside a room.
	if kind == POST or kind == CHIMNEY or not furniture_boxes(kind).is_empty():
		body.collision_layer = TerrainSpec.LAYER_PROPS
	node.add_child(body)
	for pair: Array in furniture_boxes(kind):
		_collision_box(body, pair[0], pair[1])
	match kind:
		WALL_DOOR, WALL_ARCH:
			# Two pillars and a lintel round an opening. Each pillar reaches
			# past the end of the square by CORNER_FILL, like the drawn wall.
			var opening := DOOR_WIDTH if kind == WALL_DOOR else ARCH_WIDTH
			var opening_height := DOOR_HEIGHT if kind == WALL_DOOR else ARCH_HEIGHT
			var inner := MODULE - WALL_POST * 2.0
			var side_width := (inner - opening) * 0.5
			var pillar_width := WALL_POST + side_width + CORNER_FILL
			for side in PackedFloat32Array([-1.0, 1.0]):
				var centre := side * (MODULE * 0.5 + CORNER_FILL - pillar_width * 0.5)
				_collision_box(
					body, Vector3(centre, STOREY * 0.5, 0.0),
					Vector3(pillar_width, STOREY, WALL_THICKNESS)
				)
			_collision_box(
				body, Vector3(0.0, (opening_height + STOREY) * 0.5, 0.0),
				Vector3(opening, STOREY - opening_height, WALL_THICKNESS)
			)
			if kind == WALL_ARCH:
				# The rounded shoulders of the arch, as the steps they are drawn.
				for side in PackedFloat32Array([-1.0, 1.0]):
					_collision_box(
						body, Vector3(side * (ARCH_WIDTH * 0.5 - ARCH_SHOULDER * 0.5), ARCH_HEIGHT - ARCH_SHOULDER * 0.5, 0.0),
						Vector3(ARCH_SHOULDER, ARCH_SHOULDER, WALL_THICKNESS)
					)
		WALL, WALL_WINDOW, WALL_WIDE:
			_collision_box(
				body, Vector3(0.0, STOREY * 0.5, 0.0),
				Vector3(MODULE + WALL_THICKNESS, STOREY, WALL_THICKNESS)
			)
		WALL_HALF:
			_collision_box(
				body, Vector3(0.0, HALF_WALL_HEIGHT * 0.5, 0.0),
				Vector3(MODULE + WALL_THICKNESS, HALF_WALL_HEIGHT, WALL_THICKNESS)
			)
		POST:
			_collision_box(body, Vector3(0.0, STOREY * 0.5, 0.0), Vector3(0.2, STOREY, 0.2))
		CHIMNEY:
			_collision_box(body, Vector3(CHIMNEY_AT, 1.35, 0.0), Vector3(0.5, 2.7, 0.5))
		FLOOR:
			_collision_box(
				body, Vector3(0.0, FLOOR_STANDS * 0.5, 0.0), Vector3(MODULE, FLOOR_STANDS, MODULE)
			)
		STAIRS:
			# One ramp, not six treads: a body is carried up a slope and cannot
			# be asked to step. It starts a hand's breadth up, which a foot
			# clears, and ends level with the top of the floor of the next
			# storey, so that the child walks off it with no lip to climb. It
			# runs under the treads by at most a step, and is gentle enough to
			# walk (see the check that does).
			var ramp := PackedVector3Array()
			var width := MODULE * 0.4
			for sx in PackedFloat32Array([-1.0, 1.0]):
				ramp.append(Vector3(sx * width, 0.0, MODULE * 0.5))
				ramp.append(Vector3(sx * width, STAIRS_FOOT, MODULE * 0.5))
				ramp.append(Vector3(sx * width, STOREY + FLOOR_THICKNESS, -MODULE * 0.5))
				# A little flat past the top, lying over the edge of the floor
				# there: the crest is one shape's, not a seam between two, which
				# a body stuck on.
				ramp.append(Vector3(sx * width, STOREY + FLOOR_THICKNESS, -MODULE * 0.5 - STAIRS_LANDING))
				ramp.append(Vector3(sx * width, 0.0, -MODULE * 0.5 - STAIRS_LANDING))
			_collision_hull(body, ramp)
		ROOF_FLAT:
			_collision_box(body, Vector3(0.0, 0.11, 0.0), Vector3(2.3, 0.22, 2.3))
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

static func _collision_hull(body: StaticBody3D, points: PackedVector3Array) -> void:
	var shape := CollisionShape3D.new()
	var hull := ConvexPolygonShape3D.new()
	hull.points = points
	shape.shape = hull
	body.add_child(shape)

static func _collision_box(body: StaticBody3D, at: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)

## A wall panel with a frame, optionally holed for a door, a window, a shop
## window or an arch, or cut down to waist height.
## Built as a frame plus panels rather than a box with a hole cut out, because
## a hole is a boolean operation and a frame is four slabs.
static func _wall(kind: StringName, material := DEFAULT_MATERIAL) -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var look := wall_look(material)
	var panel: Color = look["panel"]
	var frame: Color = look["frame"]
	var brace: Color = look["brace"]
	var thickness := WALL_THICKNESS
	var post := WALL_POST
	var top := height(kind)

	# End posts, which is what makes a row of walls read as framing rather than
	# as a flat fence. Each reaches CORNER_FILL past the square, so the outside
	# of a corner is solid; the same colour overlapping the next wall's post is
	# invisible.
	for side in PackedFloat32Array([-1.0, 1.0]):
		var reach := post + CORNER_FILL
		_box(tool, Vector3(side * (MODULE * 0.5 + CORNER_FILL - reach * 0.5), top * 0.5, 0.0),
			Vector3(reach, top, thickness * 1.15), frame)

	var inner := MODULE - post * 2.0

	if kind == WALL_DOOR or kind == WALL_ARCH:
		var door := kind == WALL_DOOR
		var door_width := DOOR_WIDTH if door else ARCH_WIDTH
		var door_height := DOOR_HEIGHT if door else ARCH_HEIGHT
		var side_width := (inner - door_width) * 0.5
		for side in PackedFloat32Array([-1.0, 1.0]):
			_box(tool, Vector3(side * (door_width + side_width) * 0.5, STOREY * 0.5, 0.0),
				Vector3(side_width, STOREY, thickness), panel)
		# Lintel over the opening.
		_box(tool, Vector3(0.0, (door_height + STOREY) * 0.5, 0.0),
			Vector3(door_width, STOREY - door_height, thickness), panel)
		if door:
			_box(tool, Vector3(0.0, door_height, 0.0),
				Vector3(door_width + 0.12, 0.14, thickness * 1.3), frame)
		else:
			# The shoulders of the arch: a step in each top corner, so the
			# opening is rounded off rather than square.
			for side in PackedFloat32Array([-1.0, 1.0]):
				_box(tool, Vector3(side * (door_width * 0.5 - ARCH_SHOULDER * 0.5), door_height - ARCH_SHOULDER * 0.5, 0.0),
					Vector3(ARCH_SHOULDER, ARCH_SHOULDER, thickness * 1.1), frame)
		return _finish(tool)

	if kind == WALL_WINDOW or kind == WALL_WIDE:
		var wide := kind == WALL_WIDE
		var opening := WIDE_OPENING if wide else WINDOW_OPENING
		var opening_height := WIDE_HEIGHT if wide else WINDOW_OPENING
		var sill := WIDE_SILL if wide else WINDOW_SILL
		var side_width := (inner - opening) * 0.5
		for side in PackedFloat32Array([-1.0, 1.0]):
			_box(tool, Vector3(side * (opening + side_width) * 0.5, STOREY * 0.5, 0.0),
				Vector3(side_width, STOREY, thickness), panel)
		_box(tool, Vector3(0.0, sill * 0.5, 0.0), Vector3(opening, sill, thickness), panel)
		var head := sill + opening_height
		_box(tool, Vector3(0.0, (head + STOREY) * 0.5, 0.0),
			Vector3(opening, STOREY - head, thickness), panel)
		# The pane itself, set back so it reads as glass in a reveal.
		_box(tool, Vector3(0.0, sill + opening_height * 0.5, 0.0),
			Vector3(opening, opening_height, thickness * 0.35), GLASS)
		if wide:
			# A sill board that sticks out, which is what a shop front has.
			_box(tool, Vector3(0.0, sill, 0.0), Vector3(opening + 0.1, 0.06, thickness * 1.6), frame)
		return _finish(tool)

	if kind == WALL_HALF:
		_box(tool, Vector3(0.0, top * 0.5 - 0.03, 0.0), Vector3(inner, top - 0.06, thickness), panel)
		# A cap along the top, so it reads as a rail or a counter front.
		_box(tool, Vector3(0.0, top - 0.03, 0.0), Vector3(MODULE, 0.06, thickness * 1.3), brace)
		return _finish(tool)

	_box(tool, Vector3(0.0, STOREY * 0.5, 0.0), Vector3(inner, STOREY, thickness), panel)
	if material == STONE_WALL:
		# Courses of stone: darker lines of mortar across the face.
		for i in 5:
			_box(tool, Vector3(0.0, STOREY * (float(i) + 0.5) / 5.0, 0.0),
				Vector3(inner, 0.04, thickness * 1.05), brace)
		return _finish(tool)
	# A brace across the panel, which is what makes it look built rather than
	# extruded.
	_box(tool, Vector3(0.0, STOREY * 0.55, 0.0), Vector3(inner, 0.13, thickness * 1.2), brace)
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
	# The level piece the ramp carries on with past the top step (see
	# add_collision) is drawn too, or a child stood on the air beyond the stairs
	# whenever no floor lay beside them. Two centimetres under the top of a
	# floor laid there, so where there is one the boards hide it rather than
	# fighting it for the same pixels.
	var landing_top := STOREY + FLOOR_THICKNESS - 0.02
	var landing_base := STOREY - 0.1
	_box(
		tool,
		Vector3(0.0, (landing_top + landing_base) * 0.5, -MODULE * 0.5 - STAIRS_LANDING * 0.5),
		Vector3(MODULE * 0.8, landing_top - landing_base, STAIRS_LANDING),
		STONE
	)
	return _finish(tool)

static func _post() -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(tool, Vector3(0.0, STOREY * 0.5, 0.0), Vector3(0.2, STOREY, 0.2), TIMBER_DARK)
	return _finish(tool)

## A flat roof: a slab a little wider than the square, with a low rim round
## the edge. Its underside is at y = 0, the top of the walls it stands on.
static func _flat_roof() -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wide := MODULE + 0.3
	_box(tool, Vector3(0.0, 0.11, 0.0), Vector3(wide, 0.22, wide), TILE)
	for side in PackedFloat32Array([-1.0, 1.0]):
		_box(tool, Vector3(side * (wide * 0.5 - 0.04), 0.27, 0.0), Vector3(0.08, 0.1, wide), TIMBER_DARK)
		_box(tool, Vector3(0.0, 0.27, side * (wide * 0.5 - 0.04)), Vector3(wide, 0.1, 0.08), TIMBER_DARK)
	return _finish(tool)

## A stone stack, standing a little off the middle of its square so that it
## comes up beside a roof's ridge rather than inside it. Taller than any
## roof it is likely to stand on, and capped.
static func _chimney() -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(tool, Vector3(CHIMNEY_AT, 1.35, 0.0), Vector3(0.5, 2.7, 0.5), STONE.darkened(0.15))
	_box(tool, Vector3(CHIMNEY_AT, 2.65, 0.0), Vector3(0.62, 0.1, 0.62), STONE.darkened(0.35))
	return _finish(tool)

const WOOD_LIGHT := Color(0.74, 0.56, 0.36)

static func _table() -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(tool, Vector3(0.0, 0.725, 0.0), Vector3(1.0, 0.07, 0.7), WOOD_LIGHT)
	for side in PackedFloat32Array([-1.0, 1.0]):
		for end in PackedFloat32Array([-1.0, 1.0]):
			_box(tool, Vector3(side * 0.44, 0.345, end * 0.29), Vector3(0.07, 0.69, 0.07), TIMBER)
	return _finish(tool)

## A chair standing in the same square as a table, on the side the child's own
## turn decides, and facing the middle of the square: the seat and the back
## are built off-centre for exactly that.
static func _chair() -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(tool, Vector3(0.0, 0.45, 0.68), Vector3(0.42, 0.06, 0.42), WOOD_LIGHT)
	for side in PackedFloat32Array([-1.0, 1.0]):
		for end in PackedFloat32Array([-1.0, 1.0]):
			_box(tool, Vector3(side * 0.18, 0.21, 0.68 + end * 0.18), Vector3(0.05, 0.42, 0.05), TIMBER)
	_box(tool, Vector3(0.0, 0.68, 0.865), Vector3(0.42, 0.44, 0.05), TIMBER)
	return _finish(tool)

static func _counter() -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(tool, Vector3(0.0, 0.46, 0.0), Vector3(1.86, 0.92, 0.66), TIMBER_DARK)
	# A panel on the front — the side a customer stands, towards the room's
	# front — and a top that overhangs it.
	_box(tool, Vector3(0.0, 0.44, 0.33), Vector3(1.6, 0.6, 0.03), TIMBER)
	_box(tool, Vector3(0.0, 0.96, 0.0), Vector3(1.9, 0.08, 0.7), WOOD_LIGHT)
	return _finish(tool)

## A shelf standing against the far side of its square, shelves facing the
## near side, with a few jars on the boards.
static func _shelf() -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z := -0.72
	for side in PackedFloat32Array([-1.0, 1.0]):
		_box(tool, Vector3(side * 0.88, 0.95, z), Vector3(0.04, 1.9, 0.4), TIMBER_DARK)
	_box(tool, Vector3(0.0, 0.95, z - 0.19), Vector3(1.8, 1.9, 0.02), TIMBER)
	var jars: Array[Color] = [Color(0.86, 0.45, 0.30), Color(0.40, 0.66, 0.42), Color(0.92, 0.80, 0.40), Color(0.45, 0.58, 0.82)]
	for i in 5:
		var y := 0.04 + float(i) * 0.465
		_box(tool, Vector3(0.0, y, z), Vector3(1.8, 0.06, 0.4), WOOD_LIGHT)
		if i == 4:
			continue
		for j in 4:
			_box(tool, Vector3((float(j) - 1.5) * 0.4, y + 0.2, z + 0.02), Vector3(0.17, 0.3, 0.17), jars[(i + j) % jars.size()])
	return _finish(tool)

## A standing lamp. The shade is the colour of a lit one by day too, so it
## reads as a lamp whether or not it has come on.
static func _lamp() -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(tool, Vector3(0.0, 0.03, 0.0), Vector3(0.34, 0.06, 0.34), TIMBER_DARK)
	_box(tool, Vector3(0.0, 0.8, 0.0), Vector3(0.06, 1.5, 0.06), TIMBER_DARK)
	_box(tool, Vector3(0.0, 1.56, 0.0), Vector3(0.34, 0.28, 0.34), Color(1.0, 0.86, 0.55))
	_box(tool, Vector3(0.0, 1.7 - 0.02, 0.0), Vector3(0.38, 0.04, 0.38), TIMBER_DARK)
	return _finish(tool)

## A board on a post, standing to one side of its square so it does not block
## a door that opens onto it, and facing the same way the square's front does.
static func _sign() -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(tool, Vector3(0.7, 0.325, 0.0), Vector3(0.08, 0.65, 0.08), TIMBER_DARK)
	_box(tool, Vector3(0.7, 1.1, 0.0), Vector3(0.56, 0.42, 0.08), WOOD_LIGHT)
	# A painted shape on it, which is all a sign needs to say "sign" to a
	# child who cannot read the words yet.
	_box(tool, Vector3(0.7, 1.1, 0.045), Vector3(0.4, 0.26, 0.02), Color(0.78, 0.34, 0.30))
	_box(tool, Vector3(0.7, 1.1, 0.06), Vector3(0.18, 0.12, 0.02), Color(0.96, 0.92, 0.82))
	return _finish(tool)

static func _pot() -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(tool, Vector3(0.0, 0.18, 0.0), Vector3(0.38, 0.36, 0.38), Color(0.76, 0.42, 0.28))
	_box(tool, Vector3(0.0, 0.34, 0.0), Vector3(0.42, 0.06, 0.42), Color(0.68, 0.36, 0.24))
	_box(tool, Vector3(0.0, 0.5, 0.0), Vector3(0.3, 0.26, 0.3), Color(0.32, 0.58, 0.30))
	var petals: Array[Color] = [Color(0.95, 0.45, 0.50), Color(0.98, 0.84, 0.35), Color(0.62, 0.50, 0.88)]
	for i in 3:
		var angle := TAU * float(i) / 3.0
		_box(tool, Vector3(cos(angle) * 0.08, 0.7, sin(angle) * 0.08), Vector3(0.12, 0.12, 0.12), petals[i])
	return _finish(tool)

static func _rug() -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(tool, Vector3(0.0, 0.015, 0.0), Vector3(1.7, 0.03, 1.7), Color(0.70, 0.30, 0.32))
	_box(tool, Vector3(0.0, 0.02, 0.0), Vector3(1.3, 0.03, 1.3), Color(0.92, 0.84, 0.62))
	_box(tool, Vector3(0.0, 0.025, 0.0), Vector3(0.8, 0.03, 0.8), Color(0.36, 0.52, 0.66))
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
