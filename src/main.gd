extends Node3D

## Entry point, and the only place that knows about both the world and the game.
##
## The world does not know it is being played: it streams terrain and scatters
## sticks and asks nothing of anyone. The game — carrying, building, and the
## world's answer to it — is wired together here.


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
var profiles: Profiles
var session: Session
var visitors: Visitors
var ride_sync: RideSync
var voice: Voice
var ambience: Ambience
var animal_voices: AnimalVoices
var kick_preview: KickPreview
var today: Today
var lantern: Lantern

var _waiting_for_ground := false

## Being a guest in somebody else's valley. The guest's own valley is left on
## disk exactly as it was: while this is true nothing of the world is written,
## and the child's own player file says they are standing where they were when
## they set out. Coming home is then a reload, which reads all of it back.
var _visiting := false
## Asked to join, and not yet standing beside the host.
var _arriving := false
## Where the host was last said to be, while arriving.
var _host_at := Vector3.INF
var _valley_received := false
var _placed := false
var _home_at := Vector3.ZERO
var _home_undo: Array = []
var _going_home := false
## What to say once the valley has reloaded after a visit. A static, because the
## scene that said it is gone by then.
static var _come_home_note := ""
var _autosave := AUTOSAVE_SECONDS
var _seen_first_grove := false

## False in a `--seed=` run, which is a look at some other valley and must not
## write over the child's own save with it.
var _may_save := true

## True once the valley has appeared and the child's save has been laid over it.
## Until then the player, the structures and the bag hold only their blank
## starting state, and writing them down would replace a child's valley with an
## empty one.
var _world_ready := false

## The wall-clock second the game was put away at (APPLICATION_PAUSED), or 0.0
## when it is in the child's hands. The sleeping time is measured against it.
var _paused_at := 0.0

## Frames still to run with the clock stopped after a resume, and the speed to
## give it back at. See _hush_the_resume_frame.
var _resume_hush_frames := 0
var _resume_time_scale := 1.0
const RESUME_HUSH_FRAMES := 2

## The game's own frame runs after everything it reads.
##
## A rider in a coaster car is put where the car is, and that has to be where
## the car is *now*. Godot calls a parent's _physics_process before its
## children's, and the game is the root of the tree, so it was placing the
## rider from the car's position on the previous frame — at twenty-nine metres
## a second that is half a metre of lag, arriving as a judder in the seat
## every frame. A later priority puts this after the rides have moved.
const RUNS_AFTER_THE_WORLD := 100

func _ready() -> void:
	process_priority = RUNS_AFTER_THE_WORLD
	process_physics_priority = RUNS_AFTER_THE_WORLD
	InputActions.register()

	profiles = Profiles.new()
	profiles.load_index()
	# A player named on the command line, so a second child can be started on
	# the same machine without touching the interface.
	var wanted := _profile_from_command_line()
	if not wanted.is_empty() and profiles.players.has(wanted):
		profiles.choose_player(wanted)

	# There must always be somewhere to play. On a first run that means one copy
	# of the home valley, made before anyone has chosen a name — a child should
	# reach the game, not a form.
	# Also when the world remembered is not one this child may enter, which is
	# what a different child chosen on the command line finds.
	if profiles.current_world.is_empty() or not profiles.current_world_is_enterable():
		var existing := profiles.worlds_for(profiles.current_player)
		if existing.is_empty():
			profiles.choose_world(
				profiles.create_world(Profiles.HOME_MAP, profiles.current_player)
			)
		else:
			profiles.choose_world(existing[0])

	# A valley built before profiles existed becomes that first world, rather
	# than being quietly abandoned.
	SaveGame.migrate_legacy(profiles.current_save_path())

	var save := SaveGame.read(profiles.current_save_path())
	# The valley's own state, shared by everyone in this copy. Merged over the
	# player's file so that a save written before the split still loads: the old
	# single file holds both, and the world file simply wins where it exists.
	var shared := SaveGame.read(profiles.current_world_path())
	for key in shared:
		save[key] = shared[key]
	# The language is read before anything is built, so the first frame is
	# already in the right one rather than flashing English.
	Text.set_language(StringName(str(save.get("language", Text.EN))))
	# Talking is allowed unless a parent has said otherwise, and the answer is
	# remembered: a switch that forgets is a switch nobody trusts.
	_voice_allowed = SaveGame.as_bool(save.get("voice_allowed", true), true)
	_first_person = SaveGame.as_bool(save.get("first_person", false))
	_cafe_paid = SaveGame.as_bool(save.get("cafe_paid", false))
	# Clamped, not just checked for -1. The index off the network is validated
	# in session.gd and this one was not, so a hand-edited save — or the
	# palette ever losing a colour — indexed off the end of SHIRTS during
	# startup and the game never reached the valley at all.
	_shirt = SaveGame.as_int(save.get("shirt", -1), -1)
	if _shirt < -1 or _shirt >= Visitors.SHIRTS.size():
		_shirt = -1
	# Who this child is drawn as. A save from before there were characters has
	# no such key and is the plain figure in today's colours; one that has the
	# key but with rubbish in it is the same, by Character.clean.
	var kept: Variant = save.get("look", {})
	_look = Character.from_data(kept if kept is Dictionary else {})
	# Offered once, to a child with nothing saved yet. A child who has been
	# playing for weeks is not stopped in front of a panel they have no reason
	# to expect; they find it in the settings.
	_look_offered = SaveGame.as_bool(save.get("look_offered", save.has("player")), save.has("player"))

	# The world's map decides the seed, not the save: everyone in one copy of the
	# valley must get the same ground, even though their own progress is in
	# separate files.
	var seed_value := profiles.seed_of_world(profiles.current_world)
	var override := _seed_from_command_line()
	if override != 0:
		seed_value = override
		save = {}
		# `save = {}` only hides the child's valley from this run; the autosave
		# would still have written the seeded one over it.
		_may_save = false

	inventory = Inventory.new()
	if save.get("inventory") is Dictionary:
		inventory.from_data(save["inventory"])

	# Sound is created before the world, so the very first pickup is audible.
	# Before anything that makes a sound, so every player finds its bus.
	Mix.build()
	sounds = Sounds.new()
	add_child(sounds)

	tasks = Tasks.new()
	tasks.name = "Tasks"
	add_child(tasks)

	wallet = Wallet.new()
	if save.get("wallet") is Dictionary:
		wallet.from_data(save["wallet"])

	vitals = Vitals.new()
	# The bottle is a shop purchase, so a restored game that already bought one
	# still carries it.
	if wallet.has(ShopStock.BOTTLE):
		vitals.grant_bottle()
	if save.get("vitals") is Dictionary:
		vitals.from_data(save["vitals"])
		# The purse is the authority on the bottle: a vitals record without one
		# would leave a bought bottle that cannot be filled.
		if wallet.has(ShopStock.BOTTLE) and not vitals.has_bottle:
			vitals.grant_bottle()

	_free_meal_after = _play_seconds() + clampf(
		SaveGame.as_float(save.get("free_meal_in", 0.0)), 0.0, Venues.FREE_WAIT
	)
	_built_a_house = SaveGame.as_bool(save.get("built_house", false))

	lantern = Lantern.new()
	lantern.name = "Lantern"

	journal = Journal.new()
	if save.get("journal") is Dictionary:
		journal.from_data(save["journal"])
	journal.arrive(int(Time.get_unix_time_from_system()))

	today = Today.new()
	if save.get("today") is Dictionary:
		today.from_data(save["today"])
	today.begin(int(Time.get_unix_time_from_system()))
	today.completed.connect(_on_today_done)

	vitals.energy_changed.connect(func(_f: float) -> void: _refresh_vitals())
	vitals.water_changed.connect(func(_f: float) -> void: _refresh_vitals())
	vitals.exhausted.connect(func() -> void: hud.announce(Text.of("say_tired"), 3.0))
	vitals.revived.connect(func() -> void: hud.announce(Text.of("say_rested"), 2.0))

	world = World.new(seed_value)
	world.name = "World"
	world.ready_at_spawn.connect(_on_world_ready.bind(save))
	add_child(world)

	# What the frame actually costs, on whatever this is running on. Debug
	# builds only, which is what gets installed on a tablet for testing.
	if OS.is_debug_build():
		add_child(PerfLog.new())

func _on_world_ready(spawn: Vector3, save: Dictionary) -> void:
	# Every container is checked for its kind before it is handed over: a typed
	# parameter given the wrong kind is an engine error that ends this whole
	# function, so one damaged field kept the child out of the valley.
	if save.get("pickups_taken") is Array:
		world.pickups.from_data(save["pickups_taken"])
	if save.has("time_of_day"):
		world.atmosphere.set_time(SaveGame.as_float(save["time_of_day"], 8.0))
	world.pickups.collected.connect(_on_collected)

	structures = Structures.new(world.field)
	structures.name = "Structures"
	structures.matured.connect(_on_matured)
	structures.groves_changed.connect(_on_groves_changed)
	add_child(structures)
	# A tray set down in front of a chair the child built is turned to it, on
	# this phone as on the other child's (see Places.set_down).
	world.places.chair_yaw_finder = structures.plate_yaw_near
	# A machine got off is not left in a wall the child built (see Mounts.in_the_way).
	world.mounts.in_the_way.append(structures.blocks)
	# And an animal is not born in one (tiles loaded from here on).
	world.animals.built_blocks = structures.blocks
	if save.get("structures") is Array:
		structures.from_data(save["structures"])

	# After the structures exist and have been restored: the greeting ages
	# saplings by the time the game was closed, and cannot do that to structures
	# that have not been created yet. Called at the top of _ready before, where
	# it only failed on a returning visit — which is the one case it exists for.
	_greet_on_arrival(save)

	birds = Birds.new()
	birds.name = "Birds"
	add_child(birds)
	# The groves restored from the save spoke up before the birds existed; the
	# handler below now waits for them, and this gives them the groves.
	birds.set_points(structures.attract_points())

	session = Session.new()
	add_child(session)
	visitors = Visitors.new()
	visitors.name = "Visitors"
	visitors.seat_finder = _seat_at
	visitors.animal_finder = _animal_head_near
	add_child(visitors)

	# Its loops are synthesised on a worker and handed over a few frames in.
	ambience = Ambience.new(true)
	add_child(ambience)
	kick_preview = KickPreview.new()
	add_child(kick_preview)
	animal_voices = AnimalVoices.new()
	add_child(animal_voices)

	voice = Voice.new()
	voice.attach(session)
	add_child(voice)

	# The rides are the host's: a guest's phone follows them, and the other
	# child is drawn in the seat they said they are in.
	ride_sync = RideSync.new()
	ride_sync.local_position = func() -> Vector3:
		return player.global_position if player != null else Vector3.INF
	ride_sync.attach(session, world.park)
	add_child(ride_sync)
	visitors.ride_seat_of = ride_sync.seat_of_guest
	session.remote_turnstile.connect(func(_from: int) -> void: world.places.turn_for_another())

	session.opened.connect(_on_session_opened)
	session.joined.connect(_on_session_joined)

	session.guest_arrived.connect(_on_guest_arrived)
	session.guest_left.connect(_on_guest_left)
	session.peer_gone.connect(voice.forget)
	session.peer_gone.connect(_let_go_of_their_mounts)
	# Also for one who dropped before saying who they were: a position that
	# arrived ahead of their name is kept for them, and would hold a place in
	# the few there are for good.
	session.peer_gone.connect(visitors.remove)
	voice.someone_spoke.connect(visitors.speaking)
	session.guest_renamed.connect(_on_guest_renamed)
	session.guest_moved.connect(_on_guest_moved)
	session.guest_moving.connect(visitors.moving)
	session.failed.connect(_on_session_failed)
	session.closed.connect(visitors.clear)
	session.closed.connect(_on_session_closed)
	session.closed.connect(voice.forget_everyone)
	# The fallback shirt comes from this machine's network id, which is 1 until
	# the connection completes and 1 again once it closes.
	session.joined.connect(_refresh_own_shirt)
	session.closed.connect(_refresh_own_shirt)

	# Changes made on another machine are applied exactly as if a local child
	# had made them, which is why each goes through the same call the local
	# controls do.
	session.remote_built.connect(_on_remote_built)
	session.remote_removed.connect(_on_remote_removed)
	session.remote_felled.connect(_on_remote_felled)
	session.remote_meal.connect(_on_remote_meal)
	session.remote_dam_stick.connect(_on_remote_dam_stick)
	session.remote_time_of_day.connect(world.atmosphere.set_time)
	session.remote_valley.connect(_on_remote_valley)
	session.remote_shared.connect(_on_remote_shared)
	session.remote_picked.connect(_on_remote_picked)
	session.remote_parked.connect(_on_remote_parked)
	session.remote_animals.connect(world.animals.tell)
	# What this child picks up is gone for the other as well, and a mount got off
	# is left where the other phone is told it stands.
	# A guest says what it took only once it is in the host's valley: before
	# that the ids are those of its own valley, and the host would mark them gone
	# in its own.
	world.pickups.taken_here.connect(func(id: String) -> void:
		if _the_hosts_valley_is_here():
			session.report_picked(id))
	# The host is the arbiter of a stick two children reached together.
	session.pickup_is_gone = func(id: String) -> bool: return world.pickups.taken.has(id)
	session.pick_refused.connect(_on_pick_refused)
	world.mounts.dismounted.connect(_on_dismounted)

	# In somebody else's valley the football is theirs; this phone only draws it.
	world.football.attach(session)
	world.football.goal_scored.connect(_on_goal)
	world.football.match_won.connect(_on_match_won)
	world.football.guest_kicked.connect(_on_guest_kicked)
	world.football.guest_began_new_game.connect(_on_guest_began_new_game)
	world.football.scores_changed.connect(_on_scores_changed)
	world.places.basket.connect(func(total: int) -> void:
		sounds.play(Sounds.Sound.GOAL)
		hud.announce(Text.of("say_basket"), 1.6)
		journal.record(Journal.GOALS))
	world.boulders.jumped.connect(_on_boulder_jumped)
	if save.get("boulders") is Dictionary:
		world.boulders.from_data(save["boulders"])
	if save.get("tasks") is Dictionary:
		tasks.from_data(save["tasks"])
	if save.get("animals") is Array:
		world.animals.from_data(save["animals"])
	if save.get("felled") is Array:
		world.felled.from_data(save["felled"])
	if save.get("mounts") is Dictionary:
		world.mounts.from_data(save["mounts"])
	if save.get("hearths") is Array:
		world.hearths.from_data(save["hearths"])
	if save.get("dams") is Dictionary:
		world.dams.from_data(save["dams"])
		# The height field has to know before anything is generated against it.
		world.field.dams_built = world.dams.built.duplicate()
		world.dams.restore()

	# The fires need to know which of the built pieces are campfires.
	_refresh_fires()
	world.hearths.lit.connect(func(_at: Vector3) -> void:
		sounds.play(Sounds.Sound.GROWN, 0.8))
	world.hearths.went_out.connect(func(_at: Vector3) -> void:
		hud.announce(Text.of("say_fire_out"), 3.0))

	world.dams.stick_delivered.connect(func(site: float, carried: int, needed: int) -> void:
		sounds.play_at(Sounds.Sound.PLACE, _metres_to_dam(site), 0.8)
		hud.announce(Text.format("say_dam_stick", [needed - carried]), 2.0))
	world.dams.dam_finished.connect(func(site: float) -> void:
		sounds.play_at(Sounds.Sound.GOAL, _metres_to_dam(site))
		hud.announce(Text.of("say_dam_done"), 5.0))
	# The fairground's two big drops and swings are heard from where they are,
	# like the dam: a ride across the valley is not in the child's ear.
	world.park.drop_tower.dropped.connect(func() -> void:
		sounds.play_at(
			Sounds.Sound.DROP, _metres_to_spot(world.park.drop_tower.global_position)
		))
	world.park.pirate_ship.passed_the_bottom.connect(func(strength: float) -> void:
		sounds.play_at(
			Sounds.Sound.SWING,
			_metres_to_spot(world.park.pirate_ship.global_position),
			1.0, linear_to_db(strength)
		))
	# A bicycle already bought must be standing in the world on reload.
	lantern.owned = wallet.has(ShopStock.LANTERN)
	# Every machine a child owns must be standing somewhere on reload. Where
	# they were left is in the world file; any that are missing — a machine
	# bought on a day the world was not saved — are put back at the shop.
	for machine: Array in [
		[ShopStock.BICYCLE, MountKinds.BICYCLE, Places.BICYCLE_STANDS_AT],
		[ShopStock.MOTORCYCLE, MountKinds.MOTORCYCLE, Places.MOTORCYCLE_STANDS_AT],
		[ShopStock.QUAD, MountKinds.QUAD, Places.QUAD_STANDS_AT],
	]:
		var wanted := wallet.count_of(machine[0])
		while world.mounts.count_of_kind(machine[1]) < wanted:
			world.mounts.place(
				world.mounts.free_id(machine[1]),
				_outside_the_shop(Places.machine_stand(
					machine[2], _free_row(machine[2])
				))
			)

	world.archery.hit_target.connect(_on_arrow_hit)
	# A miss is not a refusal. The arrow stands in the ground and says where it
	# went; the line says what to try. The sound for "no" said a third thing —
	# that a child had done something wrong — and at seven-tenths pitch it was
	# too low for the phone to play anyway.
	world.archery.missed.connect(func() -> void:
		sounds.play(Sounds.Sound.LAND, 0.9)
		hud.announce(Text.of("say_missed"), 1.8))

	world.animals.cared_for.connect(func(_kind: StringName, _coins: int, _at: Vector3) -> void: pass)
	world.animals.befriended.connect(func(kind: StringName) -> void:
		hud.announce(Text.format("say_friend", [AnimalKinds.label(kind)]), 4.0))
	wallet.changed.connect(func(total: int) -> void: hud.set_coins(total))
	wallet.changed.connect(func(_total: int) -> void: hud.set_owned(wallet.owned))

	# The reward line is an announcement; the instruction is a standing label.
	# Keeping them separate is what stops the screen filling with old advice.
	tasks.completed.connect(func(reward: String) -> void:
		sounds.play(Sounds.Sound.CHIME)
		hud.announce(reward, 4.5))
	tasks.changed.connect(func(_instruction: String) -> void: hud.set_task(_task_line()))
	today.progressed.connect(func() -> void: hud.set_task(_task_line()))
	if save.get("football") is Dictionary:
		world.football.from_data(save["football"])

	player = Player.new()
	player.name = "Player"
	var start := spawn
	if save.has("player"):
		var at: Dictionary = save["player"] if save["player"] is Dictionary else {}
		start = Vector3(
			SaveGame.as_float(at.get("x", spawn.x), spawn.x),
			SaveGame.as_float(at.get("y", spawn.y), spawn.y),
			SaveGame.as_float(at.get("z", spawn.z), spawn.z)
		)
	# Never below the ground as it is *now*. A saved height is only as good as
	# the terrain it was saved against, and the terrain can change between
	# sessions: the day the playground stopped being a thirty-metre pit, a child
	# saved at the bottom of it would have loaded thirty metres inside a hill.
	#
	# And not wherever the save says, believed blindly: a spot off the world, in
	# the water, inside something the other child built while visiting, or
	# inside a ride is given up for the nearest open ground, and failing that
	# the camp. The signpost's clearance is applied in there too, since it was
	# put where a child happened to be standing and a solid thing that appears
	# around somebody traps them.
	start = RespawnSpot.choose(
		world.field, structures, world.places, world.park, world.signpost, start, spawn
	)
	_last_on_ground = start
	player.position = start + Vector3.UP * SPAWN_CLEARANCE
	# A game saved mid-ride has its machine at the child's feet.
	world.mounts.make_room_at(start)
	# Terrain arrives a few chunks per frame, so for the first instants there is
	# nothing under the player's feet. Physics stays off until the ground they
	# are standing on exists, or the game opens with a fall.
	player.set_physics_process(false)
	_waiting_for_ground = true
	# The footballs and this child meet by a push the game works out, not by the
	# capsule and the ball colliding; see FootballGround.let_pass.
	world.football.let_pass(player)
	world.places.let_pass(player)
	player.moved.connect(world.follow)
	player.jumped.connect(func() -> void: sounds.play(Sounds.Sound.JUMP))
	player.landed.connect(func(speed: float) -> void:
		# Landing on the trampoline's mat throws some of the fall back up. Not
		# all of it, so a child who simply steps on does not start bouncing
		# for ever — jumping from the mat is what sends them high.
		if world.park.on_trampoline(player.global_position):
			# The fairground's trampoline is twice the size and gives back
			# more: it is the one a ten-year-old goes to the park for.
			player.velocity.y = maxf(
				speed * Park.TRAMPOLINE_REBOUND, Park.TRAMPOLINE_JUMP
			)
			sounds.play(Sounds.Sound.JUMP, 1.2)
			return
		elif world.places.on_trampoline(player.global_position):
			player.velocity.y = clampf(speed * Places.TRAMPOLINE_REBOUND, 0.0, 9.0)
			sounds.play(Sounds.Sound.JUMP, 0.8)
			return
		sounds.play(Sounds.Sound.LAND, clampf(1.2 - speed * 0.02, 0.75, 1.2)))
	add_child(player)

	camera_rig = CameraRig.new(player)
	camera_rig.name = "CameraRig"
	# The view a child left it in, applied as soon as there is a camera to
	# apply it to.
	camera_rig.set_first_person(_first_person)
	if save.has("camera_yaw"):
		camera_rig.yaw = SaveGame.as_float(save["camera_yaw"], camera_rig.yaw)
	player.add_child(camera_rig)
	# Carried by the child, so the light moves with them.
	player.hold(lantern)

	build_mode = BuildMode.new(world.field, structures, inventory)
	build_mode.name = "BuildMode"
	add_child(build_mode)
	# A house is not built where a tree stands, and the forest is the game's
	# to know about.
	build_mode.set_tree_finder(func(at: Vector3, reach: float) -> Array[Vector3]:
		return world.vegetation.trees_near(at, reach))
	# Nor on top of anyone: the child's own feet, an animal, a parked horse.
	build_mode.set_body_finder(_bodies_near)
	build_mode.set_mount_finder(func(at: Vector3, margin: float) -> bool:
		return world.mounts.blocks(at.x, at.z, margin))
	# The undo list is this child's, kept in their own save, and found again
	# among the structures that were restored above.
	build_mode.restore_history(save.get("undo", []))
	# A cafe or a shop already standing in a loaded valley is not news.
	_known_cafe = structures.has_venue(&"cafe")
	_known_shop = structures.has_venue(&"shop")

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.set_score(world.football.blue, world.football.red)
	Wiring.connect_hud(hud, build_mode, camera_rig, inventory, world.field, player, structures, _handlers())

	# The interface exists from here and not one line earlier. These sat above,
	# where `hud` was still null, so the game reached the tablet with its talk
	# button and its entire play-together panel connected to nothing at all.
	hud.set_voice_allowed(_voice_allowed)
	hud.set_first_person(_first_person)
	hud.set_cafe_paid(_cafe_paid)
	hud.restore_cafe_choices(_cafe_paid, StringName(str(save.get("dish", Dishes.USUAL))))
	_cooled_for = clampf(SaveGame.as_float(save.get("cooled_for", 0.0)), 0.0, Dishes.COOL_SECONDS)
	# Turning up is the whole of a visiting day, and nothing was ever telling
	# today that anybody had: one day in six asks only that a child opens the
	# game, and on that day the task sat there uncompletable and its eight
	# coins could not be earned. Here rather than beside today.begin(), for the
	# reason written just above — finishing a task announces itself and rewrites
	# the task line, and up there the HUD it would announce into is still null.
	# `record()` refuses a day already finished, so this cannot pay twice.
	today.arrive()
	_connect_the_rest_of_the_hud()
	_show_the_state()

	world.follow(start)
	# Everything the save holds is back in place: from here a save is the child's
	# valley and not a blank one.
	_world_ready = true
	# Home from a visit: said once the world has appeared, and why it did.
	if not _come_home_note.is_empty():
		var note := Text.of(_come_home_note)
		_come_home_note = ""
		get_tree().create_timer(2.4).timeout.connect(func() -> void:
			if is_instance_valid(hud):
				hud.announce(note, 4.5))
	print("Aava seed %d, spawn %v, player '%s' in world '%s', save at %s" % [
		world.world_seed, start,
		profiles.current_player if not profiles.current_player.is_empty() else "(nobody yet)",
		profiles.current_world,
		SaveGame.absolute_path(profiles.current_save_path())
	])

