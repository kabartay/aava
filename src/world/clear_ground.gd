class_name ClearGround
extends RefCounted

## Ground that is built over, and so must stay free of grass tufts.
##
## A tuft is a third of a metre tall and a mat, a court, a deck or a floor is a
## few centimetres thick, so every flat built surface laid on the grass had
## grass coming up through it, one special case at a time (the café's floor,
## then its doormat, then the shop's porch). This is the one place that says
## "nothing grows here", and any place, ride or structure can say it:
##
##     ClearGround.rect(&"playground", Vector3(x, 0.0, z), half_x, half_z)
##     ClearGround.circle(&"playground", Vector3(x, 0.0, z), radius)
##
## Registered by `owner`, so a place that is built again forgets what it
## claimed before (`forget`) instead of claiming it twice. Rectangles may be
## turned (`yaw`, radians about the vertical axis, as Basis(Vector3.UP, yaw)).
## Coordinates are world metres; only x and z are read.
##
## The scatter of grass runs on worker threads, so the list is guarded by a
## mutex and a tile asks for its own handful of shapes ONCE (`near`), then tests
## its candidates against that list with `covers` — no lock and no search of
## the whole world per tuft. A surface registered after a tile has been baked
## is only seen when that tile is baked again: call
## `Vegetation.rebuild_around` for a late registration. Dependency-free, like
## PlaceSpec, so the vegetation bake may read it.

## A tuft is wider than a point: keep this much clear beyond each edge, so a
## blade at the rim does not lean across the boards.
const MARGIN := 0.35

## One shape is six numbers: centre x, centre z, half x, half z (a circle has
## half z of -1 and its radius in half x), then the cosine and sine of the yaw.
static var _shapes: Dictionary = {}
static var _mutex := Mutex.new()

## Keep a rectangle clear: `centre` and half-extents in metres, optionally turned.
static func rect(owner: StringName, centre: Vector3, half_x: float, half_z: float, yaw := 0.0) -> void:
	_add(owner, PackedFloat64Array([centre.x, centre.z, half_x, half_z, cos(yaw), sin(yaw)]))

## Keep a disc clear.
static func circle(owner: StringName, centre: Vector3, radius: float) -> void:
	_add(owner, PackedFloat64Array([centre.x, centre.z, radius, -1.0, 1.0, 0.0]))

## Forget everything one owner has claimed.
static func forget(owner: StringName) -> void:
	_mutex.lock()
	_shapes.erase(owner)
	_mutex.unlock()

## Forget everything. For tests and for a world that is torn down.
static func forget_all() -> void:
	_mutex.lock()
	_shapes.clear()
	_mutex.unlock()

## How many shapes are registered, all owners.
static func count() -> int:
	_mutex.lock()
	var total := 0
	for owner: StringName in _shapes:
		total += (_shapes[owner] as Array).size()
	_mutex.unlock()
	return total

## The shapes that reach into this box, for `covers`. Taken once per tile.
static func near(x0: float, z0: float, x1: float, z1: float) -> Array[PackedFloat64Array]:
	var out: Array[PackedFloat64Array] = []
	_mutex.lock()
	for owner: StringName in _shapes:
		for shape: PackedFloat64Array in _shapes[owner]:
			var reach := _reach(shape) + MARGIN
			if shape[0] + reach < x0 or shape[0] - reach > x1:
				continue
			if shape[1] + reach < z0 or shape[1] - reach > z1:
				continue
			out.append(shape)
	_mutex.unlock()
	return out

## Is this point on one of these shapes, or within MARGIN of one?
static func covers(shapes: Array[PackedFloat64Array], x: float, z: float) -> bool:
	for shape in shapes:
		var dx := x - shape[0]
		var dz := z - shape[1]
		if shape[3] < 0.0:
			var radius := shape[2] + MARGIN
			if dx * dx + dz * dz <= radius * radius:
				return true
			continue
		# Into the rectangle's own axes.
		var local_x := dx * shape[4] + dz * shape[5]
		var local_z := -dx * shape[5] + dz * shape[4]
		if absf(local_x) <= shape[2] + MARGIN and absf(local_z) <= shape[3] + MARGIN:
			return true
	return false

## One-off question, for callers that are not scattering anything: is this
## point kept clear of grass by something registered?
static func kept_at(x: float, z: float) -> bool:
	return covers(near(x - 1.0, z - 1.0, x + 1.0, z + 1.0), x, z)

static func _reach(shape: PackedFloat64Array) -> float:
	if shape[3] < 0.0:
		return shape[2]
	return sqrt(shape[2] * shape[2] + shape[3] * shape[3])

static func _add(owner: StringName, shape: PackedFloat64Array) -> void:
	_mutex.lock()
	if not _shapes.has(owner):
		_shapes[owner] = []
	(_shapes[owner] as Array).append(shape)
	_mutex.unlock()
