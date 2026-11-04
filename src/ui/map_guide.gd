class_name MapGuide
extends RefCounted

## Where a child has said they want to go, and which way and how far that is.
##
## The map showed where things were and left the walking to the child: a three
## year old who has tapped the swing on the map has no use for a chart of the
## valley once the map is closed again. This is the memory behind a gentle
## pointer at the edge of the play screen (see GuideBadge) and the dotted line
## on the map (see MapRoute). It holds one place at a time, belongs to one
## map — so to one child, on one phone — and clears itself on arrival.
##
## Pure arithmetic with no nodes, so the checks can ask it questions without a
## screen, and so that a second phone's guide cannot be this one's.

## Said once, when the child has got close enough to the place.
signal arrived(kind: int)

## How close counts as having got there, in metres, by what the place is. A
## place has a footprint, and a child standing at the edge of the pool has
## arrived; a horse is arrived at when you could pat it.
const ARRIVE_WITHIN := {
	PlaceGlyph.Kind.HOME: 9.0,
	PlaceGlyph.Kind.PLAYGROUND: 16.0,
	PlaceGlyph.Kind.CAFE: 13.0,
	PlaceGlyph.Kind.POOL: 15.0,
	PlaceGlyph.Kind.PITCH: 12.0,
	PlaceGlyph.Kind.RANGE: 22.0,
	PlaceGlyph.Kind.SHOP: 15.0,
	PlaceGlyph.Kind.BRIDGE: 9.0,
	PlaceGlyph.Kind.MOUNTAIN: 0.0,
	PlaceGlyph.Kind.FAIRGROUND: 30.0,
	PlaceGlyph.Kind.LAKE: 24.0,
	PlaceGlyph.Kind.BOAT: 24.0,
	PlaceGlyph.Kind.HORSE: 6.0,
	PlaceGlyph.Kind.FRIEND: 6.0,
}

## Upper bounds, in metres, of the footprints that stand for "close", "quite
## close", "a walk", "far" and "very far": a child who cannot read a number
## can still count five little feet.
const PIP_BOUNDS: Array[float] = [40.0, 110.0, 250.0, 500.0]
const PIPS := 5

var active := false
## Which kind of place, and which of the map's marks (an index into its
## destinations; -1 when nothing is chosen).
var kind := -1
var index := -1
## Where it is now. A friend or a horse moves, so the map refreshes this.
var at := Vector3.ZERO
## Metres to it, in the flat, and the angle on the play screen, clockwise from
## straight up, once `update` has been given where the child stands.
var distance := 0.0
var angle := 0.0

## Choose a place. Choosing the one already chosen clears it instead, so the
## same tap that set the guide takes it away.
func toggle(mark_index: int, mark_kind: int, where: Vector3) -> void:
	if active and index == mark_index:
		clear()
		return
	active = true
	index = mark_index
	kind = mark_kind
	at = where

func clear() -> void:
	active = false
	index = -1
	kind = -1
	distance = 0.0

## Follow a moving place.
func retarget(where: Vector3) -> void:
	at = where

## Work out the way and the distance from where the child stands, looking
## along `yaw`. Returns true, and clears itself, the moment they arrive.
func update(player: Vector3, yaw: float) -> bool:
	if not active:
		return false
	distance = flat_distance(player, at)
	angle = relative_angle(player, at, yaw)
	if distance <= arrive_radius(kind):
		var was := kind
		clear()
		arrived.emit(was)
		return true
	return false

static func arrive_radius(of_kind: int) -> float:
	return float(ARRIVE_WITHIN.get(of_kind, 12.0))

static func flat_distance(from: Vector3, to: Vector3) -> float:
	return Vector2(to.x - from.x, to.z - from.z).length()

## The angle to turn from straight up the play screen to point at `to`, as a
## child standing at `from` whose camera looks along `yaw` sees it, clockwise,
## in radians. North is -z and the camera's yaw 0 looks north; turning the
## camera to the left (positive yaw) swings everything to the right.
static func relative_angle(from: Vector3, to: Vector3, yaw: float) -> float:
	var flat := Vector2(to.x - from.x, to.z - from.z)
	if flat.length_squared() < 0.0001:
		return 0.0
	return wrapf(atan2(flat.x, -flat.y) + yaw, -PI, PI)

## How many of the five footprints are filled for this far.
static func pips_for(metres: float) -> int:
	var filled := 1
	for bound in PIP_BOUNDS:
		if metres > bound:
			filled += 1
	return filled

