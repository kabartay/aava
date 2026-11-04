class_name Pickups
extends Node3D

## Things lying about to be found and carried home.
##
## Collected by walking into them, with no button. That is deliberate: it is the
## six-year-old's whole job in this game, and a proximity radius is something a
## small child understands immediately, while a context button is one more thing
## to be told about. It also means gathering never interrupts walking.

const TILE_SIZE := 32
const RADIUS := 3

## Within this distance a pickup is collected. Generous on purpose — walking
## near a stick should be enough.
const REACH := 1.5

const CANDIDATES_PER_TILE := 30

## How far from the river reeds grow, and how high above the water. The river
## is wide and mostly water, so the dry ground within twenty metres of it was a
## few dozen squares near the camp: seven reeds in all, for a house that takes
## twelve. Reeds grow wherever the ground is still damp, which is further.
const REED_BANK := 24.0
const REED_HEIGHT := 2.7

## The share of forest floor that is a stick. A house is twenty-eight of them
## and the wood near the camp is thin; this is what makes it one outing.
const STICK_SHARE := 0.44
const TILES_PER_FRAME := 1

## Restocking: a pickup that was taken is laid again, but slowly and out of
## sight, so that a valley is never emptied for good and never visibly refilled.
##
## A stick comes back after a quarter of an hour of play, and only where no
## child is near enough to watch it: the whole ring of streamed tiles is out of
## bounds, plus one more tile (so a child who turns round and walks back sees
## what was always going to be there, not a thing appearing). A pass runs every
## twenty seconds and lays at most a couple of dozen, so nothing ever arrives
## in a rush. Near the camp the valley holds some five hundred pickups, which
## at this rate are laid again at about one a minute at most: enough for a dog
## to be fed all afternoon, and far too few to farm.
const RESTOCK_AFTER := 900.0
const RESTOCK_EVERY := 20.0
const RESTOCK_PER_PASS := 24
const RESTOCK_CLEAR := float((RADIUS + 1) * TILE_SIZE) + 24.0

## Bob and glint, so that a stick in tall grass is still findable. A shared
## shader keyed on world position means every pickup moves out of phase with
## its neighbours at no cost.
const SHADER := """
shader_type spatial;
render_mode world_vertex_coords, diffuse_lambert;

uniform vec3 tint : source_color = vec3(1.0);
uniform float bob_height = 0.09;

varying float glint;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = origin.x * 0.7 + origin.z * 0.5;
	VERTEX.y += sin(TIME * 1.7 + phase) * bob_height;
	glint = 0.5 + 0.5 * sin(TIME * 2.3 + phase);
}

void fragment() {
	ALBEDO = pow(tint, vec3(2.2));
	// A slow pulse of self-illumination. Not a glow so much as a hint that this
	// object is different from the scenery around it.
	EMISSION = pow(tint, vec3(2.2)) * (0.10 + 0.22 * glint);
	ROUGHNESS = 0.75;
}
"""

signal collected(kind: StringName, world_position: Vector3)
## The same, by the id the valley gives it — the same one on every phone, since
## the valley is the same — for telling somebody else it is gone.
signal taken_here(id: String)
## Some taken pickups have been laid again, by id (see `restock_step`). Only the
## phone that holds the valley says so; the others are told.
signal restocked(ids: PackedStringArray)

var field: HeightField
var world_seed: int

## Which pickups are already gone, keyed "tx:tz:index". Kept out of the tiles so
## that a tile which streams out and back does not hand the same stick over
## twice.
var taken: Dictionary = {}

## When each taken pickup was taken, on `clock`. Kept beside `taken` rather than
## in it so that everything that asks "is it gone?" is unchanged.
var _taken_at: Dictionary = {}

## Seconds of play the valley has seen, advanced by `restock_step`.
var clock := 0.0
var _restock_timer := 0.0

## Asked whether a spot has been built on (set by the game, which knows about
## structures; the world does not): `func(x: float, z: float) -> bool`. A spot
## that is built on is not laid again.
var blocked := Callable()

var _meshes: Dictionary = {}
var _materials: Dictionary = {}
var _tiles: Dictionary = {}
var _queue: Array[Vector2i] = []
var _centre := Vector2i(9999, 9999)
var _active: Array[Dictionary] = []

