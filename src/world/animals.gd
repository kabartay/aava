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

## And each kind's own walking pace.
##
## They all moved at one speed, which for a cow is a brisk human walk and for
## a squirrel is a stroll — and because the legs swing at a rate of their own,
## a cow crossing a meadow slid along with her legs barely moving. A big
## animal is slow and takes long steps; a small one is quick and takes short
## ones, and the two together are what walking looks like.
const SPEEDS := {
	AnimalKinds.COW: 0.85,
	AnimalKinds.SHEEP: 1.05,
	AnimalKinds.BEAVER: 1.2,
	AnimalKinds.CAT: 1.6,
	AnimalKinds.DOG: 1.9,
	AnimalKinds.SQUIRREL: 2.3,
}

static func pace_of(kind: StringName) -> float:
	return float(SPEEDS.get(kind, SPEED))
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
	# The big ones take long steps. Short ones under a body that size read as
	# a table being pushed across the floor.
	AnimalKinds.SHEEP: 0.44, AnimalKinds.COW: 0.5,
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

## The machines and horses standing about, so an animal walks round them.
var parked: Mounts = null

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
	# And whatever is parked in the meadow. A sheep walked through a quad
	# somebody had left standing, which is the sort of thing that makes a
	# valley feel like a screensaver rather than a place.
	if parked != null and is_instance_valid(parked) and parked.blocks(x, z, margin + 0.4):
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
## Where the player was last said to be. Animals far from here are not felt
## for with physics: nobody sees them, and no collider is built out there.
var _player := Vector3.ZERO
var _has_player := false
## One shape query for every feeler, refilled each time, not one made per look.
var _feeler_shape := BoxShape3D.new()
var _feeler := _make_feeler()

func _make_feeler() -> PhysicsShapeQueryParameters3D:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _feeler_shape
	return query

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

	_material = AnimalKinds.fur_material()

func follow(world_position: Vector3) -> void:
	_player = world_position
	_has_player = true
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
		var node := AnimalKinds.build_node(kind, AnimalKinds.variant_at(x, z))
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
	var node := AnimalKinds.build_node(kind, AnimalKinds.variant_at(at.x, at.z))
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
	var afloat := field.is_pond(node.position.x, node.position.z)
	if afloat:
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
		# Arrived: whatever it was stuck on is behind it, so the patience
		# starts afresh rather than carrying a stale count through the rest.
		animal["stuck"] = 0.0
		# Nor does a sidestep carry over to the next errand: its hold only ran
		# down while walking, so one taken on the last step before arriving
		# was still in force, frozen, when the animal set off again, and it
		# turned away from its new target towards the old detour.
		animal["hold"] = 0.0
		animal["rest"] = float(animal["rest"]) - delta
		# A cow with her head down stays where the grass is: grazing is what
		# the rest is for, and it ends when she lifts her head.
		if float(animal["rest"]) <= 0.0 and not bool(animal.get("graze", false)):
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
		var heading_before := heading
		heading = lerp_angle(heading, wanted, 1.0 - exp(-turn_rate * delta))
		forward = Vector3(-sin(heading), 0.0, -cos(heading))
		# Speed follows how squarely the body faces where it is going, and
		# eases off on arrival, so a turn is a curve and a stop is a stop.
		var aim := clampf(forward.dot(direction), 0.0, 1.0)
		var wanted_speed := speed * (0.25 + 0.75 * aim) * clampf(distance / 1.5, 0.3, 1.0)
		moving = move_toward(moving, wanted_speed, ACCEL * delta)
		var next := node.position + forward * moving * delta
		var blocked := blocked_at(next.x, next.z, 0.15)
		# Run down whether or not it is felt for this frame: standing against
		# something, or being out of range, must not freeze a sidestep.
		animal["hold"] = maxf(0.0, float(animal.get("hold", 0.0)) - delta)
		if not blocked and moving > 0.01 and _worth_feeling_for(node.position):
			# And whatever solid the world has put in the way that no list
			# knows about: fences, gates, the rides' platforms and frames,
			# houses a child has built. Felt for ahead, and walked along
			# rather than stopped at.
			# A sidestep, once taken, is kept for a moment. Without that the
			# heading swung back at the target the frame after, the feeler
			# found the fence again, and the animal flickered along it.
			var hold := float(animal.get("hold", 0.0))
			var base: Vector3 = animal.get("way", forward) if hold > 0.0 else forward
			var way := _clear_way(animal, node, base, direction)
			if way != Vector3.ZERO and (way != forward) and (hold <= 0.0 or way != base):
				animal["way"] = way
				hold = SIDESTEP_HOLD
			animal["hold"] = hold
			if way == Vector3.ZERO:
				blocked = true
			elif way != forward:
				# One turn this frame, from where it started, towards the
				# sidestep instead of the target: turning towards the target
				# and then again towards the sidestep wobbled along a fence.
				heading = lerp_angle(
					heading_before, atan2(-way.x, -way.z), 1.0 - exp(-turn_rate * delta)
				)
				next = node.position + way * moving * delta
				blocked = blocked_at(next.x, next.z, 0.15)
		# And not into a pond. Only the wander picks a spot that is dry; a
		# child at the water's edge, a flight from a motorcycle or a straight
		# line across a bend all name targets over the water, and the animal
		# waded in, was turned out by the check at the top of this function,
		# and was sent back in by the next call to `watch`. One already afloat
		# is let walk, or it could never get out.
		if not blocked and not afloat and field.is_pond(next.x, next.z):
			blocked = true
		if blocked:
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
			_lean_with_the_ground(animal, node, delta)
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
	# Big animals stride slowly. The rate was the same for every kind, so a
	# cow trotted her legs at a squirrel's cadence while her body crawled.
	var cadence := 1.0 / sqrt(maxf(AnimalKinds.size_of(animal["kind"]), 0.2))
	animal["bob"] = float(animal["bob"]) + delta * (3.0 + moving * 6.0) * cadence
	var trot := clampf(moving / Animals.pace_of(animal["kind"]), 0.0, 1.0)
	var bob := float(animal["bob"])
	var kind: StringName = animal["kind"]
	var hops := kind == AnimalKinds.SQUIRREL
	node.position.y = (
		_footing(node.position.x, node.position.z)
		# Enough to keep a long animal on a steep hill out of the ground:
		# see the note in _lean_with_the_ground.
		+ float(animal.get("lift", 0.0))
		+ sin(bob) * 0.02 * (1.0 - trot)
		+ absf(sin(bob)) * (0.02 + minf(moving, 2.5) * (0.05 if hops else 0.02)) * trot * (1.0 + 0.5 * run_of(kind, moving))
	)
	_stride(animal, node, kind, bob, trot, delta)
	_head_and_tail(animal, node, kind, bob, moving, trot, delta)

