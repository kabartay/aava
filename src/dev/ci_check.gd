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
	_check_ground_rejects_what_it_cannot_touch()
	_check_baking_on_threads_changes_nothing()
	_check_planting_on_threads_changes_nothing()
	_check_the_ponds_hold_water()
	_check_no_place_is_in_a_pit()
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
	await _check_the_valley_is_not_silent()
	_check_trees_are_capital()
	await _check_a_fire_needs_feeding()
	_check_a_house_is_worth_having()
	_check_every_part_has_an_icon()
	_check_walls_are_solid()
	await _check_context_buttons_never_overlap()
	_check_caring_pays()
	_check_animals_dont_drown()
	_check_animals_stay_on_the_ground()
	_check_trees_are_solid()
	_check_a_thrown_ball_comes_down_on_the_ring()
	_check_the_aim_shows_where_the_ball_goes()
	_check_animals_walk_round_the_playground()
	_check_animals_walk_on_their_legs()
	_check_nothing_hangs_in_the_air()
	_check_the_voices_bake_off_thread()
	_check_the_map_bakes_off_thread()
	_check_boats_float_on_the_pond()
	_check_nothing_is_built_on_the_playground()
	_check_the_cafe_serves()
	_check_the_pool_takes_a_ticket()
	_check_getting_off_a_mount_is_safe()
	_check_swimming_looks_like_swimming()
	_check_animals_are_solid()
	_check_a_dog_asks_for_a_stick()
	_check_water_sounds_and_looks_like_water()
	_check_every_wet_place_shows_water()
	_check_the_wind_moves_only_the_crown()
	_check_snow_lies_where_snow_lies()
	_check_the_far_country_is_there()
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
	_check_the_map_shows_the_valley()
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
	# Two questions, not one. The world as a whole has to have mountains in it,
	# and the part a child actually walks around in has to have some shape of
	# its own — a kilometre of billiard table with peaks on the horizon is still
	# a billiard table.
	var lowest := INF
	var highest := -INF
	for z in range(-900, 901, 60):
		for x in range(-900, 901, 60):
			var height := field.height_at(float(x), float(z))
			lowest = minf(lowest, height)
			highest = maxf(highest, height)
	var relief := highest - lowest
	if relief < 200.0:
		_fail("only %.0f m of relief across the whole world" % relief)
	else:
		_ok("%.0f m from the riverbed to the peaks" % relief)

	var valley_low := INF
	var valley_high := -INF
	for z in range(-400, 401, 30):
		for x in range(-400, 401, 30):
			var height := field.height_at(float(x), float(z))
			valley_low = minf(valley_low, height)
			valley_high = maxf(valley_high, height)
	var rolling := valley_high - valley_low
	if rolling < 60.0:
		_fail("only %.0f m of rise and fall inside the valley — it is a field" % rolling)
	else:
		_ok("%.0f m of rise and fall inside the valley itself" % rolling)

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
		var chunk := TerrainChunk.new(
			TerrainChunk.bake(field, Vector2i(0, 0), step, false), 0,
			StandardMaterial3D.new(), false
		)
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

## Two rejections that carry the cost of building ground, and one accuracy
## claim that pays for the cheaper of them.
##
## `Paths.touches_box` and `Pitch.touches_box` are what let a chunk skip
## asking, once per vertex, about a pitch and a path that are nowhere near it.
## If either ever answered "no" for a chunk that does contain one, the ground
## would quietly lose its markings — invisible in a check that only counts
## triangles, so it is asserted directly here.
func _check_ground_rejects_what_it_cannot_touch() -> void:
	print("a chunk asks about the pitch and the paths only where they are")
	var size := float(TerrainSpec.CHUNK_SIZE)

	# The pitch: its own chunk must admit it, and one far across the valley
	# must not.
	var pitch := Pitch.centre()
	_expect(
		Pitch.touches_box(pitch.x - size, pitch.z - size, pitch.x + size, pitch.z + size),
		"the pitch's own ground knows the pitch is there"
	)
	_expect(
		not Pitch.touches_box(pitch.x + 400.0, pitch.z + 400.0, pitch.x + 400.0 + size, pitch.z + 400.0 + size),
		"and ground four hundred metres away does not"
	)

	# The paths: every route's own midpoint must be admitted, or a path
	# vanishes from the ground it is drawn on.
	var admitted := true
	var i := 0
	while i < Paths.SEGMENTS.size():
		var mid_x := (Paths.SEGMENTS[i] + Paths.SEGMENTS[i + 2]) * 0.5
		var mid_z := (Paths.SEGMENTS[i + 1] + Paths.SEGMENTS[i + 3]) * 0.5
		i += 4
		if not Paths.touches_box(mid_x - 1.0, mid_z - 1.0, mid_x + 1.0, mid_z + 1.0):
			admitted = false
			printerr("  a path at (%.0f, %.0f) is rejected by its own box" % [mid_x, mid_z])
	_expect(admitted, "every route is admitted where it actually runs")
	_expect(
		not Paths.touches_box(900.0, 900.0, 900.0 + size, 900.0 + size),
		"and ground outside every route is rejected outright"
	)

	# Collision on a coarser ring is read between the heights already sampled
	# rather than asked of the field again — 4,225 queries that cost two thirds
	# of what such a chunk took to build. The surface a child stands on has to
	# stay within a hand's width of the true ground for that to be honest.
	var field := HeightField.new(20260903)
	var step := 2
	var grid := TerrainSpec.CHUNK_SIZE / step + 1
	var padded := grid + 2
	var origin_x := 2.0 * size
	var origin_z := 0.0
	var heights := field.fill_grid(
		origin_x - float(step), origin_z - float(step), float(step), padded
	)
	var last := padded - 2
	var worst := 0.0
	for z in TerrainSpec.CHUNK_SIZE + 1:
		var fz := float(z) / float(step)
		var gz0 := mini(int(fz), last - 1)
		var tz := fz - float(gz0)
		for x in TerrainSpec.CHUNK_SIZE + 1:
			var fx := float(x) / float(step)
			var gx0 := mini(int(fx), last - 1)
			var tx := fx - float(gx0)
			var row := (gz0 + 1) * padded + (gx0 + 1)
			var between := lerpf(
				lerpf(heights[row], heights[row + 1], tx),
				lerpf(heights[row + padded], heights[row + padded + 1], tx),
				tz
			)
			worst = maxf(worst, absf(between - field.height_at(origin_x + float(x), origin_z + float(z))))
	_expect(
		worst < 0.25,
		"collision read between sampled heights stays within %.2f m of the ground" % worst
	)


## Terrain is baked on worker threads now, which is only safe because reading
## the height field writes nothing back. That is an assumption about
## `FastNoiseLite`, about the lazily-cached camp level (primed in the
## constructor for exactly this reason), and about every static leaf the field
## consults. Assumptions of that shape fail silently and intermittently, so
## this asserts it directly: the same chunks baked three at a time on workers
## must come out byte-identical to baking them one at a time here.
func _check_baking_on_threads_changes_nothing() -> void:
	print("ground baked on threads is the same ground")
	var field := HeightField.new(20260903)

	var coords: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 1),
		Vector2i(2, 2), Vector2i(-3, 0), Vector2i(4, -2),
	]

	var alone: Array = []
	for coord in coords:
		alone.append(TerrainChunk.bake(field, coord, 1, true))

	# The same work, handed to the pool all at once.
	var together: Array = []
	together.resize(coords.size())
	var guard := Mutex.new()
	var tasks: Array[int] = []
	for i in coords.size():
		tasks.append(WorkerThreadPool.add_task(
			func() -> void:
				var baked := TerrainChunk.bake(field, coords[i], 1, true)
				guard.lock()
				together[i] = baked
				guard.unlock()
		))
	for task in tasks:
		WorkerThreadPool.wait_for_task_completion(task)

	var identical := true
	for i in coords.size():
		var one: Dictionary = alone[i]
		var many = together[i]
		if many == null:
			identical = false
			printerr("  chunk %s never came back from the pool" % coords[i])
			continue
		var a: Array = one["arrays"]
		var b: Array = many["arrays"]
		if a[Mesh.ARRAY_VERTEX] != b[Mesh.ARRAY_VERTEX]:
			identical = false
			printerr("  chunk %s has different vertices when baked in parallel" % coords[i])
		if a[Mesh.ARRAY_COLOR] != b[Mesh.ARRAY_COLOR]:
			identical = false
			printerr("  chunk %s has different colours when baked in parallel" % coords[i])
		if one["collision"] != many["collision"]:
			identical = false
			printerr("  chunk %s has different collision when baked in parallel" % coords[i])
	_expect(identical, "%d chunks baked in parallel match the same chunks baked alone" % coords.size())

## A pond is two things that have to agree: a hole the height field digs, and
## water the shader draws over it. They did not agree at all — the shader chose
## where water went by distance from the river, so both ponds were dry craters
## a child could walk into and stand at the bottom of. Nothing caught it,
## because every check here asks the height field and the height field was
## right.
func _check_the_ponds_hold_water() -> void:
	print("the ponds hold water")
	var field := HeightField.new(20260903)

	var i := 0
	var index := 0
	while i < Lakes.PONDS.size():
		var cx := Lakes.PONDS[i]
		var cz := Lakes.PONDS[i + 1]
		var long_axis := Lakes.PONDS[i + 2]
		var short_axis := Lakes.PONDS[i + 3]
		i += Lakes.POND_STRIDE
		index += 1

		_expect(
			field.height_at(cx, cz) < HeightField.WATER_LEVEL - 1.0,
			"pond %d is dug below the waterline (%.1f m)" % [index, field.height_at(cx, cz)]
		)
		_expect(
			Lakes.influence(cx, cz) > 0.95,
			"pond %d is deepest at its own centre" % index
		)
		_expect(
			long_axis > short_axis * 1.15,
			"pond %d is an oval rather than a circle (%.0f by %.0f m)" % [
				index, long_axis * 2.0, short_axis * 2.0
			]
		)

		# Open water, measured rather than assumed: the bank shelves up, so the
		# basin is always wider than the water in it.
		var wet_metres := 0
		for step in range(-60, 61):
			if field.height_at(cx + float(step), cz) < HeightField.WATER_LEVEL:
				wet_metres += 1
		_expect(
			wet_metres >= 12,
			"pond %d has %d m of open water across, which is a pond and not a puddle" % [
				index, wet_metres
			]
		)

		# Far enough from the river to read as its own water.
		_expect(
			field.distance_to_river(cx, cz) > 40.0,
			"pond %d is its own water, %d m from the river" % [
				index, int(field.distance_to_river(cx, cz))
			]
		)

		# And nothing grows in it.
		_expect(Lakes.wet(cx, cz), "nothing is planted in pond %d" % index)

	# The half of this the height field cannot see: the sheet has to be told
	# where the ponds are, or the holes stay empty.
	var water_source := _code_only(FileAccess.get_file_as_string("res://src/world/water.gd"))
	_expect(
		water_source.contains("pond_blend"),
		"the water shader has a shape for still water, not only the river"
	)
	_expect(
		water_source.contains("Lakes.PONDS"),
		"and it takes that shape from Lakes rather than keeping its own copy"
	)
	_expect(
		water_source.contains("pond_place") and water_source.contains("pond_turn"),
		"every pond's place and angle reaches the shader"
	)

## An animal that stands still must stay on the ground.
##
## The idle bob was added to the animal's height every frame, while the ground
## was only read again on frames the animal was walking. Standing still for the
## few seconds animals rest for meant sixty small additions a second with
## nothing to correct them, and they rose into the air — reported from the
## phone as animals flying.
func _check_animals_stay_on_the_ground() -> void:
	print("an animal standing still stays on the ground")
	var field := HeightField.new(20260903)
	var animals := Animals.new(field, 20260903)
	get_root().add_child(animals)

	var at := field.camp_centre()
	at.y = field.height_at(at.x, at.z)
	var node := Node3D.new()
	get_root().add_child(node)
	node.position = at

	var resting := {
		"kind": AnimalKinds.CAT,
		"node": node,
		"home": at,
		# Already where it wants to be, so it rests rather than walks.
		"target": at,
		"tile": Vector2i(0, 0),
		"rest": 1e9,
		"cooldown": 0.0,
		"bob": 0.0,
	}

	# Two minutes of standing still, at sixty frames a second.
	for _frame in 7200:
		animals._step(resting, 1.0 / 60.0)

	var drift := absf(node.position.y - field.height_at(at.x, at.z))
	_expect(
		drift < 0.1,
		"after two minutes of standing it is %.3f m from the ground" % drift
	)

	node.queue_free()
	animals.queue_free()

## A tree you can walk through is scenery.
##
## The forest is instanced — thousands of trees in a few draw calls, which is
## the only way a tablet draws a wood — and instances carry no collision, so
## every trunk in the valley was walk-through until someone on the phone walked
## into one. A pool of trunk-shaped bodies follows the player instead.
## A thrown basketball has to arrive: the throw solves for a launch velocity
## under gravity and drag, and this integrates the flight the way the physics
## server does — gravity, then drag as a per-step factor — to see that the
## ball is at the ring when the flight time runs out.
func _check_a_thrown_ball_comes_down_on_the_ring() -> void:
	print("a thrown basketball comes down on the ring")
	var ball := Ball.new(Vector3(0.0, Ball.RADIUS, 0.0), Ball.Look.BASKETBALL)
	var ring := Vector3(6.0, 3.3, 1.5)
	var launch := ball.throw_to(ring, 1.0)
	_expect(launch.y > 0.0, "the ball leaves upwards")
	var gravity := Vector3(0.0, -ball.gravity_strength(), 0.0)
	var damp := ball.effective_linear_damp()
	_expect(damp > 0.3, "the air drags on the ball (damp %.2f), so the throw must allow for it" % damp)
	var step := 1.0 / 240.0
	var at := ball.position
	var velocity := launch
	var nearest := 1e9
	var peak := at.y
	for _i in int(2.0 / step):
		velocity += gravity * step
		velocity *= maxf(0.0, 1.0 - damp * step)
		at += velocity * step
		peak = maxf(peak, at.y)
		nearest = minf(nearest, at.distance_to(ring))
	_expect(nearest < 0.15, "the throw passes within %.2f m of the ring" % nearest)
	_expect(peak > ring.y + 0.4, "and comes down on it from above (apex %.1f m over the ring)" % (peak - ring.y))
	ball.free()

