extends Node3D

## Entry point, and the only place that knows about both the world and the game.
##
## The world does not know it is being played: it streams terrain and scatters
## sticks and asks nothing of anyone. The game — carrying, building, and the
## world's answer to it — is wired together here.

const DEFAULT_SEED := 20260903

## How far above the ground the player is placed, so they settle onto the
## terrain rather than starting a fraction of a metre inside it.
const SPAWN_CLEARANCE := 1.2

## Autosave interval. Frequent enough that nothing a child built is ever lost,
## cheap enough that it is never noticed.
const AUTOSAVE_SECONDS := 20.0

## How far a piece can be from the player and still be taken down. Wider than
## the build reach, because walking up to something you want gone is natural and
## aiming at it is not.
const REMOVE_REACH := 4.0

var world: World
var player: Player
var camera_rig: CameraRig
var hud: Hud
var inventory: Inventory
var structures: Structures
var build_mode: BuildMode
var birds: Birds

var _waiting_for_ground := false
var _autosave := AUTOSAVE_SECONDS
var _seen_first_grove := false

func _ready() -> void:
	InputActions.register()

	var save := SaveGame.read()
	var seed_value := int(save.get("seed", DEFAULT_SEED))
	var override := _seed_from_command_line()
	if override != 0:
		seed_value = override
		save = {}

	inventory = Inventory.new()
	if save.has("inventory"):
		inventory.from_data(save["inventory"])

	world = World.new(seed_value)
	world.name = "World"
	world.ready_at_spawn.connect(_on_world_ready.bind(save))
	add_child(world)

func _on_world_ready(spawn: Vector3, save: Dictionary) -> void:
	if save.has("pickups_taken"):
		world.pickups.from_data(save["pickups_taken"])
	if save.has("time_of_day"):
		world.atmosphere.set_time(float(save["time_of_day"]))
	world.pickups.collected.connect(_on_collected)

	structures = Structures.new(world.field)
	structures.name = "Structures"
	structures.matured.connect(_on_matured)
	structures.groves_changed.connect(_on_groves_changed)
	add_child(structures)
	if save.has("structures"):
		structures.from_data(save["structures"])

	birds = Birds.new()
	birds.name = "Birds"
	add_child(birds)

	world.football.goal_scored.connect(_on_goal)
	world.boulders.jumped.connect(_on_boulder_jumped)
	if save.has("boulders"):
		world.boulders.from_data(save["boulders"])
	if save.has("football"):
		world.football.from_data(save["football"])

	player = Player.new()
	player.name = "Player"
	var start := spawn
	if save.has("player"):
		var at: Dictionary = save["player"]
		start = Vector3(at.get("x", spawn.x), at.get("y", spawn.y), at.get("z", spawn.z))
	player.position = start + Vector3.UP * SPAWN_CLEARANCE
	# Terrain arrives a few chunks per frame, so for the first instants there is
	# nothing under the player's feet. Physics stays off until the ground they
	# are standing on exists, or the game opens with a fall.
	player.set_physics_process(false)
	_waiting_for_ground = true
	player.moved.connect(world.follow)
	add_child(player)

	camera_rig = CameraRig.new(player)
	camera_rig.name = "CameraRig"
	if save.has("camera_yaw"):
		camera_rig.yaw = float(save["camera_yaw"])
	player.add_child(camera_rig)

	build_mode = BuildMode.new(world.field, structures, inventory)
	build_mode.name = "BuildMode"
	add_child(build_mode)

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.set_score(world.football.score)
	Wiring.connect_hud(hud, build_mode, camera_rig, inventory, _on_place, _on_kick_start, _on_kick_release, _on_jump, _on_remove)

	world.follow(start)
	print("Aava seed %d, spawn %v, save at %s" % [world.world_seed, start, SaveGame.absolute_path()])

