class_name Vegetation
extends Node3D

## Plants everything, streamed in tiles around the player.
##
## Grass only exists close by, trees much further out. That split is the whole
## performance strategy: grass is what sells the ground underfoot and is
## invisible at fifty metres, while trees are what give the valley its shape
## from across the water.

const TILE_SIZE := 32

## Radius in tiles. Trees reach much further than grass because they are what
## the horizon is made of.
const TREE_RADIUS := 8
const GRASS_RADIUS := 2

## Tiles built per frame. Planting a tile is heavier than building a terrain
## chunk, so this is deliberately lower.
const TILES_PER_FRAME := 1

## How many tiles may be baking on the pool at once, and how many finished
## bakes become instances in one frame. The terrain has the same pair, for the
## same reason: a burst of completions landing together would be the old hitch
## in a smaller hat.
const BAKES_IN_FLIGHT := 2
const ASSEMBLED_PER_FRAME := 1

## Wind. One shader serves every plant; the uniforms are what make grass whip
## and a conifer barely lean.
const WIND_SHADER := """
shader_type spatial;
render_mode world_vertex_coords, cull_disabled, diffuse_lambert, specular_disabled;

// How far the top of the plant moves, in metres, and how tall the plant is:
// the bend is a fraction of its own height rather than of how many metres
// above its root a vertex happens to be.
//
// It used to be pow(height_above_root, stiffness) * strength, which for a
// six-metre tree raised six to the power of 1.6 and multiplied: the crown
// swung a metre and a half either way, some thirty degrees, and a wooden
// trunk does not do that. Grass and trees share one shader, and only one of
// them could be tuned right by that formula.
uniform float sway_amplitude = 0.2;
uniform float plant_height = 6.4;
uniform float sway_speed = 1.3;
uniform float stiffness = 1.6;
uniform float gust_scale = 0.012;
// The valley's one wind (see Wind): the way the air is going, and how hard.
uniform vec2 wind_direction = vec2(0.7, 0.7);
uniform float wind_strength = 0.6;
uniform float wind_clock = 0.0;

void vertex() {
	// MODEL_MATRIX carries the per-instance transform inside a MultiMesh, so
	// this is where each plant gets its own phase and stops swaying in unison.
	vec3 origin = MODEL_MATRIX[3].xyz;
	// Measured in the plant's own units: a tree grown half as tall again is
	// still bent along its whole length, not rigidly shoved above 6.4 m.
	float local_height = max(VERTEX.y - origin.y, 0.0) / max(length(MODEL_MATRIX[1].xyz), 0.001);

	// Deliberately nothing here reads the camera or the screen: in a shadow
	// pass those describe the light instead, and the shadow would swing away
	// from the plant casting it.
	//
	// The phase is a hash of where the plant stands. It was a plane
	// (x * 0.31 + z * 0.23), so neighbours differed by a fraction of a radian
	// and the whole meadow rolled in diagonal stripes, in step.
	float phase = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453) * 6.2831853;
	// A gust is a front that travels with the wind, so it crosses the meadow
	// downwind rather than pulsing in place.
	float front = dot(origin.xz, wind_direction) * gust_scale - wind_clock * 0.27;
	float gust = (sin(front) * 0.25 + 0.75) * (0.35 + 0.65 * wind_strength);
	// The shared clock, not TIME: TIME rolls over every hour, and with it
	// every plant in the valley would jump to a new phase at once.
	float t = wind_clock * sway_speed + phase;

	// Bending grows towards the top of the plant, so the trunk stays put and
	// only the crown moves — the higher the stiffness the more the movement
	// is confined to the thin end.
	float along = clamp(local_height / max(plant_height, 0.001), 0.0, 1.0);
	float bend = pow(along, stiffness) * sway_amplitude * gust;
	// Every plant leans downwind and flutters about that lean; only the
	// flutter takes the plant's own phase. Across the wind it moves less.
	vec2 across = vec2(-wind_direction.y, wind_direction.x);
	vec2 move = wind_direction * (0.6 + 0.4 * sin(t)) + across * cos(t * 0.81) * 0.25;
	VERTEX.xz += move * bend;
}

void fragment() {
	// Vertex colours are authored as sRGB, which is how they were chosen, so
	// they have to be linearised here or every plant comes out washed out.
	ALBEDO = pow(COLOR.rgb, vec3(2.2));
	ROUGHNESS = 0.92;
}
"""

