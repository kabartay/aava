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
const RINGS := [
	{"radius": 1, "step": 1, "collide": true},
	{"radius": 3, "step": 2, "collide": true},
	{"radius": 6, "step": 4, "collide": false},
	{"radius": 9, "step": 8, "collide": false},
]

const COLOR_SAND := Color(0.83, 0.76, 0.56)
const COLOR_GRASS := Color(0.36, 0.60, 0.28)
const COLOR_MEADOW := Color(0.52, 0.68, 0.30)
const COLOR_ROCK := Color(0.44, 0.43, 0.44)
const COLOR_SNOW := Color(0.92, 0.94, 0.97)

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
