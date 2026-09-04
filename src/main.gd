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
var sounds: Sounds
var tasks: Tasks
var wallet: Wallet
var vitals: Vitals
var journal: Journal

var _waiting_for_ground := false
var _autosave := AUTOSAVE_SECONDS
var _seen_first_grove := false

func _ready() -> void:
	InputActions.register()

	var save := SaveGame.read()
	# The language is read before anything is built, so the first frame is
	# already in the right one rather than flashing English.
	Text.set_language(StringName(save.get("language", Text.EN)))

	var seed_value := int(save.get("seed", DEFAULT_SEED))
	var override := _seed_from_command_line()
	if override != 0:
		seed_value = override
		save = {}

	inventory = Inventory.new()
	if save.has("inventory"):
		inventory.from_data(save["inventory"])

	# Sound is created before the world, so the very first pickup is audible.
	sounds = Sounds.new()
	add_child(sounds)

	tasks = Tasks.new()
	tasks.name = "Tasks"
	add_child(tasks)

	wallet = Wallet.new()
	if save.has("wallet"):
		wallet.from_data(save["wallet"])

	vitals = Vitals.new()
	# The bottle is a shop purchase, so a restored game that already bought one
	# still carries it.
	if wallet.has(ShopStock.BOTTLE):
		vitals.grant_bottle()
	if save.has("vitals"):
		vitals.from_data(save["vitals"])

	journal = Journal.new()
	if save.has("journal"):
		journal.from_data(save["journal"])
	journal.arrive(int(Time.get_unix_time_from_system()))
	_greet_on_arrival(save)

	vitals.energy_changed.connect(func(_f: float) -> void: _refresh_vitals())
	vitals.water_changed.connect(func(_f: float) -> void: _refresh_vitals())
	vitals.exhausted.connect(func() -> void: hud.announce(Text.of("say_tired"), 3.0))
	vitals.revived.connect(func() -> void: hud.announce(Text.of("say_rested"), 2.0))

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
	if save.has("tasks"):
		tasks.from_data(save["tasks"])
	if save.has("animals"):
		world.animals.from_data(save["animals"])
	if save.has("felled"):
		world.felled.from_data(save["felled"])

	world.animals.cared_for.connect(func(_kind: StringName, _coins: int, _at: Vector3) -> void: pass)
	world.animals.befriended.connect(func(kind: StringName) -> void:
		hud.announce(Text.format("say_friend", [AnimalKinds.label(kind)]), 4.0))
	wallet.changed.connect(func(total: int) -> void: hud.set_coins(total))

	# The reward line is an announcement; the instruction is a standing label.
	# Keeping them separate is what stops the screen filling with old advice.
	tasks.completed.connect(func(reward: String) -> void:
		sounds.play(Sounds.Sound.CHIME)
		hud.announce(reward, 4.5))
	tasks.changed.connect(func(instruction: String) -> void: hud.set_task(instruction))
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
	player.jumped.connect(func() -> void: sounds.play(Sounds.Sound.JUMP))
	player.landed.connect(func(speed: float) -> void:
		sounds.play(Sounds.Sound.LAND, clampf(1.2 - speed * 0.02, 0.75, 1.2)))
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
	Wiring.connect_hud(hud, build_mode, camera_rig, inventory, world.field, player, structures, _handlers())

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
	world.animals.watch(player.global_position, inventory)

	# Energy follows what the player actually did this frame, and gates running
	# on the next one.
	vitals.advance(delta, player.is_running, player.is_moving)
	player.may_run = vitals.can_run()

	# Standing in the shallows fills the bottle without a button. A child who
	# walks into the river to fill up has already expressed the intent; asking
	# him to also find a control would be asking twice.
	if vitals.has_bottle and _standing_in_water():
		if vitals.fill():
			sounds.play(Sounds.Sound.SPLASH)
			hud.announce(Text.of("say_filled"), 1.6)

	# The axe only offers itself when there is a tree to use it on.
	hud.set_tree_in_reach(
		wallet.has(ShopStock.AXE)
		and not world.vegetation.nearest_tree(player.global_position, CHOP_REACH).is_zero_approx()
	)

	# The care button says what the animal in front of you wants, at the moment
	# you can do something about it.
	var near_animal := world.animals.nearest_caring(player.global_position, inventory)
	hud.set_animal_in_reach(
		AnimalKinds.wish(near_animal["kind"]) if not near_animal.is_empty() else ""
	)
	tasks.on_moved(player.global_position)
	build_mode.aim(player.global_position, camera_rig.yaw)
	hud.set_storey(build_mode.storey(), build_mode.active and HouseParts.is_house_part(build_mode.selected))

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
	# Pitched by how many you already have, so a run of pickups climbs a scale
	# instead of repeating one note. It costs nothing and turns collecting into
	# something that sounds like progress.
	var held := inventory.count(kind)
	sounds.play(Sounds.Sound.PICKUP, 1.0 + minf(float(held % 6), 5.0) * 0.045)
	tasks.on_collected(inventory)

