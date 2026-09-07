class_name Lakes
extends RefCounted

## Still water, away from the river.
##
## The valley was 3% water against a river that runs in one line: a child could
## follow it or cross it, and that was all water was for. A pond is somewhere to
## go rather than something in the way — you can swim in it, a horse can wade
## it, and it puts a second kind of blue on the map.
##
## A dependency-free leaf, like `place_spec.gd` and `paths.gd`, because the
## height field has to carve the basins and must not depend on anything that
## depends on it.
##
## The basins are carved rather than the water being raised, for the same reason
## the swimming pool is: the water surface is one flat plane across the whole
## world and cannot be lifted locally. Digging the ground below the waterline
## gives exactly what a child expects to see — provided something actually
## draws water over the hole, which for a while nothing did: `water.gd`'s shader
## decided where water was by distance from the river, so both ponds were dry
## craters. It knows about these now, and `_check_the_ponds_hold_water` fails
## the build if the two ever disagree again.

## Each pond as five numbers: centre x, centre z, the long and short half-axes,
## and the angle the long axis lies along.
##
## Flat floats rather than a Vector3 apiece, which is what this was: the
## comment said "(x, z, radius)" and the code read "(x, radius, z)", so the two
## disagreed for as long as nobody looked. Numbers read in order out of a flat
## list, against a stride named right here, cannot drift like that.
## The axes are the *basin*, not the water: the bank shelves up to meet the
## waterline, so open water comes to roughly two thirds of the long axis.
##
## Twenty metres was tried first and looked, from the bank, like a puddle in a
## pit — too small to be worth walking to and too small for the shelving edge
## to read as a shore. These give something over fifty metres of open water on
## the long side: far enough across that swimming it is a decision, which is
## what makes a pond somewhere to go.
const POND_STRIDE := 5
const PONDS: Array[float] = [
	# Across the river from the camp, in the western meadow.
	-205.0, -370.0, 54.0, 34.0, 0.62,
	# The eastern one, beyond the trees.
	255.0, 250.0, 46.0, 31.0, -0.35,
]

## How far below the waterline the middle of a pond sits. Comfortably more than
## the depth at which a child starts swimming, so the middle is for swimming and
## the edge is for wading in.
const DEPTH := 3.6

## How much of the way out the bed stays flat before it starts rising. A pond
## with a vertical edge reads as a hole full of water; this one has a beach.
##
## Lower than it was: a longer shelf means the ground comes up to meet the
## water over ten metres or so rather than two, which is the difference between
## a shore and the rim of a bucket.
const SHELF := 0.34

## How much the outline wanders from a true ellipse, as a fraction of the
## radius. A stamped ellipse reads as a swimming pool; a wobble on two periods
## reads as a bank that water found for itself. Raised once the ponds were big
## enough for the shape of the shore to be visible from it.
const WOBBLE := 0.19

## The box everything here lives in, so almost every point in the world is
## rejected on four comparisons before any square root — the same lesson the
## paths taught. Generous enough to cover both ponds wherever they are moved
## within the valley.
const BOUNDS := 460.0

## How far out the shore reads as pond at all, in units of the radius. Past
## this the ground is ordinary meadow again.
const EDGE := 1.0

## How much of a pond is at this point, from 1 in the middle to 0 outside it.
##
## The same shape the water shader draws, and it has to stay that way: this
## carves the hole and the shader fills it, and a disagreement is either water
## lying on grass or a crater with nothing in it.
static func influence(x: float, z: float) -> float:
	if absf(x) > BOUNDS or absf(z) > BOUNDS:
		return 0.0

	var deepest := 0.0
	var i := 0
	while i < PONDS.size():
		var cx := PONDS[i]
		var cz := PONDS[i + 1]
		var long_axis := PONDS[i + 2]
		var short_axis := PONDS[i + 3]
		var angle := PONDS[i + 4]
		i += POND_STRIDE

		# A box first, on the larger of the two axes, before any trigonometry.
		var reach := (long_axis if long_axis > short_axis else short_axis) * (1.0 + WOBBLE)
		var dx := x - cx
		var dz := z - cz
		if absf(dx) > reach or absf(dz) > reach:
			continue

		deepest = maxf(deepest, _pond_at(dx, dz, long_axis, short_axis, angle))
	return deepest

