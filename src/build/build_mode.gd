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

## Everything snaps to this grid, and rotation to eighths of a turn. Snapping is
## not a constraint here, it is a gift: it means a child's fence comes out
## straight, and a straight fence is the difference between proud and
## disappointed.
const GRID := 1.0
const TURN_STEPS := 8

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
var _material: StandardMaterial3D
var _target := Vector3.ZERO
var _spin := 0.0
var _valid := false
var _reason := ""
var _last_signature := ""

func _init(height_field: HeightField, structure_store: Structures, player_inventory: Inventory) -> void:
	field = height_field
	structures = structure_store
	inventory = player_inventory

func _ready() -> void:
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
	_refresh_mesh()

func set_active(enabled: bool) -> void:
	active = enabled
	_ghost.visible = enabled
	_last_signature = ""

func select(kind: StringName) -> void:
	if not BuildKinds.INFO.has(kind) or kind == selected:
		return
	selected = kind
	_refresh_mesh()
	_last_signature = ""

func _refresh_mesh() -> void:
	# The ghost of something that grows shows what it will become, not the sprout
	# it starts as: a child is choosing a tree, not a twig.
	var stage := BuildKinds.GROWTH_STAGES - 1 if BuildKinds.grows(selected) else 0
	_ghost.mesh = BuildKinds.build_mesh(selected, stage)

## Driven from wherever the player is, once per frame.
func aim(player_position: Vector3, yaw: float) -> void:
	if not active:
		return

	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var raw := player_position + forward * REACH
	_target = Vector3(
		snappedf(raw.x, GRID),
		0.0,
		snappedf(raw.z, GRID)
	)
	_target.y = field.height_at(_target.x, _target.z)

	var step := TAU / float(TURN_STEPS)
	_spin = snappedf(yaw, step)

	_ghost.transform = Transform3D(Basis(Vector3.UP, _spin), _target)
	_evaluate()

func _evaluate() -> void:
	var cost := BuildKinds.cost(selected)
	_valid = true
	_reason = ""

	if not inventory.can_afford(cost):
		_valid = false
		_reason = "need " + _cost_text(cost)
	elif _target.y < HeightField.WATER_LEVEL + 0.15:
		_valid = false
		_reason = "too wet"
	elif field.steepness_at(_target.x, _target.z) > MAX_SLOPE:
		_valid = false
		_reason = "too steep"
	elif not structures.is_clear(_target, BuildKinds.footprint(selected)):
		_valid = false
		_reason = "no room"

	_material.albedo_color = (
		Color(0.45, 1.0, 0.55, 0.5) if _valid
		else Color(1.0, 0.42, 0.38, 0.45)
	)

	# Only announce a change, so the interface is not rebuilt sixty times a
	# second while the player stands still.
	var signature := "%s|%s|%s" % [selected, _valid, _reason]
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
	if not inventory.spend(BuildKinds.cost(selected)):
		return false
	structures.place(selected, _target, _spin)
	# Re-evaluate immediately: the same spot is now occupied and the resources
	# are spent, and the ghost has to say so before the next tap.
	_evaluate()
	return true

func target() -> Vector3:
	return _target
