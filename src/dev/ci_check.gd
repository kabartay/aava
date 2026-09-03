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
