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

## Each pond as six numbers: centre x, centre z, the long and short half-axes,
## the angle the long axis lies along, and the height its water stands at.
##
## The level is the sixth number because a pond is not a hole in the sea. Both
## of these were dug straight down to the world's waterline wherever they
## happened to sit, and the eastern one sits on a shoulder of hill thirteen
## metres up: what a child found there was a crater forty metres across with
## water at the bottom of it and banks too steep to climb out of. Reported from
## the phone as "a huge pit with water — if you fall in you cannot get out",
## which is exactly what it was.
##
## A pond up a hill holds its own water. The level has to stay below the lowest
## ground on its shore, or the water would run out over that lip; a check works
## that out from the terrain and fails the build if a pond is ever moved
## somewhere it would spill.
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
const POND_STRIDE := 6
const PONDS: Array[float] = [
	# Across the river from the camp, in the western meadow. Its lowest shore
	# is barely a metre up, so this one always was a lowland pond and its water
	# stays at the valley's own waterline.
	-205.0, -370.0, 54.0, 34.0, 0.62, 0.0,
	# The eastern one, beyond the trees and up on a shoulder of hill. Its
	# lowest shore stands at 13.6 m; the water sits just under that, so it fills
	# the hollow to the brim and a child wades out at the low end instead of
	# being trapped at the bottom of a pit.
	255.0, 250.0, 46.0, 31.0, -0.35, 13.0,
]

## Which numbers are which, so no caller counts on its fingers.
const POND_X := 0
const POND_Z := 1
const POND_LONG := 2
const POND_SHORT := 3
const POND_ANGLE := 4
const POND_LEVEL := 5

## How far below its own water a pond's bed sits — its own, not the world's.
## Deep enough that the middle is for swimming and the edge is for wading in,
## and no deeper: a pond is somewhere to swim, not somewhere to disappear.
const DEPTH := 2.0

## The shore.
##
## A basin dug into a hillside is a bath, and that is what the raised pond
## looked like: water thirteen metres up with the hill going on rising thirty
## metres out of it on three sides. A lake has a shore — a band of low ground
## round the water, half a metre above it, and the hill starting beyond that.
##
## SHORE is how far out that low ground reaches, and SHORE_FADE where it has
## blended back into the hillside, both in units of the basin's own axes.
## SHORE_RISE is how far the shore stands above the water: enough that the
## ground is dry and little enough that a child steps in rather than climbing
## down.
##
## The shore only ever cuts ground away, never fills it in. A lake in a meadow
## needs no shore built for it — the meadow is already the shore — and filling
## would have raised the western pond's whole valley floor half a metre for
## nothing.
const SHORE := 1.2
const SHORE_FADE := 3.0
const SHORE_RISE := 0.5

## How much of the way out the bed stays flat before it starts rising. A pond
## with a vertical edge reads as a hole full of water; this one has a beach.
##
## Higher than it was, now that a pond is two metres deep rather than three and
## a half. At a third of the way out the bed spent most of the pond climbing,
## so a child walked a long way down a slope in knee-deep water before anything
## happened — reported from the phone as walking about on the bottom instead of
## swimming. At seven tenths the bed is flat across most of the pond and comes
## up over the last dozen metres: a few steps in from the shore and you are
## swimming, which is what a pond is for.
const SHELF := 0.72

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
		var cx := PONDS[i + POND_X]
		var cz := PONDS[i + POND_Z]
		var long_axis := PONDS[i + POND_LONG]
		var short_axis := PONDS[i + POND_SHORT]
		var angle := PONDS[i + POND_ANGLE]
		i += POND_STRIDE

		# A box first, on the larger of the two axes, before any trigonometry.
		var reach := (long_axis if long_axis > short_axis else short_axis) * (1.0 + WOBBLE)
		var dx := x - cx
		var dz := z - cz
		if absf(dx) > reach or absf(dz) > reach:
			continue

		deepest = maxf(deepest, _pond_at(dx, dz, long_axis, short_axis, angle))
	return deepest

