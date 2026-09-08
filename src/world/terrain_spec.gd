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

## Physics layers. The ground is on the first, like everything Godot puts there
## by default. Thin props — swing posts, tree trunks, a bin — are on PROPS: the
## player and the balls collide with it, the camera's spring arm does not.
## Before this the arm caught on every post and trunk it passed, shortening
## and lengthening a few centimetres a frame, and the whole view rattled when
## a child walked up to the slide.
const LAYER_GROUND := 1
const LAYER_PROPS := 4
## Walls a camera must not pass through: the café's, so a child sitting at a
## table is not watched from outside the building with the wall in the way.
## Furniture stays off this layer, for the rattling reason above.
const LAYER_WALLS := 8

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
	## Step 1, not 2. Halving the mesh resolution here looks like a saving and is
	## not: the collision grid is full resolution either way, and at step 1 the
	## mesh and the collision share one set of samples. At step 2 they no longer
	## match, collision samples the field all over again, and the chunk costs
	## more than it did before — 22.4 ms against 14.6.
	{"radius": 1, "step": 1, "collide": true},
	{"radius": 3, "step": 2, "collide": true},
	{"radius": 6, "step": 4, "collide": false},
	{"radius": 9, "step": 16, "collide": false},
]

const COLOR_SAND := Color(0.83, 0.76, 0.56)
## The bed under water: silt, dark and green-blue. Ground below the waterline
## was painted the same sand as the beach, so a hollow full of water — a
## backwater beside the river, a dip near a pond — read as a patch of sand
## you then sank into up to the chest. Sand is what a beach is; the bed of
## the water is not a beach.
const COLOR_SILT := Color(0.29, 0.38, 0.33)
const COLOR_GRASS := Color(0.36, 0.60, 0.28)

## Bare, trodden earth. Warmer and lighter than the grass so a route reads from
## a distance, which is the entire purpose of a path.
const COLOR_PATH := Color(0.62, 0.52, 0.36)
## Ground worn bare by many feet: a shade yellower than a single path, since it
## is trodden from every direction and dries out in the sun.
const COLOR_TRODDEN := Color(0.68, 0.58, 0.38)
const COLOR_MEADOW := Color(0.52, 0.68, 0.30)
const COLOR_ROCK := Color(0.44, 0.43, 0.44)
## Forest seen from far off, where no single tree can be made out: a
## hillside under trees is darker and bluer than the grass beside it, and
## that darkening is the whole of what a distant wood looks like.
const COLOR_FOREST_FAR := Color(0.21, 0.34, 0.24)
const COLOR_SNOW := Color(0.92, 0.94, 0.97)

## Glacier ice, for the high ground gentle enough for it to gather on. Bluer
## and slightly darker than snow: an unbroken white cap reads as icing, and it
## is the difference between the two that makes a range look like the Alps
## rather than like a hill in winter.
const COLOR_ICE := Color(0.78, 0.86, 0.94)

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
