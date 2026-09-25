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
	_check_a_horse_swims()
	_check_the_horses_are_spread_and_grazing()
	_check_the_swing_is_pumped()
	_check_the_motorcycle_is_heard()
	_check_the_icon_is_the_valley()
	_check_the_valley_is_populated()
	_check_a_flock_is_worth_keeping()
	_check_every_animal_is_finished()
	_check_the_forest_is_asked_once()
	_check_nobody_falls_out_of_the_world()
	_check_snow_lies_on_the_shoulders()
	_check_a_horse_cannot_walk_through_a_wood()
	_check_the_terrace_is_off_the_doorstep()
	_check_the_shop_is_somewhere_you_walk_to()
	_check_a_child_can_get_out_of_every_pond()
	_check_the_ducks_are_only_ducks()
	_check_the_range_is_clear()
	_check_the_bow_can_be_aimed()
	_check_swimming_looks_like_swimming()
	_check_animals_are_solid()
	_check_a_dog_asks_for_a_stick()
	_check_water_sounds_and_looks_like_water()
	_check_every_wet_place_shows_water()
	_check_the_wind_moves_only_the_crown()
	_check_snow_lies_where_snow_lies()
	_check_the_far_country_is_there()
	_check_the_mountainside_has_zones()
	_check_every_buildable_thing_has_a_picture()
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
	_check_talking_can_be_switched_off()
	_check_a_valley_survives_a_new_phone()
	_check_felling_your_own_tree_costs_what_it_paid()
	_check_nothing_is_planted_where_it_does_not_belong()
	_check_the_shop_sells_seconds_and_buys_back()
	_check_the_machines_steer()
	_check_a_stump_is_grubbed_out_by_a_new_tree()
	_check_nothing_is_used_before_it_exists()
	_check_the_lantern_is_carried()
	await _check_the_open_bag_moves_nothing()
	_check_the_valley_loops_without_a_tick()
	_check_a_machine_backs_out_of_a_corner()
	_check_the_bridge_carries_what_cannot_swim()
	_check_the_bridge_is_walked_not_climbed()
	_check_the_bridge_is_on_the_map()
	_check_the_roads_have_names()
	_check_the_fairground()
	await _check_the_rides_carry_a_child()
	_check_the_coaster_stands_on_the_ground()
	await _check_the_rides_are_solid()
	_check_the_wheel_stands_on_the_sand()
	_check_the_animals_keep_off_the_playing_places()
	_check_the_coaster_runs_a_lap()
	_check_the_rides_are_paid_for()

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
		var script := ResourceLoader.load(path, "Script") as GDScript
		if script == null:
			_fail("%s did not load" % path)
			continue
		# Loading is not enough. A script whose body names something that does
		# not exist — a constant moved to another class, a function never
		# written — still comes back from the loader as an object; it is only
		# when it is compiled that the name is looked for. Two rides went into
		# the game calling constants that were not there, the export built, and
		# every check here passed.
		# Except this file, which is the one running: reloading a script from
		# inside itself fails on principle rather than on merit.
		if path == get_script().resource_path:
			continue
		if script.reload() != OK:
			_fail("%s did not compile" % path)
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

	for pond in Lakes.count():
		var cx := Lakes.at(pond, Lakes.POND_X)
		var cz := Lakes.at(pond, Lakes.POND_Z)
		var long_axis := Lakes.at(pond, Lakes.POND_LONG)
		var short_axis := Lakes.at(pond, Lakes.POND_SHORT)
		var level := Lakes.at(pond, Lakes.POND_LEVEL)
		var index := pond + 1

		# Dug below its own water, which is not the world's for a pond up a
		# hill. Digging every pond to sea level is what turned the eastern one
		# into a crater a child could not climb out of.
		_expect(
			field.height_at(cx, cz) < level - 1.0,
			"pond %d is dug %.1f m below its own water, which stands at %.1f m" % [
				index, level - field.height_at(cx, cz), level
			]
		)
		_expect(
			level - field.height_at(cx, cz) <= Lakes.DEPTH + 0.01,
			"and no deeper than the %.1f m it is meant to be" % Lakes.DEPTH
		)
		_expect(
			is_equal_approx(field.water_level_at(cx, cz), level),
			"the game agrees the water here stands at %.1f m" % field.water_level_at(cx, cz)
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
			if field.height_at(cx + float(step), cz) < level:
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
	# One mark for every place a child might set out for, the crossing over the
	# river included.
	_expect(
		map._destinations.size() == PlaceGlyph.Kind.size(),
		"%d destinations are marked, one for every kind of place" % map._destinations.size()
	)
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
	# And it hangs: a horse's tail leaves the dock about level and is falling
	# within a hand's width, rather than curling up over the rump like a dog's.
	_expect(joints[1].y < joints[0].y + 0.08, "it leaves the dock about level, not cocked upwards")
	_expect(
		joints[joints.size() - 1].y < joints[0].y - 0.5,
		"and hangs %.2f m below where it starts" % (joints[0].y - joints[joints.size() - 1].y)
	)

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

	# Loudness. The river was the loudest thing in the valley and drowned
	# everything on the bank, which is what "the water is too loud when you
	# are close" meant.
	_expect(Ambience.WATER_DB < Ambience.WIND_DB + 2.0, "the river is no louder than the wind (%.0f dB against %.0f)" % [Ambience.WATER_DB, Ambience.WIND_DB])
	_expect(Ambience.WATER_DB <= -32.0, "and quiet enough to stand beside")
	_expect(Ambience.SWIMMING_DB > Ambience.WATER_DB, "the water you are in is the louder of the two, as it should be")
	# On the bank itself it is already easing off rather than at full.
	var bank := Vector3(field.river_centre_x(30.0) + HeightField.RIVER_HALF_WIDTH, 2.0, 30.0)
	for _frame in 300:
		ambience.follow(bank, field, places, 0.0, 1.0 / 60.0, 0.0)
	var beside: Dictionary = ambience.levels()
	_expect(float(beside["water"]) < 0.8, "and from the bank it is %.0f%% of full, not all of it" % (float(beside["water"]) * 100.0))
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
	# A shadow on a transparent, shiny plane is a dark shape on the
	# reflection: the child's own shadow landed in the sun's glare on the
	# water and read as a black diamond following them about.
	_expect(
		_code_only(FileAccess.get_file_as_string("res://src/world/water.gd")).contains("shadows_disabled"),
		"the water takes no shadows"
	)
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
## A mountainside goes through bands, as a real one does: mixed wood, spruce
## forest, stunted trees, alpine pasture, crag, snow, ice. The valley is a
## few hundred metres tall rather than a few thousand, so the bands are
## scaled — but the order of them is what makes a hillside read as a
## mountainside, and the order is what this checks.
func _check_the_mountainside_has_zones() -> void:
	print("the mountainside has zones")
	# The bands are in order and none of them is empty.
	_expect(
		HeightField.MIXED_TOP < HeightField.CONIFER_TOP
		and HeightField.CONIFER_TOP < HeightField.TREELINE
		and HeightField.TREELINE < HeightField.SNOWLINE
		and HeightField.SNOWLINE < HeightField.PASTURE_TOP,
		"the bands climb in order: mixed wood, spruce, treeline, snow"
	)

	# Trees: mixed low down, all spruce by the middle slopes, stunted at the
	# treeline.
	_expect(HeightField.conifer_share(6.0) < 0.4, "a third of the valley's trees are spruce (%.0f%%)" % (HeightField.conifer_share(6.0) * 100.0))
	_expect(HeightField.conifer_share(HeightField.MIXED_TOP + 4.0) > 0.95, "and above the mixed wood they all are")
	_expect(is_equal_approx(HeightField.tree_vigour(20.0), 1.0), "trees in the valley grow to their full size")
	_expect(HeightField.tree_vigour(HeightField.TREELINE) < 0.6, "and the last ones under the treeline are stunted (%.0f%%)" % (HeightField.tree_vigour(HeightField.TREELINE) * 100.0))

	# The forest thickens towards the mountains, and stops at the treeline.
	var field := HeightField.new(20260903)
	var low := _average_density(field, 6.0, 24.0)
	var slope := _average_density(field, 40.0, 80.0)
	_expect(slope > low, "the wood is thicker on the lower slopes than in the valley (%.2f against %.2f)" % [slope, low])
	var above := 0.0
	for z in range(-500, 501, 13):
		for x in range(-500, 501, 13):
			if field.height_at(float(x), float(z)) <= HeightField.TREELINE:
				continue
			above = maxf(above, field.forest_density_at(float(x), float(z)))
	_expect(is_zero_approx(above), "and no tree grows above the treeline")

	# The ground: pasture above the last trees, crag above that, snow above
	# that. Measured on gentle ground, where each band is at its clearest.
	var pasture := TerrainChunk._tint(field, 4000.0, 4000.0, HeightField.TREELINE + 2.0, 0.12, false, false, false)
	var crag := TerrainChunk._tint(field, 4000.0, 4000.0, HeightField.PASTURE_TOP - 4.0, 0.12, false, false, false)
	_expect(
		_closer_to(pasture, TerrainSpec.COLOR_PASTURE, TerrainSpec.COLOR_ROCK),
		"just above the treeline the ground is pasture, not rock"
	)
	_expect(
		_closer_to(crag, TerrainSpec.COLOR_ROCK, TerrainSpec.COLOR_PASTURE)
		or _snow_in(field, HeightField.PASTURE_TOP - 4.0, 0.12) > 0.5,
		"higher still it is crag or snow, not pasture"
	)
	_expect(_snow_in(field, HeightField.TREELINE + 4.0, 0.12) < 0.2, "and no snow lies on the pasture")
	_expect(_snow_in(field, HeightField.SNOWLINE + 16.0, 0.12) > 0.8, "while the tops are white")

## The forest's density averaged over a band of heights, found by walking the
## valley until enough ground in that band has been sampled.
func _average_density(field: HeightField, low: float, high: float) -> float:
	var total := 0.0
	var found := 0
	for z in range(-500, 501, 11):
		for x in range(-500, 501, 11):
			var height := field.height_at(float(x), float(z))
			if height < low or height > high:
				continue
			total += field.forest_density_at(float(x), float(z))
			found += 1
	return total / maxf(float(found), 1.0)

func _check_snow_lies_where_snow_lies() -> void:
	print("snow lies where snow lies")
	var field := HeightField.new(20260903)
	var high := HeightField.SNOWLINE + 30.0
	var gentle := _snow_in(field, high, 0.1)
	# A genuine cliff, not merely a steep hillside. This asked about a
	# steepness of 0.9 — about forty-two degrees — which is ground snow holds
	# on perfectly well, and the high ground in this valley averages 0.85. The
	# line is where a slope stops keeping anything, and the height field owns
	# it now.
	var cliff := _snow_in(field, high, HeightField.SNOW_SLIDES_AT + 0.3)
	var valley := _snow_in(field, 20.0, 0.1)
	# High and gentle is white — snow, and above it the blue of glacier ice,
	# which is a shade darker than snow and still nothing like rock.
	_expect(gentle > 0.7, "a high shoulder is white with snow and ice (%.2f)" % gentle)
	_expect(_snow_in(field, HeightField.SNOWLINE + 14.0, 0.1) > 0.85, "just above the snowline it is snow, before the ice starts")
	_expect(cliff < 0.15, "a high cliff face is bare rock (%.2f)" % cliff)
	_expect(valley < 0.02, "and the valley floor never is (%.2f)" % valley)
	# The treeline is where snow starts, not somewhere in the middle of the
	# forest: trees stop at TREELINE and snow must not be under them.
	# And nothing white down where the trees and the pasture are: snow starts
	# at the snowline, a good way above the last tree.
	_expect(_snow_in(field, HeightField.TREELINE - 40.0, 0.1) < 0.05, "no snow lies in the forest")
	_expect(_snow_in(field, HeightField.TREELINE + 6.0, 0.1) < 0.15, "nor on the alpine pasture above it")

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

## Every piece in the build palette must be a picture, not a letter.
##
## The house parts were given drawings and the objects were left behind: a
## sapling was "T", a fir "A", a bird feeder "Y". A child who cannot read
## cannot read a letter standing in for a thing either, and a picture nobody
## drew shows as a blank square — which is how the bed went unnoticed for an
## afternoon.
func _check_every_buildable_thing_has_a_picture() -> void:
	print("everything you can build has a picture")
	var drawn := true
	for kind in BuildKinds.ALL:
		if not PartIcon.knows(kind):
			drawn = false
			printerr("  no picture for %s" % kind)
	for kind in HouseParts.ALL:
		if not PartIcon.knows(kind):
			drawn = false
			printerr("  no picture for %s" % kind)
	_expect(drawn, "all %d objects and %d house parts are drawn" % [BuildKinds.ALL.size(), HouseParts.ALL.size()])

	# And each drawing actually puts something on the screen: a `match` with
	# no arm for a kind draws nothing at all and fails silently.
	var blank := true
	for kind in BuildKinds.ALL + HouseParts.ALL:
		var icon := PartIcon.new(kind)
		icon.size = Vector2(64.0, 64.0)
		var drawn_kind := icon.kind
		icon.free()
		if drawn_kind != kind:
			blank = false
	_expect(blank, "and each one is asked to draw its own kind")

	# The letters are gone from the data as well, so nothing can quietly go
	# back to using them.
	var source := FileAccess.get_file_as_string("res://src/build/build_kinds.gd")
	source += FileAccess.get_file_as_string("res://src/build/house_parts.gd")
	_expect(not source.contains('"icon"'), "and no letter icons are left in the data")

	# The palette itself: every button carries a drawing.
	var hud := Hud.new()
	get_root().add_child(hud)
	var pictured := true
	for kind in hud._palette_buttons:
		var button: Button = hud._palette_buttons[kind]
		var has_icon := false
		for child in button.get_children():
			if child is PartIcon:
				has_icon = true
		if not has_icon or button.text != "":
			pictured = false
			printerr("  the %s button is not a picture" % kind)
	_expect(pictured, "every button in the palette is a picture")
	hud.queue_free()

## A horse crossing deep water swims, and carries its rider.
##
## It walked the bottom while the child floated at the surface, so the two
## came apart with a gap of open water between them — reported from the phone
## as "the horse went along the bottom and I stayed up here".
func _check_a_horse_swims() -> void:
	print("a horse swims")
	var field := HeightField.new(20260903)
	var mounts := Mounts.new(field)
	get_root().add_child(mounts)

	# Somewhere the river is genuinely deep.
	var deep := Vector3.ZERO
	var deepest := 0.0
	for z in range(-200, 201, 10):
		var x := field.river_centre_x(float(z))
		var under := HeightField.WATER_LEVEL - field.height_at(x, float(z))
		if under > deepest:
			deepest = under
			deep = Vector3(x, 0.0, float(z))
	_expect(deepest > MountKinds.HORSE_SWIMS_AT, "the river is %.1f m deep somewhere, deep enough to swim" % deepest)

	mounts.place(MountKinds.HORSE, deep)
	var floating := mounts.position_of(MountKinds.HORSE)
	_expect(
		floating.y > field.height_at(deep.x, deep.z) + 0.5,
		"a horse in deep water floats rather than standing on the bed (%.2f m up from it)" % (floating.y - field.height_at(deep.x, deep.z))
	)
	_expect(
		absf(floating.y - (HeightField.WATER_LEVEL - MountKinds.HORSE_DRAUGHT)) < 0.01,
		"at its own draught below the surface"
	)
	_expect(mounts.afloat(MountKinds.HORSE, deep), "and the game knows it is swimming")

	# The rider sits in the saddle. What is held is where they *stand*, and
	# their body is drawn a mount's eye-lift above that: held at the saddle's
	# own height instead, the lift was counted twice and the child hovered a
	# body's length over the horse.
	var stands_at := Mounts.saddle_afloat()
	var body_at := stands_at + MountKinds.eye_lift(MountKinds.HORSE)
	var saddle_on_the_horse := floating.y + MountKinds.HORSE_SADDLE_Y
	_expect(is_equal_approx(stands_at, floating.y), "a rider is held where the horse itself is")
	_expect(
		absf(body_at - saddle_on_the_horse) < 0.25,
		"so their body is drawn in the saddle (%.2f m against the saddle's %.2f)" % [body_at, saddle_on_the_horse]
	)
	_expect(body_at > HeightField.WATER_LEVEL, "and above the water rather than in it")
	# The same relation as on dry land, where nothing was ever wrong.
	var bank_probe := deep + Vector3(60.0, 0.0, 0.0)
	var on_land := field.height_at(bank_probe.x, bank_probe.z) + MountKinds.eye_lift(MountKinds.HORSE)
	_expect(
		absf((on_land - field.height_at(bank_probe.x, bank_probe.z)) - (body_at - stands_at)) < 0.01,
		"held exactly as a rider on land is"
	)

	# On dry land and in the shallows it walks as before.
	var bank := deep + Vector3(60.0, 0.0, 0.0)
	mounts.place(MountKinds.HORSE, bank)
	_expect(
		absf(mounts.position_of(MountKinds.HORSE).y - field.height_at(bank.x, bank.z)) < 0.01,
		"on dry ground it stands on the ground"
	)
	_expect(not mounts.afloat(MountKinds.HORSE, bank), "and is not swimming there")
	_expect(not Mounts.swims(MountKinds.BICYCLE), "a bicycle never swims")
	_expect(not Mounts.swims(MountKinds.boat_id(0)), "and a boat is afloat to begin with")
	mounts.queue_free()

	# The player is held at the saddle rather than swimming under it.
	var rider := Player.new()
	get_root().add_child(rider)
	rider.water_depth = 3.0
	rider.held_at_height = stands_at
	rider._physics_process(1.0 / 60.0)
	_expect(not rider.is_swimming, "a rider on a swimming horse is not swimming themselves")
	rider.held_at_height = Player.NOT_HELD
	rider._physics_process(1.0 / 60.0)
	_expect(rider.is_swimming, "and starts swimming the moment they get off")
	rider.queue_free()

## The archery range needs level ground and no trees on it: it stood on a
## hillside with the wood a few paces from the butts, and an arrow met a
## trunk before it met a target.
func _check_the_range_is_clear() -> void:
	print("the archery range is clear")
	var field := HeightField.new(20260903)
	var camp := field.camp_centre()
	var centre := PlaceSpec.centre_of(&"range", camp)

	# Flat where it matters: across the footprint the shooting line and the
	# butts stand on.
	var lowest := 1e9
	var highest := -1e9
	var footprint: float = PlaceSpec.FOOTPRINT[&"range"]
	for dz in range(-4, 5):
		for dx in range(-4, 5):
			var here := field.height_at(
				centre.x + float(dx) * footprint / 4.0, centre.z + float(dz) * footprint / 4.0
			)
			lowest = minf(lowest, here)
			highest = maxf(highest, here)
	_expect(highest - lowest < 0.12, "the ground under the range is flat to %.3f m" % (highest - lowest))

	# And nothing grows on it, out to well past the furthest butt.
	var wooded := 0.0
	for turn in 24:
		var angle := TAU * float(turn) / 24.0
		for reach in range(1, 11):
			var at := centre + Vector3(cos(angle), 0.0, sin(angle)) * float(reach)
			wooded = maxf(wooded, field.forest_density_at(at.x, at.z))
	_expect(is_zero_approx(wooded), "no tree grows within ten metres of it")
	var further := 0.0
	for turn in 24:
		var angle := TAU * float(turn) / 24.0
		var at := centre + Vector3(cos(angle), 0.0, sin(angle)) * 18.0
		further = maxf(further, field.forest_density_at(at.x, at.z))
	_expect(is_zero_approx(further), "nor as far out as the furthest butt")

	# Nor can a child plant one there.
	_expect(PlaceSpec.reserved(centre.x, centre.z, camp), "and nothing can be built on it")
	_expect(PlaceSpec.reserved(centre.x + 10.0, centre.z, camp), "including ten metres out")
	_expect(not PlaceSpec.reserved(centre.x + 40.0, centre.z, camp), "while the meadow beyond it is a child's own")

	# The hill is still there — the range is a level shelf on it, not a hole
	# cut through it.
	var uphill := 0.0
	for turn in 16:
		var angle := TAU * float(turn) / 16.0
		var at := centre + Vector3(cos(angle), 0.0, sin(angle)) * 60.0
		uphill = maxf(uphill, field.height_at(at.x, at.z) - centre.y)
	_expect(uphill > 4.0, "and the ground still climbs %.0f m beyond it" % uphill)

	# The edge of it must be a slope a child walks up, not a bank they
	# scramble. Six metres of drop feathered over seven is a wall; the range
	# has a fade of its own for that reason.
	# Measured across the fade itself — from just inside the level ground to
	# just past where it meets the hill — and not further: beyond that is the
	# mountain, and a mountain is supposed to be steep.
	var steepest := 0.0
	var from: float = PlaceSpec.RADIUS[&"range"] - 2.0
	var span: float = PlaceSpec.RADIUS[&"range"] + PlaceSpec.feather_of(&"range") + 2.0
	for turn in 24:
		var angle := TAU * float(turn) / 24.0
		var out := Vector3(cos(angle), 0.0, sin(angle))
		var step := 2.0
		var walked := from
		var last := field.height_at(centre.x + out.x * walked, centre.z + out.z * walked)
		walked += step
		while walked <= span:
			var here := field.height_at(centre.x + out.x * walked, centre.z + out.z * walked)
			steepest = maxf(steepest, absf(here - last) / step)
			last = here
			walked += step
	_expect(
		steepest < 0.5,
		"the ground round it rises no more than %.0f cm a stride — a walk, not a scramble" % (steepest * 200.0)
	)

	# Every place, with its own fade, must fit inside the box that decides
	# whether levelling applies at all. The range sat 440 m out against a box
	# of 460 and the far side of its fade fell outside it: the levelling
	# stopped mid-slope and left a three-metre step in the hillside.
	var furthest := 0.0
	var offender := &""
	for place in PlaceSpec.OFFSETS:
		var offset: Vector3 = PlaceSpec.OFFSETS[place]
		var reach: float = PlaceSpec.RADIUS[place] + PlaceSpec.feather_of(place)
		var corner := maxf(absf(offset.x), absf(offset.z)) + reach
		if corner > furthest:
			furthest = corner
			offender = place
	_expect(
		furthest < PlaceSpec.BOUNDS_HALF,
		"every place fits inside the levelling box (%s reaches %.0f m of %.0f)" % [
			offender, furthest, PlaceSpec.BOUNDS_HALF
		]
	)

## A child must be able to see what they are aiming at.
##
## The aim follows the camera's pitch, which is the right control and an
## invisible one: from the phone, "I am shooting but I cannot see how to
## aim". So the bow appears at the child's side and draws as the string is
## pulled, and the arrow's own arc hangs in the air in front of them —
## computed from the shot's own arithmetic, so what is drawn is what flies.
func _check_the_bow_can_be_aimed() -> void:
	print("the bow can be aimed")
	var field := HeightField.new(20260903)

	# The arc is the flight: the same launch the shot uses, integrated the
	# way the arrows are.
	var flat := Archery.launch_velocity(Vector3.FORWARD, Vector3.FORWARD, 1.0, 0.0)
	var lofted := Archery.launch_velocity(Vector3.FORWARD, Vector3.FORWARD, 1.0, 0.8)
	_expect(is_equal_approx(flat.length(), lofted.length()), "aiming higher does not change the speed, only the angle")
	_expect(lofted.y > flat.y, "and a higher aim leaves the bow higher")
	_expect(flat.length() > Archery.SPEED_MIN, "a full draw is faster than an empty one (%.0f m/s)" % flat.length())
	var weak := Archery.launch_velocity(Vector3.FORWARD, Vector3.FORWARD, 0.0, 0.0)
	_expect(weak.length() < flat.length(), "and a tap is slower than a hold")

	var ground := func(_x: float, _z: float) -> float:
		return 0.0
	# Eight seconds, not three: a full draw leaves at forty-four metres a
	# second and a lofted one is still forty metres up at three. The arc the
	# game draws is cut short on purpose — it is an aim, not a survey — but
	# what is asserted here is the flight, so it has to run to the end of it.
	var arc := Archery.predict(Vector3(0.0, 1.2, 0.0), lofted, 8.0, 0.06, ground)
	_expect(arc.size() > 8, "the arc has %d dots in it" % arc.size())
	var peak := 0.0
	for point in arc:
		peak = maxf(peak, point.y)
	_expect(peak > 1.2, "it rises to %.1f m" % peak)
	_expect(is_zero_approx(arc[arc.size() - 1].y), "and ends on the ground")
	var flat_arc := Archery.predict(Vector3(0.0, 1.2, 0.0), flat, 8.0, 0.06, ground)
	# Forward is -Z, so "further" is a smaller z. Compared as distances, which
	# cannot be read backwards the way the raw coordinates were.
	var lofted_reach := absf(arc[arc.size() - 1].z)
	var flat_reach := absf(flat_arc[flat_arc.size() - 1].z)
	_expect(
		lofted_reach > flat_reach,
		"a lofted shot lands further away than a flat one (%.0f m against %.0f)" % [lofted_reach, flat_reach]
	)

	# The bow: hidden until the string is drawn, and drawn as far as it is
	# pulled.
	var child := Player.new()
	get_root().add_child(child)
	_expect(not child.bow_shown(), "no bow while walking about")
	child.hold_the_bow(true, 0.5)
	_expect(child.bow_shown(), "a bow appears when the string is nocked")
	_expect(absf(child.bow_draw() - 0.5) < 0.01, "drawn as far as the string is pulled")
	child.hold_the_bow(true, 1.0)
	_expect(is_equal_approx(child.bow_draw(), 1.0), "and to full draw when it is held")
	child.hold_the_bow(false, 0.0)
	_expect(not child.bow_shown(), "and put away when the arrow is loosed")
	child.queue_free()

## Five horses, spread across the valley and grazing.
##
## There was one, by the camp. A valley with a single horse in it is a valley
## with a vehicle parked in it; a handful grazing on the meadows is a place
## horses live.
func _check_the_horses_are_spread_and_grazing() -> void:
	print("the horses are spread and grazing")
	var field := HeightField.new(20260903)
	var mounts := Mounts.new(field)
	get_root().add_child(mounts)
	var camp := field.camp_centre()
	var spawn := field.find_spawn_point()
	mounts.turn_out_horses(World.HORSES, camp, spawn)
	_expect(mounts.horse_count() == World.HORSES, "%d horses are turned out" % mounts.horse_count())

	# One near the spawn, for the first afternoon.
	var nearest := 1e9
	var spots: Array[Vector3] = []
	for i in World.HORSES:
		var at := mounts.position_of(MountKinds.horse_id(i))
		spots.append(at)
		nearest = minf(nearest, Vector2(at.x - spawn.x, at.z - spawn.z).length())
	_expect(nearest < 20.0, "one is within %.0f m of where a child wakes up" % nearest)

	# And the rest are properly spread, not heaped.
	var closest_pair := 1e9
	var furthest := 0.0
	for i in spots.size():
		for j in range(i + 1, spots.size()):
			closest_pair = minf(closest_pair, spots[i].distance_to(spots[j]))
		furthest = maxf(furthest, Vector2(spots[i].x - camp.x, spots[i].z - camp.z).length())
	_expect(closest_pair > 18.0, "no two are within %.0f m of each other" % closest_pair)
	_expect(furthest > 120.0, "and the furthest grazes %.0f m out" % furthest)

	# Each stands somewhere a horse would: dry, gentle, out of the places.
	var standing := true
	for i in World.HORSES:
		var at := spots[i]
		var ground := field.height_at(at.x, at.z)
		if ground < HeightField.WATER_LEVEL + 0.5:
			standing = false
			printerr("  horse %d stands in water" % i)
		if PlaceSpec.reserved(at.x, at.z, camp):
			standing = false
			printerr("  horse %d stands on somebody's ground" % i)
		if not is_equal_approx(at.y, ground):
			standing = false
			printerr("  horse %d floats %.2f m above the ground" % [i, at.y - ground])
	_expect(standing, "every horse stands on dry, open ground")

	# And no two are the same colour: five identical horses read as one horse
	# drawn five times.
	# Not every horse can have a coat to itself once there is a herd of twenty,
	# but no two standing together should share one.
	var coats := {}
	for i in World.HORSES:
		coats[MountKinds.colour(MountKinds.horse_id(i))] = true
	_expect(
		coats.size() == mini(World.HORSES, MountKinds.HORSE_COATS.size()),
		"the herd wears %d different coats" % coats.size()
	)

	# Grazing: head down, up now and then. Measured at the nose rather than at
	# the joint — the first version had the angle right and the sign wrong, and
	# every horse in the valley stood with its head thrown back over its own
	# withers, staring at the sky. An angle cannot tell those two apart; where
	# the nose ends up can.
	var grazing := MountKinds.horse_id(1)
	var standing_nose := mounts.nose_at(grazing)
	_expect(standing_nose.y > 0.0, "a horse has a nose to put down")
	for _frame in 240:
		mounts._process(1.0 / 60.0)
	var grazing_nose := mounts.nose_at(grazing)
	_expect(
		grazing_nose.y < standing_nose.y - 0.4,
		"grazing drops the nose %.2f m, rather than throwing the head back" % (standing_nose.y - grazing_nose.y)
	)
	var withers := mounts.position_of(grazing).y + MountKinds.HORSE_HEAD_PIVOT.y
	_expect(grazing_nose.y < withers, "the nose ends up below the withers, where grass grows")
	# In front of the body, not folded into it. The horse's own collision box
	# is where the chest ends, so that is what the muzzle has to clear: turning
	# the joint far enough to put the nose on the grass buries the head in the
	# chest instead, because the neck is short and pivots at the shoulder.
	var body_half: float = (MountKinds.body_box(grazing)[0] as Vector3).z * 0.5
	_expect(
		mounts.nose_ahead(grazing) > body_half,
		"and %.2f m out in front of the horse, clear of a chest that ends at %.2f m" % [
			mounts.nose_ahead(grazing), body_half
		]
	)
	# And low enough to read as eating rather than as sniffing the air. It
	# cannot reach the grass itself: this horse's neck is about half the length
	# a real one of its height has, so the muzzle bottoms out short of the
	# ground however far the joint turns.
	_expect(
		grazing_nose.y - mounts.position_of(grazing).y < 1.1,
		"and %.2f m above the grass, which reads as eating" % (grazing_nose.y - mounts.position_of(grazing).y)
	)
	_expect(mounts.head_angle(grazing) > deg_to_rad(30.0), "a horse nobody is riding has its head down")
	var lifted := false
	for _frame in int(Mounts.GRAZE_LOOKS_UP_EVERY * 60.0) + 120:
		mounts._process(1.0 / 60.0)
		if mounts.head_angle(grazing) < deg_to_rad(12.0):
			lifted = true
	_expect(lifted, "and lifts it to look around every so often")

	# A ridden horse holds its head up, whatever the herd is doing.
	_expect(mounts.mount(grazing), "one can still be caught and ridden")
	for _frame in 120:
		mounts.carry(spots[1], 0.0)
		mounts._process(1.0 / 60.0)
	_expect(mounts.head_angle(grazing) < deg_to_rad(12.0), "and stops grazing once it is")
	mounts.queue_free()

## A swing is pumped: push again and it goes higher, up to a limit.
##
## It used to wind a timer: every push gave the same arc, and the ride was over
## in three seconds. Reported from the phone as "one click swings once and
## that is all".
func _check_the_swing_is_pumped() -> void:
	print("the swing is pumped")
	var field := HeightField.new(20260903)
	var camp := field.camp_centre()
	var places := Places.new(field)
	get_root().add_child(places)
	places.stand_up(camp)
	var seat := places.seat_positions()[0]

	# The project's gravity, which is what the seat's pace is worked out from.
	_expect(
		is_equal_approx(Places.SWING_GRAVITY, float(ProjectSettings.get_setting("physics/3d/default_gravity"))),
		"a swing falls under the same gravity as everything else"
	)
	var period := TAU / Places.swing_rate()
	_expect(period > 1.5 and period < 4.0, "a swing of this rope takes %.1f s to go and come back" % period)

	# Each push adds to the arc, and they stack.
	_expect(places.push_swing(seat), "a swing can be pushed by a child standing at it")
	var first := places.swing_arc()
	_expect(first > 0.0, "one push gets it moving")
	places.push_swing(seat)
	var second := places.swing_arc()
	_expect(second > first + 0.1, "a second push takes it higher (%.2f then %.2f rad)" % [first, second])
	places.push_swing(seat)
	var third := places.swing_arc()
	_expect(third > second, "and a third higher still (%.2f rad)" % third)

	# But not for ever: nobody goes over the bar.
	for _push in 20:
		places.push_swing(seat)
	_expect(places.swing_arc() <= Places.SWING_ARC + 0.001, "however many times it is pushed, the arc stops at %.2f rad" % places.swing_arc())
	_expect(Places.SWING_ARC < deg_to_rad(75.0), "which is short of level with the bar")

	# The seat really moves through that arc, and the child moves with it.
	var lowest := 1e9
	var highest := -1e9
	var swept := 0.0
	for _frame in int(TAU / Places.swing_rate() * 60.0) + 4:
		places._process(1.0 / 60.0)
		var rider := places.swing_rider_at()
		lowest = minf(lowest, rider.y)
		highest = maxf(highest, rider.y)
		swept = maxf(swept, Vector2(rider.x - seat.x, rider.z - seat.z).length())
	_expect(highest - lowest > 0.5, "a child on it rises and falls %.2f m" % (highest - lowest))
	_expect(swept > 1.5, "and swings %.1f m out from under the beam" % swept)

	# A full swing lasts, and pushing an already-swinging seat does not hop to
	# the one next door.
	var kept := 0.0
	while places.swinging() and kept < 300.0:
		places._process(1.0 / 60.0)
		kept += 1.0 / 60.0
	_expect(kept > 40.0, "a swing pumped to the top runs for %.0f s before it is done" % kept)

	# And a child can get off before then.
	places.push_swing(seat)
	_expect(places.swinging(), "pushed again, it swings")
	places.step_off_swing()
	_expect(not places.swinging(), "and a child who steps off is walking, not riding")
	places.queue_free()

## A ridden horse has to go round a tree, the same as a child on foot.
##
## What the world could touch was the child's own capsule, a third of a metre
## across, whatever they were sitting on. So a rider passed neatly to one side
## of a trunk while the horse under them — three metres long, nearly one wide —
## went straight through it: from the saddle the forest was not there.
func _check_a_horse_cannot_walk_through_a_wood() -> void:
	print("a horse cannot walk through a wood")
	var field := HeightField.new(20260903)
	var trees := TreeCollision.new(null)
	get_root().add_child(trees)
	_expect(is_equal_approx(trees.trunk_radius(), TreeCollision.TRUNK_RADIUS), "on foot a trunk is %.2f m across" % trees.trunk_radius())

	# Mounted, a trunk stands as wide as the mount, so the drawn animal clears
	# it rather than sliding through it.
	trees.set_girth(MountKinds.girth(MountKinds.HORSE))
	var mounted := trees.trunk_radius()
	var horse_half: float = (MountKinds.body_box(MountKinds.HORSE)[0] as Vector3).x * 0.5
	_expect(mounted > TreeCollision.TRUNK_RADIUS, "on a horse it stands %.2f m across" % mounted)
	_expect(
		mounted - TreeCollision.TRUNK_RADIUS >= horse_half - 0.001,
		"which keeps the horse's flank (%.2f m out) clear of the bark" % horse_half
	)
	_expect(
		mounted + Player.RADIUS - horse_half > TreeCollision.TRUNK_RADIUS,
		"a rider stopped at that distance has the whole animal outside the trunk"
	)

	# A bicycle is narrower than a horse, and on foot the world goes back to
	# being the size it was.
	trees.set_girth(MountKinds.girth(MountKinds.BICYCLE))
	var cycling := trees.trunk_radius()
	_expect(cycling < mounted, "a bicycle needs less room than a horse (%.2f m against %.2f m)" % [cycling, mounted])
	_expect(cycling > TreeCollision.TRUNK_RADIUS, "but more than a child on foot")
	trees.set_girth(MountKinds.girth(&""))
	_expect(is_equal_approx(trees.trunk_radius(), TreeCollision.TRUNK_RADIUS), "and off the bicycle the wood is a wood again")
	trees.queue_free()

	# Nothing is ridden into the pool — not into the water, and not inside the
	# fence either. The poolside is ordinary ground, so a horse could be ridden
	# in through the gate and stand among the loungers, and a rider who got in
	# that way was never asked for a ticket.
	var mounts := Mounts.new(field)
	get_root().add_child(mounts)
	var camp := field.camp_centre()
	var pool := PlaceSpec.centre_of(&"pool", camp)
	_expect(not mounts.can_ride_over(MountKinds.HORSE, pool), "a horse cannot be ridden into the water")
	var poolside := pool + Vector3(PlaceSpec.POOL_HALF_X + 1.5, 0.0, 0.0)
	_expect(
		PlaceSpec.excavation(poolside.x, poolside.z, camp) <= 0.4,
		"the poolside inside the fence is ordinary ground, not a hole"
	)
	_expect(not mounts.can_ride_over(MountKinds.HORSE, poolside), "and cannot be ridden onto the poolside inside the fence")
	var outside := pool + Vector3(Places.POOL_FENCE_X + 3.0, 0.0, 0.0)
	_expect(mounts.can_ride_over(MountKinds.HORSE, outside), "but rides happily past the fence outside it")
	mounts.queue_free()

	# And a rider is never lifted far off the saddle, whatever the ground does.
	_expect(Player.HOLD_SLACK < 0.2, "a held rider is never more than %.2f m off where they are held" % Player.HOLD_SLACK)

## The café's outside tables stand out in front of the door, not against it.
##
## They were two and a half metres from the front wall, with their umbrellas
## over the way in: from the path the café read as a building with furniture
## piled against its door.
func _check_the_terrace_is_off_the_doorstep() -> void:
	print("the terrace is off the doorstep")
	var out := Places.CAFE_FRONT_Z - Places.CAFE_TERRACE_Z
	_expect(out > 0.0, "the terrace is on the door's side of the café")
	_expect(
		out >= Places.CAFE_WIDTH * 0.7 and out <= Places.CAFE_WIDTH * 1.0,
		"and stands %.1f m out, which is %.2f of the café's own length" % [out, out / Places.CAFE_WIDTH]
	)

	# Far enough that nobody has to squeeze past an umbrella to get in, and
	# still on the café's own flat ground rather than out on the slope.
	for table in Places.CAFE_TERRACE:
		var from_door := Vector2(table.x, table.z - Places.CAFE_FRONT_Z).length()
		_expect(from_door > 4.0, "a table %.1f m from the doorway is not in the way of it" % from_door)
		var from_centre := Vector2(table.x, table.z).length()
		_expect(
			from_centre < PlaceSpec.RADIUS[&"cafe"],
			"and stands %.1f m from the middle, inside the %.0f m of level ground" % [
				from_centre, float(PlaceSpec.RADIUS[&"cafe"])
			]
		)

	# And the café still reaches its own terrace: a child who sits down outside
	# must still be able to order. The reach used to be a number written beside
	# the tables, which was true while they stood on the doorstep.
	_expect(
		Places.cafe_reach() > Vector2(Places.CAFE_TERRACE[0].x, Places.CAFE_TERRACE[0].z).length(),
		"the café reaches %.1f m, out past its own furthest table" % Places.cafe_reach()
	)

	# The lamps came with them: a terrace nobody lit is a terrace nobody uses
	# after tea.
	for lamp in Places.CAFE_LAMPS:
		var to_table := 1e9
		for table in Places.CAFE_TERRACE:
			to_table = minf(to_table, Vector2(lamp.x - table.x, lamp.z - table.z).length())
		_expect(to_table < 5.0, "a lamp stands %.1f m from a table it lights" % to_table)

## The shop is a building a child can walk to, and the button that opens it is
## the one they press standing in it.
##
## It had no door of its own at all. The panel was written, the prices were
## checked, the close button worked — and nothing in the whole game ever opened
## it. A child could earn coins for a week and never spend one. Nothing caught
## it because every check asked about the contents of the shop and none asked
## whether a child could get in.
func _check_the_shop_is_somewhere_you_walk_to() -> void:
	print("the shop is somewhere you walk to")
	var field := HeightField.new(20260903)
	var camp := field.camp_centre()
	var places := Places.new(field)
	get_root().add_child(places)
	places.stand_up(camp)

	_expect(places.exists(Places.SHOP), "the shop is a place in the valley")
	var spot := places.position_of(Places.SHOP)

	# Its own quarter of the map: an errand, not something to fall over, and
	# not crowding the café, the playground or the pool.
	var from_camp := Vector2(spot.x - camp.x, spot.z - camp.z).length()
	_expect(from_camp > 300.0, "%.0f m from the camp, which makes going shopping an errand" % from_camp)
	for other: StringName in [Places.PLAYGROUND, Places.CAFE, Places.POOL]:
		var apart := Vector2(
			spot.x - places.position_of(other).x, spot.z - places.position_of(other).z
		).length()
		_expect(apart > 200.0, "%.0f m from %s" % [apart, other])
	# At about the distance the other far places stand at, as asked for.
	var playground_out := Vector2(
		places.position_of(Places.PLAYGROUND).x - camp.x,
		places.position_of(Places.PLAYGROUND).z - camp.z
	).length()
	_expect(
		from_camp > playground_out * 0.8 and from_camp < playground_out * 1.4,
		"a comparable walk to the playground's %.0f m" % playground_out
	)

	# Level ground under it, like every other place, and a building on it.
	var fall := 0.0
	var lowest := 1e9
	var highest := -1e9
	for step in 12:
		var a := TAU * float(step) / 12.0
		var at := spot + Vector3(cos(a), 0.0, sin(a)) * float(PlaceSpec.FOOTPRINT[&"shop"])
		lowest = minf(lowest, field.height_at(at.x, at.z))
		highest = maxf(highest, field.height_at(at.x, at.z))
	fall = highest - lowest
	_expect(fall < 0.05, "its ground is flat to %.3f m across the whole footprint" % fall)
	_expect(places.shop_solid_count() > 0, "the shop has %d solid pieces inside and out" % places.shop_solid_count())

	# Big enough to walk round the stock in, and stocked with the stock: what
	# a child is saving up for stands on the floor of the shop, in its own
	# colours, rather than being a coloured box on a shelf.
	_expect(
		Places.SHOP_WIDTH * Places.SHOP_DEPTH > 180.0,
		"its floor is %.0f square metres" % (Places.SHOP_WIDTH * Places.SHOP_DEPTH)
	)
	_expect(
		Places.SHOP_BICYCLES >= 2 and Places.SHOP_MOTORCYCLES >= 1,
		"%d bicycles and %d motorcycles stand in it" % [Places.SHOP_BICYCLES, Places.SHOP_MOTORCYCLES]
	)
	_expect(Places.SHOP_STAND_Z.size() >= 2, "and the small goods are out on stands")

	# What is in the purse is on the screen at all times, in its own panel
	# between the bag and the health. It was a bare number in warm type over
	# whatever the sky was doing, and it was missed — which matters, because
	# knowing what you have is what decides whether to look after another
	# animal before walking four hundred metres to the shop.
	var screen := Hud.new()
	get_root().add_child(screen)
	screen.set_coins(0)
	_expect(screen._purse != null, "there is a purse on the screen")
	_expect(screen._purse.visible, "and it is there before the first coin is earned")
	screen.set_coins(766)
	_expect(screen._coins_label.text == "766", "it says %s" % screen._coins_label.text)
	var purse_at := screen._purse.position.y
	var bag_at := screen._backpack.position.y
	_expect(purse_at > bag_at, "it sits below the bag")
	_expect(screen._vitals.position.y > purse_at, "and above the health")
	screen.queue_free()

	# Everything the shop has is on the shelf at once. A tile is a button and a
	# button eats the drag before the scrolling shelf sees it, so anything
	# below the fold is unreachable — the bicycle was, and there was nothing to
	# say it existed.
	var on_the_shelf := ShopStock.ALL.size() + ShopStock.BUYS.size()
	var rows := ceili(float(on_the_shelf) / float(Hud.SHOP_COLUMNS))
	_expect(
		rows <= 2,
		"%d things stand %d across in %d rows, which fits without scrolling" % [
			on_the_shelf, Hud.SHOP_COLUMNS, rows
		]
	)

	# The way in is a way in. Nothing stands in the aisle between the door and
	# the counter: a shop with the stock down the middle of it is a shop laid
	# out by somebody who never had to carry anything through one.
	var door_at := places.position_of(Places.SHOP) + Vector3(0.0, 0.0, Places.SHOP_MID_Z - Places.SHOP_DEPTH * 0.5)
	var aisle_clear := true
	for step in 12:
		var along := door_at + Vector3(0.0, 0.9, 1.0 + float(step) * 0.8)
		for piece in places._shop_solid.get_children():
			var shape := piece as CollisionShape3D
			if shape == null or not (shape.shape is BoxShape3D):
				continue
			var box := (shape.shape as BoxShape3D).size
			var middle: Vector3 = places.position_of(Places.SHOP) + shape.position
			if (
				absf(along.x - middle.x) < box.x * 0.5 + 0.35
				and absf(along.z - middle.z) < box.z * 0.5 + 0.35
				and along.y < middle.y + box.y * 0.5
			):
				aisle_clear = false
	_expect(aisle_clear, "the aisle from the door to the counter is clear")

	# A roof comes off while a child is under it. The camera sits above and
	# behind them, so indoors it is up among the rafters looking down, and what
	# it was looking at was tiles — in the café first, and then in the shop.
	var shop_middle := places.position_of(Places.SHOP) + Vector3(0.0, 0.5, Places.SHOP_MID_Z)
	var cafe_middle := places.position_of(Places.CAFE) + Vector3(0.0, 0.5, Places.CAFE_MID_Z)
	places.roofs_follow(shop_middle + Vector3(0.0, 0.0, 200.0))
	_expect(places.roof_is_on(Places.SHOP), "the shop has a roof on it from outside")
	_expect(places.roof_is_on(Places.CAFE), "and so has the café")
	places.roofs_follow(shop_middle)
	_expect(not places.roof_is_on(Places.SHOP), "standing in the shop, its roof is out of the way")
	_expect(places.roof_is_on(Places.CAFE), "and the café's, four hundred metres off, is not")
	places.roofs_follow(cafe_middle)
	_expect(not places.roof_is_on(Places.CAFE), "standing in the café, the café's roof comes off")
	_expect(places.roof_is_on(Places.SHOP), "and the shop's goes back on")
	places.roofs_follow(shop_middle + Vector3(Places.SHOP_WIDTH, 0.0, 0.0))
	_expect(places.roof_is_on(Places.SHOP), "a pace outside the wall, the roof is back")

	# A machine bought at the shop is left outside the shop. They used to be
	# put at the camp, four hundred and fifty metres away: a child bought a
	# bicycle, walked out of the door and found nothing at all.
	for stands: Vector3 in [Places.BICYCLE_STANDS_AT, Places.MOTORCYCLE_STANDS_AT]:
		var parked := places.position_of(Places.SHOP) + stands
		_expect(
			Vector2(stands.x, stands.z).length() < PlaceSpec.RADIUS[&"shop"],
			"a machine bought here stands %.1f m from the door, on the shop's own flat ground" % Vector2(stands.x, stands.z).length()
		)
		_expect(
			not PlaceSpec.indoors(parked.x, parked.z, camp),
			"and outside the building rather than in the middle of the floor"
		)
		_expect(
			stands.z < Places.SHOP_MID_Z - Places.SHOP_DEPTH * 0.5,
			"on the door's side of it, where a child walking out will see it"
		)

	# The roof is a roof: the line from the eave to the ridge climbs at the same
	# angle the boards on it are tilted. It climbed at seven and a half degrees
	# while every board was tilted at thirty-four, because the ridge's height
	# was a number written down beside the pitch rather than worked out from
	# it — so the slopes stood at an angle to their own roof and never met.
	var eave_y := Places.shop_eave_height()
	var ridge_y := Places.shop_ridge_height()
	var half_span := Places.SHOP_WIDTH * 0.5 + Places.SHOP_ROOF_OVERHANG
	var climbs := rad_to_deg(atan((ridge_y - eave_y) / half_span))
	_expect(
		absf(climbs - Places.SHOP_ROOF_PITCH) < 0.01,
		"the roof climbs at %.1f degrees, which is the pitch its boards are laid at" % climbs
	)
	_expect(ridge_y > eave_y + 2.0, "the ridge stands %.1f m above the eaves" % (ridge_y - eave_y))
	_expect(
		ridge_y < Places.SHOP_HEIGHT * 2.2,
		"and %.1f m above the floor, which is a barn rather than a spire" % ridge_y
	)

	# The shop is lit. A tall room with a roof on it is a dark room, and what a
	# child saw walking in was a shed full of shapes.
	var lit := 0
	for child in places.get_children():
		var lamp := child as OmniLight3D
		if lamp == null:
			continue
		if PlaceSpec.indoors(lamp.position.x, lamp.position.z, camp):
			lit += 1
	_expect(lit >= 4, "%d lights hang inside the shop" % lit)

	# And the lake is blue on the map. The colouring asked whether the ground
	# was below the world's waterline, and a raised pond's bed is eleven metres
	# above it, so the one piece of open water in that quarter came out green.
	var map := Minimap.new(field)
	var lake_at := Vector2(Lakes.at(1, Lakes.POND_X), Lakes.at(1, Lakes.POND_Z))
	_expect(
		map._colour_at(lake_at.x, lake_at.y) == Minimap.WATER,
		"the lake up the hill is drawn as water on the map"
	)
	map.queue_free()

	# Nothing grows through the floor of a building.
	var inside_shop := places.position_of(Places.SHOP) + Vector3(0.0, 0.0, Places.SHOP_MID_Z)
	_expect(
		PlaceSpec.indoors(inside_shop.x, inside_shop.z, camp),
		"the middle of the shop counts as indoors, where nothing is planted"
	)
	_expect(
		not PlaceSpec.indoors(inside_shop.x + Places.SHOP_WIDTH, inside_shop.z, camp),
		"and the ground outside its wall does not"
	)

	# Everything the shop sells has a name, a price, a picture for the panel and
	# a shape for the shelf. A thing you can buy and cannot see is a thing a
	# child never buys.
	var stocked := true
	for item in ShopStock.ALL:
		if ShopStock.price(item) <= 0:
			stocked = false
			printerr("  %s costs nothing" % item)
		for code: StringName in [Text.EN, Text.FR, Text.RU]:
			Text.set_language(code)
			if ShopStock.label(item).begins_with("?"):
				stocked = false
				printerr("  %s has no name in %s" % [item, code])
	Text.set_language(Text.EN)
	_expect(stocked, "every one of the %d things for sale is priced and named" % ShopStock.ALL.size())
	_expect(places.shop_wall_count() >= 4, "and %d walls, which the camera stops at" % places.shop_wall_count())
	_expect(
		(places._shop_walls.collision_layer & TerrainSpec.LAYER_WALLS) != 0,
		"the walls are on the layer the camera arm watches"
	)

	# Standing at the counter offers the shop, and standing anywhere else does
	# not. This is the assertion that was missing.
	_expect(places.nearest(spot) == Places.SHOP, "a child standing in it is offered the shop")
	_expect(
		places.nearest(spot + Vector3(40.0, 0.0, 0.0)) != Places.SHOP,
		"and one forty metres away is not"
	)

	# Nothing is ridden in through the doorway; there is a rail outside to tie
	# a horse to instead.
	_expect(Places.SHOP_RAIL_X != 0.0 or Places.SHOP_RAIL_Z != 0.0, "there is a hitching rail outside")
	places.queue_free()

## Every pond has a shore a child can walk out by, and its water never stands
## higher than the ground holding it in.
##
## Both ponds were dug straight down to the world's waterline wherever they
## happened to lie. The eastern one lies on a shoulder of hill thirteen metres
## up, so what was there was a crater forty metres across with water in the
## bottom and banks too steep to climb — reported from the phone as "a huge pit
## with water; if you fall in you cannot get out". It was exactly that.
func _check_a_child_can_get_out_of_every_pond() -> void:
	print("a child can get out of every pond")
	var field := HeightField.new(20260903)
	for pond in Lakes.count():
		var cx := Lakes.at(pond, Lakes.POND_X)
		var cz := Lakes.at(pond, Lakes.POND_Z)
		var long_axis := Lakes.at(pond, Lakes.POND_LONG)
		var short_axis := Lakes.at(pond, Lakes.POND_SHORT)
		var angle := Lakes.at(pond, Lakes.POND_ANGLE)
		var level := Lakes.at(pond, Lakes.POND_LEVEL)

		# The ground all round the outside of the basin. The lowest of it is
		# the lip the water would run out over, and the gentlest of it is the
		# way out.
		var lowest_shore := 1e9
		var kindest_bank := 1e9
		for step in 72:
			var bearing := TAU * float(step) / 72.0
			var along := cos(bearing) * long_axis
			var across := sin(bearing) * short_axis
			var turned := Vector2(
				along * cos(angle) - across * sin(angle),
				along * sin(angle) + across * cos(angle)
			)
			var out_at := Vector3(cx + turned.x * 1.35, 0.0, cz + turned.y * 1.35)
			if Lakes.influence(out_at.x, out_at.z) > 0.0:
				continue
			lowest_shore = minf(lowest_shore, field.height_at(out_at.x, out_at.z))
			# How steeply the bank climbs from the water's edge to that ground:
			# the rise over the last stretch of shore.
			var edge_at := Vector3(cx + turned.x, 0.0, cz + turned.y)
			var rise := field.height_at(out_at.x, out_at.z) - field.height_at(edge_at.x, edge_at.z)
			var run := Vector2(turned.x, turned.y).length() * 0.35
			kindest_bank = minf(kindest_bank, rise / maxf(run, 0.01))

		# Water that stands above the lowest ground on its shore is water
		# running out over that lip.
		_expect(
			level <= lowest_shore + 0.01,
			"pond %d holds its water: the surface at %.1f m is under the lowest shore at %.1f m" % [
				pond + 1, level, lowest_shore
			]
		)
		# And it is not a well: a child who swims to the right side of it walks
		# out rather than treading water against a wall.
		_expect(
			lowest_shore - level < 1.6,
			"and its lowest shore is %.2f m above the water, which is a step and not a wall" % (lowest_shore - level)
		)
		_expect(
			kindest_bank < 0.9,
			"its gentlest bank climbs at %.2f, which a child walks up" % kindest_bank
		)

		# The bed is below the water everywhere a child could be swimming, and
		# the drop from the surface to the bed is the depth it is meant to be.
		var deepest := level - field.height_at(cx, cz)
		_expect(
			deepest > 1.0 and deepest <= Lakes.DEPTH + 0.01,
			"pond %d is %.1f m deep: enough to swim, not enough to lose anybody" % [pond + 1, deepest]
		)

		# Nothing grows in it, whatever height it stands at. A raised pond's
		# bed is well above the world's waterline, and to everything that asks
		# the height alone it looked like dry hillside.
		_expect(field.is_pond(cx, cz), "and the world knows pond %d is water" % (pond + 1))

		# It is painted as water, too. The terrain's colouring measured the
		# ground against the sea, so the bed of a pond eleven metres up came
		# out meadow green — green sand under blue water, and no beach at all
		# round the one lake a child swims in.
		var bed := TerrainChunk._tint(
			field, cx, cz, field.height_at(cx, cz), 0.0, false, false, false
		)
		_expect(
			bed.b > bed.g * 0.85,
			"the bed of pond %d is painted as a bed rather than as a meadow" % (pond + 1)
		)
		var beach_at := Vector3(cx + long_axis * 1.02, 0.0, cz)
		var beach := TerrainChunk._tint(
			field, beach_at.x, beach_at.z, field.height_at(beach_at.x, beach_at.z),
			0.0, false, false, false
		)
		_expect(
			beach.r > beach.g * 0.9,
			"and there is sand along its shore rather than grass to the water's edge"
		)

		# You walk in and you are swimming. The bed used to start climbing a
		# third of the way out, so a child waded a long way down a slope in
		# knee-deep water and never got off their feet — reported from the
		# phone as walking about on the bottom of the pond.
		var wet_at := -1.0
		var swimming_at := -1.0
		for step in range(0, 200):
			var out := long_axis * 1.25 - float(step) * 0.5
			var depth := level - field.height_at(cx + out, cz)
			if depth > 0.05 and wet_at < 0.0:
				wet_at = float(step) * 0.5
			if depth >= Player.SWIM_DEPTH and swimming_at < 0.0:
				swimming_at = float(step) * 0.5
				break
		_expect(swimming_at > 0.0, "a child walking into pond %d ends up swimming" % (pond + 1))
		_expect(
			swimming_at - wet_at < 8.0,
			"after %.1f m of wading, not a walk down a slope" % (swimming_at - wet_at)
		)

		# And the shore they walked in from is a step above the water, not a
		# wall: the whole ring of it, measured in the pond's own frame rather
		# than on a circle that overshoots the short axis.
		var shore_low := 1e9
		var shore_high := -1e9
		for step in 48:
			var bearing := TAU * float(step) / 48.0
			var along := cos(bearing) * 1.1 * long_axis
			var across := sin(bearing) * 1.1 * short_axis
			var at := Vector3(
				cx + along * cos(angle) - across * sin(angle), 0.0,
				cz + along * sin(angle) + across * cos(angle)
			)
			shore_low = minf(shore_low, field.height_at(at.x, at.z))
			shore_high = maxf(shore_high, field.height_at(at.x, at.z))
		_expect(
			shore_high - level <= Lakes.SHORE_RISE + 0.01,
			"its shore stands %.2f m above the water all the way round" % (shore_high - level)
		)
		_expect(shore_low >= level - 0.01, "and none of it is under water")

	# A raised pond gets a surface of its own, because the world's one sheet of
	# water lies flat at zero and cannot cover it.
	var water := Water.new()
	get_root().add_child(water)
	var raised := 0
	for pond in Lakes.count():
		if Lakes.is_raised(pond, HeightField.WATER_LEVEL):
			raised += 1
	_expect(water.tarn_count() == raised, "%d pond(s) above the waterline have a surface drawn at their own height" % water.tarn_count())
	for i in water.tarn_count():
		_expect(
			water.tarn_level(i) > HeightField.WATER_LEVEL,
			"and it stands at %.1f m rather than at the sea's level" % water.tarn_level(i)
		)
		# It hangs from the sheet of water that follows the player about. A
		# lake does not follow anybody: wherever the sheet has gone, the lake
		# is still on its own hill, or a child finds the dry bowl it was dug
		# out of.
		var where := water.tarn_world_position(i)
		water.follow(Vector3(600.0, 0.0, -450.0))
		var moved := water.tarn_world_position(i).distance_to(where)
		_expect(moved < 0.01, "and stays on its hill when the child walks away (%.2f m of drift)" % moved)
		water.follow(Vector3.ZERO)
	water.queue_free()

	# Swimming works up there: a child in the middle of a raised pond is in
	# water, not standing on a hillside.
	var places := Places.new(field)
	get_root().add_child(places)
	places.stand_up(field.camp_centre())
	for pond in Lakes.count():
		if not Lakes.is_raised(pond, HeightField.WATER_LEVEL):
			continue
		# Standing on the bed in the middle of it, which is where a child who
		# waded in ends up.
		var middle := Vector3(
			Lakes.at(pond, Lakes.POND_X), 0.0, Lakes.at(pond, Lakes.POND_Z)
		)
		middle.y = field.height_at(middle.x, middle.z) + Player.HEIGHT * 0.5
		var depth := places.submersion(middle, Player.HEIGHT)
		_expect(depth > Player.SWIM_DEPTH, "a child in the middle of it is %.2f m under and swimming" % depth)
	places.queue_free()

## Ducks on the ponds: afloat, staying on their own water, and asking nothing
## of anybody.
##
## They are the one living thing here that is not an errand. Everything else
## that moves wants a cone or a stick or a stroke, and a valley where every
## moving thing is a task is a place to work rather than a place to be.
func _check_the_ducks_are_only_ducks() -> void:
	print("the ducks are only ducks")
	var ducks := Ducks.new()
	get_root().add_child(ducks)
	ducks.settle(20260903)
	_expect(
		ducks.count() == Lakes.count() * Ducks.PER_POND,
		"%d ducks, %d on each pond" % [ducks.count(), Ducks.PER_POND]
	)

	# Each one floats on the water of the pond it belongs to, not on the world's
	# waterline and not on the bed.
	var afloat := true
	var inside := true
	for i in ducks.count():
		var pond := ducks.duck_pond(i)
		var at := ducks.duck_position(i)
		if absf(at.y - Lakes.at(pond, Lakes.POND_LEVEL)) > 0.1:
			afloat = false
			printerr("  duck %d sits %.2f m off its pond's surface" % [
				i, at.y - Lakes.at(pond, Lakes.POND_LEVEL)
			])
		if Lakes.influence(at.x, at.z) <= 0.0:
			inside = false
			printerr("  duck %d is not on any pond at all" % i)
	_expect(afloat, "every duck floats on its own pond's surface")
	_expect(inside, "and every one of them is on the water")

	# They paddle, and they stay on the pond: a duck that walks up the bank and
	# off across the meadow is a duck that has stopped being decoration.
	var before := ducks.duck_position(0)
	for _frame in 60:
		ducks._process(1.0 / 60.0)
	_expect(ducks.duck_position(0).distance_to(before) > 0.2, "they paddle about")
	for _frame in 3600:
		ducks._process(1.0 / 60.0)
	var ashore := 0
	for i in ducks.count():
		var at := ducks.duck_position(i)
		if Lakes.influence(at.x, at.z) <= 0.0:
			ashore += 1
	_expect(ashore == 0, "and after a minute of paddling none has left the water")

	# Solid: a duck you swim straight through is a picture of a duck.
	var solid := true
	for i in ducks.count():
		if not ducks.is_solid(i):
			solid = false
	_expect(solid, "every duck is something a child bumps into")

	# And they are not animals: nothing to feed, no coins, no cooldown.
	var is_animal := false
	for kind in AnimalKinds.ALL:
		if String(kind).contains("duck"):
			is_animal = true
	_expect(not is_animal, "a duck is not one of the animals that wants something")
	ducks.queue_free()

## A motorcycle is heard. The whole trade the machine offers is that it is the
## fastest thing in the valley and empties the meadow around it — and it was
## emptying the meadow in silence, which reads as the animals fleeing for no
## reason.
func _check_the_motorcycle_is_heard() -> void:
	print("the motorcycle is heard")
	var sound := Ambience.new()
	get_root().add_child(sound)
	_expect(not sound.engine_is_running(), "nothing is running before anybody starts one")
	sound.engine(0.0)
	_expect(sound.engine_is_running(), "an idling engine is heard")
	var idle := sound._engine.pitch_scale
	var idle_db := sound._engine.volume_db
	sound.engine(1.0)
	_expect(sound._engine.pitch_scale > idle, "it rises in pitch as the machine pulls away")
	_expect(sound._engine.volume_db > idle_db, "and in loudness with it")

	# Through the gears: the note climbs, drops as it changes up, and climbs
	# again. A single ramp from idle to flat out is a siren.
	var notes := PackedFloat32Array()
	for step in 31:
		sound.engine(float(step) / 30.0)
		notes.append(sound._engine.pitch_scale)
	var drops := 0
	for i in range(1, notes.size()):
		if notes[i] < notes[i - 1] - 0.05:
			drops += 1
	_expect(
		drops == Ambience.GEARS - 1,
		"it changes up %d times between a standstill and full pelt" % drops
	)

	# The waveform loops without a click: every part of it has to complete a
	# whole number of cycles, or the end does not meet the beginning and the
	# join is heard once a second for ever.
	var wave := sound._engine.stream as AudioStreamWAV
	var bytes := wave.data
	var last := bytes[bytes.size() - 2] | (bytes[bytes.size() - 1] << 8)
	if last >= 32768:
		last -= 65536
	var first := bytes[0] | (bytes[1] << 8)
	if first >= 32768:
		first -= 65536
	_expect(
		absi(first - last) < 4000,
		"and its ends meet, within %d of 32768, so the loop does not click" % absi(first - last)
	)
	# An engine is two sounds. The first version was only the top one, which
	# pitched down to idle is a mosquito and pitched up is a hairdryer; what a
	# child hears going past the window is the exhaust. So the two trade places
	# as the revs come up — thump at rest, wail at speed — and the thump is
	# swept over a much smaller range, because a thump pitched up an octave is
	# not a thump.
	_expect(
		Ambience.EXHAUST_PITCH_RANGE < Ambience.ENGINE_PITCH_RANGE * 0.5,
		"the exhaust is swept over %.2f against the wail's %.2f" % [
			Ambience.EXHAUST_PITCH_RANGE, Ambience.ENGINE_PITCH_RANGE
		]
	)
	sound.engine(0.0)
	var thump_idle := sound._exhaust.volume_db
	var wail_idle := sound._engine.volume_db
	sound.engine(1.0)
	_expect(
		sound._exhaust.volume_db < thump_idle,
		"the thump eases off as the machine pulls away"
	)
	_expect(
		sound._engine.volume_db > wail_idle,
		"while the wail comes up"
	)
	_expect(
		thump_idle > wail_idle,
		"so a standing engine is mostly exhaust: %.1f dB against %.1f" % [thump_idle, wail_idle]
	)

	# The exhaust loops without a click as well: its rings are wrapped round
	# the end of the loop rather than cut off there.
	var thump := sound._exhaust.stream as AudioStreamWAV
	var thump_bytes := thump.data
	var thump_last := thump_bytes.decode_s16(thump_bytes.size() - 2)
	var thump_first := thump_bytes.decode_s16(0)
	# Measured against the steps the waveform takes anyway, not against zero:
	# a firing begins at the loop point, and a firing begins with a crack. The
	# question is whether the join is bigger than the fifty-four cracks a
	# second either side of it, not whether it is small.
	var thump_usual := 0.0
	for i in range(1, 8000):
		thump_usual += absf(float(
			thump_bytes.decode_s16(i * 2) - thump_bytes.decode_s16((i - 1) * 2)
		))
	thump_usual /= 7999.0
	_expect(
		absf(float(thump_first - thump_last)) < thump_usual * 14.0,
		"the exhaust joins with a step of %d against its usual %.0f" % [
			absi(thump_first - thump_last), thump_usual
		]
	)

	sound.engine(-1.0)
	_expect(not sound.engine_is_running(), "and stops when the rider gets off")
	_expect(not sound._exhaust.playing, "both halves of it stop together")

	# Louder than the wood it is driven into. An engine that the leaves drown
	# is an engine a child cannot hear themselves riding.
	sound.engine(0.6)
	var engine_db := sound._engine.volume_db
	_expect(
		engine_db > Ambience.LEAVES_DB and engine_db > Ambience.WIND_DB,
		"an engine at %.0f dB is heard over leaves at %.0f" % [engine_db, Ambience.LEAVES_DB]
	)
	# And its waveform fills the range, or the numbers above mean nothing: two
	# voices at the same volume setting are only as loud as their samples are.
	_expect(
		sound.engine_peak() > 0.7,
		"and its sound uses %.0f%% of the range, like the other voices" % (sound.engine_peak() * 100.0)
	)
	sound.queue_free()

	# What it costs: everything within earshot goes, whatever it was doing.
	var field := HeightField.new(20260903)
	var beasts := Animals.new(field, 20260903)
	get_root().add_child(beasts)
	var spot := field.find_spawn_point()
	var beast := beasts.put_one_at(AnimalKinds.DOG, spot + Vector3(6.0, 0.0, 0.0))
	beasts.racket = true
	beasts.watch(spot, Inventory.new())
	var fleeing: Vector3 = beast["target"]
	_expect(
		fleeing.distance_to(spot) > (beast["node"] as Node3D).position.distance_to(spot),
		"an animal near a running engine heads away from it"
	)
	_expect(
		float(beast["speed"]) > Animals.SPEED,
		"at a run rather than a walk (%.1f m/s)" % float(beast["speed"])
	)
	_expect(Animals.RACKET_RANGE > Animals.NOTICE * 3.0, "and it is heard %.0f m off, long before it is seen" % Animals.RACKET_RANGE)
	beasts.queue_free()

## The icon: four files that have to agree with each other and with the game.
##
## An icon is the one picture of this game most people ever see, and it is also
## the easiest thing in the project to break silently — the PNGs the exporter
## ships are rasterised from the SVGs by hand, so an edited drawing with a
## stale PNG beside it looks perfectly fine in the repository and ships the old
## picture.
func _check_the_icon_is_the_valley() -> void:
	print("the icon is the valley")
	for path: String in [
		"res://icon.svg",
		"res://android/icons/foreground.svg",
		"res://android/icons/background.svg",
		"res://android/icons/monochrome.svg",
	]:
		_expect(FileAccess.file_exists(path), "%s is there" % path)

	# Each shipped PNG is the size the exporter asks for, and each is what its
	# own SVG draws right now rather than what it drew last week.
	for job: Array in [
		["res://android/icons/foreground.svg", "res://android/icons/foreground_432.png", 432],
		["res://android/icons/background.svg", "res://android/icons/background_432.png", 432],
		["res://android/icons/monochrome.svg", "res://android/icons/monochrome_432.png", 432],
	]:
		var shipped := Image.load_from_file(job[1])
		_expect(shipped != null, "%s is a picture" % job[1])
		if shipped == null:
			continue
		_expect(
			shipped.get_width() == int(job[2]) and shipped.get_height() == int(job[2]),
			"%s is %d by %d" % [job[1], shipped.get_width(), shipped.get_height()]
		)
		var drawn := Image.new()
		drawn.load_svg_from_string(
			FileAccess.get_file_as_string(job[0]), float(int(job[2])) / 128.0
		)
		var differs := 0
		for y in range(0, shipped.get_height(), 7):
			for x in range(0, shipped.get_width(), 7):
				if shipped.get_pixel(x, y).is_equal_approx(drawn.get_pixel(x, y)):
					continue
				differs += 1
		_expect(
			differs == 0,
			"%s matches the drawing it comes from" % job[1].get_file()
		)

	# The plain icon — the one a launcher falls back to — is the two adaptive
	# layers flattened, square and full bleed. Rounding its corners here shows
	# up as a small rounded picture sitting inside the launcher's own shape,
	# which is how it looked on the phone.
	var legacy := Image.load_from_file("res://android/icons/main_192.png")
	_expect(legacy != null, "there is a plain icon for launchers that want one")
	if legacy != null:
		_expect(legacy.get_width() == 192, "%d px square" % legacy.get_width())
		var corners_filled := true
		for corner: Vector2i in [
			Vector2i(1, 1), Vector2i(190, 1), Vector2i(1, 190), Vector2i(190, 190)
		]:
			if legacy.get_pixelv(corner).a < 0.99:
				corners_filled = false
		_expect(corners_filled, "and painted right into its corners, not rounded")

	# The themed icon has to be a picture rather than a blank or a slab: the
	# launcher tints every pixel the same colour, so it is the gaps that carry
	# the drawing.
	var mono := Image.load_from_file("res://android/icons/monochrome_432.png")
	var covered := 0
	for y in range(0, mono.get_height(), 3):
		for x in range(0, mono.get_width(), 3):
			if mono.get_pixel(x, y).a > 0.5:
				covered += 1
	var samples := (mono.get_height() / 3) * (mono.get_width() / 3)
	var share := float(covered) / float(samples)
	_expect(
		share > 0.15 and share < 0.75,
		"the themed icon covers %.0f%% of its square: a drawing, not a blank or a slab" % (share * 100.0)
	)

	# Nothing that reads as its own object may sit outside the safe circle an
	# adaptive icon guarantees — two thirds of the half-width — or a round mask
	# cuts it in half. The sun was moved once for exactly this.
	var safe := 128.0 * 0.667 * 0.5
	var scene := FileAccess.get_file_as_string("res://android/icons/foreground.svg")
	for object: Array in [["the sun", 80.0, 40.0, 11.0], ["the horse", 52.0, 89.0, 13.0]]:
		var out := Vector2(float(object[1]) - 64.0, float(object[2]) - 64.0).length() + float(object[3])
		_expect(
			out < safe,
			"%s reaches %.0f units from the middle, inside the safe %.0f" % [object[0], out, safe]
		)
	_expect(scene.contains("cx=\"80\" cy=\"40\""), "and the sun is where this check thinks it is")

## Somebody of every kind lives here.
##
## The animals are spawned tile by tile from rules about the ground, which is
## the right way round — they live where they would live — and it means a rule
## that contradicts itself does not fail, it just quietly produces nothing. The
## beavers were exactly that: theirs asked for ground within fourteen metres of
## a river thirty-two metres across, so every point it accepted was riverbed,
## and the riverbed is under water and thrown away one line earlier. One beaver
## lived in the whole valley, and the dam they exist for needs them.
func _check_the_valley_is_populated() -> void:
	print("the valley is populated")
	var field := HeightField.new(20260903)
	var animals := Animals.new(field, 20260903)
	get_root().add_child(animals)

	var tally := {}
	var reach := 10
	var tiles := 0
	for tx in range(-reach, reach + 1):
		for tz in range(-reach, reach + 1):
			tiles += 1
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(Vector3i(20260903 + 331, tx, tz))
			for _index in Animals.CANDIDATES_PER_TILE:
				var x := float(tx * Animals.TILE_SIZE) + rng.randf() * Animals.TILE_SIZE
				var z := float(tz * Animals.TILE_SIZE) + rng.randf() * Animals.TILE_SIZE
				var kind: StringName = animals._kind_at(x, z, rng)
				if kind != &"":
					tally[kind] = int(tally.get(kind, 0)) + 1

	for kind in AnimalKinds.ALL:
		var many := int(tally.get(kind, 0))
		_expect(
			many >= tiles / 100,
			"%d %ss live in %d tiles of valley" % [many, kind, tiles]
		)
	animals.queue_free()

	# And the things that are placed rather than spawned.
	_expect(
		World.HORSES == int(AnimalKinds.WANTED.get(&"horse", World.HORSES)),
		"%d horses are turned out" % World.HORSES
	)
	_expect(
		Lakes.count() * Ducks.PER_POND >= 6,
		"%d ducks are on the ponds" % (Lakes.count() * Ducks.PER_POND)
	)

## Snow lies on the shoulders of the mountains and slides off their cliffs.
##
## It was cut off at a steepness of 0.42, and the high ground in this valley
## averages 0.85 — so five sixths of every mountain was bare, and from the
## meadow the peaks read as grey rock with a dusting on top. What a child
## should see is white shoulders with dark crags between them.
func _check_snow_lies_on_the_shoulders() -> void:
	print("snow lies on the shoulders")
	var field := HeightField.new(20260903)
	var above := 0
	var white := 0
	var icy := 0
	var cliffs := 0
	var white_cliffs := 0
	for gx in range(-80, 81, 2):
		for gz in range(-80, 81, 2):
			var x := float(gx) * 8.0
			var z := float(gz) * 8.0
			var height := field.height_at(x, z)
			if height < HeightField.SNOWLINE:
				continue
			above += 1
			var steep := field.steepness_at(x, z)
			if HeightField.snow_at(height, steep) > 0.6:
				white += 1
			if HeightField.ice_at(height, steep) > 0.35:
				icy += 1
			if steep > HeightField.SNOW_SLIDES_AT:
				cliffs += 1
				if HeightField.snow_at(height, steep) > 0.5:
					white_cliffs += 1
	_expect(above > 100, "there is high ground to put snow on (%d samples)" % above)
	var share := float(white) / maxf(float(above), 1.0)
	_expect(
		share > 0.6,
		"%.0f%% of the ground above the snowline is under snow" % (share * 100.0)
	)
	_expect(
		float(icy) / maxf(float(above), 1.0) > 0.1,
		"and %.0f%% of it carries glacier ice" % (100.0 * float(icy) / maxf(float(above), 1.0))
	)
	_expect(
		white_cliffs == 0,
		"while none of its %d cliffs is white: snow slides off anything past %.2f" % [
			cliffs, HeightField.SNOW_SLIDES_AT
		]
	)

	# The near ground and the far mountains have to agree, or the line where
	# the streamed valley ends and the painted range begins is a seam a child
	# can see. They each had their own copy of this, with different numbers.
	var land := DistantLand.new(field)
	get_root().add_child(land)
	var mismatched := 0
	for step in 40:
		var at := Vector3(float(step) * 21.0 - 420.0, 0.0, 380.0)
		var height := field.height_at(at.x, at.z)
		if height < HeightField.SNOWLINE - 30.0:
			continue
		var steep := field.steepness_at(at.x, at.z)
		var near := TerrainChunk._tint(field, at.x, at.z, height, steep, false, false, false)
		var far := land._colour(height, at.x, at.z)
		if absf(near.r - far.r) > 0.35:
			mismatched += 1
	_expect(mismatched == 0, "the far mountains are the colour the near ones are")
	land.queue_free()

## Sheep and cows: the two animals that give a thing rather than coins.
##
## Everything else in this valley pays in coins on a cooldown, which makes the
## meadows a place to collect money. A fleece has to be cut, carried and sold,
## and milk is drunk where it stands — so the flock is a trade and the herd is
## a larder, and neither is another coin dispenser.
func _check_a_flock_is_worth_keeping() -> void:
	print("a flock is worth keeping")
	var field := HeightField.new(20260903)
	var animals := Animals.new(field, 20260903)
	get_root().add_child(animals)
	var spot := field.find_spawn_point()

	# A sheep gives wool, and only to somebody with shears. Offering it to a
	# child who has none would teach them to press a button that does nothing.
	var sheep := animals.put_one_at(AnimalKinds.SHEEP, spot + Vector3(2.0, 0.0, 0.0))
	var bag := Inventory.new()
	animals.has_shears = false
	_expect(
		animals.nearest_caring(spot, bag).is_empty(),
		"a sheep offers nothing to a child with no shears"
	)
	animals.has_shears = true
	_expect(
		not animals.nearest_caring(spot, bag).is_empty(),
		"and offers itself to one who has them"
	)
	_expect(AnimalKinds.gives(AnimalKinds.SHEEP) == ItemKinds.WOOL, "what it gives is wool")
	_expect(AnimalKinds.coins(AnimalKinds.SHEEP) == 0, "and not coins")
	_expect(animals.care_for(sheep, bag) == 0, "shearing pays no coins")
	_expect(animals.last_gift == ItemKinds.WOOL, "it hands over a fleece")
	_expect(
		float(sheep["cooldown"]) > 60.0,
		"and grows the next one over %.0f seconds" % float(sheep["cooldown"])
	)

	# A cow gives milk, which is drunk rather than carried.
	var cow := animals.put_one_at(AnimalKinds.COW, spot + Vector3(-2.0, 0.0, 0.0))
	animals.last_gift = &""
	_expect(animals.care_for(cow, bag) == 0, "milking pays no coins either")
	_expect(animals.last_gift == &"milk", "what a cow gives is milk")
	_expect(
		AnimalKinds.cooldown(AnimalKinds.COW) > AnimalKinds.cooldown(AnimalKinds.SHEEP),
		"and a cow is ready again less often than a sheep"
	)
	animals.queue_free()

	# The shop buys the fleece. It is the first thing this shop has ever bought
	# rather than sold, and the reason the shears are worth twenty-five coins.
	_expect(ShopStock.pays_for(ItemKinds.WOOL) > 0, "the shop pays %d a fleece" % ShopStock.pays_for(ItemKinds.WOOL))
	_expect(ShopStock.pays_for(ItemKinds.STICK) == 0, "and buys nothing else")
	var fleeces := ShopStock.price(ShopStock.SHEARS) / ShopStock.pays_for(ItemKinds.WOOL)
	_expect(
		fleeces > 3 and fleeces < 20,
		"the shears pay for themselves in %d fleeces: worth doing, not free money" % fleeces
	)

	# And wool is a thing the bag can draw and name, like everything else in
	# it. An item with no picture is an item a child cannot find.
	for code: StringName in [Text.EN, Text.FR, Text.RU]:
		Text.set_language(code)
		_expect(not ItemKinds.label(ItemKinds.WOOL).begins_with("?"), "wool is named in %s" % code)
	Text.set_language(Text.EN)

## Every animal has everything an animal here needs.
##
## Adding a kind means touching half a dozen tables in five files, and missing
## one of them fails silently: the sheep arrived with no voice — a hundred of
## them standing about the meadows in complete silence — and with a prompt over
## their heads saying they wanted stroking. Neither broke anything, and neither
## would ever have shown up in a check that only asked whether sheep exist.
func _check_every_animal_is_finished() -> void:
	print("every animal is finished")
	var voices := AnimalVoices.new()
	get_root().add_child(voices)
	voices.bake_now()

	for kind in AnimalKinds.ALL:
		# A body, of a believable size.
		var box := AnimalKinds.build_mesh(kind).get_aabb().size
		_expect(
			box.x > 0.2 and box.y > 0.2 and box.z > 0.3,
			"a %s is %.1f by %.1f by %.1f m" % [kind, box.x, box.y, box.z]
		)
		# A name, in every language, and a prompt that says what to do with it
		# rather than what to do with some other animal.
		for code: StringName in [Text.EN, Text.FR, Text.RU]:
			Text.set_language(code)
			_expect(not AnimalKinds.label(kind).begins_with("?"), "%s is named in %s" % [kind, code])
			_expect(not AnimalKinds.wish(kind).begins_with("?"), "and says what it wants in %s" % code)
		Text.set_language(Text.EN)
		# A voice, and a gap between one cry and the next.
		_expect(voices.voices().has(kind), "a %s has a voice" % kind)
		_expect(
			AnimalVoices.GAPS.has(kind),
			"and a gap between one cry and the next"
		)
		# Something to do with it: coins, or a thing it hands over.
		_expect(
			AnimalKinds.coins(kind) > 0 or AnimalKinds.gives(kind) != &"",
			"and something to give: %s" % (
				"%d coins" % AnimalKinds.coins(kind) if AnimalKinds.coins(kind) > 0
				else String(AnimalKinds.gives(kind))
			)
		)
		# How it moves.
		_expect(Animals.TURN_RATES.has(kind), "%s turns at its own rate" % kind)
		_expect(Animals.LEG_SWINGS.has(kind), "and swings its legs its own way")
		# And a number of them the valley is meant to hold.
		_expect(AnimalKinds.WANTED.has(kind), "and there is a wanted number of them")
	voices.queue_free()

## Asking where the trees are does not rebuild the forest.
##
## The pool of solid trunks asks for every tree within fourteen metres each
## time a child walks four, and that question generated nine whole tiles from
## scratch — forty-six candidates apiece, each asking the height field for its
## ground, its density and whether it stands in a pond. On a phone it came to
## 600 ms inside one frame and the game ran at one frame a second: the largest
## single cost in the game, spent working out an answer it had just worked out.
func _check_the_forest_is_asked_once() -> void:
	print("the forest is asked once")
	var field := HeightField.new(20260903)
	var forest := Vegetation.new(field, 20260903)
	get_root().add_child(forest)

	# In the middle of a wood, where there is most to generate.
	var at := Vector3(-200.0, 0.0, -200.0)
	var first := Time.get_ticks_usec()
	var trees := forest.trees_near(at, TreeCollision.REACH)
	var cold := Time.get_ticks_usec() - first

	var again := Time.get_ticks_usec()
	for _repeat in 20:
		forest.forget_tree_query()
		forest.trees_near(at, TreeCollision.REACH)
	var warm := float(Time.get_ticks_usec() - again) / 20.0

	_expect(trees.size() > 0, "%d trees stand within reach there" % trees.size())
	_expect(
		warm < float(cold) * 0.25,
		"asking again costs %.0f µs against %d the first time" % [warm, cold]
	)
	_expect(warm < 3000.0, "which is %.1f ms, not a frame" % (warm / 1000.0))

	# And the answer is the same answer: a cache that lies is worse than none.
	var remembered := forest.trees_near(at, TreeCollision.REACH)
	var identical := remembered.size() == trees.size()
	if identical:
		for i in trees.size():
			if trees[i].distance_to(remembered[i]) > 0.001:
				identical = false
	_expect(identical, "and it is the same forest both times")

	# Felling a tree throws it away, or the felled tree stands there for ever.
	var felled := Felled.new()
	felled.fell(trees[0])
	forest.felled = felled
	forest.rebuild_all()
	forest.forget_tree_query()
	var after := forest.trees_near(at, TreeCollision.REACH)
	_expect(
		after.size() < trees.size(),
		"a felled tree is gone from the answer (%d, was %d)" % [after.size(), trees.size()]
	)
	forest.queue_free()

## A child who falls through the ground is put back on it.
##
## The world builds its collision around wherever the player is, and the player
## is put down before any of it exists. Usually the ground arrives first; on a
## phone, twice in one evening, it did not — and a save was found at minus
## seventy thousand metres, with a child turning on the spot in the dark
## wondering where the game had gone. Nothing was broken, nothing was logged,
## and there was no way back.
func _check_nobody_falls_out_of_the_world() -> void:
	print("nobody falls out of the world")
	var field := HeightField.new(20260903)
	var spot := field.find_spawn_point()
	var ground := field.height_at(spot.x, spot.z)

	# The game holds the player still until the ground under them will hold
	# them up. "Exists" is not enough: a chunk is in the list from the moment
	# it is asked for, and its collision comes later from the worker that bakes
	# it — which is the gap they fell through.
	var terrain := Terrain.new(field)
	get_root().add_child(terrain)
	_expect(not terrain.has_ground_at(spot), "before anything is built, there is no ground to stand on")
	terrain.follow(spot)
	while not terrain.is_idle():
		terrain._process(1.0 / 60.0)
	_expect(terrain.has_ground_at(spot), "once the chunks are baked, there is")
	var chunk: TerrainChunk = terrain._chunks.get(TerrainSpec.chunk_at(spot))
	_expect(chunk != null and chunk.has_collision, "and the chunk under the player carries collision, not merely a mesh")
	terrain.queue_free()

	# The margin has to clear everything a child can legitimately be under.
	_expect(
		Player.CAUGHT_BELOW > Lakes.DEPTH,
		"the catch is %.1f m down, below the %.1f m of the deepest pond" % [
			Player.CAUGHT_BELOW, Lakes.DEPTH
		]
	)
	_expect(
		Player.CAUGHT_BELOW > PlaceSpec.POOL_DEPTH,
		"and below the swimming pool's %.1f m" % PlaceSpec.POOL_DEPTH
	)
	# Standing on the bottom of the pool is not falling out of the world.
	var pool := PlaceSpec.centre_of(&"pool", field.camp_centre())
	var pool_floor := field.height_at(pool.x, pool.z)
	_expect(
		pool_floor > field.height_at(pool.x, pool.z) - Player.CAUGHT_BELOW,
		"a child standing on the floor of the pool is not caught"
	)
	# But one below the ground by more than that is.
	_expect(
		ground - 20.0 < ground - Player.CAUGHT_BELOW,
		"and one twenty metres under the meadow is"
	)

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

	# And they are in price order, cheapest first: the shelf is a ladder a
	# child climbs, and a ladder with its rungs shuffled is a list.
	var ordered := true
	for i in range(1, ShopStock.ALL.size()):
		if ShopStock.price(ShopStock.ALL[i]) < ShopStock.price(ShopStock.ALL[i - 1]):
			ordered = false
			printerr("  %s at %d comes after %s at %d" % [
				ShopStock.ALL[i], ShopStock.price(ShopStock.ALL[i]),
				ShopStock.ALL[i - 1], ShopStock.price(ShopStock.ALL[i - 1])
			])
	_expect(ordered, "the shelf runs from %d coins to %d" % [
		ShopStock.price(ShopStock.ALL[0]),
		ShopStock.price(ShopStock.ALL[ShopStock.ALL.size() - 1])
	])

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

	# Buying a second one is allowed, and charged for. What a child pays for is
	# the thing, not the right to have one: a bicycle left at the far side of
	# the valley still counted as owned, so the shop refused to sell another
	# and a child standing at the counter could not ride home.
	wallet.earn(100)
	var before := wallet.coins
	_expect(
		wallet.buy(ShopStock.BOTTLE, ShopStock.price(ShopStock.BOTTLE)),
		"a second bottle can be bought"
	)
	_expect(
		wallet.coins == before - ShopStock.price(ShopStock.BOTTLE),
		"and is paid for like the first"
	)
	_expect(wallet.count_of(ShopStock.BOTTLE) == 2, "so there are two of them")
	_expect(wallet.give_up(ShopStock.BOTTLE), "one can be put down")
	_expect(wallet.count_of(ShopStock.BOTTLE) == 1, "leaving one")
	_expect(wallet.has(ShopStock.BOTTLE), "which is still a bottle owned")
	wallet.take(ShopStock.BOTTLE)
	_expect(wallet.count_of(ShopStock.BOTTLE) == 2, "and one picked up off the ground is free")

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
	inventory.add(ItemKinds.WOOD, 50)

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
		MountKinds.speed(MountKinds.BICYCLE) < MountKinds.speed(MountKinds.HORSE),
		"a bicycle is slower than a galloping horse (%.1f against %.1f m/s)" % [
			MountKinds.speed(MountKinds.BICYCLE), MountKinds.speed(MountKinds.HORSE)
		]
	)
	# A machine with wheels is steered rather than pointed: it turns by leaning
	# into a corner, so the turn takes ground, and standing still it does not
	# turn at all. Pushing the stick sideways used to spin it on the spot like
	# a shopping trolley.
	_expect(MountKinds.steers(MountKinds.MOTORCYCLE), "a motorcycle is steered")
	_expect(MountKinds.steers(MountKinds.BICYCLE), "so is a bicycle")
	_expect(not MountKinds.steers(MountKinds.HORSE), "a horse is not: it turns where it stands")
	_expect(not MountKinds.steers(&""), "and neither is a child on their own feet")

	# And half what a motorcycle does, which is what a bicycle is beside one: a
	# child pedalling is not a machine.
	_expect(
		absf(MountKinds.speed(MountKinds.BICYCLE) - MountKinds.speed(MountKinds.MOTORCYCLE) * 0.5) < 0.2,
		"and half the motorcycle's %.1f m/s" % MountKinds.speed(MountKinds.MOTORCYCLE)
	)
	# The motorcycle is the climber: an engine and a knobbly tyre beat a horse
	# up a bank, and a machine costing three hundred coins that stopped at the
	# first slope would be a strange reward.
	_expect(
		MountKinds.max_slope(MountKinds.MOTORCYCLE) > MountKinds.max_slope(MountKinds.HORSE) + Mounts.SADDLE_GRIP,
		"a motorcycle takes %.2f, steeper than a saddled horse's %.2f" % [
			MountKinds.max_slope(MountKinds.MOTORCYCLE),
			MountKinds.max_slope(MountKinds.HORSE) + Mounts.SADDLE_GRIP
		]
	)
	_expect(
		MountKinds.max_slope(MountKinds.MOTORCYCLE) < tan(Player.CLIMBS_TO),
		"and still less than a child manages on their own feet"
	)
	_expect(
		MountKinds.max_slope(MountKinds.HORSE) > MountKinds.max_slope(MountKinds.BICYCLE),
		"but the horse climbs what the bicycle cannot"
	)
	_expect(MountKinds.fords_water(MountKinds.HORSE), "the horse fords the river")

	# Anything with wheels is longer than it is wide, because its wheels turn
	# about the axle and the axle lies across it. Both machines were built with
	# their wheels turned a quarter turn — standing across the frame like
	# roundabouts — and the box they occupy is what says so: two metres wide and
	# half a metre long is not a bicycle.
	for wheeled: StringName in [MountKinds.BICYCLE, MountKinds.MOTORCYCLE]:
		var box := MountKinds.build_mesh(wheeled).get_aabb().size
		_expect(
			box.z > box.x * 2.0,
			"a %s is %.2f m long and %.2f m wide, so its wheels are on the right way round" % [
				wheeled, box.z, box.x
			]
		)
		_expect(box.y > 0.9 and box.y < 2.0, "and %.2f m tall, which is a machine a child gets on" % box.y)
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
	# On the ground — unless it was left in deep water, where it floats.
	var resting := (
		HeightField.WATER_LEVEL - MountKinds.HORSE_DRAUGHT
		if mounts.afloat(MountKinds.HORSE, left_at)
		else field.height_at(left_at.x, left_at.z)
	)
	_expect(
		is_equal_approx(left_at.y, resting),
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
	# There is a herd now, so a save written before there was one — where the
	# only horse is called "horse", with no number — must come back as the
	# first horse of the herd rather than as a nameless sixth animal that
	# nothing would ever look for again.
	var came_back := MountKinds.horse_id(0)
	_expect(restored.exists(came_back), "the horse survives a save")
	var recalled := restored.position_of(came_back)
	_expect(
		absf(recalled.x - left_at.x) < 0.01 and absf(recalled.z - left_at.z) < 0.01,
		"and is still where it was left"
	)
	var herd := Mounts.new(field)
	get_root().add_child(herd)
	herd.from_data({"horse:3": [12.0, 0.0, 34.0]})
	_expect(herd.exists(MountKinds.horse_id(3)), "and a save with the whole herd in it comes back as the herd")
	# A horse saved standing in a lake comes out of it. Worlds written before
	# the ponds had water levels of their own have horses in the middle of one,
	# and a solid animal out in the water is something a swimming child gets
	# trapped against — which is how it was found.
	var drowned := Vector3(
		Lakes.at(1, Lakes.POND_X), 0.0, Lakes.at(1, Lakes.POND_Z)
	)
	herd.from_data({"horse:4": [drowned.x, 0.0, drowned.z]})
	var rescued := herd.position_of(MountKinds.horse_id(4))
	_expect(
		not field.is_pond(rescued.x, rescued.z),
		"a horse saved in the lake is put ashore, %.0f m away" % rescued.distance_to(drowned)
	)
	_expect(
		rescued.y > field.water_level_at(rescued.x, rescued.z),
		"on ground above the water rather than under it"
	)
	# The bank of a lake stands half a metre above its water, which is less
	# than the metre of clearance that makes ground worth turning a horse out
	# on — so a rescue that asked for good grazing refused every bank round the
	# pond and left the horse where it was.
	_expect(
		rescued.y - Lakes.at(1, Lakes.POND_LEVEL) < 1.2,
		"which is the pond's own bank, %.2f m above its water, and not a hill a mile away" % (
			rescued.y - Lakes.at(1, Lakes.POND_LEVEL)
		)
	)
	herd.queue_free()

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
	var lamps_wanted := (
		Places.LAMPS.size() + Places.CAFE_LAMPS.size() + Places.POOL_LAMPS.size()
		+ Places.SHOP_LAMPS.size() + 4
	)
	_expect(places.lamp_count() == lamps_wanted, "%d lamps: round the pad, at the café, at the pool, at the shop, and the pitch's four floodlights" % places.lamp_count())
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
			var at: Vector3 = Paths.end_of(end, camp)
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
	# And a route has to be walkable. A path painted up a cliff is worse than no
	# path at all: it tells a child to go somewhere they cannot go, which is
	# what the first path from the lake to the shop did — the shop stands on a
	# plateau above a cliff, and every straight line to it from anywhere on the
	# lake's shore climbed ground at a gradient of one.
	var steepest := 0.0
	var steepest_route := ""
	var legs: Array[Array] = []
	for route in Paths.ROUTES:
		legs.append([
			Paths.end_of(route["from"], camp), Paths.end_of(route["to"], camp),
			"%s to %s" % [
				"camp" if route["from"] == &"" else route["from"],
				"camp" if route["to"] == &"" else route["to"],
			]
		])
	for corner in Paths.LAKE_WALK.size() - 1:
		legs.append([
			Paths.LAKE_WALK[corner], Paths.LAKE_WALK[corner + 1],
			"the lake walk, leg %d" % (corner + 1)
		])
	for leg in legs:
		for step in 80:
			var at: Vector3 = (leg[0] as Vector3).lerp(leg[1] as Vector3, float(step) / 79.0)
			var here := field.steepness_at(at.x, at.z)
			if here > steepest:
				steepest = here
				steepest_route = String(leg[2])
	# Three quarters, not a half: the walk from the playground to the pool
	# crosses a shoulder at 0.63 and has always been fine. What is being caught
	# is ground at a gradient of one and more, which the player's own controller
	# will not climb — it slides off anything past 52 degrees, and long before
	# that a child simply gives up.
	_expect(
		steepest < 0.75,
		"every route is walkable: the steepest ground on any of them is %.2f, on the one from %s" % [
			steepest, steepest_route
		]
	)

	# No animal stands in a lake. A cat walked into the eastern pond and stayed
	# there up to its neck: they wade rivers, which are shallow and have two
	# banks, and nothing told them a pond is different.
	var herd_field := field
	var beasts := Animals.new(herd_field, 20260903)
	get_root().add_child(beasts)
	var in_the_lake := Vector3(
		Lakes.at(1, Lakes.POND_X), 0.0, Lakes.at(1, Lakes.POND_Z)
	)
	in_the_lake.y = herd_field.height_at(in_the_lake.x, in_the_lake.z)
	var stranded := beasts.put_one_at(AnimalKinds.CAT, in_the_lake)
	_expect(not stranded.is_empty(), "a cat can be stood in the middle of the lake for the test")
	for _frame in 600:
		beasts._process(1.0 / 60.0)
	var walked_to: Vector3 = (stranded["node"] as Node3D).position
	_expect(
		not herd_field.is_pond(walked_to.x, walked_to.z),
		"and it walks out of the water rather than standing in it"
	)
	beasts.queue_free()

	# Nothing is built in a lake. The test for wet ground compared against the
	# world's waterline, and a raised pond's bed is well above it — so a ladder
	# could be stood in the middle of one.
	var builder := BuildMode.new(field, Structures.new(field), Inventory.new())
	get_root().add_child(builder)
	var open_water := Vector3(
		Lakes.at(1, Lakes.POND_X), 0.0, Lakes.at(1, Lakes.POND_Z)
	)
	open_water.y = field.height_at(open_water.x, open_water.z)
	_expect(
		not builder.would_build_at(open_water),
		"nothing is built in the middle of a lake"
	)
	var bank := open_water + Vector3(Lakes.at(1, Lakes.POND_LONG) + 12.0, 0.0, 0.0)
	bank.y = field.height_at(bank.x, bank.z)
	_expect(builder.would_build_at(bank), "but the bank beside it is ordinary ground")
	builder.queue_free()

	# The lake walk has to start at the lake and end at the shop's door, however
	# it wanders in between.
	var walk_start: Vector3 = Paths.LAKE_WALK[0]
	var walk_end: Vector3 = Paths.LAKE_WALK[Paths.LAKE_WALK.size() - 1]
	_expect(
		walk_start.distance_to(Paths.end_of(&"lake", camp)) < 2.0,
		"the lake walk begins on the lake's own shore"
	)
	_expect(
		walk_end.distance_to(Paths.end_of(&"shop", camp)) < 2.0,
		"and ends at the shop's door"
	)
	# And it is a walk, not a line: a straight one between those two points is
	# a cliff, which is the whole reason it winds.
	var straight := walk_start.distance_to(walk_end)
	var wandered := 0.0
	for corner in Paths.LAKE_WALK.size() - 1:
		wandered += Paths.LAKE_WALK[corner].distance_to(Paths.LAKE_WALK[corner + 1])
	_expect(
		wandered > straight * 1.5,
		"it winds %.0f m to cover %.0f m as the crow flies" % [wandered, straight]
	)
	var crow := 0.0
	for step in 40:
		var at := walk_start.lerp(walk_end, float(step) / 39.0)
		crow = maxf(crow, field.steepness_at(at.x, at.z))
	_expect(crow > 0.75, "because the straight line climbs ground at %.2f, which nobody gets up" % crow)

	# A route may be interrupted by water — that is a ford, and it is on purpose
	# — but it must be worn everywhere it is on land, or it is two patches
	# rather than a path.
	var worn := 0
	var dry_samples := 0
	for route in Paths.ROUTES:
		# Each route runs to where it actually arrives, which for the pool is
		# its gate rather than the bottom of the water.
		var a: Vector3 = Paths.end_of(route["from"], camp)
		var b: Vector3 = Paths.end_of(route["to"], camp)
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
	# Sampled on rings round the camp. A route crossing a ring will sometimes
	# land on one of these points — the sports ground's road to the playground
	# does — and that is a road doing its job, not the valley being paved. What
	# is being guarded against is paint everywhere, so the test is how many of
	# the two dozen samples are on a path rather than whether any of them is.
	var on_a_path := 0
	var samples := 0
	for distance: float in [80.0, 160.0, 320.0]:
		for step in 8:
			var angle := TAU * float(step) / 8.0
			var at := camp + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
			samples += 1
			if field.path_at(at.x, at.z, field.height_at(at.x, at.z)) > 0.0:
				on_a_path += 1
	_expect(
		on_a_path <= samples / 8,
		"the open valley is open: %d of %d points round the camp are on a path" % [
			on_a_path, samples
		]
	)

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
	# Sampled where the ground is actually carved, not only out in open
	# country. Three corners of empty valley agreed perfectly while every pond
	# in the world was a different shape in the two paths: the grid still dug
	# each one down to sea level and gave it no shore, so the lake a child saw
	# was the old crater with its water hanging two or three metres above the
	# bank. Every place that shapes the ground gets a corner here now.
	var worst := 0.0
	var corners: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(-320.0, 224.0), Vector2(896.0, 0.0)]
	for pond in Lakes.count():
		var middle := Vector2(Lakes.at(pond, Lakes.POND_X), Lakes.at(pond, Lakes.POND_Z))
		# The middle of the water, and its shore on two sides.
		corners.append(middle - Vector2(16.0, 16.0))
		corners.append(middle + Vector2(Lakes.at(pond, Lakes.POND_LONG) - 8.0, 0.0))
		corners.append(middle - Vector2(Lakes.at(pond, Lakes.POND_LONG) + 24.0, 0.0))
	for place in PlaceSpec.OFFSETS:
		var centre := PlaceSpec.centre_of(place, field.camp_centre())
		corners.append(Vector2(centre.x - 16.0, centre.z - 16.0))
	for corner: Vector2 in corners:
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
	while places.swinging() and swung < 300.0:
		places._process(1.0 / 60.0)
		swung += 1.0 / 60.0
	_expect(not places.swinging(), "the swing stops on its own after %.0f s" % swung)
	_expect(swung > 20.0, "and one push is worth a proper ride, not a couple of passes")
	_expect(swung < 120.0, "but it does not go on for ever")

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
		"TICKET", "SHOP", "SNACK", "LANTERN", "RIDE_BICYCLE", "RIDE_MOTORCYCLE",
	]:
		if not icon_source.contains("Kind.%s:" % face):
			drawn = false
			printerr("  action_icon.gd draws nothing for %s" % face)
	_expect(drawn, "every action icon has something to draw")