## A cat walked through the slide and the hedge, because nothing told the
## animals where either was. The places now publish what must be walked round,
## and an animal steers past it — this sends one straight at the trampoline
## and asserts it never ends up inside anything, and still gets somewhere.
func _check_animals_walk_round_the_playground() -> void:
	print("animals walk round the playground")
	var field := HeightField.new(20260903)
	var places := Places.new(field)
	get_root().add_child(places)
	places.stand_up(field.camp_centre())
	var spot: Vector3 = places._spots[Places.PLAYGROUND]
	_expect(places.obstacle_count() > 20, "the playground publishes %d things to walk round" % places.obstacle_count())
	var slide_mid: Vector3 = spot + Places.SLIDE_TOP.lerp(Places.SLIDE_FOOT, 0.5)
	_expect(places.obstructed(slide_mid.x, slide_mid.z), "the middle of the slide is not somewhere to stand")
	var clear := spot + Vector3(-3.5, 0.0, 4.0)
	_expect(not places.obstructed(clear.x, clear.z), "the open ground between the swings and the benches is")
	_expect(places.obstructed(spot.x, spot.z + Places.HEDGE_RADIUS), "the hedge is solid to an animal")
	_expect(not places.obstructed(spot.x + Places.HEDGE_RADIUS, spot.z), "except at its openings")
	var before := spot + Places.TRAMPOLINE + Vector3(0.0, 0.0, Places.TRAMPOLINE_RADIUS + 1.2)
	var push := places.steer_around(before, Vector3.FORWARD, Vector3.FORWARD)
	_expect(push.length() > 0.1 and push.z > 0.0, "walking at the trampoline, an animal is pushed back and aside")
	_expect(places.steer_around(before, Vector3.BACK, Vector3.BACK).length() < 0.001, "and not by something behind it")

	var animals := Animals.new(field, 20260903)
	animals.obstacles = places
	get_root().add_child(animals)
	var node := MeshInstance3D.new()
	animals.add_child(node)
	var start := spot + Places.TRAMPOLINE + Vector3(0.0, 0.0, Places.TRAMPOLINE_RADIUS + 3.0)
	start.y = field.height_at(start.x, start.z)
	var goal := spot + Places.TRAMPOLINE + Vector3(0.0, 0.0, -(Places.TRAMPOLINE_RADIUS + 3.0))
	goal.y = field.height_at(goal.x, goal.z)
	node.position = start
	var walker := {
		"kind": &"cat", "node": node, "home": start, "target": goal, "tile": Vector2i.ZERO,
		"rest": 99.0, "cooldown": 0.0, "bob": 0.0, "heading": PI, "velocity": 0.0, "speed": Animals.SPEED,
	}
	var ever_inside := false
	var closest := 1e9
	var jerkiest := 0.0
	var last_heading := float(walker["heading"])
	for _frame in 900:
		animals._step(walker, 1.0 / 60.0)
		if places.obstructed(node.position.x, node.position.z):
			ever_inside = true
		closest = minf(closest, Vector2(node.position.x - goal.x, node.position.z - goal.z).length())
		jerkiest = maxf(jerkiest, absf(angle_difference(last_heading, float(walker["heading"]))))
		last_heading = float(walker["heading"])
	_expect(not ever_inside, "in fifteen seconds of walking at the trampoline the cat never stood in it")
	_expect(closest < 3.5, "and got round it to within %.1f m of where it wanted to go" % closest)
	# The about-face at the start is the sharpest moment, some fourteen degrees
	# in its first frame; a snap would be a hundred and eighty.
	_expect(jerkiest < deg_to_rad(20.0), "turning no more than %.0f degrees in a frame: a curve, not a snap" % rad_to_deg(jerkiest))
	animals.queue_free()
	places.queue_free()

## The voices are synthesised on a worker thread now; they must still all
## arrive, and be silent rather than crash before they do.
func _check_the_voices_bake_off_thread() -> void:
	print("the voices bake off the main thread")
	var voices := AnimalVoices.new()
	get_root().add_child(voices)
	voices.speak(&"cat", Vector3.ZERO)
	voices.bake_now()
	var made := voices.voices()
	for kind: StringName in [&"dog", &"squirrel", &"beaver", &"cat", &"cat_short", &"cat_purr"]:
		_expect(made.has(kind), "the %s has a voice" % kind)
	var purr: AudioStreamWAV = voices._sounds[&"cat_purr"]
	_expect(purr.data.size() > AnimalVoices.RATE * 2, "the purr lasts over a second")
	# The players are what actually make the sound; an edit once stranded
	# their construction after a return and every animal went silent.
	_expect(voices._players.size() == AnimalVoices.VOICES, "and there are %d players to play them" % voices._players.size())
	voices.queue_free()

## The map is baked on a worker thread; it must still arrive, and every
## destination must be on it — on the rim, pointing, when it is off the map.
func _check_the_map_bakes_off_thread() -> void:
	print("the map bakes off the main thread")
	var field := HeightField.new(20260903)
	var map := Minimap.new(field)
	get_root().add_child(map)
	map.show_map()
	var camp := field.camp_centre()
	map.track(camp, 0.0, [] as Array[Vector3])
	_expect(not map.is_drawn(), "the picture is not there the instant it is asked for")
	map.wait_for_bake()
	map.track(camp, 0.0, [] as Array[Vector3])
	_expect(map.is_drawn(), "and is once the bake is collected")
	_expect(map._destinations.size() == 6, "six destinations are marked")
	var home: PlaceGlyph = map._destinations[0]["glyph"]
	var playground: PlaceGlyph = map._destinations[1]["glyph"]
	_expect(not home.pointing, "standing at the camp, home is on the map itself")
	_expect(playground.pointing, "and the playground, four hundred metres off, is on the rim pointing at itself")
	var to_playground := Vector2(PlaceSpec.OFFSETS[&"playground"].x, PlaceSpec.OFFSETS[&"playground"].z).angle()
	_expect(absf(angle_difference(playground.angle, to_playground)) < 0.05, "in the right direction")
	map.queue_free()

## Five boats wait round the big pond, in wading depth, and a boat goes where
## there is water under it and nowhere else — which is how it lands a child on
## the far shore.
func _check_boats_float_on_the_pond() -> void:
	print("boats float on the pond")
	var field := HeightField.new(20260903)
	var mounts := Mounts.new(field)
	get_root().add_child(mounts)
	mounts.launch_boats(0, 5)
	_expect(mounts.boat_count() == 5, "%d boats wait at the pond" % mounts.boat_count())
	_expect(MountKinds.kind_of(MountKinds.boat_id(3)) == MountKinds.BOAT, "a boat's id names its kind")
	_expect(MountKinds.boat_index(MountKinds.boat_id(3)) == 3, "and which boat it is")
	_expect(MountKinds.boat_index(MountKinds.HORSE) == -1, "a horse is not a boat")
	_expect(MountKinds.floats(MountKinds.boat_id(0)) and not MountKinds.floats(MountKinds.HORSE), "boats float; horses do not")
	_expect(is_equal_approx(MountKinds.speed(MountKinds.boat_id(1)), MountKinds.speed(MountKinds.BOAT)), "every boat is as fast as a boat")
	var colours: Dictionary = {}
	var afloat := true
	var wadeable := true
	var apart := true
	var spots: Array[Vector3] = []
	for i in 5:
		var id := MountKinds.boat_id(i)
		colours[str(MountKinds.colour(id))] = true
		var at := mounts.position_of(id)
		var ground := field.height_at(at.x, at.z)
		if not is_equal_approx(at.y, HeightField.WATER_LEVEL):
			afloat = false
		if ground > HeightField.WATER_LEVEL - 0.35 or ground < HeightField.WATER_LEVEL - 1.05:
			wadeable = false
			printerr("  boat %d sits over ground %.2f m below the water" % [i, HeightField.WATER_LEVEL - ground])
		for other in spots:
			if other.distance_to(at) < 8.0:
				apart = false
		spots.append(at)
	_expect(colours.size() == 5, "five boats, five colours")
	_expect(afloat, "every boat rests on the waterline")
	_expect(wadeable, "each in water a child can wade out to, not swim to")
	_expect(apart, "and they are spread round the shore, not heaped in one cove")

	var centre := Vector3(Lakes.PONDS[0], 0.0, Lakes.PONDS[1])
	_expect(mounts.can_ride_over(MountKinds.boat_id(0), centre), "a boat can be rowed across the middle of the pond")
	var meadow := centre + Vector3(Lakes.PONDS[2] * 2.0, 0.0, 0.0)
	_expect(not mounts.can_ride_over(MountKinds.boat_id(0), meadow), "and not across the meadow beyond it")
	# Left in the shallows on the far side, it floats there rather than
	# sitting on the bed.
	_expect(mounts.mount(MountKinds.boat_id(0)), "a boat can be boarded")
	var shallows := spots[2]
	mounts.dismount(shallows)
	_expect(is_equal_approx(mounts.position_of(MountKinds.boat_id(0)).y, HeightField.WATER_LEVEL), "and floats where it is left")
	# Saved and restored by id, so five boats come back as five boats.
	var restored := Mounts.new(field)
	get_root().add_child(restored)
	restored.from_data(mounts.to_data())
	_expect(restored.boat_count() == 5, "five boats come back from a save")
	restored.queue_free()
	mounts.queue_free()

## A sapling planted beside the trampoline grew into a tree standing in it.
## The places keep their ground now: building there is refused, and anything
## already built there when a save is loaded is moved just outside.
func _check_nothing_is_built_on_the_playground() -> void:
	print("nothing is built on the playground")
	var field := HeightField.new(20260903)
	var camp := field.camp_centre()
	var pad := PlaceSpec.centre_of(&"playground", camp)
	_expect(PlaceSpec.reserved(pad.x - 3.5, pad.z - 8.0, camp), "the ground under the trampoline is kept")
	_expect(PlaceSpec.reserved(pad.x, pad.z + Places.HEDGE_RADIUS, camp), "so is the hedge")
	_expect(not PlaceSpec.reserved(pad.x + 30.0, pad.z, camp), "thirty metres out is not")
	_expect(not PlaceSpec.reserved(camp.x, camp.z, camp), "and the camp is a child's own")
	var free := PlaceSpec.nearest_free(pad.x - 3.5, pad.z - 8.0, camp)
	_expect(not PlaceSpec.reserved(free.x, free.z, camp), "the nearest free ground is outside the pad")
	_expect(Vector2(free.x - pad.x, free.z - pad.z).length() < PlaceSpec.RADIUS[&"playground"] + 3.0, "and only just")

	var structures := Structures.new(field)
	get_root().add_child(structures)
	structures.from_data([
		{"kind": String(BuildKinds.SAPLING), "x": pad.x - 4.0, "y": pad.y, "z": pad.z - 5.0, "spin": 0.0, "age": 150.0},
		{"kind": String(BuildKinds.SAPLING), "x": pad.x - 25.0, "y": pad.y, "z": pad.z - 7.0, "spin": 0.0, "age": 150.0},
	])
	var positions := structures.positions()
	_expect(positions.size() == 2, "both saplings survive the load")
	var on_pad := 0
	for at in positions:
		if PlaceSpec.reserved(at.x, at.z, camp):
			on_pad += 1
	_expect(on_pad == 0, "and neither stands on the playground any more")
	var still_far := false
	for at in positions:
		if absf(at.x - (pad.x - 25.0)) < 0.01 and absf(at.z - (pad.z - 7.0)) < 0.01:
			still_far = true
	_expect(still_far, "the one that was outside was left where it was")
	structures.queue_free()

	_expect(Text.of("why_reserved") != "", "and there is a word for why not")

## The café could be walked through, and three coins bought a word. It is
## solid now, and a paid-for meal is a thing on the bar that steams and is
## cleared away.
func _check_the_cafe_serves() -> void:
	print("the café serves")
	var field := HeightField.new(20260903)
	var places := Places.new(field)
	get_root().add_child(places)
	places.stand_up(field.camp_centre())
	var spot: Vector3 = places._spots[Places.CAFE]
	_expect(places.cafe_solid_count() >= 30, "the café has %d solid pieces: walls, bar, stools, tables, chairs, sofa" % places.cafe_solid_count())
	_expect(places._cafe_solid.collision_layer == TerrainSpec.LAYER_PROPS, "the furniture on the props layer, so the camera passes it")
	_expect(places.cafe_wall_count() == 7, "%d walls and a ceiling on the walls layer as well" % places.cafe_wall_count())
	_expect((places._cafe_walls.collision_layer & TerrainSpec.LAYER_WALLS) != 0, "which the camera does not pass")
	var wall_probe := CameraRig.new(Player.new())
	_expect((wall_probe._arm.collision_mask & TerrainSpec.LAYER_WALLS) != 0, "because its arm stops at walls")
	_expect((wall_probe._arm.collision_mask & TerrainSpec.LAYER_PROPS) == 0, "and still not at furniture")
	wall_probe.free()
	_expect(places.cafe_seat_count() == 15, "%d seats: three stools, six chairs inside, two on the sofa, four on the terrace" % places.cafe_seat_count())
	var inside := spot + Places.CAFE_TABLES[0]
	_expect(places.nearest(inside) == Places.CAFE, "a child at a table inside is offered a meal")
	_expect(places.nearest(spot + Places.CAFE_TERRACE[0]) == Places.CAFE, "and one at a terrace table")
	_expect(places.nearest(spot + Vector3(0.0, 0.0, -16.0)) == &"", "not one sixteen metres off")
	_expect(places.obstructed(spot.x, spot.z + Places.CAFE_MID_Z), "the building is not somewhere an animal walks")
	_expect(not places.obstructed(spot.x, spot.z - 12.0), "the ground beyond the terrace is")
	# The door is a way in: the ground in the doorway is not a wall.
	var door := spot + Vector3(0.0, 0.0, Places.CAFE_MID_Z - Places.CAFE_DEPTH * 0.5)
	var doorway_blocked := false
	for shape in places._cafe_solid.get_children() + places._cafe_walls.get_children():
		var collider := shape as CollisionShape3D
		if collider == null or not (collider.shape is BoxShape3D):
			continue
		var box := collider.shape as BoxShape3D
		var local := collider.transform.origin
		if absf(local.z - (door.z - spot.z)) < 0.3 and absf(local.x) < box.size.x * 0.5 and local.y - box.size.y * 0.5 < 1.0:
			doorway_blocked = true
	_expect(not doorway_blocked, "and nothing solid stands in the doorway below head height")
	_expect(places.meals_served() == 0, "nothing on the tables before anyone orders")
	var seat := places.serve_meal(inside + Vector3(1.0, 0.0, 0.0))
	_expect(places.meals_served() == 1, "a paid-for meal appears")
	_expect(not seat.is_empty() and seat["seat"].distance_to(inside + Vector3(1.05, 0.45, 0.0)) < 0.01, "at the chair the child stood by")
	_expect(is_equal_approx(float(seat["facing"]), PI * 0.5), "facing the table")
	var far := places.serve_meal(spot + Vector3(0.0, 0.0, -20.0))
	_expect(far.is_empty(), "a child too far from any seat is not sat down")
	places._tick(1.0)
	_expect(places.meals_served() == 2, "and both meals are still there a second later")
	places._tick(Places.MEAL_SHOWN)
	_expect(places.meals_served() == 0, "and cleared away when they have been eaten")
	places.queue_free()

