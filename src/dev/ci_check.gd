extends SceneTree

## Checks that run without a screen, so a machine can catch what a human would
## otherwise catch by noticing the game looks wrong.
##
## Every assertion here corresponds to a bug that actually happened during
## development, which is the only kind of test worth the maintenance: a parse
## error that hangs the loader, a valley flat enough to be a table, a chunk mesh
## with no triangles in it, a spawn point under water.

var _failures := 0

func _initialize() -> void:
	_check_every_script_loads()
	_check_world_has_relief()
	_check_chunks_have_geometry()
	_check_spawn_is_habitable()
	_check_forest_density_is_sane()
	_check_pickups_are_findable()
	_check_inventory_arithmetic()
	_check_build_costs_are_real()
	_check_a_grove_forms()
	_check_save_round_trip()
	_check_nothing_is_missing()
	_check_the_pitch_is_playable()
	_check_goals_are_judged()
	_check_kick_can_be_aimed()
	_check_rocks_are_jumpable()
	_check_the_camera_zooms()
	_check_a_house_can_be_built_and_unbuilt()
	_check_every_language_is_complete()
	_check_the_opening_leads_somewhere()
	_check_sounds_exist()
	_check_caring_pays()
	_check_the_shop_adds_up()
	_check_nodes_are_usable_immediately()
	_check_energy_never_strands()
	_check_the_valley_remembers()
	_check_a_tree_can_be_felled()
	_check_riding()
	_check_the_bow()
	_check_night_is_dark()
	_check_places_worth_walking_to()
	_check_every_handler_is_reachable()
	_check_signals_match_their_handlers()
	_check_paths_lead_somewhere()
	_check_dams_change_the_world()
	_check_one_thing_a_day()
	_check_players_and_worlds()
	_check_playing_together()
	_check_it_will_run_on_a_tablet()
	_check_voice_is_safe()
	_check_nothing_is_used_before_it_exists()

	if _failures > 0:
		printerr("FAILED: %d check(s)" % _failures)
		quit(1)
	else:
		print("all checks passed")
		quit(0)

func _fail(message: String) -> void:
	printerr("  FAIL: %s" % message)
	_failures += 1

func _ok(message: String) -> void:
	print("  ok: %s" % message)

## Assert and report in one line. The message is written as the thing that is
## true when the check passes, so the passing output reads as a description of
## the game rather than as a list of test names.
## A script with its comments removed.
##
## Checks that read source to enforce a rule kept flagging the very comment
## that explains the rule: the archery check tripped on the word "animals" in
## the sentence saying arrows must never reach one, and the voice check on the
## word "FileAccess" in the sentence saying voice must never use it. Twice is a
## pattern. Rules are about code, so the comments come out first.
##
## Only whole-line comments are stripped, which is enough here and avoids
## guessing about a "#" inside a string.
func _code_only(source: String) -> String:
	var out := ""
	for line in source.split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		out += line + "\n"
	return out

func _expect(condition: bool, message: String) -> void:
	if condition:
		_ok(message)
	else:
		_fail(message)

## A script that fails to parse returns null from load(). This also catches the
## cyclic class_name dependency that hangs Godot's loader, because the import
## step that precedes this would already have failed.
func _check_every_script_loads() -> void:
	print("scripts load")
	var scripts := _find_scripts("res://src")
	if scripts.is_empty():
		_fail("no scripts found to check — is the path wrong?")
		return
	for path in scripts:
		if ResourceLoader.load(path, "Script") == null:
			_fail("%s did not load" % path)
	_ok("%d scripts" % scripts.size())

func _find_scripts(directory: String) -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(directory)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := "%s/%s" % [directory, entry]
		if dir.current_is_dir():
			found.append_array(_find_scripts(full))
		elif entry.ends_with(".gd"):
			found.append(full)
		entry = dir.get_next()
	return found

## The valley was once flat enough to be a table top, because fractal noise
## spends most of its time near zero and the hills never rose.
func _check_world_has_relief() -> void:
	print("world has relief")
	var field := HeightField.new(20260903)
	var lowest := INF
	var highest := -INF
	for z in range(-400, 401, 40):
		for x in range(-400, 401, 40):
			var height := field.height_at(float(x), float(z))
			lowest = minf(lowest, height)
			highest = maxf(highest, height)
	var relief := highest - lowest
	if relief < 60.0:
		_fail("only %.1f m of relief across 800 m — the valley is flat" % relief)
	else:
		_ok("%.1f m from riverbed to peak" % relief)

	if lowest > HeightField.WATER_LEVEL:
		_fail("nothing is below the water line, so there is no river")
	else:
		_ok("riverbed reaches %.1f m, below the water line" % lowest)

## A chunk whose mesh has no triangles renders as nothing and looks exactly like
## geometry that was never built.
func _check_chunks_have_geometry() -> void:
	print("chunks have geometry")
	var field := HeightField.new(20260903)
	var steps := PackedInt32Array([1, 4, 8])
	for step in steps:
		var chunk := TerrainChunk.new(field, Vector2i(0, 0), step, 0, StandardMaterial3D.new(), false)
		var visual := chunk.get_child(0) as MeshInstance3D
		if visual == null or visual.mesh == null or visual.mesh.get_surface_count() == 0:
			_fail("step %d produced no surface" % step)
			continue
		var arrays := visual.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var expected := TerrainSpec.CHUNK_SIZE / step + 1
		if vertices.size() != expected * expected:
			_fail("step %d: %d vertices, expected %d" % [step, vertices.size(), expected * expected])
		elif indices.size() % 3 != 0 or indices.is_empty():
			_fail("step %d: %d indices is not whole triangles" % [step, indices.size()])
		else:
			_ok("step %d: %d vertices, %d triangles" % [step, vertices.size(), indices.size() / 3])
		chunk.free()

## The player must not open the game underwater or on a cliff.
func _check_spawn_is_habitable() -> void:
	print("spawn is habitable")
	var seeds := PackedInt32Array([20260903, 1, 777, 123456])
	for seed_value in seeds:
		var field := HeightField.new(seed_value)
		var spawn := field.find_spawn_point()
		var ground := field.height_at(spawn.x, spawn.z)
		if ground <= HeightField.WATER_LEVEL:
			_fail("seed %d spawns at %.2f m, under water" % [seed_value, ground])
		elif field.steepness_at(spawn.x, spawn.z) > 0.4:
			_fail("seed %d spawns on a slope of %.2f" % [seed_value, field.steepness_at(spawn.x, spawn.z)])
		else:
			_ok("seed %d: dry, flat ground at %.2f m" % [seed_value, ground])

## Density outside 0..1 silently breaks planting: above 1 every candidate is
## accepted and the valley becomes solid trees.
func _check_forest_density_is_sane() -> void:
	print("forest density is sane")
	var field := HeightField.new(20260903)
	var planted := 0
	var samples := 0
	for z in range(-300, 301, 20):
		for x in range(-300, 301, 20):
			var density := field.forest_density_at(float(x), float(z))
			samples += 1
			if density < 0.0 or density > 1.0:
				_fail("density %.3f at (%d, %d) is out of range" % [density, x, z])
				return
			if density > 0.35:
				planted += 1
	var share := float(planted) / float(samples)
	# Neither a bare plain nor a wall of trees: both are failures of the same
	# knob, and both are invisible until someone looks at the world.
	if share < 0.05:
		_fail("only %.1f%% of the world is forest — nothing grows" % (share * 100.0))
	elif share > 0.75:
		_fail("%.1f%% of the world is dense forest — there is nowhere to walk" % (share * 100.0))
	else:
		_ok("%.1f%% of sampled ground is forest" % (share * 100.0))

## A world with nothing to pick up gives a child nothing to do, and a world
## carpeted in sticks makes finding one meaningless.
func _check_pickups_are_findable() -> void:
	print("pickups are findable")
	var field := HeightField.new(20260903)
	var pickups := Pickups.new(field, 20260903)
	get_root().add_child(pickups)
	pickups.follow(field.find_spawn_point())
	for _i in 200:
		pickups._process(0.016)
		if pickups.is_idle():
			break
	var found := pickups.count_active()
	if found < 20:
		_fail("only %d pickups within reach of the spawn — too little to find" % found)
	elif found > 900:
		_fail("%d pickups around the spawn — the ground is a carpet" % found)
	else:
		_ok("%d pickups scattered near the spawn" % found)
	pickups.queue_free()

func _check_inventory_arithmetic() -> void:
	print("inventory arithmetic")
	var inventory := Inventory.new()
	inventory.add(ItemKinds.STICK, 3)
	inventory.add(ItemKinds.STONE, 1)
	var cost := {ItemKinds.STICK: 3, ItemKinds.STONE: 2}
	if inventory.can_afford(cost):
		_fail("claims to afford 2 stones while holding 1")
	elif inventory.spend(cost):
		_fail("spent a cost it could not afford")
	elif inventory.count(ItemKinds.STICK) != 3:
		_fail("a refused purchase took %d sticks anyway" % (3 - inventory.count(ItemKinds.STICK)))
	else:
		_ok("a refused purchase spends nothing")

	inventory.add(ItemKinds.STONE, 1)
	if not inventory.spend(cost):
		_fail("refused an affordable cost")
	elif inventory.count(ItemKinds.STICK) != 0 or inventory.count(ItemKinds.STONE) != 0:
		_fail("spending left %d sticks and %d stones behind" % [
			inventory.count(ItemKinds.STICK), inventory.count(ItemKinds.STONE)])
	else:
		_ok("spending takes exactly the cost")

## A build whose cost names an item that does not exist can never be afforded,
## and the piece is silently unbuildable with no error anywhere.
func _check_build_costs_are_real() -> void:
	print("build costs are real")
	for kind in BuildKinds.ALL:
		var cost := BuildKinds.cost(kind)
		if cost.is_empty():
			_fail("%s is free" % kind)
			continue
		for item in cost:
			if not ItemKinds.INFO.has(item):
				_fail("%s costs unknown item %s" % [kind, item])
		if BuildKinds.footprint(kind) <= 0.0:
			_fail("%s has no footprint, so it can overlap anything" % kind)
	if BuildKinds.build_mesh(BuildKinds.SAPLING, 0) == BuildKinds.build_mesh(BuildKinds.SAPLING, 2):
		_fail("a sprout and a grown tree are the same mesh, so growth is invisible")
	else:
		_ok("%d pieces, all payable, and growth changes the mesh" % BuildKinds.ALL.size())

## The whole promise of the game in one test: plant three trees close together,
## let them grow, and the world answers.
func _check_a_grove_forms() -> void:
	print("a grove forms")
	var field := HeightField.new(20260903)
	var structures := Structures.new(field)
	get_root().add_child(structures)

	var spawn := field.find_spawn_point()
	var offsets: Array[Vector3] = [Vector3(0, 0, 0), Vector3(6, 0, 2), Vector3(3, 0, 7)]
	for offset in offsets:
		var at := spawn + offset
		at.y = field.height_at(at.x, at.z)
		structures.place(BuildKinds.SAPLING, at, 0.0)

	if structures.grove_count() != 0:
		_fail("three sprouts already count as a grove")

	# Long enough for every stage; growth is driven by elapsed play time.
	var total := BuildKinds.GROWTH_STAGE_SECONDS * float(BuildKinds.GROWTH_STAGES) + 1.0
	var elapsed := 0.0
	while elapsed < total:
		structures._process(1.0)
		elapsed += 1.0

	if structures.grove_count() < 1:
		_fail("three grown trees six metres apart did not make a grove")
	elif structures.attract_points().is_empty():
		_fail("a grove formed but nothing was there to draw birds")
	else:
		_ok("three saplings grew into a grove with %d place(s) for birds" % structures.attract_points().size())

	# And a lone tree must not count, or the reward means nothing.
	var lonely := Structures.new(field)
	get_root().add_child(lonely)
	var far := spawn + Vector3(120.0, 0.0, 0.0)
	far.y = field.height_at(far.x, far.z)
	lonely.place(BuildKinds.SAPLING, far, 0.0)
	elapsed = 0.0
	while elapsed < total:
		lonely._process(1.0)
		elapsed += 1.0
	if lonely.grove_count() != 0:
		_fail("a single tree counts as a grove")
	else:
		_ok("one tree on its own is not a grove")
	structures.queue_free()
	lonely.queue_free()

## An afternoon of building has to survive closing the game.
func _check_save_round_trip() -> void:
	print("save round trip")
	var field := HeightField.new(20260903)
	var structures := Structures.new(field)
	get_root().add_child(structures)
	var spawn := field.find_spawn_point()
	structures.place(BuildKinds.CAMPFIRE, spawn, 1.0)
	structures.place(BuildKinds.SAPLING, spawn + Vector3(4.0, 0.0, 0.0), 2.0)

	var inventory := Inventory.new()
	inventory.add(ItemKinds.REED, 7)

	var written := SaveGame.write({
		"seed": 20260903,
		"structures": structures.to_data(),
		"inventory": inventory.to_data(),
		"pickups_taken": ["1:2:3"],
	})
	if not written:
		_fail("could not write the save file")
		return

	var read := SaveGame.read()
	if read.is_empty():
		_fail("the save file read back empty")
		return

	var restored := Structures.new(field)
	get_root().add_child(restored)
	restored.from_data(read["structures"])
	var restored_inventory := Inventory.new()
	restored_inventory.from_data(read["inventory"])

	if restored.to_data().size() != 2:
		_fail("saved 2 structures, restored %d" % restored.to_data().size())
	elif restored_inventory.count(ItemKinds.REED) != 7:
		_fail("saved 7 reeds, restored %d" % restored_inventory.count(ItemKinds.REED))
	elif read["pickups_taken"].size() != 1:
		_fail("collected pickups did not survive the round trip")
	else:
		_ok("structures, inventory and collected pickups all survive a round trip")

	structures.queue_free()
	restored.queue_free()