func _process(delta: float) -> void:
	if player == null:
		return

	if _waiting_for_ground:
		if world.terrain.has_ground_at(player.global_position):
			player.set_physics_process(true)
			_waiting_for_ground = false
		return

	world.pickups.check_reach(player.global_position)
	# The rocks watch the player rather than the player reporting to them, so
	# nothing in the controller has to know that jumping rocks is a game.
	world.boulders.watch(player.global_position, not player.is_on_floor())
	build_mode.aim(player.global_position, camera_rig.yaw)

	# The kick button appears only with a ball at your feet. The keyboard runs
	# through the same two calls as the button, so the two controls cannot end
	# up kicking differently.
	var ball := world.football.ball_near(player.global_position)
	hud.set_ball_in_reach(ball != null)
	if ball != null and Input.is_action_just_pressed(InputActions.KICK):
		_on_kick_start()
	if player.is_charging() and Input.is_action_just_released(InputActions.KICK):
		_on_kick_release()

	# While winding up, show how hard and how high — and drop the wind-up if the
	# ball is kicked away or walked away from, so the bar never lies.
	if player.is_charging():
		if ball == null:
			player.release_charge()
			hud.set_kick_preview(false, 0.0, 0.0)
		else:
			hud.set_kick_preview(true, player.kick_charge, camera_rig.aim_height())
	else:
		hud.set_kick_preview(false, 0.0, 0.0)

	_autosave -= delta
	if _autosave <= 0.0:
		_autosave = AUTOSAVE_SECONDS
		_write_save()

func _on_collected(kind: StringName, _at: Vector3) -> void:
	inventory.add(kind, 1)

func _on_jump() -> void:
	player.request_jump()

## Take down the nearest piece and give the materials back in full.
##
## A full refund is deliberate. A partial one would teach a child that trying
## something costs him, and the whole point of being able to take a wall down is
## that trying costs nothing.
func _on_remove() -> void:
	var record := structures.nearest(player.global_position, REMOVE_REACH)
	if record.is_empty():
		hud.announce("nothing to take down here")
		return
	var kind := structures.remove(record)
	if kind == &"":
		return
	var cost := (
		HouseParts.cost(kind) if HouseParts.is_house_part(kind)
		else BuildKinds.cost(kind)
	)
	for item in cost:
		inventory.add(item, int(cost[item]))
	hud.announce("took the %s back" % (
		HouseParts.label(kind) if HouseParts.is_house_part(kind) else BuildKinds.label(kind)
	), 1.6)

func _on_kick_start() -> void:
	if world.football.ball_near(player.global_position) != null:
		player.start_charging()

func _on_kick_release() -> void:
	var strength := player.release_charge()
	hud.set_kick_preview(false, 0.0, 0.0)
	var ball := world.football.ball_near(player.global_position)
	if ball == null:
		return
	# A tap is a nudge and a hold is a shot, but even the very shortest tap has
	# to move the ball, or a child taps and concludes the button is broken.
	ball.kick(
		player.global_position,
		player.facing(),
		player.is_sprinting(),
		maxf(strength, 0.12),
		camera_rig.aim_height()
	)

func _on_boulder_jumped(_at: Vector3, total: int) -> void:
	hud.announce("cleared it — %d" % total, 1.8)

func _on_goal(_index: int, total: int) -> void:
	hud.set_score(total)
	hud.announce("GOAL", 2.0)

func _on_place() -> void:
	if build_mode.place():
		return
	# A refused build is the moment a child most needs to be told why, and the
	# ghost's colour alone does not say it.
	hud.announce("not here")

func _on_matured(_kind: StringName, _at: Vector3) -> void:
	hud.announce("your tree has grown")

func _on_groves_changed(centres: Array) -> void:
	birds.set_points(structures.attract_points())
	if centres.is_empty():
		return
	if not _seen_first_grove:
		_seen_first_grove = true
		hud.announce("a grove — and the birds have found it", 5.0)

func _notification(what: int) -> void:
	# Both of these arrive when the game is closing: the desktop window button,
	# and Android's back gesture.
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_write_save()

func _write_save() -> void:
	if player == null or world == null:
		return
	var at := player.global_position
	SaveGame.write({
		"seed": world.world_seed,
		"time_of_day": world.atmosphere.time_of_day,
		"player": {"x": at.x, "y": at.y, "z": at.z},
		"camera_yaw": camera_rig.yaw,
		"inventory": inventory.to_data(),
		"structures": structures.to_data(),
		"pickups_taken": world.pickups.to_data(),
		"football": world.football.to_data(),
		"boulders": world.boulders.to_data(),
	})

func _seed_from_command_line() -> int:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			return argument.substr(7).to_int()
	return 0