## Switching language rebuilds the interface rather than trying to retranslate
## it in place. Every button was created with its text baked in, and hunting
## down each one to update it is the kind of job that is always one label short.
func _on_language(code: StringName) -> void:
	Text.set_language(code)
	_write_save()
	_rebuild_hud()

## Throw the valley away and start it over, keeping the same seed so it is the
## same place rather than a different one.
##
## Everything a child made goes: what they carried, what they built, which
## pickups they had taken, the score. The seed stays because "start again"
## should mean a clean morning in the valley you know, not exile to a new one.
func _on_reset() -> void:
	if structures != null:
		structures.from_data([])
	inventory.from_data({})
	world.pickups.from_data([])
	world.boulders.from_data({})
	world.football.from_data({})
	birds.set_points([])
	_seen_first_grove = false
	world.follow(player.global_position)
	_write_save()
	_rebuild_hud()
	hud.announce(Text.of("say_reset"), 3.0)

func _rebuild_hud() -> void:
	var was_building := build_mode.active
	if hud != null:
		hud.queue_free()
	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	Wiring.connect_hud(hud, build_mode, camera_rig, inventory, world.field, player, structures, _handlers())
	hud.set_score(world.football.score)
	if was_building:
		hud.set_building(true)

## Every control's handler in one place, named rather than ordered.
func _handlers() -> Dictionary:
	return {
		&"place": _on_place,
		&"kick_start": _on_kick_start,
		&"kick_release": _on_kick_release,
		&"jump": _on_jump,
		&"remove": _on_remove,
		&"language": _on_language,
		&"reset": _on_reset,
		&"care": _on_care,
		&"shop": _on_shop,
		&"buy": _on_buy,
		&"drink": _on_drink,
		&"whistle": _on_whistle,
		&"chop": _on_chop,
	}

## Feeding or stroking whatever is in front of the player.
## What the valley says when a child comes back. One line, after a beat, so it
## does not collide with the opening task and is not missed while the world is
## still streaming in.
func _greet_on_arrival(save: Dictionary) -> void:
	# A brand new world has nothing to remember and should not pretend to.
	if not save.has("journal") or journal.visits <= 1:
		return

	var grown := 0
	if journal.last_seen > 0 and journal.days_away >= 0:
		var away := float(Time.get_unix_time_from_system() - journal.last_seen)
		grown = structures.advance_offline(away)

	var line := ""
	if journal.has_last_visit():
		var headline := journal.headline()
		var key: StringName = headline[0]
		var count: int = headline[1]
		if key != &"":
			line = Text.format("back_%s" % key, [count])
	if line.is_empty() and grown > 0:
		line = Text.of("back_grown")
	if line.is_empty():
		line = Text.of("back_welcome")
	elif grown > 0:
		line += ". " + Text.of("back_grown")

	# After the world has actually appeared, or it is read against a grey screen.
	await get_tree().create_timer(1.6).timeout
	if is_instance_valid(hud):
		hud.announce(line, 6.0)

func _refresh_vitals() -> void:
	hud.set_vitals(vitals.fraction(), vitals.water_fraction(), vitals.has_bottle)

## True when the player is standing in water shallow enough to reach into.
func _standing_in_water() -> bool:
	var at := player.global_position
	return at.y < HeightField.WATER_LEVEL + 0.9 and world.field.distance_to_river(at.x, at.z) < 30.0

## How much wood a tree is worth, and how far you must be to reach it.
const CHOP_REACH := 3.4
const WOOD_PER_TREE := 4

func _on_chop() -> void:
	if not wallet.has(ShopStock.AXE):
		return
	var tree := world.vegetation.nearest_tree(player.global_position, CHOP_REACH)
	if tree.is_zero_approx():
		return
	world.felled.fell(tree)
	# The forest is a MultiMesh generated from the seed, so the tree cannot be
	# deleted — the tiles are rebuilt against the new record instead.
	world.vegetation.rebuild_around(tree)
	inventory.add(&"wood", WOOD_PER_TREE)
	sounds.play(Sounds.Sound.REMOVE, 0.7)
	hud.announce(Text.format("say_felled", [WOOD_PER_TREE]), 2.2)

func _on_whistle() -> void:
	if not wallet.has(ShopStock.WHISTLE):
		return
	world.animals.call_animals()
	sounds.play(Sounds.Sound.CHIME, 1.6)
	hud.announce(Text.of("say_whistled"), 1.8)

func _on_drink() -> void:
	if vitals.drink():
		sounds.play(Sounds.Sound.PICKUP)
	_refresh_vitals()