## Round a distance to something worth saying: tens of metres up to three
## hundred, fifties beyond.
static func rounded(metres: float) -> int:
	if metres < 100.0:
		return maxi(5, int(round(metres / 5.0)) * 5)
	if metres < 300.0:
		return int(round(metres / 10.0)) * 10
	return int(round(metres / 50.0)) * 50

## Push marks that overlap apart, and keep them off the fixed things and inside
## the box. `centres` are where the marks want to be; the result is where they
## go. Marks keep their order, so the answer for a given map is the same
## every frame and nothing flickers.
##
## `obstacles` are fixed discs — the child's own arrow — that no mark may sit
## on: the arrow used to be drawn over whatever stood where the child stood,
## which hid the house at home and the ball at the pitch.
static func declutter(
	centres: PackedVector2Array,
	radii: PackedFloat32Array,
	obstacles: PackedVector2Array,
	obstacle_radii: PackedFloat32Array,
	bounds: Rect2
) -> PackedVector2Array:
	var out := centres.duplicate()
	for pass_over in 100:
		var moved := false
		for a in out.size():
			for b in range(a + 1, out.size()):
				var gap := out[b] - out[a]
				var wanted := radii[a] + radii[b]
				var length := gap.length()
				if length >= wanted:
					continue
				# Exactly on top of each other: a fixed, different direction
				# for each pair, never random.
				var direction := gap / length if length > 0.01 else Vector2.from_angle(float(a * 7 + b * 3))
				var push := (wanted - length) * 0.5 + 0.1
				out[a] -= direction * push
				out[b] += direction * push
				moved = true
		for a in out.size():
			for o in obstacles.size():
				var gap := out[a] - obstacles[o]
				var wanted := radii[a] + obstacle_radii[o]
				var length := gap.length()
				if length >= wanted:
					continue
				var direction := gap / length if length > 0.01 else Vector2.from_angle(float(a) * 1.3)
				out[a] += direction * (wanted - length + 0.1)
				moved = true
			out[a] = Vector2(
				clampf(out[a].x, bounds.position.x, bounds.end.x),
				clampf(out[a].y, bounds.position.y, bounds.end.y)
			)
		if not moved:
			break
	return out

## Spread marks that sit on the rim of a square so that they keep `gap` apart
## along it, going round the corners. Marks that share a direction used to pile
## up in one corner, because pushing them apart in the plane pushed them into
## the wall: along the rim they slide past each other instead. Marks must be on
## the rim of `box` already; the result is on it too, in the same order.
static func spread_on_rim(marks: PackedVector2Array, box: Rect2, gap: float) -> PackedVector2Array:
	var count := marks.size()
	var out := marks.duplicate()
	if count < 2:
		return out
	var side := box.size.x
	var round_trip := side * 4.0
	var along := PackedFloat32Array()
	along.resize(count)
	for i in count:
		along[i] = _along_rim(marks[i], box)
	var order: Array[int] = []
	for i in count:
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return along[a] < along[b])
	for pass_over in 60:
		var moved := false
		for k in count:
			var a := order[k]
			var b := order[(k + 1) % count]
			var between := along[b] - along[a] + (round_trip if k == count - 1 else 0.0)
			if between >= gap:
				continue
			var push := (gap - between) * 0.5 + 0.05
			along[a] -= push
			along[b] += push
			moved = true
		if not moved:
			break
	for i in count:
		out[i] = _point_on_rim(fposmod(along[i], round_trip), box)
	return out

## How far round the rim of the box, clockwise from its top-left corner, a
## point on it is.
static func _along_rim(point: Vector2, box: Rect2) -> float:
	var side := box.size.x
	var local := point - box.position
	var edge := 0.5
	if absf(local.y) <= edge:
		return local.x
	if absf(local.x - side) <= edge:
		return side + local.y
	if absf(local.y - side) <= edge:
		return side * 2.0 + (side - local.x)
	return side * 3.0 + (side - local.y)

static func _point_on_rim(along: float, box: Rect2) -> Vector2:
	var side := box.size.x
	if along < side:
		return box.position + Vector2(along, 0.0)
	if along < side * 2.0:
		return box.position + Vector2(side, along - side)
	if along < side * 3.0:
		return box.position + Vector2(side - (along - side * 2.0), side)
	return box.position + Vector2(0.0, side - (along - side * 3.0))