## Voice is the only part of this game whose failures reach outside it, and the
## children are small. These checks read the source, because the rules have to
## be structural: a rule held by a comment is a rule that gets edited away.
## A parent can switch talking off, and the switch is obeyed by the microphone
## rather than by the interface.
##
## Hiding the button would be a promise about the screen; this is a promise
## about the capture stream, which is the one that matters. It is also the
## answer to the parental-controls question every children's store asks.
func _check_talking_can_be_switched_off() -> void:
	print("talking can be switched off")
	var voice := Voice.new()
	get_root().add_child(voice)
	_expect(voice.allowed, "talking is allowed to begin with")
	voice.allowed = false
	voice.start_talking()
	_expect(not voice.is_talking(), "and switching it off stops the microphone starting")
	voice.queue_free()

	var hud := Hud.new()
	get_root().add_child(hud)
	hud.set_voice_allowed(false)
	hud.set_voice(true, false)
	_expect(
		not hud._talk_button.visible,
		"the talk button is gone while it is switched off"
	)
	hud.set_voice_allowed(true)
	hud.set_voice(true, false)
	_expect(hud._talk_button.visible, "and comes back when it is switched on")
	_expect(hud.voice_allowed(), "the switch remembers where it is")
	hud.queue_free()

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

## The bag folds open over what is under it rather than pushing it off the
## screen. A child opened it and the purse, the gauges and half the buttons
## walked down past the bottom edge.
func _check_the_open_bag_moves_nothing() -> void:
	print("the open bag moves nothing")
	var hud := Hud.new()
	get_root().add_child(hud)
	await process_frame

	hud.set_item_count(ItemKinds.STICK, 3)
	hud.set_item_count(ItemKinds.STONE, 2)
	hud.set_item_count(ItemKinds.REED, 1)
	hud._layout()
	await process_frame
	var purse_shut := hud._purse.position
	var vitals_shut := hud._vitals.position
	var bag := hud._backpack

	_expect(not bag.is_open(), "the bag starts folded")
	bag.toggle()
	await process_frame
	hud._layout()
	await process_frame

	_expect(bag.is_open(), "and opens when its title is tapped")
	_expect(bag.size.y > bag.shut_height() + 1.0, "and is taller open than shut")
	_expect(
		hud._purse.position.is_equal_approx(purse_shut),
		"but the purse has not moved: %s against %s" % [hud._purse.position, purse_shut]
	)
	_expect(hud._vitals.position.is_equal_approx(vitals_shut), "and neither have the gauges")
	_expect(bag.z_index > hud._purse.z_index, "the list is drawn over them")
	_expect(bag.modulate.a < 1.0, "and thinly enough to read them through it")
	hud.queue_free()

