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

## Stumps that have been grubbed out, keyed the same way.
##
## Two states, not one. A felled tree must stay felled — the forest is
## generated from the seed, and forgetting the record would stand the tree back
## up — but the stump itself can go, and planting a sapling on the spot is
## exactly when it should: a child who cuts a tree down and puts one back has
## tidied up, and the ground ought to show that rather than keeping the scar
## for ever.
var _cleared: Dictionary = {}

func count() -> int:
	return _count

## Grub out any stump within `radius` of a point. Returns how many went.
func clear_stumps_near(world_position: Vector3, radius: float) -> int:
	var gone := 0
	var base := Vector2i(int(floor(world_position.x / CELL)), int(floor(world_position.z / CELL)))
	for dx: int in [-1, 0, 1]:
		for dz: int in [-1, 0, 1]:
			var key := Vector2i(base.x + dx, base.y + dz)
			if not _stumps.has(key):
				continue
			for stump in _stumps[key] as PackedVector2Array:
				if Vector2(world_position.x, world_position.z).distance_to(stump) > radius:
					continue
				if _is_cleared(stump.x, stump.y):
					continue
				if not _cleared.has(key):
					_cleared[key] = PackedVector2Array()
				var bucket: PackedVector2Array = _cleared[key]
				bucket.append(stump)
				_cleared[key] = bucket
				gone += 1
	return gone

## Is there a stump to draw here? A cleared one is still felled — the tree does
## not come back — but nothing is left standing in the grass.
func shows_stump(world_x: float, world_z: float) -> bool:
	return is_felled(world_x, world_z) and not _is_cleared(world_x, world_z)

func _is_cleared(world_x: float, world_z: float) -> bool:
	if _cleared.is_empty():
		return false
	var base := Vector2i(int(floor(world_x / CELL)), int(floor(world_z / CELL)))
	for dx: int in [-1, 0, 1]:
		for dz: int in [-1, 0, 1]:
			var key := Vector2i(base.x + dx, base.y + dz)
			if not _cleared.has(key):
				continue
			for stump in _cleared[key] as PackedVector2Array:
				if Vector2(world_x, world_z).distance_to(stump) <= MATCH_RADIUS:
					return true
	return false

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

## An exact copy, for a worker thread to read while this one keeps being
## written to. `to_data()` would do but it snaps every stump to a tenth of a
## metre on the way, and a copy for a thread should not be a slightly different
## forest. Cheap: there are as many stumps as a child has had the patience to
## make.
func snapshot() -> Felled:
	var copy := Felled.new()
	for key in _stumps:
		copy._stumps[key] = (_stumps[key] as PackedVector2Array).duplicate()
	for key in _cleared:
		copy._cleared[key] = (_cleared[key] as PackedVector2Array).duplicate()
	copy._count = _count
	return copy

func _cell_of(world_x: float, world_z: float) -> Vector2i:
	return Vector2i(int(floor(world_x / CELL)), int(floor(world_z / CELL)))

## Saved as a flat list of [x, z] or [x, z, cleared]. The two-value form is
## what every world written before stumps could be grubbed out contains, and it
## still loads: a stump with nothing said about it is a stump that shows.
func to_data() -> Array:
	var out: Array = []
	for key in _stumps:
		for stump in _stumps[key] as PackedVector2Array:
			var entry := [snappedf(stump.x, 0.1), snappedf(stump.y, 0.1)]
			if _is_cleared(stump.x, stump.y):
				entry.append(1)
			out.append(entry)
	return out

func from_data(data: Array) -> void:
	_stumps.clear()
	_cleared.clear()
	_count = 0
	for entry in data:
		if entry is Array and entry.size() >= 2:
			var at := Vector3(float(entry[0]), 0.0, float(entry[1]))
			fell(at)
			if entry.size() >= 3 and int(entry[2]) == 1:
				clear_stumps_near(at, 0.05)
