class_name BuildMode
extends Node3D

## Placing things: the ghost preview, the snapping, and the one rule that a
## piece may not overlap another.
##
## The preview always sits a short way in front of the player rather than under
## a cursor. On a tablet there is no cursor, and asking a six-year-old to aim is
## asking the wrong thing: he walks to where he wants the thing and it is there.

## How far ahead of the player the ghost sits.
const REACH := 3.2

## Indoors, furniture is aimed at the nearest free square of the room instead,
## no further than this from where the child stands. A table 3.2 m ahead is on
## the far side of the wall of any ordinary room, so it took a child pressed
## against that wall to set one down inside.
const ROOM_REACH := 2.0

## Everything snaps to a grid, and rotation to eighths of a turn. Snapping is
## not a constraint here, it is a gift: it means a child's fence comes out
## straight, and a straight fence is the difference between proud and
## disappointed.
##
## House parts use a coarser grid and only four rotations, because a wall at
## 45 degrees cannot meet the wall beside it. Everything else keeps the fine
## grid, where a rock or a sapling wants to go exactly where it was aimed.
const GRID := 1.0
const TURN_STEPS := 8
const HOUSE_TURN_STEPS := 4

## Ground steeper than this refuses a build, because a house on a cliff face
## looks broken and a child cannot tell why.
const MAX_SLOPE := 0.32

signal preview_changed(kind: StringName, valid: bool, reason: String)
## The walls' material was changed, by the button or by anything else.
signal material_changed(material: StringName)

var field: HeightField
var structures: Structures
var inventory: Inventory

var active := false
var selected: StringName = BuildKinds.SAPLING

var _ghost: MeshInstance3D

## A flat tile on the ground under the ghost, and an outline around each piece
## the new one will touch.
##
## The ghost alone was not enough. A translucent wall floating ahead of the
## player says what will be built but not where: a child cannot see which square
## of ground it lands on, nor that it is about to join the wall he built a
## moment ago. The tile answers the first, the outlines answer the second, and
## together they turn "put it roughly there and hope" into something he can aim.
var _tile: MeshInstance3D
var _tile_material: StandardMaterial3D
var _neighbour_markers: Array[MeshInstance3D] = []
var _material: StandardMaterial3D
var _target := Vector3.ZERO
var _spin := 0.0
var _valid := false
var _reason := ""
var _last_signature := ""

## The storey a house piece starts from, chosen with the up and down buttons.
##
## A fallback, not the way up: a wall tapped onto a wall goes on top of it by
## itself, and a roof finds the top of the walls round it. This is for what
## cannot be found by looking — a floor laid upstairs, a bed on it.
var lift := 0

## How many squares the piece covers, across and along: only a whole roof
## covers more than one.
var _extent := Vector2i.ONE
var _ghost_extent := Vector2i.ZERO
## The level of the house's ground floor where the ghost is aimed.
var _floor_level := 0.0
## Why a house piece cannot go where it is aimed, found while aiming — a whole
## roof with no room under it, a wall stack already as tall as a house goes.
var _problem := ""

## What this child has put up, newest last, for the undo button: one entry for
## each tap, which is one piece, or every piece of a plan.
var _history: Array[Array] = []

## What the last tap put up.
var _placed: Array[Dictionary] = []

## What new walls are made of, chosen with the button in the walls group.
var material: StringName = HouseParts.DEFAULT_MATERIAL

## Where the trees are: given a point and a reach, the positions of the trees
## standing within it. Set by the game, which owns the forest, through
## set_tree_finder(); with nothing set there are no trees to be in the way.
var tree_finder := Callable()

## The pieces of the plan being aimed, in the world as it would be built.
var _plan_pieces: Array[Dictionary] = []
## What was found wrong with the plan, and for which aim and which valley —
## asked of every piece, so only asked again when something has changed.
var _plan_check_key := ""
var _plan_check_reason := ""
## Which of the plan's pieces (by place in Plans.pieces) cannot be built where
## it is aimed, and the ghost of those, drawn red.
var _plan_blocked: Array[int] = []
var _plan_ghost_key := ""
var _blocked_ghost: MeshInstance3D
var _blocked_material: StandardMaterial3D