func _init(height_field: HeightField, seed_value: int) -> void:
	# Animated in _process, so the engine's physics interpolation must not
	# touch it. See LESSONS.md: with interpolation on, a node's transform is
	# sampled once a physics tick and drawn a tick late, which throws away
	# everything moved between ticks — sixty-hertz motion on a hundred-and-
	# twenty-hertz screen, which is the flicker a child described as the world
	# coming in frames.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	field = height_field
	world_seed = seed_value
	# Meshes and materials are built here rather than in _ready. A node used
	# before the scene tree starts processing never gets _ready called, and the
	# result was silent: no meshes, no pickups, and an error per candidate. A
	# resource needs no tree, so there is no reason to wait for one.
	var shader := Shader.new()
	shader.code = SHADER
	for kind in ItemKinds.SCATTERED:
		_meshes[kind] = ItemKinds.build_mesh(kind)
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("tint", ItemKinds.color(kind))
		_materials[kind] = material

func follow(world_position: Vector3) -> void:
	var tile := Vector2i(
		floori(world_position.x / float(TILE_SIZE)),
		floori(world_position.z / float(TILE_SIZE))
	)
	if tile == _centre:
		return
	_centre = tile
	_rebuild_queue()

## Draw every tile again, for the same reason as the boulders: a finished dam
## lifts the ground, and finds drawn before it would stand buried in it.
func rebuild_all() -> void:
	for coord in _tiles.keys():
		_drop_tile(coord)
	_queue.clear()
	_centre = Vector2i(9999, 9999)

func is_idle() -> bool:
	return _queue.is_empty()

func count_active() -> int:
	return _active.size()

func _rebuild_queue() -> void:
	var wanted: Dictionary = {}
	for dz in range(-RADIUS, RADIUS + 1):
		for dx in range(-RADIUS, RADIUS + 1):
			if dx * dx + dz * dz > RADIUS * RADIUS:
				continue
			wanted[_centre + Vector2i(dx, dz)] = true

	for coord in _tiles.keys():
		if not wanted.has(coord):
			_drop_tile(coord)

	var pending: Array[Vector2i] = []
	for coord in wanted.keys():
		if not _tiles.has(coord):
			pending.append(coord)
	pending.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - _centre).length_squared() < (b - _centre).length_squared())
	_queue = pending

## The ground has changed under the tiles already built — a dam has been
## finished — so what lay on it is laid again. What has been taken stays taken.
func regrow() -> void:
	for coord in _tiles.keys():
		_drop_tile(coord)
	_queue.clear()
	_rebuild_queue()

func _drop_tile(coord: Vector2i) -> void:
	var node = _tiles.get(coord)
	if node != null:
		node.queue_free()
	_tiles.erase(coord)
	for i in range(_active.size() - 1, -1, -1):
		if _active[i]["tile"] == coord:
			_active.remove_at(i)
			_revision += 1

func _process(_delta: float) -> void:
	var built := 0
	while built < TILES_PER_FRAME and not _queue.is_empty():
		_build_tile(_queue.pop_front())
		built += 1

## Called by whoever owns the player, rather than the pickups reaching for the
## player themselves: the world does not get to know about the game.
func check_reach(world_position: Vector3) -> void:
	# Nothing can have come into reach unless the child has walked further than
	# the gap that was left at the last full look, or the list has changed (a
	# tile built or dropped, a pickup taken). Pickups do not move, so until
	# then there is nothing to measure: every frame, every pickup in the
	# loaded tiles — nearly two hundred — was measured against a child who is
	# nowhere near any of them.
	if _reach_revision == _revision and _weighted(world_position - _reach_from) < _reach_slack:
		return
	var reach_squared := REACH * REACH
	var nearest := INF
	for i in range(_active.size() - 1, -1, -1):
		var record := _active[i]
		var offset: Vector3 = record["position"] - world_position
		# Vertical distance is weighted down so standing on a slope above a
		# stone still counts as reaching it.
		offset.y *= 0.5
		var away := offset.length_squared()
		if away > reach_squared:
			nearest = minf(nearest, away)
			continue
		_mark_taken(record["id"])
		_remember_the_claim(record["id"], record["kind"])
		var node: Node3D = record["node"]
		if is_instance_valid(node):
			node.queue_free()
		_active.remove_at(i)
		_revision += 1
		taken_here.emit(record["id"])
		collected.emit(record["kind"], record["position"])
	_reach_from = world_position
	# Measured the same way the reach is, so the slack is exact: the weighted
	# distance to a pickup changes by no more than the weighted distance the
	# child moves.
	_reach_slack = sqrt(nearest) - REACH
	_reach_revision = _revision
	_reach_scans += 1

