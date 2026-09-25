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

## How far a motorcycle empties the meadow, and how hard everything runs from
## it. Far further than NOTICE: the point of the noise is that you hear it long
## before you see it, and the animals go before you arrive.
const RACKET_RANGE := 30.0
const RACKET_FLIGHT := 1.4

## Set by the game: something loud is being ridden nearby.
var racket := false

## Set by the game: whether the child owns a pair of shears. A sheep with a
## full fleece offers nothing to somebody who cannot cut it, and offering it
## anyway would teach a child to press a button that does nothing.
var has_shears := false

## How quickly an animal comes round to face where it is going, how quickly
## it gets up to speed, and how far ahead it looks for things to walk round.
## Turning was instant and speed was constant, and every animal moved like a
## toy on a string; a body swings round and gathers pace.
const TURN_RATE := 5.0
## Each kind comes round at its own rate: a squirrel whips about, a cat
## flows, a beaver lumbers.
const TURN_RATES := {
	AnimalKinds.CAT: 4.0, AnimalKinds.DOG: 6.0, AnimalKinds.SQUIRREL: 8.5, AnimalKinds.BEAVER: 3.5,
	AnimalKinds.SHEEP: 2.6, AnimalKinds.COW: 2.0,
}
## How far the legs swing at a walk, per kind, and how the body bounces.
const LEG_SWINGS := {
	AnimalKinds.CAT: 0.42, AnimalKinds.DOG: 0.55, AnimalKinds.SQUIRREL: 0.5, AnimalKinds.BEAVER: 0.35,
	AnimalKinds.SHEEP: 0.3, AnimalKinds.COW: 0.26,
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

## Things to walk round that the places know nothing about: the signpost at the
## square, the rides on the fairground, the piers of the bridge. Each is a
## circle — x, radius, z — and the world fills them in as it builds them.
##
## The places keep their own list, and everything built since has been walked
## straight through: a sheep stood in the middle of the signpost's plinth,
## which is the sort of thing that makes a valley feel like a diorama.
var keep_out: Array[Vector3] = []

## Ground that is kept for people. Nothing lives on the fairground, the
## playground, the football pitch or inside the pool fence — except a cat or a
## dog, which is exactly where a cat or a dog would be.
func kept_for_people(x: float, z: float) -> bool:
	if ParkSpec.inside(x, z):
		return true
	if Pitch.is_levelled(x, z):
		return true
	var camp := field.camp_centre()
	if PlaceSpec.inside_the_pool_fence(x, z, camp):
		return true
	return PlaceSpec.influence_of(&"playground", x, z, camp) > 0.45

## May this kind be here at all?
static func belongs_at(kind: StringName, kept: bool) -> bool:
	if not kept:
		return true
	return kind == AnimalKinds.CAT or kind == AnimalKinds.DOG

## Is this spot blocked to an animal — by a place's own furniture, or by
## something else the world has put there?
func blocked_at(x: float, z: float, margin: float) -> bool:
	if obstacles != null and obstacles.obstructed(x, z, margin):
		return true
	for circle in keep_out:
		if Vector2(x - circle.x, z - circle.z).length() < circle.y + margin:
			return true
	return false

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

## Put one animal somewhere, for the checks. The world spawns them by tile and
## by chance, which is no way to ask "what does a cat standing in the lake do".
func put_one_at(kind: StringName, at: Vector3) -> Dictionary:
	var node := AnimalKinds.build_node(kind)
	node.position = at
	add_child(node)
	var animal := {
		"kind": kind,
		"node": node,
		"home": at,
		"target": at,
		"tile": Vector2i.ZERO,
		"rest": 0.0,
		"cooldown": 0.0,
		"bob": 0.0,
		"heading": 0.0,
		"velocity": 0.0,
	}
	_living.append(animal)
	return animal

## Where an animal's feet actually rest: the ground, unless the ground here is
## the bed of a river or a lake, in which case no lower than a wade.
func _footing(x: float, z: float) -> float:
	return maxf(field.height_at(x, z), field.water_level_at(x, z) - MAX_WADE_DEPTH)

## Who lives where. Each animal belongs to the ground it is found on, which is
## how a child learns that cones are a forest thing and beavers are a river one.
func _kind_at(x: float, z: float, rng: RandomNumberGenerator) -> StringName:
	var height := field.height_at(x, z)
	# Ground kept for people takes cats and dogs and nothing else. A sheep on
	# the football pitch is funny once; twenty of them on the fairground, in
	# the pool and under the swings is a valley nobody has charge of.
	var kept := kept_for_people(x, z)
	if kept and rng.randf() < 0.55:
		return &""
	if field.is_pond(x, z) or height < field.water_level_at(x, z) + 0.2:
		return &""
	if Pitch.is_levelled(x, z):
		return &""

	# Which kinds could live at this spot at all, and then how likely each of
	# them is to be here.
	#
	# It used to be a ladder of chances written straight into the code — 0.6
	# for a beaver, 0.7 for a squirrel, 0.35 for a dog — and what fell out of
	# it was five hundred squirrels and two hundred dogs: so many that a child
	# tripped over coins and the shop stopped being something to save for. The
	# numbers come from AnimalKinds.WANTED now, through CHANCE below, and a
	# check counts the valley against them.

	# Beavers on the bank, which is where a beaver is — not in the river.
	#
	# This asked for ground within fourteen metres of the river, and the river
	# is thirty-two metres across: everything that close to it is the bed, and
	# the bed is under water, so the test above had already thrown every such
	# point away. One beaver spawned in the whole valley, and the dam they are
	# there for needs them. The band is the bank now: outside the water, within
	# a short waddle of it, and low.
	var to_river := field.distance_to_river(x, z)
	if to_river < BEAVER_BANK and height < HeightField.WATER_LEVEL + 3.0:
		if kept:
			return &""
		return AnimalKinds.BEAVER if rng.randf() < CHANCE[AnimalKinds.BEAVER] else &""

	if field.forest_density_at(x, z) > 0.3:
		if kept:
			return &""
		return AnimalKinds.SQUIRREL if rng.randf() < CHANCE[AnimalKinds.SQUIRREL] else &""

	if field.steepness_at(x, z) > 0.35 or height > 60.0:
		return &""

	# Open meadow near the middle of the world: the tame ones, and the flocks
	# and herds that make a meadow worth walking across.
	var roll := rng.randf()
	var reached := 0.0
	for kind: StringName in MEADOW:
		reached += float(CHANCE[kind])
		if roll < reached:
			return kind if Animals.belongs_at(kind, kept) else &""
	return &""

## Who lives on open ground, in the order the roll walks through them.
const MEADOW: Array[StringName] = [
	AnimalKinds.SHEEP, AnimalKinds.COW, AnimalKinds.DOG, AnimalKinds.CAT,
]

## How likely each kind is at a candidate spot of its own habitat.
##
## Worked back from AnimalKinds.WANTED and the amount of ground of each kind
## the valley has, both measured rather than guessed: the forest offers about
## 730 candidates over the whole map, the meadows about 700, and the river
## bank about 60. Change a wanted number and these have to be recomputed —
## the check that counts the population is what says so.
const CHANCE := {
	AnimalKinds.SQUIRREL: 0.41,
	AnimalKinds.SHEEP: 0.15,
	AnimalKinds.COW: 0.083,
	AnimalKinds.DOG: 0.095,
	AnimalKinds.CAT: 0.071,
	AnimalKinds.BEAVER: 0.43,
}

func _step(animal: Dictionary, delta: float) -> void:
	var node: Node3D = animal["node"]
	if not is_instance_valid(node):
		return
	# One that is already standing in a pond walks out of it. They are placed
	# on dry ground and never choose a pond to walk to, but a pond can appear
	# under one: the eastern lake was dug where a cat was already living.
	if field.is_pond(node.position.x, node.position.z):
		_head_for_the_bank(animal)
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
		if blocked_at(next.x, next.z, 0.15):
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
			# And it leans with the slope it is walking down. A cow going
			# downhill stayed dead level, hanging in the air at the front and
			# buried at the back, which reads as a cardboard cut-out being slid
			# along rather than an animal walking.
			_lean_with_the_ground(animal, node)
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

## Tip an animal to the ground under it, front to back.
##
## Sampled over the animal's own length, so a sheep notices a bank a cat walks
## over, and held to a limit so nothing stands on its nose at the foot of a
## slope.
func _lean_with_the_ground(animal: Dictionary, node: Node3D) -> void:
	var kind: StringName = animal["kind"]
	var half := AnimalKinds.body_size(kind).z * 0.5
	var facing := node.rotation.y
	var ahead := Vector3(-sin(facing), 0.0, -cos(facing)) * half
	var front := _footing(node.position.x + ahead.x, node.position.z + ahead.z)
	var back := _footing(node.position.x - ahead.x, node.position.z - ahead.z)
	var pitch := clampf(atan2(back - front, half * 2.0), -LEANS_TO, LEANS_TO)
	node.rotation.x = lerpf(node.rotation.x, pitch, 0.2)

## How far an animal will tip to the ground under it.
const LEANS_TO := deg_to_rad(22.0)

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
		if blocked_at(spot.x, spot.z, 0.4):
			continue
		# And not onto ground kept for people, unless it is a cat or a dog.
		if not Animals.belongs_at(animal["kind"], kept_for_people(spot.x, spot.z)):
			continue
		# Not into a pond. An animal wades a river, which is shallow and has
		# two banks; a pond is deep still water, and a cat that walked into one
		# stood there in it up to its neck with nowhere to go.
		if field.is_pond(spot.x, spot.z):
			continue
		spot.y = _footing(spot.x, spot.z)
		animal["target"] = spot
		animal["rest"] = randf_range(1.5, 5.0)
		animal["speed"] = SPEED
		return
	animal["rest"] = randf_range(1.0, 2.0)

## Send an animal to the nearest dry ground. Its home moves too — otherwise it
## wanders straight back into the water it has just come out of.
func _head_for_the_bank(animal: Dictionary) -> void:
	var node: Node3D = animal["node"]
	for ring in 12:
		var out := 6.0 + 8.0 * float(ring)
		for step in 12:
			var bearing := TAU * float(step) / 12.0
			var spot := node.position + Vector3(cos(bearing), 0.0, sin(bearing)) * out
			if field.is_pond(spot.x, spot.z):
				continue
			if field.height_at(spot.x, spot.z) < field.water_level_at(spot.x, spot.z) + 0.2:
				continue
			spot.y = _footing(spot.x, spot.z)
			animal["home"] = spot
			animal["target"] = spot
			animal["rest"] = 0.0
			animal["speed"] = FLEE_SPEED
			return

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
		# An engine sends everything away — the tame ones, the shy ones and the
		# ones that were coming to be fed. This is what a motorcycle costs.
		if racket and distance <= RACKET_RANGE:
			var bolt := node.position + offset.normalized() * -1.0 * ROAM
			var den: Vector3 = animal["home"]
			if bolt.distance_to(den) > ROAM * 2.2:
				bolt = den
			bolt.y = _footing(bolt.x, bolt.z)
			animal["target"] = bolt
			animal["speed"] = FLEE_SPEED * RACKET_FLIGHT
			animal["rest"] = 0.6
			continue
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
		var kind: StringName = animal["kind"]
		# Livestock gives a thing rather than coins: wool from a sheep, milk
		# from a cow. A sheep is no use without shears, so it does not offer
		# itself to a child who has none.
		if AnimalKinds.gives(kind) == ItemKinds.WOOL and not has_shears:
			continue
		var wanted := AnimalKinds.want(kind)
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
## How far from the river a beaver will settle. Past the water's own width, or
## the answer is the riverbed.
const BEAVER_BANK := 46.0

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
	# What livestock hands over. The caller takes it from here rather than
	# from the coins, which are zero for these.
	last_gift = AnimalKinds.gives(kind)
	var node: Node3D = animal["node"]
	cared_for.emit(kind, coins, node.position)

	if not friends.has(kind):
		friends[kind] = true
		befriended.emit(kind)
	return coins

## What the last animal cared for handed over — an item rather than coins, for
## the sheep and the cow — or nothing.
var last_gift := &""

func to_data() -> Array:
	return friends.keys()

func from_data(kinds: Array) -> void:
	friends.clear()
	for kind in kinds:
		friends[StringName(kind)] = true