## One pond, in its own frame: the point turned into the ellipse's axes, then
## measured against a radius that wanders a little with the angle.
static func _pond_at(
	dx: float, dz: float, long_axis: float, short_axis: float, angle: float
) -> float:
	var turn_cos := cos(angle)
	var turn_sin := sin(angle)
	var along := dx * turn_cos + dz * turn_sin
	var across := -dx * turn_sin + dz * turn_cos

	# Normalised into a circle, so the wobble and the shelf are one calculation
	# rather than two axes' worth.
	var unit_x := along / long_axis
	var unit_z := across / short_axis
	var distance := sqrt(unit_x * unit_x + unit_z * unit_z)
	if distance > 1.0 + WOBBLE:
		return 0.0

	# Dead centre has no bearing to take a wobble from, and dividing by the
	# distance there is a division by zero: the deepest point of both ponds
	# came back as untouched hillside, thirty-one metres above the water.
	if distance < 0.0001:
		return 1.0

	var edge := EDGE + WOBBLE * _wobble_at(unit_x / distance, unit_z / distance)
	if distance > edge:
		return 0.0
	return 1.0 - smoothstep(edge * SHELF, edge, distance)

## How far the bank wanders from a true ellipse at this bearing, given the
## bearing as a unit vector rather than an angle.
##
## The obvious way to write this is sin(3t) and sin(2t) off an atan2, and that
## is how it was written — until the same formula in the water shader, running
## over fifty thousand vertices of the water sheet, took the phone from sixty
## frames a second to eighteen. `atan` is expensive on a mobile GPU and the
## angle is never wanted for its own sake, so the multiple angles are taken
## from the unit vector directly. Identical output, no transcendentals: this
## is the same arithmetic the shader does, and it has to stay that way.
static func _wobble_at(bearing_x: float, bearing_z: float) -> float:
	# sin(3t) = 3s - 4s^3, and sin(2t + 1.1) expanded onto sin(2t) = 2sc and
	# cos(2t) = c^2 - s^2.
	var s := bearing_z
	var c := bearing_x
	var sin3 := s * (3.0 - 4.0 * s * s)
	var sin2 := 2.0 * s * c
	var cos2 := c * c - s * s
	var shifted := sin2 * cos(1.1) + cos2 * sin(1.1)
	return sin3 * 0.6 + shifted * 0.4

## Is this point inside a pond at all? Used to keep trees and grass out of them.
static func wet(x: float, z: float) -> bool:
	return influence(x, z) > 0.05

## How far this point is from the nearest still water, in metres, and zero
## inside a pond. What the ambient sound wants: it used to take the pond's
## shape apart itself, which is how it came to read the numbers in an order the
## file no longer used.
static func distance_to_water(x: float, z: float) -> float:
	var nearest := INF
	var i := 0
	while i < PONDS.size():
		var cx := PONDS[i]
		var cz := PONDS[i + 1]
		var long_axis := PONDS[i + 2]
		var short_axis := PONDS[i + 3]
		var angle := PONDS[i + 4]
		i += POND_STRIDE

		var dx := x - cx
		var dz := z - cz
		var along := dx * cos(angle) + dz * sin(angle)
		var across := -dx * sin(angle) + dz * cos(angle)
		# Scaled back out of the ellipse's own frame, which is near enough for
		# choosing how loud water is a hundred metres away.
		var reach := sqrt(along * along + across * across)
		var unit := sqrt(
			(along / long_axis) * (along / long_axis)
			+ (across / short_axis) * (across / short_axis)
		)
		if unit <= 1.0:
			return 0.0
		nearest = minf(nearest, reach * (1.0 - 1.0 / unit))
	return nearest

## Where each pond is and how big, for anything that needs to know without
## sampling the ground — the water shader, and the checks.
static func centres() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var i := 0
	while i < PONDS.size():
		out.append(Vector3(PONDS[i], 0.0, PONDS[i + 1]))
		i += POND_STRIDE
	return out