## Everything is built here rather than in _ready, because add_child() defers
## _ready until the tree next processes — so a caller that adds this node and
## then immediately calls set_active() would find no ghost to show. That has
## now cost us three separate bugs (pickups with no mesh, balls placed 56 m
## away, this one). Nodes that a caller may use on the line after add_child
## build their resources in _init.
func _init(height_field: HeightField, structure_store: Structures, player_inventory: Inventory) -> void:
	field = height_field
	structures = structure_store
	inventory = player_inventory

	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# The ghost draws through terrain on purpose: half a preview hidden behind a
	# tuft of grass is worse than one that floats.
	_material.no_depth_test = true
	_material.albedo_color = Color(0.45, 1.0, 0.55, 0.5)

	_ghost = MeshInstance3D.new()
	_ghost.material_override = _material
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.visible = false
	add_child(_ghost)

	# The pieces of a plan that cannot go where it is aimed, drawn red in the
	# same place as the rest of the ghost, which stays green.
	_blocked_material = _material.duplicate() as StandardMaterial3D
	_blocked_material.albedo_color = Color(1.0, 0.42, 0.38, 0.6)
	_blocked_ghost = MeshInstance3D.new()
	_blocked_ghost.material_override = _blocked_material
	_blocked_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blocked_ghost.visible = false
	add_child(_blocked_ghost)

	# The ground tile answers "where exactly does this land?". It is a flat
	# square one module across, so the scale applied when previewing is simply
	# the piece's footprint in modules.
	_tile_material = StandardMaterial3D.new()
	_tile_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tile_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_tile_material.no_depth_test = true
	_tile_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_tile_material.albedo_color = Color(0.45, 1.0, 0.55, 0.28)

	var quad := PlaneMesh.new()
	quad.size = Vector2(HouseParts.MODULE, HouseParts.MODULE)
	_tile = MeshInstance3D.new()
	_tile.mesh = quad
	_tile.material_override = _tile_material
	_tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tile.visible = false
	add_child(_tile)

	# Four outlines, one per neighbouring square, shown only where something
	# already stands. Brighter and warmer than the tile so "you will join this"
	# reads differently from "you will stand here".
	var outline_material := StandardMaterial3D.new()
	outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outline_material.no_depth_test = true
	outline_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	outline_material.albedo_color = Color(1.0, 0.86, 0.42, 0.42)

	for _i in 4:
		var marker := MeshInstance3D.new()
		marker.mesh = quad
		marker.material_override = outline_material
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marker.visible = false
		add_child(marker)
		_neighbour_markers.append(marker)

	_refresh_mesh()

## Where the next piece would land, and how it would be turned. Read by the
## session so that a piece built here can be described to the other machine.
func preview_position() -> Vector3:
	return _target

func preview_spin() -> float:
	return _spin

## How many squares the next piece covers, across and along its ridge — sent
## with a whole roof so the other phone builds one the same size.
func preview_extent() -> Vector2i:
	return _extent

## The up and down buttons.
func change_lift(step: int) -> void:
	lift = clampi(lift + step, 0, HouseParts.MAX_STOREYS - 1)
	_last_signature = ""

## The newest piece this child put up that is still standing, taken off the
## list; or an empty record when there is nothing left to take back. The
## caller takes it down and refunds it, the same way a tap does.
func take_last() -> Dictionary:
	while not _history.is_empty():
		var group: Array = _history.back()
		while not group.is_empty():
			var record: Dictionary = group.pop_back()
			if structures.has(record):
				return record
		_history.pop_back()
	return {}

## Everything the newest tap put up that is still standing, taken off the
## list: one piece, or all of a plan. Undo takes a plan back in one go, because
## a child who tapped once expects one tap to take it away.
func take_last_group() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	while not _history.is_empty():
		var group: Array = _history.pop_back()
		for record: Dictionary in group:
			if structures.has(record):
				found.append(record)
		if not found.is_empty():
			break
	return found

## How many taps the undo list keeps across a save. A plan is one tap, so a
## handful is a whole afternoon's building.
const HISTORY_KEPT := 8

## The last few taps, as what can be written down: each piece by its kind, its
## square and its storey, which is enough to find it again in a loaded valley.
func history_to_data() -> Array:
	var data: Array = []
	for group: Array in _history:
		var entries: Array = []
		for record: Dictionary in group:
			if not structures.has(record):
				continue
			var at: Vector3 = record["position"]
			entries.append({
				"kind": String(record["kind"]), "x": at.x, "z": at.z,
				"storey": structures.storey_of(record),
			})
		if not entries.is_empty():
			data.append(entries)
	return data.slice(maxi(data.size() - HISTORY_KEPT, 0))