## The child's own measure of distance to a pickup, with height counting half.
func _weighted(offset: Vector3) -> float:
	offset.y *= 0.5
	return offset.length()

## Bumped whenever `_active` changes, so that `check_reach` knows its last look
## is out of date. Where the child stood for it, how far they may walk before
## it has to look again, and how many full looks it has made (for the checks).
var _revision := 0
var _reach_revision := -1
var _reach_from := Vector3.ZERO
var _reach_slack := 0.0
var _reach_scans := 0

func reach_scans() -> int:
	return _reach_scans

## What this phone's child took lately, by id, with the time: a guest's pick-up
## is provisional until the host has had its say (see Session.report_picked), and
## if the host says the thing was already its own, the phone needs to know what
## to take back out of the bag.
var _claims: Dictionary = {}

## Longer than any reply from a host on a family network takes; a claim older
## than this is the child's for good.
const CLAIM_WINDOW_MSEC := 15000

func _remember_the_claim(id: String, kind: StringName) -> void:
	var now := Time.get_ticks_msec()
	for old: String in _claims.keys():
		if now - int(_claims[old][1]) > CLAIM_WINDOW_MSEC:
			_claims.erase(old)
	_claims[id] = [kind, now]

## The host had it first. Returns the kind of thing the child had been given for
## it, so it can be taken from them again, or nothing if this phone never took
## that one (or took it too long ago to be taken back). The pickup stays gone
## from the valley: it is in the host's bag.
func take_back(id: String) -> StringName:
	if not _claims.has(id):
		return &""
	var claim: Array = _claims[id]
	_claims.erase(id)
	if Time.get_ticks_msec() - int(claim[1]) > CLAIM_WINDOW_MSEC:
		return &""
	return claim[0]

## Somebody else picked this up. It is gone here too, without a reward: it went
## into their bag. A tile not built yet will leave it out when it is.
func taken_elsewhere(id: String) -> void:
	_mark_taken(id)
	for i in range(_active.size() - 1, -1, -1):
		if _active[i]["id"] != id:
			continue
		var node: Node3D = _active[i]["node"]
		if is_instance_valid(node):
			node.queue_free()
		_active.remove_at(i)
		_revision += 1

## Record that a pickup is gone, `age` seconds ago.
func _mark_taken(id: String, age := 0.0) -> void:
	taken[id] = true
	_taken_at[id] = clock - clampf(age, 0.0, 86400.0 * 30.0)

## What the ground would hold at candidate `index` of a tile, drawn the way
## `_build_tile` draws it (the same random numbers in the same order), so a
## pickup can be asked about without building its tile. Empty if the id is not
## one of this valley's, or there is nothing there now.
func spot_of(id: String) -> Dictionary:
	var parts := id.split(":")
	if parts.size() != 3 or not (parts[0].is_valid_int() and parts[1].is_valid_int() and parts[2].is_valid_int()):
		return {}
	var coord := Vector2i(int(parts[0]), int(parts[1]))
	var index := int(parts[2])
	if index < 0 or index >= CANDIDATES_PER_TILE:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(world_seed + 91, coord.x, coord.y))
	var x := 0.0
	var z := 0.0
	var roll := 0.0
	for _step in index + 1:
		x = float(coord.x * TILE_SIZE) + rng.randf() * TILE_SIZE
		z = float(coord.y * TILE_SIZE) + rng.randf() * TILE_SIZE
		rng.randf()
		roll = rng.randf()
	var kind := _kind_at(x, z, roll)
	if kind == &"":
		return {}
	return {"kind": kind, "x": x, "z": z, "tile": coord}

