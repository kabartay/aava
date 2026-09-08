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

## How quickly an animal comes round to face where it is going, how quickly
## it gets up to speed, and how far ahead it looks for things to walk round.
## Turning was instant and speed was constant, and every animal moved like a
## toy on a string; a body swings round and gathers pace.
const TURN_RATE := 5.0
## Each kind comes round at its own rate: a squirrel whips about, a cat
## flows, a beaver lumbers.
const TURN_RATES := {
	AnimalKinds.CAT: 4.0, AnimalKinds.DOG: 6.0, AnimalKinds.SQUIRREL: 8.5, AnimalKinds.BEAVER: 3.5,
}
## How far the legs swing at a walk, per kind, and how the body bounces.
const LEG_SWINGS := {
	AnimalKinds.CAT: 0.42, AnimalKinds.DOG: 0.55, AnimalKinds.SQUIRREL: 0.5, AnimalKinds.BEAVER: 0.35,
}
const ACCEL := 3.5
const LOOK_AHEAD := 3.2
## Seconds of standing against something before wanting somewhere else.
const STUCK_PATIENCE := 1.5
## Tries at finding a wander target that is not inside something.
const WANDER_TRIES := 6

## How far below the water surface an animal may stand. A beaver lives at the
## river's edge, which means its wander radius reaches the riverbed itself —
## `field.height_at()` there is the carved channel floor, well under the
## surface, and setting an animal's position straight to it renders the animal
## underwater. A beaver wading ankle-deep is the river doing its job; a beaver
## standing on the bottom of it is a bug.
const MAX_WADE_DEPTH := 0.18

signal cared_for(kind: StringName, coins: int, world_position: Vector3)
signal befriended(kind: StringName)

var field: HeightField
var world_seed: int

## Animals already befriended, by kind. A befriended animal never flees again,
## which is the visible, permanent reward for having looked after it.
var friends: Dictionary = {}

## What to walk round — the places, which know where the slide and the hedge
## are. Optional: a check builds animals without places.
var obstacles: Places = null

var _material: StandardMaterial3D
var _tiles: Dictionary = {}
var _queue: Array[Vector2i] = []
var _centre := Vector2i(9999, 9999)
var _living: Array[Dictionary] = []

func _init(height_field: HeightField, seed_value: int) -> void:
	field = height_field
	world_seed = seed_value

	_material = AnimalKinds.fur_material()

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
	var stamp := PerfLog.stamp()
	_tick(delta)
	PerfLog.note("animals", stamp)

func _tick(delta: float) -> void:
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

		var home := Vector3(x, _footing(x, z), z)
		var node := AnimalKinds.build_node(kind)
		node.position = home
		var heading := rng.randf() * TAU
		node.rotation.y = heading
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
			"heading": heading,
			"velocity": 0.0,
		})

