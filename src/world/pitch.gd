class_name Pitch
extends RefCounted

## Where the football pitch is, and how it flattens the ground under itself.
##
## This is not decoration bolted onto the terrain: a pitch on procedural ground
## is unplayable, because a ball on a one-in-five slope rolls away and never
## comes back. So the pitch is part of the world's shape. HeightField asks this
## class before returning a height, which means the flattening is known to the
## terrain mesh, the collision heightmap, the tree scattering, the pickups and
## the ball — all of which read the height field and none of which need to be
## told that a pitch exists.
##
## It is a RefCounted with no dependencies for the same reason TerrainSpec is:
## HeightField needs it, and a cyclic class_name dependency hangs Godot's
## loader outright.

## Half-extents of the playing surface, in metres. A real pitch is 105 x 68,
## which is far too big for a six-year-old to chase a ball across; this is about
## a third of that, the size of a school five-a-side court.
const HALF_LENGTH := 20.0
const HALF_WIDTH := 13.0

## How far past the touchline the ground stays flat, so there is room to stand
## and take a run-up, and the slope back to the valley starts outside play.
const APRON := 5.0

## Over what distance the flattening blends back into the natural ground. Too
## short and the pitch sits on a plinth; too long and it swallows the valley.
const BLEND := 22.0

## Where the pitch sits, and how high its surface is. It is placed a short walk
## from the spawn, on the meadow side of the river rather than across it: a
## six-year-old should be able to find it by walking, without a bridge.
const CENTRE := Vector3(-46.0, 0.0, 34.0)

## Goal geometry. Small enough that a child scores, wide enough that a
## ten-year-old has to aim.
const GOAL_WIDTH := 5.2
const GOAL_HEIGHT := 2.1
const GOAL_DEPTH := 1.6
const POST_RADIUS := 0.11

## How far the goal mouth sits inside the touchline.
const GOAL_INSET := 0.6

static func centre() -> Vector3:
	return CENTRE

## 1 inside the pitch, falling to 0 out in the valley. Everything about the
## pitch — its height, its grass colour, whether trees may grow — is this one
## number, so the surface, the paint and the planting can never disagree about
## where the pitch is.
## Whether a box comes near enough to the pitch for any of it to matter. Lets a
## whole terrain chunk skip the pitch in one test instead of once per vertex.
static func touches_box(x0: float, z0: float, x1: float, z1: float) -> bool:
	var reach_x := HALF_LENGTH + 40.0
	var reach_z := HALF_WIDTH + 40.0
	if x1 < CENTRE.x - reach_x or x0 > CENTRE.x + reach_x:
		return false
	if z1 < CENTRE.z - reach_z or z0 > CENTRE.z + reach_z:
		return false
	return true

static func influence(x: float, z: float) -> float:
	var dx := absf(x - CENTRE.x) - (HALF_LENGTH + APRON)
	var dz := absf(z - CENTRE.z) - (HALF_WIDTH + APRON)
	# Distance outside the flat rectangle, as a rounded rectangle rather than a
	# cross, so the corners blend as smoothly as the sides.
	var outside := Vector2(maxf(dx, 0.0), maxf(dz, 0.0)).length()
	return 1.0 - smoothstep(0.0, BLEND, outside)

## True on the mown surface itself, inside the touchlines.
static func is_in_play(x: float, z: float) -> bool:
	return (
		absf(x - CENTRE.x) <= HALF_LENGTH
		and absf(z - CENTRE.z) <= HALF_WIDTH
	)

## True anywhere the ground has been levelled, including the apron.
static func is_levelled(x: float, z: float) -> bool:
	return (
		absf(x - CENTRE.x) <= HALF_LENGTH + APRON
		and absf(z - CENTRE.z) <= HALF_WIDTH + APRON
	)

## The centre of each goal mouth, at ground level. Index 0 is the goal at
## negative x, index 1 the goal at positive x.
static func goal_centre(index: int) -> Vector3:
	var sign := -1.0 if index == 0 else 1.0
	return CENTRE + Vector3(sign * (HALF_LENGTH - GOAL_INSET), 0.0, 0.0)

## Has the ball crossed this goal line, between the posts and under the bar?
static func is_goal(index: int, ball: Vector3, ball_radius: float) -> bool:
	var mouth := goal_centre(index)
	var beyond := (mouth.x - ball.x) if index == 0 else (ball.x - mouth.x)
	# The whole ball must be over the line, which is the actual rule and also
	# stops a ball resting on the line from scoring over and over.
	if beyond < ball_radius:
		return false
	if beyond > GOAL_DEPTH + ball_radius * 2.0:
		return false
	if absf(ball.z - mouth.z) > GOAL_WIDTH * 0.5 - ball_radius:
		return false
	return ball.y - mouth.y < GOAL_HEIGHT