## The dotted arc shown while winding up must be the kick's own arithmetic,
## or it lies: the predicted path has to start where the ball is, rise, come
## down, and stop at the ground.
func _check_the_aim_shows_where_the_ball_goes() -> void:
	print("the aim shows where the ball goes")
	var ball := Ball.new(Vector3(4.0, Ball.RADIUS, 0.0), Ball.Look.FOOTBALL)
	var striker := Vector3(2.0, 0.0, 0.0)
	var launch := Ball.launch_velocity(ball.position, striker, Vector3.FORWARD, false, 0.7, 0.6)
	_expect(launch.x > 0.0 and absf(launch.z) < 0.01, "a kick goes along the line from the striker to the ball, not the way they face")
	_expect(launch.y > 0.0, "and lofted, it rises")
	var speed := ball.kick(striker, Vector3.FORWARD, false, 0.7, 0.6)
	_expect(is_equal_approx(speed, launch.length()), "the kick itself uses the same numbers (%.1f m/s)" % speed)
	var ground := func(_x: float, _z: float) -> float:
		return 0.0
	var path := Ball.predict(Vector3(4.0, Ball.RADIUS, 0.0), launch, ball.effective_linear_damp(), ball.gravity_strength(), 3.0, 0.09, ground)
	_expect(path.size() > 6, "the path has %d dots in it" % path.size())
	var peak := 0.0
	for point in path:
		peak = maxf(peak, point.y)
	_expect(peak > 1.0, "rises to %.1f m" % peak)
	_expect(is_equal_approx(path[path.size() - 1].y, Ball.RADIUS), "and ends on the ground")
	_expect(path[path.size() - 1].x > 8.0, "%.0f m away" % path[path.size() - 1].x)
	var preview := KickPreview.new()
	preview.show_path(path)
	_expect(preview.dots_shown() == path.size(), "and every dot of it is drawn")
	preview.hide_path()
	_expect(preview.dots_shown() == 0, "until the button is let go")
	preview.free()
	ball.free()

## An animal's legs are nodes hung from its hips, and swing as it walks: a
## dog carried across a meadow must move its legs, and a dog stood still must
## not.
func _check_animals_walk_on_their_legs() -> void:
	print("animals walk on their legs")
	for kind in AnimalKinds.ALL:
		var node := AnimalKinds.build_node(kind)
		var body := node.get_node("Body") as MeshInstance3D
		_expect(body != null and body.get_child_count() == 4 and body.mesh != null, "the %s has a body and four legs" % kind)
		_expect(AnimalKinds.hips(kind).size() == 4, "hung from four hips")
		node.free()
	var field := HeightField.new(20260903)
	var animals := Animals.new(field, 20260903)
	get_root().add_child(animals)
	var dog := AnimalKinds.build_node(AnimalKinds.DOG)
	animals.add_child(dog)
	var start := Vector3(0.0, field.height_at(0.0, 0.0), 0.0)
	dog.position = start
	var walker := {
		"kind": AnimalKinds.DOG, "node": dog, "home": start, "target": start + Vector3(0.0, 0.0, -30.0),
		"tile": Vector2i.ZERO, "rest": 99.0, "cooldown": 0.0, "bob": 0.0, "heading": 0.0, "velocity": 0.0, "speed": Animals.SPEED,
	}
	var swung := 0.0
	for _frame in 90:
		animals._step(walker, 1.0 / 60.0)
		for i in 4:
			swung = maxf(swung, absf((dog.get_node("Body/Leg%d" % i) as Node3D).rotation.x))
	_expect(swung > 0.15, "walking, the dog swings its legs (%.0f degrees at most)" % rad_to_deg(swung))
	walker["target"] = dog.position
	for _frame in 120:
		animals._step(walker, 1.0 / 60.0)
	var still := 0.0
	for i in 4:
		still = maxf(still, absf((dog.get_node("Body/Leg%d" % i) as Node3D).rotation.x))
	_expect(still < 0.03, "and standing, they hang straight (%.1f degrees)" % rad_to_deg(still))
	animals.queue_free()

## The pool beside the pitch: fenced, entered through a turnstile that costs
## coins and opens for a while, and lets a child inside straight out.
func _check_the_pool_takes_a_ticket() -> void:
	print("the pool takes a ticket")
	var field := HeightField.new(20260903)
	var places := Places.new(field)
	get_root().add_child(places)
	places.stand_up(field.camp_centre())
	var spot: Vector3 = places._spots[Places.POOL]
	var pitch := Pitch.centre()
	# Off the pitch's long side, not beyond a goal, and three times the ten
	# metres it first stood at.
	var gap := absf(pitch.z - spot.z) - Pitch.HALF_WIDTH - Places.POOL_HALF_Z
	_expect(gap > 26.0 and gap < 34.0, "the pool lies %.0f m off the pitch's touchline" % gap)
	_expect(absf(pitch.x - spot.x) < Pitch.HALF_LENGTH + 6.0, "alongside it rather than behind a goal")
	_expect(Places.POOL_HALF_X > Places.POOL_HALF_Z, "with its long side along the pitch's own")
	_expect(Places.POOL_HALF_X == 14.0 and Places.POOL_HALF_Z == 9.0, "and is seven tenths of the pitch each way")
	_expect(places.water_depth_at(spot.x + 10.0, spot.z) > Player.SWIM_DEPTH, "deep enough to swim in ten metres along it")
	_expect(is_zero_approx(places.water_depth_at(spot.x + Places.POOL_HALF_X + 1.0, spot.z)), "and dry just past its rim")
	# The brim, not the floor: everything the pool is built from hangs off
	# this, and taken from the floor the fence and the water sat in the hole.
	var floor_height := field.height_at(spot.x, spot.z)
	_expect(
		is_equal_approx(spot.y, floor_height + PlaceSpec.POOL_DEPTH),
		"the pool's own level is its brim %.1f m above the floor of it" % (spot.y - floor_height)
	)
	_expect(
		spot.y > field.height_at(spot.x + Places.POOL_FENCE_X + 2.0, spot.z) - 0.6,
		"which stands with the ground round it, not below it"
	)
	_expect(places.pool_solid_count() >= 11, "%d solid pieces: fence, booth, block, loungers, lamps" % places.pool_solid_count())
	# Nothing at the poolside may touch the fence or hang over the water: the
	# loungers were laid across a three-metre gap, two metres long, and stuck
	# out through the railings.
	var roomy := true
	var dry := true
	for lounger in Places.POOL_LOUNGERS:
		var half := Places.POOL_LOUNGER_SIZE * 0.5
		var to_fence_x := Places.POOL_FENCE_X - (absf(lounger.x) + half.x)
		var to_fence_z := Places.POOL_FENCE_Z - (absf(lounger.z) + half.z)
		if to_fence_x < Places.POOLSIDE_CLEARANCE or to_fence_z < Places.POOLSIDE_CLEARANCE:
			roomy = false
			printerr("  a lounger comes within %.2f m of the fence" % minf(to_fence_x, to_fence_z))
		if absf(lounger.z) - half.z < Places.POOL_HALF_Z + 0.2:
			dry = false
			printerr("  a lounger overhangs the water")
	_expect(roomy, "the loungers stand clear of the fence")
	_expect(dry, "and beside the water rather than over it")
	var gate := spot + Vector3(Places.POOL_FENCE_X, 0.0, 0.0)
	_expect(places.at_turnstile(gate + Vector3(1.5, 0.0, 0.0)), "a child a stride outside the gate is at the turnstile")
	_expect(not places.at_turnstile(gate + Vector3(8.0, 0.0, 0.0)), "one eight metres off is not")
	_expect(not places.inside_pool_fence(gate + Vector3(1.5, 0.0, 0.0)), "and is outside the fence")
	_expect(places.inside_pool_fence(spot), "while the middle of the pool is inside it")
	_expect(not places.turnstile_open(), "the turnstile starts shut")
	_expect(places._turnstile.collision_layer == TerrainSpec.LAYER_PROPS, "and solid")
	places.open_turnstile()
	_expect(places.turnstile_open() and places._turnstile.collision_layer == 0, "paid for, it opens and lets a child through")
	places._tick(Places.TURNSTILE_OPEN + 0.5)
	_expect(not places.turnstile_open() and places._turnstile.collision_layer == TerrainSpec.LAYER_PROPS, "and shuts again after %.0f seconds" % Places.TURNSTILE_OPEN)
	_expect(Places.POOL_TICKET == 5, "a ticket costs five coins")
	_expect(Text.of("say_ticket").contains("%d") and Text.of("say_welcome_pool") != "", "and the price and the welcome have words")
	places.queue_free()

## Nothing a child looks at may hang in the air.
##
## Two bugs of the same kind shipped within an hour of each other: the
## horse's head and tail, drawn relative to a joint and then moved to that
## joint again, floated half a metre off it; and its tail's two halves were
## placed at two chosen points that did not meet, so the end of it trailed
## behind unattached. Neither was visible to any check — the meshes were
## built, the counts were right, and only an eye on the phone could see it.
##
## So this looks at the geometry itself. Every mesh that makes up an animal
## or a mount must be one connected lump of vertices, and every part hung as
## a node of its own must touch the body it hangs from.
func _check_nothing_hangs_in_the_air() -> void:
	print("nothing hangs in the air")

	# One connected lump: vertices are dropped into a coarse grid and the
	# cells joined to their neighbours, which is enough to tell a tail that
	# meets its dock from one that floats a hand's width behind it.
	var pieces: Dictionary = {
		"the horse's body": MountKinds.horse_part("body"),
		"its head": MountKinds.horse_part("head"),
		"its tail": MountKinds.horse_part("tail"),
		"its leg": MountKinds.horse_leg(),
		"the whole horse in one mesh": MountKinds.build_mesh(MountKinds.HORSE),
		"the bicycle": MountKinds.build_mesh(MountKinds.BICYCLE),
		"a boat": MountKinds.build_mesh(MountKinds.boat_id(0)),
	}
	for kind in AnimalKinds.ALL:
		pieces["the %s" % kind] = AnimalKinds.body_mesh(kind)
		pieces["the %s's leg" % kind] = AnimalKinds.leg_mesh(kind, false)
	for name in pieces:
		var lumps := _count_lumps(pieces[name])
		_expect(lumps == 1, "%s is one lump, not %d" % [name, lumps])
	# And the counting can see a gap when there is one, or every line above
	# is a check that cannot fail.
	_expect(_count_lumps(_a_mesh_in_two_pieces(0.25)) == 2, "and a quarter of a metre of air is seen as a gap")
	_expect(_count_lumps(_a_mesh_in_two_pieces(0.6)) == 2, "as is half a metre of it")

	# And every moving part must touch the body it hangs from, or it is a
	# head floating beside a horse.
	var field := HeightField.new(20260903)
	var mounts := Mounts.new(field)
	get_root().add_child(mounts)
	mounts.place(MountKinds.HORSE, Vector3.ZERO)
	_expect(_parts_touch_the_body(mounts._nodes[MountKinds.HORSE], "horse"), "every part of the horse touches it")
	mounts.queue_free()
	for kind in AnimalKinds.ALL:
		var node := AnimalKinds.build_node(kind)
		_expect(_parts_touch_the_body(node, kind), "every leg of the %s touches it" % kind)
		node.free()

	# The tail's own chain: each piece starts where the last one ended, and
	# the root of it sits inside the rump rather than behind it.
	var joints := MountKinds.horse_tail_joints()
	_expect(joints.size() >= 4, "the tail is a chain of %d joints" % (joints.size() - 1))
	var root: Vector3 = MountKinds.HORSE_TAIL_PIVOT + joints[0]
	_expect(
		root.distance_to(MountKinds.HORSE_RUMP_CENTRE) < MountKinds.HORSE_RUMP_RADIUS,
		"and grows out of the rump, %.2f m inside its surface" % (MountKinds.HORSE_RUMP_RADIUS - root.distance_to(MountKinds.HORSE_RUMP_CENTRE))
	)
	var falls := true
	for i in range(1, joints.size()):
		if joints[i].z <= joints[i - 1].z:
			falls = false
	_expect(falls, "and every joint of it lies further back than the last")

## How many separate lumps of geometry a mesh is made of.
##
## The surface of every triangle is sampled at half the grid step and the
## cells joined to their twenty-six neighbours; a mesh whose parts touch or
## overlap comes back as one. Sampling the surface rather than the vertices
## is the whole trick: a plank two metres long has eight corners and nothing
## in between, so a vertex-only version reported a boat as fourteen pieces.
##
## Calibrated: at a 0.15 m grid every mesh in the game is one lump, and two
## balls with a quarter of a metre of air between them are two — which is
## finer than any gap that has actually shipped.
const LUMP_CELL := 0.15