## Which way a leg swings with the sine of the stride: diagonal pairs for a
## walk, every leg together for the squirrel's hop. The hop used to send the
## front legs forward as the hind ones went back, which is a stretch, not a
## bound.
static func leg_phase(index: int, hops: bool) -> float:
	if hops:
		return 1.0
	return 1.0 if (index == 0 or index == 3) else -1.0

## The legs and the body as the animal walks: legs swing in diagonal pairs
## — front-left with hind-right — as far as the kind's stride, or, for the
## squirrel, front and hind together in a hop; standing, they hang straight
## and the body breathes. What made them read as toys on strings was legs
## that never moved.
func _stride(animal: Dictionary, node: Node3D, kind: StringName, bob: float, trot: float, delta: float) -> void:
	var body := node.get_node_or_null("Body") as Node3D
	if body == null:
		return
	# Found once and kept: four name lookups an animal a frame add up.
	var legs: Array = animal.get("legs", [])
	if legs.is_empty():
		for i in 4:
			var found := body.get_node_or_null("Leg%d" % i) as Node3D
			if found != null:
				legs.append(found)
		animal["legs"] = legs
	var swing_amount := float(LEG_SWINGS.get(kind, 0.45))
	var hops := kind == AnimalKinds.SQUIRREL
	var run := run_of(kind, float(animal.get("velocity", 0.0)))
	for i in legs.size():
		var leg: Node3D = legs[i]
		var pair := leg_phase(i, hops)
		# Walking, the diagonal pairs swing against each other. Running, the
		# front pair and the hind pair each go together, one behind the other,
		# and the whole stride is longer: the blend runs from one to the
		# other as the speed rises, so a cat that bolts does not keep the
		# legs of a cat that is strolling.
		var offset := 0.0
		if not hops:
			offset = lerpf(0.0, GALLOP[i] - (PI if pair < 0.0 else 0.0), run)
		var swing := sin(bob + offset) * swing_amount * (1.0 + 0.6 * run) * trot * pair
		# Eased quickly enough to keep up: a run cycles the legs at a rate the
		# walk's easing smooths away to a third of their swing, which left a
		# bolting cat with legs that barely moved.
		leg.rotation.x = lerp_angle(leg.rotation.x, swing, 1.0 - exp(-(12.0 + 150.0 * run) * delta))
	body.scale.y = 1.0 + 0.015 * sin(bob * 0.5) * (1.0 - trot)
	# The back flexes in a run, and the squirrel's whole body in its hop.
	body.rotation.x = (sin(bob) * 0.04 if hops else sin(bob + 1.0) * 0.05 * run) * trot