## Take the undo list back from a save, once the valley has been loaded. A
## piece that is no longer there — taken down, felled, or moved by a rule made
## since — is dropped, and so is a tap with nothing left of it.
func restore_history(data: Variant) -> void:
	_history.clear()
	if typeof(data) != TYPE_ARRAY:
		return
	var used: Array[Dictionary] = []
	for entries: Variant in data:
		if typeof(entries) != TYPE_ARRAY:
			continue
		var group: Array = []
		for entry: Variant in entries:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var found := structures.find_own(
				StringName(str(entry.get("kind", ""))),
				float(entry.get("x", INF)), float(entry.get("z", INF)),
				int(entry.get("storey", 0))
			)
			if found.is_empty() or used.has(found):
				continue
			used.append(found)
			group.append(found)
		if not group.is_empty():
			_history.append(group)
	while _history.size() > HISTORY_KEPT:
		_history.pop_front()

## The pieces the last tap put up, so the game can tell the other phone about
## each. Empty after a tap that built nothing.
func just_placed() -> Array[Dictionary]:
	return _placed

## What the piece being aimed would cost, a whole roof by the squares it covers
## and a plan by every piece in it.
func preview_cost() -> Dictionary:
	if Plans.is_plan(selected):
		return Plans.cost(selected)
	if HouseParts.is_house_part(selected):
		return HouseParts.cost_for(selected, _extent.x * _extent.y)
	return BuildKinds.cost(selected)

func set_active(enabled: bool) -> void:
	active = enabled
	_ghost.visible = enabled
	_blocked_ghost.visible = enabled and _blocked_ghost.mesh != null and Plans.is_plan(selected)
	_tile.visible = enabled
	if not enabled:
		for marker in _neighbour_markers:
			marker.visible = false
	_last_signature = ""

## Say what is being aimed at again, to an interface that is new and has not
## heard it: the preview only speaks when it changes.
func say_again() -> void:
	_last_signature = ""

func select(kind: StringName) -> void:
	var known := BuildKinds.INFO.has(kind) or HouseParts.is_house_part(kind) or Plans.is_plan(kind)
	if not known or kind == selected:
		return
	selected = kind
	_refresh_mesh()
	_last_signature = ""

## The next material for walls, round and round. Everything laid after it, and
## the ghost, is in the new one; what is already standing is not touched.
func cycle_material() -> void:
	var next := (HouseParts.MATERIALS.find(material) + 1) % HouseParts.MATERIALS.size()
	set_material(HouseParts.MATERIALS[next])

func set_material(wanted: StringName) -> void:
	if not HouseParts.MATERIALS.has(wanted) or wanted == material:
		return
	material = wanted
	_refresh_mesh()
	_last_signature = ""
	material_changed.emit(material)

func _refresh_mesh() -> void:
	_ghost_extent = _extent
	_blocked_ghost.mesh = null
	_blocked_ghost.visible = false
	_plan_ghost_key = ""
	if Plans.is_plan(selected):
		_ghost.mesh = Plans.mesh(selected, material)
		return
	if HouseParts.is_house_part(selected):
		_ghost.mesh = HouseParts.mesh_for(selected, _extent, material)
		return
	# The ghost of something that grows shows what it will become, not the sprout
	# it starts as: a child is choosing a tree, not a twig.
	var stage := BuildKinds.GROWTH_STAGES - 1 if BuildKinds.grows(selected) else 0
	_ghost.mesh = BuildKinds.build_mesh(selected, stage)

## A house part or an ordinary object — the two follow different rules and this
## is the one place that has to know which is which.
func _is_house() -> bool:
	return HouseParts.is_house_part(selected)

func _footprint_of(kind: StringName) -> float:
	if Plans.is_plan(kind):
		return HouseParts.MODULE
	return HouseParts.footprint(kind) if HouseParts.is_house_part(kind) else BuildKinds.footprint(kind)

func _label_of(kind: StringName) -> String:
	return HouseParts.label(kind) if HouseParts.is_house_part(kind) else BuildKinds.label(kind)

## Driven from wherever the player is, once per frame.
func aim(player_position: Vector3, yaw: float) -> void:
	if not active:
		return

	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var raw := player_position + forward * REACH

	_extent = Vector2i.ONE
	_problem = ""
	var tile_shape := Vector3.ONE * (_footprint_of(selected) / HouseParts.MODULE)
	if Plans.is_plan(selected):
		tile_shape = _aim_plan(raw, yaw)
	elif _is_house():
		tile_shape = _aim_house(raw, yaw, player_position)
	else:
		_target = Vector3(snappedf(raw.x, GRID), 0.0, snappedf(raw.z, GRID))
		_target.y = field.height_at(_target.x, _target.z)
		_spin = snappedf(yaw, TAU / float(TURN_STEPS))

	if _ghost_extent != _extent:
		_refresh_mesh()
	_ghost.transform = Transform3D(Basis(Vector3.UP, _spin), _target)
	_blocked_ghost.transform = _ghost.transform

	# Lifted clear of the ground, or it fights the terrain for the same pixels
	# and shimmers. Turned with the piece and shaped like what it stands on: a
	# strip along an edge for a wall, the whole room for a whole roof.
	_tile.visible = true
	var tile_at := _target
	if Plans.is_plan(selected):
		# The ground tile covers the whole plan, which does not stand on its
		# aimed square alone.
		tile_at += Basis(Vector3.UP, _spin) * Plans.centre_of(selected)
	_tile.transform = Transform3D(
		Basis(Vector3.UP, _spin) * Basis.from_scale(tile_shape),
		Vector3(tile_at.x, _target.y + 0.03, tile_at.z)
	)

	_show_neighbours()
	_evaluate()