var field: HeightField
var world_seed: int

var _conifer: Mesh
var _broadleaf: Mesh
var _grass: Mesh
var _tree_material: ShaderMaterial
var _grass_material: ShaderMaterial

var _tiles: Dictionary = {}
var _queue: Array[Vector2i] = []

## Tiles baking on a worker, by coordinate; finished bakes waiting to become
## instances; the mutex guards only the handover. A bake carries the
## generation it started in, and felling a tree bumps it — a tile baked before
## the axe fell describes a forest that no longer exists.
var _baking: Dictionary = {}
var _finished: Array = []
var _finished_mutex := Mutex.new()
var _generation := 0
var _centre := Vector2i(9999, 9999)

## Trees that have been cut down. Set by the world before streaming begins.
var felled: Felled = null
var _stump: Mesh

func _init(height_field: HeightField, seed_value: int) -> void:
	field = height_field
	world_seed = seed_value
	# Built here, not in _ready: a node used before the tree starts processing
	# never receives _ready, and the failure is silent.
	_conifer = PlantMeshes.conifer(VegetationTile.CONIFER_HEIGHT)
	_broadleaf = PlantMeshes.broadleaf(VegetationTile.BROADLEAF_HEIGHT)
	_grass = PlantMeshes.grass_tuft(0.34, 5)
	_stump = PlantMeshes.stump(0.24)

	var shader := Shader.new()
	shader.code = WIND_SHADER

	_tree_material = ShaderMaterial.new()
	_tree_material.shader = shader
	# A quarter of a metre at the crown of a six-metre tree: about two degrees,
	# which is a tree in a breeze. Stiff, so the trunk itself is still.
	_tree_material.set_shader_parameter("sway_amplitude", 0.26)
	_tree_material.set_shader_parameter("plant_height", 6.4)
	_tree_material.set_shader_parameter("stiffness", 2.6)
	_tree_material.set_shader_parameter("sway_speed", 0.9)

	_grass_material = ShaderMaterial.new()
	_grass_material.shader = shader
	# Grass is all thin end: its tips move a good part of their own height,
	# which is what makes a meadow read as moving at all.
	_grass_material.set_shader_parameter("sway_amplitude", 0.12)
	_grass_material.set_shader_parameter("plant_height", 0.3)
	_grass_material.set_shader_parameter("stiffness", 1.3)
	_grass_material.set_shader_parameter("sway_speed", 2.1)

## Hands the shared wind to both materials, so every plant reads the same air.
func _blow() -> void:
	# Worked out once and handed to both: it used to be a fresh array and the
	# same trigonometry twice, every frame.
	var now := Wind.clock()
	var direction := Wind.direction(now)
	var strength := Wind.strength(now)
	_set_wind(_tree_material, direction, strength, now)
	_set_wind(_grass_material, direction, strength, now)

func _set_wind(material: ShaderMaterial, direction: Vector2, strength: float, now: float) -> void:
	material.set_shader_parameter("wind_direction", direction)
	material.set_shader_parameter("wind_strength", strength)
	material.set_shader_parameter("wind_clock", now)

func follow(world_position: Vector3) -> void:
	var tile := Vector2i(
		floori(world_position.x / float(TILE_SIZE)),
		floori(world_position.z / float(TILE_SIZE))
	)
	if tile == _centre:
		return
	_centre = tile
	_rebuild_queue()

## The nearest standing tree to a point, or an empty vector if there is none in
## reach.
##
## This replays the same generator the tile used, for the tile the player is
## standing in and its neighbours. It is not a search of anything stored,
## because nothing is stored: the forest exists only as instance transforms
## inside a MultiMesh. Replaying is cheap — three tiles of 46 candidates — and
## it is guaranteed to agree with what is drawn, which a parallel list of tree
## positions would not be.
## Cached, because this is asked every frame to decide whether to show the chop
## button, and answering it costs nine tiles of forty-six candidates — some four
## hundred noise lookups — for a question whose answer only changes when the
## player moves a metre or a tree comes down.
var _tree_query_at := Vector3(1e9, 1e9, 1e9)
var _tree_query_reach := -1.0
var _tree_query_result := Vector3.ZERO
var _tree_query_found := false