## Where in its stride each leg is when running, front-left first: the fronts
## land together and the hinds follow them, rather than the walk's diagonals.
const GALLOP: Array[float] = [0.0, 0.5, 2.6, 3.1]

## How far into a run an animal at this speed is, 0 at a walk and 1 flat out.
## A walk is its kind's own pace; the run begins well above it, so an animal
## easing in and out of a walk never breaks into one. Before, the legs knew
## only "how fast", clamped to the walking pace, and a cat bolting from a
## motorcycle at nearly three times its pace swung them exactly as it did
## strolling.
static func run_of(kind: StringName, speed: float) -> float:
	return clampf((speed / pace_of(kind) - 1.3) / 0.9, 0.0, 1.0)

## How far the head goes down to the grass, per kind that grazes, in radians
## about the foot of the neck. Chosen so the mouth is just above the ground:
## a check measures it off the drawn head.
const GRAZE_PITCH := {
	AnimalKinds.COW: 0.55,
	AnimalKinds.SHEEP: 0.85,
}

## How far to either side the head turns to look, and how far a head turns to
## follow somebody standing near.
const LOOK_YAW := 0.95
const WATCH_RANGE := 5.0

## The head and the tail, which are nodes of their own.
##
## Standing, an animal used to be a statue that breathed: the head was part of
## the body and the tail part of it too. Now a cow or a sheep drops her head to
## graze for several seconds at a time and lifts it to look about; the others
## turn their heads to glance round, and all of them look at a child who comes
## near; and the tail of a cat, a dog, a squirrel and a cow moves. Walking, the
## head nods with the stride.
##
## It costs a handful of arithmetic and no allocation: the two nodes are found
## once and kept, and the choice of what to do next is made when the last has
## run out, every few seconds, not every frame.
func _head_and_tail(
	animal: Dictionary, node: Node3D, kind: StringName, bob: float, moving: float, trot: float, delta: float
) -> void:
	if not animal.has("head"):
		animal["head"] = node.get_node_or_null("Head")
		animal["tail"] = node.get_node_or_null("Tail")
	var head := animal["head"] as Node3D
	var tail := animal["tail"] as Node3D
	var near_you := false
	var toward_you := 0.0
	if _has_player:
		var to_player := _player - node.position
		to_player.y = 0.0
		if to_player.length_squared() < WATCH_RANGE * WATCH_RANGE:
			near_you = true
			# Relative to the body: the head turns on the neck, and no neck
			# looks straight behind.
			toward_you = clampf(
				wrapf(atan2(-to_player.x, -to_player.z) - node.rotation.y, -PI, PI), -1.1, 1.1
			)

	if head != null:
		var yaw := 0.0
		var pitch := 0.0
		var graze := bool(animal.get("graze", false))
		if moving > 0.25:
			graze = false
			animal["look_t"] = 0.0
			yaw = 0.0
			# The head nods with the stride, a little more on the big ones.
			pitch = sin(bob) * (0.06 if GRAZE_PITCH.has(kind) else 0.035) * trot
		elif near_you:
			graze = false
			animal["look_t"] = 0.0
			yaw = toward_you
		else:
			var left := float(animal.get("look_t", 0.0)) - delta
			if left <= 0.0:
				# Time to do something else. A grazer mostly grazes; a glance
				# is a second or two, grazing five to ten.
				# Only one that has arrived: one already sent somewhere else
				# would be grazing with its mind on a walk.
				var settled := (animal["target"] as Vector3).distance_to(node.position) < 0.5
				graze = GRAZE_PITCH.has(kind) and settled and randf() < 0.6
				if graze:
					left = randf_range(5.0, 10.0)
				else:
					left = randf_range(1.2, 3.5)
					# Half the glances are back to straight ahead.
					animal["look_yaw"] = randf_range(-LOOK_YAW, LOOK_YAW) if randf() < 0.6 else 0.0
					animal["look_pitch"] = randf_range(-0.12, 0.2)
			animal["look_t"] = left
			if graze:
				pitch = float(GRAZE_PITCH[kind])
				# Chewing: the head bobs a little as it works along the grass.
				pitch += sin(bob * 5.0) * 0.05
				yaw = sin(bob * 0.4) * 0.15
			else:
				yaw = float(animal.get("look_yaw", 0.0))
				pitch = -float(animal.get("look_pitch", 0.0))
		animal["graze"] = graze
		# `pitch` is how far down; down is a negative turn about X, since a
		# positive angle lifts what is at -Z, which is the nose.
		var blend := 1.0 - exp((-3.0 if graze else -5.0) * delta)
		animal["head_x"] = lerpf(float(animal.get("head_x", 0.0)), -pitch, blend)
		head.rotation.x = float(animal["head_x"])
		head.rotation.y = lerpf(head.rotation.y, yaw, blend)

	if tail != null:
		var glad := near_you and kind == AnimalKinds.DOG
		var rate := 1.5
		var reach := 0.0
		match kind:
			AnimalKinds.DOG:
				# A wag that is fast and wide for somebody it knows, and an
				# easy sway when it is only walking.
				rate = 11.0 if glad else 4.0
				reach = 0.6 if glad else (0.3 if moving > 0.25 else 0.12)
			AnimalKinds.CAT:
				rate = 2.0 + moving
				reach = 0.28
			AnimalKinds.SQUIRREL:
				rate = 7.0 if moving > 0.25 else 2.5
				reach = 0.16
			_:
				# A cow's tail swishes in bursts, at flies.
				rate = 2.2
				reach = 0.12 + 0.35 * maxf(0.0, sin(bob * 0.17))
		var wag := float(animal.get("wag", 0.0)) + delta * rate
		animal["wag"] = wag
		var amount := lerpf(float(animal.get("wag_reach", reach)), reach, 1.0 - exp(-6.0 * delta))
		animal["wag_reach"] = amount
		tail.rotation.y = sin(wag) * amount
		if kind == AnimalKinds.SQUIRREL:
			# A squirrel's flicks up and down, not side to side.
			tail.rotation.x = sin(wag) * amount
			tail.rotation.y = 0.0