var _lump_parent: Dictionary = {}

func _count_lumps(mesh: Mesh, cell_size := LUMP_CELL) -> int:
	_lump_parent.clear()
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var step := cell_size * 0.5
	var corner := 0
	while corner + 2 < vertices.size():
		var a := vertices[corner]
		var b := vertices[corner + 1]
		var c := vertices[corner + 2]
		corner += 3
		var longest := maxf(a.distance_to(b), maxf(b.distance_to(c), c.distance_to(a)))
		var n := maxi(1, ceili(longest / step))
		for i in n + 1:
			for j in n + 1 - i:
				var at := a + (b - a) * (float(i) / float(n)) + (c - a) * (float(j) / float(n))
				var cell := Vector3i(
					floori(at.x / cell_size), floori(at.y / cell_size), floori(at.z / cell_size)
				)
				if not _lump_parent.has(cell):
					_lump_parent[cell] = cell
	for cell: Vector3i in _lump_parent.keys():
		for dx: int in [-1, 0, 1]:
			for dy: int in [-1, 0, 1]:
				for dz: int in [-1, 0, 1]:
					var beside := cell + Vector3i(dx, dy, dz)
					if not _lump_parent.has(beside):
						continue
					var mine := _lump_root(cell)
					var theirs := _lump_root(beside)
					if mine != theirs:
						_lump_parent[mine] = theirs
	var roots: Dictionary = {}
	for cell: Vector3i in _lump_parent.keys():
		roots[_lump_root(cell)] = true
	return roots.size()

## The group a cell belongs to, flattening the chain as it goes.
func _lump_root(cell: Vector3i) -> Vector3i:
	var root: Vector3i = cell
	while _lump_parent[root] != root:
		root = _lump_parent[root]
	var walk: Vector3i = cell
	while _lump_parent[walk] != root:
		var next: Vector3i = _lump_parent[walk]
		_lump_parent[walk] = root
		walk = next
	return root

## Two balls with air between them, to prove the counting above can actually
## see a gap. A check that always answers "one" would have passed every
## broken horse this exists to catch.
func _a_mesh_in_two_pieces(gap: float) -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 2:
		var ball := SphereMesh.new()
		ball.radius = 0.12
		ball.height = 0.24
		ball.radial_segments = 8
		ball.rings = 4
		var arrays := ball.get_mesh_arrays()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for k in indices.size():
			tool.add_vertex(vertices[indices[k]] + Vector3(0.0, 0.0, float(i) * (0.24 + gap)))
	tool.generate_normals()
	return tool.commit()

## Whether every child mesh of a body overlaps that body's own box. A part
## drawn relative to its joint and then placed at that joint again ends up
## twice as far out as it should be, which this catches.
func _parts_touch_the_body(node: Node3D, what: String) -> bool:
	var body := node.get_node_or_null("Body") as MeshInstance3D
	if body == null or body.mesh == null:
		printerr("  the %s has no body" % what)
		return false
	var trunk := body.mesh.get_aabb().grow(0.05)
	var attached := true
	for child in body.get_children():
		var piece := child as MeshInstance3D
		if piece == null or piece.mesh == null:
			continue
		var box := piece.mesh.get_aabb()
		box.position += piece.position
		if not trunk.intersects(box):
			attached = false
			printerr("  the %s's %s hangs in the air at %s" % [what, piece.name, str(piece.position)])
	return attached

## Carry a ridden mount along at `speed` for a second and report the widest
## swing any leg reached, and where all four legs were at that moment.
func _watch_the_gait(mounts: Mounts, from: Vector3, speed: float) -> Dictionary:
	var most := 0.0
	var at_most: Array = [0.0, 0.0, 0.0, 0.0]
	# Half a second to get up to the pace first: the gait blends from trot to
	# gallop as the pace rises, and measuring through that blend once caught
	# the legs mid-change and called it neither.
	for warm in 30:
		mounts.carry(from + Vector3(0.0, 0.0, -speed * float(warm + 1) / 60.0), 0.0)
		mounts._process(1.0 / 60.0)
	for frame in 60:
		mounts.carry(from + Vector3(0.0, 0.0, -speed * float(frame + 31) / 60.0), 0.0)
		mounts._process(1.0 / 60.0)
		var legs := mounts.leg_swings()
		var widest := 0.0
		for angle in legs:
			widest = maxf(widest, absf(angle))
		if widest > most:
			most = widest
			at_most = [legs[0], legs[1], legs[2], legs[3]]
	return {"most": most, "at_most": at_most}

## Getting off must not throw the child into the air.
##
## A mount was put down on the exact spot the child stood and made solid in
## the same frame, so its body had the child inside it: the physics server
## pushed them up and out, and from the phone that read as the horse getting
## stuck and the child floating free of it. It is put down beside them now
## and becomes solid once they have stepped clear.
func _check_getting_off_a_mount_is_safe() -> void:
	print("getting off a mount is safe")
	var field := HeightField.new(20260903)
	var mounts := Mounts.new(field)
	get_root().add_child(mounts)
	var spot := field.find_spawn_point()
	mounts.place(MountKinds.HORSE, spot + Vector3(2.0, 0.0, 0.0))
	_expect(mounts.mount(MountKinds.HORSE), "the horse can be got on")
	var here := spot + Vector3(6.0, 0.0, 4.0)
	mounts.dismount(here, 0.0)
	var left_at := mounts.position_of(MountKinds.HORSE)
	var aside := Vector2(left_at.x - here.x, left_at.z - here.z).length()
	_expect(aside > 1.2, "it is left %.1f m aside, not under the child" % aside)
	_expect(not mounts.is_solid(MountKinds.HORSE), "and is not solid while the child is still beside it")
	mounts.watch(here)
	_expect(not mounts.is_solid(MountKinds.HORSE), "nor after a frame of standing there")
	mounts.watch(here + Vector3(0.0, 0.0, -6.0))
	_expect(mounts.is_solid(MountKinds.HORSE), "and is solid again once they have walked clear of it")

	# And a horse cannot be ridden into the pool, which is a hole with walls
	# rather than a river to ford.
	var camp := field.camp_centre()
	var pool := PlaceSpec.centre_of(&"pool", camp)
	_expect(not mounts.can_ride_over(MountKinds.HORSE, pool), "a horse cannot be ridden into the pool")
	_expect(mounts.can_ride_over(MountKinds.HORSE, pool + Vector3(Places.POOL_FENCE_X + 6.0, 0.0, 0.0)), "but can be ridden past it")
	mounts.queue_free()

## A child in deep water must look like one. Buoyancy holds the collider at
## the right height, which left the whole of the body above the surface: from
## the phone it was not clear they were in the water at all. The drawn body
## is dropped to the chest and tipped forward while swimming, and comes back
## up when they walk out.
func _check_swimming_looks_like_swimming() -> void:
	print("swimming looks like swimming")
	var player := Player.new()
	get_root().add_child(player)
	_expect(is_zero_approx(player.swim_sink()), "on dry land the body is drawn where it stands")

	player.is_swimming = true
	for _frame in 60:
		player._settle_in_water(1.0 / 60.0)
	_expect(
		player.swim_sink() > Player.SWIM_SINK * 0.8 and player.swim_sink() < Player.SWIM_SINK * 1.2,
		"swimming, it sits %.2f m lower — about a third of its %.2f m height" % [player.swim_sink(), Player.HEIGHT]
	)
	_expect(player.swim_sink() < Player.HEIGHT * 0.5, "but not so low that the head goes under")
	_expect(player.swim_lean() > deg_to_rad(15.0), "and is tipped forward %.0f degrees" % rad_to_deg(player.swim_lean()))

	player.is_swimming = false
	for _frame in 90:
		player._settle_in_water(1.0 / 60.0)
	_expect(player.swim_sink() < 0.02 and player.swim_lean() < 0.02, "and stands up again on dry land")
	player.queue_free()

## A child walked straight through the dog. The animals are drawn nodes with
## no collision, so a few bodies follow whichever are nearest — the same
## answer as the forest's.
func _check_animals_are_solid() -> void:
	print("animals are solid")
	var field := HeightField.new(20260903)
	var animals := Animals.new(field, 20260903)
	get_root().add_child(animals)
	var solid := AnimalCollision.new(animals)
	get_root().add_child(solid)
	_expect(solid.solid_count() == 0, "nothing is solid before the child is anywhere")
	_expect(solid._bodies.size() == AnimalCollision.BODIES, "%d bodies wait to be lent out" % AnimalCollision.BODIES)
	_expect(solid._bodies[0].collision_layer == TerrainSpec.LAYER_PROPS, "on the props layer, which the player collides with and the camera does not")

	# Three animals in a row, the middle one nearest.
	var here := Vector3(0.0, 0.0, 0.0)
	var made: Array[Dictionary] = []
	for i in 3:
		var node := AnimalKinds.build_node(AnimalKinds.DOG)
		animals.add_child(node)
		node.position = Vector3(float(i) * 3.0 - 3.0, 0.0, 0.0)
		made.append({"kind": AnimalKinds.DOG, "node": node})
	solid.follow(here)
	solid.set_animals(made)
	_expect(solid.solid_count() == 3, "three animals nearby are three solid bodies")
	var nearest_body: StaticBody3D = solid._bodies[0]
	_expect(
		Vector2(nearest_body.position.x, nearest_body.position.z).length() < 0.01,
		"the nearest animal gets the first body"
	)
	var girth: CapsuleShape3D = solid._shapes[0]
	_expect(
		girth.radius > 0.2 and girth.height > girth.radius * 2.0,
		"whose shape is the size of a dog (%.2f m across, %.2f m tall)" % [girth.radius * 2.0, girth.height]
	)
	_expect(nearest_body.position.y > 0.1, "standing on the ground rather than sunk into it")
	solid.set_animals([] as Array[Dictionary])
	_expect(solid.solid_count() == 0, "and they are free again when the animals wander off")
	solid.queue_free()
	animals.queue_free()

## A dog asks for a stick until it is given one. It used to ask only while
## the child already carried a stick, which is backwards: the asking is what
## sends a child to look for one.
func _check_a_dog_asks_for_a_stick() -> void:
	print("a dog asks for a stick")
	var voices := AnimalVoices.new()
	get_root().add_child(voices)
	voices.bake_now()
	var node := Node3D.new()
	get_root().add_child(node)
	node.position = Vector3(2.0, 0.0, 0.0)
	var dog := {"kind": &"dog", "node": node, "cooldown": 0.0}
	var near: Array[Dictionary] = [dog]

	var barks := 0
	for _frame in 600:
		if voices._beg(near, Vector3.ZERO, 1.0 / 60.0):
			barks += 1
	_expect(barks > 0, "a dog beside an empty-handed child asks for one (%d times in ten seconds)" % barks)
	_expect(barks < 6, "and not more often than every few seconds")

	# Given something, it is quiet.
	dog["cooldown"] = 30.0
	var after := 0
	for _frame in 600:
		if voices._beg(near, Vector3.ZERO, 1.0 / 60.0):
			after += 1
	_expect(after == 0, "once it has been given something it is quiet")

	# And a dog across the meadow is not heard asking.
	dog["cooldown"] = 0.0
	node.position = Vector3(40.0, 0.0, 0.0)
	var far := 0
	for _frame in 600:
		if voices._beg(near, Vector3.ZERO, 1.0 / 60.0):
			far += 1
	_expect(far == 0, "nor is one across the meadow")
	node.queue_free()
	voices.queue_free()

## Water a child is standing in has to look and sound different from the
## meadow beside it. Ground below the waterline was painted the beach's own
## sand, so a hollow full of water read as a patch of sand — until the child
## walked into it and sank to the chest; and the valley's voices did not
## change at all when they did.
func _check_water_sounds_and_looks_like_water() -> void:
	print("water sounds and looks like water")
	var field := HeightField.new(20260903)

	# Colour: the bed of the water is silt, the beach above it is sand, and
	# the meadow beyond is neither.
	var bed := TerrainChunk._tint(field, 0.0, 0.0, HeightField.WATER_LEVEL - 0.9, 0.0, false, false, false)
	var beach := TerrainChunk._tint(field, 0.0, 0.0, HeightField.WATER_LEVEL + 0.4, 0.0, false, false, false)
	_expect(
		_closer_to(bed, TerrainSpec.COLOR_SILT, TerrainSpec.COLOR_SAND),
		"the ground under the water is silt, not sand"
	)
	_expect(
		_closer_to(beach, TerrainSpec.COLOR_SAND, TerrainSpec.COLOR_SILT),
		"the beach just above it is sand"
	)
	_expect(bed.v < beach.v, "and the bed is darker than the beach (%.2f against %.2f)" % [bed.v, beach.v])

	# Sound: in the water there is a voice for it, and the meadow's own
	# voices give way.
	var ambience := Ambience.new()
	get_root().add_child(ambience)
	var places := Places.new(field)
	get_root().add_child(places)
	var wooded := Vector3(0.0, 6.0, 0.0)
	var best := 0.0
	for z in range(-200, 201, 20):
		for x in range(-200, 201, 20):
			var here := field.forest_density_at(float(x), float(z))
			if here > best:
				best = here
				wooded = Vector3(float(x), 6.0, float(z))
	for _frame in 200:
		ambience.follow(wooded, field, places, 0.0, 1.0 / 60.0, 0.0)
	var dry: Dictionary = ambience.levels()
	_expect(float(dry["swimming"]) < 0.02, "on dry land there is no sound of being in water")
	_expect(not ambience.is_sounding("swimming"), "and that voice is not even playing")
	var leaves_dry := float(dry["leaves"])

	for _frame in 200:
		ambience.follow(wooded, field, places, 0.0, 1.0 / 60.0, 1.0)
	var wet: Dictionary = ambience.levels()
	_expect(float(wet["swimming"]) > 0.9, "in the water there is")
	_expect(ambience.is_sounding("swimming"), "and it is sounding")
	# The leaves are not turned off — the mix ducks them. Their own level
	# drifts with the weather, so what is asserted is the ducking.
	_expect(float(dry["hush"]) > 0.98, "on the bank the valley is heard in full")
	_expect(float(wet["hush"]) < 0.4, "in the water it is hushed to %.0f%% behind the water" % (float(wet["hush"]) * 100.0))
	_expect(float(wet["leaves"]) > 0.0 and leaves_dry > 0.0, "and the leaves are still there, in the wood, either way")
	ambience.queue_free()
	places.queue_free()