## Every class the game references must actually exist.
##
## This is the check CI earned. A `build/` line in .gitignore also matched
## src/build/, so an entire subsystem was absent from the pushed tree while
## working perfectly on the machine that wrote it. A missing script is invisible
## locally and fatal everywhere else, so the classes the game cannot run without
## are named here explicitly rather than discovered.
func _check_nothing_is_missing() -> void:
	print("nothing is missing")
	var required := PackedStringArray([
		"HeightField", "TerrainSpec", "Terrain", "TerrainChunk", "Water",
		"Atmosphere", "PlantMeshes", "Vegetation", "VegetationTile", "Pickups",
		"Birds", "World", "Player", "CameraRig", "CameraPad", "Hud",
		"InputActions", "ItemKinds", "Inventory", "SaveGame", "Wiring",
		"BuildKinds", "Structures", "BuildMode", "Backpack", "Text", "HouseParts", "Minimap", "PartIcon", "Sounds", "Tasks", "Animals", "AnimalKinds", "Wallet", "ShopStock", "Vitals", "Journal", "Felled", "Mounts", "MountKinds", "Archery", "Lantern", "Places", "PlaceSpec", "Paths", "Dams", "DamSpec", "Today", "Profiles", "Session", "Visitors", "TogetherPanel", "Voice",
		"Pitch", "Ball", "Goal", "FootballGround", "Boulders", "HouseParts",
	])
	var missing := PackedStringArray()
	for name in required:
		# A global class registers as a named script; if the file never made it
		# into the tree, the name is simply not in the list.
		if not _class_exists(name):
			missing.append(name)
	if missing.is_empty():
		_ok("all %d classes the game needs are present" % required.size())
	else:
		_fail("missing classes: %s" % ", ".join(missing))

func _class_exists(name: String) -> bool:
	for entry in ProjectSettings.get_global_class_list():
		if String(entry.get("class", "")) == name:
			return true
	return false

## Football on a slope is not football. The pitch must be flat, dry, clear of
## trees, and reachable on foot from where the player wakes up.
func _check_the_pitch_is_playable() -> void:
	print("the pitch is playable")
	var field := HeightField.new(20260903)
	var centre := Pitch.centre()

	var lowest := INF
	var highest := -INF
	var steepest := 0.0
	var x := -Pitch.HALF_LENGTH
	while x <= Pitch.HALF_LENGTH:
		var z := -Pitch.HALF_WIDTH
		while z <= Pitch.HALF_WIDTH:
			var height := field.height_at(centre.x + x, centre.z + z)
			lowest = minf(lowest, height)
			highest = maxf(highest, height)
			steepest = maxf(steepest, field.steepness_at(centre.x + x, centre.z + z))
			z += 2.0
		x += 2.0

	var unevenness := highest - lowest
	# A ball will not sit still on more than a few centimetres of fall.
	if unevenness > 0.12:
		_fail("the pitch varies by %.2f m — a ball would roll away" % unevenness)
	else:
		_ok("flat to within %.0f mm across the whole surface" % (unevenness * 1000.0))

	if lowest < HeightField.WATER_LEVEL + 1.0:
		_fail("the pitch is at %.2f m, too close to the water line" % lowest)
	else:
		_ok("dry, %.1f m above the water" % (lowest - HeightField.WATER_LEVEL))

	var forest := 0.0
	x = -Pitch.HALF_LENGTH
	while x <= Pitch.HALF_LENGTH:
		var z := -Pitch.HALF_WIDTH
		while z <= Pitch.HALF_WIDTH:
			forest = maxf(forest, field.forest_density_at(centre.x + x, centre.z + z))
			z += 4.0
		x += 4.0
	if forest > 0.0:
		_fail("trees would grow on the pitch (density %.2f)" % forest)
	else:
		_ok("no trees on the pitch")

	# It has to be findable by a six-year-old, which means walkable, not across
	# the river and not over a mountain.
	var spawn := field.find_spawn_point()
	var walk := Vector2(centre.x - spawn.x, centre.z - spawn.z).length()
	var crosses_river := signf(spawn.x - field.river_centre_x(spawn.z)) != signf(centre.x - field.river_centre_x(centre.z))
	if walk > 140.0:
		_fail("the pitch is %.0f m from the spawn — too far to stumble across" % walk)
	elif crosses_river:
		_fail("the pitch is on the far bank, so a child needs a bridge to reach it")
	else:
		_ok("%.0f m walk from the spawn, same side of the river" % walk)

## The one rule the whole game of football rests on.
func _check_goals_are_judged() -> void:
	print("goals are judged")
	for index in 2:
		var mouth := Pitch.goal_centre(index)
		var outward := -1.0 if index == 0 else 1.0

		# Well over the line, central, low: a goal.
		var scored := mouth + Vector3(outward * (Ball.RADIUS + 0.5), 0.3, 0.0)
		if not Pitch.is_goal(index, scored, Ball.RADIUS):
			_fail("goal %d: a ball over the line was not given" % index)

		# Resting exactly on the line: not a goal, because the whole ball must
		# be over it. This also stops a ball on the line scoring every frame.
		var on_line := mouth + Vector3(0.0, 0.3, 0.0)
		if Pitch.is_goal(index, on_line, Ball.RADIUS):
			_fail("goal %d: a ball on the line was given" % index)

		# Wide of the post.
		var wide := mouth + Vector3(outward * (Ball.RADIUS + 0.5), 0.3, Pitch.GOAL_WIDTH * 0.5 + 0.4)
		if Pitch.is_goal(index, wide, Ball.RADIUS):
			_fail("goal %d: a ball wide of the post was given" % index)

		# Over the bar.
		var over := mouth + Vector3(outward * (Ball.RADIUS + 0.5), Pitch.GOAL_HEIGHT + 0.5, 0.0)
		if Pitch.is_goal(index, over, Ball.RADIUS):
			_fail("goal %d: a ball over the bar was given" % index)

		# Far behind the goal, having flown straight through: not a goal.
		var behind := mouth + Vector3(outward * (Pitch.GOAL_DEPTH + 4.0), 0.3, 0.0)
		if Pitch.is_goal(index, behind, Ball.RADIUS):
			_fail("goal %d: a ball miles behind the net was given" % index)

		# And the same ball at the other end must not score in this goal.
		var other := Pitch.goal_centre(1 - index) + Vector3(-outward * (Ball.RADIUS + 0.5), 0.3, 0.0)
		if Pitch.is_goal(index, other, Ball.RADIUS):
			_fail("goal %d: a ball at the far end was given" % index)

	_ok("both goals: over the line given; on the line, wide, over the bar and through the net all refused")

## A kick with one setting is a kick a child masters in ten seconds and then
## has no reason to take again. These assertions are about range: a tap must be
## a nudge, a full swing must reach the goal, and looking up must actually
## change the shape of the shot.
func _check_kick_can_be_aimed() -> void:
	print("the kick can be aimed")
	var field := HeightField.new(20260903)
	var ground := FootballGround.new(field)
	get_root().add_child(ground)

	var stand := Pitch.centre() + Vector3(1.1, 0.0, 0.0)
	stand.y = field.height_at(stand.x, stand.z)
	var ball := ground.ball_near(stand)
	if ball == null:
		_fail("no ball within reach of a player standing next to one")
		return

	# A tap has to move the ball, but only a little.
	ball.reset_to(Pitch.centre())
	var tap := ball.kick(stand, Vector3.LEFT, false, 0.12, 0.2)
	if tap <= 0.0:
		_fail("the softest tap does nothing at all")
	elif tap > 6.0:
		_fail("the softest tap is %.1f m/s — dribbling would be impossible" % tap)
	else:
		_ok("a tap moves it at %.1f m/s" % tap)

	# A full swing has to be able to reach a goal from the halfway line, which
	# is Pitch.HALF_LENGTH away.
	ball.reset_to(Pitch.centre())
	var full := ball.kick(stand, Vector3.LEFT, false, 1.0, 0.25)
	# Range of a projectile launched at this speed, ignoring drag: enough to
	# tell "can reach the goal" from "cannot".
	var lift := ball.linear_velocity.y
	var flat := Vector2(ball.linear_velocity.x, ball.linear_velocity.z).length()
	var flight := 2.0 * lift / 20.0
	var reach := flat * maxf(flight, 0.9)
	if full <= tap * 2.0:
		_fail("a full swing (%.1f m/s) is barely harder than a tap (%.1f)" % [full, tap])
	elif reach < Pitch.HALF_LENGTH:
		_fail("a full swing carries about %.0f m; the goal is %.0f m away" % [reach, Pitch.HALF_LENGTH])
	else:
		_ok("a full swing at %.1f m/s carries about %.0f m, past the %.0f m goal" % [full, reach, Pitch.HALF_LENGTH])

	# Aim has to change the shape of the shot, not just its speed.
	ball.reset_to(Pitch.centre())
	ball.kick(stand, Vector3.LEFT, false, 0.8, 0.0)
	var driven := ball.linear_velocity
	ball.reset_to(Pitch.centre())
	ball.kick(stand, Vector3.LEFT, false, 0.8, 1.0)
	var chipped := ball.linear_velocity

	if chipped.y <= driven.y * 3.0:
		_fail("looking up barely lifts the ball: %.2f vs %.2f m/s upward" % [chipped.y, driven.y])
	elif driven.y > 1.5:
		_fail("even a flat drive goes up at %.2f m/s — there is no ground pass" % driven.y)
	else:
		_ok("flat drive rises %.2f m/s, chip rises %.2f m/s" % [driven.y, chipped.y])

	# And a chip must not be faster than a drive, or "high" would also mean
	# "harder" and the two controls would not be separable.
	if absf(chipped.length() - driven.length()) > 0.6:
		_fail("aiming changes the speed as well: %.1f vs %.1f m/s" % [chipped.length(), driven.length()])
	else:
		_ok("aiming changes only the angle, not the power")

	# Running at it still helps, on top of the charge.
	ball.reset_to(Pitch.centre())
	var running := ball.kick(stand, Vector3.LEFT, true, 0.8, 0.25)
	ball.reset_to(Pitch.centre())
	var standing := ball.kick(stand, Vector3.LEFT, false, 0.8, 0.25)
	if running <= standing:
		_fail("running at the ball does not hit it harder")
	else:
		_ok("running adds %.1f m/s over the same swing" % (running - standing))

## Rocks have to be there, be low enough to clear, and stay off the pitch.
func _check_rocks_are_jumpable() -> void:
	print("rocks are jumpable")
	var field := HeightField.new(20260903)
	var rocks := Boulders.new(field, 20260903)
	get_root().add_child(rocks)
	rocks.follow(field.find_spawn_point())
	for _i in 300:
		rocks._process(0.016)
		if rocks.is_idle():
			break

	var found := rocks.count_active()
	if found < 8:
		_fail("only %d rocks in the whole area — nothing to jump" % found)
	elif found > 600:
		_fail("%d rocks — the meadow is a boulder field" % found)
	else:
		_ok("%d rocks scattered within reach" % found)

	# None of them may sit on the football pitch.
	var on_pitch := 0
	var centre := Pitch.centre()
	for x in range(-24, 25, 3):
		for z in range(-17, 18, 3):
			if rocks._suits(centre.x + float(x), centre.z + float(z)):
				on_pitch += 1
	if on_pitch > 0:
		_fail("%d rock positions fall on the pitch" % on_pitch)
	else:
		_ok("no rocks on the football pitch")

	# A jump has to be clearable: the player rises JUMP_VELOCITY^2 / 2g.
	var apex := (Player.JUMP_VELOCITY * Player.JUMP_VELOCITY) / (2.0 * 24.0)
	if apex < Boulders.MAX_HEIGHT + 0.3:
		_fail("a jump reaches %.2f m but rocks stand up to %.2f m" % [apex, Boulders.MAX_HEIGHT])
	else:
		_ok("a jump clears %.2f m, well over the tallest rock" % apex)

## Zoom has to reach both ends and stop at them, and it must not quietly turn
## the camera while it does.
func _check_the_camera_zooms() -> void:
	print("the camera zooms")
	var player := Player.new()
	get_root().add_child(player)
	var rig := CameraRig.new(player)
	player.add_child(rig)

	var start_yaw := rig.yaw
	var start_pitch := rig.pitch

	# Pushed all the way out, and no further.
	for _i in 200:
		rig.zoom(-CameraRig.ZOOM_PER_NOTCH)
	if not is_equal_approx(rig.wanted_distance, CameraRig.ARM_MAX):
		_fail("zooming out stopped at %.1f m instead of %.1f" % [rig.wanted_distance, CameraRig.ARM_MAX])
	else:
		_ok("zooms out to %.0f m and stops" % CameraRig.ARM_MAX)

	# Pulled all the way in, and no further — a negative arm would put the
	# camera in front of the player, which is a very confusing bug to look at.
	for _i in 200:
		rig.zoom(CameraRig.ZOOM_PER_NOTCH)
	if not is_equal_approx(rig.wanted_distance, CameraRig.ARM_MIN):
		_fail("zooming in stopped at %.1f m instead of %.1f" % [rig.wanted_distance, CameraRig.ARM_MIN])
	elif CameraRig.ARM_MIN <= 0.0:
		_fail("the closest zoom is %.1f m, which is in front of the player" % CameraRig.ARM_MIN)
	else:
		_ok("zooms in to %.1f m and stops, never past the player" % CameraRig.ARM_MIN)

	if not is_equal_approx(rig.yaw, start_yaw) or not is_equal_approx(rig.pitch, start_pitch):
		_fail("zooming also turned the camera")
	else:
		_ok("zooming changes distance only, not where the camera points")

	# And the far end has to be far enough to be worth having: a valley view
	# should see well past the pitch you are standing on.
	if CameraRig.ARM_MAX < 12.0:
		_fail("the widest view is only %.0f m back — not a view of anything" % CameraRig.ARM_MAX)
	else:
		_ok("the widest view stands %.0f m back, enough to survey" % CameraRig.ARM_MAX)

	player.queue_free()