## Every looping voice joins its own end to its own beginning.
##
## These are filtered noise, and a filter has a memory: without folding the end
## back over the start, the last sample knows nothing about the first and the
## join is a step — a tick, every few seconds, for ever. The step is compared
## against how big a step that waveform takes from one sample to the next
## normally, because a hiss takes big steps and a rumble takes small ones and
## there is no single number that suits both.
func _check_the_valley_loops_without_a_tick() -> void:
	print("the valley loops without a tick")
	var ambience := Ambience.new()
	for voice: String in ["water", "leaves"]:
		var stream := ambience._stream_of(voice)
		var data := stream.data
		var count := data.size() / 2
		var seam := absf(float(data.decode_s16(0) - data.decode_s16((count - 1) * 2)))
		var usual := 0.0
		for i in range(1, mini(count, 8000)):
			usual += absf(float(data.decode_s16(i * 2) - data.decode_s16((i - 1) * 2)))
		usual /= 7999.0
		_expect(
			seam < usual * 14.0,
			"the %s joins with a step of %.0f against its usual %.0f" % [voice, seam, usual]
		)
		# And long enough that the repeat is not counted. Four seconds of river
		# with two dozen audible gurgles in it is heard as a loop in half a
		# minute.
		_expect(
			float(count) / float(Ambience.RATE) > 5.0,
			"and runs for %.1f s before it repeats" % (float(count) / float(Ambience.RATE))
		)
	ambience.queue_free()