## Which of two colours a colour is nearer to.
func _closer_to(colour: Color, wanted: Color, other: Color) -> bool:
	var to_wanted := Vector3(colour.r - wanted.r, colour.g - wanted.g, colour.b - wanted.b).length()
	var to_other := Vector3(colour.r - other.r, colour.g - other.g, colour.b - other.b).length()
	return to_wanted < to_other

## Anywhere a child can swim must be somewhere they can see water.
##
## The valley floor is noise and noise dips: there were hollows below the
## waterline out in the meadow, and the water sheet is drawn from the river's
## line and the ponds' outlines, so nothing was drawn over them. A child
## walked in and sank to the chest on what looked like sand, while the map,
## which reads the ground, drew a blue lake there. The ground is held above
## the waterline unless it is river or pond; this walks the valley and
## checks it.
func _check_every_wet_place_shows_water() -> void:
	print("every wet place shows water")
	var field := HeightField.new(20260903)
	var stray := 0
	var worst := Vector3.ZERO
	var deepest := 0.0
	var wet_samples := 0
	for z in range(-400, 401, 7):
		for x in range(-400, 401, 7):
			var here := field.height_at(float(x), float(z))
			if here >= HeightField.WATER_LEVEL:
				continue
			wet_samples += 1
			# Water is drawn where the sheet's own blend is strong enough to be
			# opaque — the same formula the shader runs, so this asks about the
			# water a child actually sees rather than about a rule of thumb.
			var to_river := absf(float(x) - field.river_centre_x(float(z)))
			var blend := 1.0 - smoothstep(
				HeightField.RIVER_HALF_WIDTH,
				HeightField.RIVER_HALF_WIDTH + HeightField.RIVER_BANK_FADE,
				to_river
			)
			var shown := blend > 0.3
			shown = shown or Lakes.influence(float(x), float(z)) > 0.3
			shown = shown or PlaceSpec.excavation(float(x), float(z), field.camp_centre()) > 0.0
			if shown:
				continue
			stray += 1
			if HeightField.WATER_LEVEL - here > deepest:
				deepest = HeightField.WATER_LEVEL - here
				worst = Vector3(float(x), here, float(z))
	_expect(wet_samples > 0, "the valley has water in it at all (%d wet samples)" % wet_samples)
	if stray > 0:
		printerr("  worst is %.2f m under the water at (%.0f, %.0f)" % [deepest, worst.x, worst.z])
	_expect(stray == 0, "and no hollow away from the river or a pond is below the waterline (%d found)" % stray)

	# The river and the ponds are still wet, or the holding-up has flattened
	# the valley's water away entirely.
	var river_x := field.river_centre_x(40.0)
	_expect(field.height_at(river_x, 40.0) < HeightField.WATER_LEVEL - 1.0, "the river is still a river")
	var pond := Vector3(Lakes.PONDS[0], 0.0, Lakes.PONDS[1])
	_expect(field.height_at(pond.x, pond.z) < HeightField.WATER_LEVEL - 1.0, "and the pond is still a pond")

## A tree bends at the crown, not at the trunk, and not by much.
##
## The bend was `pow(metres_above_the_root, stiffness)`, which for a
## six-metre tree came to a metre and a half of swing — some thirty degrees,
## reported from the phone as trees waving like grass. It is a fraction of
## the plant's own height now, so the same shader can hold a tree still and
## whip a blade of grass.
func _check_the_wind_moves_only_the_crown() -> void:
	print("the wind moves only the crown")
	var forest := Vegetation.new(HeightField.new(20260903), 20260903)
	get_root().add_child(forest)
	for named: String in ["sway_amplitude", "plant_height", "stiffness", "sway_speed"]:
		_expect(
			forest._tree_material.get_shader_parameter(named) != null
			and forest._grass_material.get_shader_parameter(named) != null,
			"both trees and grass are told their %s" % named
		)
	var tree_amplitude := float(forest._tree_material.get_shader_parameter("sway_amplitude"))
	var tree_height := float(forest._tree_material.get_shader_parameter("plant_height"))
	var stiffness := float(forest._tree_material.get_shader_parameter("stiffness"))
	var lean := rad_to_deg(atan2(tree_amplitude, tree_height))
	_expect(lean < 5.0, "a tree's crown leans %.1f degrees at most, not thirty" % lean)
	_expect(stiffness > 2.0, "and the bend is confined to the thin end (stiffness %.1f)" % stiffness)
	# Half way up the tree, the same formula must give far less than at the top.
	var half := pow(0.5, stiffness) * tree_amplitude
	_expect(half < tree_amplitude * 0.25, "half way up it moves %.0f%% as far" % (half / tree_amplitude * 100.0))
	# Grass, by contrast, moves a real fraction of its own height.
	var grass_amplitude := float(forest._grass_material.get_shader_parameter("sway_amplitude"))
	var grass_height := float(forest._grass_material.get_shader_parameter("plant_height"))
	_expect(grass_amplitude / grass_height > 0.2, "grass still whips (%.0f%% of its height)" % (grass_amplitude / grass_height * 100.0))
	_expect(tree_amplitude / tree_height < grass_amplitude / grass_height * 0.3, "and moves far more, for its size, than a tree")
	forest.queue_free()

## Snow lies on gentle ground high up and slides off cliffs. The steepness
## term used to be measured against a scale steepness never reaches, so it
## was one everywhere and the mountains were white to their vertical walls.
func _check_snow_lies_where_snow_lies() -> void:
	print("snow lies where snow lies")
	var field := HeightField.new(20260903)
	var high := HeightField.TREELINE + 30.0
	var gentle := _snow_in(field, high, 0.1)
	var cliff := _snow_in(field, high, 0.9)
	var valley := _snow_in(field, 20.0, 0.1)
	# High and gentle is white — snow, and above it the blue of glacier ice,
	# which is a shade darker than snow and still nothing like rock.
	_expect(gentle > 0.7, "a high shoulder is white with snow and ice (%.2f)" % gentle)
	_expect(_snow_in(field, HeightField.TREELINE + 8.0, 0.1) > 0.85, "just above the treeline it is snow, before the ice starts")
	_expect(cliff < 0.15, "a high cliff face is bare rock (%.2f)" % cliff)
	_expect(valley < 0.02, "and the valley floor never is (%.2f)" % valley)
	# The treeline is where snow starts, not somewhere in the middle of the
	# forest: trees stop at TREELINE and snow must not be under them.
	_expect(_snow_in(field, HeightField.TREELINE - 40.0, 0.1) < 0.05, "no snow lies below the treeline")

## How white the ground comes out at a height and steepness, as a fraction.
##
## Measured as how pale its *darkest* channel is: snow and ice are pale in
## all three, while grass and rock have a dark one apiece. Projecting onto
## the rock-to-snow line instead reported the valley's green as an eighth
## snow, because green is not on that line at all.
func _snow_in(field: HeightField, height: float, steep: float) -> float:
	var colour := TerrainChunk._tint(field, 4000.0, 4000.0, height, steep, false, false, false)
	var palest := minf(colour.r, minf(colour.g, colour.b))
	var rock := minf(TerrainSpec.COLOR_ROCK.r, minf(TerrainSpec.COLOR_ROCK.g, TerrainSpec.COLOR_ROCK.b))
	var snow := minf(TerrainSpec.COLOR_SNOW.r, minf(TerrainSpec.COLOR_SNOW.g, TerrainSpec.COLOR_SNOW.b))
	return clampf((palest - rock) / (snow - rock), 0.0, 1.0)

## From a hilltop a child must see a valley, not the edge of what is
## streamed. The ground is built in chunks out to nine of them — a little
## under six hundred metres — and past that there was sky. One coarse ring
## carries the rest of the way to the mountains in a single draw call.
func _check_the_far_country_is_there() -> void:
	print("the far country is there")
	var field := HeightField.new(20260903)
	var far := DistantLand.new(field)
	get_root().add_child(far)
	_expect(not far.is_drawn(), "nothing is drawn before anyone is anywhere")

	var streamed: int = TerrainSpec.RINGS[TerrainSpec.RINGS.size() - 1]["radius"] * TerrainSpec.CHUNK_SIZE
	_expect(
		DistantLand.INNER < float(streamed),
		"the ring starts at %d m, inside the %d m the chunks reach, so no sky shows between them" % [int(DistantLand.INNER), streamed]
	)
	_expect(DistantLand.OUTER > 1500.0, "and reaches %d m out" % int(DistantLand.OUTER))

	far.follow(Vector3.ZERO)
	far.wait_for_it()
	_expect(far.is_drawn(), "it is drawn once the bake comes back")
	var triangles := far.triangle_count()
	_expect(triangles > 2000, "%d triangles of far country" % triangles)
	_expect(triangles < 40000, "and few enough to be worth one draw call")

	# It must agree with the ground it stands beyond: a point just outside the
	# ring's inner edge is at the same height in both.
	var probe := Vector3(DistantLand.INNER + DistantLand.STEP * 2.0, 0.0, 0.0)
	var mesh_height := _height_in_mesh(far, probe)
	_expect(
		absf(mesh_height - field.height_at(probe.x, probe.z)) < 6.0,
		"and stands at the same height as the ground it continues (%.1f m against %.1f m)" % [
			mesh_height, field.height_at(probe.x, probe.z)
		]
	)

	# Walking a little does not rebuild it; walking far does.
	var built_at := far._built_at
	far.follow(Vector3(20.0, 0.0, 0.0))
	_expect(far._built_at == built_at and far._task < 0, "a few steps do not rebuild it")
	far.follow(Vector3(DistantLand.REBUILD_AFTER + 50.0, 0.0, 0.0))
	_expect(far._task >= 0 or far._built_at != built_at, "walking far enough does")
	far.wait_for_it()
	far.queue_free()

## The height of the nearest vertex of a mesh to a point, in world terms.
func _height_in_mesh(far: DistantLand, at: Vector3) -> float:
	var vertices: PackedVector3Array = far._mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var origin: Vector3 = far._mesh.position
	var best := 0.0
	var nearest := 1e9
	for vertex in vertices:
		var world := vertex + origin
		var flat := Vector2(world.x - at.x, world.z - at.z).length_squared()
		if flat < nearest:
			nearest = flat
			best = world.y
	return best

func _check_trees_are_solid() -> void:
	print("a tree stops you")
	var field := HeightField.new(20260903)
	var forest := Vegetation.new(field, 20260903)
	get_root().add_child(forest)
	var trunks := TreeCollision.new(forest)
	get_root().add_child(trunks)

	_expect(trunks.solid_count() == 0, "nothing is solid before the player is anywhere")

	# Somewhere the forest actually is, rather than wherever the camp happens
	# to be: a check that stands in a meadow proves nothing about trees.
	var wooded := Vector3.ZERO
	var best := 0.0
	for z in range(-300, 301, 20):
		for x in range(-300, 301, 20):
			var density := field.forest_density_at(float(x), float(z))
			if density > best:
				best = density
				wooded = Vector3(float(x), 0.0, float(z))
	_expect(best > 0.3, "there is thick forest to test in (density %.2f)" % best)

	var near := forest.trees_near(wooded, TreeCollision.REACH)
	_expect(not near.is_empty(), "%d trees stand within reach of that spot" % near.size())

	# Nearest first, or the pool lends its bodies to the trees furthest away.
	var ordered := true
	for i in range(1, near.size()):
		var previous := Vector2(near[i - 1].x - wooded.x, near[i - 1].z - wooded.z).length()
		var current := Vector2(near[i].x - wooded.x, near[i].z - wooded.z).length()
		if current < previous - 0.001:
			ordered = false
	_expect(ordered, "and they come back nearest first")

	trunks.follow(wooded)
	_expect(trunks.solid_count() > 0, "standing in the wood makes trunks solid")
	_expect(
		trunks.solid_count() <= TreeCollision.BODIES,
		"never more than the %d bodies it owns" % TreeCollision.BODIES
	)

	# And walking out of the wood releases them again.
	trunks.set_trunks([] as Array[Vector3])
	_expect(trunks.solid_count() == 0, "and leaving the wood frees them")

	trunks.queue_free()
	forest.queue_free()

