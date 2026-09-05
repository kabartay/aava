class_name TerrainSpec
extends RefCounted

## Shared terrain constants.
##
## These live in their own dependency-free script on purpose. Terrain manages
## chunks and TerrainChunk builds one, so each needs the other's numbers — and
## two class_name scripts that reference each other are a cyclic dependency that
## hangs Godot's loader outright. Constants in a leaf script break the cycle.

## Side of one chunk in metres, and the number of quads at full detail, because
## the height field is sampled once per metre at ring zero.
const CHUNK_SIZE := 64

## Sampling step per detail ring and how far out each ring reaches, in chunks.
## Ring zero is where the player stands, so it is the only detail that has to
## survive a camera two metres off the ground.
## Rings of decreasing detail around the player. `radius` is in chunks,
## Chebyshev distance, so ring 9 means a 19x19 grid — 361 chunks and therefore
## 361 draw calls every frame.
##
## That number is fine on a desktop and is the first thing that will hurt on a
## tablet, where draw calls cost far more than triangles. The outer ring is now
## twice as coarse: at step 16 a chunk two hundred metres away is eight
## triangles across, which is invisible at that distance and halves the vertex
## work for the third of the world that is furthest from the camera.
const RINGS := [
	{"radius": 1, "step": 1, "collide": true},
	{"radius": 3, "step": 2, "collide": true},
	{"radius": 6, "step": 4, "collide": false},
	{"radius": 9, "step": 16, "collide": false},
]

const COLOR_SAND := Color(0.83, 0.76, 0.56)
const COLOR_GRASS := Color(0.36, 0.60, 0.28)

## Bare, trodden earth. Warmer and lighter than the grass so a route reads from
## a distance, which is the entire purpose of a path.
const COLOR_PATH := Color(0.62, 0.52, 0.36)
const COLOR_MEADOW := Color(0.52, 0.68, 0.30)
const COLOR_ROCK := Color(0.44, 0.43, 0.44)
const COLOR_SNOW := Color(0.92, 0.94, 0.97)

## Mown grass, and the paint on it. Two tones of green rather than one, because
## a pitch that is the same colour as the meadow does not read as a pitch.
const COLOR_PITCH_DARK := Color(0.21, 0.47, 0.22)
const COLOR_PITCH_LIGHT := Color(0.34, 0.65, 0.30)
const COLOR_PITCH_LINE := Color(0.93, 0.95, 0.92)

## Width of the painted lines, in metres.
const LINE_WIDTH := 0.24

## Width of a mown stripe. Stripes are what make grass read as tended.
const STRIPE_WIDTH := 5.0

## Which detail ring a chunk at this Chebyshev distance belongs to, or -1 if it
## is beyond the last ring and should not exist.
static func ring_for(chebyshev_distance: int) -> int:
	for i in RINGS.size():
		if chebyshev_distance <= int(RINGS[i]["radius"]):
			return i
	return -1

static func chunk_at(world_position: Vector3) -> Vector2i:
	return Vector2i(
		floori(world_position.x / float(CHUNK_SIZE)),
		floori(world_position.z / float(CHUNK_SIZE))
	)