## A machine ridden nose-first into a wood can be backed out of it again.
##
## It could not. Two things were wrong and they compounded: steering had no
## bite below a walking pace, so a machine stopped dead against a trunk could
## not be pointed anywhere else; and reverse was capped by squashing the stick
## push, which is applied twice — once through the gait and once again to the
## target speed — so a third of a push came out as a tenth of the speed.
func _check_a_machine_backs_out_of_a_corner() -> void:
	print("a machine backs out of a corner")
	_expect(Player.PADDLE_BITE > 0.0, "a standing machine can still be turned while the throttle is held")
	_expect(
		Player.PADDLE_BITE < 1.0,
		"but not as freely as one under way, or it spins on the spot"
	)
	var top := MountKinds.speed(MountKinds.MOTORCYCLE)
	var reverse := top * Player.REVERSE_SHARE
	_expect(reverse > Player.WALK_SPEED, "reverse is %.1f m/s, faster than walking away from it" % reverse)
	_expect(reverse < top * 0.5, "and well under half what it does forwards")

## The bridge: the one place a machine on wheels crosses the river.
##
## A bicycle cannot ford water, which is right, and that left everything east
## of the river closed to anything bought in the shop. The deck has to land on
## the ground at both ends, clear the water in the middle, and be ridable where
## the bank beside it is not.
func _check_the_bridge_carries_what_cannot_swim() -> void:
	print("the bridge carries what cannot swim")
	var field := HeightField.new(20260903)
	var river_x := field.river_centre_x(BridgeSpec.CENTRE_Z)

	# In sight of where a child starts. It used to cross fifty metres away,
	# between the pitch and the pool, and a crossing you cannot see from your
	# own door is one you do not know exists.
	var camp := field.camp_centre()
	_expect(
		absf(BridgeSpec.CENTRE_Z - camp.z) < 12.0,
		"it crosses at the camp's own latitude: z=%.0f against the camp at z=%.0f" % [
			BridgeSpec.CENTRE_Z, camp.z
		]
	)
	_expect(
		Vector2(river_x, BridgeSpec.CENTRE_Z).distance_to(Vector2(camp.x, camp.z)) < 60.0,
		"and is %.0f m from the camp, which is a walk a child takes without deciding to" % (
			Vector2(river_x, BridgeSpec.CENTRE_Z).distance_to(Vector2(camp.x, camp.z))
		)
	)

	# Both ends meet the ground they land on, with no step to trip over.
	for side: float in [-1.0, 1.0]:
		var at_x := river_x + side * BridgeSpec.HALF_SPAN
		var deck := field.bridge_deck_at(at_x, BridgeSpec.CENTRE_Z)
		_expect(
			absf(deck - field.height_at(at_x, BridgeSpec.CENTRE_Z)) < 0.05,
			"the deck meets the bank at x=%.0f rather than ending above it" % at_x
		)

	# And clears the water in between, or it is a causeway.
	var middle := Vector3(river_x, 0.0, BridgeSpec.CENTRE_Z)
	middle.y = field.bridge_deck_at(middle.x, middle.z)
	_expect(
		middle.y > field.water_level_at(middle.x, middle.z) + 1.0,
		"and stands %.1f m over the water at the middle" % (middle.y - field.water_level_at(middle.x, middle.z))
	)

	# Gentle enough to ride up. The arch is a half sine, so the steepest part
	# of it is at the ends, where a rider joins.
	var steepest := 0.0
	var step := 1.0
	var x := river_x - BridgeSpec.HALF_SPAN
	while x < river_x + BridgeSpec.HALF_SPAN - step:
		var rise := field.bridge_deck_at(x + step, BridgeSpec.CENTRE_Z) - field.bridge_deck_at(x, BridgeSpec.CENTRE_Z)
		steepest = maxf(steepest, absf(rise) / step)
		x += step
	_expect(
		steepest < MountKinds.max_slope(MountKinds.BICYCLE),
		"the deck rises at %.2f, which a bicycle takes" % steepest
	)

	var mounts := Mounts.new(field)
	get_root().add_child(mounts)
	_expect(
		mounts.can_ride_over(MountKinds.BICYCLE, middle),
		"a bicycle can be ridden across the bridge"
	)
	_expect(
		mounts.can_ride_over(MountKinds.MOTORCYCLE, middle),
		"and so can a motorcycle"
	)
	# The water beside it is still water. Off the end of the deck, at the
	# river's own level, nothing on wheels may go.
	var river := Vector3(river_x, field.water_level_at(river_x, BridgeSpec.CENTRE_Z + 60.0), BridgeSpec.CENTRE_Z + 60.0)
	_expect(
		not mounts.can_ride_over(MountKinds.BICYCLE, river),
		"but not through the river a little way downstream"
	)
	_expect(
		not mounts.can_ride_over(MountKinds.MOTORCYCLE, river),
		"and neither may the motorcycle"
	)
	# Swimming under the arch is not riding over it.
	var under := Vector3(middle.x, field.water_level_at(middle.x, middle.z), middle.z)
	_expect(
		not mounts.can_ride_over(MountKinds.BICYCLE, under),
		"and being in the water under the deck is not being on it"
	)
	_expect(
		field.forest_density_at(river_x, BridgeSpec.CENTRE_Z) == 0.0,
		"nothing grows up through the planks"
	)
	mounts.queue_free()