## How strongly the shore's levelling applies here, from 1 at the water's edge
## to 0 where the hillside takes over again — and the height it levels to, as
## one answer: [shore_height, strength].
static func shore_at(x: float, z: float) -> Array:
	if absf(x) > BOUNDS or absf(z) > BOUNDS:
		return [0.0, 0.0]
	var strongest := 0.0
	var height := 0.0
	var i := 0
	while i < PONDS.size():
		var long_axis := PONDS[i + POND_LONG]
		var short_axis := PONDS[i + POND_SHORT]
		var reach := (long_axis if long_axis > short_axis else short_axis) * SHORE_FADE
		var dx := x - PONDS[i + POND_X]
		var dz := z - PONDS[i + POND_Z]
		if absf(dx) > reach or absf(dz) > reach:
			i += POND_STRIDE
			continue
		var distance := _reach_of(dx, dz, long_axis, short_axis, PONDS[i + POND_ANGLE])
		var here := 1.0 - smoothstep(SHORE, SHORE_FADE, distance)
		if here > strongest:
			strongest = here
			height = PONDS[i + POND_LEVEL] + SHORE_RISE
		i += POND_STRIDE
	return [height, strongest]

## How far out a point is in a pond's own frame, where 1.0 is the basin's edge.
## Both the basin and the shore are measured from this, so the two cannot drift
## apart.
static func _reach_of(
	dx: float, dz: float, long_axis: float, short_axis: float, angle: float
) -> float:
	var turn_cos := cos(angle)
	var turn_sin := sin(angle)
	var along := (dx * turn_cos + dz * turn_sin) / long_axis
	var across := (-dx * turn_sin + dz * turn_cos) / short_axis
	return sqrt(along * along + across * across)

## The height the water stands at here, and how much of a pond is here, as one
## answer: [level, influence]. Everything that used to compare against the
## world's waterline asks this instead, because the world's waterline is only
## the answer for the river and for ponds that happen to sit beside it.
static func water_at(x: float, z: float, world_level: float) -> Array:
	if absf(x) > BOUNDS or absf(z) > BOUNDS:
		return [world_level, 0.0]
	var best := world_level
	var deepest := 0.0
	var i := 0
	while i < PONDS.size():
		var here := _pond_at(
			x - PONDS[i + POND_X], z - PONDS[i + POND_Z],
			PONDS[i + POND_LONG], PONDS[i + POND_SHORT], PONDS[i + POND_ANGLE]
		)
		if here > deepest:
			deepest = here
			best = PONDS[i + POND_LEVEL]
		i += POND_STRIDE
	return [best, deepest]

## The height of the water covering this point, or the world's own waterline
## where no pond does.
static func level_at(x: float, z: float, world_level: float) -> float:
	return water_at(x, z, world_level)[0]

## Is this pond's water above the world's waterline? Those are the ones that
## need a surface of their own drawn at their own height, because the world's
## one sheet of water lies flat at zero.
static func is_raised(index: int, world_level: float) -> bool:
	return PONDS[index * POND_STRIDE + POND_LEVEL] > world_level + 0.01

## How many ponds there are.
static func count() -> int:
	return PONDS.size() / POND_STRIDE

static func at(index: int, field: int) -> float:
	return PONDS[index * POND_STRIDE + field]

## The pond's outline at the height its water stands at, as a ring of points
## around its centre: what a surface drawn for it has to cover. Sampled rather
## than solved, because the bank wobbles and the shelf is a smoothstep — and
## this runs twice in the life of a world.
static func outline(index: int, points: int, cut := 0.06) -> PackedVector2Array:
	var long_axis := at(index, POND_LONG)
	var short_axis := at(index, POND_SHORT)
	var angle := at(index, POND_ANGLE)
	var turn_cos := cos(angle)
	var turn_sin := sin(angle)
	var ring := PackedVector2Array()
	for step in points:
		var bearing := TAU * float(step) / float(points)
		var along := cos(bearing)
		var across := sin(bearing)
		# Walk outwards along this bearing until the pond gives out.
		var reach := 0.0
		var probe := 0.02
		while probe <= 1.0 + WOBBLE:
			var dx := (along * probe * long_axis) * turn_cos - (across * probe * short_axis) * turn_sin
			var dz := (along * probe * long_axis) * turn_sin + (across * probe * short_axis) * turn_cos
			if _pond_at(dx, dz, long_axis, short_axis, angle) < cut:
				break
			reach = probe
			probe += 0.02
		var out_along := along * reach * long_axis
		var out_across := across * reach * short_axis
		ring.append(Vector2(
			out_along * turn_cos - out_across * turn_sin,
			out_along * turn_sin + out_across * turn_cos
		))
	return ring

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
