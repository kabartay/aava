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
		"BuildKinds", "Structures", "BuildMode",
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
