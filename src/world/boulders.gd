class_name Boulders
extends Node3D

## Rocks strewn about the valley, and the small game of jumping them.
##
## They exist for one reason: a world you can only walk across is a world with
## nothing to do while walking. A rock in a meadow is a question — can I clear
## that? — and a child answers it without being asked to, which is the cheapest
## and most reliable kind of play there is.
##
## Scoring a jump is deliberately generous. The rule is "you were above it and
## you landed past it", not a frame-perfect arc, because the point is to be
## rewarded for trying rather than to be judged.

const TILE_SIZE := 32
const RADIUS := 4
const CANDIDATES_PER_TILE := 12
const TILES_PER_FRAME := 1

## A rock has to be low enough to clear and high enough to be worth clearing.
##
## The ceiling is set against the jump rather than chosen: a jump rises about
## 1.4 m, and a rock at 1.15 m left a 25 cm margin — thin enough that a child
## who mistimed slightly would clip it and not understand why. At 0.85 m the
## margin is comfortable, and clearing one still feels like clearing something.
const MIN_HEIGHT := 0.4
const MAX_HEIGHT := 0.85

## How far past a rock the player must land for the jump to count.
const CLEARANCE := 0.7

signal jumped(world_position: Vector3, total: int)

var field: HeightField
var world_seed: int

## Rocks already jumped, by id, so the same rock is not worth points twice and a
## tile that streams back does not reset a child's tally.
var cleared: Dictionary = {}
var jumps := 0

var _meshes: Array[Mesh] = []
var _material: StandardMaterial3D
var _tiles: Dictionary = {}
var _queue: Array[Vector2i] = []
var _centre := Vector2i(9999, 9999)
var _active: Array[Dictionary] = []

## The rock the player is currently airborne over, if any.
var _over: Dictionary = {}

func _init(height_field: HeightField, seed_value: int) -> void:
	field = height_field
	world_seed = seed_value

	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.roughness = 0.95

	# Three shapes rather than one, so a field of rocks does not read as a field
	# of copies. Built once and shared by every instance.
	for variant in 3:
		_meshes.append(_build_rock(variant))

func _build_rock(variant: int) -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var lumps := 3 + variant
	var rng := RandomNumberGenerator.new()
	rng.seed = 4000 + variant

	for i in lumps:
		var blob := SphereMesh.new()
		blob.radius = rng.randf_range(0.28, 0.46)
		blob.height = blob.radius * rng.randf_range(1.3, 1.8)
		blob.radial_segments = 7
		blob.rings = 4
		var at := Vector3(
			rng.randf_range(-0.28, 0.28),
			rng.randf_range(0.0, 0.22),
			rng.randf_range(-0.28, 0.28)
		)
		# Grey with a faint warm or cool bias per lump, which is what stops a
		# rock reading as a plastic pebble.
		var grey := rng.randf_range(0.42, 0.60)
		var color := Color(grey, grey * rng.randf_range(0.97, 1.02), grey * rng.randf_range(0.95, 1.03))
		_add(tool, blob, Transform3D(Basis(), at), color)

	tool.generate_normals()
	return tool.commit()

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

func _build_tile(coord: Vector2i) -> void:
	var holder := Node3D.new()
	var origin_x := float(coord.x * TILE_SIZE)
	var origin_z := float(coord.y * TILE_SIZE)
	holder.position = Vector3(origin_x, 0.0, origin_z)
	add_child(holder)
	_tiles[coord] = holder

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(world_seed + 517, coord.x, coord.y))

	for index in CANDIDATES_PER_TILE:
		var local_x := rng.randf() * TILE_SIZE
		var local_z := rng.randf() * TILE_SIZE
		var spin := rng.randf() * TAU
		var scale := rng.randf_range(0.7, 1.15)
		var variant := rng.randi_range(0, _meshes.size() - 1)

		var world_x := origin_x + local_x
		var world_z := origin_z + local_z
		if not _suits(world_x, world_z):
			continue

		var height := field.height_at(world_x, world_z)
		var node := MeshInstance3D.new()
		node.mesh = _meshes[variant]
		node.material_override = _material
		node.transform = Transform3D(
			Basis(Vector3.UP, spin).scaled(Vector3(scale, scale * rng.randf_range(0.7, 1.0), scale)),
			Vector3(local_x, height - 0.12, local_z)
		)
		holder.add_child(node)

		# A rock is collision as well as scenery, or a child runs straight
		# through the thing he was about to jump.
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var size := scale * 0.72
		box.size = Vector3(size, size * 0.9, size)
		collider.shape = box
		body.add_child(collider)
		body.position = Vector3(local_x, height + size * 0.3, local_z)
		holder.add_child(body)

		_active.append({
			"id": "%d:%d:%d" % [coord.x, coord.y, index],
			"position": Vector3(world_x, height, world_z),
			"reach": size * 0.8 + CLEARANCE,
			"tile": coord,
		})

## Where a rock belongs: on open ground, out of the water, off the pitch, and
## not so steep that it would be half buried.
func _suits(x: float, z: float) -> bool:
	var height := field.height_at(x, z)
	if height < HeightField.WATER_LEVEL + 0.4:
		return false
	if Pitch.is_levelled(x, z):
		return false
	if field.steepness_at(x, z) > 0.45:
		return false
	# Sparse in the meadow, commoner on the rising ground, which is where a
	# child would expect to find rocks.
	var chance := 0.18 + 0.5 * clampf((height - 6.0) / 40.0, 0.0, 1.0)
	return absf(sin(x * 12.9898 + z * 78.233) * 43758.5453) - floorf(absf(sin(x * 12.9898 + z * 78.233) * 43758.5453)) < chance

## Called every frame with where the player is and whether they are airborne.
## Scoring lives here rather than in the player because it is a property of the
## rock — the player does not need to know this game exists.
func watch(player_position: Vector3, airborne: bool) -> void:
	if airborne:
		if _over.is_empty():
			for record in _active:
				if cleared.has(record["id"]):
					continue
				var offset: Vector3 = record["position"] - player_position
				offset.y = 0.0
				if offset.length() < float(record["reach"]) and player_position.y > float(record["position"].y) + 0.35:
					_over = record
					break
		return

	# Landed. It counts if we were over a rock and have come down clear of it.
	if _over.is_empty():
		return
	var landed: Vector3 = _over["position"] - player_position
	landed.y = 0.0
	if landed.length() > float(_over["reach"]) * 0.75:
		cleared[_over["id"]] = true
		jumps += 1
		jumped.emit(_over["position"], jumps)
	_over = {}

func to_data() -> Dictionary:
	return {"jumps": jumps, "cleared": cleared.keys()}

func from_data(data: Dictionary) -> void:
	jumps = int(data.get("jumps", 0))
	cleared.clear()
	for id in data.get("cleared", []):
		cleared[String(id)] = true
	_centre = Vector2i(9999, 9999)

static func _add(tool: SurfaceTool, source: PrimitiveMesh, transform: Transform3D, color: Color) -> void:
	var arrays := source.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for i in vertices.size():
			tool.set_color(color)
			tool.add_vertex(transform * vertices[i])
		return
	for i in indices.size():
		tool.set_color(color)
		tool.add_vertex(transform * vertices[indices[i]])