## Where a house piece goes, and how high. Returns the shape of the ground
## tile under it, in modules.
##
## The height counts from the level of whatever is already built nearby, not
## the ground under this particular square. Following the ground meant three
## walls in a row sat at 1.81, 1.64 and 1.35 metres: a house that leans
## downhill, with the roof over one end of it. A building has one floor level,
## so the first piece sets it and the rest join it.
##
## Which storey is no longer decided by how high the child is standing. That
## meant climbing onto the walls to put a roof on them — which a six-year-old
## cannot do, so no house was ever finished. Now a wall tapped onto a wall goes
## on top of it, a roof goes on top of the walls round it, and the up and down
## buttons are there for the rest.
func _aim_house(raw: Vector3, yaw: float, player_position: Vector3) -> Vector3:
	# A quarter turn, counted. The wall runs across the way the child is
	# looking, so it appears straight ahead of them, face on.
	var turn := TAU / float(HOUSE_TURN_STEPS)
	var quarter := posmod(roundi(yaw / turn), HOUSE_TURN_STEPS)
	_spin = float(quarter) * turn
	var spot: Vector2
	match HouseParts.seat(selected):
		HouseParts.Seat.EDGE:
			spot = HouseParts.snap_edge(raw.x, raw.z, quarter % 2 == 0)
		HouseParts.Seat.CORNER:
			spot = HouseParts.snap_corner(raw.x, raw.z)
		_:
			spot = HouseParts.snap_cell(raw.x, raw.z)
			if HouseParts.is_furniture(selected):
				spot = _square_in_room(player_position, yaw, spot)
	_target = Vector3(spot.x, 0.0, spot.y)

	var ground := field.height_at(spot.x, spot.y)
	var datum := structures.nearby_datum(_target, HouseParts.MODULE * 2.6)
	_floor_level = ground if is_inf(datum) else datum
	var key := HouseParts.key_of(_target)
	var storey_height := HouseParts.STOREY
	_target.y = _floor_level + float(lift) * storey_height

	var tile := Vector3.ONE
	if HouseParts.is_wall(selected) or selected == HouseParts.POST:
		# Onto whatever already stands here: the first free storey up.
		var storey := structures.free_storey(HouseParts.layer(selected), key, _floor_level, lift)
		if storey >= HouseParts.MAX_STOREYS:
			_problem = Text.of("why_too_high")
			storey = HouseParts.MAX_STOREYS - 1
		_target.y = _floor_level + float(storey) * storey_height
		return Vector3(1.0, 1.0, 0.22) if selected != HouseParts.POST else Vector3.ONE * 0.2
	match selected:
		HouseParts.ROOF, HouseParts.ROOF_PEAK, HouseParts.ROOF_FLAT, HouseParts.CHIMNEY:
			var top := structures.wall_top_round(key)
			_target.y = top if is_finite(top) else _floor_level + float(lift + 1) * storey_height
		HouseParts.ROOF_ROOM:
			tile = _aim_whole_roof(key)
		HouseParts.SIGN:
			pass
		_:
			# Furniture, on the boards if there are boards.
			if structures.floor_under(key, _target.y):
				_target.y += HouseParts.FLOOR_TOP
	return tile