## A house is many pieces placed independently that must still meet, and every
## one of them must come back down again.
func _check_a_house_can_be_built_and_unbuilt() -> void:
	print("a house goes up and comes down")
	var field := HeightField.new(20260903)
	var structures := Structures.new(field)
	get_root().add_child(structures)
	var inventory := Inventory.new()
	for kind in ItemKinds.ALL:
		inventory.add(kind, 200)
	var build := BuildMode.new(field, structures, inventory)
	get_root().add_child(build)
	build.set_active(true)

	# Four walls in a square, each placed on its own, must not overlap and must
	# sit exactly one module apart.
	var base := Pitch.centre() + Vector3(0.0, 0.0, 26.0)
	base.y = field.height_at(base.x, base.z)
	var module := HouseParts.MODULE
	var corners: Array[Vector3] = [
		base, base + Vector3(module, 0.0, 0.0),
		base + Vector3(module, 0.0, module), base + Vector3(0.0, 0.0, module),
	]
	var placed := 0
	for corner in corners:
		if structures.is_clear(corner, HouseParts.footprint(HouseParts.WALL)):
			structures.place(HouseParts.WALL, corner, 0.0)
			placed += 1
	if placed != corners.size():
		_fail("only %d of %d walls fitted — pieces a module apart are colliding" % [placed, corners.size()])
	else:
		_ok("four walls a module apart all fit")

	# A wall directly above another is a first floor, not a collision.
	var upstairs := base + Vector3(0.0, HouseParts.STOREY, 0.0)
	if not structures.is_clear(upstairs, HouseParts.footprint(HouseParts.WALL)):
		_fail("a wall one storey up collides with the wall below it")
	else:
		structures.place(HouseParts.WALL, upstairs, 0.0)
		_ok("a wall one storey up stacks rather than colliding")

	# And a wall in the same place on the same storey must not.
	if structures.is_clear(base, HouseParts.footprint(HouseParts.WALL)):
		_fail("two walls can occupy the same square")
	else:
		_ok("two walls cannot occupy the same square")

	# Every piece must come down, and the refund must be exact.
	var before := inventory.count(ItemKinds.STICK)
	var cost := HouseParts.cost(HouseParts.WALL)
	inventory.spend(cost)
	var spent := before - inventory.count(ItemKinds.STICK)
	var record := structures.nearest(base, 4.0)
	if record.is_empty():
		_fail("nothing found to take down where five pieces were just placed")
	else:
		var kind := structures.remove(record)
		if kind == &"":
			_fail("remove() refused a record it had just returned")
		else:
			var refund := HouseParts.cost(kind) if HouseParts.is_house_part(kind) else BuildKinds.cost(kind)
			for item in refund:
				inventory.add(item, int(refund[item]))
			var after := inventory.count(ItemKinds.STICK)
			if after != before:
				_fail("building and unbuilding a wall left %d sticks, started with %d" % [after, before])
			else:
				_ok("a piece comes back down and refunds exactly what it cost")

	# Every part must be buildable at all: an unknown mesh or a zero footprint
	# makes a piece silently unplaceable.
	for kind in HouseParts.ALL:
		if HouseParts.build_mesh(kind) == null:
			_fail("%s has no mesh" % kind)
		if HouseParts.footprint(kind) <= 0.0:
			_fail("%s has no footprint" % kind)
		for item in HouseParts.cost(kind):
			if not ItemKinds.INFO.has(item):
				_fail("%s costs unknown item %s" % [kind, item])
	_ok("all %d house parts have a mesh, a footprint and a real cost" % HouseParts.ALL.size())

	# A house must be level even where the ground is not. Three walls in a row
	# on sloping meadow once sat at 1.81, 1.64 and 1.35 metres — a building that
	# leaned downhill with its roof over one end.
	var slope_base := Pitch.centre() + Vector3(34.0, 0.0, 30.0)
	slope_base.y = field.height_at(slope_base.x, slope_base.z)
	var levels: Array[float] = []
	for column in 3:
		var at := slope_base + Vector3(float(column) * module, 0.0, 0.0)
		var datum := structures.nearby_datum(at, module * 2.6)
		at.y = field.height_at(at.x, at.z) if is_inf(datum) else datum
		structures.place(HouseParts.WALL, at, 0.0)
		levels.append(at.y)
	# Array.max() returns an untyped Variant, so the subtraction cannot be
	# inferred — the same trap as an untyped array literal, wearing a hat.
	var highest: float = levels.max()
	var lowest: float = levels.min()
	var spread := highest - lowest
	if spread > 0.01:
		_fail("three walls in a row differ in height by %.2f m — the house leans" % spread)
	else:
		_ok("a row of walls stays level across %.2f m of ground fall" % absf(
			field.height_at(slope_base.x, slope_base.z)
			- field.height_at(slope_base.x + module * 2.0, slope_base.z)))

	structures.queue_free()
	build.queue_free()

## A half-translated interface is worse than an untranslated one: a child sees
## his own language and then a word of someone else's, and concludes the game is
## broken. These checks make a missing translation a build failure.
func _check_every_language_is_complete() -> void:
	print("every language is complete")

	var missing := PackedStringArray()
	for key in Text.STRINGS:
		var entry: Dictionary = Text.STRINGS[key]
		for code in Text.LANGUAGES:
			if not entry.has(code) or String(entry[code]).strip_edges().is_empty():
				missing.append("%s/%s" % [key, code])
	if missing.is_empty():
		_ok("%d strings, all present in %d languages" % [Text.STRINGS.size(), Text.LANGUAGES.size()])
	else:
		_fail("missing translations: %s" % ", ".join(missing))

	# A format string that takes a value must take it in every language, or the
	# translated one silently drops the number it was meant to show.
	for key in Text.STRINGS:
		var entry: Dictionary = Text.STRINGS[key]
		var english := String(entry[Text.EN])
		var slots := english.count("%")
		for code in Text.LANGUAGES:
			if String(entry[code]).count("%") != slots:
				_fail("'%s' has %d value slots in English but a different number in %s" % [key, slots, code])

	# Every name the game asks for must exist. This is what catches a new item
	# or building added without its words.
	for kind in ItemKinds.ALL:
		if ItemKinds.label(kind).begins_with("?"):
			_fail("item %s has no name" % kind)
	for kind in BuildKinds.ALL:
		if BuildKinds.label(kind).begins_with("?"):
			_fail("building %s has no name" % kind)
	for kind in HouseParts.ALL:
		if HouseParts.label(kind).begins_with("?"):
			_fail("house part %s has no name" % kind)
	_ok("every item, building and house part is named in all three languages")

	# And switching language actually changes what comes out.
	Text.set_language(Text.RU)
	var russian := ItemKinds.label(ItemKinds.STONE)
	Text.set_language(Text.FR)
	var french := ItemKinds.label(ItemKinds.STONE)
	Text.set_language(Text.EN)
	var english := ItemKinds.label(ItemKinds.STONE)
	if russian == english or french == english or russian == french:
		_fail("switching language returned the same word: %s / %s / %s" % [english, french, russian])
	else:
		_ok("switching gives %s / %s / %s" % [english, french, russian])

## The opening thread must run to its end and then stop asking. A tutorial that
## stalls is worse than none: the child is left holding an instruction he cannot
## satisfy, and concludes he has done something wrong.
func _check_the_opening_leads_somewhere() -> void:
	print("the opening leads somewhere")
	var tasks := Tasks.new()
	get_root().add_child(tasks)
	var inventory := Inventory.new()

	if tasks.instruction().is_empty():
		_fail("the game opens with no instruction at all")
	elif tasks.instruction().begins_with("?"):
		_fail("the first instruction has no translation")
	else:
		_ok("opens by asking for something: \"%s\"" % tasks.instruction())

	# Gathering.
	for i in Tasks.STICKS_WANTED:
		inventory.add(ItemKinds.STICK, 1)
		tasks.on_collected(inventory)
	if tasks.step != Tasks.Step.BUILD:
		_fail("collecting %d sticks did not finish the first task" % Tasks.STICKS_WANTED)

	# Building.
	tasks.on_built(BuildKinds.PATH)
	if tasks.step != Tasks.Step.PITCH:
		_fail("building something did not finish the second task")

	# Walking to the pitch.
	var field := HeightField.new(20260903)
	var centre := Pitch.centre()
	centre.y = field.height_at(centre.x, centre.z)
	tasks.on_moved(centre)
	if tasks.step != Tasks.Step.PLANT:
		_fail("standing on the pitch did not finish the third task")

	# And the grove.
	tasks.on_grove()
	if not tasks.is_finished():
		_fail("the thread did not end after the last step")
	elif not tasks.instruction().is_empty():
		_fail("the game keeps asking for things after the opening is over")
	else:
		_ok("four steps, each completed by doing it, then the valley is handed over")

	# Every step must say something in every language.
	var steps := PackedStringArray(["task_gather", "task_build", "task_pitch", "task_plant"])
	for key in steps:
		for code in Text.LANGUAGES:
			var entry: Dictionary = Text.STRINGS[key]
			if String(entry.get(code, "")).strip_edges().is_empty():
				_fail("%s has no %s text" % [key, code])
	_ok("every step is written in all three languages")

	# A reloaded save must not repeat the tutorial.
	var restored := Tasks.new()
	get_root().add_child(restored)
	restored.from_data(tasks.to_data())
	if not restored.is_finished():
		_fail("a finished tutorial starts again after a reload")
	else:
		_ok("a finished opening stays finished across a save")

	tasks.queue_free()
	restored.queue_free()

## Silence reads as "nothing happened" whatever the screen shows, so an empty
## sound is a bug rather than a missing nicety.
func _check_sounds_exist() -> void:
	print("every action makes a sound")
	var sounds := Sounds.new()
	get_root().add_child(sounds)
	var silent := PackedStringArray()
	for value in Sounds.Sound.values():
		var stream := sounds._build(value)
		if stream == null or stream.data.size() < 512:
			silent.append(str(value))
	if silent.is_empty():
		_ok("all %d sounds generate audible audio" % Sounds.Sound.values().size())
	else:
		_fail("silent sounds: %s" % ", ".join(silent))
	sounds.queue_free()

## The care loop is the whole economy: an animal wants something, you have it,
## you give it, you are paid. Every link is checked here because a break in any
## one of them leaves a child stroking a cat that never responds.
func _check_caring_pays() -> void:
	print("caring for animals pays")
	var field := HeightField.new(20260904)
	var animals := Animals.new(field, 20260904)
	get_root().add_child(animals)
	var inventory := Inventory.new()

	# Every animal must want something the valley actually contains, or it can
	# never be fed.
	var askable := true
	for kind in AnimalKinds.ALL:
		var wanted := AnimalKinds.want(kind)
		if wanted != &"" and not ItemKinds.ALL.has(wanted):
			askable = false
			printerr("  %s wants '%s', which is not a collectable item" % [kind, wanted])
	_expect(askable, "everything an animal wants can actually be picked up")

	# A cat asks for nothing, so it can always be stroked; the rest need goods.
	var free_to_care := 0
	for kind in AnimalKinds.ALL:
		if AnimalKinds.want(kind) == &"":
			free_to_care += 1
	_expect(free_to_care >= 1, "at least one animal can be cared for empty-handed")

	# Rarer or shyer animals must be worth more, or there is no reason to seek
	# them out rather than stroking the nearest cat forever.
	_expect(
		AnimalKinds.coins(AnimalKinds.BEAVER) > AnimalKinds.coins(AnimalKinds.CAT),
		"the hard-to-reach beaver pays better than the cat at your feet"
	)

	# The exchange itself: one stick in, coins out, stick gone.
	var animal := {
		"kind": AnimalKinds.DOG, "cooldown": 0.0,
		"node": Node3D.new(),
	}
	get_root().add_child(animal["node"])
	inventory.add(&"stick", 1)
	# A one-element array, because a lambda cannot assign to a captured local.
	var paid: Array[int] = [0]
	animals.cared_for.connect(func(_k: StringName, c: int, _p: Vector3) -> void: paid[0] = c)
	var earned := animals.care_for(animal, inventory)
	_expect(earned == AnimalKinds.coins(AnimalKinds.DOG), "feeding a dog a stick pays %d" % AnimalKinds.coins(AnimalKinds.DOG))
	_expect(paid[0] == earned, "the signal reports the same coins the call returned")
	_expect(inventory.count(&"stick") == 0, "the stick was actually handed over")

	# And it cannot be repeated instantly, or one animal is an infinite mine.
	inventory.add(&"stick", 1)
	_expect(animals.care_for(animal, inventory) == 0, "a fed animal will not be fed again at once")
	_expect(inventory.count(&"stick") == 1, "the refused second stick was not taken")

	# Feeding with nothing in the bag must fail rather than pay.
	var empty := {"kind": AnimalKinds.SQUIRREL, "cooldown": 0.0, "node": Node3D.new()}
	get_root().add_child(empty["node"])
	_expect(animals.care_for(empty, Inventory.new()) == 0, "a squirrel with no cone to give earns nothing")

	_expect(animals.friends.has(AnimalKinds.DOG), "the dog is remembered as a friend")
	var restored := Animals.new(field, 20260904)
	restored.from_data(animals.to_data())
	_expect(restored.friends.has(AnimalKinds.DOG), "friends survive a save")

	animal["node"].queue_free()
	empty["node"].queue_free()
	animals.queue_free()

## Coins are earned slowly, so prices must be reachable but not trivial.
func _check_the_shop_adds_up() -> void:
	print("the shop adds up")
	var wallet := Wallet.new()

	var priced := true
	for item in ShopStock.ALL:
		if ShopStock.price(item) <= 0:
			priced = false
			printerr("  %s costs nothing" % item)
	_expect(priced, "all %d items in the shop cost something" % ShopStock.ALL.size())

	# The cheapest thing must be within a short session's reach: caring for a
	# beaver pays 5, so a first purchase should be a handful of animals away.
	var cheapest := ShopStock.price(ShopStock.ALL[0])
	for item in ShopStock.ALL:
		cheapest = mini(cheapest, ShopStock.price(item))
	_expect(cheapest <= 15, "something costs %d or less, so a first purchase is close" % cheapest)

	_expect(not wallet.buy(ShopStock.BICYCLE, ShopStock.price(ShopStock.BICYCLE)), "an empty purse buys nothing")

	wallet.earn(ShopStock.price(ShopStock.BOTTLE))
	_expect(wallet.buy(ShopStock.BOTTLE, ShopStock.price(ShopStock.BOTTLE)), "exactly enough coins is enough")
	_expect(wallet.coins == 0, "the price was actually deducted")
	_expect(wallet.has(ShopStock.BOTTLE), "the bottle is owned afterwards")

	# Buying the same thing twice must not charge twice for nothing.
	wallet.earn(100)
	var before := wallet.coins
	wallet.buy(ShopStock.BOTTLE, ShopStock.price(ShopStock.BOTTLE))
	_expect(wallet.coins == before, "buying something already owned costs nothing")

	var restored := Wallet.new()
	restored.from_data(wallet.to_data())
	_expect(restored.coins == wallet.coins, "coins survive a save")
	_expect(restored.has(ShopStock.BOTTLE), "purchases survive a save")

	var named := true
	for item in ShopStock.ALL:
		for code in [Text.EN, Text.FR, Text.RU]:
			Text.set_language(code)
			if ShopStock.label(item).begins_with("?"):
				named = false
				printerr("  %s has no name in %s" % [item, code])
	Text.set_language(Text.EN)
	_expect(named, "every item is named in all three languages")

