class_name DamSpec
extends RefCounted

## Where beavers can build a dam, and what a finished one does to the river.
##
## A dependency-free leaf, for the same reason `place_spec.gd` and `paths.gd`
## are: the height field has to raise the riverbed behind a dam, and the dam has
## to know where the river is. Anything else and the two reference each other,
## which does not error in Godot — the import simply never finishes.
##
## A dam is the only thing in this game that changes the world rather than the
## score. Feeding a squirrel earns coins; damming the river makes a pond that is
## still there tomorrow, and that a child can swim in. That is worth more than
## any number going up, and it is why this was worth the extra work.

## The dam sites, as a depth along the river. Fixed rather than chosen, because
## the height field must stay a pure function of position and seed — a site
## picked at runtime could not be levelled into the terrain.
##
## Two of them, at narrow points, far enough apart that each pond is its own
## place rather than one long lake.
const SITES: Array[float] = [-64.0, 96.0]

## How many sticks a beaver needs before the dam is finished.
const STICKS_NEEDED := 8

## How high the riverbed rises behind a finished dam, how far back the pond
## reaches, and how wide it spreads.
##
## The rise is small on purpose. The riverbed sits about 3.7 m below the water
## line, so raising it by much more than a metre leaves a puddle rather than a
## pond — and the point of a dam is still water deep enough to swim in. What
## makes it read as a pond is the width, not the depth: the river is a narrow
## trench, and the pond spreads three times as wide.
const RISE := 1.1
const POND_LENGTH := 34.0
const POND_HALF_WIDTH := 15.0

## How thick the dam wall itself is.
const WALL_THICKNESS := 3.0

## How much a finished dam raises the ground at a point, in metres.
##
## The pond is made by raising the riverbed rather than by raising the water:
## the water surface is one flat plane across the whole world, so lifting it
## locally is not possible. Filling the trench in behind the dam produces the
## same thing a child sees — still water, wider than the river, deep enough to
## swim in — and every system already agrees about the ground.
static func fill(x: float, z: float, river_x: float, built: Array) -> float:
	if built.is_empty():
		return 0.0

	var raised := 0.0
	for site in built:
		var along: float = site
		# Upstream is the direction of decreasing z, so the pond lies behind the
		# wall at greater z. Outside that stretch, nothing.
		var behind := z - along
		if behind < 0.0 or behind > POND_LENGTH:
			continue
		var across := absf(x - river_x)
		if across > POND_HALF_WIDTH:
			continue

		# Deepest at the wall and tapering upstream, the way a real pond does,
		# and feathered at the banks so there is no wall of water.
		var length_fade := 1.0 - smoothstep(POND_LENGTH * 0.45, POND_LENGTH, behind)
		var width_fade := 1.0 - smoothstep(
			POND_HALF_WIDTH * 0.55, POND_HALF_WIDTH, across
		)
		raised = maxf(raised, RISE * length_fade * width_fade)
	return raised

## Is this point on the wall of a dam that has been built?
static func on_wall(x: float, z: float, river_x: float, built: Array) -> bool:
	for site in built:
		if absf(z - float(site)) > WALL_THICKNESS * 0.5:
			continue
		if absf(x - river_x) < POND_HALF_WIDTH:
			return true
	return false

## The nearest dam site to a point, or NAN if none is within reach.
static func nearest_site(z: float, reach: float) -> float:
	var best := NAN
	var best_distance := reach
	for site in SITES:
		var distance := absf(z - site)
		if distance < best_distance:
			best_distance = distance
			best = site
	return best