## Tip an animal to the ground under it, front to back.
##
## Sampled over the animal's own length, so a sheep notices a bank a cat walks
## over, and held to a limit so nothing stands on its nose at the foot of a
## slope.
func _lean_with_the_ground(animal: Dictionary, node: Node3D, delta: float) -> void:
	var kind: StringName = animal["kind"]
	var half := AnimalKinds.body_size(kind).z * 0.5
	var facing := node.rotation.y
	var ahead := Vector3(-sin(facing), 0.0, -cos(facing)) * half
	var front := _footing(node.position.x + ahead.x, node.position.z + ahead.z)
	var back := _footing(node.position.x - ahead.x, node.position.z - ahead.z)
	# front - back, not back - front.
	#
	# Rotating about the body's own X by a positive angle lifts what is at -Z,
	# and -Z is the animal's nose: so ground that falls away ahead was making
	# her put her nose up and drive her hindquarters into the hill. On a cow
	# that is nearly half a metre of animal underground, which is how it was
	# reported — "half the cow is stuck in the ground" — and it is the same
	# sign error as the cow who came down the slope looking horizontal.
	var pitch := clampf(atan2(front - back, half * 2.0), -LEANS_TO, LEANS_TO)
	# 1 - exp(-k*delta), like the leg swing two functions up and everything else
	# eased in this project. A flat 0.2 a frame settles twice as fast on a
	# 120 Hz phone as on a 60 Hz one — and since the height an animal stands at
	# is read back off this same rotation just below, a cow on a hill stood at a
	# different height depending on the screen she was drawn on.
	node.rotation.x = lerpf(node.rotation.x, pitch, 1.0 - exp(-12.0 * delta))

	# And how high she has to stand to be on the hill rather than in it.
	#
	# The body is tipped about the point between her feet, and the tip is
	# capped at LEANS_TO — so on anything steeper than that the downhill end
	# of a long animal is left under the ground. A positive turn lifts the
	# nose by half a body length times its sine and drops the tail by the
	# same, so the height that clears both ends is the larger of the two
	# demands. On a slope gentler than the cap this comes out at nought,
	# which is what it should: a cow on a gentle hill is not on stilts.
	var leaning := sin(node.rotation.x) * half
	var stand := maxf(front - leaning, back + leaning)
	animal["lift"] = maxf(
		0.0, stand - _footing(node.position.x, node.position.z)
	)

## How far an animal will tip to the ground under it.
const LEANS_TO := deg_to_rad(22.0)