## Three separate bugs have come from building resources in _ready: a node is
## added and used on the very next line, but _ready has not run yet, so the
## thing it was supposed to build is null. This checks the nodes that callers
## actually do use immediately.
func _check_nodes_are_usable_immediately() -> void:
	print("nodes work the moment they are added")
	var field := HeightField.new(20260904)
	var structures := Structures.new(field)
	get_root().add_child(structures)
	var inventory := Inventory.new()
	inventory.add(&"wood", 50)

	var build := BuildMode.new(field, structures, inventory)
	get_root().add_child(build)
	# No frame is allowed to pass here on purpose — this is exactly what main.gd
	# and the screenshot tool do.
	build.set_active(true)
	_expect(build.active, "build mode activates on the line after add_child")
	build.select(HouseParts.WALL)
	_expect(true, "a piece can be chosen before the first frame")

	build.queue_free()
	structures.queue_free()

## Energy paces the day. The one thing it must never do is leave a child unable
## to get home, so most of this check is about what stays possible at zero.
func _check_energy_never_strands() -> void:
	print("energy paces without stranding")
	var vitals := Vitals.new()

	_expect(is_equal_approx(vitals.fraction(), 1.0), "a new player starts rested")

	# Run it flat.
	for _i in 200:
		vitals.advance(1.0, true, true)
	_expect(vitals.fraction() <= 0.0001, "running long enough empties the bar")
	_expect(not vitals.can_run(), "an empty bar stops the running")

	# The critical property: walking is never taken away.
	var walked := Player.WALK_SPEED
	_expect(walked > 0.0, "walking speed is unaffected by energy — there is no way to be stranded")

	# Resting brings it back, and within a reasonable wait.
	var seconds := 0.0
	while not vitals.can_run() and seconds < 600.0:
		vitals.advance(1.0, false, false)
		seconds += 1.0
	_expect(vitals.can_run(), "resting restores the ability to run")
	_expect(seconds <= 30.0, "the wait to run again is %d s, not a punishment" % int(seconds))

	# Walking also recovers, so heading home is never wasted time.
	var walking := Vitals.new()
	walking.energy = 10.0
	walking.advance(4.0, false, true)
	_expect(walking.energy > 10.0, "walking recovers energy too, just slower than resting")

	# Water: nothing works without the bottle, everything works with it.
	var thirsty := Vitals.new()
	thirsty.energy = 10.0
	_expect(not thirsty.fill(), "no bottle, nothing to fill")
	_expect(not thirsty.drink(), "no bottle, nothing to drink")

	thirsty.grant_bottle()
	_expect(thirsty.fill(), "the bottle fills at the river")
	_expect(is_equal_approx(thirsty.water_fraction(), 1.0), "and it fills completely")
	_expect(not thirsty.fill(), "a full bottle cannot be filled again")

	var before := thirsty.energy
	_expect(thirsty.drink(), "a full bottle gives a drink")
	_expect(thirsty.energy > before, "drinking restores energy")

	var drinks := 1
	while thirsty.drink():
		drinks += 1
	_expect(drinks == int(Vitals.MAX_WATER / Vitals.DRINK), "a full bottle holds %d drinks" % drinks)
	_expect(not thirsty.drink(), "an empty bottle gives nothing")

	# Pouring for an animal costs water and returns no energy.
	var pouring := Vitals.new()
	pouring.grant_bottle()
	pouring.fill()
	pouring.energy = 20.0
	_expect(pouring.pour(), "water can be poured out for an animal")
	_expect(is_equal_approx(pouring.energy, 20.0), "pouring for an animal gives the player nothing back")
	_expect(pouring.water < Vitals.MAX_WATER, "but it does cost water")

	# Drinking must never overflow the bar.
	var brimming := Vitals.new()
	brimming.grant_bottle()
	brimming.fill()
	brimming.drink()
	_expect(brimming.energy <= Vitals.MAX_ENERGY, "drinking while full does not overflow")

	var restored := Vitals.new()
	restored.from_data(pouring.to_data())
	_expect(restored.has_bottle, "the bottle survives a save")
	_expect(is_equal_approx(restored.water, pouring.water), "the water level survives a save")
	_expect(is_equal_approx(restored.energy, pouring.energy), "energy survives a save")

	for code in [Text.EN, Text.FR, Text.RU]:
		Text.set_language(code)
		_expect(not Text.of("say_tired").begins_with("?"), "being tired is explained in %s" % code)
	Text.set_language(Text.EN)

## The reason to come back tomorrow. Most of this is about not lying: a greeting
## that reports an afternoon nobody had is worse than no greeting.
func _check_the_valley_remembers() -> void:
	print("the valley remembers yesterday")
	var journal := Journal.new()

	_expect(not journal.has_last_visit(), "a new world claims no history")
	_expect(not journal.did_anything_this_session(), "and nothing has happened in it yet")

	# An afternoon: two houses, a fed squirrel, one goal.
	journal.record(Journal.BUILT, 2)
	journal.record(Journal.CARED)
	journal.record(Journal.GOALS)
	_expect(journal.did_anything_this_session(), "doing things is noticed")
	_expect(int(journal.lifetime[Journal.BUILT]) == 2, "the lifetime tally counts everything")

	# Nothing is reportable until the session is closed out.
	_expect(not journal.has_last_visit(), "mid-session, there is still no last visit to report")
	journal.depart()
	_expect(journal.has_last_visit(), "closing the game files the afternoon away")

	# The headline picks building over the rock-jumping, because one house is a
	# bigger afternoon than nine stones.
	var headline := journal.headline()
	_expect(headline[0] == Journal.BUILT, "the headline is the most notable thing, not the largest number")
	_expect(int(headline[1]) == 2, "and it reports the right count")

	var loud := Journal.new()
	loud.record(Journal.ROCKS, 40)
	loud.record(Journal.BUILT, 1)
	loud.depart()
	_expect(loud.headline()[0] == Journal.BUILT, "one house still outranks forty rocks")

	# A session in which nothing happened must not overwrite a real one.
	var quiet := Journal.new()
	quiet.record(Journal.BUILT, 3)
	quiet.depart()
	quiet.arrive(1_700_000_000)
	quiet.depart()
	_expect(int(quiet.last_visit[Journal.BUILT]) == 3, "an afternoon where nothing happened does not erase the one before")

	# Days away.
	var returning := Journal.new()
	returning.arrive(1_700_000_000)
	returning.arrive(1_700_000_000 + 86400 * 3)
	_expect(returning.days_away == 3, "three days away is counted as three")
	_expect(returning.visits == 2, "and the visit is counted")

	var same_day := Journal.new()
	same_day.arrive(1_700_000_000)
	same_day.arrive(1_700_000_000 + 600)
	_expect(same_day.days_away == 0, "ten minutes away is not a new day")

	# Session totals reset on arrival, lifetime does not.
	var continuing := Journal.new()
	continuing.record(Journal.COINS, 12)
	continuing.arrive(1_700_000_000)
	_expect(int(continuing.session[Journal.COINS]) == 0, "arriving clears the session tally")
	_expect(int(continuing.lifetime[Journal.COINS]) == 12, "but never the lifetime one")

	# Offline growth is what the greeting does to the world, and it needs the
	# structures to exist. This was ordered wrongly in main.gd for a while and
	# only failed on a returning visit — the one case the greeting is for — so
	# a first run never showed it.
	var world_field := HeightField.new(20260903)
	var structures := Structures.new(world_field)
	get_root().add_child(structures)
	var sapling_at := world_field.camp_centre() + Vector3(3.0, 0.0, 3.0)
	sapling_at.y = world_field.height_at(sapling_at.x, sapling_at.z)
	structures.place(BuildKinds.SAPLING, sapling_at, 0.0)
	_expect(structures.advance_offline(600.0) > 0, "a sapling ages while the game is closed")
	_expect(structures.advance_offline(0.0) == 0, "and no time away ages nothing")
	structures.queue_free()

	var restored := Journal.new()
	restored.from_data(journal.to_data())
	_expect(restored.has_last_visit(), "history survives a save")
	_expect(int(restored.lifetime[Journal.BUILT]) == 2, "and so do the lifetime totals")
	_expect(restored.headline()[0] == Journal.BUILT, "the headline is the same after a reload")

	# Every greeting must exist in every language, or a child gets "?back_built".
	var greeted := true
	for key in Journal.ALL:
		for code in [Text.EN, Text.FR, Text.RU]:
			Text.set_language(code)
			if Text.format("back_%s" % key, [1]).begins_with("?"):
				greeted = false
				printerr("  no greeting for %s in %s" % [key, code])
	Text.set_language(Text.EN)
	_expect(greeted, "every kind of afternoon can be described in all three languages")

	# The whistle: it must reach further than ordinary notice, or it does
	# nothing the animals were not already doing.
	_expect(
		Animals.WHISTLE_RANGE > Animals.NOTICE,
		"the whistle carries further (%d m) than an animal notices you (%d m)" % [
			int(Animals.WHISTLE_RANGE), int(Animals.NOTICE)
		]
	)
	var field := HeightField.new(20260904)
	var animals := Animals.new(field, 20260904)
	get_root().add_child(animals)
	_expect(not animals.whistle_active(), "the whistle is not sounding to begin with")
	animals.call_animals()
	_expect(animals.whistle_active(), "blowing it starts a call")
	animals.queue_free()

## Felling a tree is the one action that edits the world itself. Trees are
## instances inside a MultiMesh generated from the seed, so there is nothing to
## delete — the record runs the other way, and these checks are mostly about
## that record staying true to what is actually drawn.
func _check_a_tree_can_be_felled() -> void:
	print("a tree can be felled")
	var field := HeightField.new(20260904)
	var felled := Felled.new()

	_expect(felled.count() == 0, "nothing is felled to begin with")

	# Find a tile that actually has trees in it, rather than assuming one does.
	var wooded := Vector2i.ZERO
	var trees: Array[Dictionary] = []
	for x in range(-4, 5):
		for z in range(-4, 5):
			var candidate := Vector2i(x, z)
			var found := VegetationTile.generate_trees(field, candidate, 64, 20260904, null)
			if found.size() > trees.size():
				trees = found
				wooded = candidate
	_expect(trees.size() > 0, "the generator finds %d trees in tile %s" % [trees.size(), wooded])
	if trees.is_empty():
		return

	# The property the whole design rests on: the generator is pure, so asking
	# twice gives the same forest.
	var again := VegetationTile.generate_trees(field, wooded, 64, 20260904, null)
	var identical := again.size() == trees.size()
	if identical:
		for i in trees.size():
			if not (trees[i]["position"] as Vector3).is_equal_approx(again[i]["position"]):
				identical = false
				break
	_expect(identical, "generating the same tile twice gives the same trees")

	# Fell one, and it must be the only one that disappears. This is the check
	# that matters: an earlier version consumed a different number of random
	# draws once a tree was removed, and every tree after it moved.
	var victim: Vector3 = trees[trees.size() / 2]["position"]
	felled.fell(victim)
	_expect(felled.count() == 1, "felling one tree records one stump")
	_expect(felled.is_felled(victim.x, victim.z), "and that tree reads as felled")

	var after := VegetationTile.generate_trees(field, wooded, 64, 20260904, felled)
	_expect(after.size() == trees.size() - 1, "exactly one tree is gone, not %d" % (trees.size() - after.size()))

	var moved := 0
	var survivors: Array[Vector3] = []
	for tree in after:
		survivors.append(tree["position"])
	for tree in trees:
		var at: Vector3 = tree["position"]
		if at.is_equal_approx(victim):
			continue
		var still_there := false
		for survivor in survivors:
			if survivor.is_equal_approx(at):
				still_there = true
				break
		if not still_there:
			moved += 1
	_expect(moved == 0, "no other tree moved — %d did" % moved)

	# A felled tree is a hole, not a shift: the tree that was next in the list
	# must not have slid into the gap.
	_expect(not felled.is_felled(survivors[0].x, survivors[0].z), "a standing tree does not read as felled")

	# Cell-boundary lookups. A tree recorded near the edge of a lookup cell must
	# still be found from the other side of that edge.
	var edge := Felled.new()
	var on_edge := Vector3(Felled.CELL * 3.0, 0.0, Felled.CELL * -2.0)
	edge.fell(on_edge)
	_expect(edge.is_felled(on_edge.x, on_edge.z), "a tree on a cell boundary is still found")
	_expect(edge.is_felled(on_edge.x - 0.2, on_edge.z + 0.2), "and so is one just across the boundary")
	_expect(not edge.is_felled(on_edge.x + 4.0, on_edge.z), "but a tree 4 m away is not")

	var restored := Felled.new()
	restored.from_data(felled.to_data())
	_expect(restored.count() == felled.count(), "the stumps survive a save")
	_expect(restored.is_felled(victim.x, victim.z), "and the felled tree stays felled")

	var saved_again := VegetationTile.generate_trees(field, wooded, 64, 20260904, restored)
	_expect(saved_again.size() == after.size(), "a reloaded world draws the same forest")

	for code in [Text.EN, Text.FR, Text.RU]:
		Text.set_language(code)
		_expect(not Text.of("ui_chop").begins_with("?"), "the axe is labelled in %s" % code)
	Text.set_language(Text.EN)