## Vegetation is baked on worker threads now, like the terrain, and for the
## same reason: a tile with grass is two thousand height-field queries, and it
## landed on the main thread every thirty metres walked. The same assertion
## the terrain has: tiles baked together on the pool must match tiles baked
## alone, tuft for tuft — and a stump must appear exactly where a felled tree
## no longer does.
func _check_planting_on_threads_changes_nothing() -> void:
	print("a forest baked on threads is the same forest")
	var field := HeightField.new(20260903)
	var seed_value := 20260903
	var size := Vegetation.TILE_SIZE

	# A wood, found rather than assumed.
	var wooded := Vector2i.ZERO
	var best := 0.0
	for z in range(-8, 9):
		for x in range(-8, 9):
			var d := field.forest_density_at(float(x * size) + size * 0.5, float(z * size) + size * 0.5)
			if d > best:
				best = d
				wooded = Vector2i(x, z)

	var coords: Array[Vector2i] = [
		wooded, wooded + Vector2i(1, 0), wooded + Vector2i(0, 1),
		wooded + Vector2i(-1, -1), Vector2i(0, 0), Vector2i(2, -3),
	]

	var alone: Array = []
	for coord in coords:
		alone.append(VegetationTile.bake(field, coord, size, seed_value, null, true))

	var together: Array = []
	together.resize(coords.size())
	var guard := Mutex.new()
	var tasks: Array[int] = []
	for i in coords.size():
		tasks.append(WorkerThreadPool.add_task(
			func() -> void:
				var baked := VegetationTile.bake(field, coords[i], size, seed_value, null, true)
				guard.lock()
				together[i] = baked
				guard.unlock()
		))
	for task in tasks:
		WorkerThreadPool.wait_for_task_completion(task)

	var identical := true
	var any_trees := 0
	var any_grass := 0
	for i in coords.size():
		var one: Dictionary = alone[i]
		var many = together[i]
		if many == null:
			identical = false
			printerr("  tile %s never came back from the pool" % coords[i])
			continue
		for layer: String in ["conifers", "broadleaves", "stumps", "grass"]:
			if one[layer] != many[layer]:
				identical = false
				printerr("  tile %s: %s differ when baked in parallel" % [coords[i], layer])
		any_trees += (one["conifers"] as Array).size() + (one["broadleaves"] as Array).size()
		any_grass += (one["grass"] as Array).size()
	_expect(any_trees > 0 and any_grass > 0, "the tiles have %d trees and %d tufts to compare" % [any_trees, any_grass])
	_expect(identical, "%d tiles baked in parallel match the same tiles baked alone" % coords.size())

	# Felling: one pass now produces both the standing trees and the stumps, so
	# a felled tree must leave the standing set and enter the stump set.
	var before: Dictionary = alone[0]
	var standing_before: int = (before["conifers"] as Array).size() + (before["broadleaves"] as Array).size()
	if standing_before > 0:
		var trees := VegetationTile.generate_trees(field, wooded, size, seed_value, null)
		var victim: Vector3 = trees[0]["position"]
		var felled := Felled.new()
		felled.fell(victim)
		var after := VegetationTile.bake(field, wooded, size, seed_value, felled.snapshot(), true)
		var standing_after: int = (after["conifers"] as Array).size() + (after["broadleaves"] as Array).size()
		_expect(standing_after == standing_before - 1, "felling one tree removes exactly one standing tree")
		_expect((after["stumps"] as Array).size() == 1, "and leaves exactly one stump")
		# The snapshot must be a copy: felling another tree afterwards must not
		# reach into a bake already handed to a thread.
		var snap := felled.snapshot()
		felled.fell(trees[1]["position"] if trees.size() > 1 else victim + Vector3(1.0, 0.0, 0.0))
		_expect(snap.count() == 1, "a snapshot does not change when the live record does")

## Every place stands on ground near its own natural height.
##
## All three were flattened to one level, read at the camp, and two of them
## stand on hills thirty metres above it: the playground and the café were at
## the bottom of thirty-metre craters, reported from the phone as "a huge pit
## with the playground in it". No check noticed because every check asked the
## height field, and the height field was doing exactly what it was told.
func _check_no_place_is_in_a_pit() -> void:
	print("no place is at the bottom of a pit")
	var field := HeightField.new(20260903)
	var camp := field.camp_centre()
	for place in PlaceSpec.OFFSETS:
		var centre := PlaceSpec.centre_of(place, camp)
		var levelled := field.height_at(centre.x, centre.z)
		var natural := field._raw_height(centre.x, centre.z)
		# The pool is dug on purpose; its rim, not its floor, is the level.
		if place == &"pool":
			levelled += PlaceSpec.POOL_DEPTH
		_expect(
			absf(levelled - natural) < 0.5,
			"the %s stands at %.1f m, on ground that is naturally %.1f m" % [place, levelled, natural]
		)
		# And where the flat ground ends there is a bank, not a cliff. Measured
		# just past the feathered edge, which is where a child would meet it —
		# not forty metres out, where a café on a hillside is simply on a hill.
		var reach: float = PlaceSpec.RADIUS[place] + PlaceSpec.FEATHER + 2.0
		var bank := 0.0
		for turn in 12:
			var a := TAU * float(turn) / 12.0
			var edge := centre + Vector3(cos(a), 0.0, sin(a)) * reach
			bank = maxf(bank, absf(field.height_at(edge.x, edge.z) - levelled))
		_expect(
			bank < 9.0,
			"and the ground at the edge of the %s's flat patch is within %.1f m of it" % [place, bank]
		)

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
		"BuildKinds", "Structures", "BuildMode", "Backpack", "Text", "HouseParts", "Minimap", "PartIcon", "Sounds", "Tasks", "Animals", "AnimalKinds", "Wallet", "ShopStock", "Vitals", "Journal", "Felled", "Mounts", "MountKinds", "Archery", "Lantern", "Places", "PlaceSpec", "Paths", "Hearths", "Ambience", "Dams", "DamSpec", "Today", "Profiles", "Session", "Visitors", "TogetherPanel", "Voice",
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

