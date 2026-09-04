class_name Animals
extends Node3D

## The creatures living in the valley, and the small business of caring for them.
##
## They are streamed like everything else, but unlike rocks and sticks they move
## and they react. Two behaviours carry all of it: an animal drifts about its
## home patch, and it watches the player — backing away if it is shy, coming
## closer if the child is carrying what it wants.
##
## That second half is what makes a squirrel worth chasing. A shy animal that
## simply flees is a frustration; one that flees until you are holding a cone
## and then walks up to you is a puzzle a six-year-old solves on his own.

const TILE_SIZE := 48
const RADIUS := 3
const TILES_PER_FRAME := 1
const CANDIDATES_PER_TILE := 3

## How close the player must be to feed or stroke.
const REACH := 2.4

## How far an animal wanders from where it lives.
const ROAM := 9.0
const SPEED := 1.5
const FLEE_SPEED := 4.2

## Within this distance a shy animal starts backing away, unless the player is
## carrying what it wants.
const NOTICE := 7.0

signal cared_for(kind: StringName, coins: int, world_position: Vector3)
signal befriended(kind: StringName)

var field: HeightField
var world_seed: int

## Animals already befriended, by kind. A befriended animal never flees again,
## which is the visible, permanent reward for having looked after it.
var friends: Dictionary = {}

var _meshes: Dictionary = {}
var _material: StandardMaterial3D
var _tiles: Dictionary = {}
var _queue: Array[Vector2i] = []
var _centre := Vector2i(9999, 9999)
var _living: Array[Dictionary] = []

func _init(height_field: HeightField, seed_value: int) -> void:
	field = height_field
	world_seed = seed_value

	_material = AnimalKinds.fur_material()

	for kind in AnimalKinds.ALL:
		_meshes[kind] = AnimalKinds.build_mesh(kind)

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

func count_living() -> int:
	return _living.size()

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
	for i in range(_living.size() - 1, -1, -1):
		if _living[i]["tile"] == coord:
			_living.remove_at(i)

func _process(delta: float) -> void:
	var built := 0
	while built < TILES_PER_FRAME and not _queue.is_empty():
		_build_tile(_queue.pop_front())
		built += 1
	for animal in _living:
		_step(animal, delta)

func _build_tile(coord: Vector2i) -> void:
	var holder := Node3D.new()
	add_child(holder)
	_tiles[coord] = holder

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(world_seed + 331, coord.x, coord.y))

	for index in CANDIDATES_PER_TILE:
		var x := float(coord.x * TILE_SIZE) + rng.randf() * TILE_SIZE
		var z := float(coord.y * TILE_SIZE) + rng.randf() * TILE_SIZE
		var kind := _kind_at(x, z, rng)
		if kind == &"":
			continue

		var home := Vector3(x, field.height_at(x, z), z)
		var node := MeshInstance3D.new()
		node.mesh = _meshes[kind]
		node.material_override = _material
		node.position = home
		holder.add_child(node)

		_living.append({
			"kind": kind,
			"node": node,
			"home": home,
			"target": home,
			"tile": coord,
			"rest": rng.randf() * 3.0,
			"cooldown": 0.0,
			"bob": rng.randf() * TAU,
		})

## Who lives where. Each animal belongs to the ground it is found on, which is
## how a child learns that cones are a forest thing and beavers are a river one.
func _kind_at(x: float, z: float, rng: RandomNumberGenerator) -> StringName:
	var height := field.height_at(x, z)
	if height < HeightField.WATER_LEVEL + 0.2:
		return &""
	if Pitch.is_levelled(x, z):
		return &""

	var to_river := field.distance_to_river(x, z)
	if to_river < 14.0 and height < HeightField.WATER_LEVEL + 3.0:
		return AnimalKinds.BEAVER if rng.randf() < 0.6 else &""

	if field.forest_density_at(x, z) > 0.3:
		return AnimalKinds.SQUIRREL if rng.randf() < 0.7 else &""

	if field.steepness_at(x, z) > 0.35 or height > 60.0:
		return &""

	# Open meadow near the middle of the world is where the tame ones are.
	var roll := rng.randf()
	if roll < 0.35:
		return AnimalKinds.DOG
	if roll < 0.6:
		return AnimalKinds.CAT
	return &""