## The nearest standing tree, and whether there was one at all. The second
## return matters: Vector3.ZERO is a position a tree can genuinely occupy, so it
## cannot also mean "none".
func nearest_tree_found(world_position: Vector3, reach: float) -> Array:
	if (
		is_equal_approx(reach, _tree_query_reach)
		and world_position.distance_squared_to(_tree_query_at) < 0.25
	):
		return [_tree_query_result, _tree_query_found]

	var answer := _search_tree(world_position, reach)
	_tree_query_at = world_position
	_tree_query_reach = reach
	_tree_query_result = answer[0]
	_tree_query_found = answer[1]
	return answer

## Counts every change to which trees stand. Read by the trunk pool, which has to
## choose again when it moves even though nobody has walked anywhere.
func forest_generation() -> int:
	return _generation

## Invalidate the cache. Called when the forest changes under it.
func forget_tree_query() -> void:
	_tree_query_at = Vector3(1e9, 1e9, 1e9)

func nearest_tree(world_position: Vector3, reach: float) -> Vector3:
	return nearest_tree_found(world_position, reach)[0]

## Every standing tree within reach, nearest first.
##
## The same 3x3 tile scan the axe uses, kept here rather than in the collision
## pool so that the generator stays the one place that knows where trees are.
func trees_near(world_position: Vector3, reach: float) -> Array[Vector3]:
	var places: Array[Vector3] = []
	for trunk in trunks_near(world_position, reach):
		places.append(Vector3(trunk.x, trunk.y, trunk.z))
	return places

## The same trees with their trunk radius in `w`, nearest first.
func trunks_near(world_position: Vector3, reach: float) -> Array[Vector4]:
	var found: Array[Vector4] = []
	var base := Vector2i(
		int(floor(world_position.x / float(TILE_SIZE))),
		int(floor(world_position.z / float(TILE_SIZE)))
	)
	for dx: int in [-1, 0, 1]:
		for dz: int in [-1, 0, 1]:
			var coord := Vector2i(base.x + dx, base.y + dz)
			var trees := _trees_in(coord)
			var radii: PackedFloat32Array = _radius_cache[coord]
			for i in trees.size():
				var candidate := trees[i]
				var flat := Vector2(
					candidate.x - world_position.x, candidate.z - world_position.z
				)
				if flat.length() <= reach:
					found.append(Vector4(candidate.x, candidate.y, candidate.z, radii[i]))
	found.sort_custom(func(a: Vector4, b: Vector4) -> bool:
		return (
			Vector2(a.x - world_position.x, a.z - world_position.z).length_squared()
			< Vector2(b.x - world_position.x, b.z - world_position.z).length_squared()
		))
	return found

func _search_tree(world_position: Vector3, reach: float) -> Array:
	var best := Vector3.ZERO
	var found := false
	var best_distance := reach
	var base := Vector2i(
		int(floor(world_position.x / float(TILE_SIZE))),
		int(floor(world_position.z / float(TILE_SIZE)))
	)
	for dx: int in [-1, 0, 1]:
		for dz: int in [-1, 0, 1]:
			var coord := Vector2i(base.x + dx, base.y + dz)
			for candidate in _trees_in(coord):
				var flat := Vector2(candidate.x - world_position.x, candidate.z - world_position.z)
				var distance := flat.length()
				if distance < best_distance:
					best_distance = distance
					best = candidate
					found = true
	return [best, found]

## Every standing tree in one tile, from the one generator that also draws them.
## Where the trees are in one tile, remembered.
##
## This generated the whole tile afresh on every call: forty-six candidates,
## each asking the height field for its ground, its forest density and whether
## it stands in a pond. `trees_near` asks for nine tiles, and the solid-trunk
## pool asks `trees_near` every four metres a child walks — so walking across
## the valley regenerated four hundred candidates several times a second, on
## the main thread, for ever. On a phone that was 600 ms in a frame and the
## game ran at one frame a second; the perf log named it `trunks` and it was
## the largest single cost in the game.
##
## The answer is simply to keep the answer. A tile's trees do not change unless
## one is felled, and `_generation` already counts that.
var _tree_cache: Dictionary = {}
var _tree_cache_generation := -1