## Where an animal's feet actually rest: the ground, unless the ground here is
## the bed of a river or a lake, in which case no lower than a wade.
func _footing(x: float, z: float) -> float:
	return maxf(field.height_at(x, z), HeightField.WATER_LEVEL - MAX_WADE_DEPTH)

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
	var distance := to_target.length()
	var speed: float = animal.get("speed", SPEED)
	var moving := float(animal.get("velocity", 0.0))
	var heading := float(animal.get("heading", node.rotation.y))

	if distance < 0.4:
		moving = move_toward(moving, 0.0, ACCEL * delta)
		animal["rest"] = float(animal["rest"]) - delta
		if float(animal["rest"]) <= 0.0:
			_pick_wander(animal)
	else:
		var direction := to_target / distance
		var forward := Vector3(-sin(heading), 0.0, -cos(heading))
		if obstacles != null:
			# Lean away from whatever is ahead, and along its side, so the
			# path bends round the slide rather than ending in it.
			var push := obstacles.steer_around(node.position, forward, direction, LOOK_AHEAD)
			if push.length_squared() > 0.0:
				direction = (direction + push).normalized()
		var wanted := atan2(-direction.x, -direction.z)
		var turn_rate := float(TURN_RATES.get(animal["kind"], TURN_RATE))
		heading = lerp_angle(heading, wanted, 1.0 - exp(-turn_rate * delta))
		forward = Vector3(-sin(heading), 0.0, -cos(heading))
		# Speed follows how squarely the body faces where it is going, and
		# eases off on arrival, so a turn is a curve and a stop is a stop.
		var aim := clampf(forward.dot(direction), 0.0, 1.0)
		var wanted_speed := speed * (0.25 + 0.75 * aim) * clampf(distance / 1.5, 0.3, 1.0)
		moving = move_toward(moving, wanted_speed, ACCEL * delta)
		var next := node.position + forward * moving * delta
		if obstacles != null and obstacles.obstructed(next.x, next.z, 0.15):
			# Up against something despite the steering: stand and keep
			# turning — the heading is already swinging along its side — and
			# only after a while of that want somewhere else instead.
			moving = 0.0
			animal["stuck"] = float(animal.get("stuck", 0.0)) + delta
			if float(animal["stuck"]) > STUCK_PATIENCE:
				animal["stuck"] = 0.0
				animal["target"] = node.position
				animal["rest"] = 0.2
		else:
			node.position = next
			animal["stuck"] = 0.0
		node.rotation.y = heading

	animal["heading"] = heading
	animal["velocity"] = moving

	# The gait: a slow breathing bob at rest, a quicker bounce on the move,
	# both as an offset from the ground worked out fresh each frame.
	#
	# It used to be added to the animal's height with `+=`, while the ground
	# was only read again while walking. Two centimetres a frame, sixty times
	# a second, for the seconds an animal stood still: they climbed into the
	# air and stayed there. Reported as animals flying, which is what it was.
	animal["bob"] = float(animal["bob"]) + delta * (3.0 + moving * 6.0)
	var trot := clampf(moving / SPEED, 0.0, 1.0)
	var bob := float(animal["bob"])
	var kind: StringName = animal["kind"]
	var hops := kind == AnimalKinds.SQUIRREL
	node.position.y = (
		_footing(node.position.x, node.position.z)
		+ sin(bob) * 0.02 * (1.0 - trot)
		+ absf(sin(bob)) * (0.02 + minf(moving, 2.5) * (0.05 if hops else 0.02)) * trot
	)
	_stride(node, kind, bob, trot, delta)

## The legs and the body as the animal walks: legs swing in diagonal pairs
## — front-left with hind-right — as far as the kind's stride, or, for the
## squirrel, front and hind together in a hop; standing, they hang straight
## and the body breathes. What made them read as toys on strings was legs
## that never moved.
func _stride(node: Node3D, kind: StringName, bob: float, trot: float, delta: float) -> void:
	var body := node.get_node_or_null("Body") as Node3D
	if body == null:
		return
	var swing_amount := float(LEG_SWINGS.get(kind, 0.45))
	var hops := kind == AnimalKinds.SQUIRREL
	for i in 4:
		var leg := body.get_node_or_null("Leg%d" % i) as Node3D
		if leg == null:
			continue
		var pair := 1.0 if (i == 0 or i == 3) else -1.0
		if hops:
			pair = 1.0 if i < 2 else -1.0
		var swing := sin(bob) * swing_amount * trot * pair
		leg.rotation.x = lerp_angle(leg.rotation.x, swing, 1.0 - exp(-12.0 * delta))
	body.scale.y = 1.0 + 0.015 * sin(bob * 0.5) * (1.0 - trot)
	body.rotation.x = (sin(bob) * 0.04 if hops else 0.0) * trot

## Somewhere else nearby to wander to, and a while to settle when it arrives.
## Constant motion reads as a machine; pauses read as an animal deciding. A
## spot inside the slide or the hedge is not somewhere to wander to, so a few
## are tried; if none is clear, the animal stays where it is a little longer.
func _pick_wander(animal: Dictionary) -> void:
	var home: Vector3 = animal["home"]
	for _try in WANDER_TRIES:
		var angle := randf() * TAU
		var distance := randf() * ROAM
		var spot := home + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
		if obstacles != null and obstacles.obstructed(spot.x, spot.z, 0.4):
			continue
		spot.y = _footing(spot.x, spot.z)
		animal["target"] = spot
		animal["rest"] = randf_range(1.5, 5.0)
		animal["speed"] = SPEED
		return
	animal["rest"] = randf_range(1.0, 2.0)

## Called every frame with where the player is and what they are carrying.
##
## The animals watch rather than being told: nothing in the player or the
## inventory knows that animals exist.
## How long a whistle keeps animals coming, and how far it carries. It reaches
## much further than NOTICE because the point of the whistle is to bring in
## something you cannot see yet.
const WHISTLE_TIME := 6.0
const WHISTLE_RANGE := 46.0

