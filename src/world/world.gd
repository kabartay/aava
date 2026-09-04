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
var pickups: Pickups
var boulders: Boulders
var animals: Animals
var felled: Felled
var mounts: Mounts
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

	mounts = Mounts.new(field)
	mounts.name = "Mounts"
	add_child(mounts)
	animals = Animals.new(field, world_seed)
	animals.name = "Animals"
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
	follow(spawn)
	ready_at_spawn.emit(spawn)

## Keeps streamed content centred on whoever is looking at it.
func follow(world_position: Vector3) -> void:
	terrain.follow(world_position)
	vegetation.follow(world_position)
	pickups.follow(world_position)
	boulders.follow(world_position)
	animals.follow(world_position)
	water.follow(world_position)
