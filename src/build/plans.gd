class_name Plans
extends RefCounted

## Ready-made buildings: a room, a house, a cafe, a shop.
##
## A plan is nothing but a list of ordinary pieces laid out in a fixed pattern,
## so everything that works for a piece works for a plan one piece at a time —
## undo, taking one down, saving, and the other phone being told. The only new
## thing is that one tap puts them all up, if the bag holds enough.
##
## A plan is drawn in its own frame: it reaches away from the child (towards
## -z) and to either side, from the square the child aims at. The front is the
## +z side, where the door is. A quarter turn of the whole plan is all the
## turning there is, which is why every piece lands on the same grid as one
## laid by hand.

const ROOM := &"plan_room"
const HOUSE := &"plan_house"
const CAFE := &"plan_cafe"
const SHOP := &"plan_shop"

const ALL: Array[StringName] = [ROOM, HOUSE, CAFE, SHOP]

static func is_plan(kind: StringName) -> bool:
	return ALL.has(kind)

## How many squares a plan covers, across and deep.
static func size_of(plan: StringName) -> Vector2i:
	if plan == CAFE:
		return Vector2i(3, 2)
	return Vector2i(2, 2)

## The middle of the plan's squares, in its own frame.
static func centre_of(plan: StringName) -> Vector3:
	var size := size_of(plan)
	return Vector3(
		2.0 * float(_first_column(size.x)) + float(size.x - 1), 0.0, -float(size.y - 1)
	)

## The column the plan starts at, so that it sits across the child's view
## rather than reaching off to one side of it.
static func _first_column(width: int) -> int:
	return -(width / 2)

## Where square (column, row) is, in the plan's frame: columns run to the
## right, rows away from the child.
static func _cell(plan: StringName, column: int, row: int) -> Vector3:
	var first := _first_column(size_of(plan).x)
	return Vector3(2.0 * float(first + column), 0.0, -2.0 * float(row))

## The pieces of a plan, in the plan's own frame, in the order they go up:
## walls first, then the floor, then what is on it, then the roof.
##
## Each is a kind, a position (with y counted from the house's floor level),
## a spin, and for a whole roof its size. Walls are in `material`.
static func pieces(plan: StringName, material := HouseParts.DEFAULT_MATERIAL) -> Array[Dictionary]:
	var size := size_of(plan)
	var out: Array[Dictionary] = []
	var front: Array[StringName] = []
	var right: Array[StringName] = []
	var wall := HouseParts.WALL
	match plan:
		ROOM, HOUSE:
			front = [HouseParts.WALL_DOOR, wall]
			right = [HouseParts.WALL_WINDOW, wall]
		CAFE:
			front = [HouseParts.WALL_DOOR, HouseParts.WALL_WIDE, HouseParts.WALL_WIDE]
			right = [wall, wall]
		SHOP:
			front = [HouseParts.WALL_DOOR, HouseParts.WALL_WIDE]
			right = [wall, wall]
	for column in size.x:
		var at := _cell(plan, column, 0) + Vector3(0.0, 0.0, HouseParts.HALF)
		out.append(_piece(front[column], at, 0.0, material))
		var back := _cell(plan, column, size.y - 1) + Vector3(0.0, 0.0, -HouseParts.HALF)
		out.append(_piece(wall, back, 0.0, material))
	for row in size.y:
		var left_at := _cell(plan, 0, row) + Vector3(-HouseParts.HALF, 0.0, 0.0)
		out.append(_piece(wall, left_at, PI * 0.5, material))
		var right_at := _cell(plan, size.x - 1, row) + Vector3(HouseParts.HALF, 0.0, 0.0)
		out.append(_piece(right[row], right_at, PI * 0.5, material))
	for column in size.x:
		for row in size.y:
			out.append(_piece(HouseParts.FLOOR, _cell(plan, column, row), 0.0, material))

	# What goes in it, on the boards.
	match plan:
		HOUSE:
			out.append(_piece(HouseParts.BED, _cell(plan, 1, 1), 0.0, material, true))
		CAFE:
			out.append(_piece(HouseParts.COUNTER, _cell(plan, 0, 1), 0.0, material, true))
			for column: int in [1, 2]:
				out.append(_piece(HouseParts.TABLE, _cell(plan, column, 0), 0.0, material, true))
				out.append(_piece(HouseParts.CHAIR, _cell(plan, column, 0), 0.0, material, true))
			# Outside, beside the door, where it can be read from the path.
			out.append(_piece(HouseParts.SIGN, _cell(plan, 0, -1), 0.0, material))
		SHOP:
			out.append(_piece(HouseParts.COUNTER, _cell(plan, 1, 0), 0.0, material, true))
			out.append(_piece(HouseParts.SHELF, _cell(plan, 0, 1), 0.0, material, true))
			# A shop says it is one from the path, like the cafe.
			out.append(_piece(HouseParts.SIGN, _cell(plan, 0, -1), 0.0, material))
	if plan == HOUSE:
		# The ridge runs the long way, as a whole roof laid by hand does.
		var long_way := size.y >= size.x
		var roof := _piece(
			HouseParts.ROOF_ROOM, centre_of(plan) + Vector3(0.0, HouseParts.STOREY, 0.0),
			0.0 if long_way else PI * 0.5, material
		)
		roof["extent"] = Vector2i(size.x, size.y) if long_way else Vector2i(size.y, size.x)
		out.append(roof)
	return out

static func _piece(
	kind: StringName, at: Vector3, spin: float, material: StringName, on_floor := false
) -> Dictionary:
	var piece := {}
	piece["kind"] = kind
	piece["at"] = at + (Vector3(0.0, HouseParts.FLOOR_TOP, 0.0) if on_floor else Vector3.ZERO)
	piece["spin"] = spin
	piece["extent"] = Vector2i.ONE
	piece["material"] = material if HouseParts.is_wall(kind) else HouseParts.DEFAULT_MATERIAL
	return piece

## What the whole plan costs. A whole roof costs by the squares it covers.
static func cost(plan: StringName) -> Dictionary:
	var total := {}
	for piece in pieces(plan):
		var extent: Vector2i = piece["extent"]
		var each := HouseParts.cost_for(piece["kind"], extent.x * extent.y)
		for item in each:
			total[item] = int(total.get(item, 0)) + int(each[item])
	return total

## What is short of a cost in a bag: the items, and how many more of each.
static func missing(wanted: Dictionary, inventory: Inventory) -> Dictionary:
	var short := {}
	for item in wanted:
		var lacking := int(wanted[item]) - inventory.count(item)
		if lacking > 0:
			short[item] = lacking
	return short

## One mesh of the whole plan, for the ghost.
static func mesh(plan: StringName, material := HouseParts.DEFAULT_MATERIAL) -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for piece in pieces(plan, material):
		var part := HouseParts.mesh_for(piece["kind"], piece["extent"], piece["material"])
		var arrays := part.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var turn := Transform3D(Basis(Vector3.UP, float(piece["spin"])), piece["at"])
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for i in count:
			tool.add_vertex(turn * (vertices[indices[i]] if not indices.is_empty() else vertices[i]))
	return tool.commit()