func _step(animal: Dictionary, delta: float) -> void:
	var node: Node3D = animal["node"]
	if not is_instance_valid(node):
		return
	animal["cooldown"] = maxf(0.0, float(animal["cooldown"]) - delta)

	var to_target: Vector3 = animal["target"] - node.position
	to_target.y = 0.0
	var speed: float = animal.get("speed", SPEED)

	if to_target.length() < 0.4:
		animal["rest"] = float(animal["rest"]) - delta
		if float(animal["rest"]) <= 0.0:
			# Wander somewhere else nearby, and settle for a while when it
			# arrives. Constant motion reads as a machine; pauses read as an
			# animal deciding.
			var home: Vector3 = animal["home"]
			var angle := randf() * TAU
			var distance := randf() * ROAM
			var spot := home + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
			spot.y = field.height_at(spot.x, spot.z)
			animal["target"] = spot
			animal["rest"] = randf_range(1.5, 5.0)
			animal["speed"] = SPEED
	else:
		var direction := to_target.normalized()
		node.position += direction * speed * delta
		node.position.y = field.height_at(node.position.x, node.position.z)
		node.rotation.y = atan2(-direction.x, -direction.z)

	# A gentle bob, so a standing animal is not a statue.
	animal["bob"] = float(animal["bob"]) + delta * 3.0
	node.position.y += sin(float(animal["bob"])) * 0.02

## Called every frame with where the player is and what they are carrying.
##
## The animals watch rather than being told: nothing in the player or the
## inventory knows that animals exist.
func watch(player_position: Vector3, inventory: Inventory) -> void:
	for animal in _living:
		var node: Node3D = animal["node"]
		if not is_instance_valid(node):
			continue
		var kind: StringName = animal["kind"]
		var offset := player_position - node.position
		offset.y = 0.0
		var distance := offset.length()
		if distance > NOTICE:
			continue

		var wanted := AnimalKinds.want(kind)
		var offered := wanted == &"" or inventory.count(wanted) > 0
		var tame := friends.has(kind) or offered

		if tame:
			# Come and meet the child, but stop short rather than walking into
			# them, which looks like a bug rather than like interest.
			if distance > REACH * 0.8:
				animal["target"] = player_position - offset.normalized() * REACH * 0.7
				animal["target"].y = field.height_at(animal["target"].x, animal["target"].z)
				animal["speed"] = SPEED * 1.3
				animal["rest"] = 0.5
			continue

		var shy: float = AnimalKinds.shyness(kind)
		if shy <= 0.0 or distance > NOTICE * (0.4 + shy * 0.6):
			continue
		# Back away, keeping to its own patch so it does not flee to the horizon
		# and vanish from the world.
		var home: Vector3 = animal["home"]
		var away := node.position + offset.normalized() * -1.0 * ROAM * 0.6
		if away.distance_to(home) > ROAM * 1.6:
			away = home
		away.y = field.height_at(away.x, away.z)
		animal["target"] = away
		animal["speed"] = FLEE_SPEED * shy
		animal["rest"] = 0.4

## The animal nearest the player that can be cared for right now, or empty.
func nearest_caring(player_position: Vector3, inventory: Inventory) -> Dictionary:
	var best := {}
	var best_distance := REACH
	for animal in _living:
		var node: Node3D = animal["node"]
		if not is_instance_valid(node) or float(animal["cooldown"]) > 0.0:
			continue
		var wanted := AnimalKinds.want(animal["kind"])
		if wanted != &"" and inventory.count(wanted) <= 0:
			continue
		var distance := node.position.distance_to(player_position)
		if distance <= best_distance:
			best_distance = distance
			best = animal
	return best

## Feed or stroke it. Returns the coins earned, or zero.
func care_for(animal: Dictionary, inventory: Inventory) -> int:
	if animal.is_empty():
		return 0
	# The cooldown is checked here and not only in nearest_caring, because this
	# is the function that pays out. Guarding only the "who is nearby" query
	# left the payout itself open: two care presses landing in the same frame,
	# or any caller holding on to an animal it found a moment ago, would be paid
	# twice for one animal.
	if float(animal["cooldown"]) > 0.0:
		return 0
	var kind: StringName = animal["kind"]
	var wanted := AnimalKinds.want(kind)
	if wanted != &"":
		if not inventory.spend({wanted: 1}):
			return 0

	animal["cooldown"] = AnimalKinds.cooldown(kind)
	var coins := AnimalKinds.coins(kind)
	var node: Node3D = animal["node"]
	cared_for.emit(kind, coins, node.position)

	if not friends.has(kind):
		friends[kind] = true
		befriended.emit(kind)
	return coins

func to_data() -> Array:
	return friends.keys()

func from_data(kinds: Array) -> void:
	friends.clear()
	for kind in kinds:
		friends[StringName(kind)] = true