## Where furniture goes when the child is standing in a room: the nearest free
## square of that room in front of them, within ROOM_REACH of where they stand
## (measured to the square's near edge, since nobody stands on its exact
## middle). Anywhere else, or with no free square ahead, it is `outside`, the
## usual place REACH metres on.
func _square_in_room(player_position: Vector3, yaw: float, outside: Vector2) -> Vector2:
	var here := HouseParts.snap_cell(player_position.x, player_position.z)
	var here_key := HouseParts.key_of(Vector3(here.x, 0.0, here.y))
	var room := structures.enclosed_room(here_key)
	if room.is_empty():
		return outside
	var datum := structures.nearby_datum(player_position, HouseParts.MODULE * 2.6)
	var level := field.height_at(here.x, here.y) if is_inf(datum) else datum
	var layer := HouseParts.layer(selected)
	var feet := Vector2(player_position.x, player_position.z)
	var ahead := Vector2(-sin(yaw), -cos(yaw))
	var best := outside
	var best_distance := INF
	for key: Vector2i in room["cells"]:
		if key == here_key:
			continue
		var centre := Vector2(float(key.x), float(key.y)) * HouseParts.HALF
		var to_centre := centre - feet
		# In front, not beside or behind: within about sixty degrees of the way
		# the child faces.
		if to_centre.normalized().dot(ahead) < 0.5:
			continue
		var gap := Vector2(
			maxf(absf(to_centre.x) - HouseParts.HALF, 0.0),
			maxf(absf(to_centre.y) - HouseParts.HALF, 0.0)
		).length()
		if gap > ROOM_REACH or to_centre.length() >= best_distance:
			continue
		if structures.free_storey(layer, key, level, lift) != lift:
			continue
		best = centre
		best_distance = to_centre.length()
	return best

## Where a plan goes: the square aimed at is its first, and it reaches away
## from the child and across their view, turned a quarter at a time with the
## way they face. Every piece is found here, in the world, so the ghost, the
## refusals and the building all work from the same list.
func _aim_plan(raw: Vector3, yaw: float) -> Vector3:
	var turn := TAU / float(HOUSE_TURN_STEPS)
	var quarter := posmod(roundi(yaw / turn), HOUSE_TURN_STEPS)
	_spin = float(quarter) * turn
	var spot := HouseParts.snap_cell(raw.x, raw.z)
	_target = Vector3(spot.x, 0.0, spot.y)
	var ground := field.height_at(spot.x, spot.y)
	var datum := structures.nearby_datum(_target, HouseParts.MODULE * 2.6)
	_floor_level = ground if is_inf(datum) else datum
	_target.y = _floor_level + float(lift) * HouseParts.STOREY

	var around := Basis(Vector3.UP, _spin)
	_plan_pieces.clear()
	for piece in Plans.pieces(selected, material):
		var at: Vector3 = _target + around * (piece["at"] as Vector3)
		var placed := {}
		placed["kind"] = piece["kind"]
		# Quarter turns land on whole half-modules: the rounding only takes
		# out the dust of turning by a multiple of a right angle.
		placed["position"] = Vector3(
			snappedf(at.x, HouseParts.HALF), at.y, snappedf(at.z, HouseParts.HALF)
		)
		placed["spin"] = fposmod(float(piece["spin"]) + _spin, TAU)
		placed["extent"] = piece["extent"]
		placed["material"] = piece["material"]
		_plan_pieces.append(placed)
	var size := Plans.size_of(selected)
	return Vector3(float(size.x), 1.0, float(size.y))

## The whole roof: find the room the child is aiming into and cover it.
func _aim_whole_roof(key: Vector2i) -> Vector3:
	var room := structures.enclosed_room(key)
	if room.is_empty():
		_problem = Text.of("why_no_walls")
		_target.y = _floor_level + float(lift + 1) * HouseParts.STOREY
		return Vector3.ONE
	var span: Vector2i = room["span"]
	if not bool(room["rectangle"]):
		_problem = Text.of("why_not_box")
	elif not bool(room["level"]):
		_problem = Text.of("why_uneven")
	var low: Vector2i = room["low"]
	var high: Vector2i = room["high"]
	_target.x = float(low.x + high.x) * 0.5 * HouseParts.HALF
	_target.z = float(low.y + high.y) * 0.5 * HouseParts.HALF
	_target.y = float(room["top"])
	# The ridge runs the long way, which is how a house is roofed: the gables
	# on the short ends, and the slopes as gentle as the room allows.
	if span.y >= span.x:
		_spin = 0.0
		_extent = Vector2i(span.x, span.y)
	else:
		_spin = PI * 0.5
		_extent = Vector2i(span.y, span.x)
	return Vector3(float(_extent.x), 1.0, float(_extent.y))

