class_name HeightField
extends RefCounted

## The single source of truth for the shape of the world.
##
## Everything that needs to know where the ground is — the terrain mesh, the
## collision heightmap, tree scattering, animal spawning, the player's spawn
## point — asks this class. Keeping one function authoritative is what stops
## trees from floating and the player from falling through a hill: there is no
## second opinion about the ground anywhere in the codebase.
##
## It is a pure function of (x, z) plus a seed, so the same seed always produces
## the same valley on every device, and a chunk can be regenerated at any time
## without remembering anything.

## Water surface sits at y = 0, so anything negative is under water.
const WATER_LEVEL := 0.0

## Distance from the river centre where the flat valley floor ends.
##
## Widened along with the mountains below: a valley a kilometre across with a
## seventy-metre floor would read as a corridor between two walls rather than
## as somewhere to wander.
const VALLEY_HALF_WIDTH := 96.0

## Distance from the origin where the ground starts climbing into mountains.
##
## This single number decides how big the world is to play in. At 210 the
## walkable valley died at 300 m and everything the children were given — the
## pitch, the range, the pool, the café — was crammed within sixty metres of the
## camp, which is what it felt like.
##
## 500 gives a walkable disc about a kilometre across. It is deliberately not
## larger: the terrain streams to 576 m, so mountains much beyond this would sit
## outside the view and the world would end in haze instead of in peaks. Three
## kilometres was considered and refused for exactly that — the mountains are
## half of why the valley is worth being in.
const MOUNTAIN_START := 500.0

## Nothing grows above this. A bare treeline is what makes a mountain read as
## high rather than as a big green lump.
##
## Raised from 86: the forested band between the valley floor and the bare rock
## was only forty metres of height against peaks three hundred and thirty metres
## tall, so almost none of the ring around the valley was wooded. At 140 the
## trees climb well up the lower slopes, which is what makes the near mountains
## read as hills you could walk into and the far ones as something else.
const TREELINE := 118.0

## How high the football pitch sits. Fixed rather than sampled from the natural
## ground, because a pitch has to be level and a level surface needs one number.
const PITCH_LEVEL := 2.4

var seed: int

var _plains := FastNoiseLite.new()
var _hills := FastNoiseLite.new()
var _mountains := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _forest := FastNoiseLite.new()

func _init(world_seed: int) -> void:
	seed = world_seed

	# Gentle undulation of the valley floor: enough to stop it reading as a
	# table top, not enough to make walking annoying.
	_plains.seed = world_seed
	_plains.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_plains.frequency = 0.0045
	_plains.fractal_octaves = 3

	# Rolling hills on the shoulders of the valley.
	_hills.seed = world_seed + 1
	_hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hills.frequency = 0.0018
	_hills.fractal_octaves = 4
	_hills.fractal_gain = 0.45

	# Ridged noise gives mountains actual ridgelines instead of blobs.
	_mountains.seed = world_seed + 2
	_mountains.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_mountains.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_mountains.frequency = 0.0012
	_mountains.fractal_octaves = 5

	# Where the forest wants to be thick. Low frequency, so woods come in stands
	# of a few hundred metres with meadows between them, rather than as an even
	# sprinkle of trees over everything.
	_forest.seed = world_seed + 4
	_forest.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_forest.frequency = 0.0038
	_forest.fractal_octaves = 3

	# High-frequency grain, applied everywhere at small amplitude so slopes
	# catch the light instead of looking like polished plastic.
	_detail.seed = world_seed + 3
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail.frequency = 0.05
	_detail.fractal_octaves = 2

## Where the river's centre line sits at a given depth into the world.
## Two sine waves of different periods read as a meander rather than a snake.
func river_centre_x(z: float) -> float:
	return 46.0 * sin(z * 0.0038) + 22.0 * sin(z * 0.0111 + 1.3)

func distance_to_river(x: float, z: float) -> float:
	return absf(x - river_centre_x(z))