## Lay taken pickups again. Called every frame by whoever holds the valley (a
## guest's phone does not: the host decides, and tells it, see
## `restocked_elsewhere`), with where every child is. Returns, and announces,
## the ids laid this pass — usually none.
##
## Never in sight: a pickup is only laid in a tile that is not built (so not
## within the ring a child can see) and farther than RESTOCK_CLEAR from every
## child. Never on ground that is not a pickup's now (water, a pitch, indoors),
## nor where something has been built.
func restock_step(delta: float, children: Array[Vector3]) -> PackedStringArray:
	clock += delta
	_restock_timer += delta
	var laid := PackedStringArray()
	if _restock_timer < RESTOCK_EVERY:
		return laid
	_restock_timer = 0.0
	for id: String in taken.keys():
		if laid.size() >= RESTOCK_PER_PASS:
			break
		if clock - float(_taken_at.get(id, clock)) < RESTOCK_AFTER:
			continue
		var tile := _tile_of(id)
		if tile == NO_TILE or _tiles.has(tile) or _queue.has(tile) or _seen_from(tile, children):
			continue
		var spot := spot_of(id)
		if spot.is_empty():
			# Not a pickup this ground has now: look again in a while.
			_taken_at[id] = clock
			continue
		if blocked.is_valid() and bool(blocked.call(spot["x"], spot["z"])):
			_taken_at[id] = clock
			continue
		taken.erase(id)
		_taken_at.erase(id)
		laid.append(id)
	if not laid.is_empty():
		restocked.emit(laid)
	return laid

## The tile a pickup's id names, or NO_TILE if it names none.
func _tile_of(id: String) -> Vector2i:
	var parts := id.split(":")
	if parts.size() != 3 or not (parts[0].is_valid_int() and parts[1].is_valid_int()):
		return NO_TILE
	return Vector2i(int(parts[0]), int(parts[1]))

const NO_TILE := Vector2i(2147483647, 2147483647)

## Is any child within sight of the tile — nearer than RESTOCK_CLEAR to its
## nearest edge?
func _seen_from(tile: Vector2i, children: Array[Vector3]) -> bool:
	var low := Vector2(tile.x * TILE_SIZE, tile.y * TILE_SIZE)
	var high := low + Vector2(TILE_SIZE, TILE_SIZE)
	for at in children:
		var nearest := Vector2(clampf(at.x, low.x, high.x), clampf(at.z, low.y, high.y))
		if Vector2(at.x, at.z).distance_to(nearest) < RESTOCK_CLEAR:
			return true
	return false

## The phone that holds the valley laid these again. A tile that is already built
## is left as it is, so nothing appears in front of this phone's child; it shows
## the next time the tile is built.
func restocked_elsewhere(ids: PackedStringArray) -> void:
	for id in ids:
		taken.erase(id)
		_taken_at.erase(id)

func _build_tile(coord: Vector2i) -> void:
	var holder := Node3D.new()
	var origin_x := float(coord.x * TILE_SIZE)
	var origin_z := float(coord.y * TILE_SIZE)
	holder.position = Vector3(origin_x, 0.0, origin_z)
	add_child(holder)
	_tiles[coord] = holder

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(world_seed + 91, coord.x, coord.y))

	for index in CANDIDATES_PER_TILE:
		var id := "%d:%d:%d" % [coord.x, coord.y, index]
		var local_x := rng.randf() * TILE_SIZE
		var local_z := rng.randf() * TILE_SIZE
		var spin := rng.randf() * TAU
		# The random draws, the choice of kind included, happen before the
		# "already taken" test so that collecting one stick never shifts what
		# the others are. Deciding the kind after it let a taken candidate skip
		# its draws, so after a reload the rest of the tile were different
		# things in different places.
		var world_x := origin_x + local_x
		var world_z := origin_z + local_z
		# One draw for the kind, taken here whatever the ground is: _kind_at
		# used to leave early over water without drawing, so a dam that put dry
		# ground where there had been river shifted every later candidate in the
		# tile, and sticks already taken came back as other things.
		var roll := rng.randf()
		var kind := _kind_at(world_x, world_z, roll)
		if taken.has(id):
			continue
		if kind == &"":
			continue

		var height := field.height_at(world_x, world_z)
		var node := MeshInstance3D.new()
		node.mesh = _meshes[kind]
		node.material_override = _materials[kind]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.transform = Transform3D(
			ItemKinds.resting_rotation(kind, spin),
			Vector3(local_x, height + ItemKinds.resting_height(kind), local_z)
		)
		holder.add_child(node)

		_revision += 1
		_active.append({
			"id": id,
			"kind": kind,
			"node": node,
			"position": Vector3(world_x, height, world_z),
			"tile": coord,
		})

