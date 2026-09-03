class_name Inventory
extends RefCounted

## What the player is carrying.
##
## There is no capacity limit and nothing to drop. A six-year-old should never
## be told that his pockets are full, and a ten-year-old gets nothing from
## managing rows of slots: the interesting decision is what to build, not what
## to leave behind.

signal changed(kind: StringName, total: int)

var _counts: Dictionary = {}

func count(kind: StringName) -> int:
	return _counts.get(kind, 0)

func add(kind: StringName, amount := 1) -> void:
	if amount <= 0:
		return
	_counts[kind] = count(kind) + amount
	changed.emit(kind, _counts[kind])

## True only if every listed cost can be paid. Checked before anything is spent,
## so a build can never half-succeed.
func can_afford(cost: Dictionary) -> bool:
	for kind in cost:
		if count(kind) < int(cost[kind]):
			return false
	return true

func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for kind in cost:
		_counts[kind] = count(kind) - int(cost[kind])
		changed.emit(kind, _counts[kind])
	return true

func to_data() -> Dictionary:
	var data := {}
	for kind in _counts:
		data[String(kind)] = _counts[kind]
	return data

func from_data(data: Dictionary) -> void:
	_counts.clear()
	for key in data:
		var kind := StringName(key)
		var amount := int(data[key])
		if amount > 0:
			_counts[kind] = amount
	for kind in _counts:
		changed.emit(kind, _counts[kind])