## The lantern is carried on the body, and looks like a lantern.
##
## It was a glowing ball parented to the character rather than to the body, so
## it never turned, never leaned and — the way it was found — never went down
## with a swimmer: the child sank to their chin and the light stayed at
## standing height beside their ear, which reads as a face coming off.
func _check_the_lantern_is_carried() -> void:
	print("the lantern is carried")
	var player := Player.new()
	get_root().add_child(player)
	var before := player.get_child_count()
	var lantern := Lantern.new()
	player.hold(lantern)
	_expect(player.is_held(lantern), "it hangs on the body rather than on the character")
	_expect(
		player.get_child_count() == before,
		"and asking for it built no second body to hang it on"
	)

	# Below the shoulder and out to one side: in a hand, not in front of a face.
	var head := Player.HEIGHT * 0.79
	_expect(
		Lantern.HELD_AT.y < head - 0.25,
		"it is carried at %.2f m, well under the head at %.2f m" % [Lantern.HELD_AT.y, head]
	)
	_expect(absf(Lantern.HELD_AT.x) > Player.RADIUS * 0.7, "and out at arm's length, clear of the chest")

	# And it is built like one: a lit part, and metal above and below it.
	lantern.owned = true
	lantern.follow(1.0, 10.0)
	_expect(lantern.is_lit(), "it lights when the night is dark")
	var box: AABB = _lamp_extent(lantern)
	_expect(box.size.y > box.size.x * 1.3, "the lamp stands taller than it is wide, as a lantern does")
	_expect(box.size.y > 0.2 and box.size.y < 0.5, "and is %.2f m tall, a thing a child carries" % box.size.y)
	_expect(lantern._lamp.get_child_count() >= 6, "and is built of parts rather than being one glowing ball")
	player.queue_free()