## Outline whatever the new piece will stand against, so a child can see it is
## about to join a wall rather than land beside one.
func _show_neighbours() -> void:
	for marker in _neighbour_markers:
		marker.visible = false
	if not _is_house():
		return

	# The pieces of the same layer that the new one meets, on its storey: the
	# walls sharing an end with a wall, the floors beside a floor. A whole roof
	# shows its room with its tile instead.
	if selected == HouseParts.ROOF_ROOM:
		return
	var layer := HouseParts.layer(selected)
	var key := HouseParts.key_of(_target)
	var shown := 0
	for record in structures.house_pieces_near(_target, HouseParts.MODULE * 1.05):
		if shown >= _neighbour_markers.size():
			break
		var kind: StringName = record["kind"]
		var at: Vector3 = record["position"]
		if HouseParts.layer(kind) != layer or HouseParts.key_of(at) == key:
			continue
		if absf(at.y - _target.y) > HouseParts.STOREY * 0.5:
			continue
		var shape := Vector3(1.0, 1.0, 0.22) if layer == &"wall" else Vector3.ONE
		var marker := _neighbour_markers[shown]
		marker.transform = Transform3D(
			Basis(Vector3.UP, float(record["spin"])) * Basis.from_scale(shape),
			Vector3(at.x, at.y + 0.05, at.z)
		)
		marker.visible = true
		shown += 1

## Would anything go up here? Asked by the checks: the rule about wet ground is
## easy to get wrong in a valley where the water is not all at one height, and
## the way it was wrong let a ladder stand in the middle of a lake.
func would_build_at(at: Vector3) -> bool:
	if field.is_pond(at.x, at.z):
		return false
	if at.y < field.water_level_at(at.x, at.z) + 0.15:
		return false
	if field.steepness_at(at.x, at.z) > MAX_SLOPE:
		return false
	return not PlaceSpec.reserved(at.x, at.z, field.camp_centre())

func _evaluate() -> void:
	var cost := preview_cost()
	_valid = true
	_reason = ""
	var affordable := inventory.can_afford(cost)
	var is_plan := Plans.is_plan(selected)
	# Asked whether the bag pays or not, so the ghost can always show which of
	# its pieces are blocked (answered once for each aim, not once a frame).
	var refusal := _plan_refusal() if is_plan else ""

	if not affordable:
		_valid = false
		if is_plan:
			# A whole building is a lot to read as a bill: say what is short.
			_reason = Text.format("why_missing", [_cost_text(Plans.missing(cost, inventory))])
		else:
			_reason = Text.format("why_need", [_cost_text(cost)])
	elif is_plan:
		if refusal.is_empty():
			_reason = _cost_text(cost)
		else:
			_valid = false
			_reason = refusal
	elif field.is_pond(_target.x, _target.z):
		# A pond, whatever height its water stands at. The test below compares
		# against the world's waterline, and a raised pond's bed is well above
		# that — so a ladder could be stood in the middle of a lake, which is
		# how it was found.
		_valid = false
		_reason = Text.of("why_wet")
	elif _target.y < field.water_level_at(_target.x, _target.z) + 0.15:
		_valid = false
		_reason = Text.of("why_wet")
	elif field.steepness_at(_target.x, _target.z) > MAX_SLOPE:
		_valid = false
		_reason = Text.of("why_steep")
	elif _kept_ground(_target.x, _target.z):
		# The playground, the pool and the café are somebody else's work. A
		# sapling planted beside the trampoline became a tree standing in it.
		_valid = false
		_reason = Text.of("why_reserved")
	elif not _trees_in_the_way(selected, _target, _spin, _extent).is_empty():
		# A trunk in the middle of a room, or a fence, a fire or a sapling
		# standing in one. The axe clears it, or the piece can go a step to
		# one side; either way the child is told.
		_valid = false
		_reason = Text.of("why_tree")
	elif not _problem.is_empty():
		_valid = false
		_reason = _problem
	elif _is_house() and structures.stairs_blocked_above(selected, _target, _spin):
		# Stairs with a floor over them, or a floor over where stairs go.
		_valid = false
		_reason = Text.of("why_headroom")
	elif not structures.is_clear(_target, _footprint_of(selected), selected, _spin, _extent):
		_valid = false
		_reason = Text.of("why_no_room")
	elif selected == HouseParts.ROOF_ROOM:
		# Not a refusal: what the whole roof will take out of the bag, which
		# depends on the room and so cannot be printed on its button.
		_reason = _cost_text(cost)

	# A plan with some pieces blocked is green where it can go and red where it
	# cannot; one the bag cannot pay for is red all over.
	var split := is_plan and affordable and not _plan_blocked.is_empty()
	if is_plan:
		_show_plan_ghost(split)
	_material.albedo_color = (
		Color(0.45, 1.0, 0.55, 0.5) if _valid or split
		else Color(1.0, 0.42, 0.38, 0.45)
	)
	_tile_material.albedo_color = (
		Color(0.45, 1.0, 0.55, 0.28) if _valid
		else Color(1.0, 0.42, 0.38, 0.24)
	)

	# Only announce a change, so the interface is not rebuilt sixty times a
	# second while the player stands still.
	var signature := "%s|%s|%s|%.2f" % [selected, _valid, _reason, _target.y]
	if signature != _last_signature:
		_last_signature = signature
		preview_changed.emit(selected, _valid, _reason)

