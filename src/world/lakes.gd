class_name Lakes
extends RefCounted

## Still water, away from the river.
##
## The valley was 3% water against a river that runs in one line: a child could
## follow it or cross it, and that was all water was for. A lake is somewhere to
## go rather than something in the way — you can swim across it, a horse can
## wade it, and it puts a second kind of blue on the map.
##
## A dependency-free leaf, like `place_spec.gd` and `paths.gd`, because the
## height field has to carve the basins and must not depend on anything that
## depends on it.
##
## The basins are carved rather than the water being raised, for the same reason
## the swimming pool is: the water surface is one flat plane across the whole
## world and cannot be lifted locally. Digging the ground below the waterline
## gives exactly what a child expects to see.

## Where the lakes are and how big, as (x, z, radius). Chosen to sit in the
## walkable valley, clear of the river and of everything that was built, and far
## enough apart to be two places rather than one lake with a waist.
const BASINS: Array[Vector3] = [
	Vector3(255.0, 78.0, 250.0),
	Vector3(-205.0, 82.0, -370.0),
]

## How far below the waterline the middle of a lake sits. Comfortably more than
## the depth at which a child starts swimming, so the middle is for swimming and
## the edge is for wading in.
const DEPTH := 3.6

## How much of the radius is the shelving rim. A lake with a vertical edge reads
## as a hole full of water; this one has a beach.
const SHELF := 0.42

## The box everything here lives in, so almost every point in the world is
## rejected on four comparisons before any square root — the same lesson the
## paths taught.
const BOUNDS := 460.0

## How much of a lake is at this point, from 1 in the middle to 0 outside it.
static func influence(x: float, z: float) -> float:
	if absf(x) > BOUNDS or absf(z) > BOUNDS:
		return 0.0

	var deepest := 0.0
	for basin in BASINS:
		var radius := basin.y
		var dx := x - basin.x
		var dz := z - basin.z
		if absf(dx) > radius or absf(dz) > radius:
			continue
		var distance := sqrt(dx * dx + dz * dz)
		if distance > radius:
			continue
		# Flat across the middle and shelving over the outer part, which is what
		# makes an edge a beach rather than a step.
		deepest = maxf(deepest, 1.0 - smoothstep(radius * SHELF, radius, distance))
	return deepest

## Is this point inside a lake at all? Used to keep trees and grass out of them.
static func wet(x: float, z: float) -> bool:
	return influence(x, z) > 0.05