## How much room the lamp's parts take up together.
func _lamp_extent(lantern: Lantern) -> AABB:
	var box := AABB()
	var first := true
	for part in lantern._lamp.get_children():
		var mesh := part as MeshInstance3D
		if mesh == null:
			continue
		var here := mesh.get_aabb()
		here.position += mesh.position
		if first:
			box = here
			first = false
		else:
			box = box.merge(here)
	return box

## Nothing on the bridge stands above the deck.
##
## The planks each carried their own collider, tilted to their own piece of the
## arch and made a little long so the joins would not gape — and two tilted
## boxes that overlap cannot be flush: the upper corner of each stands proud of
## its neighbour. What that makes is not a ramp but twenty-eight low steps, and
## a child had to jump up every one of them the whole way over.
##
## So: the deck a foot meets is one swept surface, no part of it is above the
## line `bridge_deck_at` reports, and nothing else bolted to the bridge —
## handrail, post, trestle — reaches down into that line either.
func _check_the_bridge_is_walked_not_climbed() -> void:
	print("the bridge is walked, not climbed")
	var field := HeightField.new(20260903)
	var bridge := Bridge.new(field)
	get_root().add_child(bridge)
	var body := bridge.get_node("Solid") as StaticBody3D
	_expect(body != null, "the bridge is solid")

	# The walking corridor: the part of the deck a child or a machine actually
	# travels along, inside the handrails.
	var surfaces := 0
	var boxes := 0
	var highest_in_the_way := -INF
	var lowest_rail := INF
	for child in body.get_children():
		var collider := child as CollisionShape3D
		if collider == null:
			continue
		if collider.shape is BoxShape3D:
			boxes += 1
			continue
		var sweep := collider.shape as ConcavePolygonShape3D
		if sweep == null:
			continue
		surfaces += 1
		# Which surface this is, judged by where it lies across the crossing
		# rather than by which vertex is being looked at: the deck runs under
		# the middle, a handrail runs entirely off to one side. Judging it
		# vertex by vertex called the deck's own outer edge a handrail.
		var nearest := INF
		var furthest := -INF
		for point in sweep.get_faces():
			var z := (collider.transform * point).z
			nearest = minf(nearest, z)
			furthest = maxf(furthest, z)
		# The deck is the surface that spans the middle of the crossing; a
		# handrail lies wholly to one side of it. Its own strip of planks has
		# no vertex in the middle at all — they are all out at the edges — so
		# asking whether any single point is near the centre line called the
		# deck a handrail and failed on its own underside.
		var walked := nearest <= BridgeSpec.CENTRE_Z and furthest >= BridgeSpec.CENTRE_Z
		for point in sweep.get_faces():
			var at := collider.transform * point
			var line := _deck_line(field, at.x)
			if walked:
				# The deck: no part of it may stand above the walking line.
				highest_in_the_way = maxf(highest_in_the_way, at.y - line)
			else:
				# A handrail: no part of it may reach down through the planks.
				lowest_rail = minf(lowest_rail, at.y - line)

	_expect(surfaces == 3, "the deck and its two rails are three swept surfaces, not a row of boxes")
	_expect(boxes == 0, "and nothing on the bridge is a tilted box, which cannot be laid flush")
	_expect(
		highest_in_the_way < 0.001,
		"nothing stands above the walking line: highest is %.3f m" % highest_in_the_way
	)
	_expect(
		lowest_rail > -0.001,
		"and the handrails sit on the planks rather than through them: %.3f m" % lowest_rail
	)

	# The tilt itself. Every piece of the bridge — plank, beam, rail — is a box
	# turned to its own bit of the arch, and the turn was made about
	# Vector3.FORWARD, which is the *negative* Z axis: each piece leaned
	# against the slope instead of along it. The deck came out a sawtooth that
	# had to be jumped up board by board, and the handrail came apart into
	# separate sticks.
	_expect(
		(Bridge._slope(1.0, 1.0) * Vector3.RIGHT).y > 0.0,
		"a rising piece of the arch actually rises"
	)

	# And the drawn bridge agrees: nothing a child sees underfoot stands above
	# the line their feet are held at. This reads the committed mesh, because
	# the sawtooth was in what was drawn rather than in what was computed.
	var planking := BridgeSpec.HALF_WIDTH - BridgeSpec.RAIL_INSET - 0.3
	var proud := -INF
	var triangles := 0
	for child in bridge.get_children():
		var drawn := child as MeshInstance3D
		if drawn == null:
			continue
		var faces := drawn.mesh.get_faces()
		for point in faces:
			if absf(point.z - BridgeSpec.CENTRE_Z) > planking:
				continue
			var line := _deck_line(field, point.x)
			# Only the deck itself: the beams and trestles under it are
			# supposed to be below the line, and are.
			if point.y < line - 0.5:
				continue
			proud = maxf(proud, point.y - line)
		triangles += faces.size() / 3
	# There is something drawn at all. The rewrite that made the deck one
	# swept surface also lost the few lines that committed the timber into a
	# mesh and put it in the scene, and every check here still passed: they
	# all walked a list of drawn pieces that was empty. A bridge you can cross
	# and cannot see is worse than no bridge.
	_expect(triangles > 200, "the bridge is drawn: %d triangles of timber" % triangles)

	# The bridge wears its name, on the parapet at the near end, in the same
	# enamel the square's plaque is made of.
	var named := 0
	var lowest_writing := INF
	for child in bridge.get_children():
		var label := child as Label3D
		if label == null:
			continue
		named += 1
		lowest_writing = minf(lowest_writing, label.position.y - _deck_line(field, label.position.x))
		_expect(
			absf(label.position.z - BridgeSpec.CENTRE_Z) > BridgeSpec.HALF_WIDTH - BridgeSpec.RAIL_INSET - 0.2,
			"the name is on the parapet rather than across the roadway"
		)
	_expect(named >= 4, "the name is written on both faces of the plaque: %d lines" % named)
	_expect(
		lowest_writing > 0.0,
		"and stands above the planks, not through them: lowest is %.2f m" % lowest_writing
	)
	_expect(
		Bridge.NAME_WIDTH < BridgeSpec.HALF_SPAN,
		"the plaque is a plaque and not a hoarding"
	)
	_expect(
		proud < 0.02,
		"no board is drawn standing above the deck: worst is %.3f m" % proud
	)

	# Walked end to end, there is no step anywhere — over the arch, and across
	# the seam where the planks meet the bank at either end.
	var river_x := field.river_centre_x(BridgeSpec.CENTRE_Z)
	var step := 0.25
	var biggest := 0.0
	var at_x := river_x - BridgeSpec.HALF_SPAN - 2.0
	while at_x < river_x + BridgeSpec.HALF_SPAN + 2.0:
		var rise := absf(_deck_line(field, at_x + step) - _deck_line(field, at_x))
		biggest = maxf(biggest, rise)
		at_x += step
	# What the arch itself asks of a stride, doubled to leave room for the
	# bank at either end. A character body here has no step-up at all — it
	# climbs slopes and nothing else — so anything much beyond the arch's own
	# rise is a thing that has to be jumped.
	var allowed := BridgeSpec.LIFT * PI / (BridgeSpec.HALF_SPAN * 2.0) * step * 2.0
	_expect(
		biggest < allowed,
		"the biggest step in a quarter-metre stride is %.3f m against %.3f m allowed" % [biggest, allowed]
	)
	bridge.queue_free()

## The height of the walking surface at a point on the crossing: the deck where
## there is a deck, and the ground where the deck has run out.
func _deck_line(field: HeightField, x: float) -> float:
	var deck := field.bridge_deck_at(x, BridgeSpec.CENTRE_Z)
	if is_nan(deck):
		return field.height_at(x, BridgeSpec.CENTRE_Z)
	return deck

## The bridge is marked on the map.
##
## It is the only way over the river on anything with wheels, and the river
## looks the same for a kilometre in either direction: a child who has just
## bought a bicycle cannot be expected to find it by walking the bank.
func _check_the_bridge_is_on_the_map() -> void:
	print("the bridge is on the map")
	var field := HeightField.new(20260903)
	var minimap := Minimap.new(field)
	get_root().add_child(minimap)

	var marked := Vector3.ZERO
	var found := false
	for destination in minimap._destinations:
		if (destination["glyph"] as PlaceGlyph).kind == PlaceGlyph.Kind.BRIDGE:
			marked = destination["at"]
			found = true
	_expect(found, "there is a mark for the crossing")
	if found:
		_expect(
			field.is_on_the_bridge(
				Vector3(marked.x, field.bridge_deck_at(marked.x, marked.z), marked.z)
			),
			"and it is where the bridge actually is"
		)
	# Every kind of place has a picture; a glyph with no picture is a blank
	# disc, which is a colour to remember rather than a thing to recognise.
	for kind: int in PlaceGlyph.Kind.values():
		_expect(
			PlaceGlyph.COLOURS.has(kind),
			"every place on the map has a colour: %d" % kind
		)
	minimap.queue_free()

## The junction at the camp has its name on it, and every plate points along
## the road it names.
##
## The four roads out of the camp were anonymous worn earth, and a child had to
## walk one to learn where it went. A sign is only worth having if it is right,
## so the thing checked here is that each plate is turned to the road it names
## rather than to a bearing written down beside it.
func _check_the_roads_have_names() -> void:
	print("the roads have names")
	var field := HeightField.new(20260903)
	var post := Signpost.new(field)
	get_root().add_child(post)

	var camp := field.camp_centre()
	var foot := post.where()
	_expect(
		Vector2(foot.x, foot.z).distance_to(Vector2(camp.x, camp.z)) < 12.0,
		"the post stands at the camp, where the roads fork"
	)
	_expect(
		absf(foot.y - field.height_at(foot.x, foot.z)) < 0.01,
		"and its foot is on the ground rather than in it or over it"
	)

	# Every road out of the camp has a plate, and no plate names a road that
	# is not there.
	var named: Array[StringName] = []
	for road in Signpost.ROADS:
		named.append(road["toward"])
	for wanted: StringName in [&"playground", &"cafe", &"pool", &"bridge"]:
		_expect(named.has(wanted), "there is a plate for the %s road" % wanted)
	_expect(Signpost.ROADS.size() == 4, "four roads, four plates")
	_expect(
		Signpost.PLACE_NAME.strip_edges() != "",
		"and the square itself is named: %s" % Signpost.PLACE_NAME
	)

	# Each plate points where its road actually goes. Compared against the
	# destination rather than against a stored angle, so moving a place turns
	# its sign.
	for road in Signpost.ROADS:
		var toward: StringName = road["toward"]
		var there := post.destination(toward)
		var wanted := atan2(-(there.z - foot.z), there.x - foot.x)
		var off := absf(angle_difference(post.bearing_to(toward), wanted))
		_expect(
			off < deg_to_rad(1.0),
			"%s points at what it names, to within %.2f degrees" % [road["name"], rad_to_deg(off)]
		)

	# No two plates occupy the same height, or two roads crossing at a narrow
	# angle would draw through one another.
	var heights: Array[float] = []
	for road in Signpost.ROADS.size():
		var at := post._plate_height(road)
		for other in heights:
			_expect(
				absf(at - other) > Signpost.PLATE_HEIGHT,
				"the plates are stacked clear of one another"
			)
		heights.append(at)
	_expect(
		heights.min() > 2.0,
		"and the lowest plate is %.2f m up, over the head of a child walking under it" % heights.min()
	)
	_expect(
		heights.max() < Signpost.POLE_HEIGHT - 0.5,
		"while the highest is below the plaque on top"
	)

	# The square's own name is one plaque with a front and a back, turned to
	# face the way a child arrives. It used to be two plates crossed at right
	# angles so the name faced all four roads, which is not a thing anybody
	# builds: a street plaque goes on a wall, and four of them back to back
	# read as a lantern with writing on it.
	var camp_bearing := atan2(
		-(field.camp_centre().z - foot.z), field.camp_centre().x - foot.x
	)
	_expect(
		absf(angle_difference(post.plaque_facing(), camp_bearing)) < deg_to_rad(1.0),
		"the plaque faces the camp, which is the way a child comes home"
	)

	# The plaque stands clear above the topmost plate. It did not: the plates
	# were measured down from the top of the post and the plaque was too, so
	# the highest street sign came out through the middle of the square's own
	# name.
	var plaque_bottom := post._plaque_centre() - Signpost.PLAQUE_BODY * 0.5
	var highest_plate := post._plate_height(0) + Signpost.PLATE_HEIGHT * 0.5
	_expect(
		plaque_bottom > highest_plate + 0.2,
		"the plaque hangs %.2f m clear of the highest plate" % (plaque_bottom - highest_plate)
	)
	# And the post does not go through it. It did: the plaque was centred on
	# the pole's own axis at a height the pole still reached, so the grey post
	# came up through the middle of the enamel and cut the name in half.
	_expect(
		plaque_bottom >= Signpost.POLE_HEIGHT,
		"the post stops at %.2f m, under the plaque's foot at %.2f m" % [
			Signpost.POLE_HEIGHT, plaque_bottom
		]
	)

	# Nobody is left standing inside it. The post went up exactly where a child
	# was standing, and they loaded back in within its collision and could not
	# walk out — a solid thing that appears around somebody traps them.
	var inside := Vector3(foot.x, foot.y, foot.z)
	var freed := post.push_clear(inside)
	_expect(
		Vector2(freed.x, freed.z).distance_to(Vector2(foot.x, foot.z)) >= Signpost.KEEP_CLEAR,
		"somebody standing in the post is stepped out of it"
	)
	_expect(
		absf(freed.y - field.height_at(freed.x, freed.z)) < 0.5,
		"and put down on the ground where they land"
	)
	var beside := Vector3(foot.x + 6.0, foot.y, foot.z)
	_expect(
		post.push_clear(beside).is_equal_approx(beside),
		"while somebody standing clear of it is left where they are"
	)
	_expect(
		Signpost.KEEP_CLEAR > Player.RADIUS,
		"the clear ground round the post is wider than a child"
	)

	# And no rock sits in the road or at the foot of the post. One did, right
	# against the signs, which is what a child on a bicycle hits while reading
	# them — and a boulder in the middle of a worn path is one that would have
	# been rolled aside years ago.
	var rocks := Boulders.new(field, 20260903)
	get_root().add_child(rocks)
	_expect(
		not rocks._suits(foot.x + 1.5, foot.z + 1.0),
		"no rock stands against the signpost"
	)
	var on_the_road := false
	var i := 0
	while i < Paths.SEGMENTS.size():
		for step in 9:
			var along := float(step + 1) / 10.0
			var x := lerpf(Paths.SEGMENTS[i], Paths.SEGMENTS[i + 2], along)
			var z := lerpf(Paths.SEGMENTS[i + 1], Paths.SEGMENTS[i + 3], along)
			if rocks._suits(x, z):
				on_the_road = true
		i += 4
	_expect(not on_the_road, "and none in the middle of a road")
	rocks.queue_free()

	# It is drawn, and it is readable: a post with no mesh and no writing is
	# the bug the bridge already taught us to check for.
	var drawn := 0
	var writing := 0
	for child in post.get_children():
		if child is MeshInstance3D:
			drawn += (child as MeshInstance3D).mesh.get_faces().size() / 3
		elif child is Label3D:
			writing += 1
	_expect(drawn > 200, "the post is drawn: %d triangles" % drawn)
	# Both faces of four plates, and both faces of the two plaques.
	_expect(writing >= Signpost.ROADS.size() * 2 + 2, "and carries %d pieces of writing" % writing)
	post.queue_free()

## The fairground: its ground, its fence and its five rides.
##
## Everything here is a thing that would be wrong on the phone and cannot be
## seen from a desk: a ride standing outside its own fence, a wheel that is
## thirty metres to its axle rather than to its top, a park levelled into the
## river, grass growing up through the sand.
func _check_the_fairground() -> void:
	print("the fairground")
	var field := HeightField.new(20260903)

	# The ground under it is flat, at the height the rides are built to.
	var roughest := 0.0
	var steepest := 0.0
	var x := ParkSpec.WEST
	while x <= ParkSpec.EAST:
		var z := ParkSpec.NORTH
		while z <= ParkSpec.SOUTH:
			roughest = maxf(roughest, absf(field.height_at(x, z) - ParkSpec.LEVEL))
			steepest = maxf(steepest, field.steepness_at(x, z))
			z += 6.0
		x += 4.0
	_expect(roughest < 0.05, "the fairground is level to %.3f m" % roughest)
	_expect(steepest < 0.05, "and flat underfoot: steepest %.3f" % steepest)

	# It is dry ground, clear of the river it stands beside.
	var nearest_water := INF
	var zz := ParkSpec.NORTH
	while zz <= ParkSpec.SOUTH:
		nearest_water = minf(
			nearest_water, field.distance_to_river(ParkSpec.WEST, zz)
		)
		zz += 6.0
	_expect(
		nearest_water > HeightField.RIVER_HALF_WIDTH + 4.0,
		"and stands %.1f m from the middle of the river, clear of the water" % nearest_water
	)

	# The gate is a few paces off the road east, which is how a child finds it.
	var road_z := 18.0 + (ParkSpec.gate().x / 440.0) * 40.0
	_expect(
		absf(ParkSpec.SOUTH - road_z) < 12.0,
		"the gate stands %.1f m from the road east" % absf(ParkSpec.SOUTH - road_z)
	)

	# Nothing grows or lies about on it.
	_expect(
		field.forest_density_at(ParkSpec.centre().x, ParkSpec.centre().z) == 0.0,
		"no trees on the fairground"
	)
	var rocks := Boulders.new(field, 20260903)
	get_root().add_child(rocks)
	_expect(not rocks._suits(ParkSpec.centre().x, ParkSpec.centre().z), "and no boulders")
	rocks.queue_free()

	var park := Park.new(field)
	get_root().add_child(park)

	# Every ride stands inside the fence, with the verge to spare.
	# Each one measured across the ground and along it separately: the coaster
	# is six metres wide and a hundred and thirty long, and one number for both
	# puts it out through the fence in the direction it is not.
	for ride: Array in [
		["carousel", Park.CAROUSEL_AT, Carousel.RADIUS, Carousel.RADIUS],
		["walkway", Park.WALKWAY_AT, Walkway.WIDTH + Walkway.GAP, Walkway.LENGTH * 0.5 + 1.5],
		["trampoline", Park.TRAMPOLINE_AT, Park.TRAMPOLINE_RADIUS, Park.TRAMPOLINE_RADIUS],
		["wheel", Park.WHEEL_AT, 3.5, FerrisWheel.RADIUS],
		["coaster", Park.COASTER_AT, RollerCoaster.HALF_WIDTH + 1.0, RollerCoaster.HALF_LENGTH],
	]:
		var at: Vector3 = ride[1]
		var across: float = ride[2]
		var along: float = ride[3]
		for corner: Vector2 in [
			Vector2(across, 0.0), Vector2(-across, 0.0),
			Vector2(0.0, along), Vector2(0.0, -along)
		]:
			_expect(
				ParkSpec.inside(at.x + corner.x, at.z + corner.y),
				"the %s stands inside the fence" % ride[0]
			)

	# And no two of them are in the same place.
	var rides: Array = [
		[Park.CAROUSEL_AT, Carousel.RADIUS], [Park.WALKWAY_AT, Walkway.LENGTH * 0.5],
		[Park.TRAMPOLINE_AT, Park.TRAMPOLINE_RADIUS], [Park.WHEEL_AT, FerrisWheel.RADIUS],
	]
	for first in rides.size():
		for second in range(first + 1, rides.size()):
			var a: Vector3 = rides[first][0]
			var b: Vector3 = rides[second][0]
			var apart := Vector2(a.x - b.x, a.z - b.z).length()
			_expect(
				apart > float(rides[first][1]) + float(rides[second][1]),
				"two rides %.1f m apart do not share ground" % apart
			)

	# The rides are what was asked for: a big trampoline, thirty metres of
	# wheel, twenty of coaster, fifteen of walkway each way.
	_expect(
		Park.TRAMPOLINE_RADIUS > Places.TRAMPOLINE_RADIUS * 1.9,
		"the trampoline is twice the playground's: %.1f m against %.1f" % [
			Park.TRAMPOLINE_RADIUS, Places.TRAMPOLINE_RADIUS
		]
	)
	_expect(
		absf(park.wheel.top_of_the_ride() - 30.0) < 1.5,
		"the wheel carries a child to %.1f m" % park.wheel.top_of_the_ride()
	)
	_expect(
		park.coaster.highest() > 18.0 and park.coaster.highest() <= 20.5,
		"the coaster climbs to %.1f m" % park.coaster.highest()
	)
	_expect(
		RollerCoaster.HALF_LENGTH * 2.0 > ParkSpec.length() * 0.75,
		"and runs %.0f m, most of the length of the ground" % (RollerCoaster.HALF_LENGTH * 2.0)
	)
	_expect(
		Walkway.LENGTH > 20.0,
		"the walkways are %.1f m of belt, which is a ride rather than a step" % Walkway.LENGTH
	)
	# And they can be got onto: the ramp at each end is solid and gentle
	# enough to walk up. They were painted slopes with nothing behind them,
	# and the belt was a step a third of a metre high — a character body
	# climbs slopes and not steps, so the whole ride was unreachable.
	_expect(
		Walkway.TOP / Walkway.RAMP_LENGTH < tan(Player.CLIMBS_TO),
		"the ramp onto a belt rises one in %.1f, which is a walk" % (
			Walkway.RAMP_LENGTH / Walkway.TOP
		)
	)
	var north := park.walkway.carries(0)
	var south := park.walkway.carries(1)
	_expect(
		north.dot(south) < 0.0 and absf(north.z) > 0.5,
		"and run opposite ways: %.1f and %.1f" % [north.z, south.z]
	)

	# You can step into a coaster car from the platform: it stands level with
	# the car's floor, and the car is open at the sides. It had four walls and
	# a platform a metre below it, so the ride could be looked at and never
	# ridden.
	var boards := park.coaster.point_at(park.coaster.circuit() * RollerCoaster.BOARDS_AT)
	var platform := park.coaster.get_node("Platform") as StaticBody3D
	_expect(platform != null, "the station has a platform")
	if platform != null:
		var deck := (platform.get_child(0) as CollisionShape3D)
		var deck_top := deck.position.y + (deck.shape as BoxShape3D).size.y * 0.5
		var car_floor := boards.y + RollerCoaster.CAR_FLOOR
		_expect(
			absf(deck_top - car_floor) < 0.25,
			"and it stands level with the car floor: %.2f m against %.2f" % [deck_top, car_floor]
		)

	# The belts look like they are moving, and their arrows point the way they
	# actually go. The arrows were built from the belt's own heading and came
	# out pointing back up it, which is worse than no arrow at all: a child
	# reads it, steps on, and is carried the other way.
	for side in 2:
		var carries := park.walkway.carries(side)
		var treads := park.walkway.get_node(
			"Treads%s" % ("North" if side == 0 else "South")
		) as MultiMeshInstance3D
		_expect(treads != null, "belt %d has treads on it" % side)
		if treads == null:
			continue
		var apex := Vector3.ZERO
		for point in treads.multimesh.mesh.get_faces():
			if absf(point.z) > absf(apex.z):
				apex = point
		_expect(
			signf(apex.z) == signf(carries.z),
			"and its arrow points the way it runs: arrow %.2f, belt %.2f" % [apex.z, carries.z]
		)
		# Asked of the belt rather than of the multimesh: instance transforms
		# live on the rendering server, and there is no rendering server here,
		# so a headless check reads nothing back from one however well it is
		# working.
		var before := park.walkway.tread_at(side, 0)
		park.walkway._physics_process(0.25)
		var after := park.walkway.tread_at(side, 0)
		_expect(
			absf(after - before) > 0.05,
			"and its treads are seen to move: %.2f m in a quarter second" % absf(after - before)
		)
		# The right way: the treads go the way the belt carries you.
		_expect(
			signf(after - before) == signf(carries.z) or absf(after - before) > Walkway.LENGTH * 0.5,
			"and they move the way it runs"
		)

	# The moving parts carry their passengers themselves rather than leaving it
	# to the engine. Godot carries a character along a platform that slides and
	# abandons them on one that turns, and where it does help it helps *as
	# well*, so a child went round half again as fast as the floor. So: the
	# carousel's floor is a still disc (a disc turned about its middle is the
	# same disc), and the gondolas are not moving platforms at all.
	_expect(
		park.carousel.get_node("Floor") is StaticBody3D,
		"the carousel's floor is still, and only its paint goes round"
	)
	var gondola := park.wheel.gondola(0) as AnimatableBody3D
	_expect(gondola != null, "a gondola is a body a child can stand in")
	if gondola != null:
		_expect(
			not gondola.sync_to_physics,
			"and is not also carried by the engine, which would double the ride"
		)

	# They actually move, and the coaster is slow over the top and fast at the
	# bottom, which is the whole feeling of a coaster.
	var before := park.carousel.turned()
	park.carousel._physics_process(1.0)
	_expect(park.carousel.turned() > before, "the carousel goes round")
	var wheel_before := park.wheel.turned()
	park.wheel._physics_process(1.0)
	_expect(park.wheel.turned() > wheel_before, "the wheel goes round")
	_expect(
		park.coaster.speed_at(0.46) > park.coaster.speed_at(0.30) * 1.5,
		"the coaster runs %.1f m/s at the bottom against %.1f over the top" % [
			park.coaster.speed_at(0.46), park.coaster.speed_at(0.30)
		]
	)
	# And the track is a loop: it comes back to where it started, at the height
	# it started, or a car falls off the end of it.
	var start := park.coaster.point_at(0.0)
	var round_again := park.coaster.point_at(park.coaster.circuit())
	_expect(
		start.distance_to(round_again) < 0.01,
		"the coaster's track closes on itself"
	)

	# It is all drawn.
	var triangles := 0
	for node: Node in [park, park.carousel, park.wheel, park.coaster, park.walkway]:
		for child in node.get_children():
			var drawn := child as MeshInstance3D
			if drawn != null:
				triangles += drawn.mesh.get_faces().size() / 3
	_expect(triangles > 2000, "the fairground is drawn: %d triangles" % triangles)
	park.queue_free()