## The fairground's moving floors carry whoever is standing on them.
##
## Godot does this itself for a platform that slides, and not for one that
## turns or that is moved by hand — a child on the carousel was left standing
## while it went round under them, and one in a gondola was dropped back onto
## its floor every frame as it rose. So each ride says how far it has taken its
## passengers and the child is moved by that much, here, in step with the
## physics that moved the ride.
## Which ride the child is aboard, and whether they got on it without paying.
var _aboard: StringName = &""
var _riding_without_a_ticket := false
## Whether the ride at the coaster's platform has been paid for, and whether
## the child has been told they need a ticket for it.
var _coaster_paid := false
## And whether the child currently in a car paid to be there.
var _coaster_rider_paid := false
## Whether the wheel has already offered a ride at its button, whether it has
## said that a gondola is waiting, and whether the child in a gondola paid.
var _wheel_told := false
var _wheel_here_told := false
var _wheel_rider_paid := false
## And whether they actually got into the gondola they paid for.
var _wheel_boarded := false
## Which ride the question on screen is about.
var _asked_ride: StringName = &""
## The carousel: whether the child has paid and is waiting to be put on a
## horse, and whether they are now in a saddle. A ticket is taken once, at the
## answer, and the ride is the one it bought.
var _carousel_paid := false
var _carousel_seated := false
## The tower or the ship, when its ticket was taken while it stood waiting to
## go: the ride has not begun, so a child who steps off gets the ticket back.
var _ride_waiting_paid: StringName = &""
## The tower or the ship, once it has gone with a child aboard on that ticket.
## A ticket buys one go: a child who stays in the seat while it comes back to
## rest is on the next one without having paid for it, so this is how the game
## knows to ask again.
var _ride_gone_paid: StringName = &""
## Whether the wheel has carried the child once round on the ticket they paid
## for. At the boards again, with the bar up, that ticket is spent.
var _wheel_went_round := false

## Offer a ride at a ride's own button: use a ticket if there is one, buy one
## with coins if there is not, and say so plainly if neither.
##
## One function for both buttons, because a child who has learnt what the
## coaster's does knows what the wheel's does. Returns false when there was
## nothing to offer — no ticket and not enough coins — so the caller can stop
## asking until they walk away and come back.
func _offer_a_ride(which: StringName) -> bool:
	if _asked != &"":
		return true
	# Paid for, or already in the saddle: that ride has its ticket, and asking
	# again would take a second one for it.
	if which == &"carousel" and (_carousel_paid or _carousel_seated):
		return true
	# A coaster ticket stays good until the child leaves the park, but the
	# booking it bought does not: the train pulls up, stands its ten seconds and
	# clears it. A child who missed it and came back to the button was asked
	# for, and charged, a second ticket for a ride already paid for. The one
	# they hold is simply put back on the train's list.
	if which == &"coaster" and _coaster_paid:
		world.park.coaster.book()
		hud.announce(Text.of("say_coaster_booked"), 2.4)
		return true
	if wallet.tickets > 0:
		_asked = &"ride"
		_asked_ride = which
		hud.ask(Text.of("ask_use_ticket"))
		return true
	if wallet.can_afford(Park.RIDE_PRICE):
		_asked = &"ride"
		_asked_ride = which
		hud.ask(Text.format("ask_buy_ride", [Park.RIDE_PRICE]))
		return true
	sounds.play(Sounds.Sound.REFUSE)
	hud.announce(Text.format("say_no_coins", [Park.RIDE_PRICE]), 2.4)
	return false
var _coaster_told := false
## What the game has just asked about: a ticket at the kiosk, or a ride.
var _asked: StringName = &""
## Whether a parent has left talking switched on.
var _voice_allowed := true

## Whether this child's own café asks a coin for a meal. A setting like the
## voice switch, so it is kept here, saved, and handed to each new interface:
## it lived only in the button, and a change of language or a restart put the
## café back to free.
var _cafe_paid := false

## The last place the child stood on dry ground, off every ride and out of every
## boat. A save made while they are up on the wheel, in a gondola of the drop
## tower or out on the pond is written here instead, so that the phone coming
## back never puts them in mid-air or in the water. See RespawnSpot.
var _last_on_ground := Vector3.ZERO

## Whether the body is somewhere that must not be saved: aboard a ride, in a
## boat, or in the water.
func _off_the_ground() -> bool:
	var here := player.global_position
	return (
		_aboard != &"" or world.park.ride_under(here) != &""
		or (player.riding != &"" and MountKinds.kind_of(player.riding) == MountKinds.BOAT)
		or RespawnSpot.is_wet(world.field, world.places, here)
	)

func _physics_process(delta: float) -> void:
	if player == null or _waiting_for_ground or world.park == null:
		return
	if player.is_on_floor() and not _off_the_ground():
		_last_on_ground = player.global_position
	_lift_out_of_a_pocket(delta)
	# Which ride a child is aboard, and whether it is one that charges. A
	# ticket is taken when they get on, not while they stay on: the carousel
	# turns for a minute and a ride is a ride.
	var aboard := world.park.ride_under(player.global_position)
	# A child strapped in is aboard whatever the boxes say: the ride has just
	# moved and the child was put where its seat was a frame ago.
	var strapped_to := _strapped_to()
	if strapped_to != &"":
		aboard = strapped_to

	# The coaster is booked at the button on the platform, not in the car.
	#
	# The train used to stop every lap whether anybody wanted it or not, and
	# the ticket was taken from whoever walked up to a standing car — so the
	# ride happened *at* a child rather than being asked for. Now it runs all
	# day, and the button is where both things happen: the ticket is taken and
	# the next train is booked to pull up.
	var coaster := world.park.coaster
	# Nothing is asked by walking up to a button any more: the ticket control
	# on screen is what buys a ride, at both platforms, exactly as it does at
	# the kiosk and at the pool gate.
	#
	# Walking away from either platform withdraws the question, which is how
	# every other question in this game is said no to. It has to be *either*
	# platform: this used to ask only about the coaster's, so a ride bought at
	# the wheel had its own question cancelled on the same frame it was asked.
	var at_a_button := (
		coaster.at_the_button(player.global_position)
		or world.park.wheel.at_the_button(player.global_position)
	)
	# Nor while a child stands on a ride that asks its question as they step
	# on — the tower, the ship, the carousel. Those were withdrawn here on the
	# very next frame after being asked, so the question flashed up for a
	# tenth of a second and was gone before anybody could answer it.
	var asked_on_board := aboard != &"" and Park.charges_for(aboard)
	if not at_a_button and aboard != &"coaster" and aboard != &"wheel" and not asked_on_board:
		_coaster_told = false
		if _asked == &"ride":
			_asked = &""
			hud.stop_asking()
	# And the ticket kiosk's question goes when the child walks away from the
	# kiosk, like every other question here. Only the rides' questions were
	# ever withdrawn, so "buy a ticket?" followed a child across the valley
	# until it was answered.
	if _asked == &"buy" and not world.park.at_the_booth(player.global_position):
		_asked = &""
		hud.stop_asking()
	# The ticket stays good until it is used or the child walks away from the
	# ride: paying and then missing the train should not cost a coin.
	#
	# Walking away with it still unused hands the ticket back: it was ten coins,
	# and "paying and then missing the train should not cost a coin" was true of
	# the booking and not of the purse.
	if not ParkSpec.inside(player.global_position.x, player.global_position.z):
		if _coaster_paid:
			wallet.return_ticket()
		_coaster_paid = false
	# The wheel's payment is the same: good while a gondola is coming or
	# standing at the boards, and gone once the child leaves the park or the
	# booking runs out. Left set, a child who paid and never got in rode the
	# next time for nothing — and, never boarded, it is given back as a ticket.
	if aboard == &"wheel" and _wheel_rider_paid:
		_wheel_boarded = true
		if world.park.wheel.ridden() > 0.5:
			_wheel_went_round = true
		# Set down at the boards after its turn and still sitting there: the
		# ticket bought that turn, and the wheel would otherwise carry them
		# round again, and again, for nothing.
		elif _wheel_went_round and world.park.wheel.waiting() > 0.0:
			_wheel_went_round = false
			_wheel_rider_paid = false
			_riding_without_a_ticket = true
			# Asked again, as the tower and the ship ask: the wheel now stands
			# at the boards while they are unpaid (see keep_at_boards below).
			_offer_a_ride(&"wheel")
	if _wheel_rider_paid and aboard != &"wheel" and (
		not ParkSpec.inside(player.global_position.x, player.global_position.z)
		or (not world.park.wheel.called() and world.park.wheel.waiting() <= 0.0)
	):
		_wheel_rider_paid = false
		if not _wheel_boarded:
			wallet.return_ticket()
	coaster.clear_to_board(_coaster_paid)
	# And the bars come down the moment somebody sits in a car, which is what
	# being strapped in means — they are certainly down by the time it leaves.
	coaster.rider_aboard(aboard == &"coaster")
	if aboard == &"coaster":
		# Whether *this* rider paid, which lasts as long as they are in the
		# car. Being strapped in cannot be read off the shoulder bars: they
		# take a second to come down, and for that second a child who had paid
		# counted as unrestrained and was put off the ride they had just
		# bought.
		if _coaster_paid:
			_coaster_rider_paid = true
		_coaster_paid = false
	elif not coaster.boarding() or aboard == &"":
		_coaster_rider_paid = false

	# The tower and the ship run on their own clocks. Once one has gone, the
	# ticket has bought its ride; until then it is only a place in the queue.
	if _ride_waiting_paid == &"drop_tower" and not world.park.drop_tower.at_rest():
		_ride_gone_paid = _ride_waiting_paid
		_ride_waiting_paid = &""
	elif _ride_waiting_paid == &"pirate_ship" and not world.park.pirate_ship.at_rest():
		_ride_gone_paid = _ride_waiting_paid
		_ride_waiting_paid = &""
	# Back at rest with the child still in the seat: that go is over. `aboard`
	# does not change, so the step-on question below would never be asked
	# again, and the next climb or swing was carried for nothing.
	if _ride_gone_paid != &"":
		var back := (
			world.park.drop_tower.at_rest() if _ride_gone_paid == &"drop_tower"
			else world.park.pirate_ship.at_rest()
		)
		if aboard != _ride_gone_paid:
			_ride_gone_paid = &""
		elif back:
			_ride_gone_paid = &""
			_riding_without_a_ticket = true
			_offer_a_ride(aboard)
	if aboard != _aboard:
		# Paid on the tower or the ship and stepped off before it went: the
		# ticket comes back, as the carousel's does, or the child's next step
		# aboard would be asked for a second one for the same departure.
		if _ride_waiting_paid != &"" and aboard != _ride_waiting_paid:
			wallet.return_ticket()
			_ride_waiting_paid = &""
		# Stepping out of a gondola spends the ride that was paid for at the
		# button: the next one is a new ride and a new ticket.
		if _aboard == &"wheel" and aboard != &"wheel":
			_wheel_rider_paid = false
		_aboard = aboard
		# Getting on is heard, and so is getting off: a soft knock either way, so
		# a ride starting is something that happened and not only a picture
		# beginning to move.
		sounds.play(Sounds.Sound.PLACE if aboard != &"" else Sounds.Sound.LAND, 1.2, -6.0)
		# The coaster and the wheel are both paid for at their own buttons, so
		# stepping into one of those is not a second sale.
		if aboard == &"wheel":
			_riding_without_a_ticket = not _wheel_rider_paid
			# Stepped into a gondola with nothing paid for it: asked, rather
			# than carried round or left to find out.
			if not _wheel_rider_paid:
				_offer_a_ride(&"wheel")
		elif aboard != &"" and aboard != &"coaster" and Park.charges_for(aboard):
			# Nothing carries them until they say yes. Asked the same way the
			# buttons ask — a ticket if there is one, coins if not — and about
			# this ride, so the answer is not filed under whichever ride was
			# asked about last.
			_riding_without_a_ticket = true
			# Stepping straight from one paid ride onto another: the first
			# one's question is withdrawn, or _offer_a_ride would leave it up
			# and a yes would be filed under the ride just left.
			if _asked == &"ride" and _asked_ride != aboard:
				_asked = &""
				hud.stop_asking()
			_offer_a_ride(aboard)
		else:
			_riding_without_a_ticket = false
			if _asked == &"ride":
				_asked = &""
				hud.stop_asking()

	# Off the mount for a ride that has taken their ticket and carries them: the
	# carousel and the coaster both do this, and the wheel, the tower and the
	# ship did not, so a child on a horse was lifted ninety metres with the
	# animal still under them and drawn in the saddle of a gondola's seat.
	if player.riding != &"" and not _riding_without_a_ticket and (
		aboard == &"wheel" or aboard == &"drop_tower" or aboard == &"pirate_ship"
	):
		_on_ride()

	# Strapped in, while the bars are down: the ride puts the rider where the
	# seat is rather than nudging them along by how far the car moved. A loop
	# turns the car over as well as carrying it forward, and no amount of
	# nudging keeps a child in a seat that is upside down.
	# The big wheel's button works exactly as the coaster's does: it is where
	# the ride is paid for and where it is asked for. It used to be free, and
	# the ticket was taken when a child stepped into a gondola — which meant
	# that standing at the wheel there was nothing offering to sell you a
	# ride and nothing saying you needed one.
	var wheel := world.park.wheel
	# The wheel is told who is riding, so it can bring them back down: a ride
	# is one turn, and then it stands at the boards with the bar up.
	wheel.set_rider(wheel.gondola_under(player.global_position))
	# Anyone aboard who has not paid keeps the wheel, the tower and the ship
	# standing where they are, bars up. These bodies are moved by hand but are
	# solid, and the engine lifts a child standing on one whatever the game
	# does about carrying them, so saying "no" and staying on was a free ride.
	# Standing still is also the way off, so nobody is trapped by it.
	wheel.keep_at_boards(
		aboard == &"wheel" and not _wheel_rider_paid and wheel.waiting() > 0.0
	)
	# Nor does anybody who has paid but is not sitting on a seat go up or swing
	# with nothing to hold them: the bars come down across a seat, and a child
	# standing on the deck of the ring or in the boat's gangway has none.
	world.park.drop_tower.hold_at_ground(
		aboard == &"drop_tower" and (
			_riding_without_a_ticket
			or is_nan(world.park.drop_tower.seat_near(player.global_position).origin.x)
		)
	)
	world.park.pirate_ship.hold_still(
		aboard == &"pirate_ship" and (
			_riding_without_a_ticket
			or is_nan(world.park.pirate_ship.seat_near(player.global_position).origin.x)
		)
	)
	if wheel.waiting() > 0.0 and not _wheel_here_told:
		_wheel_here_told = true
		hud.announce(
			Text.of("say_wheel_done" if aboard == &"wheel" else "say_wheel_here"), 2.2
		)
	elif wheel.waiting() <= 0.0:
		_wheel_here_told = false

	# The carousel seats whoever has paid on the nearest animal and turns for
	# its minute; the child is held in the saddle, as in a coaster's car, and
	# put down beside it when it has stopped.
	var carousel := world.park.carousel
	if _carousel_paid and aboard != &"carousel":
		# Paid and walked off before it took them: the ticket comes back.
		_carousel_paid = false
		wallet.return_ticket()
	elif _carousel_paid and carousel.free_to_board():
		if player.riding != &"":
			_on_ride()
		if carousel.board(player.global_position):
			_carousel_paid = false
			_carousel_seated = true
	var on_horse := false
	if _carousel_seated:
		if carousel.ride_is_over() or not carousel.has_rider():
			player.global_position = carousel.step_off()
			player.velocity = Vector3.ZERO
			_carousel_seated = false
			sounds.play(Sounds.Sound.CHIME, 0.9)
		else:
			on_horse = true
			var saddle := carousel.rider_seat()
			player.carried_to = saddle.origin
			player.carried_facing = saddle.basis
	var seat := coaster.seat_under(player.global_position)
	# Held from the moment it pulls out, not from the moment the bars finish
	# coming down, and never while it is standing at the platform — a child at
	# the boards may get in and out as they please.
	var strapped := (
		aboard == &"coaster" and _coaster_rider_paid and not coaster.boarding()
		and (coaster.strapped() or not is_nan(seat.origin.x))
	)
	if strapped:
		# The car is remembered from here on (see RollerCoaster.strap).
		if not coaster.strapped():
			coaster.strap(player.global_position)
		seat = coaster.strap_place()
	else:
		coaster.unstrap()
	if strapped:
		# Off the mount first. A bar comes down over a child, not over a child
		# and a horse: left riding, the animal was carried round the track
		# under them and the body was still drawn in the saddle.
		if player.riding != &"":
			_on_ride()
		player.carried_to = seat.origin
		player.carried_facing = seat.basis
	# The tower, the ship and the wheel hold their rider the same way, once their
	# bars are down: placed in the seat, with no physics of their own.
	var fastened := _fasten_to_the_ride(aboard)
	player.strapped_in = strapped or on_horse or fastened
	# And the camera stops being shoved into the seat back by the car it is
	# riding in — or into the carousel's drum and canopy.
	camera_rig.set_riding(strapped or on_horse or fastened)
	if strapped:
		# Which way the car is pointed: its own forward, turned into the yaw
		# the camera is steered by.
		var ahead := seat.basis * Vector3.FORWARD
		camera_rig.look_along(atan2(-ahead.x, -ahead.z), delta)

	# Nobody rides it unrestrained. The bars come down for a ticket and for
	# nothing else, so anybody still in a car once the train has left the
	# platform is somebody who did not pay — and they are put back on the
	# boards rather than carried round upside down with nothing holding them.
	if coaster.must_get_off(player.global_position, strapped):
		player.strapped_in = false
		player.velocity = Vector3.ZERO
		player.global_position = coaster.platform_spot()
		sounds.play(Sounds.Sound.REFUSE)
		hud.announce(Text.of("say_park_put_off"), 2.4)
		return

	if strapped or on_horse or fastened:
		# Put there now, not on the player's own next tick. The player is a
		# child of this node with the default priority, so it moves before this
		# runs: left to itself it sits where the seat was a frame ago, which is
		# a car's length behind the coaster at thirty frames a second and a
		# quarter of a metre off the tower's seat on its way down.
		player.global_transform = Transform3D(player.carried_facing, player.carried_to)
		return

	var carried := world.park.carry(player.global_position, delta)
	# A ride nobody has paid for does not carry them. It still turns: what a
	# child sees is the roundabout going round under their feet while they
	# stand still on it, which is exactly what happens when you have not paid.
	#
	# The carousel is the exception: it only goes round for somebody who has
	# paid and is in a saddle, so a child on its floor while it turns is one
	# who is standing still on a moving floor, and is carried with it rather
	# than left to be swept off.
	if carried != Vector3.ZERO and (
		not _riding_without_a_ticket or world.park.carrier() == &"carousel"
	):
		player.global_position += carried

## How far from its seat a strapped child may be found before they are taken to
## have been moved by something else (a visit, a rescue) and are let go of. A
## frame at fifteen a second on the coaster's fastest stretch is two and a bit.
const STRAP_REACH := 6.0

## Which ride has a child strapped to it right now, or nothing.
func _strapped_to() -> StringName:
	var park := world.park
	for held: Array in [
		[&"coaster", park.coaster], [&"drop_tower", park.drop_tower],
		[&"pirate_ship", park.pirate_ship], [&"wheel", park.wheel],
	]:
		var ride: Node = held[1]
		if not bool(ride.call("strapped")):
			continue
		var place: Transform3D = ride.call("strap_place")
		if place.origin.distance_to(player.global_position) < STRAP_REACH:
			return held[0]
		# Somewhere else altogether: put there by something other than the ride.
		ride.call("unstrap")
	return &""

## Let go of every strap: the child has been taken off the rides.
func _unstrap_every_ride() -> void:
	var park := world.park
	for ride: Node in [park.coaster, park.drop_tower, park.pirate_ship, park.wheel]:
		ride.call("unstrap")

## Hold a paid child to the seat of the tower, the ship or the wheel while its
## bars are down: put where the seat is, every frame, as the coaster's rider is.
##
## These three used to move a rider only by how far the ride had moved, and
## leave the rest to the engine. At the drop's thirty metres a second that left
## a child up to a metre above or below the cushion; on the ship's tilt it let
## them slide over the bar; and a child holding the stick forward and jumping
## walked off a gondola at the top of the wheel, or off the ring at a hundred and
## fifty metres. Returns whether the child is held now.
func _fasten_to_the_ride(aboard: StringName) -> bool:
	var park := world.park
	var held: Node = null
	match aboard:
		&"drop_tower":
			held = park.drop_tower
		&"pirate_ship":
			held = park.pirate_ship
		&"wheel":
			held = park.wheel
	# One rider, one strap: whichever ride the child is not in lets go of them.
	for ride: Node in [park.drop_tower, park.pirate_ship, park.wheel]:
		if ride != held:
			ride.call("unstrap")
	if held == null:
		return false
	var restrained: bool = (
		held.call("restrained", park.wheel.gondola_under(player.global_position))
		if held == park.wheel else held.call("restrained")
	)
	# The bars up: free to step off, which is the way off at rest. A child who
	# has not paid is never newly fastened, but one already strapped in stays so
	# until the bars are up: the ride's end asks for the next ticket the moment
	# it touches down, while the bars are still across the lap.
	var already := bool(held.call("strapped"))
	if not restrained or (_riding_without_a_ticket and not already):
		held.call("unstrap")
		return false
	if not already and not bool(held.call("strap", player.global_position)):
		return false
	var place: Transform3D = held.call("strap_place")
	if player.riding != &"":
		_on_ride()
	player.carried_to = place.origin
	player.carried_facing = place.basis
	return true

