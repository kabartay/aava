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
const TILES_PER_FRAME := 1

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

var field: HeightField
var world_seed: int

## Which pickups are already gone, keyed "tx:tz:index". Kept out of the tiles so
## that a tile which streams out and back does not hand the same stick over
## twice.
var taken: Dictionary = {}

var _meshes: Dictionary = {}
var _materials: Dictionary = {}
var _tiles: Dictionary = {}
var _queue: Array[Vector2i] = []
var _centre := Vector2i(9999, 9999)
var _active: Array[Dictionary] = []

func _init(height_field: HeightField, seed_value: int) -> void:
	field = height_field
	world_seed = seed_value
	# Meshes and materials are built here rather than in _ready. A node used
	# before the scene tree starts processing never gets _ready called, and the
	# result was silent: no meshes, no pickups, and an error per candidate. A
	# resource needs no tree, so there is no reason to wait for one.
	var shader := Shader.new()
	shader.code = SHADER
	for kind in ItemKinds.ALL:
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

func _drop_tile(coord: Vector2i) -> void:
	var node = _tiles.get(coord)
	if node != null:
		node.queue_free()
	_tiles.erase(coord)
	for i in range(_active.size() - 1, -1, -1):
		if _active[i]["tile"] == coord:
			_active.remove_at(i)

func _process(_delta: float) -> void:
	var built := 0
	while built < TILES_PER_FRAME and not _queue.is_empty():
		_build_tile(_queue.pop_front())
		built += 1

## Called by whoever owns the player, rather than the pickups reaching for the
## player themselves: the world does not get to know about the game.
func check_reach(world_position: Vector3) -> void:
	var reach_squared := REACH * REACH
	for i in range(_active.size() - 1, -1, -1):
		var record := _active[i]
		var offset: Vector3 = record["position"] - world_position
		# Vertical distance is weighted down so standing on a slope above a
		# stone still counts as reaching it.
		offset.y *= 0.5
		if offset.length_squared() > reach_squared:
			continue
		taken[record["id"]] = true
		var node: Node3D = record["node"]
		if is_instance_valid(node):
			node.queue_free()
		_active.remove_at(i)
		collected.emit(record["kind"], record["position"])

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
		# The random draws happen before the "already taken" test so that
		# collecting one stick never shifts where the others are.
		if taken.has(id):
			continue

		var world_x := origin_x + local_x
		var world_z := origin_z + local_z
		var kind := _kind_at(world_x, world_z, rng)
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
func _kind_at(x: float, z: float, rng: RandomNumberGenerator) -> StringName:
	var height := field.height_at(x, z)
	if height < HeightField.WATER_LEVEL + 0.1:
		return &""

	var to_river := field.distance_to_river(x, z)
	if to_river < 20.0 and height < HeightField.WATER_LEVEL + 2.4:
		return ItemKinds.REED if rng.randf() < 0.55 else &""

	var forest := field.forest_density_at(x, z)
	if forest > 0.22:
		var roll := rng.randf()
		if roll < 0.34:
			return ItemKinds.STICK
		# Cones lie under the conifers, which grow higher up — so climbing into
		# the forest is what finds them, and that is worth a walk.
		if roll < 0.34 + (0.26 if height > 22.0 else 0.08):
			return ItemKinds.CONE
		if roll < 0.72:
			return ItemKinds.SEED
		return &""

	var steep := field.steepness_at(x, z)
	if steep > 0.22 or height > 40.0:
		return ItemKinds.STONE if rng.randf() < 0.38 else &""

	# Open meadow: mostly empty, which is what makes a find feel like a find.
	var roll := rng.randf()
	if roll < 0.10:
		return ItemKinds.SEED
	if roll < 0.16:
		return ItemKinds.STONE
	return &""

func to_data() -> Array:
	return taken.keys()

func from_data(ids: Array) -> void:
	taken.clear()
	for id in ids:
		taken[String(id)] = true
	# Force a rebuild so already-collected pickups do not reappear.
	_centre = Vector2i(9999, 9999)
