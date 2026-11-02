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

## What this child has put up, newest last, for the undo button.
var _history: Array[Dictionary] = []

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
		var record: Dictionary = _history.pop_back()
		if structures.has(record):
			return record
	return {}

## What the piece being aimed would cost, a whole roof by the squares it covers.
func preview_cost() -> Dictionary:
	if HouseParts.is_house_part(selected):
		return HouseParts.cost_for(selected, _extent.x * _extent.y)
	return BuildKinds.cost(selected)

func set_active(enabled: bool) -> void:
	active = enabled
	_ghost.visible = enabled
	_tile.visible = enabled
	if not enabled:
		for marker in _neighbour_markers:
			marker.visible = false
	_last_signature = ""

func select(kind: StringName) -> void:
	var known := BuildKinds.INFO.has(kind) or HouseParts.is_house_part(kind)
	if not known or kind == selected:
		return
	selected = kind
	_refresh_mesh()
	_last_signature = ""

func _refresh_mesh() -> void:
	_ghost_extent = _extent
	if HouseParts.is_house_part(selected):
		_ghost.mesh = HouseParts.mesh_for(selected, _extent)
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
	if _is_house():
		tile_shape = _aim_house(raw, yaw)
	else:
		_target = Vector3(snappedf(raw.x, GRID), 0.0, snappedf(raw.z, GRID))
		_target.y = field.height_at(_target.x, _target.z)
		_spin = snappedf(yaw, TAU / float(TURN_STEPS))

	if _ghost_extent != _extent:
		_refresh_mesh()
	_ghost.transform = Transform3D(Basis(Vector3.UP, _spin), _target)

	# Lifted clear of the ground, or it fights the terrain for the same pixels
	# and shimmers. Turned with the piece and shaped like what it stands on: a
	# strip along an edge for a wall, the whole room for a whole roof.
	_tile.visible = true
	_tile.transform = Transform3D(
		Basis(Vector3.UP, _spin) * Basis.from_scale(tile_shape),
		Vector3(_target.x, _target.y + 0.03, _target.z)
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
func _aim_house(raw: Vector3, yaw: float) -> Vector3:
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
	_target = Vector3(spot.x, 0.0, spot.y)

	var ground := field.height_at(spot.x, spot.y)
	var datum := structures.nearby_datum(_target, HouseParts.MODULE * 2.6)
	_floor_level = ground if is_inf(datum) else datum
	var key := HouseParts.key_of(_target)
	var storey_height := HouseParts.STOREY
	_target.y = _floor_level + float(lift) * storey_height

	var tile := Vector3.ONE
	match selected:
		HouseParts.WALL, HouseParts.WALL_DOOR, HouseParts.WALL_WINDOW, HouseParts.POST:
			# Onto whatever already stands here: the first free storey up.
			var storey := structures.free_storey(HouseParts.layer(selected), key, _floor_level, lift)
			if storey >= HouseParts.MAX_STOREYS:
				_problem = Text.of("why_too_high")
				storey = HouseParts.MAX_STOREYS - 1
			_target.y = _floor_level + float(storey) * storey_height
			tile = Vector3(1.0, 1.0, 0.22) if selected != HouseParts.POST else Vector3.ONE * 0.2
		HouseParts.ROOF, HouseParts.ROOF_PEAK:
			var top := structures.wall_top_round(key)
			_target.y = top if is_finite(top) else _floor_level + float(lift + 1) * storey_height
		HouseParts.ROOF_ROOM:
			tile = _aim_whole_roof(key)
		HouseParts.BED:
			# On the boards, if there are boards.
			if structures.floor_under(key, _target.y):
				_target.y += HouseParts.FLOOR_TOP
	return tile

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

	if not inventory.can_afford(cost):
		_valid = false
		_reason = Text.format("why_need", [_cost_text(cost)])
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
	elif not _problem.is_empty():
		_valid = false
		_reason = _problem
	elif not structures.is_clear(_target, _footprint_of(selected), selected, _spin, _extent):
		_valid = false
		_reason = Text.of("why_no_room")
	elif selected == HouseParts.ROOF_ROOM:
		# Not a refusal: what the whole roof will take out of the bag, which
		# depends on the room and so cannot be printed on its button.
		_reason = _cost_text(cost)

	_material.albedo_color = (
		Color(0.45, 1.0, 0.55, 0.5) if _valid
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
		parts.append("%d %s" % [amount, label if amount == 1 else label + "s"])
	return ", ".join(parts)

## Returns true if something was actually built.
func place() -> bool:
	if not active or not _valid:
		return false
	if not inventory.spend(preview_cost()):
		return false
	_history.append(structures.place(selected, _target, _spin, true, _extent))
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
	if not _is_house():
		return 0
	var counted := HouseParts.storey_of(_target.y - _floor_level)
	if HouseParts.is_roof(selected):
		counted -= 1
	return maxi(counted, 0)