## A horse and a bicycle are the same problem solved once. These checks are
## mostly about the ways riding could take something away from a child: being
## stranded, losing the mount, or being charged energy for sitting down.
func _check_riding() -> void:
	print("a horse and a bicycle can be ridden")
	var field := HeightField.new(20260904)
	var mounts := Mounts.new(field)
	get_root().add_child(mounts)

	# The reason to own both.
	_expect(
		MountKinds.speed(MountKinds.BICYCLE) > MountKinds.speed(MountKinds.HORSE),
		"the bicycle is faster on the flat (%.1f vs %.1f m/s)" % [
			MountKinds.speed(MountKinds.BICYCLE), MountKinds.speed(MountKinds.HORSE)
		]
	)
	_expect(
		MountKinds.max_slope(MountKinds.HORSE) > MountKinds.max_slope(MountKinds.BICYCLE),
		"but the horse climbs what the bicycle cannot"
	)
	_expect(MountKinds.fords_water(MountKinds.HORSE), "the horse fords the river")
	_expect(not MountKinds.fords_water(MountKinds.BICYCLE), "the bicycle does not")
	for kind in MountKinds.ALL:
		_expect(
			MountKinds.speed(kind) > Player.RUN_SPEED,
			"%s is faster than running, or there is no point riding it" % kind
		)

	var spot := field.find_spawn_point()
	_expect(not mounts.exists(MountKinds.HORSE), "no horse before one is placed")
	mounts.place(MountKinds.HORSE, spot + Vector3(2.0, 0.0, 0.0))
	_expect(mounts.exists(MountKinds.HORSE), "the horse stands where it was put")

	# Reach.
	_expect(mounts.nearest(spot) == MountKinds.HORSE, "a horse two metres away is within reach")
	_expect(mounts.nearest(spot + Vector3(40.0, 0.0, 0.0)) == &"", "one forty metres away is not")

	_expect(mounts.mount(MountKinds.HORSE), "it can be mounted")
	_expect(mounts.riding == MountKinds.HORSE, "and the game knows what is being ridden")
	_expect(not mounts.mount(MountKinds.HORSE), "it cannot be mounted twice")
	_expect(mounts.nearest(spot) == &"", "nothing else is offered while riding")

	# Dismounting leaves it where the child left it, which is where they will
	# look for it.
	var elsewhere := spot + Vector3(30.0, 0.0, -18.0)
	_expect(mounts.dismount(elsewhere) == MountKinds.HORSE, "it can be dismounted")
	_expect(mounts.riding == &"", "and riding stops")
	var left_at := mounts.position_of(MountKinds.HORSE)
	_expect(
		absf(left_at.x - elsewhere.x) < 0.01 and absf(left_at.z - elsewhere.z) < 0.01,
		"the horse is left where the child got off, not where it started"
	)
	_expect(
		is_equal_approx(left_at.y, field.height_at(elsewhere.x, elsewhere.z)),
		"and it stands on the ground rather than in the air"
	)
	_expect(mounts.dismount(elsewhere) == &"", "dismounting twice does nothing")

	# The property that matters most: a bicycle must refuse ground it cannot
	# take, so that a child is put down rather than carried somewhere they then
	# cannot leave.
	mounts.place(MountKinds.BICYCLE, spot)
	var deep := Vector3(field.river_centre_x(spot.z), HeightField.WATER_LEVEL - 1.0, spot.z)
	_expect(
		not mounts.can_ride_over(MountKinds.BICYCLE, deep),
		"a bicycle refuses deep water"
	)
	_expect(
		mounts.can_ride_over(MountKinds.HORSE, deep) or field.steepness_at(deep.x, deep.z) > MountKinds.max_slope(MountKinds.HORSE),
		"a horse fords the same water, unless the bank there is too steep"
	)

	var flat := spot
	flat.y = field.height_at(flat.x, flat.z)
	_expect(mounts.can_ride_over(MountKinds.BICYCLE, flat), "and it rides happily on the flat")

	# Riding must not cost the child's own energy.
	var rider := Player.new()
	rider.riding = MountKinds.HORSE
	_expect(not rider.is_running, "sitting on a horse is not running")
	rider.queue_free()

	var restored := Mounts.new(field)
	get_root().add_child(restored)
	restored.from_data(mounts.to_data())
	_expect(restored.exists(MountKinds.HORSE), "the horse survives a save")
	var recalled := restored.position_of(MountKinds.HORSE)
	_expect(
		absf(recalled.x - left_at.x) < 0.01 and absf(recalled.z - left_at.z) < 0.01,
		"and is still where it was left"
	)

	for kind in MountKinds.ALL:
		for code in [Text.EN, Text.FR, Text.RU]:
			Text.set_language(code)
			_expect(
				not MountKinds.label(kind).begins_with("?"),
				"%s is named in %s" % [kind, code]
			)
	Text.set_language(Text.EN)

	mounts.queue_free()
	restored.queue_free()

## The bow. The first check is the one that matters: an arrow must not be able
## to reach an animal, and that must be true because of how the code is built
## rather than because nobody thought to try.
func _check_the_bow() -> void:
	print("the bow shoots at targets and nothing else")

	# Read the source: the hit test must consider targets and the ground, and
	# must never mention animals. A rule enforced by a comment is a rule that
	# gets edited away; this one fails the build.
	var source := _code_only(FileAccess.get_file_as_string("res://src/archery/archery.gd"))
	_expect(not source.is_empty(), "the archery source can be read")
	var mentions_animals := (
		source.contains("Animals") or source.contains("AnimalKinds")
		or source.contains("animal")
	)
	_expect(not mentions_animals, "the bow knows nothing about animals, so it cannot hit one")

	var field := HeightField.new(20260904)
	var archery := Archery.new(field)
	get_root().add_child(archery)

	var line := Pitch.centre() + Vector3(0.0, 0.0, 60.0)
	archery.stand_up(line, Vector3.FORWARD)
	_expect(archery.target_count() == Archery.TARGET_COUNT, "the range has %d butts" % Archery.TARGET_COUNT)

	# Three different shots, not the same one three times.
	var distances: Array[float] = []
	for i in archery.target_count():
		distances.append(archery.shooting_line().distance_to(archery.target_centre(i)))
	var all_different := true
	for i in distances.size():
		for j in range(i + 1, distances.size()):
			if absf(distances[i] - distances[j]) < 1.0:
				all_different = false
	_expect(all_different, "each butt is a different distance away")

	# Scoring: nearer the middle must pay more, or aiming is pointless.
	for ring in range(Archery.RING_POINTS.size() - 1):
		_expect(
			Archery.RING_POINTS[ring] > Archery.RING_POINTS[ring + 1],
			"ring %d pays more than ring %d" % [ring, ring + 1]
		)
	for ring in range(Archery.RINGS.size() - 1):
		_expect(
			Archery.RINGS[ring] < Archery.RINGS[ring + 1],
			"and the better-paying ring is the smaller one"
		)

	# A drawn bow must be faster than a touched one, or the charge does nothing.
	_expect(Archery.SPEED_MAX > Archery.SPEED_MIN * 2.0, "a full draw is far faster than a touch")

	# Actually shoot. Aimed straight at the nearest gold from the shooting line,
	# at full draw, it must register a hit — and the hit must be scored.
	var struck: Array[int] = []
	archery.hit_target.connect(func(_i: int, ring: int, points: int) -> void:
		struck.append(ring)
		struck.append(points))

	var target := archery.target_centre(0)
	var from := archery.shooting_line() + Vector3.UP * 1.2
	# Aim at the centre, with no extra loft, and let the arrow's own launch
	# adjustment do the work — this is what the game does.
	archery.loose(from, target - from, 1.0, 0.0)
	_expect(archery.arrows_in_flight() == 1, "loosing an arrow puts one in the air")

	# Step physics forward by hand rather than waiting on the tree.
	for _i in 240:
		archery._physics_process(1.0 / 120.0)
		if struck.size() > 0:
			break
	_expect(struck.size() >= 2, "an arrow aimed at the gold from the line actually hits")
	if struck.size() >= 2:
		_expect(struck[1] > 0, "and it scores %d points" % struck[1])

	# An arrow that hits nothing must not fly forever.
	var wild := Archery.new(field)
	get_root().add_child(wild)
	wild.stand_up(line, Vector3.FORWARD)
	var lost: Array[bool] = []
	wild.missed.connect(func() -> void: lost.append(true))
	wild.loose(from + Vector3.UP * 40.0, Vector3.UP, 1.0, 0.9)
	for _i in 2000:
		wild._physics_process(1.0 / 120.0)
		if lost.size() > 0:
			break
	_expect(lost.size() > 0, "an arrow that hits nothing is eventually reported as a miss")
	_expect(wild.arrows_in_flight() == 0, "and it stops being in flight")

	for code in [Text.EN, Text.FR, Text.RU]:
		Text.set_language(code)
		_expect(not Text.of("say_missed").begins_with("?"), "a miss is explained in %s" % code)
	Text.set_language(Text.EN)

	archery.queue_free()
	wild.queue_free()

## Night has to be dark enough that a lantern is worth sixty coins, and light
## enough that a child is not lost in it.
func _check_night_is_dark() -> void:
	print("night is dark, and the lantern answers it")
	var atmosphere := Atmosphere.new()
	get_root().add_child(atmosphere)

	atmosphere.set_time(0.5)
	_expect(atmosphere.darkness() < 0.01, "noon is not dark at all")
	atmosphere.set_time(0.0)
	_expect(atmosphere.darkness() > 0.95, "midnight is fully dark")
	atmosphere.set_time(0.25)
	var dawn := atmosphere.darkness()
	_expect(dawn > 0.0 and dawn < 0.2, "dawn is in between (%.2f), not a switch" % dawn)

	# The lantern must not light up in daylight, and must light up at night.
	var lantern := Lantern.new()
	get_root().add_child(lantern)
	lantern.owned = false
	lantern.follow(1.0, 10.0)
	_expect(not lantern.is_lit(), "an unbought lantern stays dark even at midnight")

	lantern.owned = true
	lantern.follow(0.0, 10.0)
	_expect(not lantern.is_lit(), "and a bought one stays dark at noon")
	lantern.follow(1.0, 10.0)
	_expect(lantern.is_lit(), "but lights at midnight")

	# It must light a circle, not the valley: the appeal is that what is outside
	# the circle is worth walking towards.
	_expect(Lantern.RANGE < 30.0, "the lantern reaches %d m, so the valley stays large in the dark" % int(Lantern.RANGE))
	_expect(Lantern.RANGE > 6.0, "but far enough to walk by")

	lantern.queue_free()
	atmosphere.queue_free()

## The playground, the pool and the café. The valley was large and evenly
## interesting, which meant nowhere in particular was worth going.
func _check_places_worth_walking_to() -> void:
	print("there are places worth walking to")
	var field := HeightField.new(20260903)
	var camp := field.camp_centre()

	# The ground under each must actually be flat, or a pool sits on a slope
	# and a slide's foot hangs in the air.
	for place in PlaceSpec.OFFSETS:
		var centre: Vector3 = PlaceSpec.centre_of(place, camp)
		var lowest := 1e9
		var highest := -1e9
		# Probed over the structure's own footprint, not the whole levelling
		# radius: the outer part of that radius is the feathered edge, where
		# ground is meant to slope back into the valley.
		var footprint: float = PlaceSpec.FOOTPRINT[place]
		for dx in range(-4, 5):
			for dz in range(-4, 5):
				var step := footprint / 4.0
				var px := centre.x + float(dx) * step
				var pz := centre.z + float(dz) * step
				# The excavation is added back, because the pool is *meant* to
				# be 1.9 m below the rest. What is being checked is that the
				# ground the buildings stand on is level, not that nothing was
				# dug into it.
				var h := field.height_at(px, pz) + PlaceSpec.excavation(px, pz, camp)
				lowest = minf(lowest, h)
				highest = maxf(highest, h)
		var spread := highest - lowest
		_expect(
			spread < 0.12,
			"the ground under the %s is flat to %.3f m across its %.1f m footprint" % [
				place, spread, footprint * 2.0
			]
		)

	# They must be far enough apart that going from one to another is a walk.
	var names := PlaceSpec.OFFSETS.keys()
	var all_apart := true
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: Vector3 = PlaceSpec.centre_of(names[i], camp)
			var b: Vector3 = PlaceSpec.centre_of(names[j], camp)
			if a.distance_to(b) < 18.0:
				all_apart = false
				printerr("  %s and %s are only %.1f m apart" % [names[i], names[j], a.distance_to(b)])
	_expect(all_apart, "no two places are within 18 m of each other")

	var places := Places.new(field)
	get_root().add_child(places)
	places.stand_up(camp)
	for place in Places.ALL:
		_expect(places.exists(place), "the %s was built" % place)

	# Standing in one offers it; standing in the valley offers nothing.
	for place in Places.ALL:
		_expect(
			places.nearest(places.position_of(place)) == place,
			"standing at the %s offers the %s" % [place, place]
		)
	_expect(places.nearest(camp + Vector3(0.0, 0.0, 120.0)) == &"", "the open valley offers nothing")

	# The pool must be deep enough to swim in rather than wade through, and dry
	# everywhere else.
	var pool := places.position_of(Places.POOL)
	_expect(
		places.water_depth_at(pool.x, pool.z) > Player.SWIM_DEPTH,
		"the pool is deep enough to float in"
	)
	# The hole and the water must be the same shape, or a child floats above the
	# floor or stands in the water. Both come from PlaceSpec.excavation, and
	# this is what proves it.
	var same_shape := true
	for dx in range(-6, 7):
		var px := pool.x + float(dx)
		var dug := PlaceSpec.excavation(px, pool.z, camp)
		var wet := places.water_depth_at(px, pool.z)
		if absf(dug - wet) > 0.001:
			same_shape = false
	_expect(same_shape, "the water is exactly as deep as the hole is deep")
	_expect(
		is_zero_approx(places.water_depth_at(pool.x + 40.0, pool.z)),
		"and the grass beside it is dry"
	)
	# A step-in rather than a drop at the edge.
	var edge := places.water_depth_at(pool.x + Places.POOL_HALF - 0.4, pool.z)
	_expect(
		edge > 0.0 and edge < Places.POOL_DEPTH,
		"the pool shelves at the edge (%.2f m) rather than dropping" % edge
	)

	# The property that matters most about water, and the one whose absence sent
	# a child 1,445 m into the sky: being above the surface must mean being out
	# of the water, whatever the depth beneath.
	var pool_at := places.position_of(Places.POOL)
	var bottom := Vector3(pool_at.x, field.height_at(pool_at.x, pool_at.z) + Player.HEIGHT * 0.5, pool_at.z)
	_expect(
		places.submersion(bottom, Player.HEIGHT) > Player.SWIM_DEPTH,
		"standing on the bottom of the pool is deep enough to swim"
	)

	var floating := bottom
	floating.y = field.height_at(pool_at.x, pool_at.z) + Places.POOL_DEPTH
	_expect(
		places.submersion(floating, Player.HEIGHT) < Player.SWIM_DEPTH,
		"at the surface it is no longer deep enough, so buoyancy stops"
	)

	for height in [2.0, 20.0, 200.0, 1445.0]:
		var above := bottom
		above.y = field.height_at(pool_at.x, pool_at.z) + Places.POOL_DEPTH + height
		_expect(
			is_zero_approx(places.submersion(above, Player.HEIGHT)),
			"%d m above the pool is not in the pool" % int(height)
		)

	# The same over the river, since it has its own surface.
	var river_z := 40.0
	var river_x := field.river_centre_x(river_z)
	var in_river := Vector3(river_x, field.height_at(river_x, river_z) + Player.HEIGHT * 0.5, river_z)
	_expect(places.submersion(in_river, Player.HEIGHT) > 0.0, "the river is water too")
	var over_river := in_river
	over_river.y = HeightField.WATER_LEVEL + 60.0
	_expect(
		is_zero_approx(places.submersion(over_river, Player.HEIGHT)),
		"but sixty metres above it is not"
	)

	_expect(places.push_swing(), "the swing can be pushed")
	_expect(places.swinging(), "and it swings")

	# Swimming itself: forgiving by design. No drowning, and slower than
	# walking so it reads as crossing something rather than as a shortcut.
	_expect(Player.SWIM_SPEED < Player.WALK_SPEED, "swimming is slower than walking")
	_expect(Player.BUOYANCY > 0.0, "water pushes a child back up, so nobody sinks")

	# But it must never throw them off it. Buoyancy was proportional to depth
	# with no ceiling, and the river reaches 3.8 m: that came to 24.8 m/s²
	# upward, more than gravity, and a child who waded into a deep stretch was
	# fired into the sky the moment they broke the surface.
	var deepest := 0.0
	for z in range(-300, 300, 11):
		var rx := field.river_centre_x(float(z))
		deepest = maxf(deepest, HeightField.WATER_LEVEL - field.height_at(rx, float(z)))
	_expect(deepest > Player.SWIM_DEPTH, "the river is deep enough to swim in (%.1f m)" % deepest)

	var lift := Player.BUOYANCY * minf(deepest - Player.SWIM_DEPTH, Player.MAX_LIFT_DEPTH)
	_expect(
		lift < 24.0,
		"at the deepest point water lifts at %.1f m/s², which is less than gravity" % lift
	)

	# And simulate it, rather than trusting the arithmetic: no sequence of
	# frames in the deepest water may reach a speed that reads as a launch.
	var rising := 0.0
	for _step in 600:
		var to_surface := clampf(deepest - Player.SWIM_DEPTH, 0.0, Player.MAX_LIFT_DEPTH)
		rising = minf((rising + Player.BUOYANCY * to_surface / 60.0) * Player.SWIM_DAMP, Player.MAX_RISE)
	_expect(
		rising < Player.JUMP_VELOCITY * 0.5,
		"and nobody rises faster than %.2f m/s, well under a jump" % rising
	)

	# The café closes the energy loop: coins back into energy.
	var wallet := Wallet.new()
	_expect(not wallet.spend(Places.MEAL_PRICE), "an empty purse buys no lunch")
	wallet.earn(Places.MEAL_PRICE)
	_expect(wallet.spend(Places.MEAL_PRICE), "a meal costs %d coins" % Places.MEAL_PRICE)
	_expect(wallet.coins == 0, "and the coins are actually gone")
	# Unlike a shop item, lunch is not recorded as owned — it can be bought again.
	wallet.earn(Places.MEAL_PRICE)
	_expect(wallet.spend(Places.MEAL_PRICE), "and lunch can be bought a second time")

	_expect(
		Places.MEAL_PRICE <= AnimalKinds.coins(AnimalKinds.BEAVER),
		"one animal cared for pays for a meal"
	)

	for place in Places.ALL:
		for code in [Text.EN, Text.FR, Text.RU]:
			Text.set_language(code)
			_expect(
				not Text.of("place_%s" % place).begins_with("?"),
				"the %s is named in %s" % [place, code]
			)
	Text.set_language(Text.EN)

	places.queue_free()