func _trees_in(coord: Vector2i) -> Array[Vector3]:
	if _tree_cache_generation != _generation:
		_tree_cache.clear()
		_radius_cache.clear()
		_tree_cache_generation = _generation
	var remembered = _tree_cache.get(coord)
	if remembered != null:
		return remembered
	var out: Array[Vector3] = []
	var radii := PackedFloat32Array()
	for tree in VegetationTile.generate_trees(field, coord, TILE_SIZE, world_seed, felled):
		out.append(tree["position"])
		radii.append(tree["radius"])
	# A cap, so walking the whole valley does not remember all of it: the pool
	# only ever looks at nine tiles, and a few dozen is already generous.
	if _tree_cache.size() > TREE_CACHE_TILES:
		_tree_cache.clear()
		_radius_cache.clear()
	_tree_cache[coord] = out
	_radius_cache[coord] = radii
	return out

## How thick each tree in `_tree_cache` is, in the same order, so the solid trunk
## standing in for a tree can be as wide as the one drawn.
var _radius_cache: Dictionary = {}

## How many tiles' worth of tree positions to keep. Nine are in use at any
## moment; this is room for a good walk around before it is thrown away.
const TREE_CACHE_TILES := 48

## Rebuild every tile now, because a tree has been felled and the forest as
## drawn no longer matches the forest as recorded.
## Queued, not built here. Building every loaded tile in one frame means dozens
## of tiles of forty-six candidates each plus their grass, which locks the game
## for long enough to look like a crash. The streaming queue already spreads
## that over frames, so felling a tree simply asks for the affected tiles again
## and they come back over the next few frames, nearest first.
func rebuild_all() -> void:
	forget_tree_query()
	_generation += 1
	for coord in _tiles.keys():
		if not _queue.has(coord):
			_queue.append(coord)
	_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - _centre).length_squared() < (b - _centre).length_squared())

## Only the tiles a felled tree could possibly appear in. Cheaper than rebuilding
## the whole forest for one stump, and the visible result is identical.
func rebuild_around(world_position: Vector3) -> void:
	forget_tree_query()
	_generation += 1
	var base := Vector2i(
		int(floor(world_position.x / float(TILE_SIZE))),
		int(floor(world_position.z / float(TILE_SIZE)))
	)
	for dx: int in [-1, 0, 1]:
		for dz: int in [-1, 0, 1]:
			var coord := base + Vector2i(dx, dz)
			if _tiles.has(coord) and not _queue.has(coord):
				_queue.push_front(coord)

func is_idle() -> bool:
	return _queue.is_empty() and _baking.is_empty() and _finished.is_empty()

func _rebuild_queue() -> void:
	var wanted: Dictionary = {}
	for dz in range(-TREE_RADIUS, TREE_RADIUS + 1):
		for dx in range(-TREE_RADIUS, TREE_RADIUS + 1):
			if dx * dx + dz * dz > TREE_RADIUS * TREE_RADIUS:
				continue
			var coord := _centre + Vector2i(dx, dz)
			var with_grass := dx * dx + dz * dz <= GRASS_RADIUS * GRASS_RADIUS
			wanted[coord] = with_grass

	for coord in _tiles.keys():
		if not wanted.has(coord):
			_tiles[coord].queue_free()
			_tiles.erase(coord)

	var pending: Array[Vector2i] = []
	for coord in wanted.keys():
		var existing = _tiles.get(coord)
		# A tile that gains grass has to be rebuilt; one that loses it can stay,
		# because grass beyond its radius is not worth a rebuild to remove.
		if existing == null or (wanted[coord] and not existing.has_grass):
			pending.append(coord)

	# A tile already standing and already waiting in the queue is waiting because
	# a tree was felled, and the queue is about to be replaced. Throwing those
	# requests away left the felled tree drawn until the tile happened to be
	# rebuilt for some other reason. Felling queues every loaded tile and they
	# drain one a frame, so a child who walked on meanwhile met it standing.
	for coord in _queue:
		if _tiles.has(coord) and wanted.has(coord) and not pending.has(coord):
			pending.append(coord)

	pending.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - _centre).length_squared() < (b - _centre).length_squared())
	_queue = pending

