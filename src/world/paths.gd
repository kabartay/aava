class_name Paths
extends RefCounted

## The trodden paths between the places worth walking to.
##
## A path is the strongest signal a world can give about where to go. Until
## there were destinations there was nothing for a path to connect, and a path
## that leads nowhere is worse than no path — it promises something and does not
## deliver it. Now there are six fixed points, and the ground between them is
## worn.
##
## Like the football pitch and the pool, paths live in the height field rather
## than in a node that draws paths. That way the terrain mesh, the collision
## heightmap, the grass, the trees and the pickups all agree that there is a
## path here: grass does not grow through it, and it flattens slightly underfoot
## the way a walked route does.
##
## This is a dependency-free leaf for the same reason `place_spec.gd` is: the
## height field needs it, and it must not need anything that needs the height
## field.

## Half the width of a path, and how far its edge feathers into the grass. A
## path with a hard edge looks painted on; a feathered one looks walked.
const HALF_WIDTH := 1.5
const FEATHER := 1.4

## How much a path sinks into the ground. Small — a worn route is compacted, not
## a trench, and anything deeper makes a child stumble at the edge.
const SINK := 0.09

## What each route joins. Named rather than given as coordinates, and resolved
## through PlaceSpec, so moving a destination moves the path to it — writing the
## offsets out again here is precisely the drift PlaceSpec exists to prevent.
##
## `camp` is the empty name: it is where a child starts, and what they would
## naturally wear a route back to. The archery butts are given by offset because
## Archery places them itself; that one duplication is the price of this file
## depending on nothing, which is what keeps the height field free of cycles.
const BUTTS_OFFSET := Vector3(330.0, 0.0, -180.0)

const ROUTES: Array[Dictionary] = [
	{"from": &"", "to": &"playground"},
	{"from": &"", "to": &"cafe"},
	{"from": &"", "to": &"pool"},
	# One that does not touch the camp, so it is not the only hub and the far
	# side of the valley is worth crossing.
	{"from": &"playground", "to": &"pool"},
]

## Everything the paths touch, as a box around the camp. Checked before any
## route is, because this function is called for every terrain vertex, every
## grass tuft and every tree candidate — some four hundred thousand times per
## world build, several times over for normals and steepness — and the paths
## occupy a few hundred metres of a world twelve hundred metres across.
##
## Without this the square roots alone came to roughly seven million per build
## and the world took longer to generate than the screenshot tool would wait.
## It was 40 m, from when every destination sat beside the camp. They are four
## hundred metres out now, and a box that small silently rejected every point
## along every route: the paths existed in the data and nowhere in the ground.
##
## Widening it costs some of the cheap rejection — the median frame went from
## 1.50 ms to 2.00 ms — and an attempt to win that back by caching the resolved
## endpoints in a static Array made it 6.90 ms instead, because indexing a
## nested untyped Array in GDScript returns Variants and the type checks cost
## more than the dictionary lookups they replaced. The straightforward version
## is the fast one.
const BOUNDS_HALF := 480.0

## Every route as four flat numbers: ax, az, bx, bz.
##
## `influence` is called several million times during a world build, and the
## declarative form above cost five dictionary lookups and five Vector3
## additions on every one of them — 2.58 µs a call, which was 56% of the entire
## height field and showed up on a tablet as a stutter every time new ground
## streamed in.
##
## These are the same numbers, resolved once by hand. A check recomputes them
## from ROUTES and fails the build if the two ever disagree, so the fast form
## cannot quietly drift away from the readable one.
const SEGMENTS: Array[float] = [
	0.0, 18.0, -360.0, 268.0,
	0.0, 18.0, -300.0, -242.0,
	0.0, 18.0, 60.0, 398.0,
	-360.0, 268.0, 60.0, 398.0,
	0.0, 18.0, 330.0, -162.0,
]