## Whether somebody standing here is in the seat of a ride, and which: the
## pose (see SeatPose) and where the seat is. The same question is asked for the
## child's own body and for the other child's, from where each stands, so that
## nothing about the ride has to be sent. Empty on foot and on the floor of a
## ride.
func _seat_at(at: Vector3) -> Dictionary:
	if world == null or world.park == null:
		return {}
	var seat := world.park.seat_under(at)
	if seat.is_empty() and world.places != null:
		var swing := world.places.swing_seat_near(at)
		if not is_nan(swing.origin.x):
			return {"pose": &"swing", "place": swing}
	# At a table, sat in the chair they are kept in while they eat: in the
	# valley's café, or in a chair of the child's own (whose plate, if one is on
	# the table in front of it, is what the bites are timed by).
	if seat.is_empty() and world.places != null:
		seat = world.places.cafe_seat_near(at)
	if seat.is_empty() and structures != null:
		seat = structures.seat_under(at, Places.DINING_SINK, Places.DINING_ACROSS, Places.DINING_ABOUT)
		if not seat.is_empty() and world.places != null:
			# The plate in front of this chair, and no other: the whole of the
			# café's reach (1 m) timed a second child's bites by the first
			# child's plate on the same table.
			seat["meal_age"] = world.places.meal_age_near(seat["plate"], Places.PLATE_REACH)
	return seat

func _process(delta: float) -> void:
	_end_resume_hush()
	if player == null:
		return

	if _waiting_for_ground:
		# The engine is let go of here as well as in the ordinary path below,
		# which this early return skips: a guest put down beside the host
		# while riding was got off quietly, and the machine they had left
		# went on droning at its last pitch until the ground under them
		# had arrived.
		ambience.engine(-1.0)
		ambience.cycling(-1.0, false)
		if world.terrain.has_ground_at(player.global_position):
			player.set_physics_process(true)
			_waiting_for_ground = false
		return

	# The ground under the child is never left to the stream alone: if their own
	# chunk has no collision yet, it is built on the spot. See ensure_ground_at.
	world.terrain.ensure_ground_at(player.global_position)

	# Which seat the child is in, if they are in one, so that their body sits.
	var seated := _seat_at(player.global_position)
	player.seat_pose = seated.get("pose", &"")
	player.seat_place = seated.get("place", Transform3D())
	player.meal_age = seated.get("meal_age", -1.0)
	if structures.revision != _chairs_seen:
		_chairs_seen = structures.revision
		if not player.is_carried:
			_step_out_of_chairs()

	world.pickups.check_reach(player.global_position)
	# The rocks watch the player rather than the player reporting to them, so
	# nothing in the controller has to know that jumping rocks is a game.
	world.boulders.watch(player.global_position, not player.is_on_floor())
	world.animals.watch(player.global_position, inventory)
	# One creature near the player says something now and then, from where it
	# actually is. Never on a loop: a dog barking on a loop is wallpaper.
	animal_voices.watch(
		world.animals.living_near(player.global_position, AnimalVoices.AUDIBLE),
		player.global_position, delta
	)

	# Energy follows what the player actually did this frame, and gates running
	# on the next one.
	# Beside a burning fire, energy comes back faster. Warmth is a place rather
	# than something a child carries, so this only applies while they are at it.
	var warmth := world.hearths.warmth_at(player.global_position)
	# And after an ice cream, for half a minute: cooled down, a child's breath
	# comes back twice as fast.
	var cool := Dishes.COOL_BOOST if _cooled_for > 0.0 else 1.0
	_cooled_for = maxf(_cooled_for - delta, 0.0)
	vitals.advance(
		delta, player.is_running, player.is_moving,
		(1.0 + warmth * (Hearths.REST_BONUS - 1.0)) * cool
	)
	player.may_run = vitals.can_run()
	if world.park.on_trampoline(player.global_position):
		player.jump_boost = Park.TRAMPOLINE_BOOST
	elif world.places.on_trampoline(player.global_position):
		player.jump_boost = Places.TRAMPOLINE_JUMP
	else:
		player.jump_boost = 1.0

	# Standing in the shallows fills the bottle without a button. A child who
	# walks into the river to fill up has already expressed the intent; asking
	# him to also find a control would be asking twice.
	if vitals.has_bottle and _standing_in_water():
		if vitals.fill():
			sounds.play(Sounds.Sound.SPLASH)
			hud.announce(Text.of("say_filled"), 1.6)

	_footsteps(delta)
	lantern.follow(world.atmosphere.darkness(), delta)
	world.places.light_lamps(world.atmosphere.evening(), delta)
	world.park.glow(world.atmosphere.darkness())
	ambience.follow(
		player.global_position, world.field, world.places,
		world.atmosphere.darkness(), delta,
		clampf(player.water_depth / Player.SWIM_DEPTH, 0.0, 1.0)
	)
	# Whether what is built from now on is also being built in somebody else's
	# valley. Followed every frame rather than on the session's signals, so a
	# connection that drops without saying goodbye still ends the sharing.
	#
	# Company, not just a connection: a host whose door is open and whom nobody
	# has come through marked everything it built as standing in a valley that
	# did not exist yet. When a brother did arrive, taking one of those down
	# named a place over there where nothing of the sort had ever stood.
	var together := session.has_company()
	if together and not structures.sharing:
		structures.begin_sharing()
	elif not together and structures.sharing:
		structures.stop_sharing()
	# On foot while still arriving: what a guest is riding then is a machine of
	# their own valley, and the host has no such thing to put them on.
	session.report_position(
		player.global_position, player.facing_angle(), &"" if _arriving else player.riding,
		Session.motion_code(
			Vector2(player.velocity.x, player.velocity.z).length(), player.is_swimming, player.diving,
			player.is_tending()
		)
	)
	_share_the_animals(delta)
	# Offered only when there is somebody in the valley to talk to.
	hud.set_voice(
		voice.is_available() and session.has_company(),
		voice.is_talking()
	)

	# The mount follows the player rather than carrying them: a character body
	# parented to a moving node inherits its rotation and fights its own
	# gravity, which is a bigger problem than the one it would solve.
	var riding := player.riding
	# The steepest ground the body under the rider will stand on is the
	# steepest the machine will take. One fact, asked of one place, rather than
	# a number in the mount's table and another in the character body that
	# nobody had ever compared — see HeightField.slope_of.
	player.climbs_ground = (
		HeightField.slope_of(world.mounts.steepest_ground(riding)) if riding != &""
		else Player.CLIMBS_TO
	)
	# Whether the ground under the machine is ground it can be on at all. Asked
	# here rather than further down where it is counted, because the answer
	# decides whether the rider is held to the hillside, and being held to a
	# hillside a machine cannot climb is exactly what it means to be stuck on
	# one.
	var refused := riding != &"" and not world.mounts.can_ride_over(
		riding, player.global_position
	)
	# Only following the ground has a rate; everything else holds still.
	player.held_rate = 0.0
	# A horse in deep water swims, and its rider stays in the saddle rather
	# than floating off it.
	if riding != &"" and world.mounts.afloat(riding, player.global_position):
		player.held_at_height = Mounts.saddle_afloat(
			world.field.water_level_at(player.global_position.x, player.global_position.z)
		)
	elif refused:
		# Ground this machine cannot be on. Let go of the rider entirely: the
		# seat is what holds a machine against a slope, and held against a
		# slope too steep to climb it goes nowhere at all — it cannot go up,
		# and nothing is pulling it down. Released, gravity has it, and a bank
		# steeper than the body will stand on is a bank the body slides back
		# down, which is what a quad nosed at one should do. It is put down on
		# the last good ground a moment later either way; this is what those
		# few tenths of a second look like.
		player.held_at_height = Player.NOT_HELD
		_held_last = Player.NOT_HELD
	elif riding != &"" and Mounts.held_to_the_ground(riding):
		# A rider follows the ground the horse is walking on. Left to
		# ordinary physics, going downhill the child carried on in a straight
		# line while the horse followed the slope down, and hung in the air
		# over it — the same shape of bug as the swimming one. Only while
		# they are near the ground, so a jump or a fall is still a fall.
		# The ground under the whole machine, not under one point of it.
		#
		# A rider is held to the height of the ground beneath them, which is
		# right on a horse at a walk and shakes them to pieces on a motorcycle:
		# at sixteen metres a second every stone the terrain has is a bump
		# delivered straight to the body. Anything with a wheelbase rides the
		# average of the ground under its ends, so that is what is measured —
		# and the bumps between them average out, while a real slope does not.
		var under := Mounts.ground_under(
			world.field, riding, player.global_position, player.facing_angle(),
			Vector2(player.velocity.x, player.velocity.z).length()
		)
		if player.global_position.y - under < 1.2:
			# Followed, with its slope predicted and its bumps smoothed away.
			# See Mounts.held_height for why the slope has to be predicted.
			var held := Mounts.held_height(
				world.field, riding, player.global_position, player.velocity,
				player.facing_angle(), Vector2(_held_last, _held_rate), delta
			)
			# And how fast it is moving, for the body to move with it rather
			# than ease after it a second time.
			player.held_at_height = held.x
			player.held_rate = held.y
			_held_last = held.x
			_held_rate = held.y
		else:
			player.held_at_height = Player.NOT_HELD
			_held_last = Player.NOT_HELD
	else:
		player.held_at_height = Player.NOT_HELD
		_held_last = Player.NOT_HELD
	player.lean_with_the_ground(
		riding != &"" and not world.mounts.afloat(riding, player.global_position),
		world.field, delta
	)
	# The world takes its cue from what is being ridden: a tree is as wide as
	# the horse walking into it, and an engine going past empties the meadow.
	world.riding = riding
	world.mounts.saddled = wallet.has(ShopStock.SADDLE)
	world.animals.has_shears = wallet.has(ShopStock.SHEARS)
	var on_the_motorcycle := MountKinds.kind_of(riding) == MountKinds.MOTORCYCLE
	var on_the_quad := MountKinds.kind_of(riding) == MountKinds.QUAD
	var with_an_engine := on_the_motorcycle or on_the_quad
	# Animals leave for either engine. A quad is quieter than a motorcycle and
	# still not something a squirrel sits through.
	world.animals.racket = with_an_engine and player.is_moving
	# The engine, under the rider and nobody else. How hard it is working comes
	# from how fast the machine is actually going, so the note rises as it
	# pulls away and drops when it stops — an engine at one pitch is a hum.
	# Measured against what the machine itself can do, so a quad at its own
	# full pelt sounds like full pelt rather than like a motorcycle dawdling.
	ambience.engine(
		MountKinds.engine_effort(riding, Vector2(player.velocity.x, player.velocity.z).length()),
		delta,
		on_the_quad
	)
	# A bicycle has no engine; it is heard as tyres, and as the freewheel when
	# nobody is pedalling. Silent for everything else.
	var on_the_bicycle := MountKinds.kind_of(riding) == MountKinds.BICYCLE
	ambience.cycling(
		clampf(
			Vector2(player.velocity.x, player.velocity.z).length() / MountKinds.speed(MountKinds.BICYCLE),
			0.0, 1.0
		) if on_the_bicycle else -1.0,
		world.mounts.pedalling(),
		delta
	)
	# The mount is carried along under the rider rather than the rider being
	# parented to it.
	if riding != &"":
		# Carried to where the rider is *drawn* (as the camera follows them),
		# not to where the physics last left them: the mount is not
		# interpolated, so carried to the tick's position it lagged the
		# rider by up to a tick of travel, a quarter of a metre on the
		# motorcycle, and showed as jitter under the seat.
		var drawn := player.drawn_pose()
		world.mounts.lean(player.ride_bank(), player.steer_angle())
		world.mounts.carry(drawn["at"], drawn["facing"])
		# Told after it is carried, so the seat follows the ground the horse is
		# lying on this frame rather than the ground it was on last one.
		player.set_seat_up(world.mounts.up_of(player.riding))
		player.saddle_lift = world.mounts.saddle_lift()
		player.ride_stride = world.mounts.stride()
		player.ride_pedal = world.mounts.crank_phase() if on_the_bicycle else -1.0
	else:
		player.saddle_lift = 0.0
	_watch_the_turnstile()
	world.mounts.watch(player.global_position)
	var offered := world.mounts.nearest(player.global_position)
	# Which thing the button is about: the one being ridden if there is one,
	# and otherwise whatever is standing within reach. It passed the thing in
	# reach only, and while riding there is nothing in reach — so the button
	# for getting off a quad fell back to the horseshoe every time.
	var about := riding if riding != &"" else offered
	hud.set_mount_in_reach(
		offered != &"", riding != &"",
		MountKinds.floats(about) if about != &"" else false,
		MountKinds.kind_of(about) if about != &"" else &""
	)
	# Ground a mount cannot take, for longer than a moment.
	#
	# It used to put the rider down the instant a single frame said no, and a
	# single frame is a low bar: a wheel over the lip of a bank, a body half
	# over the edge of the bridge's apron, one physics step in which the
	# height field is consulted at a point the machine is already leaving. A
	# short grace means a child has to actually be somewhere impossible rather
	# than to have passed through it.
	if refused:
		# At most a tenth of a second a frame. A phone brought back from the
		# app switcher can hand the first frame back several seconds long, and
		# one frame of unlucky ground then counted as seconds of it and put the
		# rider down on the spot.
		_bad_ground += minf(delta, MAX_STUCK_STEP)
	else:
		_bad_ground = 0.0
	if riding != &"" and _bad_ground > STUCK_GROUND:
		# Ridden somewhere this mount cannot go — put the child down rather than
		# stranding them on a bicycle halfway up a cliff. Back on the last
		# ground it was willing to stand on, not on the slope that refused it:
		# put down where they were, a child ended up in the hillside.
		var back_at := world.mounts.safe_ground(player.global_position)
		player.global_position = back_at + Vector3(0.0, 0.2, 0.0)
		# Put down standing still: the machine's speed stayed with the body, and
		# a motorcycle's sixteen metres a second carried the child on, off the
		# safe ground and straight back into the bank they were taken off.
		player.velocity = Vector3.ZERO
		world.mounts.dismount(back_at, player.facing_angle())
		player.riding = &""
		camera_rig.set_eye_lift(0.0)
		sounds.play(Sounds.Sound.REFUSE)
		_bad_ground = 0.0
	elif riding != &"" and _bad_ground <= 0.0:
		world.mounts.note_good_ground(player.global_position)

	# How deep the player is *submerged* — not how deep the water is where they
	# are standing. Those agree only while a child is on the bottom, and the
	# difference is what sent one into the sky. See Places.submersion.
	var at := player.global_position
	player.water_depth = world.places.submersion(at)
	player.current = world.field.river_current_at(at.x, at.z)

	# Going under.
	#
	# Offered whenever there is water to go under, and taken away the moment
	# there is not, so a child standing on the bank is never shown a button
	# that would do nothing. The player clears the dive flag itself when the
	# water runs out — this only decides whether the button is on the screen.
	hud.set_dive_offer(player.is_swimming, player.diving)
	# Drawn from where the camera is, not where the swimmer is — see
	# World.see_from.
	world.see_from(camera_rig.camera.global_position, delta)
	# And heard from there too: the same eased amount, so the ear goes under at
	# the moment the eye does.
	Mix.muffle(world.atmosphere.under_water())
	# The surface is crossed with a sound, both ways. A dive was silent: the
	# picture went green and the ear was told nothing, so going under felt like
	# a camera trick rather than something done to water.
	var eye_under := eye_is_under(_eye_was_under, world.atmosphere.under_water())
	if eye_under != _eye_was_under:
		_eye_was_under = eye_under
		sounds.play(Sounds.Sound.SPLASH, 0.85 if eye_under else 1.15)

	# A child on the swing or on the slide is carried. Both end on their own —
	# there is no way to be stuck on a ride.
	_carry(delta, at)

	# Whatever the place a child is standing in offers.
	var here := _place_here(at)
	# And the child's own cafe or shop, where the valley's are not.
	var home := structures.venue_at(at) if here == &"" else &""
	hud.set_place_offer(_offer_at(here) if here != &"" else home)
	hud.set_cafe_price_offer(home == &"cafe")
	# The menu is on the screen while a child is inside a café, and goes while
	# they are sat at their plate.
	hud.set_cafe_menu_open(
		(here == Places.CAFE or home == &"cafe") and _dining <= 0.0, home == &"cafe", wallet.coins
	)
	structures.light_lamps(world.atmosphere.evening(), at)
	hud.set_at_the_pitch(Pitch.is_beside(at.x, at.z, SCORE_SHOWN_WITHIN))
	# The shelf is for standing at the counter. Left open, it went on selling
	# to a child who had walked off across the valley, with the stick still live
	# under it, and they came back to find the screen covered.
	if hud.is_shop_open() and here != Places.SHOP:
		hud.set_shop_open(false, wallet.coins, wallet.owned)

	# A bed offers itself at night, and says nothing in the daytime.
	var bed := structures.nearest(at, BED_REACH)
	hud.set_sleep_offer(
		not bed.is_empty() and bed.get("kind", &"") == HouseParts.BED
	)

	_catch_a_fall(at)

	# A roof comes off while you are under it, or the camera looks at tiles.
	world.places.roofs_follow(at)
	# The same roofless-ness keeps the camera's own reach short, so a spring
	# arm that fails to catch a nearby wall cannot sail out through it and show
	# the building from outside with its roof still off. See set_indoors.
	camera_rig.set_indoors(
		not world.places.roof_is_on(Places.CAFE) or not world.places.roof_is_on(Places.SHOP)
	)

	hud.set_lantern(lantern.owned, lantern.switched_on)

	# What the shop would pay for, so its shelf can say whether there is
	# anything to sell.
	for sellable in ShopStock.BUYS:
		hud.set_carried_for_sale(sellable, inventory.count(sellable))

	# Chocolate can be eaten anywhere, which is the point of carrying it.
	hud.set_snack_offer(inventory.count(ItemKinds.CHOCOLATE) > 0)

	# A fire takes a log from a child standing at it with wood.
	hud.set_fire_offer(
		inventory.count(ItemKinds.WOOD) > 0 and world.hearths.can_feed(at)
	)

	# The beavers take a stick at a dam site, from a child carrying one.
	var dam_site := world.dams.site_near(at)
	hud.set_dam_offer(not is_nan(dam_site) and inventory.count(&"stick") > 0)

	# Drawing a bow: the bow itself at the child's side, and the arrow's own
	# arc hanging in the air, so there is something to aim *with*. Where a
	# shot went was otherwise a guess — the aim follows the camera's pitch,
	# which is right and is invisible.
	if player.is_charging() and hud.is_shooting():
		player.hold_the_bow(true, player.kick_charge)
		_show_where_the_arrow_goes()
	else:
		player.hold_the_bow(false, 0.0)

	hud.set_on_shooting_line(
		player.global_position.distance_to(world.archery.shooting_line()) < SHOOTING_LINE_REACH
	)

	# The axe only offers itself when there is a tree to use it on.
	# A planted tree counts on its own: a child's tree standing in a meadow with
	# no wild one within reach was never offered the axe at all.
	var wild_in_reach := bool(world.vegetation.nearest_tree_found(player.global_position, CHOP_REACH)[1])
	var planted_in_reach := not structures.nearest_grown_tree(player.global_position, CHOP_REACH).is_empty()
	var tree_in_reach := wallet.has(ShopStock.AXE) and (wild_in_reach or planted_in_reach)
	# A tree somebody planted is felled first unless a wild one is nearer (see
	# _on_chop), and is somebody's work: it takes a held press, where a wild
	# tree takes a tap.
	hud.set_tree_in_reach(tree_in_reach, tree_in_reach and _axe_falls_on_a_planted_tree())

	# The care button says what the animal in front of you wants, at the moment
	# you can do something about it.
	var near_animal := world.animals.nearest_caring(player.global_position, inventory)
	hud.set_animal_in_reach(
		AnimalKinds.wish(near_animal["kind"]) if not near_animal.is_empty() else ""
	)
	tasks.on_moved(player.global_position)
	build_mode.aim(player.global_position, camera_rig.yaw)
	hud.set_storey(
		build_mode.storey(),
		build_mode.active and (HouseParts.is_house_part(build_mode.selected) or Plans.is_plan(build_mode.selected))
	)
	hud.set_house_hint(_first_house_step())

	# Which side this child is when two play, on the chip and on a band round
	# their chest; and a gentle touch for a ball they are jogging at. A guest
	# only shows the touch, the host's ball being the one that moves.
	var side := world.football.my_side()
	hud.set_side(side)
	player.set_band(Goal.SIDE_COLOURS[side] if side >= 0 else Color(0.0, 0.0, 0.0, 0.0))
	if riding == &"":
		var on_foot := player.velocity
		if world.football.is_following():
			world.football.feel(player.global_position, on_foot, delta)
		else:
			world.football.dribble(player.global_position, on_foot, delta)
		world.places.dribble(player.global_position, on_foot, delta)

	# The kick button appears only with a ball at your feet. The keyboard runs
	# through the same two calls as the button, so the two controls cannot end
	# up kicking differently.
	var ball := _ball_near()
	hud.set_ball_in_reach(ball != null, ball != null and _can_throw(ball))
	_face_the_view_at_the_ball(ball, delta)
	if ball != null and Input.is_action_just_pressed(InputActions.KICK):
		_on_kick_start()
	if player.is_charging() and Input.is_action_just_released(InputActions.KICK):
		_on_kick_release()

	# While winding up, show how hard and how high — and drop the wind-up if the
	# ball is kicked away or walked away from, so the bar never lies.
	#
	# Not while a bow is being drawn. A bow and a kick share the one wind-up,
	# and there is never a ball on the shooting line: this cancelled the draw
	# on the very frame it started, every frame, so the bow showed for one
	# frame, its arc was hidden the moment it was drawn, and every arrow flew
	# at the weakest pull there is.
	if player.is_charging() and hud.is_shooting():
		hud.set_kick_preview(false, 0.0, 0.0)
	elif player.is_charging():
		if ball == null:
			player.release_charge()
			hud.set_kick_preview(false, 0.0, 0.0)
			kick_preview.hide_path()
		else:
			hud.set_kick_preview(true, player.kick_charge, _kick_loft())
			_show_where_it_goes(ball)
	else:
		hud.set_kick_preview(false, 0.0, 0.0)
		# Not winding up, but a ball is at the child's feet: show where a tap would
		# send it, so they can turn to aim before they press. Not while building,
		# nor for a ball left in the net for the cheer, which a kick would not move.
		if ball != null and not build_mode.active and not (world.football.has_ball(ball) and world.football.in_the_net(ball)) and _resting_preview_on(player.velocity):
			_show_where_it_goes(ball)
		else:
			kick_preview.hide_path()

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
	tasks.on_collected(inventory, kind)

## Switching language rebuilds the interface rather than trying to retranslate
## it in place. Every button was created with its text baked in, and hunting
## down each one to update it is the kind of job that is always one label short.
func _on_language(code: StringName) -> void:
	Text.set_language(code)
	world.football.rewrite_board()
	_write_save()
	_rebuild_hud()