## What an animal's feelers stop for: the ground layer, where the fairground,
## the bridge and the houses stand, and the props layer, where fences, posts
## and furniture are.
const FEEL_MASK := TerrainSpec.LAYER_GROUND | TerrainSpec.LAYER_PROPS
## How far either side of straight ahead an animal looks for a way past
## something solid, nearest first.
## Beyond this many metres from the player, animals do not feel for solids.
const FEEL_RANGE := 60.0
## How long, in seconds, a sidestep is kept to before looking at the target again.
const SIDESTEP_HOLD := 0.6
const SIDESTEPS: Array[float] = [0.6, 1.2, 1.8]

## Which way to walk this step: straight on if nothing solid is there, else
## the first clear bearing to one side or the other, trying the side towards
## where it wants to go first, and keeping to that side once it has picked
## one so it follows a fence along rather than dithering at it. Nothing clear
## at all comes back as zero.
##
## Every solid thing the world builds has a collider, and almost none of them
## were on the animals' own lists: a cat walked through the fairground's gate,
## sheep stood inside the rides' platforms. Asking the physics world means a
## thing built tomorrow is walked round without anybody remembering to say so.
func _clear_way(animal: Dictionary, node: Node3D, forward: Vector3, toward: Vector3) -> Vector3:
	if not node.is_inside_tree():
		return forward
	var at := node.global_position
	if not _solid_ahead(animal, at, forward):
		animal.erase("side")
		return forward
	var side := float(animal.get("side", 0.0))
	if side == 0.0:
		side = 1.0 if forward.cross(toward).y >= 0.0 else -1.0
	for turn in SIDESTEPS:
		for sign: float in [side, -side]:
			var way := forward.rotated(Vector3.UP, turn * sign)
			if not _solid_ahead(animal, at, way):
				animal["side"] = sign
				return way
	return Vector3.ZERO

## Is this close enough to the player to be worth asking the physics world
## about? Before the player is known, everywhere is.
func _worth_feeling_for(at: Vector3) -> bool:
	if not _has_player:
		return true
	var gap := at - _player
	return gap.x * gap.x + gap.z * gap.z <= FEEL_RANGE * FEEL_RANGE

## Is there something solid within a stride ahead of this animal? Felt at two
## heights, a low one for platforms and kerbs and one at the body, for rails.
func _solid_ahead(animal: Dictionary, at: Vector3, way: Vector3) -> bool:
	var space := _space()
	if space == null:
		return false
	var kind: StringName = animal["kind"]
	var size := AnimalKinds.body_size(kind)
	# One box as wide as the animal, laid just ahead of its nose, from the
	# shins to the top of the body: a single line down the middle let a cow
	# pass a post a hand's breadth off it with her flank in the post.
	var low := 0.15
	var high := maxf(AnimalKinds.size_of(kind) * 0.45 + size.y * 0.5, low + 0.1)
	var depth := 0.4
	_feeler_shape.size = Vector3(maxf(size.x, 0.1), high - low, depth)
	var query := _feeler
	var facing := Basis(Vector3.UP, atan2(-way.x, -way.z))
	query.transform = Transform3D(
		facing, at + way * (size.z * 0.5 + 0.05) + Vector3(0.0, (low + high) * 0.5, 0.0)
	)
	query.collision_mask = FEEL_MASK
	query.exclude = []
	# A hit on something an animal walks through anyway is looked past, a few
	# times, in case a fence stands just behind it.
	for _look in 3:
		var found := space.intersect_shape(query, 8)
		var skip := query.exclude
		var seen := false
		for hit in found:
			var thing := hit["collider"] as Object
			if thing != null and thing.has_meta(TerrainSpec.ANIMALS_IGNORE):
				skip.append(hit["rid"])
				seen = true
			else:
				return true
		if not seen:
			break
		query.exclude = skip
	return false

## Is this spot inside something solid — somewhere not to wander to?
func _solid_at(spot: Vector3) -> bool:
	var space := _space()
	if space == null:
		return false
	var query := PhysicsPointQueryParameters3D.new()
	query.position = spot + Vector3(0.0, 0.35, 0.0)
	query.collision_mask = FEEL_MASK
	for found in space.intersect_point(query, 6):
		var thing := found["collider"] as Object
		if thing != null and not thing.has_meta(TerrainSpec.ANIMALS_IGNORE):
			return true
	return false

func _space() -> PhysicsDirectSpaceState3D:
	if not is_inside_tree():
		return null
	var viewport := get_viewport()
	if viewport == null or viewport.world_3d == null:
		return null
	return viewport.world_3d.direct_space_state

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
		if _solid_at(Vector3(spot.x, _footing(spot.x, spot.z), spot.z)):
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
		animal["speed"] = Animals.pace_of(animal["kind"])
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