func height_at(x: float, z: float) -> float:
	var floor_height := _raw_height(x, z)

	# The football pitch levels the ground beneath it. This happens here, in the
	# height field, rather than in some node that draws a pitch — so the terrain
	# mesh, the collision heightmap, the trees, the pickups and the ball all
	# agree about where the ground is without any of them knowing a pitch exists.
	var pitch := Pitch.influence(x, z)
	if pitch > 0.0:
		floor_height = lerpf(floor_height, PITCH_LEVEL, pitch)

	# The playground, pool and café stand on levelled ground the same way. The
	# camp is a constant rather than the result of find_spawn_point(), because
	# that function calls height_at: asking it here would recurse, and a height
	# field that depends on a search is no longer a pure function of position
	# and seed — which is the property every other system relies on.
	var places := PlaceSpec.influence(x, z, camp_centre())
	if places > 0.0:
		floor_height = lerpf(floor_height, _place_level(), places)
		# And the pool is dug out of that levelled ground. Done here so the
		# terrain mesh, the collision heightmap, the grass and the pickups all
		# agree there is a hole, rather than a rim being drawn on flat grass.
		floor_height -= PlaceSpec.excavation(x, z, camp_centre())

	# A finished dam backs the river up into a pond. The ground is raised rather
	# than the water, because the water surface is one flat plane across the
	# whole world and cannot be lifted locally — filling the trench gives a
	# child exactly what they expect to see.
	if not dams_built.is_empty():
		floor_height += DamSpec.fill(x, z, river_centre_x(z), dams_built)

	# The lakes are carved out of the ground rather than the water being raised
	# to meet them, for the same reason the swimming pool is: the water surface
	# is one flat plane across the whole world.
	var lake := Lakes.influence(x, z)
	if lake > 0.0:
		floor_height = lerpf(floor_height, WATER_LEVEL - Lakes.DEPTH, lake)

	# Paths sink very slightly where they are walked. Applied after the places,
	# so a path running into the café's flat apron settles onto it rather than
	# cutting a groove across it.
	var path := Paths.influence_fast(x, z)
	if path > 0.0:
		floor_height -= Paths.SINK * path

	return floor_height

## How much of a walked path is at this point. Asked by the terrain when it
## chooses a colour and by the vegetation when it decides whether to grow.
func path_at(x: float, z: float) -> float:
	return Paths.influence_fast(x, z)

## The terrain before anything is levelled into it. Separated from height_at so
## that the level the flattening aims at can be read without recursing through
## the flattening itself.
func _raw_height(x: float, z: float) -> float:
	var to_river := distance_to_river(x, z)
	var from_origin := sqrt(x * x + z * z)

	# The river bed. A narrow trench, so water reads as a river and not a lake.
	var bed := -3.4
	var bank := smoothstep(6.0, 26.0, to_river)
	var floor_height := lerpf(bed, 1.6, bank)

	# Valley floor: the flat, walkable, buildable part of the world.
	floor_height += _plains.get_noise_2d(x, z) * 3.2 * bank

	# Hills grow once we are clear of the valley floor. Noise is remapped to 0..1
	# rather than used raw: fractal noise spends most of its time near zero, so
	# the signed value produced hills that never actually rose.
	# Spread over a longer run than before, so the ground rises gradually across
	# the wider valley rather than in the same short ramp as when it was small.
	var hill_mask := smoothstep(VALLEY_HALF_WIDTH, VALLEY_HALF_WIDTH + 220.0, to_river)
	if hill_mask > 0.0:
		var hill := (_hills.get_noise_2d(x, z) + 1.0) * 0.5
		floor_height += pow(hill, 1.15) * 62.0 * hill_mask

	# Mountains ring the world. They are scenery first and a destination second:
	# the ridge line is what tells a child the world continues past the horizon.
	# The ramp is short on purpose. Spread over 260 m the mountains only reached
	# a quarter of their height by the edge of what can be seen (576 m), so they
	# read as low grey hills rather than as peaks — the ring of mountains that
	# frames the valley was, in practice, not there. Over 90 m they stand up
	# properly right where the walkable ground ends, all the way round.
	var mountain_mask := smoothstep(MOUNTAIN_START, MOUNTAIN_START + 170.0, from_origin)
	if mountain_mask > 0.0:
		var ridge := (_mountains.get_noise_2d(x, z) + 1.0) * 0.5
		# Taller as well, so the highest carry snow and the lowest stay green:
		# the range wants a mix, not one uniform altitude.
		floor_height += pow(ridge, 1.12) * 430.0 * mountain_mask

	floor_height += _detail.get_noise_2d(x, z) * 0.5

	return floor_height