## Throw the valley away and start it over, keeping the same seed so it is the
## same place rather than a different one.
##
## Everything a child made goes: what they carried, what they built, which
## pickups they had taken, the score. The seed stays because "start again"
## should mean a clean morning in the valley you know, not exile to a new one.
func _on_reset() -> void:
	# Not in somebody else's valley. A guest holds the host's structures in the
	# place of their own, so the hold wiped the host's valley from this screen
	# and emptied the guest's own bag, which the save then wrote down: a child
	# visiting a brother lost their own things to a button meant for their own
	# valley, and nothing of the brother's changed at all.
	if _visiting:
		sounds.play(Sounds.Sound.REFUSE)
		hud.announce(Text.of("say_reset_visiting"), 3.0)
		return
	# Nor while the way into one is still open: between joining and the host's
	# valley arriving this child is a guest already, and a reset then would
	# empty their own valley just before the host's was set over it.
	if session.is_following():
		sounds.play(Sounds.Sound.REFUSE)
		hud.announce(Text.of("say_reset_visiting"), 3.0)
		return
	# What is about to go is first copied aside, valley and bag both, so a
	# reset pressed by mistake can be put right by hand.
	if _may_save and _world_ready:
		_write_save()
		SaveGame.keep_copy(profiles.current_world_path())
		SaveGame.keep_copy(profiles.current_save_path())
	if structures != null:
		structures.from_data([])
		# Its campfires are gone, so no fire can go on burning without one.
		_refresh_fires()
	inventory.from_data({})
	world.pickups.from_data([])
	# The trees cut down and the dams the beavers finished are the child's
	# doing too: "new again" left every stump standing and every pond full.
	world.felled.from_data([])
	world.vegetation.rebuild_all()
	world.dams.adopt([], {})
	world.boulders.from_data({})
	world.football.from_data({})
	birds.set_points([])
	_seen_first_grove = false
	world.follow(player.global_position)
	_write_save()
	_rebuild_hud()
	_show_guests_the_valley_again()
	hud.announce(Text.of("say_reset"), 3.0)

## A guest in this valley is told what it now holds. The reset sends no
## removals, so the guest's phone went on showing every wall and tree that was
## just cleared here, and then refused each new piece built on the same spots
## as already taken. The valley is sent again as when they arrived: it replaces
## what they hold, so both phones show the same empty valley. Only the host
## ever sends this; a guest has no message that resets anybody's valley.
func _show_guests_the_valley_again() -> void:
	if not session.is_host() or not session.has_company():
		return
	for id: int in session.guests.keys():
		session.report_valley(structures.to_data(), world.felled.to_data(), id)
		session.report_shared(
			PackedStringArray(world.pickups.to_data()), world.dams.built,
			world.dams.progress, world.mounts.to_data(), id
		)

## Everything on the HUD that Wiring.connect_hud does not cover.
##
## In its own function because there are two places a HUD comes into being —
## starting up, and resetting the valley — and only the first of them did this.
## After a reset the talk button and the whole play-together panel were
## connected to nothing: a child could press talk and never be heard, and open
## "play together" onto a page whose buttons did nothing at all.
func _connect_the_rest_of_the_hud() -> void:
	# The map shows the children on other phones, and the nearest horse.
	var map := hud.minimap()
	if map != null:
		map.friend_source = visitors.positions
		map.horse_source = func(from: Vector3) -> Vector3:
			return world.mounts.nearest_standing(MountKinds.HORSE, from)
	voice.allowed = _voice_allowed
	hud.voice_allowed_changed.connect(func(allowed: bool) -> void:
		_voice_allowed = allowed
		voice.allowed = allowed
		_write_save())
	hud.shop_sold_back.connect(_on_sell_back)
	hud.set_cafe_paid(_cafe_paid)
	hud.cafe_price_toggled.connect(func(paid: bool) -> void:
		_cafe_paid = paid
		_write_save())
	hud.view_toggled.connect(_on_view_toggled)
	hud.confirmed.connect(_on_answered.bind(true))
	hud.refused.connect(_on_answered.bind(false))
	hud.fire_fed.connect(_on_feed_fire)
	hud.slept.connect(_on_sleep)
	hud.talk_started.connect(voice.start_talking)
	voice.permission_refused.connect(hud.show_mic_refused)
	hud.talk_released.connect(voice.stop_talking)
	hud.together_opened.connect(_on_together_opened)
	hud.name_chosen.connect(_on_name_chosen)
	hud.shirt_chosen.connect(_on_shirt_chosen)
	hud.set_player_name(profiles.current_player)
	hud.set_shirt(_shirt)
	player.set_shirt(_own_shirt_color())
	hud.set_worn_shirt(_own_shirt_color())
	player.set_look(_look)
	hud.set_look(_look)
	hud.look_chosen.connect(_on_look_chosen)
	hud.look_offer_closed.connect(_on_look_offer_closed)
	if not _look_offered:
		hud.offer_look()
	hud.together.host_requested.connect(_on_host_requested)
	hud.together.join_requested.connect(_on_join_requested)
	hud.together.leave_requested.connect(_on_leave_requested)

func _rebuild_hud() -> void:
	var was_building := build_mode.active
	# A question open on the old interface is not open on the new one, and the
	# game believing otherwise ignored every ride's button until the question
	# that was no longer on the screen was somehow answered. Walking back up to
	# whatever asked it asks again.
	_asked = &""
	_asked_ride = &""
	# The talk button goes with the old interface, and a button that is freed
	# while it is held never sends its release: the microphone, and the hush on
	# the valley's sounds, stayed on until somebody pressed talk again.
	voice.stop_talking()
	# What a child set in the old one — the price of their own café, the dish
	# on the menu — is held only there, and is carried across.
	var cafe_paid := hud != null and hud.cafe_is_paid()
	var dish: StringName = hud.chosen_dish() if hud != null else Dishes.USUAL
	if hud != null:
		hud.queue_free()
	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.restore_cafe_choices(cafe_paid, dish)
	Wiring.connect_hud(hud, build_mode, camera_rig, inventory, world.field, player, structures, _handlers())
	_connect_the_rest_of_the_hud()
	_show_the_state()
	if was_building:
		# On the tab the piece in hand is on, or the new interface opens on the
		# things and swaps the wall a child was laying for a sapling.
		hud.show_group_of(build_mode.selected)
		hud.set_building(true)
		build_mode.say_again()

## Everything the interface shows that it cannot work out for itself, read from
## the game as it is right now.
##
## The interface was only ever told about changes: the purse when a coin was
## earned, the task when a step was finished, the whistle when one was bought.
## So the game opened — and was rebuilt in full on every change of language —
## with the purse at nought until the next coin, no task on the screen, no
## whistle for a child who owned one and no bottle on the gauge. The screenshot
## tool filled these in by hand, which is why no picture ever showed it.
func _show_the_state() -> void:
	hud.set_coins(wallet.coins)
	hud.set_owned(wallet.owned)
	hud.set_task(_task_line())
	_refresh_vitals()
	hud.set_voice_allowed(_voice_allowed)
	hud.set_first_person(_first_person)
	hud.set_cafe_paid(_cafe_paid)
	hud.set_score(world.football.blue, world.football.red)

## The one line at the top of the screen: the next step while a child is still
## learning the valley, and today's task, counted, once they have.
##
## Today's task used to appear only once it was already done — the line was
## written by the handler for finishing it and by nothing else — so the one
## thing worth doing each day was never on the screen while it was worth doing.
func _task_line() -> String:
	if not tasks.is_finished():
		return tasks.instruction()
	return today.describe()