## How much of a path is at this point, from 1 in the middle to 0 off it.
static func influence_fast(x: float, z: float) -> float:
	if absf(x) > BOUNDS_HALF or absf(z) > BOUNDS_HALF + 40.0:
		return 0.0

	var reach := HALF_WIDTH + FEATHER
	var strongest := 0.0
	var i := 0
	while i < SEGMENTS.size():
		var ax := SEGMENTS[i]
		var az := SEGMENTS[i + 1]
		var bx := SEGMENTS[i + 2]
		var bz := SEGMENTS[i + 3]
		i += 4
		# The segment's own box, inline rather than through minf/maxf calls.
		if x < (ax if ax < bx else bx) - reach or x > (ax if ax > bx else bx) + reach:
			continue
		if z < (az if az < bz else bz) - reach or z > (az if az > bz else bz) + reach:
			continue
		# Squared, so the square root is only taken for the few points that are
		# actually near a path. The box test admits a lot — a diagonal route
		# from the camp to the playground has a box 360 by 250 m, of which the
		# path itself is a three-metre ribbon — so this rejection is where the
		# work is really saved.
		var squared := _squared_distance_to_segment(x, z, ax, az, bx, bz)
		if squared > reach * reach:
			continue
		var distance := sqrt(squared)
		strongest = maxf(strongest, 1.0 - smoothstep(HALF_WIDTH, HALF_WIDTH + FEATHER, distance))
		if strongest >= 0.999:
			return 1.0
	return strongest

## The same as `_distance_to_segment` without the final square root.
static func _squared_distance_to_segment(
	x: float, z: float, ax: float, az: float, bx: float, bz: float
) -> float:
	var dx := bx - ax
	var dz := bz - az
	var length_squared := dx * dx + dz * dz
	if length_squared < 0.0001:
		return (x - ax) * (x - ax) + (z - az) * (z - az)
	var along := ((x - ax) * dx + (z - az) * dz) / length_squared
	along = 0.0 if along < 0.0 else (1.0 if along > 1.0 else along)
	var near_x := ax + dx * along
	var near_z := az + dz * along
	return (x - near_x) * (x - near_x) + (z - near_z) * (z - near_z)

## The readable form, kept because it is what the routes actually mean and what
## the check compares against.
static func influence(x: float, z: float, camp: Vector3) -> float:
	# Rejected on two subtractions and two comparisons for almost every point
	# in the world, before a single square root is taken.
	if absf(x - camp.x) > BOUNDS_HALF or absf(z - camp.z) > BOUNDS_HALF:
		return 0.0

	var strongest := 0.0
	for route in ROUTES:
		var a := _end_of(route["from"], camp)
		var b := _end_of(route["to"], camp)
		# The same rejection per route, on the segment's own box.
		var reach := HALF_WIDTH + FEATHER
		if x < minf(a.x, b.x) - reach or x > maxf(a.x, b.x) + reach:
			continue
		if z < minf(a.z, b.z) - reach or z > maxf(a.z, b.z) + reach:
			continue
		var distance := _distance_to_segment(x, z, a.x, a.z, b.x, b.z)
		if distance > HALF_WIDTH + FEATHER:
			continue
		strongest = maxf(
			strongest, 1.0 - smoothstep(HALF_WIDTH, HALF_WIDTH + FEATHER, distance)
		)
		if strongest >= 0.999:
			return 1.0

	# The walk to the archery butts.
	var butts := camp + BUTTS_OFFSET
	var to_butts := _distance_to_segment(x, z, camp.x, camp.z, butts.x, butts.z)
	if to_butts <= HALF_WIDTH + FEATHER:
		strongest = maxf(
			strongest, 1.0 - smoothstep(HALF_WIDTH, HALF_WIDTH + FEATHER, to_butts)
		)
	return strongest

## Where a named end of a route is. The empty name is the camp itself.
static func _end_of(place: StringName, camp: Vector3) -> Vector3:
	if place == &"":
		return camp
	return PlaceSpec.centre_of(place, camp)

## Perpendicular distance from a point to a line segment, in the ground plane.
static func _distance_to_segment(
	x: float, z: float, ax: float, az: float, bx: float, bz: float
) -> float:
	var dx := bx - ax
	var dz := bz - az
	var length_squared := dx * dx + dz * dz
	if length_squared < 0.0001:
		return sqrt((x - ax) * (x - ax) + (z - az) * (z - az))
	# Clamped, so the nearest point is on the segment rather than on the
	# infinite line it lies along — otherwise every path would be a path across
	# the whole valley.
	var along := clampf(((x - ax) * dx + (z - az) * dz) / length_squared, 0.0, 1.0)
	var near_x := ax + dx * along
	var near_z := az + dz * along
	return sqrt((x - near_x) * (x - near_x) + (z - near_z) * (z - near_z))
