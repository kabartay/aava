extends Node3D

## Entry point.
##
## The whole world is one integer: there is no hand-placed scene content in this
## project, because a generated world is the only kind a single developer can
## make large. It also means any bug can be reproduced by sharing a seed.

const DEFAULT_SEED := 20260903

var world: World

func _ready() -> void:
	var seed_value := DEFAULT_SEED
	var override := _seed_from_command_line()
	if override != 0:
		seed_value = override

	world = World.new(seed_value)
	world.name = "World"
	world.ready_at_spawn.connect(_on_world_ready)
	add_child(world)

func _on_world_ready(spawn: Vector3) -> void:
	print("Aava seed %d, spawn %v" % [world.world_seed, spawn])

func _seed_from_command_line() -> int:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			return argument.substr(7).to_int()
	return 0
