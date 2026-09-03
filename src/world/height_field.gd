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
const VALLEY_HALF_WIDTH := 38.0

## Distance from the origin where the ground starts climbing into mountains.
const MOUNTAIN_START := 210.0

## Nothing grows above this. A bare treeline is what makes a mountain read as
## high rather than as a big green lump.
const TREELINE := 86.0

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
	var hill_mask := smoothstep(VALLEY_HALF_WIDTH, VALLEY_HALF_WIDTH + 110.0, to_river)
	if hill_mask > 0.0:
		var hill := (_hills.get_noise_2d(x, z) + 1.0) * 0.5
		floor_height += pow(hill, 1.15) * 62.0 * hill_mask

	# Mountains ring the world. They are scenery first and a destination second:
	# the ridge line is what tells a child the world continues past the horizon.
	var mountain_mask := smoothstep(MOUNTAIN_START, MOUNTAIN_START + 260.0, from_origin)
	if mountain_mask > 0.0:
		var ridge := (_mountains.get_noise_2d(x, z) + 1.0) * 0.5
		floor_height += pow(ridge, 1.30) * 240.0 * mountain_mask

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