## What stops a plan being built where it is aimed, in a child's words, or
## nothing. The same questions a single piece is asked, of every piece in it:
## the first one that fails is the one said.
func _plan_refusal() -> String:
	var centre := _target + Basis(Vector3.UP, _spin) * Plans.centre_of(selected)
	var size := Plans.size_of(selected)
	var trees := _trees_round(centre, float(maxi(size.x, size.y)) * HouseParts.MODULE + 2.0)
	var key := "%s|%s|%s|%s|%d|%d" % [
		selected, _target, _spin, material, structures.revision, trees.size()
	]
	if key == _plan_check_key:
		return _plan_check_reason
	_plan_check_key = key
	_plan_check_reason = _find_plan_refusal(trees)
	return _plan_check_reason

## How far the ground under a plan may lie from the level the plan is built at:
## past it the walls hang over a hollow or the boards are buried, and no piece
## of the ground is steep enough to say so on its own.
const PLAN_LEEWAY := 0.7

## The words for what can be wrong with one piece of a plan, most serious first:
## the line said is the most serious of all the pieces'.
const PLAN_WHY := ["why_wet", "why_steep", "why_reserved", "why_tree", "why_no_room"]

## Find which pieces cannot go up where the plan is aimed (kept in
## _plan_blocked, for the ghost) and say why in the most serious one's words.
func _find_plan_refusal(trees: Array[Vector3]) -> String:
	_plan_blocked = []
	var worst := PLAN_WHY.size()
	for index in _plan_pieces.size():
		var piece := _plan_pieces[index]
		var problem := _piece_problem(piece, trees)
		if problem < 0:
			continue
		_plan_blocked.append(index)
		worst = mini(worst, problem)
	return "" if worst >= PLAN_WHY.size() else Text.of(PLAN_WHY[worst])

## What stops one piece of a plan, as a place in PLAN_WHY, or -1 for nothing.
## The questions a single piece is asked, in the order they are said.
func _piece_problem(piece: Dictionary, trees: Array[Vector3]) -> int:
	var at: Vector3 = piece["position"]
	if field.is_pond(at.x, at.z) or at.y < field.water_level_at(at.x, at.z) + 0.15:
		return 0
	var ground := field.height_at(at.x, at.z)
	if field.steepness_at(at.x, at.z) > MAX_SLOPE or absf(ground - _floor_level) > PLAN_LEEWAY:
		return 1
	if _kept_ground(at.x, at.z):
		return 2
	for tree in trees:
		if _blocks(piece["kind"], at, float(piece["spin"]), piece["extent"], tree):
			return 3
	if not structures.is_clear(
		at, HouseParts.MODULE, piece["kind"], float(piece["spin"]), piece["extent"]
	):
		return 4
	return -1

## Draw the plan's ghost: whole when it can all go up, or when the bag cannot
## pay for it (red all over, in the colour of the material), and in two when
## only some of it is blocked — the pieces that can go in green, the ones that
## cannot in red, in the places they would stand.
func _show_plan_ghost(split: bool) -> void:
	var blocked: Array[int] = []
	if split:
		blocked = _plan_blocked
	var key := "%s|%s|%s" % [selected, material, blocked]
	if key == _plan_ghost_key:
		return
	_plan_ghost_key = key
	if blocked.is_empty():
		_ghost.mesh = Plans.mesh(selected, material)
		_blocked_ghost.mesh = null
		_blocked_ghost.visible = false
		return
	var kept: Array[int] = []
	for index in _plan_pieces.size():
		if not blocked.has(index):
			kept.append(index)
	_ghost.mesh = Plans.mesh(selected, material, kept, false) if not kept.is_empty() else null
	_blocked_ghost.mesh = Plans.mesh(selected, material, blocked, false)
	_blocked_ghost.visible = active

## The trees standing within reach of a point, or none when the game has not
## said where its trees are.
func _trees_round(at: Vector3, reach: float) -> Array[Vector3]:
	# Asked every frame the ghost is on show, and a forest does not move: the
	# last answer for the same place stands for a moment.
	var now := Time.get_ticks_msec()
	if _trees_for == [at, reach] and now - _trees_asked < 400:
		return _trees_found
	var found: Array[Vector3] = []
	if tree_finder.is_valid():
		for tree: Vector3 in tree_finder.call(at, reach):
			found.append(tree)
	_trees_for = [at, reach]
	_trees_asked = now
	_trees_found = found
	return found

