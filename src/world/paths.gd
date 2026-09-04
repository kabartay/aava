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
const BUTTS_OFFSET := Vector3(-9.0, 0.0, 6.0)

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
const BOUNDS_HALF := 40.0

## How much of a path is at this point, from 1 in the middle to 0 off it.
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
