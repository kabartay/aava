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
	if HouseParts.is_house_part(selected):
		_ghost.mesh = HouseParts.build_mesh(selected)
		return
	# The ghost of something that grows shows what it will become, not the sprout
	# it starts as: a child is choosing a tree, not a twig.
	var stage := BuildKinds.GROWTH_STAGES - 1 if BuildKinds.grows(selected) else 0
	_ghost.mesh = BuildKinds.build_mesh(selected, stage)

## A house part or an ordinary object — the two follow different rules and this
## is the one place that has to know which is which.
func _is_house() -> bool:
	return HouseParts.is_house_part(selected)

func _cost_of(kind: StringName) -> Dictionary:
	return HouseParts.cost(kind) if HouseParts.is_house_part(kind) else BuildKinds.cost(kind)

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

	var grid := HouseParts.MODULE if _is_house() else GRID
	_target = Vector3(snappedf(raw.x, grid), 0.0, snappedf(raw.z, grid))

	var ground := field.height_at(_target.x, _target.z)
	if _is_house():
		# A house part sits on a storey, not on the ground.
		#
		# Which storey is decided by how high the player is standing — walk
		# upstairs and you build upstairs, which needs no control and is the
		# only scheme a child works out unaided.
		#
		# The height it counts from is the level of whatever is already built
		# nearby, not the ground under this particular square. Following the
		# ground meant three walls in a row sat at 1.81, 1.64 and 1.35 metres:
		# a house that leans downhill, with the roof over one end of it. A
		# building has one floor level, so the first piece sets it and the rest
		# join it.
		var datum := structures.nearby_datum(_target, HouseParts.MODULE * 2.6)
		var floor_level := ground if is_inf(datum) else datum
		var above := maxf(player_position.y - floor_level, 0.0)
		_target.y = floor_level + HouseParts.snap_height(above)
	else:
		_target.y = ground

	var steps := HOUSE_TURN_STEPS if _is_house() else TURN_STEPS
	_spin = snappedf(yaw, TAU / float(steps))

	_ghost.transform = Transform3D(Basis(Vector3.UP, _spin), _target)

	# Lifted clear of the ground, or it fights the terrain for the same pixels
	# and shimmers.
	_tile.visible = true
	_tile.position = Vector3(_target.x, _target.y + 0.03, _target.z)
	_tile.scale = Vector3.ONE * (_footprint_of(selected) / HouseParts.MODULE)

	_show_neighbours()
	_evaluate()

## Outline whatever the new piece will stand against, so a child can see it is
## about to join a wall rather than land beside one.
func _show_neighbours() -> void:
	for marker in _neighbour_markers:
		marker.visible = false
	if not _is_house():
		return

	var module := HouseParts.MODULE
	var offsets: Array[Vector3] = [
		Vector3(module, 0.0, 0.0), Vector3(-module, 0.0, 0.0),
		Vector3(0.0, 0.0, module), Vector3(0.0, 0.0, -module),
	]
	for i in offsets.size():
		var beside := _target + offsets[i]
		# is_clear is false where something already stands, which is exactly
		# the question being asked: is there a neighbour here?
		if structures.is_clear(beside, _footprint_of(selected)):
			continue
		var marker := _neighbour_markers[i]
		marker.position = Vector3(beside.x, beside.y + 0.05, beside.z)
		marker.visible = true

func _evaluate() -> void:
	var cost := _cost_of(selected)
	_valid = true
	_reason = ""

	if not inventory.can_afford(cost):
		_valid = false
		_reason = Text.format("why_need", [_cost_text(cost)])
	elif _target.y < HeightField.WATER_LEVEL + 0.15:
		_valid = false
		_reason = Text.of("why_wet")
	elif field.steepness_at(_target.x, _target.z) > MAX_SLOPE:
		_valid = false
		_reason = Text.of("why_steep")
	elif not structures.is_clear(_target, _footprint_of(selected)):
		_valid = false
		_reason = Text.of("why_no_room")

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
	if not inventory.spend(_cost_of(selected)):
		return false
	structures.place(selected, _target, _spin)
	# Re-evaluate immediately: the same spot is now occupied and the resources
	# are spent, and the ghost has to say so before the next tap.
	_evaluate()
	return true

func target() -> Vector3:
	return _target


## Which storey the ghost is on, counting from zero at ground level.
##
## Shown to the player because building upstairs by standing upstairs is the one
## rule here that cannot be seen without being told.
func storey() -> int:
	if not _is_house():
		return 0
	var ground := field.height_at(_target.x, _target.z)
	return HouseParts.storey_of(_target.y - ground)