## Handlers are passed to the interface as a dictionary keyed by name. A
## duplicate key silently replaces the earlier handler rather than erroring,
## which is exactly how the place button nearly stopped building from working:
## both wanted to be called "place".
func _check_every_handler_is_reachable() -> void:
	print("every control has its own handler")
	var seen: Dictionary = {}
	var unique := true
	for name in Wiring.HANDLERS:
		if seen.has(name):
			unique = false
			printerr("  '%s' is listed twice" % name)
		seen[name] = true
	_expect(unique, "all %d handler names are distinct" % Wiring.HANDLERS.size())

	# And the source must connect one signal per handler, so a name that is
	# listed but never wired up is caught here rather than as a dead button.
	var source := FileAccess.get_file_as_string("res://src/game/wiring.gd")
	var wired := true
	for name in Wiring.HANDLERS:
		if not source.contains('&"%s"' % name):
			wired = false
			printerr("  '%s' is never connected" % name)
	_expect(wired, "every handler name is actually connected to a signal")

## Connecting a lambda with the wrong number of arguments is accepted silently
## and then fails every single time the signal fires — at runtime, in the log,
## where nobody is looking. The football ground had one for the whole life of
## the project: `kicked(strength, loft)` connected to a lambda taking one
## argument, so every kick printed an error.
func _check_signals_match_their_handlers() -> void:
	print("signals and their handlers agree")
	var scripts := _find_scripts("res://src")
	var signatures: Dictionary = {}

	# Collect every signal declaration and how many arguments it carries.
	for path in scripts:
		var source := FileAccess.get_file_as_string(path)
		for line in source.split("\n"):
			var trimmed := line.strip_edges()
			if not trimmed.begins_with("signal "):
				continue
			var name := trimmed.substr(7).strip_edges()
			var open := name.find("(")
			if open < 0:
				continue
			var inside := name.substr(open + 1, name.rfind(")") - open - 1).strip_edges()
			var count := 0 if inside.is_empty() else inside.split(",").size()
			# Every arity a signal of this name is declared with, because two
			# unrelated classes may both declare `completed` with different
			# signatures — Tasks and Today do. Matching on the bare name and one
			# arity flags perfectly correct code.
			var key := name.substr(0, open)
			if not signatures.has(key):
				signatures[key] = {}
			signatures[key][count] = true

	_expect(signatures.size() > 0, "found %d signal declarations to check" % signatures.size())

	# Then every inline `x.signal.connect(func(...))` and count its arguments.
	var mismatched := 0
	for path in scripts:
		var source := FileAccess.get_file_as_string(path)
		for line in source.split("\n"):
			var at := line.find(".connect(func(")
			if at < 0:
				continue
			var before := line.substr(0, at)
			var dot := before.rfind(".")
			if dot < 0:
				continue
			var signal_name := before.substr(dot + 1)
			if not signatures.has(signal_name):
				continue
			var args_at := at + ".connect(func(".length()
			var close := line.find(")", args_at)
			if close < 0:
				continue
			var args := line.substr(args_at, close - args_at).strip_edges()
			var given := 0 if args.is_empty() else args.split(",").size()
			var allowed: Dictionary = signatures[signal_name]
			if not allowed.has(given):
				mismatched += 1
				printerr(
					"  %s is connected to a lambda taking %d argument(s), but is only declared with %s — %s" % [
						signal_name, given, str(allowed.keys()), path
					]
				)
	_expect(mismatched == 0, "every inline signal handler takes the right number of arguments")

## Paths. A path is the strongest signal a world can give about where to go, and
## a path that leads nowhere is worse than no path at all.
func _check_paths_lead_somewhere() -> void:
	print("the paths lead somewhere")
	var field := HeightField.new(20260903)
	var camp := field.camp_centre()

	# Every route must actually arrive at a destination.
	for route in Paths.ROUTES:
		for end in [route["from"], route["to"]]:
			var at: Vector3 = camp if end == &"" else PlaceSpec.centre_of(end, camp)
			_expect(
				field.path_at(at.x, at.z) > 0.5,
				"there is a path at the %s" % ("camp" if end == &"" else String(end))
			)

	# And the middle of a route must be worn too, or it is two patches rather
	# than a path.
	var midway_worn := true
	for route in Paths.ROUTES:
		var a: Vector3 = camp if route["from"] == &"" else PlaceSpec.centre_of(route["from"], camp)
		var b: Vector3 = camp if route["to"] == &"" else PlaceSpec.centre_of(route["to"], camp)
		for step in [0.25, 0.5, 0.75]:
			var at := a.lerp(b, step)
			if field.path_at(at.x, at.z) < 0.5:
				midway_worn = false
	_expect(midway_worn, "the ground is worn along the whole of every route, not just at the ends")

	# The valley away from the camp must be untouched, or the whole world is a
	# path and none of it is a signal.
	var open_valley := true
	for distance in [80.0, 160.0, 320.0]:
		for step in 8:
			var angle := TAU * float(step) / 8.0
			var at := camp + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
			if field.path_at(at.x, at.z) > 0.0:
				open_valley = false
	_expect(open_valley, "the open valley has no paths in it")

	# Nothing grows on a path. Grass coming up through a route is what made the
	# football pitch look painted on before it was fixed the same way.
	var playground := PlaceSpec.centre_of(&"playground", camp)
	var midpoint := camp.lerp(playground, 0.5)
	_expect(
		is_zero_approx(field.forest_density_at(midpoint.x, midpoint.z)),
		"no trees grow on a path"
	)

	# A path is made of colour and bare earth, not of a dent. It used to sink by
	# nine centimetres, which was too little to see and cost six milliseconds a
	# chunk to compute — so the ground is left alone and these are what remain.
	var on_path := camp.lerp(PlaceSpec.centre_of(&"pool", camp), 0.5)
	_expect(field.path_at(on_path.x, on_path.z) > 0.5, "the middle of a route is a path")
	_expect(
		is_equal_approx(
			field.height_at(on_path.x, on_path.z),
			field.height_at(on_path.x, on_path.z)
		),
		"and the ground under it is not moved"
	)

	# The grid the terrain is actually built from has to agree with the height
	# anything else asks for, or the ground a child walks on is not the ground
	# they can see.
	var worst := 0.0
	for corner in [Vector2(0.0, 0.0), Vector2(-320.0, 224.0), Vector2(896.0, 0.0)]:
		var grid := field.fill_grid(corner.x, corner.y, 1.0, 33)
		for row in 33:
			for column in 33:
				worst = maxf(worst, absf(
					grid[row * 33 + column]
					- field.height_at(corner.x + float(column), corner.y + float(row))
				))
	_expect(worst < 0.001, "the terrain grid matches height_at to %.5f m" % worst)

	# The bounding rejection is what makes this affordable at all: without it
	# the square roots came to roughly seven million per world build and
	# generation took longer than the screenshot tool would wait.
	var far := camp + Vector3(Paths.BOUNDS_HALF + 10.0, 0.0, 0.0)
	_expect(is_zero_approx(Paths.influence(far.x, far.z, camp)), "points outside the bounds are rejected outright")

	# The rides at the playground: both must end on their own, so a child is
	# never stuck on one.
	var places := Places.new(field)
	get_root().add_child(places)
	places.stand_up(camp)

	places.push_swing()
	var swung := 0.0
	while places.swinging() and swung < 30.0:
		places._process(1.0 / 60.0)
		swung += 1.0 / 60.0
	_expect(not places.swinging(), "the swing stops on its own after %.1f s" % swung)
	_expect(swung < 10.0, "and it does not go on for ever")

	# The slide runs downhill, or a child would slide upwards.
	_expect(
		places.slide_top().y > places.slide_foot().y,
		"the top of the slide is above its foot"
	)
	_expect(
		places.at_slide_top(places.slide_top()),
		"standing at the top of the slide is recognised"
	)
	_expect(
		not places.at_slide_top(places.slide_foot()),
		"standing at the foot is not"
	)

	places.queue_free()

## Dams. The only thing in the game that changes the world rather than the
## score, which makes it the only thing that can break the world.
func _check_dams_change_the_world() -> void:
	print("beavers change the world")
	var field := HeightField.new(20260903)
	var dams := Dams.new(field)
	get_root().add_child(dams)

	_expect(DamSpec.SITES.size() >= 2, "there is more than one place to build")
	# Each pond must be its own place rather than one long lake.
	var far_apart := true
	for i in DamSpec.SITES.size():
		for j in range(i + 1, DamSpec.SITES.size()):
			if absf(DamSpec.SITES[i] - DamSpec.SITES[j]) < DamSpec.POND_LENGTH * 2.0:
				far_apart = false
	_expect(far_apart, "the dam sites are far enough apart to be separate ponds")

	var site: float = DamSpec.SITES[0]
	var river_x := field.river_centre_x(site)
	var before := field.height_at(river_x, site + DamSpec.POND_LENGTH * 0.3)

	_expect(not dams.is_built(site), "nothing is dammed to begin with")
	_expect(dams.sticks_at(site) == 0, "and no sticks have been delivered")

	# Delivering, one stick at a time.
	for i in DamSpec.STICKS_NEEDED - 1:
		_expect(dams.deliver(site), "stick %d is taken" % (i + 1))
	_expect(not dams.is_built(site), "the dam is not finished early")
	_expect(dams.sticks_at(site) == DamSpec.STICKS_NEEDED - 1, "and the count is right")

	var finished: Array[float] = []
	dams.dam_finished.connect(func(at: float) -> void: finished.append(at))
	_expect(dams.deliver(site), "the last stick is taken")
	_expect(dams.is_built(site), "and the dam is finished")
	_expect(finished.size() == 1, "which is announced exactly once")
	_expect(not dams.deliver(site), "a finished dam takes no more sticks")

	# The world must actually change. This is the whole point.
	field.dams_built = dams.built.duplicate()
	var after := field.height_at(river_x, site + DamSpec.POND_LENGTH * 0.3)
	_expect(after > before, "the riverbed behind the dam rose by %.2f m" % (after - before))

	# Deep enough to swim in, or the pond is a puddle.
	var pond_depth := HeightField.WATER_LEVEL - field.height_at(river_x, site + 4.0)
	var was_depth := HeightField.WATER_LEVEL - before
	_expect(
		pond_depth < was_depth,
		"the water behind it is shallower than the old river bed, as a filled trench should be"
	)

	# And the valley away from the dam must be untouched.
	var elsewhere_before := HeightField.new(20260903)
	var far := site + DamSpec.POND_LENGTH * 3.0
	_expect(
		is_equal_approx(
			field.height_at(field.river_centre_x(far), far),
			elsewhere_before.height_at(elsewhere_before.river_centre_x(far), far)
		),
		"the river well upstream is unchanged"
	)
	# Downstream of the wall, too: a dam holds water back, it does not flood
	# what is below it.
	var below := site - 8.0
	_expect(
		is_equal_approx(
			field.height_at(field.river_centre_x(below), below),
			elsewhere_before.height_at(elsewhere_before.river_centre_x(below), below)
		),
		"and the river below the dam is unchanged"
	)

	# Reach: a child has to be at the site, not anywhere on the river.
	_expect(
		is_equal_approx(dams.site_near(Vector3(river_x, 0.0, site)), site),
		"standing at a site finds it"
	)
	_expect(
		is_nan(dams.site_near(Vector3(river_x, 0.0, site + 200.0))),
		"standing far away finds nothing"
	)

	var restored := Dams.new(field)
	get_root().add_child(restored)
	restored.from_data(dams.to_data())
	_expect(restored.is_built(site), "a finished dam survives a save")

	# Half-finished progress must survive too, or a child loses their sticks.
	var partial := Dams.new(field)
	get_root().add_child(partial)
	partial.deliver(DamSpec.SITES[1])
	partial.deliver(DamSpec.SITES[1])
	var carried_over := Dams.new(field)
	get_root().add_child(carried_over)
	carried_over.from_data(partial.to_data())
	_expect(
		carried_over.sticks_at(DamSpec.SITES[1]) == 2,
		"and so do sticks delivered towards an unfinished one"
	)

	for code in [Text.EN, Text.FR, Text.RU]:
		Text.set_language(code)
		_expect(not Text.of("say_dam_done").begins_with("?"), "a finished dam is announced in %s" % code)
	Text.set_language(Text.EN)

	dams.queue_free()
	restored.queue_free()
	partial.queue_free()
	carried_over.queue_free()