## Surface normal from the analytic gradient of the height function.
## Cheaper and smoother than averaging face normals, and it stays correct at
## chunk seams because it never looks at the mesh.
func normal_at(x: float, z: float, epsilon := 0.75) -> Vector3:
	var dx := height_at(x + epsilon, z) - height_at(x - epsilon, z)
	var dz := height_at(x, z + epsilon) - height_at(x, z - epsilon)
	return Vector3(-dx, 2.0 * epsilon, -dz).normalized()

## 0 on flat ground, 1 on a cliff. Used to decide rock vs grass and to keep
## trees off slopes they would visibly lean out of.
func steepness_at(x: float, z: float) -> float:
	return clampf(1.0 - normal_at(x, z).y, 0.0, 1.0) / 0.55

## How thick the forest wants to be at this point, from 0 to 1.
##
## Part of the height field rather than of the planting code, because it is a
## property of the world's shape: the same question asked twice must give the
## same answer, whether it is asked when planting a tree or when deciding where
## a deer wanders.
func forest_density_at(x: float, z: float) -> float:
	var height := height_at(x, z)
	if height > TREELINE or height < WATER_LEVEL + 0.8:
		return 0.0

	# Nothing grows on the pitch or its apron. A tree on the halfway line is
	# funny once and then it is just in the way.
	if Pitch.influence(x, z) > 0.35:
		return 0.0

	# Nor on a path, nor on the flat ground the places stand on. A tree growing
	# out of the trodden route is what makes a path look painted on rather than
	# walked.
	if Paths.influence_fast(x, z) > 0.3:
		return 0.0
	if Lakes.wet(x, z):
		return 0.0
	if PlaceSpec.influence(x, z, camp_centre()) > 0.55:
		return 0.0

	var density := (_forest.get_noise_2d(x, z) + 1.0) * 0.5
	density = smoothstep(0.42, 0.78, density)

	# A clearing along the river. Rivers cut through forests in life, and here it
	# also keeps the most walkable part of the world open for building.
	density *= smoothstep(10.0, 34.0, distance_to_river(x, z))

	# Trees thin out as the ground steepens and stop where nothing could root.
	density *= 1.0 - smoothstep(0.28, 0.62, steepness_at(x, z))

	# And they thin towards the treeline instead of stopping at a hard line.
	density *= 1.0 - smoothstep(TREELINE - 26.0, TREELINE, height)

	return clampf(density, 0.0, 1.0)

## Which dam sites have been finished. Set by the game, exactly like the felled
## trees: the field stays a pure function of position and seed *plus* this
## explicit record, rather than reaching out to ask a node what has been built.
var dams_built: Array = []

## Where the camp is. Fixed rather than searched for, because the ground under
## the camp's buildings is levelled inside height_at and a search would have to
## call it — see the note there.
##
## Chosen by walking the same ring pattern find_spawn_point used, on the raw
## terrain, and taking a spot that is dry, gentle and clear of the river.
func camp_centre() -> Vector3:
	return Vector3(0.0, 0.0, 18.0)

## The height the levelled ground around the camp settles at. Read from the raw
## terrain at the camp so the buildings sit at the valley's own level rather
## than on a plateau of their own.
func _place_level() -> float:
	if _cached_place_level < -1e8:
		var camp := camp_centre()
		# Deliberately not height_at: that would recurse straight back into the
		# levelling this value is for.
		_cached_place_level = _raw_height(camp.x, camp.z)
	return _cached_place_level

var _cached_place_level := -1e9

## A calm, flat, dry spot near the river to put the player and the first camp.
func find_spawn_point() -> Vector3:
	var radii := PackedFloat32Array([0.0, 18.0, 36.0, 60.0, 90.0])
	for radius in radii:
		for step in 12:
			var angle := TAU * float(step) / 12.0
			var x := cos(angle) * radius
			var z := sin(angle) * radius
			var y := height_at(x, z)
			if y > WATER_LEVEL + 1.2 and steepness_at(x, z) < 0.25:
				return Vector3(x, y, z)
	return Vector3(0.0, height_at(0.0, 0.0), 0.0)