## What, if anything, is found at this spot. Each material comes from the place
## it would actually come from, so a child learns where to look: sticks under
## trees, reeds at the water, stone on bare ground.
func _kind_at(x: float, z: float, roll: float) -> StringName:
	var height := field.height_at(x, z)
	if height < HeightField.WATER_LEVEL + 0.1:
		return &""
	# Nor in a pond, whatever height its water stands at. A raised pond's bed
	# is well above the world's waterline, so this saw dry hillside and strewed
	# it with stones — which from the bank looked like stones floating in the
	# lake, because that is what they were.
	if field.is_pond(x, z):
		return &""
	# Nor on ground that belongs to a place: in the pool's basin, on the
	# football pitch, in the playground, in front of the big wheel — where a
	# stone lay under the water or in the middle of a match. The same rule that
	# keeps a sapling off it (see KeepOut), and the pool's hole as well.
	var camp := field.camp_centre()
	if KeepOut.kept(x, z, camp, field.river_centre_x(BridgeSpec.CENTRE_Z)) or PlaceSpec.excavation(x, z, camp) > 0.0:
		return &""
	# Nor indoors: a stick lying on the floor of the shop is a stick that grew
	# through it.
	if PlaceSpec.indoors(x, z, field.camp_centre()):
		return &""
	# Nor under the bridge deck, where a stick lay between the planks.
	if BridgeSpec.clear_of_trees(x, z, field.river_centre_x(BridgeSpec.CENTRE_Z)):
		return &""

	var to_river := field.distance_to_river(x, z)
	if to_river < REED_BANK and height < HeightField.WATER_LEVEL + REED_HEIGHT:
		return ItemKinds.REED if roll < 0.5 else &""

	var forest := field.forest_density_at(x, z)
	if forest > 0.22:
		if roll < STICK_SHARE:
			return ItemKinds.STICK
		# Cones lie under the conifers, which grow higher up — so climbing into
		# the forest is what finds them, and that is worth a walk.
		if roll < STICK_SHARE + (0.26 if height > 22.0 else 0.08):
			return ItemKinds.CONE
		if roll < 0.72:
			return ItemKinds.SEED
		return &""

	var steep := field.steepness_at(x, z)
	if steep > 0.22 or height > 40.0:
		return ItemKinds.STONE if roll < 0.38 else &""

	# Open meadow: mostly empty, which is what makes a find feel like a find.
	if roll < 0.10:
		return ItemKinds.SEED
	if roll < 0.16:
		return ItemKinds.STONE
	return &""

func to_data() -> Array:
	return taken.keys()

## How long each taken pickup has been gone, in whole seconds, by id. Saved
## beside `to_data` (which keeps its old shape, so an older build still reads a
## newer save) so that a quarter of an hour already waited is not waited again.
func ages_to_data() -> Dictionary:
	var out := {}
	for id: String in _taken_at:
		out[id] = int(clock - float(_taken_at[id]))
	return out

func from_data(ids: Array, ages: Variant = {}) -> void:
	taken.clear()
	_taken_at.clear()
	for id in ids:
		# An old save has no ages: everything in it starts the wait afresh.
		_mark_taken(String(id), SaveGame.as_float(ages.get(String(id), 0.0)) if ages is Dictionary else 0.0)
	# Force a rebuild so already-collected pickups do not reappear. Tiles that are
	# already built are thrown away too: follow() only builds the ones that are
	# missing, so a tile built under the old record would keep its old sticks —
	# collectable a second time after a load, and still gone after a reset.
	for coord in _tiles.keys():
		_drop_tile(coord)
	_queue.clear()
	_centre = Vector2i(9999, 9999)
