class_name World
extends Node3D

## The world itself: ground, water, sky and time.
##
## Kept separate from the game so that anything which needs a world can build
## one — the game, and the screenshot tool that judges how the world looks.
## A tool that renders a different world than the game does is worse than no
## tool at all, so there is exactly one place a world comes from.

signal ready_at_spawn(spawn_point: Vector3)

var world_seed: int
var field: HeightField
var terrain: Terrain
var vegetation: Vegetation
var tree_collision: TreeCollision
var pickups: Pickups
var boulders: Boulders
var animals: Animals
var felled: Felled
var mounts: Mounts
var archery: Archery
var places: Places
var dams: Dams
var hearths: Hearths
var football: FootballGround
var atmosphere: Atmosphere
var water: Water

func _init(seed_value: int) -> void:
	world_seed = seed_value
	field = HeightField.new(seed_value)

func _ready() -> void:
	atmosphere = Atmosphere.new()
	atmosphere.name = "Atmosphere"
	add_child(atmosphere)

	terrain = Terrain.new(field)
	terrain.name = "Terrain"
	add_child(terrain)

	vegetation = Vegetation.new(field, world_seed)
	vegetation.name = "Vegetation"
	add_child(vegetation)

	# The forest is drawn as instances, which have no collision at all. This
	# lends a handful of trunk-shaped bodies to whichever trees are nearest, so
	# a child walking into a tree stops at it.
	tree_collision = TreeCollision.new(vegetation)
	add_child(tree_collision)

	pickups = Pickups.new(field, world_seed)
	pickups.name = "Pickups"
	add_child(pickups)

	boulders = Boulders.new(field, world_seed)
	boulders.name = "Boulders"
	add_child(boulders)

	felled = Felled.new()
	# Set before any tile streams in, or the first tiles draw trees that have
	# already been cut down.
	vegetation.felled = felled

	hearths = Hearths.new(field)
	hearths.name = "Hearths"
	add_child(hearths)

	dams = Dams.new(field)
	dams.name = "Dams"
	add_child(dams)
	dams.rebuild_needed.connect(_on_ground_changed)

	places = Places.new(field)
	places.name = "Places"
	add_child(places)

	archery = Archery.new(field)
	archery.name = "Archery"
	add_child(archery)

	mounts = Mounts.new(field)
	mounts.name = "Mounts"
	add_child(mounts)
	animals = Animals.new(field, world_seed)
	animals.name = "Animals"
	# The animals steer round what the places build — a cat walked straight
	# through the slide and the hedge before they knew about either.
	animals.obstacles = places
	add_child(animals)

	football = FootballGround.new(field)
	football.name = "Football"
	add_child(football)

	water = Water.new()
	water.name = "Water"
	add_child(water)

	var spawn := field.find_spawn_point()
	# The horse waits near the spawn: close enough to be found on the first
	# afternoon, not so close it is the first thing a child trips over.
	mounts.place(MountKinds.HORSE, spawn + Vector3(7.0, 0.0, -5.0))
	# Five boats round the shore of the big pond, the first in Lakes.PONDS:
	# something to row across it in, and to find on the far side.
	mounts.launch_boats(0, 5)
	# The range points away from the camp and away from the pitch, so no arrow
	# ever flies towards somewhere a child stands.
	# Well away from the camp and from the pitch: an arrow and a football should
	# never share a field, and a range you can reach without walking is not a
	# journey. 376 m out, pointing away from everything.
	archery.stand_up(field.camp_centre() + PlaceSpec.RANGE_OFFSET, Vector3(0.6, 0.0, -1.0))
	# The camp constant, not the spawn search: the ground under these is
	# levelled by the height field against that same constant, so using
	# anything else would stand them beside their own flat patch.
	places.stand_up(field.camp_centre())
	follow(spawn)
	ready_at_spawn.emit(spawn)

## Keeps streamed content centred on whoever is looking at it.
## A dam has changed the ground. Everything generated against the old river has
## to be built again — and the height field has to be told first, or the rebuild
## reproduces exactly what was there before.
func _on_ground_changed() -> void:
	field.dams_built = dams.built.duplicate()
	# Only around the dam that changed, not the whole valley: a full rebuild
	# takes seconds of streaming during which the world is visibly missing.
	for site in dams.built:
		var at := Vector3(field.river_centre_x(float(site)), 0.0, float(site))
		terrain.rebuild_near(at, DamSpec.POND_LENGTH + 20.0)
	vegetation.rebuild_all()

var _last_centre := Vector3.ZERO

func follow(world_position: Vector3) -> void:
	_last_centre = world_position
	# Each step timed for the perf log, which names the slowest of a window:
	# a hitch on the phone is otherwise a number with no cause attached.
	var stamp := PerfLog.stamp()
	terrain.follow(world_position)
	PerfLog.note("terrain follow", stamp)
	stamp = PerfLog.stamp()
	vegetation.follow(world_position)
	PerfLog.note("forest follow", stamp)
	stamp = PerfLog.stamp()
	tree_collision.follow(world_position)
	PerfLog.note("trunks", stamp)
	stamp = PerfLog.stamp()
	pickups.follow(world_position)
	boulders.follow(world_position)
	PerfLog.note("pickups+boulders", stamp)
	stamp = PerfLog.stamp()
	animals.follow(world_position)
	PerfLog.note("animals follow", stamp)
	stamp = PerfLog.stamp()
	water.follow(world_position)
	PerfLog.note("water follow", stamp)