## Wait for whatever is still baking before this object goes.
##
## A bake on a worker thread writes its result back into this object. Freed
## first, the worker is left writing into memory that is no longer there — a
## crash, or a script error at "lock on a null value", depending on who wins
## the race. AnimalVoices learnt this on CI; this class had the same exposure
## and nothing closing it.
func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE:
		return
	for coord in _baking:
		WorkerThreadPool.wait_for_task_completion(_baking[coord]["task"])
	_baking.clear()

func _process(_delta: float) -> void:
	_assemble_finished()
	_blow()

	var in_flight := _baking.size()
	var started := 0
	while (
		started < TILES_PER_FRAME
		and in_flight + started < BAKES_IN_FLIGHT
		and not _queue.is_empty()
	):
		var coord: Vector2i = _queue.pop_front()
		var offset := coord - _centre
		if offset.length_squared() > TREE_RADIUS * TREE_RADIUS:
			continue
		var with_grass := offset.length_squared() <= GRASS_RADIUS * GRASS_RADIUS
		_submit_tile(coord, with_grass)
		started += 1

## Start a tile on a worker thread.
func _submit_tile(coord: Vector2i, with_grass: bool) -> void:
	if _baking.has(coord):
		return
	# The live record keeps being written by the axe on this thread; the worker
	# gets its own copy of it as of now.
	var stumps := felled.snapshot() if felled != null else null
	_baking[coord] = {
		"generation": _generation,
		"task": WorkerThreadPool.add_task(
			_bake_on_worker.bind(coord, with_grass, stumps, _generation), true,
			"aava vegetation tile"
		),
	}

## Runs on a worker thread. Reads the height field, which writes nothing back,
## and a snapshot of the felled trees that nothing else holds.
func _bake_on_worker(coord: Vector2i, with_grass: bool, stumps: Felled, generation: int) -> void:
	var baked := VegetationTile.bake(field, coord, TILE_SIZE, world_seed, stumps, with_grass)
	baked["generation"] = generation
	_finished_mutex.lock()
	_finished.append(baked)
	_finished_mutex.unlock()

## Turn finished bakes into instances, a few a frame.
func _assemble_finished() -> void:
	var stamp := PerfLog.stamp()
	_assemble_finished_now()
	PerfLog.note("tile build", stamp)

func _assemble_finished_now() -> void:
	var ready_now: Array = []
	_finished_mutex.lock()
	while not _finished.is_empty() and ready_now.size() < ASSEMBLED_PER_FRAME:
		ready_now.append(_finished.pop_front())
	_finished_mutex.unlock()

	for baked in ready_now:
		var coord: Vector2i = baked["coord"]
		var job = _baking.get(coord)
		_baking.erase(coord)
		if job == null:
			continue
		WorkerThreadPool.wait_for_task_completion(job["task"])
		# A tile the player has walked away from while it baked is not drawn: the
		# job stays in `_baking` when the tile leaves the wanted set, so without
		# this it was assembled out of range and sat there, trees and all, until
		# the next tile boundary.
		if (coord - _centre).length_squared() > TREE_RADIUS * TREE_RADIUS:
			continue
		if int(baked["generation"]) != _generation:
			# A tree was felled while this baked. Ask again rather than draw a
			# tree that has already been cut down.
			if not _queue.has(coord):
				_queue.push_front(coord)
			continue

		var previous = _tiles.get(coord)
		if previous != null:
			previous.queue_free()
		var tile := VegetationTile.new(
			baked, TILE_SIZE, _conifer, _broadleaf, _grass,
			_tree_material, _grass_material, _stump
		)
		add_child(tile)
		_tiles[coord] = tile
		# A tile baked bare while the player was further off may have come within
		# grass range since. Its restart was refused while the bake was in flight,
		# and nothing asks again until the next tile boundary, so a child who then
		# stood still had a bald patch at their feet. Ask again now.
		if not tile.has_grass and (coord - _centre).length_squared() <= GRASS_RADIUS * GRASS_RADIUS:
			if not _queue.has(coord):
				_queue.push_front(coord)