## Every control's handler in one place, named rather than ordered.
func _handlers() -> Dictionary:
	return {
		&"place": _on_place,
		&"kick_start": _on_kick_start,
		&"kick_release": _on_kick_release,
		&"jump": _on_jump,
		&"dive": _on_dive,
		&"remove": _on_remove,
		&"undo": _on_undo,
		&"language": _on_language,
		&"reset": _on_reset,
		&"care": _on_care,
		&"shop": _on_shop,
		&"buy": _on_buy,
		&"drink": _on_drink,
		&"whistle": _on_whistle,
		&"chop": _on_chop,
		&"ride": _on_ride,
		&"shoot_start": _on_shoot_start,
		&"shoot_release": _on_shoot_release,
		&"visit": _on_place_used,
		&"dam": _on_dam_stick,
		&"ticket": _on_ticket,
		&"snack": _on_snack,
		&"lantern": _on_lantern,
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
		grown = structures.advance_offline(journal.seconds_away)

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
	if world.places.at_fountain(at):
		return true
	return at.y < HeightField.WATER_LEVEL + 0.9 and world.field.distance_to_river(at.x, at.z) < 30.0

## How much wood a tree is worth, and how far you must be to reach it.
const CHOP_REACH := 3.4
const WOOD_PER_TREE := 4

## What a fleece comes to, and how much of a child's legs a cow's milk gives
## back. The fleece grows again on its own clock, so this is a wage rather than
## a prize.
const WOOL_PER_SHEEP := ShopStock.WOOL_PER_SHEEP
const MILK_RESTORE := 0.3

## How close to the shooting line a child must stand to draw a bow.
const SHOOTING_LINE_REACH := 6.0

## How long the child has been on the slide (negative when not), and how far
## along it they have come.
var _sliding := -1.0
var _slid := 0.0
## How long the child has left sitting at a café table, and where they sit.
var _dining := 0.0
var _dining_seat := Vector3.ZERO
var _dining_facing := 0.0

## Whether the slide, a chair or the swing has hold of the child right now.
func _is_being_carried() -> bool:
	return _sliding >= 0.0 or _dining > 0.0 or world.places.swinging()

## Put the child where the ride says they should be, or let them go.
func _carry(delta: float, at: Vector3) -> void:
	# A swing, a slide and a chair at a table all take hold of the child's own
	# body, so a mount cannot come with them: it was carried into the café
	# under the tray, and a child on the swing was drawn sitting on a horse.
	# Got off, as on any other ride that has hold of them.
	if player.riding != &"" and _is_being_carried():
		_on_ride()
	if _sliding >= 0.0:
		_sliding += delta
		var top := world.places.slide_top()
		var foot := world.places.slide_foot()
		var journey := top.distance_to(foot)
		var down := foot - top
		var along := Vector3(down.x, 0.0, down.z).normalized()
		# Gathering speed from rest, as a body on a slide does, up to the
		# slide's top speed; then a short run-out on the ground, slowing to a
		# stop. The first ride moved at one speed and stopped dead at the foot.
		var pace := minf(Places.SLIDE_SPEED, Places.SLIDE_ACCEL * _sliding)
		if _slid > journey:
			pace = Places.SLIDE_SPEED * (1.0 - clampf((_slid - journey) / Places.SLIDE_RUN_OUT, 0.0, 1.0))
		_slid += pace * delta
		if _slid <= journey:
			player.carried_to = top.lerp(foot, _slid / maxf(journey, 0.01)) + Vector3.UP * 0.06
		else:
			var over := foot + along * minf(_slid - journey, Places.SLIDE_RUN_OUT)
			over.y = world.field.height_at(over.x, over.z)
			player.carried_to = over
		player.face(along, delta)
		player.is_carried = true
		if _slid > journey and pace < 0.5:
			_sliding = -1.0
			_slid = 0.0
			player.is_carried = false
			sounds.play(Sounds.Sound.LAND, 1.2)
		return

	if _dining > 0.0:
		_dining -= delta
		player.carried_to = _dining_seat + Vector3(0.0, -Places.DINING_SINK, 0.0)
		player.is_carried = true
		player.face(Vector3(-sin(_dining_facing), 0.0, -cos(_dining_facing)), delta)
		if _dining <= 0.0:
			player.is_carried = false
			# Out of a chair of their own before the furniture is solid to them
			# again: they are sat inside its seat, between it and the table.
			_step_out_of_chairs()
			player.collision_mask = TerrainSpec.LAYER_GROUND | TerrainSpec.LAYER_PROPS
		return

	if world.places.swinging():
		# Pushing the stick gets off. The swing now keeps going for half a
		# minute, and a ride you cannot leave is a trap rather than a swing.
		var wants_off := Input.get_vector(
			InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT,
			InputActions.MOVE_FORWARD, InputActions.MOVE_BACK
		).length() > 0.5
		if wants_off:
			world.places.step_off_swing()
			player.is_carried = false
			# Put down, not thrown. The carry leaves the body moving at the
			# seat's own speed, which at the bottom of a full arc is over seven
			# metres a second, and the ground gives that up only as fast as
			# friction takes it: a child who stepped off a high swing flew
			# several metres, and one who stepped off on the way up rose as well.
			player.velocity = Vector3.ZERO
		else:
			player.carried_to = world.places.swing_rider_at()
			player.is_carried = true
			return

	if player.is_carried:
		player.is_carried = false

	# Stepping onto the top of the slide starts the ride, with no button: a
	# child who climbed the ladder has already said what they want.
	# On foot only: a slide that carries a rider off a horse leaves the machine
	# dragged down the chute after them.
	if world.places.at_slide_top(at) and _sliding < 0.0 and player.riding == &"":
		_sliding = 0.0
		_slid = 0.0
		sounds.play(Sounds.Sound.JUMP, 1.4)

## How far off the pitch's apron the score is still shown, in metres.
const SCORE_SHOWN_WITHIN := 10.0

## The place a child is standing in, counting the foot of the scoreboard, which
## is not one of the camp's places but offers a button the same way.
func _place_here(at: Vector3) -> StringName:
	var here := world.places.nearest(at)
	if here == &"" and Pitch.near_scoreboard(at.x, at.z):
		return Pitch.SCOREBOARD
	return here

## What the place a child is standing in is offering, as a label — or nothing.
func _offer_at(place: StringName) -> StringName:
	match place:
		Places.PLAYGROUND, Places.CAFE, Places.SHOP, Pitch.SCOREBOARD:
			return place
		_:
			# The pool needs no button: a child walks in and swims. Offering
			# "swim" beside water you are already standing in is noise.
			return &""

## The name a child is known by on the other machine. Their profile name if
## they have one, and otherwise something rather than nothing — a blank label
## over a visitor tells you somebody is there but not who.
func _display_name() -> String:
	if not profiles.current_player.is_empty():
		return profiles.current_player
	return Text.of("ui_player")

## The colour this child's own body is drawn in: their own pick, or the
## fallback for a child who has not picked one.
##
## The fallback used to be a colour of its own — blue-grey, found nowhere in
## the twelve shirts — while everyone else fell back to one from the palette
## itself, worked out from this child's own network id. A child who had never
## picked a shirt was one colour on their own screen and a different one on
## every brother's: "I am the blue one" was true nowhere, because nobody was
## told which one they were. The same formula, fed this child's own id, is
## what a peer who has just met them computes too — the two machines agree
## without a byte passing between them, because the id is the one thing both
## of them already have.
func _own_shirt_color() -> Color:
	if _shirt >= 0:
		return Visitors.SHIRTS[_shirt]
	# One is the id of a machine nobody has joined, which is also what a game
	# started without any network peer at all has to be taken as: asking for the
	# id of no peer prints an error on every start.
	if not multiplayer.has_multiplayer_peer():
		return visitors.shirt_for(1, -1)
	return visitors.shirt_for(multiplayer.get_unique_id(), -1)

## The network id changes when a visit begins and ends, and an unshirted
## child's colour is worked out from it.
func _refresh_own_shirt() -> void:
	player.set_shirt(_own_shirt_color())
	if hud != null:
		hud.set_worn_shirt(_own_shirt_color())

## A child picked a shirt in the settings.
##
## Their own body changes at once — "I am the blue one" has to be true on their
## own screen before it means anything — and everyone already in the valley is
## told, so it changes over there too without waiting for a rejoin.
func _on_shirt_chosen(which: int) -> void:
	_shirt = which
	player.set_shirt(_own_shirt_color())
	hud.set_shirt(which)
	hud.set_worn_shirt(_own_shirt_color())
	sounds.play(Sounds.Sound.CHIME, 1.35)
	_write_save()
	if session.is_connected_to_anyone():
		session.report_name(_display_name(), _shirt, _look)

## A child picked who they are in the settings, or in the panel a first run
## opens on: a character, a skin tone and a hair colour. As with the shirt, their
## own body changes at once and everybody already here is told.
func _on_look_chosen(look: Array) -> void:
	_look = Character.clean(look)
	player.set_look(_look)
	hud.set_look(_look)
	sounds.play(Sounds.Sound.CHIME, 1.35)
	_write_save()
	if session.is_connected_to_anyone():
		session.report_name(_display_name(), _shirt, _look)

## The first-run panel was closed, by the tick or by the cross: either way the
## child has been asked, and is not asked again.
func _on_look_offer_closed() -> void:
	_look_offered = true
	_write_save()

## A child named themselves in the settings.
##
## The name is what floats over their head in their brother's valley, and until
## now nothing could set it: Profiles had add_player() and choose_player() and
## no caller for either, so current_player stayed empty for ever and every
## child in the valley was labelled "player".
##
## Choosing a name changes where this child's progress is written — the save
## path is built from it — so the afternoon is written straight back out
## afterwards. The state is all in memory, so writing it to the new path
## carries the bag, the coins and the journal across; the world itself is
## keyed by the valley rather than by the child and does not move at all.
func _on_name_chosen(typed: String) -> void:
	var name := Profiles.tidy(typed)
	if name == profiles.current_player:
		return
	if not Profiles.is_valid_name(name):
		sounds.play(Sounds.Sound.REFUSE)
		hud.announce(Text.of("say_name_no"), 3.5)
		hud.set_player_name(profiles.current_player)
		return

	# A name somebody has already played under on this phone is that child:
	# typing it is how one child hands the phone to another, and how a child
	# who renamed themselves gets their old name back.
	#
	# It used to be refused as taken, because writing this child's state under
	# it would have been the end of the other child's afternoon — which was
	# right about the danger and wrong about the answer. Nothing is written
	# over either way: this child is saved under their own name first, and then
	# the game opens again as the other one, exactly as they left it.
	var known := profiles.player_named(name)
	if not known.is_empty() and known != profiles.current_player:
		_become(known)
		return

	# A new name is a new name for this child, who keeps everything.
	if not profiles.rename_player(profiles.current_player, name):
		sounds.play(Sounds.Sound.REFUSE)
		hud.announce(Text.of("say_name_no"), 3.5)
		hud.set_player_name(profiles.current_player)
		return
	_write_save()
	hud.set_player_name(name)
	sounds.play(Sounds.Sound.CHIME, 1.2)
	hud.announce(Text.format("say_name_set", [name]), 3.5)
	# Anybody already in the valley is told, so the label over this child
	# changes there and then rather than at the next join.
	if session.is_connected_to_anyone():
		session.report_name(name, _shirt, _look)

## Hand the game to another child on this phone.
##
## This child is saved where they stand, and the game opens again as the other
## one — in a valley they may enter, theirs if the one this child was in is not.
## Opened again rather than swapped in place: everything the game knows about a
## child is read once, on the way in, and a reload is the one path that is
## certain to read all of it.
func _become(other: String) -> void:
	_write_save()
	# Nothing may write again before the reload. The save path now follows
	# `other`, while everything in memory is still this child's: an autosave
	# or the pause notification landing in that gap wrote this child's bag and
	# coins over their brother's save.
	_may_save = false
	# The connection is ended here and not left to the reload: it belongs to the
	# scene tree and outlives this scene, so the other phone would go on holding
	# a child who had handed the tablet to a brother. Going home is the reload
	# that follows, so the close must not start a second one.
	_going_home = true
	session.close()
	profiles.choose_player(other)
	if not profiles.may_enter(profiles.current_world, other):
		var theirs := profiles.worlds_for(other)
		profiles.choose_world(
			theirs[0] if not theirs.is_empty()
			else profiles.create_world(Profiles.HOME_MAP, other)
		)
	profiles.save_index()
	get_tree().reload_current_scene()

func _on_together_opened() -> void:
	# Opened on the page that matches what is already happening, so a child who
	# is hosting and reopens this sees their number instead of being asked again
	# whether they would like to host.
	if session.is_host():
		hud.together.show_hosting()
	elif session.is_following():
		hud.together.show_visiting()
	else:
		# Also while a join is still in flight: that child is in their own
		# valley, and "you are in someone else's valley" would be untrue.
		hud.together.open()

func _on_host_requested() -> void:
	if session.host(_display_name(), _shirt, _look):
		hud.together.show_hosting()

func _on_join_requested(code: int) -> void:
	var address := Session.address_for_code(code)
	if address.is_empty():
		sounds.play(Sounds.Sound.REFUSE)
		hud.announce(Text.of("say_no_network"), 3.0)
		return
	if session.join(address, _display_name(), _shirt, _look):
		_arriving = true
		_host_at = Vector3.INF
		_placed = false
		_valley_received = false
		# Said at once, because a number nobody answers to takes seconds to be
		# given up on, and a keypad that does nothing looks broken.
		hud.together.close()
		hud.announce(Text.of("say_joining"), 4.0)

func _on_leave_requested() -> void:
	session.close()
	hud.together.close()
	hud.announce(Text.of("say_alone_again"), 2.5)

func _on_session_opened(_port: int) -> void:
	sounds.play(Sounds.Sound.CHIME, 1.2)
	hud.announce(Text.format("say_hosting", [Session.own_code()]), 6.0)

func _on_session_joined() -> void:
	sounds.play(Sounds.Sound.CHIME, 1.2)
	hud.together.close()
	hud.announce(Text.of("say_visiting"), 3.0)

func _on_guest_arrived(id: int, name: String, shirt: int) -> void:
	visitors.add(id, name, shirt, session.guest_looks.get(id, []))
	sounds.play(Sounds.Sound.CHIME, 1.4)
	# A guest meets the host, who has not "come to your valley": it is the
	# guest who has come to theirs.
	if session.is_host():
		hud.announce(Text.format("say_joined", [name]), 4.0)
		session.report_time_of_day(world.atmosphere.time_of_day, id)
		structures.share_standing()
		session.report_valley(structures.to_data(),world.felled.to_data(), id)
		session.report_shared(
			PackedStringArray(world.pickups.to_data()), world.dams.built,
			world.dams.progress, world.mounts.to_data(), id
		)
	else:
		hud.announce(Text.format("say_met", [name]), 4.0)

## Somebody else moved. The host's first position is where a guest who has just
## asked to come is set down, and the host's valley follows it.
func _on_guest_moved(id: int, at: Vector3, facing: float, mount := &"") -> void:
	visitors.move(id, at, facing, mount)
	_follow_their_mount(id, at, facing, mount)
	if id != Session.HOST_ID:
		return
	_host_at = at
	if _arriving and not _placed and session.is_following():
		_placed = true
		_begin_visit()
		_place_beside_host()
		if _valley_received:
			_arriving = false

## Which mount each other child is on, by their peer id. A mount somebody rides
## goes where they go on this phone too — the horse a guest rides in the host's
## valley is not left standing where it was — and is let go when they get off,
## leave, or the connection ends.
var _rides_of_others: Dictionary = {}

## Where each of those riders was last said to be, as [position, facing], so
## that a mount can be put under them again (see _on_remote_shared).
var _ride_spots: Dictionary = {}

func _follow_their_mount(id: int, at: Vector3, facing: float, mount: StringName) -> void:
	var was: StringName = _rides_of_others.get(id, &"")
	if was != &"" and was != mount:
		world.mounts.release_remote(was)
	if mount == &"":
		_rides_of_others.erase(id)
		_ride_spots.erase(id)
		return
	# Both children got on this machine in the same moment. The host's keeps
	# it (see Session.gives_way_on_a_mount): the host's phone ignores the
	# guest's claim, and the guest's puts its child down where they are, with
	# the machine taken to the host's rider, a gentle word and no jolt.
	if mount == player.riding:
		if not Session.gives_way_on_a_mount(session.is_following(), id):
			_rides_of_others.erase(id)
			_ride_spots.erase(id)
			return
		_get_off_quietly()
		sounds.play(Sounds.Sound.REFUSE, 0.6)
		hud.announce(Text.of("say_mount_taken"), 2.6)
		_rides_of_others[id] = mount
		_ride_spots[id] = [at, facing]
		world.mounts.ride_remote(mount, at, facing)
		# Beside the machine, not where they were riding it: that is the spot
		# the host's rider is on now, and the two children stood overlapped.
		var beside := world.mounts.spot_beside(mount, at, facing)
		player.global_position = beside + Vector3(0.0, 0.2, 0.0)
		player.velocity = Vector3.ZERO
		return
	_rides_of_others[id] = mount
	_ride_spots[id] = [at, facing]
	world.mounts.ride_remote(mount, at, facing)

func _let_go_of_their_mounts(id := 0) -> void:
	for who: int in _rides_of_others.keys():
		if id == 0 or who == id:
			world.mounts.release_remote(_rides_of_others[who])
			_rides_of_others.erase(who)
			_ride_spots.erase(who)

## A mount this child got off is left standing, and the other phone is told
## where. Its rider's last position said where *they* were, which is a stride
## from where the machine is put.
func _on_dismounted(kind: StringName) -> void:
	if not _telling_of_parking:
		return
	session.report_parked(kind, world.mounts.position_of(kind), world.mounts.facing_of(kind))

## How often the host says where its animals are. Often enough that two
## children feeding the same cow are at the same cow; a good deal less than the
## positions, since an animal is slow.
const ANIMAL_TELLING := 0.4
var _since_animals_told := 0.0

## The host's animals are the animals. A guest's phone follows what the host
## says; the host tells each guest about those near anybody in the valley.
func _share_the_animals(delta: float) -> void:
	world.animals.following = session.is_following()
	world.animals.pitch_in_play = world.football.my_side() >= 0
	world.animals.companions.clear()
	if not session.is_host() or not session.has_company():
		return
	for at: Vector3 in session.guest_positions.values():
		world.animals.companions.append(at)
	_since_animals_told += delta
	if _since_animals_told < ANIMAL_TELLING:
		return
	_since_animals_told = 0.0
	var places: Array[Vector3] = [player.global_position]
	for at: Vector3 in session.guest_positions.values():
		places.append(at)
	session.report_animals(world.animals.states_near(places))

## The host's valley, as it stands, arrives for a guest.
func _on_remote_valley(pieces: Array, stumps: Array) -> void:
	if not session.is_following():
		return
	_begin_visit()
	structures.from_data(pieces)
	structures.adopt_as_shared()
	world.felled.from_data(stumps)
	world.vegetation.rebuild_all()
	_refresh_fires()
	# What the host has built is not news, whatever it is.
	_known_cafe = structures.has_venue(&"cafe")
	_known_shop = structures.has_venue(&"shop")
	_valley_received = true
	# Set down again beside the host, now that their walls are here to be
	# stood clear of rather than somebody else's.
	if _placed:
		_place_beside_host()
		_arriving = false

## The rest of the host's valley arrives for a guest: the pickups already gone,
## the dams as they stand, and every mount where the host has it.
func _on_remote_shared(
	taken: PackedStringArray, built: Array, progress: Dictionary, mounts: Dictionary
) -> void:
	if not session.is_following():
		return
	_begin_visit()
	world.pickups.from_data(Array(taken))
	world.dams.adopt(built, progress)
	# Off whatever they were riding before its machine is swapped for the host's.
	_get_off_quietly()
	world.mounts.adopt(mounts)
	# Adopting forgets which machines somebody is on, and the host's first
	# position — which names the horse it is riding — arrives before this does.
	# A host standing still in the saddle sends nothing more, so the horse
	# would be left drawn, solid and empty at its old place beneath them.
	for who: int in _rides_of_others:
		var spot: Array = _ride_spots.get(who, [])
		if spot.size() == 2:
			world.mounts.ride_remote(_rides_of_others[who], spot[0], spot[1])

## Off the mount without telling the host where it was left: it is one of this
## child's own, from their own valley, and the host has none of that name.
func _get_off_quietly() -> void:
	if player.riding == &"":
		return
	_telling_of_parking = false
	_on_ride()
	_telling_of_parking = true

var _telling_of_parking := true

## The guest's own valley stops being written to, and where they were standing
## is remembered, from the moment anything of the host's reaches this phone.
func _begin_visit() -> void:
	if _visiting:
		return
	_visiting = true
	_home_at = player.global_position
	_home_undo = build_mode.history_to_data()

## Somewhere beside the host that is dry, level and clear of anything built.
func _spot_beside(host: Vector3) -> Vector3:
	var field := world.field
	for ring: float in [2.0, 3.2, 4.5]:
		for step in 8:
			var angle := TAU * float(step) / 8.0 + 0.6
			var x := host.x + cos(angle) * ring
			var z := host.z + sin(angle) * ring
			var ground := field.height_at(x, z)
			if field.is_pond(x, z) or ground < field.water_level_at(x, z) + 0.3:
				continue
			if world.places.water_depth_at(x, z) > 0.0 or field.steepness_at(x, z) > 0.5:
				continue
			var spot := Vector3(x, ground, z)
			if not structures.is_clear(spot, 0.5):
				continue
			return world.signpost.push_clear(spot)
	# Nowhere ideal — the host is in the river or up a mountain — so where they are.
	return Vector3(host.x, maxf(host.y, field.height_at(host.x, host.z)), host.z)

func _place_beside_host() -> void:
	_get_off_quietly()
	_let_the_rides_go()
	var spot := _spot_beside(_host_at)
	player.velocity = Vector3.ZERO
	player.global_position = spot + Vector3.UP * SPAWN_CLEARANCE
	world.follow(spot)
	# As on first arrival: no physics until the ground under them exists.
	player.set_physics_process(false)
	_waiting_for_ground = true

## A child set down in somebody else's valley is not still on a ride of their
## own. The carousel, the swing, the slide and a café chair each take hold of
## the body and put it where their seat is, so a child who asked to join while
## on one was carried to the host's side and then pulled straight back to a
## saddle or a swing that is not in this valley at all.
func _let_the_rides_go() -> void:
	if _carousel_seated:
		world.park.carousel.step_off()
		_carousel_seated = false
	if world.places.swinging():
		world.places.step_off_swing()
	_sliding = -1.0
	_slid = 0.0
	_dining = 0.0
	player.is_carried = false
	if world != null and world.park != null:
		_unstrap_every_ride()
	# Whatever speed the ride was giving them stays behind with it.
	player.velocity = Vector3.ZERO
	player.strapped_in = false
	player.collision_mask = TerrainSpec.LAYER_GROUND | TerrainSpec.LAYER_PROPS

## The connection is over. A guest goes home: the world is read back from disk,
## where their own valley has been kept all along.
func _on_session_closed() -> void:
	_arriving = false
	_let_go_of_their_mounts()
	if _visiting and not _going_home:
		_going_home = true
		_come_home_note = "say_alone_again"
		_write_save()
		get_tree().reload_current_scene.call_deferred()

## Everybody's sky, set to this machine's. Sent when somebody sleeps.
func _tell_everyone_the_time() -> void:
	session.report_time_of_day(world.atmosphere.time_of_day)

## Somebody already here renamed themselves: their label changes, quietly.
func _on_guest_renamed(id: int, name: String, shirt: int) -> void:
	visitors.rename(id, name)
	visitors.relook(id, shirt, session.guest_looks.get(id, []))

func _on_guest_left(id: int, name: String) -> void:
	visitors.remove(id)
	_let_go_of_their_mounts(id)
	# Their voice goes with them, or a departed child's player sits open.
	voice.forget(id)
	hud.announce(Text.format("say_left", [name]), 3.0)

func _on_session_failed(reason: String) -> void:
	visitors.clear()
	voice.forget_everyone()
	sounds.play(Sounds.Sound.REFUSE)
	_arriving = false
	var words := Session.words_for(reason)
	if _going_home:
		_come_home_note = String(words)
	# Longer for the one that has to say two things: that the number may be
	# wrong, and that both phones must be on the same Wi-Fi.
	hud.announce(Text.of(words), 7.0 if words == &"fail_unreachable" else 4.0)

## The child and the animals within reach of a point, each as (x, feet y, z,
## radius), for the build ghost to keep clear (see BuildMode.body_finder). An
## animal is taken as the circle that holds its body.
func _bodies_near(at: Vector3, reach: float) -> Array[Vector4]:
	var found: Array[Vector4] = []
	var here := player.global_position
	if Vector2(here.x - at.x, here.z - at.z).length() <= reach + Player.RADIUS:
		found.append(Vector4(here.x, here.y, here.z, Player.RADIUS))
	for animal in world.animals.living_near(at, reach + 3.0):
		var node := animal["node"] as Node3D
		var size := AnimalKinds.body_size(animal["kind"])
		found.append(Vector4(
			node.global_position.x, node.global_position.y, node.global_position.z,
			maxf(size.x, size.z) * 0.5
		))
	return found

func _footprint_of_kind(kind: StringName) -> float:
	return HouseParts.footprint(kind) if HouseParts.is_house_part(kind) else BuildKinds.footprint(kind)

func _on_remote_built(
	kind: StringName, at: Vector3, spin: float, extent := Vector2i.ONE,
	material := HouseParts.DEFAULT_MATERIAL
) -> void:
	# Only things this version knows how to build. A brother on a newer copy of
	# the game can build something this one has never heard of, and stored
	# here it was asked about every frame by the build ghost — which then never
	# went green again for the rest of the afternoon.
	if not BuildKinds.INFO.has(kind) and not HouseParts.is_house_part(kind):
		return
	if not _the_hosts_valley_is_here():
		return
	# Both children can build on one spot in the same moment, each ghost being
	# green in its own valley. The ghost is the only check a local piece gets,
	# so this is the arriving piece's: a second piece in the same place cannot
	# be taken down by one tap.
	if not structures.is_clear(at, _footprint_of_kind(kind), kind, spin, extent):
		return
	# Nor on ground that belongs to something else here. The other child's ghost
	# judged it against their valley; a piece let in on the fairground or the
	# pitch would be walked through, and moved out piece by piece at the next load.
	if KeepOut.kept(
		at.x, at.z, world.field.camp_centre(), world.field.river_centre_x(BridgeSpec.CENTRE_Z)
	):
		return
	# Not paid for here: it came out of the other child's bag.
	structures.place(
		kind, at, spin, false, extent if kind == HouseParts.ROOF_ROOM else Vector2i.ONE,
		material if HouseParts.is_wall(kind) else HouseParts.DEFAULT_MATERIAL
	)
	# Not refused, or the two phones would stop agreeing about what stands. If
	# it landed on this child, it is the child who is set beside it.
	_step_out_of_a_remote_piece(kind, at, spin)
	if kind == BuildKinds.CAMPFIRE:
		_refresh_fires()
	_note_venues_quietly()
	# A brother's building is heard where it goes up: close by it is a knock,
	# across the valley nothing. Before this it went up in silence.
	_hear_building(Sounds.Sound.PLACE, at)

## How long after one knock from the other child's building the next is left
## unheard. A plan arrives a piece at a time, twenty or thirty in one breath,
## and a knock for each was thirty voices on one frame: a thud far louder than
## the one tap that made it, where building it here is a single sound.
const BUILDING_HEARD_EVERY := 0.25
var _building_heard := -BUILDING_HEARD_EVERY

func _hear_building(sound: Sounds.Sound, at: Vector3) -> void:
	var metres := _metres_to_spot(at)
	# A knock too far away to be heard does not use up the place: a plan going
	# up out of earshot, then one beside the child a moment later, left the
	# near one silent.
	if Sounds.falloff_db(metres) <= -79.0:
		return
	var now := Time.get_ticks_msec() * 0.001
	if now - _building_heard < BUILDING_HEARD_EVERY:
		return
	_building_heard = now
	sounds.play_at(sound, metres)

## Somebody in the other valley took something down.
##
## Only something both valleys have — see Structures.sharing. And if it was
## this child's own, built from their own bag, they get their materials back:
## a wall a brother takes down is still a wall somebody paid for.
##
## Just the piece named, never what stood on it: the other phone sends each
## piece that came down, the upper ones first, so every phone ends up agreeing.
func _on_remote_removed(at: Vector3, named := &"") -> void:
	if not _the_hosts_valley_is_here():
		return
	var record := structures.nearest_shared(at, 0.6, named)
	if record.is_empty():
		return
	var paid := bool(record.get("paid", true))
	var kind := structures.remove(record)
	if kind == BuildKinds.CAMPFIRE:
		_refresh_fires()
	_note_venues_quietly()
	if kind != &"":
		_hear_building(Sounds.Sound.REMOVE, at)
	# Not the seed of a tree that has already paid its reward: the other child
	# took it down, so no coins are asked of this one, but the seed is not
	# handed back on top of what the tree gave.
	if paid and kind != &"" and BuildKinds.grown_worth(record) <= 0:
		_give_back(record)

## The materials a piece cost, back into the bag — all of them, for a whole
## roof that covered a room.
func _give_back(record: Dictionary) -> void:
	var cost := Structures.cost_of(record)
	for item in cost:
		inventory.add(item, int(cost[item]))

func _on_remote_felled(at: Vector3) -> void:
	# A peer cannot make this phone keep stumps without end, one message each.
	if not _the_hosts_valley_is_here() or world.felled.count() >= Session.MAX_STUMPS:
		return
	world.felled.fell(at)
	world.vegetation.rebuild_around(at)

## What the other child ordered, on the table they sat at: the same plate, eaten
## in the same bites on this phone as on theirs.
func _on_remote_meal(dish: int, at: Vector3) -> void:
	if not _the_hosts_valley_is_here():
		return
	world.places.set_down(Dishes.from_index(dish), at)

func _on_remote_dam_stick(site: float) -> void:
	if not _the_hosts_valley_is_here():
		return
	world.dams.deliver(site)

## Something picked up on the other phone, by the id the valley gives it.
func _on_remote_picked(id: String) -> void:
	# Bounded as the host's list is (see Session.MAX_TAKEN): every id is kept
	# and saved, and a peer could otherwise send them for ever.
	if not _the_hosts_valley_is_here() or world.pickups.taken.size() >= Session.MAX_TAKEN:
		return
	world.pickups.taken_elsewhere(id)

## The host had that one first. Quietly: the child was given it a moment ago and
## the bag is one short again, with no message to explain a thing they would not
## understand. The thing is gone from the ground on both phones, as it was.
func _on_pick_refused(id: String) -> void:
	if not _the_hosts_valley_is_here():
		return
	var kind := world.pickups.take_back(id)
	if kind != &"":
		inventory.take_back(kind)

func _on_remote_parked(id: StringName, at: Vector3, facing: float) -> void:
	if not _the_hosts_valley_is_here():
		return
	# The host chooses where a machine is left, and says so. A guest takes the
	# host's spot as it is; the host moves a machine that was left in something
	# to clear ground and sends the spot back, so both phones have it in one
	# place (see Mounts.park_remote).
	var told_by_the_host := session.is_following()
	world.mounts.park_remote(id, at, facing, told_by_the_host)
	if told_by_the_host or not world.mounts.exists(id):
		return
	# Always said, even when the spot is the one the guest gave: the guest's own
	# word went to the host alone, so this is the only way the other guests
	# hear of it, and always the corrected spot.
	session.report_parked(id, world.mounts.position_of(id), world.mounts.facing_of(id))

## Is what this phone holds the valley the other child is building in? A host's
## always is. A guest's is not until the host's has arrived: connected, they
## are still holding their own, and a piece, a stump or a pickup applied then
## stood among their own things and was saved into their own valley.
func _the_hosts_valley_is_here() -> bool:
	return not session.is_following() or _valley_received

## How far the child is from a spot in the world, along the ground.
func _metres_to_spot(at: Vector3) -> float:
	if player == null:
		return 0.0
	var here := player.global_position
	return Vector2(here.x, here.z).distance_to(Vector2(at.x, at.z))

## How far the child is from the nearest ball, which is where a goal or a kick
## happened. Nothing to measure from means the child's own ear.
func _metres_to_play() -> float:
	var nearest := INF
	for ball_at in world.football.ball_positions():
		nearest = minf(nearest, _metres_to_spot(ball_at))
	return 0.0 if nearest == INF else nearest

## How far the child is from a dam site, for how loudly its news is heard. A
## site is only a place along the river, so the river's own x is asked for.
func _metres_to_dam(site: float) -> float:
	if player == null:
		return 0.0
	var at := player.global_position
	return Vector2(at.x, at.z).distance_to(Vector2(world.field.river_centre_x(site), site))

## Footfalls, and the splash of going into the water and out of it.
##
## Walking only: a rider hears the machine under them, and a child on a ride is
## carried, not walking. The sound follows what is underfoot — see
## Sounds.step_sound — and each foot is a little different from the last, so
## the twentieth step is not the first over again.
func _footsteps(delta: float) -> void:
	var wading := is_wading(_was_wading, player.water_depth)
	if wading != _was_wading:
		_was_wading = wading
		if player.riding == &"" and not player.is_carried:
			sounds.play(Sounds.Sound.SPLASH, 1.0 if wading else 1.25, -6.0)
	var afloat := player.is_swimming
	var walking := (
		player.riding == &"" and not player.is_carried and player.is_moving
		and (player.is_on_floor() or afloat)
	)
	if not walking:
		_stride = 0.0
		return
	_stride += Vector2(player.velocity.x, player.velocity.z).length() * delta
	if _stride < (STROKE if afloat else STRIDE):
		return
	_stride = 0.0
	_left_foot = not _left_foot
	var on := Sounds.step_sound(world.field, player.global_position, wading)
	sounds.play(
		on, (0.92 if _left_foot else 1.06) * randf_range(0.95, 1.05),
		-10.0 if on == Sounds.Sound.STEP_WOOD else -8.0
	)

func _refresh_fires() -> void:
	world.hearths.set_fires(structures.positions_of(BuildKinds.CAMPFIRE))

## How near a bed a child has to be to lie down in it, and how dark it has to be
## for sleeping to be worth anything.
const BED_REACH := 2.6
const SLEEPY_DARKNESS := 0.35

## Sleeping until morning.
##
## This is what a house is for. Everything else a child builds makes a shape;
## a bed makes somewhere to be. Night is long and dark and there is little to do
## in it — so a bed turns the worst part of the day into a reason to have built
## something, and the morning is a small reward for having done so.
func _on_sleep() -> void:
	if world.atmosphere.darkness() < SLEEPY_DARKNESS:
		sounds.play(Sounds.Sound.REFUSE, 1.2)
		hud.announce(Text.of("say_not_tired"), 2.6)
		return

	# Dawn, not noon: waking to a whole day is the point.
	world.atmosphere.set_time(0.26)
	# And everyone else wakes up with them. The sky is synced when a guest
	# arrives, but sleeping jumps this machine's clock hours forward without
	# telling anyone, which put the two children back in different halves of
	# the day — the exact bug the arrival sync was added to fix.
	_tell_everyone_the_time()
	vitals.energy = Vitals.MAX_ENERGY
	_refresh_vitals()
	sounds.play(Sounds.Sound.CHIME, 0.7)
	hud.announce(Text.of("say_slept"), 4.0)

## A log on the fire. This is what the axe was for: wood was a number in a bag
## until something burned it.
func _on_feed_fire() -> void:
	# A full fire takes no more. The log was spent before the fire was asked, so
	# a fire that refused it used to keep the wood.
	if inventory.count(ItemKinds.WOOD) <= 0 or not world.hearths.can_feed(player.global_position):
		return
	if not inventory.spend({ItemKinds.WOOD: 1}):
		return
	var left := world.hearths.feed(player.global_position)
	sounds.play(Sounds.Sound.PLACE, 0.7)
	hud.announce(Text.format("say_fire_fed", [int(left / 60.0)]), 2.4)

func _on_dam_stick() -> void:
	var site := world.dams.site_near(player.global_position)
	if is_nan(site) or inventory.count(&"stick") <= 0:
		return
	# A dam the other child has just finished takes no more sticks. Spending one
	# anyway lost it for nothing when both children brought the last one at the
	# same moment, and told the other phone about a stick nobody had used.
	if world.dams.is_built(site):
		return
	if not inventory.spend({&"stick": 1}):
		return
	if world.dams.deliver(site):
		session.report_dam_stick(site)

func _on_today_done(_kind: StringName, reward: int) -> void:
	wallet.earn(reward)
	journal.record(Journal.COINS, reward)
	sounds.play(Sounds.Sound.CHIME, 1.3)
	hud.announce(Text.format("say_today", [reward]), 4.0)
	hud.set_task(_task_line())

func _on_place_used() -> void:
	var here := _place_here(player.global_position)
	if here == &"":
		# Not at a place of the valley's: perhaps at one the child built.
		match structures.venue_at(player.global_position):
			&"cafe":
				_eat_at_home()
			&"shop":
				_sell_at_home()
		return
	match here:
		Pitch.SCOREBOARD:
			_new_game()
		Places.PLAYGROUND:
			if world.places.push_swing(player.global_position):
				# Higher-pitched the harder it is already going, so pumping
				# sounds like it is doing something.
				var effort := world.places.swing_arc() / Places.SWING_ARC
				sounds.play(Sounds.Sound.JUMP, 1.0 + 0.5 * effort)
		Places.CAFE:
			_eat()
		Places.SHOP:
			# The shop opens where the shop is. The panel existed from the day
			# it was written and nothing in the game ever opened it: a child
			# could earn coins and never spend one.
			hud.set_shop_open(not hud.is_shop_open(), wallet.coins, wallet.owned)

## Both scores to nothing and the balls back on the halfway line, said aloud.
func _new_game() -> void:
	world.football.new_game()
	sounds.play(Sounds.Sound.CHIME, 1.1)
	hud.announce(Text.of("say_new_game"), 2.0)

## A meal at the café: coins for energy. This closes the energy loop from the
## other end — animals earn coins, the café turns coins back into a full bar.
func _eat() -> void:
	# One meal at a time. The button stays lit while a child is sat at the
	# table, and every tap on it paid three coins for another tray on top of
	# the first and started the sitting again.
	if _dining > 0.0:
		return
	# Nor a meal for a child who is already full: a bar that cannot rise is
	# three coins for nothing, and the child has no way to tell.
	if vitals.energy >= Vitals.MAX_ENERGY - 0.01:
		sounds.play(Sounds.Sound.REFUSE)
		hud.announce(Text.of("say_not_hungry"), 2.0)
		return
	# What is on the menu screen's chosen picture, and only that: one held press
	# is one dish. The menu's tiles choose and never buy.
	var dish := hud.chosen_dish()
	if wallet.coins < Dishes.price(dish):
		sounds.play(Sounds.Sound.REFUSE)
		hud.announce(Text.format("say_no_coins", [Dishes.price(dish)]), 2.2)
		return
	wallet.spend(Dishes.price(dish))
	vitals.energy = Dishes.energy_after(vitals.energy, dish)
	_cooled_for = Dishes.COOL_SECONDS if Dishes.cools(dish) else _cooled_for
	_finish_eating(world.places.serve_meal(player.global_position, dish))
	_tell_of_the_meal(dish, world.places.last_tray.get("at", Vector3.ZERO))

## A meal in a cafe the child built: sat at their own table, with the price
## theirs to choose. Free gives half a meal's worth of energy; a coin gives a
## whole one, like the valley cafe's — so the choice is a real one.
func _eat_at_home() -> void:
	# One meal at a time, as at the valley's cafe.
	if _dining > 0.0:
		return
	var paying := hud.cafe_is_paid()
	var now := _play_seconds()
	var dish := hud.chosen_dish()
	match Venues.eat(vitals, wallet, paying, now >= _free_meal_after, dish):
		Venues.FULL:
			sounds.play(Sounds.Sound.REFUSE)
			hud.announce(Text.of("say_not_hungry"), 2.0)
		Venues.POOR:
			sounds.play(Sounds.Sound.REFUSE)
			hud.announce(Text.format("say_no_coins", [Venues.price_of(dish)]), 2.2)
		Venues.WAIT:
			# Said kindly, with the way round it: a coin buys a meal now.
			sounds.play(Sounds.Sound.REFUSE)
			hud.announce(
				Text.format("say_free_wait", [ceili((_free_meal_after - now) / 60.0)]), 3.0
			)
		_:
			if not paying:
				_free_meal_after = now + Venues.FREE_WAIT
			_cooled_for = Dishes.COOL_SECONDS if Dishes.cools(dish) else _cooled_for
			# Sat at a chair that has a table in front of it, with the plate on
			# that table in front of them; at a table with no chair, the child
			# eats standing and the plate goes on the nearest. The other child
			# is shown it as well.
			var seat := structures.table_seat_near(player.global_position)
			_finish_eating(seat)
			var plate := Vector3(NAN, NAN, NAN)
			if not seat.is_empty():
				plate = seat["plate"]
			else:
				var table := structures.table_near(player.global_position)
				if table.is_finite():
					plate = table + Vector3(0.0, Structures.CHAIR_PLATE_UP, 0.0)
			if plate.is_finite():
				world.places.set_down(dish, plate)
				_tell_of_the_meal(dish, plate)

## How much longer an ice cream keeps a child cooled down: energy comes back
## faster for this many seconds (see Dishes.COOL_SECONDS).
var _cooled_for := 0.0

## Say what was just put on a table, and where, to the other child's phone, so
## that they see the same plate being eaten.
func _tell_of_the_meal(dish: StringName, at: Vector3) -> void:
	session.report_meal(Dishes.index_of(dish), at)

## Whether this child has ever stood a wall, a floor, a roof and a bed in the
## valley, which is when the line that says what to build next stops being
## said: a child who has built a house once knows how, and a line that went on
## after that would be read as nagging. Saved with the child, not the world.
var _built_a_house := false

var _house_step_revision := -1
var _house_step: StringName = &""

## The step to say to a child building for the first time, or nothing. Found
## again only when something has been put up or taken down.
func _first_house_step() -> StringName:
	if _built_a_house:
		return &""
	if structures.revision != _house_step_revision:
		_house_step_revision = structures.revision
		# Only this child's own pieces: a brother's house in the valley says
		# nothing of what this child has learnt, and a host whose guest built
		# the walls and the roof was told they need not learn to.
		_house_step = structures.house_step(true)
		# Not remembered in somebody else's valley: the host's house standing
		# there says nothing of this child, and the mark is saved with them, so
		# a guest who had only looked at a house was never taught to build one.
		_built_a_house = _house_step == &"" and not _visiting
	return _house_step

## Seconds since the game began: the clock the free meal's wait is kept on.
func _play_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

## Sell what the shop buys, at a shop the child built: the same price as the
## shop in the valley, over a counter they put up themselves.
func _sell_at_home() -> void:
	var sale := Venues.sell(inventory, wallet)
	if sale.x <= 0:
		sounds.play(Sounds.Sound.REFUSE)
		# A bag with wool in it and a purse with no room is not "nothing to
		# sell": the valley's shop says the purse is full, and so does this one.
		var carrying := false
		for item: StringName in ShopStock.BUYS:
			carrying = carrying or inventory.count(item) > 0
		hud.announce(Text.of("say_purse_full" if carrying else "say_nothing_to_sell"), 2.4)
		return
	journal.record(Journal.COINS, sale.y)
	sounds.play(Sounds.Sound.CHIME, 1.2)
	hud.announce(Text.format("say_sold", [sale.x, sale.y]), 2.4)

## The cafe and the shop this child has built, so that each is announced once,
## when it first counts, and again only if it was taken down and built anew.
var _known_cafe := false

## When the next free meal at the child's own cafe is ready, in seconds since
## the game began. That clock starts again with every launch, so what is saved
## is the wait still left (see Venues.wait_left) and it is read back on loading.
## Unsaved, closing the game and opening it again was a free meal whenever one
## was wanted, which is exactly what the wait is there to prevent.
var _free_meal_after := 0.0
var _known_shop := false

func _note_new_venues() -> void:
	var cafe := structures.has_venue(&"cafe")
	var shop := structures.has_venue(&"shop")
	if cafe and not _known_cafe:
		hud.announce(Text.of("say_own_cafe"), 4.0)
	elif shop and not _known_shop:
		hud.announce(Text.of("say_own_shop"), 4.0)
	_known_cafe = cafe
	_known_shop = shop

## A cafe or a shop the other child built or took down is counted without a
## word: "your cafe is open" is said to the child who built it, and said of
## somebody else's it was a lie that sent them to a table in a valley that was
## not theirs. Counting it still matters, so that this child's own first one
## is announced once and a remote one does not swallow it.
func _note_venues_quietly() -> void:
	_known_cafe = structures.has_venue(&"cafe")
	_known_shop = structures.has_venue(&"shop")

## The structures' revision the child was last looked at against, so that a chair
## put down on them is found when it is, and not every frame.
var _chairs_seen := -1

## A child caught by a chair of their own building (put down where they stand,
## or the one they have just got up from) is set beside it. See
## Structures.chair_around.
func _step_out_of_chairs() -> void:
	if player.riding != &"":
		return
	var chair := structures.chair_around(player.global_position, Player.RADIUS)
	if chair.is_empty():
		return
	var spot := structures.chair_exit(
		chair, player.get_world_3d().direct_space_state,
		TerrainSpec.LAYER_GROUND | TerrainSpec.LAYER_PROPS, [player.get_rid()]
	)
	if spot.is_finite():
		player.global_position = spot
		player.velocity = Vector3.ZERO

## A solid piece the other child built that came down on this one's feet. The
## chairs are lifted clear by `_step_out_of_chairs`, which the new piece's
## revision sets going; everything else is stepped aside here, to the nearest
## free spot beside it (Structures.exit_beside).
func _step_out_of_a_remote_piece(kind: StringName, at: Vector3, spin: float) -> void:
	if player.riding != &"" or kind == HouseParts.CHAIR:
		return
	var feet := player.global_position
	if absf(feet.y - at.y) > HouseParts.STOREY * 0.5 or not Structures.body_overlaps(kind, at, spin, feet, Player.RADIUS):
		return
	var spot := Structures.exit_beside(
		kind, at, spin, feet, player.get_world_3d().direct_space_state,
		TerrainSpec.LAYER_GROUND | TerrainSpec.LAYER_PROPS, [player.get_rid()]
	)
	player.global_position = spot
	player.velocity = Vector3.ZERO

func _finish_eating(seat: Dictionary) -> void:
	_refresh_vitals()
	# The meal is served at the nearest seat, and the child is sat down at it
	# for a while — eating is something you sit down for.
	#
	# Not from the saddle: sitting a rider into a chair pinned them to it while
	# the machine was still carried along under them, and left the child stuck
	# in the furniture. They eat where they are, and ride on afterwards.
	if not seat.is_empty() and player.riding == &"":
		_dining = Places.MEAL_SHOWN * 0.8
		_dining_seat = seat["seat"]
		_dining_facing = float(seat["facing"])
		# Down into the chair rather than standing on it: while seated the
		# body ignores the furniture, and sits with its legs in the seat.
		player.collision_mask = TerrainSpec.LAYER_GROUND
	sounds.play(Sounds.Sound.PICKUP, 0.9)
	hud.announce(Text.of("say_ate"), 2.0)

func _on_shoot_start() -> void:
	player.start_charging()

func _on_shoot_release() -> void:
	# No draw, no arrow: the wind-up is dropped when the child steps off the
	# line or the button is hidden under a finger, and a late release then
	# loosed a weakest-pull arrow from nowhere.
	if not player.is_charging():
		return
	var charge := player.release_charge()
	world.archery.loose(
		_arrow_from(), _arrow_aim(), charge, camera_rig.aim_height()
	)
	sounds.play(Sounds.Sound.KICK, 1.4)

## Where an arrow leaves the bow, and which way.
##
## Asked by the shot and by the arc that is drawn before it, from one place,
## because the two disagreed: the arc went the way the body faced, level,
## while the shot went the way the camera looked — tilted down sixteen degrees
## at the camera's resting pitch, and then lifted again by aim_height, which is
## itself made of that same pitch. Counted twice for the arrow and not at all
## for its arc, the arrow left a sixteenth of a circle below the dots that were
## meant to show it.
##
## Level, then, along where the camera looks across the ground, with how high
## the shot goes left entirely to aim_height — the way a kick is aimed.
func _arrow_aim() -> Vector3:
	var looking := -camera_rig.camera.global_transform.basis.z
	looking.y = 0.0
	if looking.length_squared() < 0.0001:
		return player.facing()
	return looking.normalized()

func _arrow_from() -> Vector3:
	return player.global_position + Vector3.UP * 1.2

func _on_arrow_hit(index: int, ring: int, points: int) -> void:
	# The score is the ring; the coins are paid once a target has rested, so a
	# child who stands at the line and looses arrows all afternoon is practising
	# rather than printing money.
	var paid := world.archery.payout(index, points)
	wallet.earn(paid)
	journal.record(Journal.COINS, paid)
	today.record(Today.SHOOT)
	sounds.play(Sounds.Sound.GOAL if ring == 0 else Sounds.Sound.CLEARED)
	hud.announce(
		Text.format("say_gold" if ring == 0 else "say_hit", [points]), 2.0
	)

## Which side of a horse at `horse_at` the child stands on, as it faces the way
## the child does: 1 for its right, -1 for its left.
func _side_of(horse_at: Vector3) -> float:
	var turned := player.facing_angle()
	var right := Vector3(cos(turned), 0.0, -sin(turned))
	var side := (player.global_position - horse_at).dot(right)
	return -1.0 if side < 0.0 else 1.0

func _on_ride() -> void:
	if player.riding != &"":
		var got_off := world.mounts.dismount(player.global_position, player.facing_angle())
		# They slide down the side the horse is not put down on.
		if got_off != &"":
			player.board_side = _side_of(world.mounts.position_of(got_off))
		player.riding = &""
		camera_rig.set_eye_lift(0.0)
		if got_off != &"":
			sounds.play(Sounds.Sound.LAND)
		return

	var kind := world.mounts.nearest(player.global_position)
	if kind == &"":
		return
	# Not from a chair or a swing: see _carry, which would only put them down.
	if _is_being_carried():
		return
	# Nor from a saddle or a seat on a ride that is carrying them. A horse
	# parked beside the carousel was offered from the saddle: the child was
	# then on two mounts at once, held by the ride and drawn on the horse.
	if player.strapped_in:
		return

	# Refused before getting on rather than a stride afterwards.
	#
	# A machine parked on a river bank stands on ground it cannot be ridden
	# over — too steep for a bicycle, too near the water for either — and what
	# happened was: the child got on, was told they were riding it, and was
	# then put down a metre away by the rule that takes a rider off ground
	# their mount cannot take. From the phone that is the game saying "you are
	# riding the motorcycle" and throwing you off in the same breath.
	#
	# Both spots are tried, because a machine can be parked half a step from
	# ground that is perfectly rideable: the child's own, and the machine's.
	var mount_at := world.mounts.position_of(kind)
	if (
		not world.mounts.can_ride_over(kind, player.global_position)
		and not world.mounts.can_ride_over(kind, mount_at)
	):
		sounds.play(Sounds.Sound.REFUSE)
		hud.announce(
			Text.format("say_not_ridden_here", [MountKinds.label(kind)]), 2.6
		)
		return

	if MountKinds.floats(kind):
		sounds.play(Sounds.Sound.SPLASH, 0.8)
	# They climb on from the side they are standing on.
	player.board_side = _side_of(mount_at)
	if not world.mounts.mount(kind):
		return
	player.riding = kind
	camera_rig.set_eye_lift(MountKinds.eye_lift(kind))
	# A machine starts out pointing the way the child is facing.
	player.take_the_handlebars(player.facing_angle())
	sounds.play(Sounds.Sound.JUMP, 0.8)
	# A ring of the bell as the child sets off on a bicycle, because every
	# child does it the moment they are on.
	if MountKinds.kind_of(kind) == MountKinds.BICYCLE:
		ambience.bell()
	hud.announce(Text.format("say_mounted", [Text.of("mount_%s_on" % MountKinds.kind_of(kind))]), 2.0)

## Whether the axe, swung now, would fall on a tree a child planted. The same
## answer drives the button (a held press for a planted tree, a tap for a wild
## one) and the swing, so the two cannot disagree about which tree it is.
func _axe_falls_on_a_planted_tree() -> bool:
	var mine := structures.nearest_grown_tree(player.global_position, CHOP_REACH)
	if mine.is_empty():
		return false
	var answer := world.vegetation.nearest_tree_found(player.global_position, CHOP_REACH)
	return Structures.planted_is_the_one_axed(
		player.global_position, mine["position"], answer[0], bool(answer[1])
	)

func _on_chop() -> void:
	if not wallet.has(ShopStock.AXE):
		return
	# A tree the child planted themselves, first: it stands where the forest's
	# own trees do not, and an axe swung at it should fell it rather than
	# reaching past it into the wood behind. Unless a wild trunk is nearer, in
	# which case that is the tree in front of the child.
	var mine := structures.nearest_grown_tree(player.global_position, CHOP_REACH)
	if not mine.is_empty() and _axe_falls_on_a_planted_tree():
		_fell_a_planted_tree(mine)
		return

	var answer := world.vegetation.nearest_tree_found(player.global_position, CHOP_REACH)
	if not bool(answer[1]):
		return
	var tree: Vector3 = answer[0]
	world.felled.fell(tree)
	session.report_felled(tree)

	# Felling costs what growing one pays. A tree that is gone is gone whether a
	# child planted it or found it, and an axe that only ever gave would make
	# the whole valley worth cutting down.
	#
	# Floored at nothing rather than refused: a child with no coins can still
	# fell a tree for the wood, they simply have nothing to pay with. Being told
	# "you may not" by a game about a valley is worse than being told what it
	# cost.
	var toll := mini(BuildKinds.WILD_TREE_VALUE, wallet.coins)
	if toll > 0:
		wallet.spend(toll)
	# The forest is a MultiMesh generated from the seed, so the tree cannot be
	# deleted — the tiles are rebuilt against the new record instead.
	world.vegetation.rebuild_around(tree)
	inventory.add(ItemKinds.WOOD, WOOD_PER_TREE)
	sounds.play(Sounds.Sound.REMOVE, 0.7)
	hud.announce(
		Text.format("say_felled_cost", [WOOD_PER_TREE, toll]) if toll > 0
		else Text.format("say_felled", [WOOD_PER_TREE]),
		2.6
	)

## Fell a tree the child grew themselves.
##
## The wood is the same wood. What is different is the price: growing it paid a
## reward, and cutting it down gives that reward back. Otherwise a child could
## plant a sapling, wait for it to mature, fell it for the coins and the timber,
## and plant it again — which is not a valley, it is a machine for making money
## out of nothing, and a ten-year-old finds that in an afternoon.
##
## The seed is not returned. The tree was grown; what is taken down is a tree,
## not a misplaced piece of building.
func _fell_a_planted_tree(record: Dictionary) -> void:
	var kind: StringName = record["kind"]
	var at: Vector3 = record["position"]
	var reward := BuildKinds.reward_for(kind)
	var shared := bool(record.get("shared", false))
	structures.remove(record)

	# Floored at what there is, like the toll on a wild tree: being told "you
	# may not" by a game about a valley is worse than being told what it cost.
	# And nothing for a tree adopted from the host's valley: its reward went into
	# the host's purse, not this child's.
	var toll := mini(reward, wallet.coins) if bool(record.get("paid", true)) else 0
	if toll > 0:
		wallet.spend(toll)
	inventory.add(ItemKinds.WOOD, WOOD_PER_TREE)
	# A stump stays where it stood, the same as a wild tree's: something was
	# here, and the ground should say so.
	world.felled.fell(at)
	# A planted tree is a structure, and taking one down has to say so. Sending
	# report_felled alone told the other machine to fell a *wild* tree here: the
	# pine a child had planted went on standing in their brother's valley, and a
	# forest tree near it disappeared instead.
	#
	# And only if the other valley has this tree at all. A stump sent for a
	# tree that was never over there felled whatever forest tree grew nearest
	# the spot instead.
	if shared:
		session.report_removed(at, kind)
		session.report_felled(at)
	world.vegetation.rebuild_around(at)
	sounds.play(Sounds.Sound.REMOVE, 0.7)
	hud.announce(
		Text.format("say_felled_own", [WOOD_PER_TREE, toll]) if toll > 0
		else Text.format("say_felled", [WOOD_PER_TREE]),
		2.8
	)

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

## The head of the animal nearest a place, within a child's reach of it, or
## null: what another child reaching out is reaching to.
func _animal_head_near(at: Vector3) -> Node3D:
	var best: Node3D = null
	var best_distance := Animals.REACH
	for animal in world.animals.living_near(at, Animals.REACH):
		var node := animal["node"] as Node3D
		var distance := node.global_position.distance_to(at)
		if distance <= best_distance:
			var head := node.get_node_or_null("Head") as Node3D
			if head != null:
				best_distance = distance
				best = head
	return best

## How far a beaver carries a stick towards its dam before it sets it down.
const BEAVER_ERRAND := 25.0

## The child reaches out to an animal they are caring for and the animal
## answers: the one place that does both, whatever the care was (food, water,
## wool, milk or a stroke), so the two never disagree about whether it happened.
func _tend(animal: Dictionary) -> void:
	var node = animal.get("node")
	if node == null or not is_instance_valid(node):
		return
	var kind: StringName = animal["kind"]
	# Stroked, and not held out to, when nothing is handed over: a pat, the
	# shears, the milking.
	var strokes := AnimalKinds.want(kind) == &"" or AnimalKinds.gives(kind) != &""
	var head := (node as Node3D).get_node_or_null("Head") as Node3D
	if head != null:
		player.tend(head, strokes)
	var errand := Vector3.INF
	if kind == AnimalKinds.BEAVER:
		# The stick goes to the dam: part of the way, along the bank.
		var site := DamSpec.nearest_site((node as Node3D).position.z, 60.0)
		if not is_nan(site):
			var dam := Vector3(world.field.river_centre_x(site), 0.0, site)
			var way := dam - (node as Node3D).position
			way.y = 0.0
			errand = (node as Node3D).position + way.limit_length(BEAVER_ERRAND)
	world.animals.answer(animal, player.global_position, errand)

func _on_care() -> void:
	var animal := world.animals.nearest_caring(player.global_position, inventory)
	if animal.is_empty():
		return
	# A thirsty animal takes water rather than food. This is the bottle's second
	# use and the reason it is the cheapest thing in the shop.
	if world.animals.is_thirsty(animal) and vitals.has_bottle and vitals.water >= Vitals.DRINK:
		if vitals.pour():
			var reward := world.animals.water_for(animal)
			_tend(animal)
			wallet.earn(reward)
			journal.record(Journal.CARED)
			journal.record(Journal.COINS, reward)
			today.record(Today.CARE)
			sounds.play(Sounds.Sound.SPLASH)
			hud.announce(Text.format("say_watered", [AnimalKinds.label(animal["kind"])]), 2.0)
			_refresh_vitals()
			return

	var coins := world.animals.care_for(animal, inventory)
	# Livestock hands over a thing rather than coins: wool into the bag, milk
	# drunk where it stands.
	var gift := world.animals.last_gift
	if gift != &"":
		world.animals.last_gift = &""
		_tend(animal)
		if gift == ItemKinds.WOOL:
			inventory.add(ItemKinds.WOOL, WOOL_PER_SHEEP)
			sounds.play(Sounds.Sound.PICKUP, 1.1)
			hud.announce(Text.format("say_sheared", [WOOL_PER_SHEEP]), 2.0)
		else:
			vitals.energy = minf(
				Vitals.MAX_ENERGY, vitals.energy + Vitals.MAX_ENERGY * MILK_RESTORE
			)
			_refresh_vitals()
			sounds.play(Sounds.Sound.SPLASH, 1.3)
			hud.announce(Text.of("say_milk"), 2.0)
			# And she says so, once. A cow that is milked in silence and then
			# goes on mooing to herself on the ambient timer has the sound and
			# the moment the wrong way round.
			var milked = animal.get("node")
			if milked != null and is_instance_valid(milked):
				animal_voices.speak(
					animal["kind"], (milked as Node3D).global_position, 0.96
				)
		journal.record(Journal.CARED)
		today.record(Today.CARE)
		return
	if coins <= 0:
		return
	_tend(animal)
	# The one voice that is never automatic: a cat purrs because it is being
	# stroked, which is the whole reason a cat purrs.
	var node = animal.get("node")
	if node != null and is_instance_valid(node):
		animal_voices.speak(animal["kind"], (node as Node3D).global_position, 1.0)

	wallet.earn(coins)
	journal.record(Journal.CARED)
	today.record(Today.CARE)
	journal.record(Journal.COINS, coins)
	sounds.play(Sounds.Sound.CHIME, 1.15)
	hud.announce(Text.format("say_fed", [coins]), 1.4)

func _on_shop() -> void:
	hud.set_shop_open(not hud.is_shop_open(), wallet.coins, wallet.owned)

## How long a child on foot pushes the stick without getting anywhere before the
## ground round them is looked at, how far counts as getting somewhere, and how
## long to leave it before looking again.
const POCKET_WAIT := 4.0
const POCKET_PROGRESS := 1.0

var _pocket_anchor := Vector3.ZERO
var _pocket_wait := 0.0

## A child shut in a hollow of the mountain, whose walls are all too steep to
## climb, has nowhere to go and no way home. Pushing the stick for a few seconds
## without moving is what asks; the ground is then read from the height field,
## and only a closed pocket moves anybody — a child leaning on a tree is not
## lifted out of anything. See RespawnSpot.way_out_of_a_pocket.
func _lift_out_of_a_pocket(delta: float) -> void:
	var here := player.global_position
	var pushing := Input.get_vector(
		InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT,
		InputActions.MOVE_FORWARD, InputActions.MOVE_BACK
	).length() > 0.5
	if (
		not pushing or not player.is_on_floor() or player.riding != &""
		or player.is_carried or player.strapped_in or _aboard != &""
		or Vector2(here.x - _pocket_anchor.x, here.z - _pocket_anchor.z).length() > POCKET_PROGRESS
	):
		_pocket_anchor = here
		_pocket_wait = 0.0
		return
	_pocket_wait += delta
	if _pocket_wait < POCKET_WAIT:
		return
	_pocket_wait = 0.0
	var out := RespawnSpot.way_out_of_a_pocket(world.field, here, world.field.find_spawn_point())
	if not out.is_finite():
		return
	out = RespawnSpot.choose(
		world.field, structures, world.places, world.park, world.signpost, out,
		world.field.find_spawn_point()
	)
	player.velocity = Vector3.ZERO
	world.terrain.ensure_ground_at(out)
	player.global_position = out + Vector3.UP * SPAWN_CLEARANCE
	_pocket_anchor = player.global_position
	hud.announce(Text.of("say_caught"), 2.4)

## Put somebody who has fallen out of the world back on top of it.
func _catch_a_fall(at: Vector3) -> void:
	# A position that is not a number is not above any ground: every comparison
	# below is false for it, so it would be "caught" and put back at the same
	# nothing. The last dry ground is somewhere real.
	if not at.is_finite():
		player.velocity = Vector3.ZERO
		player.global_position = _last_on_ground + Vector3.UP * SPAWN_CLEARANCE
		hud.announce(Text.of("say_caught"), 2.4)
		return
	var ground := world.field.height_at(at.x, at.z)
	if at.y > ground - Player.CAUGHT_BELOW:
		return
	player.velocity = Vector3.ZERO
	# The ground they are put back on has to be solid, or they fall again at once
	# and are caught again, every frame. A child can only be here because their
	# chunk had no collision, so that chunk is made solid before they land on it.
	world.terrain.ensure_ground_at(Vector3(at.x, ground, at.z))
	player.global_position = Vector3(at.x, ground + 0.5, at.z)
	# Told, not silently mended: a child who has just watched the world vanish
	# deserves to know they are back rather than wondering what happened.
	hud.announce(Text.of("say_caught"), 2.4)

## How long a mount may stand on ground it cannot take before its rider is put
## down. Long enough that crossing a lip is not an ejection, short enough that
## nobody rides up a cliff.
const STUCK_GROUND := 0.45
## The most one frame can add to that count, however long the frame was.
const MAX_STUCK_STEP := 0.1
## Shorter than this in the background and the saplings are left as they were.
const MIN_AWAY_FOR_GROWTH := 30.0
## Whether the camera was under the surface last frame, so crossing it is heard.
var _eye_was_under := false

## How far the child has walked since their last footfall, whether they were in
## the water a moment ago, and which foot it was.
var _stride := 0.0
var _was_wading := false
var _left_foot := false

## How far apart footfalls are, in metres, walking; a swimmer's strokes are
## further apart. Running covers more ground a second, so steps come faster
## without a second rule for it.
const STRIDE := 1.5
const STROKE := 2.4
const WADING := 0.15
## How much shallower than WADING the water has to get before a child counts as
## out of it. One threshold made the splash fire on every step along a shelf
## whose depth wavers either side of it, and again at each bob of a swimmer's
## head at the surface.
const WADING_HYSTERESIS := 0.07
const EYE_UNDER_ENTERS := 0.6
const EYE_UNDER_LEAVES := 0.4

## Whether feet in water this deep are wading, given whether they were a moment
## ago. Static so the checks can walk a depth up and down it.
static func is_wading(was: bool, depth: float) -> bool:
	return depth > (WADING - WADING_HYSTERESIS if was else WADING)

## The same for the eye crossing the surface, on the eased amount.
static func eye_is_under(was: bool, under: float) -> bool:
	return under > (EYE_UNDER_LEAVES if was else EYE_UNDER_ENTERS)
var _bad_ground := 0.0
var _held_last := Player.NOT_HELD
var _held_rate := 0.0

## The first row of a machine's stand at the shop with nothing standing on it.
func _free_row(offset: Vector3) -> int:
	return world.mounts.free_row(_outside_the_shop(Vector3.ZERO) + offset, Places.STANDS_ROW)

func _outside_the_shop(offset: Vector3) -> Vector3:
	var spot := world.places.position_of(Places.SHOP)
	if spot == Vector3.ZERO:
		# No shop in this world yet: fall back to where the child wakes up,
		# which is at least somewhere they will walk past.
		return world.field.find_spawn_point() + offset
	return spot + offset

## Move the camera between over the shoulder and behind the eyes.
func _on_view_toggled() -> void:
	_first_person = not _first_person
	camera_rig.set_first_person(_first_person)
	hud.set_first_person(_first_person)
	sounds.play(Sounds.Sound.PICKUP, 1.4)
	_write_save()

## Which way round the camera is sitting, remembered between days.
var _first_person := false

## Which shirt this child picked, as an index into Visitors.SHIRTS, or -1 for
## a child who has not been asked yet.
var _shirt := -1

## Who this child is drawn as: [character, skin, hair] (see Character), and
## whether the panel that offers the choice has been put in front of them yet.
var _look: Array = [Character.SIMPLE, 0, 0]
var _look_offered := true

## Sell something back to the shop, for half what it cost.
##
## The machine goes with it: a bicycle sold is a bicycle gone from the valley,
## and the one that disappears is the one standing at the shop door if there is
## one there — otherwise the furthest away, because that is the one a child has
## decided they are not walking back for.
func _on_sell_back(item: StringName) -> void:
	if not wallet.has(item):
		return
	# A machine is sold out of the valley standing on this phone, and a guest's
	# phone holds the host's valley, not their own. The coins were paid and the
	# host's machine (or none) went; the child's own stayed in the world file,
	# which is not written while visiting, so it came back at home, sold and
	# kept. It is sold at home, where it stands.
	if _visiting and _is_a_machine(item):
		sounds.play(Sounds.Sound.REFUSE)
		hud.announce(Text.of("say_sell_at_home"), 3.0)
		return
	# A full purse refuses before anything is touched. The child used to be put
	# down off their machine first and only then told the purse was too full,
	# so a refused sale still cost them their ride.
	if ShopStock.sells_back(item) > wallet.room():
		sounds.play(Sounds.Sound.REFUSE)
		hud.announce(Text.of("say_purse_full"), 2.6)
		return
	# Selling the last of a machine while sitting on it gets the child off
	# first. Mounts will never sell the one being ridden, and without this the
	# coins were paid and the machine stayed — or, before that rule, vanished
	# from under them while they went on riding nothing.
	for machine: Array in [
		[ShopStock.BICYCLE, MountKinds.BICYCLE],
		[ShopStock.MOTORCYCLE, MountKinds.MOTORCYCLE],
		[ShopStock.QUAD, MountKinds.QUAD],
	]:
		if (
			item == machine[0] and player.riding != &""
			and MountKinds.kind_of(player.riding) == machine[1]
			and world.mounts.count_of_kind(machine[1]) <= 1
		):
			_on_ride()
	# A machine that is all being ridden (by a visitor, say) cannot be taken
	# away, so it is not paid for either. One that is nowhere in the valley is
	# sold regardless: it is the purse that is wrong then, and selling mends it.
	if _is_a_machine(item) and not _machine_can_go(item):
		sounds.play(Sounds.Sound.REFUSE)
		hud.announce(Text.of("say_machine_in_use"), 3.0)
		return
	var paid := wallet.sell_back(item, ShopStock.sells_back(item))
	if paid <= 0:
		sounds.play(Sounds.Sound.REFUSE)
		hud.announce(Text.of("say_purse_full"), 2.6)
		return
	if item == ShopStock.LANTERN and not wallet.has(ShopStock.LANTERN):
		lantern.owned = false
	if item == ShopStock.BOTTLE and not wallet.has(ShopStock.BOTTLE):
		vitals.take_bottle()
	for machine: Array in [
		[ShopStock.BICYCLE, MountKinds.BICYCLE],
		[ShopStock.MOTORCYCLE, MountKinds.MOTORCYCLE],
		[ShopStock.QUAD, MountKinds.QUAD],
	]:
		if item == machine[0]:
			world.mounts.sell_one(machine[1], player.global_position)
	sounds.play(Sounds.Sound.CHIME, 1.2)
	hud.announce(Text.format("say_sold_back", [ShopStock.label(item), paid]), 2.6)
	hud.set_owned(wallet.owned)
	hud.set_shop_open(true, wallet.coins, wallet.owned)

## Whether the shop could take one of this machine away: there is one not being
## ridden, or none standing at all.
func _machine_can_go(item: StringName) -> bool:
	var kind := MountKinds.BICYCLE
	if item == ShopStock.MOTORCYCLE:
		kind = MountKinds.MOTORCYCLE
	elif item == ShopStock.QUAD:
		kind = MountKinds.QUAD
	return world.mounts.count_of_kind(kind) == 0 or world.mounts.can_sell_one(kind)

## Whether the shop's thing is one of the machines left standing in the valley.
func _is_a_machine(item: StringName) -> bool:
	return item == ShopStock.BICYCLE or item == ShopStock.MOTORCYCLE or item == ShopStock.QUAD

func _on_buy(item: StringName) -> void:
	# Selling: the shop buys wool, and nothing else. Handled here rather than
	# in the shop panel because the coins and the bag both live on this side.
	if ShopStock.pays_for(item) > 0:
		var carried := inventory.count(item)
		if carried <= 0:
			sounds.play(Sounds.Sound.REFUSE)
			return
		# Only what the purse has room to be paid for: coins stop at the
		# ceiling, and wool sold past it was handed over for nothing.
		carried = mini(carried, wallet.room() / ShopStock.pays_for(item))
		if carried <= 0:
			sounds.play(Sounds.Sound.REFUSE)
			hud.announce(Text.of("say_purse_full"), 2.6)
			return
		if not inventory.spend({item: carried}):
			return
		var paid := carried * ShopStock.pays_for(item)
		wallet.earn(paid)
		journal.record(Journal.COINS, paid)
		sounds.play(Sounds.Sound.CHIME, 1.2)
		hud.announce(Text.format("say_sold", [carried, paid]), 2.4)
		hud.set_shop_open(true, wallet.coins, wallet.owned)
		return
	# A bar of chocolate is used up rather than owned, so it goes through the
	# purse rather than the ledger: buy as many as you like, one at a time.
	if ShopStock.is_consumable(item):
		if not wallet.spend(ShopStock.price(item)):
			sounds.play(Sounds.Sound.REFUSE)
			hud.announce(Text.format("say_no_coins", [ShopStock.price(item)]), 2.2)
			return
		inventory.add(item, 1)
		sounds.play(Sounds.Sound.PICKUP, 1.2)
		# Said, like every other purchase: the bar goes into the bag, which is
		# off to one side, and a child holding the button for a second wants to
		# hear that it worked.
		hud.announce(Text.format("say_bought", [ShopStock.label(item)]), 2.0)
		hud.set_shop_open(true, wallet.coins, wallet.owned)
		return
	# Nor a machine in somebody else's valley. It would be stood outside the
	# host's shop and the coins taken, but the guest's own world file is not
	# written while visiting: at home the purse would say a bicycle was owned
	# and no bicycle stood anywhere — and the shop would count it against the
	# limit. The mirror of the refusal to sell one there.
	if _visiting and _is_a_machine(item):
		sounds.play(Sounds.Sound.REFUSE)
		hud.announce(Text.of("say_buy_at_home"), 3.0)
		hud.set_shop_open(true, wallet.coins, wallet.owned)
		return
	# Not without end. Things are objects here and a second one is a fair
	# purchase, but three of anything is a spare and a spare for the spare —
	# and a machine left at the far side of the valley is still yours, so it
	# counts. Otherwise a child buys a new bicycle rather than walking back
	# for the one they left, and the valley fills with bicycles.
	if wallet.count_of(item) >= ShopStock.limit(item):
		sounds.play(Sounds.Sound.REFUSE)
		hud.announce(
			Text.format("say_enough_of_those", [ShopStock.limit(item)]), 3.0
		)
		hud.set_shop_open(true, wallet.coins, wallet.owned)
		return
	if wallet.buy(item, ShopStock.price(item)):
		if item == ShopStock.BOTTLE:
			vitals.grant_bottle()
			_refresh_vitals()
		if item == ShopStock.LANTERN:
			lantern.owned = true
		# A machine is left outside, so it has to say so: a child who buys a
		# bicycle at a counter looks around the room for it. A second one
		# stands beside the first:
		# each is its own thing in the world, named the way the boats and the
		# horses are, so two bicycles are two bicycles rather than one flag.
		for machine: Array in [
			[ShopStock.MOTORCYCLE, MountKinds.MOTORCYCLE, Places.MOTORCYCLE_STANDS_AT],
			[ShopStock.BICYCLE, MountKinds.BICYCLE, Places.BICYCLE_STANDS_AT],
			[ShopStock.QUAD, MountKinds.QUAD, Places.QUAD_STANDS_AT],
		]:
			if item != machine[0]:
				continue
			# At the shop door, not underfoot: a machine that appears wherever
			# you happen to stand feels like a cheat rather than something you
			# own.
			world.mounts.place(
				world.mounts.free_id(machine[1]),
				_outside_the_shop(Places.machine_stand(
					machine[2], _free_row(machine[2])
				))
			)
			hud.announce(
				Text.format("say_waiting_outside", [MountKinds.label(machine[1])]), 4.0
			)
		hud.set_owned(wallet.owned)
		sounds.play(Sounds.Sound.GOAL)
		hud.announce(Text.format("say_bought", [ShopStock.label(item)]), 3.0)
	else:
		sounds.play(Sounds.Sound.REFUSE)
		hud.announce(Text.of("say_too_dear"), 2.0)
	hud.set_shop_open(true, wallet.coins, wallet.owned)

func _on_jump() -> void:
	player.request_jump()

## Go under, or come back up. A toggle rather than a button held down: both of
## a child's thumbs are already busy in the water — one on the stick, one
## turning the view — and neither is free to be held on a third control.
func _on_dive() -> void:
	player.diving = not player.diving

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
	_take_down(record)

## Take back the last thing this child put up, wherever they are standing now.
##
## A tap takes down the piece nearest the child, which after a wall went on the
## wrong edge is as likely to be the floor under their feet. Undo is the piece
## they meant: the last one, refunded exactly the same way.
func _on_undo() -> void:
	# One tap of a plan is one tap of undo: every piece that went up with it.
	var group := build_mode.take_last_group()
	if group.is_empty():
		hud.announce(Text.of("say_nothing_to_undo"))
		return
	# Last piece first, so a roof comes down before the walls under it and a
	# bed before its floor — what stood on a piece is never left in the air.
	group.reverse()
	for record in group:
		_take_down(record)

## Take a piece down, and with it whatever stands on it: the wall a storey up,
## the roof the walls held, the bed and the table on a floor. Every one is
## refunded in full and told to the other phone as a piece of its own, the
## upper ones first, so both valleys end up with the same standing.
##
## Taken down together rather than refused. A child who taps minus on the wall
## under a roof wants that wall gone, and being told to take the roof down first
## is a chore they cannot be asked to do; with a full refund, nothing is lost
## that building again does not give back.
func _take_down(record: Dictionary) -> void:
	var above := structures.standing_on(record)
	for upper in above:
		_take_down_piece(upper)
	_take_down_piece(record)
	if not above.is_empty():
		hud.announce(Text.of("say_took_stack"), 2.6)

## Take one piece down: off the other phone too if it is there, and back into
## the bag of whoever paid for it.
func _take_down_piece(record: Dictionary) -> void:
	var at: Vector3 = record["position"]
	var shared := bool(record.get("shared", false))
	var paid := bool(record.get("paid", true))
	var kind := structures.remove(record)
	if kind == BuildKinds.CAMPFIRE:
		# A fire whose campfire has been taken down cannot go on burning.
		_refresh_fires()
	_note_new_venues()
	if kind == &"":
		return
	# Putting something up crossed the network and taking it down did not:
	# Session.report_removed() was written, and the other machine's handler for
	# it was wired up, but nothing ever called it. A wall a child took down
	# stayed standing in their brother's valley, solid enough to walk into.
	#
	# Only for something the other valley has. A piece from before the game
	# together does not exist over there, and naming its place to the other
	# phone is how a wall over there that merely stood in the same spot used to
	# be taken down instead.
	if shared:
		session.report_removed(at, kind)
	sounds.play(Sounds.Sound.REMOVE)
	# Back to whoever paid for it. A piece the brother built came out of his
	# bag; taking it down here hands nothing to this child, or every wall built
	# together could be taken down twice and paid for twice.
	#
	# A tree that had finished growing has already paid its reward, so taking it
	# down pays that back first — the way the axe does — and the seed only comes
	# home if all of it could be. Otherwise planting, waiting and taking down
	# again was coins from nothing.
	var before := wallet.coins
	#
	# Only a tree this child's own purse was paid for. One adopted from the
	# host's valley paid its reward into the host's purse, so a guest taking it
	# down was being charged coins they had never been given.
	var repaid := wallet.repay(BuildKinds.grown_worth(record) if paid else 0)
	if paid and repaid:
		_give_back(record)
	if before > wallet.coins:
		hud.announce(Text.format("say_took_tree", [before - wallet.coins]), 2.2)
		return
	hud.announce(Text.format("say_took_back", [
		HouseParts.label(kind) if HouseParts.is_house_part(kind) else BuildKinds.label(kind)
	]), 1.6)

func _on_kick_start() -> void:
	if _ball_near() != null:
		player.start_charging()

## The ball at the child's feet, whichever game it belongs to: the footballs
## on the pitch or the basketballs at the playground. One kick serves both.
func _ball_near() -> Ball:
	# Not from the saddle. A rider does not dribble (see the frame loop), and a
	# kick from a bicycle seat swung a leg the pose does not have and sent the
	# ball off from wherever the machine happened to be passing.
	if player.riding != &"":
		return null
	var ball := world.football.ball_near(player.global_position)
	if ball == null:
		ball = world.places.ball_near(player.global_position)
	return ball

func _on_kick_release() -> void:
	var strength := player.release_charge()
	hud.set_kick_preview(false, 0.0, 0.0)
	var ball := _ball_near()
	if ball == null:
		return
	# The foot is at the top of its swing in this very frame, the one in which
	# the ball leaves it.
	player.swing_kick()
	# A ball in the net is left for the cheer: no kick sound for a kick that
	# moves nothing.
	if world.football.has_ball(ball) and world.football.in_the_net(ball):
		return
	if _can_throw(ball):
		# At the playground a basketball near the hoop is thrown at the ring,
		# not kicked along the ground — the ring is what it is for. Holding
		# the button steadies the aim; a tap still mostly goes in.
		sounds.play(Sounds.Sound.KICK, 1.15)
		ball.throw_to(world.places.ring_position(), strength)
		return
	# A tap is a nudge and a hold is a shot, but even the very shortest tap has
	# to move the ball, or a child taps and concludes the button is broken.
	sounds.play(Sounds.Sound.KICK, 0.85 + strength * 0.4)
	# A pitch ball goes through the football ground, which on a guest's phone
	# asks the host to kick it; a ball anywhere else is simply kicked.
	if world.football.has_ball(ball):
		world.football.kick(
			ball, player.global_position, player.facing(), player.is_sprinting(),
			maxf(strength, Ball.TAP_STRENGTH), _kick_loft(), Vector3.ZERO, _kick_turn(), player.velocity
		)
		return
	ball.kick(
		player.global_position,
		player.facing(),
		player.is_sprinting(),
		maxf(strength, Ball.TAP_STRENGTH),
		_kick_loft(),
		Vector3.ZERO,
		_kick_turn(),
		player.velocity
	)

## How high the finger has slid the shot, 0 (along the ground) to 1 (a high
## chip), and how far it has turned it, in radians with right positive. Both are
## zero for a tap, so a tap kicks the way the child faces, along the ground.
## One place for the kick and for its preview, so the dots cannot show a
## different shot from the one the ball takes.
func _kick_loft() -> float:
	return hud.kick_aim().y

func _kick_turn() -> float:
	return hud.kick_aim().x

## Where the camera looks along the ground. A child standing at a ball turns to
## face it (see _face_the_view_at_the_ball), which is what makes the way they
## face, and so the way a kick goes, the way they are looking.
func _kick_look() -> Vector3:
	return Vector3(-sin(camera_rig.yaw), 0.0, -cos(camera_rig.yaw))

## A dotted line from the ball to where a kick would send it: shown whenever a ball is at the child's feet, for a tap, and
## following the hold while the button is down. The same arithmetic the kick and
## the throw use, so it is not a guess. Which way a kick went and how far was the
## question asked most from the phone; this answers it before the foot moves, and
## a child turns to aim by looking at it.
func _show_where_it_goes(ball: Ball) -> void:
	var velocity: Vector3
	if _can_throw(ball):
		velocity = ball.throw_velocity(world.places.ring_position())
	else:
		velocity = _kick_launch(ball, player.kick_charge)
	var ground := func(x: float, z: float) -> float:
		return world.field.height_at(x, z)
	var path := Ball.aim_path(ball.position, velocity, ball.effective_linear_damp(), ball.gravity_strength(), ground)
	# Green when the shot is going into a goal mouth. The ball's own start is
	# put in front of the dots, so a shot that crosses the line within its first
	# step is not missed.
	var flight := PackedVector3Array([ball.position])
	flight.append_array(path)
	var on_target := Pitch.goal_ahead(flight, Ball.RADIUS, ground) >= 0 and ball.look == Ball.Look.FOOTBALL
	kick_preview.show_path(path, on_target)

## The velocity a kick of `strength` would give `ball` this very moment: the one
## sum the aim indicator draws from and the real kick is made with, because both
## ask Ball.launch_velocity the same question of the same child — where they
## stand and face, whether they are sprinting, and how far the finger has slid
## the shot sideways and up.
func _kick_launch(ball: Ball, strength: float) -> Vector3:
	return Ball.launch_velocity(
		ball.position, player.global_position, player.facing(), player.is_sprinting(),
		maxf(strength, Ball.TAP_STRENGTH), _kick_loft(), Vector3.ZERO, _kick_turn(), player.velocity
	)

var _preview_resting := true

func _resting_preview_on(velocity: Vector3) -> bool:
	_preview_resting = KickPreview.shown_at_pace(Vector2(velocity.x, velocity.z).length(), _preview_resting)
	return _preview_resting

## Standing still with a ball at the feet, the child turns to face where the
## camera looks, so the dotted line, which starts from the way they face, points
## where they are looking. Facing was otherwise wherever they last walked, which
## has nothing to do with the view once they stop and swing the camera round — the
## "random left or right" of the line. Not while the button is held: the aim
## is then the finger's, and the child must not swivel under it.
## Below this pace, in metres a second, a child counts as standing still.
const STANDING_SPEED := 0.3

func _face_the_view_at_the_ball(ball: Ball, delta: float) -> void:
	if ball == null or player.is_charging() or player.riding != &"":
		return
	if Vector2(player.velocity.x, player.velocity.z).length() > STANDING_SPEED:
		return
	player.face(_kick_look(), delta)

## The tick or the cross under a question. Everything that spends a child's
## coins comes through here.
func _on_answered(yes: bool) -> void:
	var asked := _asked
	_asked = &""
	if not yes:
		sounds.play(Sounds.Sound.REFUSE, 0.9)
		if asked == &"ride":
			# Said no to the ride: it turns under them and does not carry them,
			# and it does not ask again until they step off and back on.
			_coaster_told = true
		return
	match asked:
		&"buy":
			if wallet.buy_ticket(Park.RIDE_PRICE):
				sounds.play(Sounds.Sound.PICKUP, 1.2)
				hud.announce(Text.format("say_park_bought", [wallet.tickets]), 2.0)
		&"ride":
			# A ticket if there is one, bought with coins if there is not:
			# the question said which it was asking.
			var paid := wallet.use_ticket()
			if not paid and wallet.buy_ticket(Park.RIDE_PRICE):
				paid = wallet.use_ticket()
			if not paid:
				sounds.play(Sounds.Sound.REFUSE)
				hud.announce(Text.format("say_no_coins", [Park.RIDE_PRICE]), 2.2)
				return
			sounds.play(Sounds.Sound.CHIME, 1.1)
			_riding_without_a_ticket = false
			match _asked_ride:
				&"coaster":
					_coaster_paid = true
					world.park.coaster.book()
					hud.announce(Text.of("say_coaster_booked"), 2.4)
				&"carousel":
					# Seated on the nearest animal by the physics tick, which
					# takes it from here (see _physics_process).
					_carousel_paid = true
					hud.announce(Text.format("say_park_used_ticket", [wallet.tickets]), 2.0)
				&"wheel":
					_wheel_rider_paid = true
					_wheel_boarded = false
					_wheel_went_round = false
					world.park.wheel.book()
					hud.announce(Text.of("say_wheel_called"), 2.2)
				_:
					if _asked_ride == &"drop_tower" or _asked_ride == &"pirate_ship":
						_ride_waiting_paid = _asked_ride
					hud.announce(Text.format("say_park_used_ticket", [wallet.tickets]), 2.0)

## The pool's turnstile: a child outside is offered a ticket and told the
## price once; a child inside is simply let out.
var _ticket_told := false

func _watch_the_turnstile() -> void:
	var at := player.global_position
	var near := world.places.at_turnstile(at)
	var inside := world.places.inside_pool_fence(at)
	if inside and world.places.at_turnstile(at, Places.TURNSTILE_EXIT_REACH) and not world.places.turnstile_open():
		world.places.open_turnstile(false)
	world.places.the_child_is_at(at)
	# The fairground's kiosk offers the same button. One control for "pay to
	# get on something", wherever a child is standing.
	var at_booth := world.park.at_the_booth(at)
	# And so do the two rides that are booked at their own platforms. The
	# button on a platform was pressed by walking up to it, which is fine for
	# a bell and wrong for a purchase: standing at the big wheel there was
	# nothing on screen saying a ride could be bought, because the one control
	# that says that lives here.
	var at_ride := world.park.wheel.at_the_button(at) or world.park.coaster.at_the_button(at)
	var offer := (
		(near and not inside and not world.places.turnstile_open())
		or at_booth or at_ride
	)
	hud.set_ticket_offer(offer)
	if offer and not _ticket_told:
		_ticket_told = true
		if at_booth or at_ride:
			hud.announce(Text.format("say_park_ticket", [Park.RIDE_PRICE]), 2.6)
		else:
			hud.announce(Text.format("say_ticket", [Places.POOL_TICKET]), 2.6)
	elif not near and not at_booth and not at_ride:
		_ticket_told = false

## Turn the lantern on or off. It lights itself at dusk; this is how a child
## puts it out, which is most of what makes carrying one feel like carrying
## something.
func _on_lantern() -> void:
	if not lantern.owned:
		return
	var on := lantern.flick()
	sounds.play(Sounds.Sound.CHIME, 1.5 if on else 0.9)
	hud.announce(Text.of("say_lantern_on" if on else "say_lantern_off"), 1.6)
	hud.set_lantern(true, on)

## Eat a bar of chocolate. The one thing in the bag that is used up by using
## it, and the only way to get energy back without walking to the café.
func _on_snack() -> void:
	if inventory.count(ItemKinds.CHOCOLATE) <= 0:
		return
	# Not for a child who is already full, as at the cafe: the bar cannot rise,
	# and a coin's worth of chocolate would be gone for nothing.
	if vitals.energy >= Vitals.MAX_ENERGY - 0.01:
		sounds.play(Sounds.Sound.REFUSE)
		hud.announce(Text.of("say_not_hungry"), 2.0)
		return
	if not inventory.spend({ItemKinds.CHOCOLATE: 1}):
		return
	vitals.energy = minf(
		Vitals.MAX_ENERGY,
		vitals.energy + Vitals.MAX_ENERGY * ShopStock.CHOCOLATE_RESTORE
	)
	_refresh_vitals()
	sounds.play(Sounds.Sound.PICKUP, 1.35)
	hud.announce(Text.of("say_chocolate"), 1.8)

## Pay for the pool. Coins come from the animals, so a swim is earned.
func _on_ticket() -> void:
	# On a ride's own platform it buys that ride, and books it: the button on
	# the boards turns green and the next gondola — or the next train — pulls
	# up for ten seconds.
	if world.park.wheel.at_the_button(player.global_position):
		_offer_a_ride(&"wheel")
		return
	if world.park.coaster.at_the_button(player.global_position):
		_offer_a_ride(&"coaster")
		return
	# At the fairground's kiosk this buys a ticket rather than a swim.
	if world.park.at_the_booth(player.global_position):
		if not wallet.can_afford(Park.RIDE_PRICE):
			sounds.play(Sounds.Sound.REFUSE)
			hud.announce(Text.format("say_no_coins", [Park.RIDE_PRICE]), 2.2)
			return
		# Asked, not taken. Coins are the record of everything a child has
		# done, and nothing in this valley spends them without being told to.
		_asked = &"buy"
		hud.ask(Text.format("ask_buy_ride", [Park.RIDE_PRICE]))
		return
	if world.places.turnstile_open():
		return
	# Only from the outside, at the turnstile: the button is on the screen only
	# there, but a press that was in flight as the child stepped through still
	# arrives, and a ticket bought from inside the fence is a ticket thrown away.
	if not world.places.at_turnstile(player.global_position) or world.places.inside_pool_fence(player.global_position):
		return
	if wallet.coins < Places.POOL_TICKET:
		sounds.play(Sounds.Sound.REFUSE)
		hud.announce(Text.format("say_no_coins", [Places.POOL_TICKET]), 2.2)
		return
	wallet.spend(Places.POOL_TICKET)
	world.places.open_turnstile()
	session.report_turnstile()
	sounds.play(Sounds.Sound.PICKUP, 1.1)
	hud.announce(Text.of("say_welcome_pool"), 2.4)

## The arc an arrow would fly on, drawn as dots while the string is held.
## The same arithmetic the shot itself uses, so the dots do not lie.
func _show_where_the_arrow_goes() -> void:
	var from := _arrow_from()
	var velocity := Archery.launch_velocity(
		_arrow_aim(), player.facing(), player.kick_charge, camera_rig.aim_height()
	)
	var ground := func(x: float, z: float) -> float:
		return world.field.height_at(x, z)
	# Three and a half seconds at a tenth of a second a dot: about as many
	# dots as the preview can show, and far enough to see where a shot lands
	# at the range's own distances.
	kick_preview.show_path(Archery.predict(from, velocity, 3.5, 0.09, ground))

## A basketball within range of the ring is thrown, not kicked.
func _can_throw(ball: Ball) -> bool:
	return ball.look == Ball.Look.BASKETBALL and world.places.hoop_in_range(ball.position)

func _on_boulder_jumped(_at: Vector3, total: int) -> void:
	journal.record(Journal.ROCKS)
	sounds.play(Sounds.Sound.CLEARED)
	hud.announce(Text.format("say_cleared", [total]), 1.8)

func _on_goal(index: int, _blue: int, _red: int) -> void:
	# Both phones hear it and see it; the journal only counts a goal the child
	# scored for their own side, so a brother's goals are not on this one's page.
	if world.football.scored_for_me(index):
		journal.record(Journal.GOALS)
		today.record(Today.SCORE)
		player.cheer()
	# As loud as the pitch is near: a goal scored at the far end of the valley
	# was a fanfare and a crowd in the ear of a child nowhere near it.
	var away := _metres_to_play()
	sounds.play_at(Sounds.Sound.GOAL, away)
	sounds.play_at(Sounds.Sound.CHEER, away, 1.0, -3.0)
	hud.announce(Text.of("say_goal"), 2.0, Goal.SIDE_COLOURS[1 - index])

## A side has won the match: said in its own colour over the board's.
func _on_match_won(side: int, _blue: int, _red: int) -> void:
	# From the pitch, like the goal that won it, not in the ear of a child at the
	# far end of the valley.
	sounds.play_at(Sounds.Sound.CHIME, _metres_to_play(), 1.3)
	hud.announce(
		Text.of("say_won_blue" if side == 0 else "say_won_red"),
		FootballGround.WIN_PAUSE - 1.0, Goal.SIDE_COLOURS[side].lightened(0.2)
	)

## A guest asked for a new game and the host's board has begun again: the same
## chime and words as when the host's own child presses the scoreboard.
func _on_guest_began_new_game() -> void:
	sounds.play(Sounds.Sound.CHIME, 1.1)
	hud.announce(Text.of("say_new_game"), 2.0)

## The host struck a ball for a guest, and plays the sound of it.
func _on_guest_kicked(strength: float) -> void:
	# A brother's kick is heard from the ball, not from the child's own foot.
	sounds.play_at(Sounds.Sound.KICK, _metres_to_play(), 0.85 + strength * 0.4)

## The score changed for any reason — a goal, a new game, a load or a reset.
## The interface may not exist yet when a save is read, and shows the state
## itself when it does.
func _on_scores_changed(blue: int, red: int) -> void:
	if hud != null:
		hud.set_score(blue, red)

func _on_place() -> void:
	# Captured before placing, because place() moves the preview on.
	var placing := build_mode.selected
	if build_mode.place():
		# Told one piece at a time, as a plan went up: the other phone has no
		# need to know what a plan is.
		for record in build_mode.just_placed():
			session.report_built(
				record["kind"], record["position"], float(record["spin"]),
				record["extent"], record.get("material", HouseParts.DEFAULT_MATERIAL)
			)
		if placing == BuildKinds.CAMPFIRE:
			_refresh_fires()
		_note_new_venues()
		# A sapling is planted, everything else is built. The distinction
		# matters to the greeting: planting a tree is a different kind of
		# afternoon from stacking walls.
		var planted := BuildKinds.is_plant(build_mode.selected)
		journal.record(Journal.PLANTED if planted else Journal.BUILT)
		today.record(Today.PLANT if planted else Today.BUILD)
		sounds.play(Sounds.Sound.PLACE)
		tasks.on_built(build_mode.selected)
		_placed_at = Time.get_ticks_msec()
		return

	# A second tap on a spot that was free a moment ago is a spot filled by
	# what the first tap put there, and saying "not here" over a sapling a
	# child has just planted reads as the game refusing the thing it plainly
	# did. Tapping twice is also how a six-year-old presses a button.
	if Time.get_ticks_msec() - _placed_at < JUST_PLACED:
		return
	sounds.play(Sounds.Sound.REFUSE)
	# A refused build is the moment a child most needs to be told why, and the
	# ghost's colour alone does not say it.
	hud.announce(Text.of("say_not_here"))

## How long after putting something down a refusal is kept quiet.
## How far from a grown tree its old stumps are cleared away.
const STUMPS_CLEARED_WITHIN := 1.0

const JUST_PLACED := 600
var _placed_at := -JUST_PLACED

func _on_matured(kind: StringName, at: Vector3) -> void:
	sounds.play(Sounds.Sound.GROWN)
	# The stumps round it are grubbed out — as many as are within a stride.
	# A child who cut a tree down and grew one in its place has tidied up, and
	# the ground should show that rather than keeping the scar for ever. The
	# tree is still recorded as felled, or the forest would stand the old one
	# back up on the next rebuild; what goes is the stump.
	var tidied := world.felled.clear_stumps_near(at, STUMPS_CLEARED_WITHIN)
	if tidied > 0:
		world.vegetation.rebuild_around(at)
	var reward := BuildKinds.reward_for(kind)
	if reward <= 0 or not structures.is_own_at(kind, at):
		# Nothing, too, for a tree the other child planted: its reward is paid
		# on their phone, and taking it down here repays nothing either.
		hud.announce(Text.of("say_grown"))
		return
	wallet.earn(reward)
	journal.record(Journal.COINS, reward)
	hud.announce(
		Text.format("say_grown_fir" if kind == BuildKinds.PINE else "say_grown_tree", [reward]),
		3.0
	)

func _on_groves_changed(centres: Array) -> void:
	# Fired while a save is being restored, which is before the birds exist.
	if birds != null:
		birds.set_points(structures.attract_points())
	# Only a grove standing counts: this also fires when the last one is felled.
	# And not the host's: a grove standing in the valley a guest has walked into
	# was planted by somebody else, and finished the guest's "plant 3 saplings".
	# The same goes the other way: a guest's saplings in the host's valley grow
	# up on the host's phone, and tasks are each child's own lessons, so only a
	# grove with trees this child planted counts.
	if not centres.is_empty() and not _visiting and structures.own_grove_count() > 0:
		tasks.on_grove()
	if centres.is_empty():
		return
	if not _seen_first_grove:
		_seen_first_grove = true
		# On a returning visit this fires during the restore, before the HUD
		# exists. The grove is old news then, and there is nobody to tell.
		if hud != null:
			sounds.play(Sounds.Sound.CHIME)
			hud.announce(Text.of("say_grove"), 5.0)

func _notification(what: int) -> void:
	# A phone is put down at night and picked up in the morning without the
	# game ever closing, so the day it began on can be yesterday.
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_paused_at = Time.get_unix_time_from_system()
	if what == NOTIFICATION_APPLICATION_RESUMED:
		_hush_the_resume_frame()
		_grow_while_away()
	if what == NOTIFICATION_APPLICATION_RESUMED and today != null and hud != null:
		_turn_the_day()
	# The first two arrive when the game is closing: the desktop window button,
	# and Android's back gesture.
	#
	# The third is the one that actually matters on a phone, and it was missing.
	# Pressing Home, opening the app switcher, or taking a call sends neither of
	# the other two — it sends APPLICATION_PAUSED, and Android is then free to
	# kill the process without another word. A child who built a house and went
	# to show somebody lost up to a whole autosave interval of it, and left the
	# game in exactly the state where a kill corrupts the file.
	# Back with a panel open puts the panel away. Only back with nothing open
	# leaves the game, which is done here because the engine's own quit on back
	# is turned off in project.godot: it quit with the settings, the shop or the
	# parents' room open, and a child pressing back to close one lost the game.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if hud != null and hud.close_top_panel():
			return
		_write_save()
		get_tree().quit()
		return
	if (
		what == NOTIFICATION_WM_CLOSE_REQUEST
		or what == NOTIFICATION_WM_GO_BACK_REQUEST
		or what == NOTIFICATION_APPLICATION_PAUSED
	):
		_write_save()
	# A thumb is lifted from the stick while the game is not looking: Home, a
	# call, the app switcher. The release is never delivered, the stick stays
	# held, and the child walked off on their own the moment the game came back.
	if (
		what == NOTIFICATION_APPLICATION_PAUSED
		or what == NOTIFICATION_APPLICATION_FOCUS_OUT
		or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT
	):
		_let_go_of_the_controls()
	# A phone puts the game away and brings it back days later without starting
	# it again, so the day it was opened on went on being "today": yesterday's
	# task stayed offered, and finishing it paid out for a day long gone.
	if what == NOTIFICATION_APPLICATION_RESUMED and today != null:
		var was := today.day_number()
		today.begin(int(Time.get_unix_time_from_system()))
		if today.day_number() != was and hud != null:
			hud.set_task(_task_line())

## Android stops the main loop while the game is in the background and does not
## tell the clock: the first frame back can be minutes or hours long, and every
## animal, timer, cooldown, the sky and the vitals integrate that frame as if
## it had been lived. A child who put the phone down mid-ride found the day
## already at dusk, hungry, and every creature somewhere else.
##
## The engine's own clock is held at zero for a couple of frames, which makes
## the delta every node sees zero, including the long one and the timers made
## with create_timer. Two frames, because the notification can land either side
## of the frame that carries the long delta; a zero-length frame is harmless.
func _hush_the_resume_frame() -> void:
	if _resume_hush_frames <= 0:
		_resume_time_scale = Engine.time_scale
	_resume_hush_frames = RESUME_HUSH_FRAMES
	Engine.time_scale = 0.0

## Counted down at the top of every frame; gives the clock back when done.
func _end_resume_hush() -> void:
	if _resume_hush_frames <= 0:
		return
	_resume_hush_frames -= 1
	if _resume_hush_frames == 0:
		Engine.time_scale = _resume_time_scale

## What a closed game does at start-up (see _greet_on_arrival), done for one
## that was only put down: saplings are aged by the time spent in the
## background, capped as Structures.advance_offline caps it. The child sees the
## same thing either way. Not counted twice with the start-up path: that works
## from the journal's last_seen, which is moved up to now here, and a process
## that is killed after a resume starts again from there.
func _grow_while_away() -> void:
	var paused_at := _paused_at
	_paused_at = 0.0
	if paused_at <= 0.0 or not _world_ready or structures == null or _visiting:
		return
	var now := Time.get_unix_time_from_system()
	var away := maxf(now - paused_at, 0.0)
	if journal != null:
		journal.last_seen = maxi(journal.last_seen, int(now))
	# A glance away is not a night's sleep; nothing to announce or age.
	if away < MIN_AWAY_FOR_GROWTH:
		return
	var grown := structures.advance_offline(away)
	if grown > 0 and hud != null:
		hud.announce(Text.of("back_grown"), 5.0)

## Let go of everything a hand could be holding down: the stick, sprint and
## jump. A hand that is still there will press them again with its next touch.
func _let_go_of_the_controls() -> void:
	for action: StringName in [
		InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT, InputActions.MOVE_FORWARD,
		InputActions.MOVE_BACK, InputActions.SPRINT, InputActions.JUMP,
	]:
		Input.action_release(action)

## Offer the new day's task if midnight has passed since the last one was set.
func _turn_the_day() -> void:
	var before := today.day_number()
	today.begin(int(Time.get_unix_time_from_system()))
	if today.day_number() == before:
		return
	today.arrive()
	hud.set_task(_task_line())

func _exit_tree() -> void:
	# The clock is not left stopped by a scene that goes in the middle of a resume.
	if _resume_hush_frames > 0:
		Engine.time_scale = _resume_time_scale
		_resume_hush_frames = 0

func _write_save() -> void:
	if player == null or world == null or not _may_save or not _world_ready:
		return
	# What was done this session becomes what the greeting reports next time.
	journal.depart()
	SaveGame.write(_save_data(), profiles.current_save_path())
	# A guest's phone holds the host's valley in the place of their own, and
	# writing that over their own would be the end of their house. The world
	# file stays as it was until they are home.
	if _visiting:
		return
	SaveGame.write(_world_data(), profiles.current_world_path())

## What one child carries: their bag, their coins, where they are standing, what
## they did yesterday. Two children in the same valley each have their own.
func _save_data() -> Dictionary:
	# A visiting child is saved at the door they left by, not in the host's valley.
	var at := _home_at if _visiting else player.global_position
	# Not where the body is if that is up a ride, in a boat or in the water.
	if not _visiting:
		at = RespawnSpot.spot_to_save(at, _last_on_ground, _off_the_ground())
	return {
		"seed": world.world_seed,
		"language": String(Text.language()),
		"voice_allowed": _voice_allowed,
		"first_person": _first_person,
		"cafe_paid": _cafe_paid,
		# The dish a child chose from the menu, and what is left of an ice
		# cream's half minute of cooling down; both used to start over.
		"dish": String(hud.chosen_dish()) if hud != null else String(Dishes.USUAL),
		"cooled_for": snappedf(_cooled_for, 0.1),
		"shirt": _shirt,
		"look": Character.to_data(_look),
		"look_offered": _look_offered,
		"player": {"x": at.x, "y": at.y, "z": at.z},
		"camera_yaw": camera_rig.yaw,
		"inventory": inventory.to_data(),
		"tasks": tasks.to_data(),
		"wallet": wallet.to_data(),
		"vitals": vitals.to_data(),
		"free_meal_in": Venues.wait_left(_free_meal_after, _play_seconds()),
		"built_house": _built_a_house,
		"undo": _home_undo if _visiting else build_mode.history_to_data(),
		"journal": journal.to_data(),
		"today": today.to_data(),
	}

## What the valley itself holds: what has been built, felled, dammed and taken.
## Shared by everyone in this copy of the map, which is what makes an invitation
## mean something — you walk into the house your friend built, not a picture of
## it.
func _world_data() -> Dictionary:
	return {
		"seed": world.world_seed,
		"time_of_day": world.atmosphere.time_of_day,
		"structures": structures.to_data(),
		"pickups_taken": world.pickups.to_data(),
		"football": world.football.to_data(),
		"boulders": world.boulders.to_data(),
		"animals": world.animals.to_data(),
		"dams": world.dams.to_data(),
		"hearths": world.hearths.to_data(),
		"felled": world.felled.to_data(),
		"mounts": world.mounts.to_data(),
	}

## A profile named on the command line: --player=Name. Lets a second child be
## started on the same machine without going through the interface.
func _profile_from_command_line() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--player="):
			return argument.substr(9).strip_edges()
	return ""

## Set by a harness that boots this scene inside another SceneTree script, where
## there is no command line to carry `--seed=`. Zero means "not forced".
static var forced_seed := 0

func _seed_from_command_line() -> int:
	if forced_seed != 0:
		return forced_seed
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			return argument.substr(7).to_int()
	return 0