## The rides actually carry somebody.
##
## Everything else about the fairground can be read off the geometry; this
## cannot. A turning floor that does not take a child round with it, a belt
## that does not push, a gondola that rises out from under its passenger —
## each of those looks perfectly right in a screenshot and is the whole ride
## being broken. So a body is stood on each of them and the physics is run.
func _check_the_rides_carry_a_child() -> void:
	print("the rides carry a child")
	var field := HeightField.new(20260903)
	var park := Park.new(field)
	get_root().add_child(park)
	# The ground under the fairground, so a body has something to fall onto
	# rather than falling for ever.
	var floor_body := StaticBody3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(400.0, 2.0, 400.0)
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = slab
	floor_shape.position = Vector3(
		ParkSpec.centre().x, ParkSpec.LEVEL - 1.0, ParkSpec.centre().z
	)
	floor_body.add_child(floor_shape)
	get_root().add_child(floor_body)

	# On the carousel, a stride out from the middle: after a few seconds of
	# turning, a passenger has gone round with it.
	var rider := CharacterBody3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = Player.RADIUS
	shape.height = Player.HEIGHT
	var body_shape := CollisionShape3D.new()
	body_shape.shape = shape
	body_shape.position = Vector3(0.0, Player.HEIGHT * 0.5, 0.0)
	rider.add_child(body_shape)
	get_root().add_child(rider)

	var deck := park.carousel.position + Vector3(
		3.0, Carousel.FLOOR_HEIGHT + 0.7, 0.0
	)
	rider.global_position = deck
	var turned_before := park.carousel.turned()
	for step in 90:
		rider.velocity.y -= 24.0 * (1.0 / 60.0)
		rider.global_position += park.carry(rider.global_position, 1.0 / 60.0)
		rider.move_and_slide()
		await physics_frame
	var swept := park.carousel.turned() - turned_before
	var moved := Vector2(
		rider.global_position.x - park.carousel.position.x,
		rider.global_position.z - park.carousel.position.z
	)
	# Measured the way the floor turns: a point on a floor rotating about the
	# upright axis sweeps the other way round in the x/z plane.
	var swept_by_rider := -moved.angle()
	_expect(
		rider.global_position.y > park.carousel.position.y + Carousel.FLOOR_HEIGHT,
		"a child on the carousel stands on its floor rather than sinking through it"
	)
	_expect(
		swept_by_rider > swept * 0.6 and swept_by_rider < swept * 1.4,
		"and is carried round with it: %.2f rad against the floor's %.2f" % [
			swept_by_rider, swept
		]
	)

	# On a belt: carried along it, and the other belt carries the other way.
	var belt := park.walkway.position + Vector3(
		-(Walkway.WIDTH + Walkway.GAP) * 0.5, Walkway.TOP + 0.9, 0.0
	)
	rider.global_position = belt
	rider.velocity = Vector3.ZERO
	for step in 60:
		rider.velocity.y -= 24.0 * (1.0 / 60.0)
		rider.global_position += park.carry(rider.global_position, 1.0 / 60.0)
		rider.move_and_slide()
		await physics_frame
	var along := rider.global_position.z - belt.z
	_expect(
		along < -Walkway.SPEED * 0.4,
		"a child on the northbound belt is carried %.1f m up it" % -along
	)

	# And onto the coaster's platform, which stands level with the car floor
	# and nearly two metres over the sand: the steps are drawn as a flight and
	# walked as a ramp, because a character body stops dead at a riser.
	var station := park.coaster.position + park.coaster.point_at(
		park.coaster.circuit() * RollerCoaster.BOARDS_AT
	)
	var stair_foot := Vector3(
		station.x + 2.6, park.coaster.position.y + 0.6, station.z + 16.0 * 0.5 + RollerCoaster.STEPS_RUN + 1.0
	)
	rider.global_position = stair_foot
	rider.velocity = Vector3.ZERO
	for step in 180:
		rider.velocity.y -= 24.0 * (1.0 / 60.0)
		rider.velocity.z = -Player.WALK_SPEED
		rider.global_position += park.carry(rider.global_position, 1.0 / 60.0)
		rider.move_and_slide()
		await physics_frame
	_expect(
		rider.global_position.y > station.y + RollerCoaster.CAR_FLOOR - 0.4,
		"a child who walks at the station's steps ends up on the platform: %.2f m against %.2f" % [
			rider.global_position.y, station.y + RollerCoaster.CAR_FLOOR
		]
	)

	# And a child can get onto a belt by walking at it, which is the whole
	# question: the ramps used to be scenery and the ride was unreachable.
	var approach := park.walkway.position + Vector3(
		-(Walkway.WIDTH + Walkway.GAP) * 0.5,
		0.6,
		Walkway.LENGTH * 0.5 + Walkway.RAMP_LENGTH + 1.2
	)
	rider.global_position = approach
	rider.velocity = Vector3.ZERO
	for step in 150:
		rider.velocity.y -= 24.0 * (1.0 / 60.0)
		# Walking north, at the pace a child walks.
		rider.velocity.z = -Player.WALK_SPEED
		rider.global_position += park.carry(rider.global_position, 1.0 / 60.0)
		rider.move_and_slide()
		await physics_frame
	_expect(
		rider.global_position.y > park.walkway.position.y + Walkway.TOP - 0.15,
		"a child who walks at a belt ends up on it: %.2f m against the belt at %.2f" % [
			rider.global_position.y - park.walkway.position.y, Walkway.TOP
		]
	)

	# In a gondola: lifted with it rather than left where they were.
	var car := park.wheel.gondola(0)
	rider.global_position = car.global_position + Vector3(0.0, 0.2, 0.0)
	rider.velocity = Vector3.ZERO
	# Let them settle onto the floor before measuring, or the drop into the car
	# is counted as the ride failing to lift them.
	for settle in 30:
		rider.velocity.y -= 24.0 * (1.0 / 60.0)
		rider.global_position += park.carry(rider.global_position, 1.0 / 60.0)
		rider.move_and_slide()
		await physics_frame
	var lifted_from := rider.global_position.y
	var car_from := car.global_position.y
	for step in 120:
		rider.velocity.y -= 24.0 * (1.0 / 60.0)
		rider.global_position += park.carry(rider.global_position, 1.0 / 60.0)
		rider.move_and_slide()
		await physics_frame
	var car_rose := car.global_position.y - car_from
	var rider_rose := rider.global_position.y - lifted_from
	_expect(
		absf(rider_rose - car_rose) < 0.6,
		"a child in a gondola goes with it: the car moved %.2f m and they moved %.2f" % [
			car_rose, rider_rose
		]
	)

	rider.queue_free()
	floor_body.queue_free()
	park.queue_free()

## Every pile under the coaster reaches the sand.
##
## They did not: the legs were turned with the track and offset in the track's
## own frame, so on a slope they leaned with the rails and their feet stopped
## in mid-air. Read off the drawn mesh, because that is the thing a child
## looks at.
func _check_the_coaster_stands_on_the_ground() -> void:
	print("the coaster stands on the ground")
	var field := HeightField.new(20260903)
	var coaster := RollerCoaster.new(ParkSpec.centre())
	get_root().add_child(coaster)
	var drawn := coaster.get_node("Track") as MeshInstance3D
	_expect(drawn != null, "the track is drawn")

	var feet: Array[Vector2] = []
	var lowest := INF
	for point in drawn.mesh.get_faces():
		lowest = minf(lowest, point.y)
		if point.y < 0.30:
			feet.append(Vector2(point.x, point.z))
	_expect(lowest > -0.6, "nothing is buried: the lowest timber is at %.2f m" % lowest)
	_expect(feet.size() > 50, "and %d pieces of it meet the sand" % feet.size())

	# Wherever the track is high, there is a foot on the ground near it.
	var unsupported := 0
	var total := coaster.circuit()
	var step := total / 60.0
	for piece in 60:
		var here := coaster.point_at(step * float(piece))
		if here.y < 4.0:
			continue
		var nearest := INF
		for foot in feet:
			nearest = minf(nearest, foot.distance_to(Vector2(here.x, here.z)))
		# Half the span between bents, and a little over: a piece of track
		# halfway between two piles is supported by both.
		if nearest > 7.0:
			unsupported += 1
	_expect(
		unsupported == 0,
		"every high piece of track has a pile under it: %d without" % unsupported
	)
	coaster.queue_free()

## You walk into the rides, not through them.
##
## The wheel's legs, the coaster's piles, the carousel's column and the sides
## of the belts had no collision at all: a child walked through a thirty-metre
## wheel as though it were painted on the sky. This is the same fault a tree
## with no trunk has, and it is tested the same way — by firing a ray at the
## thing and expecting to be stopped.
func _check_the_rides_are_solid() -> void:
	print("the rides are solid")
	var field := HeightField.new(20260903)
	var park := Park.new(field)
	get_root().add_child(park)
	# One physics frame, or the bodies are not in the space yet and every ray
	# passes through everything.
	await physics_frame

	var space := get_root().get_world_3d().direct_space_state
	var waist := 1.0

	# Across the wheel's frame, at the height a child walks: the ray starts
	# outside one pair of legs and ends outside the other.
	var wheel := park.wheel.position
	_expect(
		_blocked(space, wheel + Vector3(-8.0, waist, 0.0), wheel + Vector3(8.0, waist, 0.0)),
		"the big wheel's frame stops you"
	)

	# Along the line the coaster's piles stand on, down the western straight:
	# a ray fired the length of it must meet timber. Firing across the track at
	# scattered points was a test of luck — the piles are a handspan wide and
	# eleven metres apart — and it failed the day they were thinned out even
	# though every one of them was still there.
	var coaster := park.coaster.position
	var pile_line := -RollerCoaster.HALF_WIDTH - RollerCoaster.PILE_OFFSET
	_expect(
		_blocked(
			space,
			coaster + Vector3(pile_line, waist, -RollerCoaster.HALF_LENGTH * 0.8),
			coaster + Vector3(pile_line, waist, RollerCoaster.HALF_LENGTH * 0.8)
		),
		"the coaster's piles stop you"
	)
	# The track itself is one swept surface, not a row of tilted boxes. Two
	# boxes turned differently cannot be laid flush — their corners cross —
	# and a child standing on the result sinks in, catches and shakes.
	var frame := park.coaster.get_node("Frame") as StaticBody3D
	var swept := 0
	var boxed := 0
	for child in frame.get_children():
		var collider := child as CollisionShape3D
		if collider == null:
			continue
		if collider.shape is ConcavePolygonShape3D:
			swept += 1
		elif collider.shape is BoxShape3D:
			boxed += 1
	_expect(swept == 1, "the track is one swept surface: %d of them" % swept)
	_expect(
		boxed < 90,
		"and the boxes left are the uprights, not the rails: %d" % boxed
	)

	# And the ground between the two straights is open: a coaster is a frame to
	# walk under, not a wall.
	_expect(
		not _blocked(
			space,
			coaster + Vector3(0.0, waist, -RollerCoaster.HALF_LENGTH * 0.4),
			coaster + Vector3(0.0, waist, RollerCoaster.HALF_LENGTH * 0.4)
		),
		"and you can walk under it between them"
	)

	# The legs under the station platform, which a child walked through on
	# their way to the ride the platform is for.
	var boards := park.coaster.position + park.coaster.point_at(
		park.coaster.circuit() * RollerCoaster.BOARDS_AT
	)
	_expect(
		_blocked(
			space,
			Vector3(boards.x + 3.8, park.coaster.position.y + 0.5, boards.z - 6.0),
			Vector3(boards.x + 3.8, park.coaster.position.y + 0.5, boards.z + 6.0)
		),
		"the station's legs stop you"
	)

	# The carousel's middle column, and the sides of the belts.
	var carousel := park.carousel.position
	_expect(
		_blocked(space, carousel + Vector3(-3.0, waist + 0.6, 0.0), carousel + Vector3(3.0, waist + 0.6, 0.0)),
		"the carousel's column stops you"
	)
	var walkway := park.walkway.position
	_expect(
		_blocked(space, walkway + Vector3(-4.0, Walkway.TOP + 0.4, 0.0), walkway + Vector3(4.0, Walkway.TOP + 0.4, 0.0)),
		"you cannot walk in through the side of a belt"
	)
	# But the way onto them is open: the ends are where you step on.
	_expect(
		not _blocked(
			space,
			walkway + Vector3(-(Walkway.WIDTH + Walkway.GAP) * 0.5, Walkway.TOP + 0.4, Walkway.LENGTH * 0.5 + 3.0),
			walkway + Vector3(-(Walkway.WIDTH + Walkway.GAP) * 0.5, Walkway.TOP + 0.4, 0.0)
		),
		"and the ends of them are open, which is where a child gets on"
	)
	park.queue_free()