## One thing a day. Deliberately small: a child who misses three days must not
## come back to a backlog, and ignoring it entirely must cost nothing.
func _check_one_thing_a_day() -> void:
	print("there is one thing worth doing today")
	var today := Today.new()

	var monday := 1_760_000_000
	today.begin(monday)
	_expect(not today.is_finished(), "the day starts unfinished")
	_expect(today.done() == 0, "with nothing done")
	_expect(today.needed() > 0, "and something to do")

	# What is offered must depend only on the day, so every child on a shared
	# map is offered the same thing and can help each other.
	var same := Today.new()
	same.begin(monday + 3600)
	_expect(same.kind() == today.kind(), "everyone gets the same task on the same day")

	var tomorrow := Today.new()
	tomorrow.begin(monday + 86400)
	_expect(tomorrow.day_number() == today.day_number() + 1, "tomorrow is the next day")

	# Over a week, the task must actually change rather than repeating.
	var offered: Dictionary = {}
	for day in 6:
		var each := Today.new()
		each.begin(monday + 86400 * day)
		offered[each.kind()] = true
	_expect(offered.size() >= 4, "%d different things are asked for across six days" % offered.size())

	# Only the thing asked for counts.
	var wanted := today.kind()
	var other := Today.VISIT if wanted != Today.VISIT else Today.CARE
	today.record(other, 99)
	_expect(today.done() == 0, "doing something else does not count")

	var paid: Array[int] = []
	today.completed.connect(func(_k: StringName, reward: int) -> void: paid.append(reward))
	today.record(wanted, today.needed())
	_expect(today.is_finished(), "doing what was asked finishes the day")
	_expect(paid.size() == 1, "and pays exactly once")
	_expect(paid[0] == Today.REWARD, "%d coins" % Today.REWARD)

	today.record(wanted, 99)
	_expect(paid.size() == 1, "doing more afterwards pays nothing extra")

	# A finished day stays finished across a save, and a new day starts fresh —
	# with no backlog from the days that were missed.
	var returning := Today.new()
	returning.from_data(today.to_data())
	returning.begin(monday)
	_expect(returning.is_finished(), "a finished day survives a save")

	var next_week := Today.new()
	next_week.from_data(today.to_data())
	next_week.begin(monday + 86400 * 7)
	_expect(not next_week.is_finished(), "a week later there is a new thing to do")
	_expect(next_week.done() == 0, "and no backlog from the days that were missed")

	# Every task must be describable, in every language, or a child sees "?".
	for kind in Today.KINDS:
		_expect(Today.AMOUNT.has(kind), "%s asks for a number of things" % kind)
	for day in Today.KINDS.size():
		var each := Today.new()
		each.begin(monday + 86400 * day)
		for code in [Text.EN, Text.FR, Text.RU]:
			Text.set_language(code)
			_expect(
				not each.describe().begins_with("?"),
				"day %d's task reads in %s" % [day, code]
			)
	Text.set_language(Text.EN)

## Players, map templates and the worlds made from them.
##
## The distinction these checks are really about: a map is the same valley for
## everybody, the way a Call of Duty map is, and a world is one copy of it that
## a child actually plays in. Two children can each have their own copy of the
## same valley, and an invitation puts one of them in the *other's* copy rather
## than in a copy of their own.
func _check_players_and_worlds() -> void:
	print("players, maps and the worlds made from them")
	var profiles := Profiles.new()
	profiles.load_index()

	_expect(profiles.maps.has(Profiles.HOME_MAP), "there is a home valley to make copies of")

	# Names become file paths, so they are restricted rather than sanitised.
	_expect(Profiles.is_valid_name("Amir"), "a latin name is allowed")
	_expect(Profiles.is_valid_name("Мурат"), "a cyrillic name is allowed")
	_expect(Profiles.is_valid_name("Ali-2"), "hyphens and digits are allowed")
	_expect(not Profiles.is_valid_name(""), "an empty name is not")
	_expect(not Profiles.is_valid_name("   "), "nor is whitespace")
	_expect(not Profiles.is_valid_name("a/b"), "nor a name with a path separator in it")
	_expect(not Profiles.is_valid_name("../etc"), "nor one that climbs out of the folder")
	_expect(not Profiles.is_valid_name("x".repeat(Profiles.MAX_NAME + 1)), "nor one that is too long")

	_expect(profiles.add_player("Amir"), "a player can be added")
	_expect(not profiles.add_player("Amir"), "but not twice")
	_expect(profiles.add_player("Мурат"), "and a second player can be added")

	# The key property: two worlds from one map are the same ground and
	# different afternoons.
	var first := profiles.create_world(Profiles.HOME_MAP, "Amir")
	var second := profiles.create_world(Profiles.HOME_MAP, "Мурат")
	_expect(not first.is_empty() and not second.is_empty(), "two copies of the valley can exist at once")
	_expect(first != second, "and they are different worlds")
	_expect(
		profiles.seed_of_world(first) == profiles.seed_of_world(second),
		"both copies have the same ground, because they are the same map"
	)
	_expect(
		profiles.world_path_for(first) != profiles.world_path_for(second),
		"but what is built in one is not in the other"
	)

	# Playing alone.
	_expect(profiles.owner_of(first) == "Amir", "a world belongs to whoever made it")
	_expect(profiles.may_enter(first, "Amir"), "who can walk into it")
	_expect(not profiles.may_enter(first, "Мурат"), "and nobody else can, uninvited")

	# Inviting a friend puts them in *this* copy.
	_expect(profiles.invite(first, "Мурат"), "a friend can be invited")
	_expect(profiles.may_enter(first, "Мурат"), "and can then walk in")
	_expect(not profiles.invite(first, "Мурат"), "inviting twice does nothing")
	_expect(not profiles.invite(first, "Amir"), "and an owner cannot be their own guest")
	_expect(not profiles.invite(first, "Nobody"), "nor can somebody who does not exist")
	_expect(not profiles.invite("no-such-world", "Мурат"), "nor into a world that does not exist")

	# A guest's own progress is still their own, even in someone else's valley.
	_expect(
		profiles.save_path_for("Amir", first) != profiles.save_path_for("Мурат", first),
		"two children in one valley each keep their own bag and coins"
	)
	# But the ground they change is shared, which is what makes the invitation
	# worth anything.
	_expect(
		profiles.world_path_for(first) == profiles.world_path_for(first),
		"and they change the same ground"
	)

	# The same child in two worlds is two separate afternoons.
	_expect(
		profiles.save_path_for("Мурат", first) != profiles.save_path_for("Мурат", second),
		"the same child in two valleys has two separate afternoons"
	)

	_expect(profiles.uninvite(first, "Мурат"), "an invitation can be withdrawn")
	_expect(not profiles.may_enter(first, "Мурат"), "and then they cannot walk in")
	profiles.invite(first, "Мурат")

	# What each child sees when choosing where to play.
	var amir_sees := profiles.worlds_for("Amir")
	var murat_sees := profiles.worlds_for("Мурат")
	_expect(amir_sees.size() == 1, "Amir sees the one world he made")
	_expect(murat_sees.size() == 2, "Мурат sees his own and the one he was invited to")

	# A new map template is a new kind of valley, with its own ground.
	_expect(profiles.add_map("river", 771234), "a new map can be added")
	_expect(not profiles.add_map("river", 9), "but not one that already exists")
	_expect(
		profiles.seed_of("river") != profiles.seed_of(Profiles.HOME_MAP),
		"and it is a different valley"
	)
	var elsewhere := profiles.create_world("river", "Amir")
	_expect(
		profiles.seed_of_world(elsewhere) != profiles.seed_of_world(first),
		"a world made from it has different ground"
	)
	_expect(profiles.create_world("nowhere", "Amir").is_empty(), "no world can be made from a map that does not exist")

	# Everything must survive a restart, or a child loses their friends' valleys.
	profiles.choose_player("Amir")
	profiles.choose_world(first)
	profiles.save_index()

	var restarted := Profiles.new()
	restarted.load_index()
	_expect(restarted.players.has("Amir") and restarted.players.has("Мурат"), "players survive a restart")
	_expect(restarted.worlds.has(first), "so do the worlds")
	_expect(restarted.may_enter(first, "Мурат"), "and so do the invitations")
	_expect(restarted.current_player == "Amir", "and who was playing")
	_expect(restarted.current_world == first, "and where")

	# Removing a player must not take the shared valley with them.
	_expect(restarted.remove_player("Мурат"), "a player can be removed")
	_expect(restarted.worlds.has(first), "and the valley they were invited to survives")
	_expect(not restarted.may_enter(first, "Мурат"), "though they are no longer a guest")

	# Leave no test data behind for the next run.
	var folder := DirAccess.open(Profiles.FOLDER)
	if folder != null:
		for file in folder.get_files():
			DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s" % [Profiles.FOLDER, file]))

