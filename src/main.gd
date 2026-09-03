extends Node3D

## Entry point.
##
## The whole world is one integer: there is no hand-placed scene content in this
## project, because a generated world is the only kind a single developer can
## make large enough. It also means any bug can be reproduced by sharing a seed.

const DEFAULT_SEED := 20260903

## How far above the ground the player is placed, so that they settle onto the
## terrain rather than starting a fraction of a metre inside it.
const SPAWN_CLEARANCE := 1.2

var world: World
var player: Player
var camera_rig: CameraRig
var hud: Hud

var _waiting_for_ground := false

func _ready() -> void:
	InputActions.register()

	var seed_value := DEFAULT_SEED
	var override := _seed_from_command_line()
	if override != 0:
		seed_value = override

	world = World.new(seed_value)
	world.name = "World"
	world.ready_at_spawn.connect(_on_world_ready)
	add_child(world)

func _on_world_ready(spawn: Vector3) -> void:
	player = Player.new()
	player.name = "Player"
	player.position = spawn + Vector3.UP * SPAWN_CLEARANCE
	# Terrain arrives a few chunks per frame, so for the first instants there is
	# nothing under the player's feet. Physics stays off until the ground they
	# are standing on actually exists, otherwise the game opens with a fall.
	player.set_physics_process(false)
	_waiting_for_ground = true
	player.moved.connect(world.follow)
	add_child(player)

	camera_rig = CameraRig.new(player)
	camera_rig.name = "CameraRig"
	player.add_child(camera_rig)

	hud = Hud.new()
	hud.name = "Hud"
	hud.camera_dragged.connect(camera_rig.orbit)
	add_child(hud)

	print("Aava seed %d, spawn %v" % [world.world_seed, spawn])

func _process(_delta: float) -> void:
	if not _waiting_for_ground:
		return
	if world.terrain.has_ground_at(player.global_position):
		player.set_physics_process(true)
		_waiting_for_ground = false

func _seed_from_command_line() -> int:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			return argument.substr(7).to_int()
	return 0