## Is the line between two points blocked by anything solid?
func _blocked(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	return not space.intersect_ray(query).is_empty()

## Nothing on the big wheel is underground, and its gondolas hang clear of the
## sand — the whole ride was half a metre into the ground when its hub was set
## to its own radius and the cars were forgotten about.
func _check_the_wheel_stands_on_the_sand() -> void:
	print("the big wheel stands on the sand")
	var wheel := FerrisWheel.new(Vector3.ZERO)
	get_root().add_child(wheel)
	var lowest := INF
	for child in wheel.get_children():
		var drawn := child as MeshInstance3D
		if drawn != null:
			lowest = minf(lowest, drawn.mesh.get_aabb().position.y)
	_expect(lowest > -0.25, "the frame stands on the sand: lowest timber at %.2f m" % lowest)

	var lowest_car := INF
	for index in FerrisWheel.GONDOLAS:
		lowest_car = minf(lowest_car, (wheel.gondola(index) as Node3D).position.y)
	_expect(
		lowest_car > 0.5,
		"and the lowest gondola floor is %.2f m up, which is a step into it" % lowest_car
	)
	_expect(
		absf(wheel.top_of_the_ride() - 30.0) < 1.5,
		"while the top of the ride is %.1f m" % wheel.top_of_the_ride()
	)

	# And it turns about its axle rather than about its feet.
	#
	# The rim was built at its true height and hung on a node standing on the
	# ground, so turning that node swung the whole wheel about a point in the
	# sand: half a turn put the rim under the fairground and the gondolas,
	# which were placed properly, were left hanging in the air on their own. A
	# thing that spins has to be built about the point it spins on, and this is
	# the only way to see that it is.
	for quarter in 8:
		wheel._turned = TAU * float(quarter) / 8.0
		wheel._rim.rotation.x = -wheel._turned
		var top := wheel.rim_point(0.0)
		# A point on the rim is a rim's radius from the hub, whichever way
		# round the wheel has gone. Measured from the axle, not from the
		# upright axis: the rim turns in a plane, so its distance from the
		# tower is nothing like constant and asking for that was the check
		# being wrong rather than the wheel.
		var hub := Vector3(0.0, FerrisWheel.HUB_HEIGHT, 0.0)
		_expect(
			absf(top.distance_to(hub) - FerrisWheel.RADIUS) < 0.01 and absf(top.x) < 0.01,
			"a point on the rim stays a rim's radius from the axle, a turn of %.2f in" % wheel._turned
		)
		_expect(
			top.y > 1.5,
			"and never goes into the sand: %.1f m at a turn of %.2f" % [top.y, wheel._turned]
		)
	wheel.queue_free()

## Nothing lives on the ground kept for people, except a cat or a dog.
##
## Sheep on the football pitch, cows in the fairground, a squirrel in the
## swimming pool: funny once, and then it is a valley nobody has charge of.
## Cats and dogs are the exception, because that is exactly where a cat or a
## dog would be.
func _check_the_animals_keep_off_the_playing_places() -> void:
	print("the animals keep off the playing places")
	var field := HeightField.new(20260903)
	var animals := Animals.new(field, 20260903)
	get_root().add_child(animals)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242

	var camp := field.camp_centre()
	var kept: Array[Vector3] = [
		ParkSpec.centre(),
		Pitch.CENTRE,
		PlaceSpec.centre_of(&"pool", camp),
		PlaceSpec.centre_of(&"playground", camp),
	]
	var strays := 0
	var tried := 0
	for spot in kept:
		_expect(
			animals.kept_for_people(spot.x, spot.z),
			"the ground at %v is kept for people" % Vector2(spot.x, spot.z)
		)
		for step in 40:
			var at := spot + Vector3(rng.randf_range(-8.0, 8.0), 0.0, rng.randf_range(-8.0, 8.0))
			if not animals.kept_for_people(at.x, at.z):
				continue
			tried += 1
			var kind := animals._kind_at(at.x, at.z, rng)
			if kind == &"":
				continue
			if not Animals.belongs_at(kind, true):
				strays += 1
	_expect(tried > 40, "%d spots on that ground were tried" % tried)
	_expect(strays == 0, "and nothing but cats and dogs was found on it: %d strays" % strays)
	_expect(
		Animals.belongs_at(AnimalKinds.CAT, true) and Animals.belongs_at(AnimalKinds.DOG, true),
		"a cat and a dog may still be there"
	)
	_expect(
		not Animals.belongs_at(AnimalKinds.SHEEP, true)
		and not Animals.belongs_at(AnimalKinds.COW, true),
		"and a sheep or a cow may not"
	)

	# And they walk round the signpost rather than through its plinth, which
	# is what was reported: a sheep standing in the middle of it.
	var post := Vector3(field.camp_centre().x, 0.0, field.camp_centre().z) + Signpost.OFFSET
	animals.keep_out = [Vector3(post.x, 1.4, post.z)]
	_expect(animals.blocked_at(post.x, post.z, 0.2), "the signpost is something to walk round")
	_expect(
		not animals.blocked_at(post.x + 6.0, post.z, 0.2),
		"and the ground beside it is not"
	)
	animals.queue_free()

## The coaster runs a lap under its own weight, stops to be boarded, and the
## speed it does it at is the speed falling that far gives you.
##
## This is the only way to know. A profile that climbs higher than it fell
## from stalls halfway up a hill and the train stands there for ever; brakes
## that are too weak run the station; a dwell that never fires means a child
## has to step into a moving car. None of it can be seen in a screenshot.
func _check_the_coaster_runs_a_lap() -> void:
	print("the coaster runs a lap")
	var coaster := RollerCoaster.new(Vector3.ZERO)
	get_root().add_child(coaster)
	var total := coaster.circuit()

	# No crest is higher than the drop that feeds it, or the train stalls.
	var top := coaster.height_at(RollerCoaster.LIFT_TOP)
	var previous := top
	var lowest_since := top
	for step in 200:
		var fraction := RollerCoaster.LIFT_TOP + (1.0 - RollerCoaster.LIFT_TOP) * float(step) / 200.0
		var height := coaster.height_at(fraction)
		lowest_since = minf(lowest_since, height)
		if height > previous and height > top:
			_fail("a crest at %.1f m stands over the lift's %.1f m" % [height, top])
			break
		previous = height

	# Run it, a frame at a time, for three minutes of game time.
	var tick := 1.0 / 60.0
	var stood_still := 0.0
	var longest_stand := 0.0
	var stopped_at := -1.0
	var fastest := 0.0
	var slowest_running := 99.0
	var laps := 0
	var was := coaster.car_distance()
	for step in int(180.0 / tick):
		coaster._roll(tick)
		var now := coaster.car_distance()
		if now < was - total * 0.5:
			laps += 1
		was = now
		if coaster.speed() < 0.01:
			stood_still += tick
			longest_stand = maxf(longest_stand, stood_still)
			if stopped_at < 0.0:
				stopped_at = now / total
		else:
			stood_still = 0.0
			fastest = maxf(fastest, coaster.speed())
			# Only while it is running free, which is where the interesting
			# part of the speed is.
			var fraction := now / total
			if fraction > RollerCoaster.LIFT_TOP and fraction < RollerCoaster.BRAKES_FROM:
				slowest_running = minf(slowest_running, coaster.speed())

	_expect(laps >= 1, "it goes round: %d laps in three minutes" % laps)
	_expect(
		longest_stand > RollerCoaster.DWELL * 0.9 and longest_stand < RollerCoaster.DWELL * 1.6,
		"and stands %.1f s at the platform against the %.1f it is meant to" % [
			longest_stand, RollerCoaster.DWELL
		]
	)
	_expect(
		stopped_at >= 0.0 and absf(stopped_at - RollerCoaster.BOARDS_AT) < 0.02,
		"it stops at the platform, not somewhere down the track: at %.3f" % stopped_at
	)
	_expect(
		fastest > 7.0 and fastest <= RollerCoaster.TOP_SPEED + 0.01,
		"the fastest it goes is %.1f m/s, which is a ride and not a bolt" % fastest
	)
	_expect(
		slowest_running < fastest * 0.6,
		"and it slows to %.1f over the crests: a coaster that runs at one speed is a train" % slowest_running
	)

	# The bends are banked and the straights are not, which is the difference
	# between a coaster and a tram.
	# In the middle of a straight, not at the end of one: the two sampled
	# points must be a straight and a bend, and total * 0.5 falls exactly on
	# the seam between them.
	var straight_bank := absf(coaster.bank_at(
		(RollerCoaster.HALF_LENGTH - RollerCoaster.HALF_WIDTH)
	))
	var bend_bank := absf(coaster.bank_at(
		2.0 * (RollerCoaster.HALF_LENGTH - RollerCoaster.HALF_WIDTH)
		+ PI * RollerCoaster.HALF_WIDTH * 0.5
	))
	_expect(straight_bank < deg_to_rad(2.0), "the straights lie flat: %.1f deg" % rad_to_deg(straight_bank))
	_expect(
		bend_bank > deg_to_rad(10.0),
		"and the bends lay over into the turn: %.1f deg" % rad_to_deg(bend_bank)
	)

	# A car sits on its track, banked or not: its floor is a car's floor above
	# the rail and not somewhere beside it.
	for sample in 12:
		var along := total * float(sample) / 12.0
		var rail := coaster.point_at(along)
		var seat := rail + coaster.frame_at(along) * Vector3(0.0, RollerCoaster.CAR_FLOOR, 0.0)
		_expect(
			absf(seat.distance_to(rail) - RollerCoaster.CAR_FLOOR) < 0.01,
			"the car sits on the rail at %.2f round" % (along / total)
		)

	# Falling makes it faster and climbing makes it slower, which is the whole
	# of it. Checked where the track actually falls and climbs.
	var falling := coaster.gradient_at(0.36)
	var climbing := coaster.gradient_at(0.45)
	_expect(falling < 0.0, "the first drop falls")
	_expect(climbing > 0.0, "and the camelback after it climbs")
	coaster.queue_free()

## The fairground charges for its rides, and the kiosk is where you pay.
##
## Ten coins a ride, the same for all of them, and the trampoline and the
## walkways free — they are the two a child uses while working out what the
## place is, and charging for those would make the fairground a shop.
func _check_the_rides_are_paid_for() -> void:
	print("the rides are paid for")
	var field := HeightField.new(20260903)
	var park := Park.new(field)
	get_root().add_child(park)

	_expect(Park.RIDE_PRICE == 10, "a ride is %d coins" % Park.RIDE_PRICE)
	for paid: StringName in [&"carousel", &"wheel", &"coaster"]:
		_expect(Park.charges_for(paid), "the %s takes a ticket" % paid)
	for free: StringName in [&"walkway", &"trampoline", &""]:
		_expect(not Park.charges_for(free), "the %s does not" % ("trampoline" if free == &"" else free))

	# The kiosk stands on the right hand as you walk in, inside the fence, and
	# near enough to the gate to be met on the way past.
	var booth := park.booth_at()
	var gate := ParkSpec.gate()
	_expect(ParkSpec.inside(booth.x, booth.z), "the kiosk stands inside the fence")
	_expect(booth.x > gate.x, "on the right hand of a child walking in")
	_expect(
		Vector2(booth.x - gate.x, booth.z - gate.z).length() < 12.0,
		"and %.1f m from the gate, which is on the way past" % Vector2(booth.x - gate.x, booth.z - gate.z).length()
	)
	_expect(park.at_the_booth(booth + Vector3(2.0, 0.0, 0.0)), "you can buy standing at it")
	_expect(
		not park.at_the_booth(booth + Vector3(0.0, 0.0, -30.0)),
		"and not from the middle of the fairground"
	)

	# The horses on the carousel face the way they are going, and they are
	# solid. They faced straight out from the middle — a row of horses looking
	# over a fence rather than a roundabout — and a child walked through them.
	_expect(
		park.carousel.get_node("Horses") is AnimatableBody3D,
		"the carousel's horses are something you bump into"
	)
	var horse_shapes := 0
	for child in (park.carousel.get_node("Horses") as Node).get_children():
		if child is CollisionShape3D:
			horse_shapes += 1
	_expect(horse_shapes == Carousel.HORSES, "%d of them, one for each horse" % horse_shapes)
	for horse in Carousel.HORSES:
		var angle := TAU * float(horse) / float(Carousel.HORSES)
		var spot := Vector3(cos(angle), 0.0, sin(angle))
		var facing := Basis(Vector3.UP, PI * 0.5 - angle) * Vector3.RIGHT
		_expect(
			absf(facing.dot(spot)) < 0.01,
			"horse %d faces along the circle rather than out of it" % horse
		)

	# A ticket is bought with coins and spent on a ride.
	var purse := Wallet.new()
	purse.earn(25)
	_expect(purse.buy_ticket(Park.RIDE_PRICE), "a ticket is bought")
	_expect(purse.coins == 15 and purse.tickets == 1, "it costs its price: %d coins, %d tickets" % [purse.coins, purse.tickets])
	_expect(purse.buy_ticket(Park.RIDE_PRICE), "and another")
	_expect(not purse.buy_ticket(Park.RIDE_PRICE), "but not a third, at five coins left")
	_expect(purse.tickets == 2, "so there are two in hand")
	_expect(purse.use_ticket() and purse.tickets == 1, "one is handed over at a ride")
	_expect(purse.use_ticket() and purse.tickets == 0, "and the other")
	_expect(not purse.use_ticket(), "and then there are none to hand over")

	# They survive being put down and picked up again.
	var kept := Wallet.new()
	purse.earn(10)
	purse.buy_ticket(Park.RIDE_PRICE)
	kept.from_data(purse.to_data())
	_expect(
		kept.tickets == purse.tickets and kept.coins == purse.coins,
		"tickets are remembered between days: %d" % kept.tickets
	)

	# And the game can tell which ride somebody is standing on, which is what
	# takes the ticket.
	var deck := park.carousel.position + Vector3(3.0, Carousel.FLOOR_HEIGHT + 0.5, 0.0)
	_expect(park.ride_under(deck) == &"carousel", "a child on the carousel is on the carousel")
	var gondola := (park.wheel.gondola(0) as Node3D).global_position + Vector3(0.0, 0.5, 0.0)
	_expect(park.ride_under(gondola) == &"wheel", "and one in a gondola is on the wheel")
	var car := (park.coaster.car_at(0) as Node3D).global_position + Vector3(0.0, 0.5, 0.0)
	_expect(park.ride_under(car) == &"coaster", "and one in a car is on the coaster")
	_expect(
		park.ride_under(ParkSpec.centre()) == &"",
		"while a child standing on the sand is on nothing"
	)
	park.queue_free()

## A child's valley survives a new phone.
##
## Everything a child makes lives in the app's own private storage, and Android
## will copy that into the owner's Google account and restore it on a new device
## — but only if the app allows it, and the export preset said no. A family that
## played for a month and changed a phone would have started again from an empty
## valley, and there is no way to notice that in testing: the only symptom is a
## loss that happens once, to somebody else, long afterwards.
##
## Read off the export preset, because that is the file that decides it.
func _check_a_valley_survives_a_new_phone() -> void:
	print("a valley survives a new phone")
	var preset := FileAccess.get_file_as_string("res://export_presets.cfg")
	_expect(not preset.is_empty(), "the export preset can be read")
	_expect(
		preset.contains("user_data_backup/allow=true"),
		"the Android build lets the system back up what a child has made"
	)
	# And everything worth keeping is in that storage rather than somewhere the
	# backup cannot see.
	_expect(
		Profiles.FOLDER.begins_with("user://"),
		"players are kept in the app's own storage: %s" % Profiles.FOLDER
	)
	_expect(
		SaveGame.PATH.begins_with("user://"),
		"and so is the save: %s" % SaveGame.PATH
	)

## Felling a tree you grew yourself gives back the coins the growing paid.
##
## Without it a child can plant a sapling, wait for it to mature, fell it for
## the coins and the timber and plant it again — which is not a valley, it is a
## machine for making money out of nothing, and a ten-year-old finds that in an
## afternoon.
func _check_felling_your_own_tree_costs_what_it_paid() -> void:
	print("felling your own tree costs what it paid")
	var field := HeightField.new(20260903)
	var structures := Structures.new(field)
	get_root().add_child(structures)

	var at := field.find_spawn_point() + Vector3(4.0, 0.0, 0.0)
	structures.place(BuildKinds.SAPLING, at, 0.0)
	var young := structures.nearest_grown_tree(at, 4.0)
	_expect(young.is_empty(), "a sapling is not something an axe fells")

	# Grown, the way the game grows it: by time passing.
	structures.advance_offline(
		BuildKinds.GROWTH_STAGE_SECONDS * float(BuildKinds.GROWTH_STAGES) + 1.0
	)
	# The ageing is recorded by advance_offline and applied by _process, so
	# that growth happens through exactly one code path rather than two.
	structures._process(0.1)
	var grown := structures.nearest_grown_tree(at, 4.0)
	_expect(not grown.is_empty(), "and a grown one is")
	_expect(
		structures.nearest_grown_tree(at + Vector3(40.0, 0.0, 0.0), 4.0).is_empty(),
		"but only within reach of the axe"
	)

	# The toll is exactly what growing it paid.
	var reward := BuildKinds.reward_for(BuildKinds.SAPLING)
	_expect(reward > 0, "growing a tree pays %d" % reward)
	var purse := Wallet.new()
	purse.earn(reward)
	var toll := mini(reward, purse.coins)
	purse.spend(toll)
	_expect(purse.coins == 0, "and felling it gives back all of it")

	# A child with nothing still fells the tree; they simply have nothing to
	# pay with. Being told "you may not" by a game about a valley is worse
	# than being told what it cost.
	var empty := Wallet.new()
	_expect(mini(reward, empty.coins) == 0, "a child with no coins pays nothing")

	structures.remove(grown)
	_expect(
		structures.nearest_grown_tree(at, 4.0).is_empty(),
		"and the tree is gone once it is felled"
	)
	structures.queue_free()

## Nothing is planted or built on ground that belongs to something else.
##
## A tree came up through the fairground beside the big wheel. The levelled
## places kept their own ground from the first day; everything built since —
## the pitch, the fairground, the crossing, the signs — was not on anybody's
## list, and a valley where a sapling can be planted in the middle of a
## roller coaster is a valley nobody is looking after.
func _check_nothing_is_planted_where_it_does_not_belong() -> void:
	print("nothing is planted where it does not belong")
	var field := HeightField.new(20260903)
	var inventory := Inventory.new()
	for kind in ItemKinds.ALL:
		inventory.add(kind, 99)
	var structures := Structures.new(field)
	get_root().add_child(structures)
	var build := BuildMode.new(field, structures, inventory)
	get_root().add_child(build)

	var camp := field.camp_centre()
	var forbidden: Array = [
		["the fairground", ParkSpec.centre()],
		["the fairground's fence", Vector3(ParkSpec.WEST + 1.0, 0.0, ParkSpec.SOUTH - 1.0)],
		["the football pitch", Pitch.CENTRE],
		["the pool", PlaceSpec.centre_of(&"pool", camp)],
		["the playground", PlaceSpec.centre_of(&"playground", camp)],
		["the café", PlaceSpec.centre_of(&"cafe", camp)],
		["the shop", PlaceSpec.centre_of(&"shop", camp)],
		["the range", PlaceSpec.centre_of(&"range", camp)],
		["the crossing", Vector3(
			field.river_centre_x(BridgeSpec.CENTRE_Z), 0.0, BridgeSpec.CENTRE_Z
		)],
		["the signs", camp + Signpost.OFFSET],
	]
	for spot: Array in forbidden:
		var at: Vector3 = spot[1]
		_expect(
			build._kept_ground(at.x, at.z),
			"nothing is planted on %s" % spot[0]
		)

	# And the open valley is still open, or the rule has eaten the game.
	var open := 0
	for step in 24:
		var angle := TAU * float(step) / 24.0
		var at := camp + Vector3(cos(angle) * 140.0, 0.0, sin(angle) * 140.0)
		if not build._kept_ground(at.x, at.z):
			open += 1
	_expect(open >= 20, "%d of 24 spots round the camp are still plantable" % open)
	build.queue_free()
	structures.queue_free()

## A stump goes when a tree grows where it stood.
##
## Felled and cleared are two different things: the tree must stay felled, or
## the forest — which is generated from the seed — stands the old one back up
## on the next rebuild. What goes is the stump.
func _check_a_stump_is_grubbed_out_by_a_new_tree() -> void:
	print("a stump is grubbed out by a new tree")
	var stumps := Felled.new()
	var at := Vector3(120.0, 0.0, -40.0)
	stumps.fell(at)
	stumps.fell(at + Vector3(0.8, 0.0, 0.0))
	stumps.fell(at + Vector3(6.0, 0.0, 0.0))
	_expect(stumps.count() == 3, "three trees were felled")
	_expect(stumps.shows_stump(at.x, at.z), "and each leaves a stump")

	var gone := stumps.clear_stumps_near(at, 1.0)
	_expect(gone == 2, "a tree grown here grubs out the two within a stride: %d" % gone)
	_expect(not stumps.shows_stump(at.x, at.z), "so that ground is clear")
	_expect(
		stumps.is_felled(at.x, at.z),
		"but the tree stays felled, or the forest stands the old one back up"
	)
	_expect(
		stumps.shows_stump(at.x + 6.0, at.z),
		"and the stump six metres away is untouched"
	)

	# It survives being saved and loaded, or the scar comes back tomorrow.
	var kept := Felled.new()
	kept.from_data(stumps.to_data())
	_expect(kept.count() == 3, "all three are remembered")
	_expect(not kept.shows_stump(at.x, at.z), "and the cleared ones stay cleared")
	_expect(kept.shows_stump(at.x + 6.0, at.z), "while the other still shows")

## The shop sells a second one, up to a limit, and takes things back.
##
## Ownership used to be a flag: you had a bicycle or you did not. A bicycle
## left at the far side of the valley still counted, so the shop refused to
## sell another and a child standing at the counter could not ride home. Things
## here are objects — but not without end, or a child buys a new one rather
## than walking back for the one they left.
func _check_the_shop_sells_seconds_and_buys_back() -> void:
	print("the shop sells seconds and buys back")
	_expect(ShopStock.limit(ShopStock.BICYCLE) == 3, "three bicycles at most")
	_expect(ShopStock.limit(ShopStock.MOTORCYCLE) == 2, "two motorcycles")
	_expect(ShopStock.limit(ShopStock.QUAD) == 1, "one quad")
	_expect(ShopStock.limit(ShopStock.AXE) == 3, "and three of anything else")

	# The quad sits between the two machines in price, as it does in speed.
	_expect(
		ShopStock.price(ShopStock.QUAD) > ShopStock.price(ShopStock.BICYCLE)
		and ShopStock.price(ShopStock.QUAD) < ShopStock.price(ShopStock.MOTORCYCLE),
		"the quad costs %d, between the bicycle and the motorcycle" % ShopStock.price(ShopStock.QUAD)
	)
	_expect(
		MountKinds.speed(MountKinds.QUAD) > MountKinds.speed(MountKinds.BICYCLE)
		and MountKinds.speed(MountKinds.QUAD) < MountKinds.speed(MountKinds.MOTORCYCLE),
		"and goes between them: %.1f m/s" % MountKinds.speed(MountKinds.QUAD)
	)
	# Four wheels, so it is wider than the two-wheeled machines and cannot be
	# mistaken for one from behind.
	var quad_box: Vector3 = MountKinds.body_box(MountKinds.QUAD)[0]
	var bike_box: Vector3 = MountKinds.body_box(MountKinds.MOTORCYCLE)[0]
	_expect(quad_box.x > bike_box.x * 1.5, "and is %.2f m wide against the motorcycle's %.2f" % [quad_box.x, bike_box.x])
	_expect(
		MountKinds.build_mesh(MountKinds.QUAD).get_faces().size() > 300,
		"the quad is drawn"
	)

	# Half the price back, rounded, and never more than was paid.
	for item: StringName in ShopStock.ALL:
		var back := ShopStock.sells_back(item)
		_expect(
			back <= ShopStock.price(item) and back >= ShopStock.price(item) / 2,
			"%s sells back for %d against %d" % [item, back, ShopStock.price(item)]
		)
	_expect(ShopStock.sells_back(ShopStock.BICYCLE) == 50, "a 99-coin bicycle comes back at 50")
	_expect(ShopStock.sells_back(ShopStock.CHOCOLATE) == 1, "and a 1-coin bar rounds to 1")

	# Buying, selling and the limit, on a purse.
	var purse := Wallet.new()
	purse.earn(ShopStock.price(ShopStock.BICYCLE) * 4)
	for bought in 3:
		_expect(
			purse.buy(ShopStock.BICYCLE, ShopStock.price(ShopStock.BICYCLE)),
			"bicycle %d is sold" % (bought + 1)
		)
	_expect(
		purse.count_of(ShopStock.BICYCLE) >= ShopStock.limit(ShopStock.BICYCLE),
		"which is as many as a child may have"
	)
	var coins_before := purse.coins
	var paid := purse.sell_back(ShopStock.BICYCLE, ShopStock.sells_back(ShopStock.BICYCLE))
	_expect(paid == 50 and purse.coins == coins_before + 50, "one sold back pays 50")
	_expect(purse.count_of(ShopStock.BICYCLE) == 2, "and leaves two")

	# And the world can hold more than one of a machine, which it could not:
	# a second bicycle replaced the first, wherever it was standing.
	var field := HeightField.new(20260903)
	var mounts := Mounts.new(field)
	get_root().add_child(mounts)
	var spot := field.find_spawn_point()
	for index in 3:
		mounts.place(mounts.free_id(MountKinds.BICYCLE), spot + Vector3(float(index) * 2.0, 0.0, 0.0))
	_expect(mounts.count_of_kind(MountKinds.BICYCLE) == 3, "three bicycles stand in the valley")
	_expect(mounts.sell_one(MountKinds.BICYCLE, spot), "one can be sold back")
	_expect(mounts.count_of_kind(MountKinds.BICYCLE) == 2, "leaving two standing")
	mounts.queue_free()

## Every machine with wheels is steered, and none of them is ridden indoors.
##
## The quad span on the spot the way the motorcycle used to, because it was
## left out of the one list that says a thing turns by going round rather than
## by pointing — and it was ridden into the shop and parked between the
## shelves, which the building had no opinion about either.
func _check_the_machines_steer() -> void:
	print("the machines steer")
	for wheeled: StringName in [
		MountKinds.BICYCLE, MountKinds.MOTORCYCLE, MountKinds.QUAD
	]:
		_expect(MountKinds.steers(wheeled), "the %s is steered, not pointed" % wheeled)
	_expect(not MountKinds.steers(MountKinds.HORSE), "and a horse turns where it stands")

	var field := HeightField.new(20260903)
	var mounts := Mounts.new(field)
	get_root().add_child(mounts)
	var camp := field.camp_centre()
	var indoors := PlaceSpec.centre_of(&"shop", camp)
	_expect(
		PlaceSpec.indoors(indoors.x, indoors.z, camp),
		"the middle of the shop is indoors"
	)
	for wheeled: StringName in [
		MountKinds.BICYCLE, MountKinds.MOTORCYCLE, MountKinds.QUAD, MountKinds.HORSE
	]:
		_expect(
			not mounts.can_ride_over(
				wheeled, Vector3(indoors.x, field.height_at(indoors.x, indoors.z), indoors.z)
			),
			"a %s is not ridden into the shop" % wheeled
		)
	mounts.queue_free()

	# A machine lays into its corners rather than turning bolt upright, which
	# is what the eye reads as turning hard.
	_expect(Player.RIDE_BANK > deg_to_rad(8.0), "a machine leans into a corner")
	_expect(
		Player.RIDE_BANK < deg_to_rad(35.0),
		"but never so far that a child reads it as falling over"
	)

	# The quad sounds like a bigger engine in a heavier machine rather than
	# like the motorcycle played back slower.
	_expect(
		Ambience.QUAD_PITCH < 1.0 and Ambience.QUAD_PITCH > 0.6,
		"the quad's note is %.2f of the motorcycle's" % Ambience.QUAD_PITCH
	)
	var sound := Ambience.new()
	get_root().add_child(sound)
	sound.engine(0.5, 0.0, false)
	var light := sound._engine.pitch_scale
	sound.engine(0.5, 0.0, true)
	_expect(sound._engine.pitch_scale < light, "and it is plainly the lower of the two")
	sound.engine(-1.0)
	sound.queue_free()