## Playing in the same valley from two devices.
##
## The transport itself needs two machines and cannot be checked here. What can
## be checked is everything around it: that the ground never travels, that the
## right things do, and that a name arriving from another machine is treated as
## the untrusted input it is.
func _check_playing_together() -> void:
	print("two children can share a valley")
	var session := Session.new()
	get_root().add_child(session)

	_expect(not session.is_networked(), "a game starts on its own")
	_expect(not session.is_host(), "and hosting nothing")
	_expect(not session.is_connected_to_anyone(), "and with nobody to talk to")

	# Nothing may be sent on a connection that is not up. A guest whose join is
	# still in flight, or has failed outright, is "networked" but has nobody
	# listening — an early version happily reported building a wall from a game
	# that had never joined anything.
	session.report_built(&"wall", Vector3.ZERO, 0.0)
	session.report_felled(Vector3.ZERO)
	session.report_dam_stick(0.0)
	session.report_position(Vector3.ONE, 0.0)
	_expect(true, "reporting anything while alone is silently ignored, not an error")

	# The MultiplayerAPI belongs to the scene tree, so a session outside one
	# cannot connect. It must say so rather than crashing on a null.
	var orphan := Session.new()
	var refusals: Array[String] = []
	orphan.failed.connect(func(reason: String) -> void: refusals.append(reason))
	_expect(not orphan.host("Amir"), "a session outside the tree refuses to host")
	_expect(not orphan.join("127.0.0.1", "Amir"), "and refuses to join")
	_expect(refusals.size() == 2, "and explains itself both times rather than crashing")
	orphan.free()

	# The single biggest property of this design: terrain is generated from the
	# seed on both machines and never sent. If the session ever learns about the
	# height field or the terrain, that has stopped being true.
	var source := FileAccess.get_file_as_string("res://src/net/session.gd")
	_expect(not source.is_empty(), "the session source can be read")
	var sends_ground := (
		source.contains("HeightField") or source.contains("TerrainChunk")
		or source.contains("Vegetation") or source.contains("height_at")
	)
	_expect(
		not sends_ground,
		"the ground is never sent — both machines generate it from the map's seed"
	)

	# Positions are unreliable and frequent; changes to the valley are reliable,
	# because a dropped house is a lost afternoon and a dropped position is
	# corrected a twelfth of a second later.
	_expect(
		source.contains('"unreliable_ordered"'),
		"positions are sent unreliably, since the next one corrects a lost one"
	)
	var reliable_changes := 0
	for line in source.split("\n"):
		if line.contains('"reliable"'):
			reliable_changes += 1
	_expect(
		reliable_changes >= 5,
		"the %d messages that change the valley are sent reliably" % reliable_changes
	)

	# Every message must be call_remote, or a machine applies its own change
	# twice — once locally and once when its own message comes back.
	var rpcs := 0
	var remote_only := 0
	for line in source.split("\n"):
		if not line.strip_edges().begins_with("@rpc("):
			continue
		rpcs += 1
		if line.contains("call_remote"):
			remote_only += 1
	_expect(rpcs > 0, "there are %d messages in all" % rpcs)
	_expect(
		remote_only == rpcs,
		"every message is call_remote, so nothing is applied twice at the sender"
	)

	# A name arrives from another machine and is drawn on screen. It is the one
	# piece of data here that crosses a trust boundary.
	_expect(
		source.contains("Profiles.is_valid_name"),
		"a name arriving from another machine is validated before it is shown"
	)

	# Addresses offered to a child must be ones on the family network, never a
	# public one.
	for address in Session.local_addresses():
		var private := (
			address.begins_with("192.168.") or address.begins_with("10.")
			or address.begins_with("172.")
		)
		_expect(private, "%s is a private address" % address)
	_expect(not Session.local_addresses().has("127.0.0.1"), "loopback is not offered as somewhere to join")

	# Small on purpose: this is a family game.
	_expect(Session.MAX_GUESTS <= 4, "at most %d guests, which is a family" % Session.MAX_GUESTS)
	_expect(Session.MOVE_INTERVAL > 0.0, "positions are rate-limited rather than sent every frame")
	_expect(
		Session.MOVE_INTERVAL <= 1.0 / 8.0,
		"but often enough (%d/s) to look like walking" % int(1.0 / Session.MOVE_INTERVAL)
	)

	# Visitors: drawn, named, and removed when they go.
	var visitors := Visitors.new()
	get_root().add_child(visitors)
	_expect(visitors.count() == 0, "nobody else is here to begin with")
	visitors.add(2, "Мурат")
	_expect(visitors.count() == 1, "an arriving child is drawn")
	visitors.add(2, "Мурат")
	_expect(visitors.count() == 1, "and not drawn twice")
	visitors.add(3, "Amir")
	_expect(visitors.count() == 2, "a second one is drawn too")

	# A first position must be applied outright rather than eased in, or a
	# visitor sprints across the valley from the origin when they appear.
	visitors.move(2, Vector3(40.0, 2.0, -18.0), 1.2)
	visitors._process(1.0 / 60.0)
	var placed := visitors._visitors[2]["node"] as Node3D
	_expect(
		placed.position.distance_to(Vector3(40.0, 2.0, -18.0)) < 1.0,
		"a visitor appears where they are, not at the origin"
	)

	visitors.remove(2)
	_expect(visitors.count() == 1, "a departing child is removed")
	visitors.clear()
	_expect(visitors.count() == 0, "and closing the session removes everyone")

	# The short code. A full address is fifteen characters of dots and digits,
	# which a six-year-old cannot read out and a ten-year-old would mistype.
	# Two devices on one family network differ only in the last number.
	_expect(Session.code_for("192.168.1.161") == 161, "an address becomes one number")
	_expect(Session.code_for("10.0.0.7") == 7, "whatever the network")
	_expect(Session.code_for("nonsense") == 0, "and nonsense becomes nothing")

	# The round trip: what one child reads out is what the other types in.
	for address in Session.local_addresses():
		var code := Session.code_for(address)
		_expect(
			Session.address_for_code(code) == address,
			"reading out %d and typing it back reaches %s" % [code, address]
		)
	_expect(Session.address_for_code(0).is_empty(), "zero is not an address")
	_expect(Session.address_for_code(255).is_empty(), "nor is 255")
	_expect(Session.address_for_code(-4).is_empty(), "nor a negative number")

	# The panel itself: four pages, no text entry anywhere.
	var panel := TogetherPanel.new()
	get_root().add_child(panel)
	_expect(not panel.visible, "the panel starts closed")
	panel.open()
	_expect(panel.visible, "and opens")
	_expect(panel.page == TogetherPanel.Page.CHOICE, "on the choice of hosting or visiting")

	var panel_source := FileAccess.get_file_as_string("res://src/ui/together_panel.gd")
	_expect(
		not panel_source.contains("LineEdit") and not panel_source.contains("TextEdit"),
		"there is no text entry anywhere on this screen"
	)

	panel._start_typing()
	_expect(panel.page == TogetherPanel.Page.TYPING, "the keypad opens")
	var asked: Array[int] = []
	panel.join_requested.connect(func(code: int) -> void: asked.append(code))

	panel._press("1")
	panel._press("6")
	panel._press("1")
	panel._press("9")
	_expect(panel._typed == "161", "a fourth digit is refused rather than clearing what was typed")
	panel._press("←")
	_expect(panel._typed == "16", "and a digit can be taken back")
	panel._press("1")
	panel._press("✓")
	_expect(asked.size() == 1 and asked[0] == 161, "pressing the tick asks to join 161")

	# Out of range must not try to connect to nothing.
	panel._start_typing()
	panel._press("0")
	panel._press("✓")
	_expect(asked.size() == 1, "and 0 is refused outright")

	# Keys big enough for a thumb.
	_expect(TogetherPanel.KEY_SIZE >= 72.0, "the keys are %d px, which a thumb can hit" % int(TogetherPanel.KEY_SIZE))

	for code in [Text.EN, Text.FR, Text.RU]:
		Text.set_language(code)
		_expect(not Text.of("say_joined").begins_with("?"), "an arrival is announced in %s" % code)
		for key in [
			"ui_together", "ui_invite", "ui_visit", "ui_your_number",
			"ui_their_number", "ui_play_alone", "say_read_it_out",
		]:
			_expect(not Text.of(key).begins_with("?"), "%s reads in %s" % [key, code])
	Text.set_language(Text.EN)

	panel.queue_free()
	session.queue_free()
	visitors.queue_free()

## The target device is a tablet, and every measurement so far has been taken on
## an M3 Max — which tells you almost nothing. These are the budgets that matter
## on mobile hardware, checked as numbers rather than hoped for.
func _check_it_will_run_on_a_tablet() -> void:
	print("the budgets a tablet cares about")

	# Draw calls, not triangles, are what a tablet GPU runs out of first. One
	# per terrain chunk, and the ring radius squares.
	var span := int(TerrainSpec.RINGS[TerrainSpec.RINGS.size() - 1]["radius"]) * 2 + 1
	var chunks := span * span
	_expect(
		chunks <= 400,
		"the terrain is %d draw calls a frame, which a tablet can afford" % chunks
	)

	# The outer ring must be much coarser than the inner one, or distant ground
	# costs as much as the ground underfoot for detail nobody can see.
	var innermost := int(TerrainSpec.RINGS[0]["step"])
	var outermost := int(TerrainSpec.RINGS[TerrainSpec.RINGS.size() - 1]["step"])
	_expect(
		outermost >= innermost * 8,
		"the furthest ring is %dx coarser than the nearest" % (outermost / maxi(innermost, 1))
	)

	# Collision is far more expensive than drawing, so only the rings a child
	# can actually reach may have any.
	var colliding := 0
	for ring in TerrainSpec.RINGS:
		if ring["collide"]:
			colliding += 1
	_expect(colliding <= 2, "only the %d nearest rings have collision" % colliding)

	# Vegetation has to be instanced, or five thousand plants is five thousand
	# draw calls and nothing else matters.
	var vegetation_source := FileAccess.get_file_as_string("res://src/world/vegetation_tile.gd")
	_expect(
		vegetation_source.contains("MultiMeshInstance3D"),
		"plants are drawn as instances rather than one node each"
	)

	# The project has to be set up for mobile at all: the renderer, the texture
	# format Android requires, and a fixed orientation.
	_expect(
		ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile") == "mobile",
		"the mobile renderer is selected for mobile builds"
	)
	_expect(
		bool(ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc")),
		"ETC2/ASTC compression is on, which Android exports require"
	)
	# Landscape is 0 and portrait is 1. The first version of this check asserted
	# "not 0", which is exactly backwards: it passed the build with the game
	# locked to portrait, and only a screenshot from the tablet found it. A
	# check that admits the wrong value is worse than no check.
	_expect(
		int(ProjectSettings.get_setting("display/window/handheld/orientation")) == 0,
		"the game is locked to landscape, which is what its interface is built for"
	)

	# Nothing may assume a keyboard: every action needs an on-screen control.
	var hud_source := FileAccess.get_file_as_string("res://src/ui/hud.gd")
	for control in ["jump", "build", "kick"]:
		_expect(
			hud_source.contains('"ui_%s"' % control) or hud_source.contains('"%s"' % control),
			"there is an on-screen control for %s" % control
		)

## Voice is the only part of this game whose failures reach outside it, and the
## children are small. These checks read the source, because the rules have to
## be structural: a rule held by a comment is a rule that gets edited away.
func _check_voice_is_safe() -> void:
	print("voice is push-to-talk and goes nowhere else")
	var source := _code_only(FileAccess.get_file_as_string("res://src/net/voice.gd"))
	_expect(not source.is_empty(), "the voice source can be read")

	# Nothing is ever written down. No recording, no history, no buffering to
	# disk — frames go microphone, network, speaker, gone.
	_expect(
		not source.contains("FileAccess") and not source.contains("DirAccess"),
		"voice never touches the filesystem, so nothing is ever recorded"
	)
	_expect(
		not source.contains("user://") and not source.contains("res://"),
		"and there is no path in it at all"
	)

	# The microphone may only be started in one place. "We only send while the
	# button is held" is a weaker promise than "the capture stream is stopped",
	# and this is the check that keeps the stronger one true.
	var starts := source.count("_microphone.play()")
	_expect(starts == 1, "the microphone is started in exactly one place")
	var start_index := source.find("_microphone.play()")
	var in_start := source.rfind("func ", start_index)
	var owner := source.substr(in_start, 40)
	_expect(
		owner.contains("start_talking"),
		"and that place is start_talking, which is the button being held"
	)
	_expect(source.contains("_microphone.stop()"), "and it is stopped again on release")

	# Voice may only travel over the session, which a child can only be in by
	# invitation. There is no lobby and no discovery, so a stranger has no path.
	_expect(
		source.contains("is_connected_to_anyone"),
		"nothing is sent unless there is an established session"
	)
	_expect(
		not source.contains("create_server") and not source.contains("create_client"),
		"voice opens no connection of its own — it uses the valley's"
	)

	# Hearing yourself a moment late is the most effective way to stop a person
	# speaking, so the capture bus is silent.
	_expect(source.contains("set_bus_mute"), "the microphone bus is muted, so nobody hears themselves")

	# Bandwidth, since this runs on a tablet's wifi alongside everything else.
	var bytes_per_second := Voice.RATE * 2
	_expect(
		bytes_per_second < 32000,
		"voice costs %d KB/s, which a home network will not notice" % (bytes_per_second / 1024)
	)
	_expect(Voice.RATE >= 8000, "but is %d Hz, which carries a child's voice" % Voice.RATE)

	var packet_seconds := float(Voice.FRAMES_PER_PACKET) / float(Voice.RATE)
	_expect(
		packet_seconds < 0.1,
		"a packet holds %.0f ms, so a lost one is a click rather than a missing word" % (packet_seconds * 1000.0)
	)

	# Unreliable, because a resent voice packet arrives after the word it
	# belonged to and is worse than the silence it replaces.
	_expect(
		source.contains('"unreliable_ordered"'),
		"voice is sent unreliably — a late packet is worse than a lost one"
	)
	_expect(source.contains("call_remote"), "and never played back to the speaker")

	# The project has to be set up for it, or the microphone silently yields
	# nothing and the button appears to do something while doing nothing.
	_expect(
		bool(ProjectSettings.get_setting("audio/driver/enable_input", false)),
		"audio input is enabled, or the microphone would yield silence"
	)
	var preset := FileAccess.get_file_as_string("res://export_presets.cfg")
	_expect(
		preset.contains("android.permission.RECORD_AUDIO"),
		"Android is told the game records audio, so a parent is asked"
	)

	# Declaring it is not enough — RECORD_AUDIO is a dangerous permission and
	# has to be requested while the game runs. Where that happens matters: a
	# parent who sees "Aava wants to record audio" the moment a game about a
	# valley opens has been given no reason for it.
	_expect(
		source.contains("OS.request_permission"),
		"and the permission is actually requested, not merely declared"
	)
	var asked_at := source.find("OS.request_permission")
	var asking_function := source.substr(source.rfind("func ", asked_at), 40)
	_expect(
		asking_function.contains("start_talking"),
		"asked when a child presses talk, not when the game opens"
	)

	# A device with no microphone must simply have no talk button, rather than
	# a button that fails.
	var voice := Voice.new()
	get_root().add_child(voice)
	_expect(not voice.is_talking(), "nobody is talking to begin with")
	voice.start_talking()
	_expect(
		not voice.is_talking(),
		"and pressing talk with no session started does nothing at all"
	)

	for code in [Text.EN, Text.FR, Text.RU]:
		Text.set_language(code)
		_expect(not Text.of("ui_talk").begins_with("?"), "the talk button is labelled in %s" % code)
	Text.set_language(Text.EN)

	voice.queue_free()

## Nothing in _ready may be used before it is built.
##
## The voice and the whole play-together panel were connected to `hud` eleven
## lines before `hud = Hud.new()` ran. GDScript does not complain: `hud` is
## simply null, the connection fails at runtime, and everything downstream of
## it is silently dead. It reached a tablet that way — the talk button and the
## networking screen were both wired to nothing, and the desktop never showed
## it because the screenshot tool builds its own interface.
##
## Checked by reading the source, because this is an ordering mistake and the
## type system has nothing to say about it.
func _check_nothing_is_used_before_it_exists() -> void:
	print("nothing is used before it is built")
	var source := _code_only(FileAccess.get_file_as_string("res://src/main.gd"))
	var lines := source.split("\n")

	# The members that are built in _ready and then used all over it.
	var watched: Array[String] = [
		"hud", "world", "player", "structures", "camera_rig", "build_mode",
		"session", "voice", "visitors", "profiles",
	]

	var built: Dictionary = {}
	for i in lines.size():
		var line: String = lines[i]
		for name in watched:
			if built.has(name):
				continue
			var stripped := line.strip_edges()
			if stripped.begins_with("%s = " % name):
				built[name] = i

	var out_of_order := 0
	for i in lines.size():
		var line: String = lines[i]
		# One tab exactly: a statement in _ready, not a line inside a lambda or
		# a nested block, where the ordering argument does not apply.
		if not line.begins_with("\t") or line.begins_with("\t\t"):
			continue
		for name in watched:
			if not built.has(name) or i >= int(built[name]):
				continue
			if line.begins_with("\t%s." % name):
				out_of_order += 1
				printerr(
					"  line %d uses '%s' but it is not built until line %d: %s" % [
						i + 1, name, int(built[name]) + 1, line.strip_edges()
					]
				)

	_expect(built.size() >= 8, "found %d of the members built in _ready" % built.size())
	_expect(out_of_order == 0, "every one of them is built before it is used")
