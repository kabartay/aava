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

## Goal geometry. Small enough that a ten-year-old has to aim, big enough
## that a six-year-old scores. It was 5.2 by 2.1: kicked from anywhere in the
## attacking half with a child's wobble of about fourteen degrees, a little over
## half of shots went in; at 6.5 it is about two in three, while a careful aim
## still beats a careless one (eight in ten against nineteen in twenty at
## eight metres, where it stops being a game).
const GOAL_WIDTH := 6.5
const GOAL_HEIGHT := 2.4
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

## True on the pitch, on its apron, or within `margin` metres of it: where the
## score is worth showing, because the game is there to be looked at.
static func is_beside(x: float, z: float, margin: float) -> bool:
	return (
		absf(x - CENTRE.x) <= HALF_LENGTH + APRON + margin
		and absf(z - CENTRE.z) <= HALF_WIDTH + APRON + margin
	)

## The centre of each goal mouth, at ground level. Index 0 is the goal at
## negative x, index 1 the goal at positive x.
static func goal_centre(index: int) -> Vector3:
	var sign := -1.0 if index == 0 else 1.0
	return CENTRE + Vector3(sign * (HALF_LENGTH - GOAL_INSET), 0.0, 0.0)

## Has the ball crossed this goal line, between the posts and under the bar?
## `surface` is the height of the grass at the goal: goal_centre sits at y = 0
## but the pitch is levelled well above that, so without it every ball on the
## pitch was taller than the bar and no goal could ever be given.
static func is_goal(index: int, ball: Vector3, ball_radius: float, surface := 0.0) -> bool:
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
	# Under the net, not merely under the bar's height: the back of the net
	# slopes from the crossbar down to the ground, and a ball chipped over the
	# bar and dropping onto the outside of that slope is still under 2.1 m and
	# past the line, and was given as a goal.
	var roof := lerpf(GOAL_HEIGHT, 0.06, clampf(beyond / GOAL_DEPTH, 0.0, 1.0))
	return ball.y - surface < roof

## The scoreboard: five metres tall, at the middle of the north touchline and
## one metre outside the apron, so it is never on the pitch or the run-up and
## can be read from the far touchline. Its numbers live here, in the leaf
## script, because KeepOut has to keep builders off it and the football ground
## has to build it, and neither may depend on the other.
const BOARD_HEIGHT := 5.0
const BOARD_HALF_WIDTH := 3.2
const BOARD_THICKNESS := 0.3
## The dark board itself is this tall, hung from the top of the legs.
const BOARD_FACE := 2.4
const LEG_HALF := 0.17

## What standing at its foot is called, for the place offer: "new game".
const SCOREBOARD := &"scoreboard"

## How near the foot a child must be to be offered a new game.
const BOARD_REACH_SIDE := 4.5
const BOARD_REACH_NORTH := 3.0
const BOARD_REACH_SOUTH := 4.5

## Where the board's legs stand, on the ground: the middle of the north
## touchline, just past the apron.
static func scoreboard_foot() -> Vector3:
	return Vector3(CENTRE.x, 0.0, CENTRE.z - HALF_WIDTH - APRON - 1.0)

## Is this point at the foot of the scoreboard, near enough to offer a new game?
static func near_scoreboard(x: float, z: float) -> bool:
	var foot := scoreboard_foot()
	return (
		absf(x - foot.x) <= BOARD_REACH_SIDE
		and z >= foot.z - BOARD_REACH_NORTH
		and z <= foot.z + BOARD_REACH_SOUTH
	)

## Ground the scoreboard stands on, with `back` of clear ground round its sides
## and behind it. Its front is the apron, which is kept already.
static func under_scoreboard(x: float, z: float, back: float) -> bool:
	var foot := scoreboard_foot()
	return (
		absf(x - foot.x) < BOARD_HALF_WIDTH + back
		and z < foot.z + BOARD_THICKNESS * 0.5 + back
		and z > foot.z - BOARD_THICKNESS * 0.5 - back
	)

## Does a flight, given as the points a ball passes through, end up in a goal
## mouth? Walked segment by segment, because a hard shot moves further between
## two dots than a goal is deep, and a test of the dots alone would miss it.
## The ball is judged where it first has its whole width over the line, by the
## same `is_goal` that gives the goal. `ground` answers the grass height.
## Returns the goal's index, or -1.
static func goal_ahead(points: PackedVector3Array, ball_radius: float, ground: Callable) -> int:
	for index in 2:
		var mouth := goal_centre(index)
		var surface := float(ground.call(mouth.x, mouth.z))
		var sign := -1.0 if index == 0 else 1.0
		var line := mouth.x + sign * (ball_radius + 0.001)
		for i in range(1, points.size()):
			var a := points[i - 1]
			var b := points[i]
			# Only a segment that carries the ball over the line this step.
			if (a.x - line) * sign >= 0.0 or (b.x - line) * sign < 0.0:
				continue
			var t := (line - a.x) / (b.x - a.x)
			if is_goal(index, a.lerp(b, t), ball_radius, surface):
				return index
	return -1