var _trees_for := []
var _trees_asked := -1000
var _trees_found: Array[Vector3] = []

func set_tree_finder(finder: Callable) -> void:
	tree_finder = finder
	_trees_for = []
	_plan_check_key = ""

## The trees a piece would be built on top of.
func _trees_in_the_way(kind: StringName, at: Vector3, spin: float, extent: Vector2i) -> Array[Vector3]:
	var blocking: Array[Vector3] = []
	var span := HouseParts.world_span(spin, extent)
	var reach := float(maxi(span.x, span.y)) * HouseParts.MODULE + 1.0
	for tree in _trees_round(at, reach):
		if _blocks(kind, at, spin, extent, tree):
			blocking.append(tree)
	return blocking

## Whether a trunk stands inside what a piece takes up. A roof is above
## anything on the ground, and a rug is flat enough to lie over a root.
func _blocks(kind: StringName, at: Vector3, spin: float, extent: Vector2i, tree: Vector3) -> bool:
	if HouseParts.is_roof(kind) or kind == HouseParts.RUG:
		return false
	var half := Vector2(HouseParts.HALF, HouseParts.HALF)
	if not HouseParts.is_house_part(kind):
		# A path is stones laid flat, which a root does not mind; everything
		# else takes up the ground its footprint says.
		if kind == BuildKinds.PATH:
			return false
		half = Vector2.ONE * BuildKinds.footprint(kind) * 0.5
	elif HouseParts.seat(kind) == HouseParts.Seat.EDGE:
		half = Vector2(HouseParts.HALF, HouseParts.WALL_THICKNESS * 0.5)
	elif HouseParts.seat(kind) == HouseParts.Seat.CORNER:
		half = Vector2(0.1, 0.1)
	var local := Basis(Vector3.UP, spin).inverse() * Vector3(tree.x - at.x, 0.0, tree.z - at.z)
	var trunk := TreeCollision.TRUNK_RADIUS
	return absf(local.x) < half.x + trunk and absf(local.z) < half.y + trunk

## How far nothing may be built from the crossing and the signs. The rule
## itself lives in KeepOut, because the builder and the loaded valley have to
## agree about it — see the note there.
const KEEP_BACK := KeepOut.KEEP_BACK

## Ground that belongs to something else.
func _kept_ground(x: float, z: float) -> bool:
	return KeepOut.kept(
		x, z, field.camp_centre(), field.river_centre_x(BridgeSpec.CENTRE_Z)
	)

func _cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for kind in cost:
		var amount := int(cost[kind])
		var label := ItemKinds.label(kind)
		# A ten-year-old reads this line, and "need 3 stick" reads as a typo
		# rather than as a requirement.
		#
		# An s on the end is only English's plural. On "палка" it made "палкаs"
		# with a Latin letter on a Russian word, and on "pomme de pin" "pomme
		# de pins": Russian has two plurals more and French its own. Those
		# say the number after the name, as the shop does.
		if Text.language() == Text.EN:
			parts.append("%d %s" % [amount, label if amount == 1 else label + "s"])
		else:
			parts.append("%s ×%d" % [label, amount])
	return ", ".join(parts)

## Returns true if something was actually built.
func place() -> bool:
	_placed = []
	if not active or not _valid:
		return false
	if not inventory.spend(preview_cost()):
		return false
	var group: Array[Dictionary] = []
	if Plans.is_plan(selected):
		# Every piece an ordinary record, in the order they go up.
		for piece in _plan_pieces:
			group.append(structures.place(
				piece["kind"], piece["position"], float(piece["spin"]), true,
				piece["extent"], piece["material"]
			))
	else:
		group.append(structures.place(
			selected, _target, _spin, true, _extent,
			material if HouseParts.is_wall(selected) else HouseParts.DEFAULT_MATERIAL
		))
	_history.append(group)
	_placed = group
	# Re-evaluate immediately: the same spot is now occupied and the resources
	# are spent, and the ghost has to say so before the next tap.
	_evaluate()
	return true

func target() -> Vector3:
	return _target


## Which storey the ghost is on, counting from zero at ground level.
##
## Shown beside the up and down buttons, because the storey a piece lands on is
## the one thing about it that is hard to judge by eye from the ground. A roof
## counts as the storey of the walls it covers.
func storey() -> int:
	if not _is_house() and not Plans.is_plan(selected):
		return 0
	var counted := HouseParts.storey_of(_target.y - _floor_level)
	if HouseParts.is_roof(selected):
		counted -= 1
	return maxi(counted, 0)