func _on_care() -> void:
	var animal := world.animals.nearest_caring(player.global_position, inventory)
	if animal.is_empty():
		return
	# A thirsty animal takes water rather than food. This is the bottle's second
	# use and the reason it is the cheapest thing in the shop.
	if world.animals.is_thirsty(animal) and vitals.has_bottle and vitals.water >= Vitals.DRINK:
		if vitals.pour():
			var reward := world.animals.water_for(animal)
			wallet.earn(reward)
			journal.record(Journal.CARED)
			journal.record(Journal.COINS, reward)
			sounds.play(Sounds.Sound.SPLASH)
			hud.announce(Text.format("say_watered", [AnimalKinds.label(animal["kind"])]), 2.0)
			_refresh_vitals()
			return

	var coins := world.animals.care_for(animal, inventory)
	if coins <= 0:
		return
	wallet.earn(coins)
	journal.record(Journal.CARED)
	journal.record(Journal.COINS, coins)
	sounds.play(Sounds.Sound.CHIME, 1.15)
	hud.announce(Text.format("say_fed", [coins]), 1.4)

func _on_shop() -> void:
	hud.set_shop_open(not hud.is_shop_open(), wallet.coins, wallet.owned)

func _on_buy(item: StringName) -> void:
	if wallet.buy(item, ShopStock.price(item)):
		if item == ShopStock.BOTTLE:
			vitals.grant_bottle()
			_refresh_vitals()
		hud.set_owned(wallet.owned)
		sounds.play(Sounds.Sound.GOAL)
		hud.announce(Text.format("say_bought", [ShopStock.label(item)]), 3.0)
	else:
		sounds.play(Sounds.Sound.REFUSE)
		hud.announce(Text.of("say_too_dear"), 2.0)
	hud.set_shop_open(true, wallet.coins, wallet.owned)

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
		hud.announce(Text.of("say_nothing_here"))
		return
	var kind := structures.remove(record)
	if kind == &"":
		return
	sounds.play(Sounds.Sound.REMOVE)
	var cost := (
		HouseParts.cost(kind) if HouseParts.is_house_part(kind)
		else BuildKinds.cost(kind)
	)
	for item in cost:
		inventory.add(item, int(cost[item]))
	hud.announce(Text.format("say_took_back", [
		HouseParts.label(kind) if HouseParts.is_house_part(kind) else BuildKinds.label(kind)
	]), 1.6)

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
	sounds.play(Sounds.Sound.KICK, 0.85 + strength * 0.4)
	ball.kick(
		player.global_position,
		player.facing(),
		player.is_sprinting(),
		maxf(strength, 0.12),
		camera_rig.aim_height()
	)

func _on_boulder_jumped(_at: Vector3, total: int) -> void:
	journal.record(Journal.ROCKS)
	sounds.play(Sounds.Sound.CLEARED)
	hud.announce(Text.format("say_cleared", [total]), 1.8)

func _on_goal(_index: int, total: int) -> void:
	journal.record(Journal.GOALS)
	sounds.play(Sounds.Sound.GOAL)
	hud.set_score(total)
	hud.announce(Text.of("say_goal"), 2.0)

func _on_place() -> void:
	if build_mode.place():
		# A sapling is planted, everything else is built. The distinction
		# matters to the greeting: planting a tree is a different kind of
		# afternoon from stacking walls.
		journal.record(
			Journal.PLANTED if BuildKinds.is_plant(build_mode.selected) else Journal.BUILT
		)
		sounds.play(Sounds.Sound.PLACE)
		tasks.on_built(build_mode.selected)
		return
	sounds.play(Sounds.Sound.REFUSE)
	# A refused build is the moment a child most needs to be told why, and the
	# ghost's colour alone does not say it.
	hud.announce(Text.of("say_not_here"))

func _on_matured(_kind: StringName, _at: Vector3) -> void:
	sounds.play(Sounds.Sound.GROWN)
	hud.announce(Text.of("say_grown"))

func _on_groves_changed(centres: Array) -> void:
	birds.set_points(structures.attract_points())
	tasks.on_grove()
	if centres.is_empty():
		return
	if not _seen_first_grove:
		_seen_first_grove = true
		sounds.play(Sounds.Sound.CHIME)
		hud.announce(Text.of("say_grove"), 5.0)

func _notification(what: int) -> void:
	# Both of these arrive when the game is closing: the desktop window button,
	# and Android's back gesture.
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_write_save()

func _write_save() -> void:
	if player == null or world == null:
		return
	# What was done this session becomes what the greeting reports next time.
	journal.depart()
	var at := player.global_position
	SaveGame.write({
		"seed": world.world_seed,
		"language": String(Text.language()),
		"time_of_day": world.atmosphere.time_of_day,
		"player": {"x": at.x, "y": at.y, "z": at.z},
		"camera_yaw": camera_rig.yaw,
		"inventory": inventory.to_data(),
		"structures": structures.to_data(),
		"pickups_taken": world.pickups.to_data(),
		"football": world.football.to_data(),
		"boulders": world.boulders.to_data(),
		"tasks": tasks.to_data(),
		"wallet": wallet.to_data(),
		"vitals": vitals.to_data(),
		"animals": world.animals.to_data(),
		"journal": journal.to_data(),
		"felled": world.felled.to_data(),
	})

func _seed_from_command_line() -> int:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			return argument.substr(7).to_int()
	return 0
