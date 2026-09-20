class_name ParkSpec
extends RefCounted

## Where the fairground is, and how the ground under it is made flat.
##
## The rides need level, dry, open ground over a stretch the size of a village
## green, and the valley floor east of the river is the one place that has it.
## Like the football pitch, the flattening lives in the height field rather
## than in the node that builds the rides — so the terrain mesh, the collision,
## the grass, the trees, the boulders and the animals all agree that there is a
## fairground here without any of them being told one exists.
##
## RefCounted with no dependencies, for the reason TerrainSpec and Pitch are:
## HeightField needs it, and a cyclic class_name dependency hangs the loader.

## The fence line, as a box in world coordinates. Long axis along the river,
## which runs north and south here; the short side at the southern end is where
## the road passes, and where the gate is.
const WEST := 56.0
const EAST := 96.0
## Remember that north is -z in this valley.
const SOUTH := 16.0
const NORTH := -152.0

## What the whole ground is levelled to. Chosen a little above the flood plain
## it stands on, so the fairground is a dry platform rather than a hollow that
## fills when the river is high.
const LEVEL := 3.0

## How far the levelling eases back into the valley. Long, because the drop at
## the southern end is nearly three metres and a short feather there is a wall.
const FEATHER := 14.0

## How far inside the fence nothing may be built, so a child can walk right
## round the inside of it.
const VERGE := 3.5

static func length() -> float:
	return SOUTH - NORTH

static func width() -> float:
	return EAST - WEST

static func centre() -> Vector3:
	return Vector3((WEST + EAST) * 0.5, LEVEL, (SOUTH + NORTH) * 0.5)

## Where the way in is: the middle of the southern fence, the side the road
## from the bridge runs past.
static func gate() -> Vector3:
	return Vector3((WEST + EAST) * 0.5, LEVEL, SOUTH)

## How wide the gateway is.
const GATE_WIDTH := 7.0

static func inside(x: float, z: float) -> bool:
	return x >= WEST and x <= EAST and z <= SOUTH and z >= NORTH

## Is this inside the fence with room to spare — the ground a ride may stand
## on?
static func buildable(x: float, z: float) -> bool:
	return (
		x >= WEST + VERGE and x <= EAST - VERGE
		and z <= SOUTH - VERGE and z >= NORTH + VERGE
	)

## How strongly the fairground claims this ground: one inside the fence, easing
## to nothing over the feather beyond it.
static func influence(x: float, z: float) -> float:
	var out := maxf(
		maxf(WEST - x, x - EAST),
		maxf(z - SOUTH, NORTH - z)
	)
	if out <= 0.0:
		return 1.0
	return 1.0 - smoothstep(0.0, FEATHER, out)

## Whether the fairground reaches into this square at all, so a chunk can ask
## once instead of once per vertex.
static func touches_box(x0: float, z0: float, x1: float, z1: float) -> bool:
	return not (
		x1 < WEST - FEATHER or x0 > EAST + FEATHER
		or z1 < NORTH - FEATHER or z0 > SOUTH + FEATHER
	)

## How much of the ground here is trodden sand rather than meadow. Full inside
## the fence and fading just past it, so the fairground has an edge rather than
## a halo.
static func sand(x: float, z: float) -> float:
	var out := maxf(
		maxf(WEST - x, x - EAST),
		maxf(z - SOUTH, NORTH - z)
	)
	if out <= 0.0:
		return 1.0
	return 1.0 - smoothstep(0.0, 3.0, out)