var _whistle := 0.0

## Blow the whistle. Every animal within earshot comes, shy ones included —
## which is the whole point: the squirrel is otherwise nearly uncatchable.
func call_animals() -> int:
	_whistle = WHISTLE_TIME
	var heard := 0
	for animal in _living:
		var node: Node3D = animal["node"]
		if is_instance_valid(node):
			heard += 1
	return heard

func whistle_active() -> bool:
	return _whistle > 0.0

func watch(player_position: Vector3, inventory: Inventory) -> void:
	_whistle = maxf(0.0, _whistle - get_process_delta_time())
	for animal in _living:
		var node: Node3D = animal["node"]
		if not is_instance_valid(node):
			continue
		var kind: StringName = animal["kind"]
		var offset := player_position - node.position
		offset.y = 0.0
		var distance := offset.length()
		var called := _whistle > 0.0 and distance <= WHISTLE_RANGE
		if distance > NOTICE and not called:
			continue

		var wanted := AnimalKinds.want(kind)
		var offered := wanted == &"" or inventory.count(wanted) > 0
		# A whistled animal comes whether or not you are holding what it wants,
		# and whether or not it is shy. Otherwise the whistle would do nothing
		# for the squirrel, which is the animal it exists for.
		var tame := called or friends.has(kind) or offered

		if tame:
			# Come and meet the child, but stop short rather than walking into
			# them, which looks like a bug rather than like interest.
			if distance > REACH * 0.8:
				animal["target"] = player_position - offset.normalized() * REACH * 0.7
				animal["target"].y = _footing(animal["target"].x, animal["target"].z)
				animal["speed"] = SPEED * (1.9 if called else 1.3)
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
		away.y = _footing(away.x, away.z)
		animal["target"] = away
		animal["speed"] = FLEE_SPEED * shy
		animal["rest"] = 0.4

## Every animal currently alive near a point. Read by the voices, which want to
## pick one at random to speak rather than the nearest.
func living_near(at: Vector3, reach: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for animal in _living:
		var node = animal.get("node")
		if node == null or not is_instance_valid(node):
			continue
		if (node as Node3D).global_position.distance_to(at) <= reach:
			out.append(animal)
	return out

## The animal nearest the player that can be cared for right now, or empty.
func nearest_caring(player_position: Vector3, inventory: Inventory) -> Dictionary:
	var best := {}
	var best_distance := REACH
	for animal in _living:
		var node: Node3D = animal["node"]
		if not is_instance_valid(node) or float(animal["cooldown"]) > 0.0:
			continue
		# An animal we cannot feed may still be one we can water, and the caller
		# decides which. Filtering on food alone hid every thirsty squirrel from
		# a player who had a full bottle but no cones.
		var wanted := AnimalKinds.want(animal["kind"])
		if wanted != &"" and inventory.count(wanted) <= 0 and not is_thirsty(animal):
			continue
		var distance := node.position.distance_to(player_position)
		if distance <= best_distance:
			best_distance = distance
			best = animal
	return best

## Thirst is separate from hunger: an animal far from the river wants a drink,
## and that is what makes carrying a bottle worth the twelve coins. Animals that
## live in the water are never thirsty, which is the joke and also the rule.
const THIRSTY_DISTANCE := 60.0

func is_thirsty(animal: Dictionary) -> bool:
	if animal.is_empty() or float(animal["cooldown"]) > 0.0:
		return false
	var kind: StringName = animal["kind"]
	if kind == AnimalKinds.BEAVER:
		return false
	var node: Node3D = animal["node"]
	if not is_instance_valid(node):
		return false
	return field.distance_to_river(node.position.x, node.position.z) > THIRSTY_DISTANCE

## Give it a drink. Pays the same as feeding, and starts the same cooldown, so
## water is an alternative to food rather than a way around the cooldown.
func water_for(animal: Dictionary) -> int:
	if animal.is_empty() or float(animal["cooldown"]) > 0.0:
		return 0
	var kind: StringName = animal["kind"]
	animal["cooldown"] = AnimalKinds.cooldown(kind)
	var coins := AnimalKinds.coins(kind)
	var node: Node3D = animal["node"]
	cared_for.emit(kind, coins, node.position)
	if not friends.has(kind):
		friends[kind] = true
		befriended.emit(kind)
	return coins

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
