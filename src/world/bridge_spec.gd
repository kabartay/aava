class_name BridgeSpec
extends RefCounted

## Where the bridge crosses the river, and what shape its deck is.
##
## A wheeled machine cannot ford the river — a bicycle ridden into the water
## puts its rider down on the bank, which is right: you do not swim a
## motorcycle across. But that left the whole eastern half of the valley
## unreachable on anything with wheels, and a child who has just spent three
## hundred coins on a motorcycle should not find half the world closed to it.
## So there is one crossing, and it is a bridge: on foot or on a horse you may
## swim, and on wheels you take the bridge like everybody else.
##
## It stands across the river from the football pitch and the swimming pool,
## between the two of them — the part of the valley a child already knows, so
## the crossing is found by walking rather than by searching.
##
## Dependency-free, like PlaceSpec and Pitch, and for the same reason: the
## height field and the vegetation both have to know where the bridge is, and a
## class_name cycle hangs Godot's loader outright. Where it needs to know where
## the river is, it is told — exactly as DamSpec is.

## Where along the river it crosses. The pitch is at z = 34 and the pool at
## z = 86; the bridge sits between them, so it is opposite both and in the way
## of neither.
const CENTRE_Z := 60.0

## How far the deck reaches either side of the river's centre line. The water
## is sixteen metres of half-width and the bank climbs for another ten, so this
## lands both ends on ground a child can walk onto rather than on the slope.
const HALF_SPAN := 28.0

## Half the width of the deck. Wide enough for a horse and a motorcycle to pass
## without either going over the side.
const HALF_WIDTH := 3.2

## How high the middle of the deck rides above the straight line between its
## two ends. This is what keeps it clear of the water, and what makes it read
## as a bridge rather than as a plank: a flat deck at bank height looks like
## the ground continuing.
const LIFT := 2.2

## Railing height, and how far the rails stand in from the deck's edge.
const RAIL_HEIGHT := 1.05
const RAIL_INSET := 0.25

## How far out from the deck nothing may grow, so a pine does not come up
## through the planks.
const CLEARING := 6.0

## How far above or below the deck a rider still counts as being on it, rather
## than swimming underneath it.
const ON_DECK_REACH := 2.2

## A hair of slack at the very edge of the deck. Asking for the height exactly
## at the abutment — which is what the builder and the checks both do — came
## out a millionth of a metre outside the span and was told there was no bridge
## there.
const EDGE_SLACK := 0.001

## Is this point over the deck?
static func on_deck(x: float, z: float, river_x: float) -> bool:
	return (
		absf(z - CENTRE_Z) <= HALF_WIDTH + EDGE_SLACK
		and absf(x - river_x) <= HALF_SPAN + EDGE_SLACK
	)

## Is this close enough to the crossing that nothing should be planted?
static func clear_of_trees(x: float, z: float, river_x: float) -> bool:
	return (
		absf(z - CENTRE_Z) <= HALF_WIDTH + CLEARING
		and absf(x - river_x) <= HALF_SPAN + CLEARING
	)

## How far across the bridge this point is, from 0 at the western end to 1 at
## the eastern one.
static func across(x: float, river_x: float) -> float:
	return clampf((x - river_x + HALF_SPAN) / (HALF_SPAN * 2.0), 0.0, 1.0)

## The height of the deck at a point, given the ground under each of its two
## ends.
##
## The deck meets the ground exactly where it lands — a bridge that ends a step
## above the bank is a thing a child trips on, and a machine bounces off — and
## arches between, which is where the clearance over the water comes from. The
## arch is a half sine, so the slope is gentlest at the two ends, where a rider
## is joining it.
static func deck_height(x: float, river_x: float, west: float, east: float) -> float:
	var along := across(x, river_x)
	return lerpf(west, east, along) + LIFT * sin(PI * along)