## A beaver lives at the river's edge, and its wander radius reaches the river
## itself. `field.height_at()` there is the carved bed, well under the water
## surface — setting an animal straight to it stands the animal on the bottom
## of the river with the water surface somewhere over its head.
func _check_animals_dont_drown() -> void:
	print("an animal in the river wades rather than drowns")
	var field := HeightField.new(20260903)
	var animals := Animals.new(field, 20260903)
	get_root().add_child(animals)

	var z := 40.0
	var river_x := field.river_centre_x(z)
	_expect(
		field.height_at(river_x, z) < HeightField.WATER_LEVEL - Animals.MAX_WADE_DEPTH,
		"the river bed really is under the water surface, so this is testing something"
	)
	_expect(
		animals._footing(river_x, z) >= HeightField.WATER_LEVEL - Animals.MAX_WADE_DEPTH - 0.001,
		"an animal standing in the river is no deeper than a wade"
	)

	# And dry ground must be untouched — a fix for the river must not flatten
	# every hill in the valley to the waterline.
	var camp := field.camp_centre()
	_expect(
		is_equal_approx(animals._footing(camp.x, camp.z), field.height_at(camp.x, camp.z)),
		"but an animal on dry ground still stands on the actual ground"
	)

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
		for code: StringName in [Text.EN, Text.FR, Text.RU]:
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

	for code: StringName in [Text.EN, Text.FR, Text.RU]:
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
		for code: StringName in [Text.EN, Text.FR, Text.RU]:
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

	for code: StringName in [Text.EN, Text.FR, Text.RU]:
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
		if MountKinds.floats(kind):
			_expect(
				MountKinds.speed(kind) > Player.SWIM_SPEED * 2.0,
				"%s is well over twice as fast as swimming, or there is no point rowing it" % kind
			)
			continue
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

	_expect(mounts.is_solid(MountKinds.HORSE), "a standing horse is solid: a child bumps into it rather than through it")
	var horse_node: Node3D = mounts._nodes[MountKinds.HORSE]
	_expect(horse_node.get_node("Body").get_child_count() == 6, "the horse has four legs, a head and a tail of its own")
	# The horse assembled from parts must stand in the same space as the horse
	# baked into one mesh. A moving part is drawn relative to its joint and
	# its node sits at that joint; built relative to nothing instead, the
	# offset was applied twice and the head and tail hung off the animal.
	var baked := MountKinds.build_mesh(MountKinds.HORSE).get_aabb()
	var assembled := AABB()
	var started := false
	for child in horse_node.get_node("Body").get_children() + [horse_node.get_node("Body")]:
		var piece := child as MeshInstance3D
		if piece == null or piece.mesh == null:
			continue
		var box := piece.mesh.get_aabb()
		box.position += piece.position
		assembled = box if not started else assembled.merge(box)
		started = true
	_expect(
		assembled.position.distance_to(baked.position) < 0.2 and assembled.size.distance_to(baked.size) < 0.3,
		"and stands in the same space as the one-piece horse (corner off by %.2f m, size by %.2f m)" % [
			assembled.position.distance_to(baked.position), assembled.size.distance_to(baked.size)
		]
	)
	_expect(mounts.mount(MountKinds.HORSE), "it can be mounted")
	# Carried along, its legs swing, and how they swing depends on the pace:
	# diagonal pairs at a trot, front legs together at a gallop. Watched over
	# a whole second rather than sampled on one frame, which is where a phase
	# near zero once read as legs that do not move.
	var start_at := spot + Vector3(2.0, 0.0, 0.0)
	var trot := _watch_the_gait(mounts, start_at, 3.0)
	_expect(float(trot["most"]) > 0.1, "at a trot its legs swing (%.0f degrees)" % rad_to_deg(float(trot["most"])))
	var trot_legs: Array = trot["at_most"]
	_expect(
		signf(trot_legs[0]) == signf(trot_legs[3]) and signf(trot_legs[0]) == -signf(trot_legs[1]),
		"in diagonal pairs, as a trot does"
	)
	var gallop := _watch_the_gait(mounts, start_at, 9.0)
	_expect(float(gallop["most"]) > 0.2, "at a gallop they reach further (%.0f degrees)" % rad_to_deg(float(gallop["most"])))
	var gallop_legs: Array = gallop["at_most"]
	_expect(signf(gallop_legs[0]) == signf(gallop_legs[1]), "and the front pair reaches together, as a gallop does")
	# Standing, they settle.
	for frame in 180:
		mounts.carry(start_at, 0.0)
		mounts._process(1.0 / 60.0)
	var rested := 0.0
	for angle in mounts.leg_swings():
		rested = maxf(rested, absf(angle))
	_expect(rested < 0.02, "and standing still they hang straight (%.1f degrees)" % rad_to_deg(rested))
	_expect(not mounts.is_solid(MountKinds.HORSE), "and stops being solid while ridden, or it would shove its rider")
	_expect(mounts.riding == MountKinds.HORSE, "and the game knows what is being ridden")
	_expect(not mounts.mount(MountKinds.HORSE), "it cannot be mounted twice")
	_expect(mounts.nearest(spot) == &"", "nothing else is offered while riding")

	# Dismounting leaves it beside where the child left it, which is where
	# they will look for it — beside, not underneath: see
	# `_check_getting_off_a_mount_is_safe`.
	var elsewhere := spot + Vector3(30.0, 0.0, -18.0)
	_expect(mounts.dismount(elsewhere, 0.0) == MountKinds.HORSE, "it can be dismounted")
	_expect(mounts.riding == &"", "and riding stops")
	var left_at := mounts.position_of(MountKinds.HORSE)
	var aside := Vector2(left_at.x - elsewhere.x, left_at.z - elsewhere.z).length()
	_expect(
		aside < Mounts.STEP_ASIDE + 0.01,
		"the horse is left a stride from where the child got off (%.1f m), not where it started" % aside
	)
	_expect(
		is_equal_approx(left_at.y, field.height_at(left_at.x, left_at.z)),
		"and it stands on the ground rather than in the air"
	)
	mounts.watch(elsewhere + Vector3(0.0, 0.0, -8.0))
	_expect(mounts.is_solid(MountKinds.HORSE), "and is solid again once the child is clear of it")
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
		for code: StringName in [Text.EN, Text.FR, Text.RU]:
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

	for code: StringName in [Text.EN, Text.FR, Text.RU]:
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
	for dx in range(-14, 15):
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
	var edge := places.water_depth_at(pool.x + Places.POOL_HALF_X - 0.4, pool.z)
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

	for height: float in [2.0, 20.0, 200.0, 1445.0]:
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

	_expect(places.seat_positions().size() == 4, "the playground has four swing seats: two frames, two children each")
	var seat_at: Vector3 = places.seat_positions()[0]
	_expect(places.push_swing(seat_at), "a swing can be pushed by a child standing at it")
	_expect(not places.push_swing(seat_at + Vector3(40.0, 0.0, 0.0)), "but not from across the field")
	_expect(places.nearest(seat_at) == Places.PLAYGROUND, "standing at a seat is offered the swing")
	_expect(places.nearest(places.slide_top()) == &"", "standing at the slide is not offered a swing it cannot reach")
	# A playground you can walk through is scenery — reported from the phone as
	# "I cannot get on the swings, I go straight through them".
	# Eight posts, a deck, four legs, the ladder, two benches; a pole and a
	# backboard; the trampoline's mat; two bins; the fountain's basin — and
	# every block of the hedge, the four corner trunks, the three lamp posts.
	var fixed_solids := 22
	var expected_solids := fixed_solids + places.hedge_segment_count() + 4 + Places.LAMPS.size()
	_expect(places.hedge_segment_count() >= 30, "the hedge is %d solid blocks" % places.hedge_segment_count())
	_expect(
		places.solid_shape_count() == expected_solids,
		"the playground has %d solid pieces to bump into and stand on (expected %d)" % [places.solid_shape_count(), expected_solids]
	)
	_expect(places.ball_count() == 3, "three basketballs lie by the hoop")
	_expect(places.has_hoop(), "and there is a hoop to throw them at")
	_expect(places.flower_bed_count() == 4, "four flower beds, in a valley that had no flowers")
	var spot: Vector3 = places._spots[Places.PLAYGROUND]
	var basketball := places.ball_near(spot + Places.BASKETBALLS[0])
	_expect(basketball != null and basketball.look == Ball.Look.BASKETBALL, "a child beside a basketball can kick it")
	_expect(places.ball_near(spot + Vector3(30.0, 0.0, 30.0)) == null, "but not from across the pad")
	# The player's origin is at its feet, so a child on the mat has it at the mat's top.
	var mat := spot + Places.TRAMPOLINE + Vector3(0.0, Places.TRAMPOLINE_TOP, 0.0)
	_expect(places.on_trampoline(mat), "standing on the mat counts as on the trampoline")
	_expect(not places.on_trampoline(mat + Vector3(Places.TRAMPOLINE_RADIUS + 1.0, 0.0, 0.0)), "standing beside it does not")
	_expect(not places.on_trampoline(mat + Vector3(0.0, 0.78, 0.0)), "nor does a body whose feet are not on the mat")
	_expect(places.at_fountain(spot + Places.FOUNTAIN + Vector3(1.2, 0.0, 0.0)), "the fountain fills a bottle from beside it")
	_expect(not places.at_fountain(spot + Places.FOUNTAIN + Vector3(6.0, 0.0, 0.0)), "not from six metres away")
	_expect(places.fountain_plays(), "and the fountain has a jet")
	# The lamps: dark by day, all three lit once it is properly night, and
	# dark again by morning.
	_expect(places.lamp_count() == Places.LAMPS.size() + Places.CAFE_LAMPS.size() + Places.POOL_LAMPS.size() + 4, "%d lamps: round the pad, at the café, at the pool, and the pitch's four floodlights" % places.lamp_count())
	_expect(places.pitch_lamp_count() == 4, "a floodlight at each corner of the pitch")
	places.light_lamps(0.0, 10.0)
	_expect(places.lamps_lit() == 0, "unlit in daylight")
	places.light_lamps(1.0, 10.0)
	_expect(places.lamps_lit() == places.lamp_count(), "all lit at midnight")
	places.light_lamps(0.15, 10.0)
	_expect(places.lamps_lit() >= 1 and places.lamps_lit() < places.lamp_count(), "%d of them lit at dusk: they come on one by one" % places.lamps_lit())
	places.light_lamps(0.0, 10.0)
	_expect(places.lamps_lit() == 0, "and out again by morning")
	# A basketball beside the hoop is thrown at it; one across the valley is not.
	_expect(places.hoop_in_range(spot + Places.BASKETBALLS[0]), "a ball beside the hoop is within throwing range")
	_expect(not places.hoop_in_range(spot + Vector3(12.0, 0.0, 12.0)), "one across the pad is not")
	# A ball dropped through the ring scores.
	var ring := places.ring_position()
	basketball.position = ring + Vector3(0.0, 0.5, 0.0)
	places._watch_balls()
	basketball.position = ring + Vector3(0.0, -0.3, 0.0)
	places._watch_balls()
	_expect(places.baskets == 1, "a ball falling through the ring is a basket")
	# The camera must not catch on the furniture. Its arm rattled against every
	# post it passed; props live on their own layer that only bodies collide with.
	_expect(places._solid.collision_layer == TerrainSpec.LAYER_PROPS, "the playground's solids are on the props layer")
	var probe_player := Player.new()
	_expect((probe_player.collision_mask & TerrainSpec.LAYER_PROPS) != 0, "which the player collides with")
	var probe_rig := CameraRig.new(probe_player)
	_expect((probe_rig._arm.collision_mask & TerrainSpec.LAYER_PROPS) == 0, "and the camera arm does not")
	probe_rig.free()
	probe_player.free()
	var climb_angle := rad_to_deg(atan2(Places.SLIDE_TOP.y, absf(Places.LADDER_RUN.z)))
	_expect(climb_angle < 52.0, "the ladder leans at %.0f degrees, which a child can walk up" % climb_angle)
	_expect(places.bench_count() == 2, "and there are two benches to sit and watch from")
	_expect(
		places.slide_top().y - places.slide_foot().y >= 2.7,
		"the slide is %.1f m tall" % (places.slide_top().y - places.slide_foot().y)
	)
	_expect(
		Vector2(places.slide_top().x - places.slide_foot().x, places.slide_top().z - places.slide_foot().z).length() >= 5.0,
		"and runs %.1f m along the ground" % Vector2(places.slide_top().x - places.slide_foot().x, places.slide_top().z - places.slide_foot().z).length()
	)
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
		for code: StringName in [Text.EN, Text.FR, Text.RU]:
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

	# A route to the pool stops at its gate, which has to be the gate the
	# turnstile is actually in — a number in two files that agreed only by
	# luck would put the path at the far side of the fence.
	var pool_arrival: Vector3 = Paths.ARRIVES_AT[&"pool"]
	_expect(
		absf(pool_arrival.x - (Places.POOL_FENCE_X + 1.5)) < 0.6 and is_zero_approx(pool_arrival.z),
		"the path to the pool ends %.1f m out, at the fence's gate %.1f m out" % [pool_arrival.x, Places.POOL_FENCE_X]
	)

	# Every route must actually arrive at a destination — on the dry ground
	# beside it, since one destination is a swimming pool and the bottom of a
	# swimming pool is not somewhere to paint a trodden path.
	for route in Paths.ROUTES:
		for end: StringName in [route["from"], route["to"]]:
			var at: Vector3 = camp if end == &"" else PlaceSpec.centre_of(end, camp) + Paths.ARRIVES_AT.get(end, Vector3.ZERO)
			var arrives := false
			for step in 24:
				var reach := float(step)
				for turn in 8:
					var angle := TAU * float(turn) / 8.0
					var near := at + Vector3(cos(angle) * reach, 0.0, sin(angle) * reach)
					var ground := field.height_at(near.x, near.z)
					if ground <= HeightField.WATER_LEVEL:
						continue
					if field.path_at(near.x, near.z, ground) > 0.5:
						arrives = true
						break
				if arrives:
					break
			_expect(
				arrives,
				"a path arrives at the %s" % ("camp" if end == &"" else String(end))
			)

	# And the middle of a route must be worn too, or it is two patches rather
	# than a path.
	# A route may be interrupted by water — that is a ford, and it is on purpose
	# — but it must be worn everywhere it is on land, or it is two patches
	# rather than a path.
	var worn := 0
	var dry_samples := 0
	for route in Paths.ROUTES:
		# Each route runs to where it actually arrives, which for the pool is
		# its gate rather than the bottom of the water.
		var a: Vector3 = camp if route["from"] == &"" else PlaceSpec.centre_of(route["from"], camp) + Paths.ARRIVES_AT.get(route["from"], Vector3.ZERO)
		var b: Vector3 = camp if route["to"] == &"" else PlaceSpec.centre_of(route["to"], camp) + Paths.ARRIVES_AT.get(route["to"], Vector3.ZERO)
		for step in 19:
			var at := a.lerp(b, float(step + 1) / 20.0)
			var ground := field.height_at(at.x, at.z)
			# Well clear of the water, so the fade at a ford is not counted as
			# a gap in the route.
			if ground < HeightField.WATER_LEVEL + 1.5:
				continue
			dry_samples += 1
			if field.path_at(at.x, at.z, ground) > 0.5:
				worn += 1
	_expect(
		dry_samples > 0 and worn == dry_samples,
		"every dry step along every route is worn ground (%d of %d)" % [worn, dry_samples]
	)

	# No route may be painted across the river. Three of the five cross it, and
	# the worn-earth colour used to run straight down the bank and along three
	# and a half metres of riverbed — reported, correctly, as looking like a
	# bug. A path stops at the water now, which is what a ford looks like.
	var dry := true
	var wettest := 0.0
	var i := 0
	while i < Paths.SEGMENTS.size():
		var ax := Paths.SEGMENTS[i]
		var az := Paths.SEGMENTS[i + 1]
		var bx := Paths.SEGMENTS[i + 2]
		var bz := Paths.SEGMENTS[i + 3]
		i += 4
		for step in 201:
			var along := float(step) / 200.0
			var x := lerpf(ax, bx, along)
			var z := lerpf(az, bz, along)
			var ground := field.height_at(x, z)
			if ground >= HeightField.WATER_LEVEL:
				continue
			var painted := field.path_at(x, z, ground)
			wettest = maxf(wettest, painted)
			if painted > 0.02:
				dry = false
	_expect(dry, "no path is painted on the riverbed (worst %.2f under water)" % wettest)

	# The valley away from the camp must be untouched, or the whole world is a
	# path and none of it is a signal.
	var open_valley := true
	for distance: float in [80.0, 160.0, 320.0]:
		for step in 8:
			var angle := TAU * float(step) / 8.0
			var at := camp + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
			if field.path_at(at.x, at.z, field.height_at(at.x, at.z)) > 0.0:
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
	# Taken a quarter of the way to the playground rather than half way to the
	# pool: that midpoint turned out to be the river crossing, where a path is
	# now deliberately absent.
	var on_path := camp.lerp(PlaceSpec.centre_of(&"playground", camp), 0.25)
	_expect(
		field.path_at(on_path.x, on_path.z, field.height_at(on_path.x, on_path.z)) > 0.5,
		"the middle of a route is a path"
	)
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
	for corner: Vector2 in [Vector2(0.0, 0.0), Vector2(-320.0, 224.0), Vector2(896.0, 0.0)]:
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

	places.push_swing(places.seat_positions()[0])
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

	for code: StringName in [Text.EN, Text.FR, Text.RU]:
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
		for code: StringName in [Text.EN, Text.FR, Text.RU]:
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
	#
	# Only against the primary address, not every address this machine
	# happens to have — address_for_code() is documented to reconstruct using
	# this machine's own network, meaning local_addresses()[0], and a tablet
	# with one Wi-Fi radio only ever has one. A CI runner or a developer's
	# machine with a Docker bridge alongside its real interface has more than
	# one private address on a different prefix, and asking the second one to
	# round-trip through the first one's prefix is not a promise this ever
	# made — that is what broke the first attempt at this check.
	var addresses := Session.local_addresses()
	if not addresses.is_empty():
		var primary := addresses[0]
		var code := Session.code_for(primary)
		_expect(
			Session.address_for_code(code) == primary,
			"reading out %d and typing it back reaches %s" % [code, primary]
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

	for code: StringName in [Text.EN, Text.FR, Text.RU]:
		Text.set_language(code)
		_expect(not Text.of("say_joined").begins_with("?"), "an arrival is announced in %s" % code)
		for key: String in [
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
	# These used to be words and are drawn now, so what this looks for is the
	# button being made at all rather than the label it once carried.
	var hud_source := _code_only(FileAccess.get_file_as_string("res://src/ui/hud.gd"))
	for control: String in ["jump", "build", "kick"]:
		_expect(
			hud_source.contains("ActionIcon.Kind.%s" % control.to_upper()),
			"there is an on-screen control for %s" % control
		)
	# And every drawn face must actually be drawn, or a button is a blank
	# rectangle — the same gap the bed's missing palette icon left.
	var icon_source := _code_only(FileAccess.get_file_as_string("res://src/ui/action_icon.gd"))
	var drawn := true
	for face: String in [
		"JUMP", "KICK", "BUILD", "CLOSE", "DRINK", "WHISTLE", "CHOP", "RIDE",
		"GET_OFF", "SHOOT", "SWING", "EAT", "GIVE_STICK", "FEED_FIRE", "SLEEP", "TALK",
	]:
		if not icon_source.contains("Kind.%s:" % face):
			drawn = false
			printerr("  action_icon.gd draws nothing for %s" % face)
	_expect(drawn, "every action icon has something to draw")

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

	for code: StringName in [Text.EN, Text.FR, Text.RU]:
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

## The map has to answer "where is anything", not only "where am I".
##
## That was fine while every destination sat beside the camp. They are four
## hundred metres apart now, and without a view of the whole valley a new world
## is a green field with no way to tell which direction anything is in.
func _check_the_map_shows_the_valley() -> void:
	print("the map shows the whole valley")
	var field := HeightField.new(20260903)
	var camp := field.camp_centre()

	# Each size must actually show more than the last, or the extra taps do
	# nothing a child can see.
	var small := Minimap.range_of(Minimap.Size.SMALL)
	var large := Minimap.range_of(Minimap.Size.LARGE)
	var full := Minimap.range_of(Minimap.Size.FULL)
	_expect(small < large, "large shows more than small (%d m against %d)" % [large, small])
	_expect(large < full, "and the whole valley more than large (%d m)" % full)

	# The full view has to contain everything a child would look for, or it is
	# not a view of the valley.
	var furthest := 0.0
	var everything: Array[Vector3] = [Pitch.centre(), camp]
	for place in PlaceSpec.OFFSETS:
		everything.append(PlaceSpec.centre_of(place, camp))
	everything.append(camp + Paths.BUTTS_OFFSET)
	for at in everything:
		furthest = maxf(furthest, maxf(absf(at.x - camp.x), absf(at.z - camp.z)))
	_expect(
		full * 0.5 > furthest,
		"the whole valley reaches %d m from the camp, and the furthest place is %d m" % [
			int(full * 0.5), int(furthest)
		]
	)

	# Every destination needs its own picture and colour, since a six-year-old
	# cannot read labels; and no two the same, or the map says two things are
	# the same thing.
	_expect(
		PlaceGlyph.COLOURS.size() == PlaceGlyph.Kind.size(),
		"every kind of place has a colour on the map (%d of %d)" % [PlaceGlyph.COLOURS.size(), PlaceGlyph.Kind.size()]
	)
	var seen: Dictionary = {}
	var distinct := true
	for kind in PlaceGlyph.COLOURS:
		var key := str(PlaceGlyph.COLOURS[kind])
		if seen.has(key):
			distinct = false
		seen[key] = true
	_expect(distinct, "and no two places share one")

	# Tapping has to come back round to where it started, or a child who taps
	# once too often is stuck in a view they did not want.
	var map := Minimap.new(field)
	get_root().add_child(map)
	# Three sizes, so three taps come back round. A child who taps once too many
	# times must not be stranded in a view they did not want.
	var started := map._size
	var seen_sizes: Dictionary = {}
	for _tap in 3:
		seen_sizes[map._size] = true
		map._gui_input(_a_tap())
	_expect(map._size == started, "tapping three times returns to the size it started at")
	_expect(seen_sizes.size() == 3, "and passes through all %d sizes on the way" % seen_sizes.size())

	map.queue_free()

## A tap, for driving the interface from a check.
func _a_tap() -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click

## The valley has to make a noise when nothing is happening.
##
## Every sound before this was an event — a kick, a coin, a piece going down —
## and between them the game was perfectly silent. Silence is what a picture of
## a place sounds like, not the place.
func _check_the_valley_is_not_silent() -> void:
	print("the valley makes a sound of its own")
	var field := HeightField.new(20260903)
	var places := Places.new(field)
	get_root().add_child(places)
	places.stand_up(field.camp_centre())

	var ambience := Ambience.new()
	get_root().add_child(ambience)
	# AudioStreamPlayer.play() needs the tree this synchronous script has not
	# actually entered yet — same reason as the Hud and Hearths checks above.
	await process_frame

	# Every voice has to be a real waveform and has to loop, or the valley falls
	# silent a few seconds after it starts.
	for named: Array in [["wind", ambience._wind], ["water", ambience._water], ["birds", ambience._birds]]:
		var stream: AudioStreamWAV = named[1].stream
		_expect(stream != null, "there is a %s sound" % named[0])
		_expect(stream.data.size() > 1000, "and it is %d KB of waveform" % (stream.data.size() / 1024))
		_expect(
			stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,
			"and it loops, so it does not stop after %.0f seconds" % Ambience.LOOP_SECONDS
		)

	# The mix has to answer to where the player is, or it is wallpaper.
	var in_river := Vector3(field.river_centre_x(40.0), 0.0, 40.0)
	ambience.follow(in_river, field, places, 0.0, 2.0)
	var wet := ambience._water_level

	var dry := in_river + Vector3(260.0, 40.0, 0.0)
	ambience.follow(dry, field, places, 0.0, 2.0)
	_expect(wet > ambience._water_level, "water is louder at the river than away from it")

	# Wind rises with the ground.
	ambience.follow(Vector3(0.0, 2.0, 18.0), field, places, 0.0, 2.0)
	var low := ambience._wind_level
	ambience.follow(Vector3(0.0, 140.0, 18.0), field, places, 0.0, 2.0)
	_expect(ambience._wind_level > low, "and wind is louder high up than down by the river")

	# Birds do not sing in the dark.
	var wooded := Vector3(120.0, 6.0, 120.0)
	ambience.follow(wooded, field, places, 0.0, 3.0)
	var daytime := ambience._bird_level
	ambience.follow(wooded, field, places, 1.0, 3.0)
	_expect(
		ambience._bird_level < daytime,
		"and the birds are quieter at night than in daylight"
	)

	ambience.queue_free()
	places.queue_free()

## A tree is worth the same standing whoever planted it, and cutting one down
## costs what growing one pays.
##
## Without that, an afternoon of felling is pure profit and the valley is worth
## more cut down than left alone — which is the opposite of what this game is
## about.
func _check_trees_are_capital() -> void:
	print("trees are worth something")
	for kind: StringName in [BuildKinds.SAPLING, BuildKinds.PINE]:
		_expect(BuildKinds.reward_for(kind) > 0, "a grown %s is worth something" % kind)

	_expect(
		BuildKinds.reward_for(BuildKinds.PINE) > BuildKinds.reward_for(BuildKinds.SAPLING),
		"a fir is worth more than a round tree (%d against %d)" % [
			BuildKinds.reward_for(BuildKinds.PINE),
			BuildKinds.reward_for(BuildKinds.SAPLING)
		]
	)

	# The fir costs a cone, which squirrels also want; the round one costs a
	# seed, which nothing else does. The price has to reflect that or the choice
	# between feeding an animal and planting a tree is not a real one.
	_expect(
		BuildKinds.INFO[BuildKinds.PINE]["cost"].has(&"cone"),
		"a fir is planted from a cone, which the squirrels are also after"
	)
	_expect(
		BuildKinds.INFO[BuildKinds.SAPLING]["cost"].has(&"seed"),
		"and a round tree from a seed, which nothing else wants"
	)

	# Symmetry: planting and felling are the same number, so an afternoon spent
	# doing both ends where it started.
	_expect(
		BuildKinds.WILD_TREE_VALUE == BuildKinds.reward_for(BuildKinds.SAPLING),
		"felling costs exactly what growing one pays (%d)" % BuildKinds.WILD_TREE_VALUE
	)

	# And a child with nothing can still fell — they simply have nothing to pay
	# with. Being refused by a game about a valley is worse than being charged.
	var empty := Wallet.new()
	_expect(not empty.spend(BuildKinds.WILD_TREE_VALUE), "an empty purse pays nothing")
	_expect(empty.coins == 0, "and is not driven into debt")

## A fire has to be fed, and warmth has to be somewhere rather than something a
## child carries away with them.
func _check_a_fire_needs_feeding() -> void:
	print("a fire burns while it is fed")
	var field := HeightField.new(20260903)
	var hearths := Hearths.new(field)
	get_root().add_child(hearths)
	# A node add_child()'d in this synchronous script is not yet is_inside_tree()
	# to its own children until a frame turns over — same as the Hud check
	# above — and _light() sets global_position on a freshly added child, which
	# needs exactly that.
	await process_frame

	var at := field.camp_centre()
	at.y = field.height_at(at.x, at.z)

	_expect(not hearths.has_fire_near(at), "there is no fire before one is built")
	_expect(is_zero_approx(hearths.feed(at)), "and nothing to put wood on")

	hearths.set_fires([at])
	_expect(hearths.has_fire_near(at), "a built campfire can be reached")
	_expect(not hearths.is_burning(at), "but is not alight until it is fed")
	_expect(is_zero_approx(hearths.warmth_at(at)), "and gives no warmth")

	var burning := hearths.feed(at)
	_expect(burning > 0.0, "one log lights it for %.0f minutes" % (burning / 60.0))
	_expect(hearths.is_burning(at), "and it is alight")
	_expect(hearths.warmth_at(at) > 0.5, "and warm to stand beside")

	# Warmth is a place. Walk away and it is gone — that is what makes a fire
	# somewhere to be rather than a button that was pressed.
	_expect(
		is_zero_approx(hearths.warmth_at(at + Vector3(Hearths.WARMTH_REACH + 5.0, 0.0, 0.0))),
		"and not warm from across the meadow"
	)

	# It cannot be stuffed indefinitely.
	for _log in Hearths.MAX_LOGS + 4:
		hearths.feed(at)
	_expect(
		hearths.minutes_left(at) <= Hearths.SECONDS_PER_LOG * Hearths.MAX_LOGS / 60.0 + 0.01,
		"it holds at most %d logs, so a bagful is not an evening" % Hearths.MAX_LOGS
	)

	# And it goes out on its own, which is what makes feeding it mean anything.
	var out: Array[bool] = []
	hearths.went_out.connect(func(_where: Vector3) -> void: out.append(true))
	for _tick in Hearths.MAX_LOGS + 2:
		hearths._process(Hearths.SECONDS_PER_LOG)
	_expect(not hearths.is_burning(at), "left alone it goes out")
	_expect(out.size() == 1, "and says so exactly once")
	_expect(is_zero_approx(hearths.warmth_at(at)), "and is cold afterwards")

	# Taking the campfire down puts the fire out with it.
	hearths.feed(at)
	hearths.set_fires([])
	_expect(not hearths.is_burning(at), "removing the campfire ends the fire")

	# Resting by a fire has to be worth walking to.
	_expect(Hearths.REST_BONUS > 1.5, "a fire is worth resting at (%.1fx)" % Hearths.REST_BONUS)

	for code: StringName in [Text.EN, Text.FR, Text.RU]:
		Text.set_language(code)
		_expect(not Text.of("ui_feed_fire").begins_with("?"), "feeding a fire is labelled in %s" % code)
	Text.set_language(Text.EN)

	hearths.queue_free()

## A house has to be worth building, not merely possible to build.
##
## Every other part makes a shape. A bed makes somewhere to be: night is long
## and dark and there is little to do in it, so sleeping through it turns the
## worst part of the day into the reason a child built something at all.
func _check_a_house_is_worth_having() -> void:
	print("a house is worth having")
	_expect(HouseParts.ALL.has(HouseParts.BED), "a bed is one of the pieces")
	_expect(
		HouseParts.build_mesh(HouseParts.BED) != null,
		"and it has something to look at"
	)

	var cost: Dictionary = HouseParts.INFO[HouseParts.BED]["cost"]
	_expect(not cost.is_empty(), "it costs something to make")
	var affordable := true
	for item in cost:
		if not ItemKinds.ALL.has(item):
			affordable = false
	_expect(affordable, "and out of things the valley actually contains")

	# Low enough to be furniture. A bed as tall as a wall is a wall.
	_expect(
		float(HouseParts.INFO[HouseParts.BED]["height"]) < HouseParts.STOREY * 0.5,
		"it is furniture rather than another wall"
	)

	# Sleeping is only worth anything in the dark, and it has to leave a child
	# at the start of a day rather than the middle of one.
	var atmosphere := Atmosphere.new()
	get_root().add_child(atmosphere)
	atmosphere.set_time(0.5)
	_expect(
		atmosphere.darkness() < 0.35,
		"at noon it is too light to want to sleep"
	)
	atmosphere.set_time(0.02)
	_expect(atmosphere.darkness() > 0.35, "and dark enough at night")

	atmosphere.set_time(0.26)
	_expect(
		atmosphere.darkness() < 0.1,
		"waking leaves a child in daylight, at the start of a day rather than the end"
	)

	# And rested, or the night was spent for nothing.
	var vitals := Vitals.new()
	vitals.energy = 4.0
	vitals.energy = Vitals.MAX_ENERGY
	_expect(is_equal_approx(vitals.fraction(), 1.0), "and fully rested")

	for code: StringName in [Text.EN, Text.FR, Text.RU]:
		Text.set_language(code)
		for key: String in ["ui_sleep", "say_slept", "say_not_tired", "part_bed"]:
			_expect(not Text.of(key).begins_with("?"), "%s reads in %s" % [key, code])
	Text.set_language(Text.EN)

	atmosphere.queue_free()

## Every house part must be drawn in the palette, or a new piece ships with a
## blank square where its icon should be — which is exactly what happened when
## the bed was added: it was buildable, had a mesh, and had no icon at all,
## because part_icon.gd's match statement was never told about it.
func _check_every_part_has_an_icon() -> void:
	print("every house part has an icon")
	var source := _code_only(FileAccess.get_file_as_string("res://src/ui/part_icon.gd"))
	var drawn := true
	for kind in HouseParts.ALL:
		if not source.contains("HouseParts.%s:" % String(kind).to_upper()):
			drawn = false
			printerr("  part_icon.gd has no case for %s" % kind)
	_expect(drawn, "part_icon.gd's match covers all %d house parts" % HouseParts.ALL.size())

## A house whose walls a child can walk straight through is scenery, not a
## house — and a camera that sails through them into the room beyond is worse,
## because it makes every other wall look just as unreal. A door is the one
## exception on purpose: the opening it cuts into the mesh has to be cut into
## the collision too, or a door is a wall wearing a costume.
func _check_walls_are_solid() -> void:
	print("a built wall actually stops you")
	for kind: StringName in [HouseParts.WALL, HouseParts.WALL_WINDOW, HouseParts.POST]:
		var node := Node3D.new()
		HouseParts.add_collision(node, kind)
		var body := _only_static_body(node)
		_expect(body != null, "%s has a collision body" % kind)
		if body != null:
			_expect(
				_body_blocks(body, Vector3(0.0, HouseParts.STOREY * 0.5, 0.0)),
				"%s blocks the middle of its own panel" % kind
			)
		node.free()

	var doorway := Node3D.new()
	HouseParts.add_collision(doorway, HouseParts.WALL_DOOR)
	var door_body := _only_static_body(doorway)
	_expect(door_body != null, "a door has a collision body")
	if door_body != null:
		_expect(
			not _body_blocks(door_body, Vector3(0.0, HouseParts.DOOR_HEIGHT * 0.5, 0.0)),
			"the doorway itself stays open at the height a child walks through"
		)
		_expect(
			_body_blocks(door_body, Vector3(HouseParts.MODULE * 0.4, HouseParts.STOREY * 0.5, 0.0)),
			"but the wall either side of the door is still solid"
		)
		_expect(
			_body_blocks(door_body, Vector3(0.0, HouseParts.STOREY - 0.05, 0.0)),
			"and the lintel above the door is still solid"
		)
	doorway.free()

	var solid: Array[StringName] = []
	var passable: Array[StringName] = []
	for kind in HouseParts.ALL:
		(solid if HouseParts.is_solid(kind) else passable).append(kind)
	_expect(
		HouseParts.BED in passable and HouseParts.FLOOR in passable,
		"a bed and a floor stay walkable rather than becoming furniture you bump into"
	)

func _only_static_body(node: Node3D) -> StaticBody3D:
	for child in node.get_children():
		if child is StaticBody3D:
			return child
	return null

## Whether any collision box on this body covers a point, checked directly
## against each BoxShape3D rather than through the physics server — the server
## needs a frame of simulation to answer, and this only needs arithmetic.
func _body_blocks(body: StaticBody3D, point: Vector3) -> bool:
	for child in body.get_children():
		if not child is CollisionShape3D:
			continue
		var shape: CollisionShape3D = child
		if not shape.shape is BoxShape3D:
			continue
		var box: BoxShape3D = shape.shape
		var half := box.size * 0.5
		var local := point - shape.position
		if absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z:
			return true
	return false

## Four buttons — visit, dam, fire, sleep — used to share one screen position on
## the assumption that a child is never at two of their contexts at once. That
## is false for a fire and a bed: both are ordinary house pieces, and building
## them side by side is exactly what a cosy house is. Two controls on one spot
## means one of them is invisible and cannot be pressed at all.
func _check_context_buttons_never_overlap() -> void:
	print("context buttons never share a position")
	var hud := Hud.new()
	get_root().add_child(hud)
	# _ready() runs deferred, not within add_child(), same as in the real game —
	# and _layout() needs get_viewport(), which only exists once it has. One
	# frame is what the running game gets for free; a script has to ask for it.
	await process_frame

	# The combination that actually happens: a fire built next to a bed.
	hud.set_fire_offer(true)
	hud.set_sleep_offer(true)
	hud.set_dam_offer(false)
	hud.set_place_offer(&"")
	hud._layout()
	_expect(
		not hud._fire_button.position.is_equal_approx(hud._sleep_button.position),
		"a fire and a bed offered together get separate slots"
	)

	# And all four at once, however unlikely, must still be four distinct spots.
	hud.set_fire_offer(true)
	hud.set_sleep_offer(true)
	hud.set_dam_offer(true)
	hud.set_place_offer(Places.CAFE)
	hud._layout()
	var spots: Dictionary = {}
	var distinct := true
	for button: Button in [hud._visit_button, hud._dam_button, hud._fire_button, hud._sleep_button]:
		var key := str(button.position)
		if spots.has(key):
			distinct = false
		spots[key] = true
	_expect(distinct, "all four context buttons get their own position when every one applies")

	hud.queue_free()
