class_name Felled
extends RefCounted

## The trees that have been cut down.
##
## Trees are not nodes. They are instances inside a `MultiMesh` generated on
## demand from the world seed, which is what makes five thousand of them
## affordable — but it also means there is nothing to delete when one is felled.
##
## So the record runs the other way: this holds the positions of trees that are
## gone, and the tile generator skips any candidate that matches one. A felled
## tree stays felled because the exception is saved, not because the tree was
## removed.
##
## Positions are rounded to a decimetre grid before comparison. The generator
## recomputes them from the seed in floating point every time a tile is rebuilt,
## and while that is deterministic on one machine it is not something to stake a
## saved world on.

## How close a generated tree must be to a recorded stump to count as the same
## tree. Comfortably larger than any floating-point drift, comfortably smaller
## than the gap between two trees.
const MATCH_RADIUS := 0.6

## Keyed by a rounded (x, z) so the lookup is a hash rather than a scan of every
## felled tree in the world.
const CELL := 4.0

var _stumps: Dictionary = {}
var _count := 0

func count() -> int:
	return _count

func fell(world_position: Vector3) -> void:
	var key := _cell_of(world_position.x, world_position.z)
	if not _stumps.has(key):
		_stumps[key] = PackedVector2Array()
	var bucket: PackedVector2Array = _stumps[key]
	bucket.append(Vector2(world_position.x, world_position.z))
	_stumps[key] = bucket
	_count += 1

## Asked once per generated tree, so it must stay cheap.
func is_felled(world_x: float, world_z: float) -> bool:
	if _count == 0:
		return false
	# The neighbouring cells are checked too, because a tree near a cell edge
	# would otherwise be recorded in one cell and looked up in another.
	var base := Vector2i(int(floor(world_x / CELL)), int(floor(world_z / CELL)))
	for dx: int in [-1, 0, 1]:
		for dz: int in [-1, 0, 1]:
			var key := Vector2i(base.x + dx, base.y + dz)
			if not _stumps.has(key):
				continue
			for stump in _stumps[key] as PackedVector2Array:
				if absf(stump.x - world_x) < MATCH_RADIUS and absf(stump.y - world_z) < MATCH_RADIUS:
					return true
	return false

func _cell_of(world_x: float, world_z: float) -> Vector2i:
	return Vector2i(int(floor(world_x / CELL)), int(floor(world_z / CELL)))

func to_data() -> Array:
	var out: Array = []
	for key in _stumps:
		for stump in _stumps[key] as PackedVector2Array:
			out.append([snappedf(stump.x, 0.1), snappedf(stump.y, 0.1)])
	return out

func from_data(data: Array) -> void:
	_stumps.clear()
	_count = 0
	for entry in data:
		if entry is Array and entry.size() >= 2:
			fell(Vector3(float(entry[0]), 0.0, float(entry[1])))
