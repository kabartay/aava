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

## Wind. One shader serves every plant; the uniforms are what make grass whip
## and a conifer barely lean.
const WIND_SHADER := """
shader_type spatial;
render_mode world_vertex_coords, cull_disabled, diffuse_lambert, specular_disabled;

uniform float sway_strength = 0.22;
uniform float sway_speed = 1.3;
uniform float stiffness = 1.6;
uniform float gust_scale = 0.012;

void vertex() {
	// MODEL_MATRIX carries the per-instance transform inside a MultiMesh, so
	// this is where each plant gets its own phase and stops swaying in unison.
	vec3 origin = MODEL_MATRIX[3].xyz;
	float local_height = max(VERTEX.y - origin.y, 0.0);

	// Deliberately nothing here reads the camera or the screen: in a shadow
	// pass those describe the light instead, and the shadow would swing away
	// from the plant casting it.
	float phase = origin.x * 0.31 + origin.z * 0.23;
	float gust = sin((origin.x + origin.z) * gust_scale + TIME * 0.27) * 0.5 + 0.75;
	float t = TIME * sway_speed + phase;

	// Bending grows with height above the root, so the base stays planted.
	float bend = pow(local_height, stiffness) * sway_strength * gust;
	VERTEX.x += sin(t) * bend;
	VERTEX.z += cos(t * 0.81) * bend * 0.7;
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
var _centre := Vector2i(9999, 9999)

func _init(height_field: HeightField, seed_value: int) -> void:
	field = height_field
	world_seed = seed_value
	# Built here, not in _ready: a node used before the tree starts processing
	# never receives _ready, and the failure is silent.
	_conifer = PlantMeshes.conifer(6.4)
	_broadleaf = PlantMeshes.broadleaf(5.2)
	_grass = PlantMeshes.grass_tuft(0.34, 5)

	var shader := Shader.new()
	shader.code = WIND_SHADER

	_tree_material = ShaderMaterial.new()
	_tree_material.shader = shader
	_tree_material.set_shader_parameter("sway_strength", 0.055)
	_tree_material.set_shader_parameter("sway_speed", 0.9)
	_tree_material.set_shader_parameter("stiffness", 1.9)

	_grass_material = ShaderMaterial.new()
	_grass_material.shader = shader
	_grass_material.set_shader_parameter("sway_strength", 1.9)
	_grass_material.set_shader_parameter("sway_speed", 2.1)
	_grass_material.set_shader_parameter("stiffness", 1.25)

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

	pending.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - _centre).length_squared() < (b - _centre).length_squared())
	_queue = pending

func _process(_delta: float) -> void:
	var built := 0
	while built < TILES_PER_FRAME and not _queue.is_empty():
		var coord: Vector2i = _queue.pop_front()
		var offset := coord - _centre
		if offset.length_squared() > TREE_RADIUS * TREE_RADIUS:
			continue
		var with_grass := offset.length_squared() <= GRASS_RADIUS * GRASS_RADIUS
		_build_tile(coord, with_grass)
		built += 1

func _build_tile(coord: Vector2i, with_grass: bool) -> void:
	var previous = _tiles.get(coord)
	if previous != null:
		previous.queue_free()

	var tile := VegetationTile.new(
		field, coord, TILE_SIZE, world_seed,
		_conifer, _broadleaf, _grass,
		_tree_material, _grass_material,
		with_grass
	)
	tile.has_grass = with_grass
	add_child(tile)
	_tiles[coord] = tile
