extends RefCounted

## A three-year-old with a phone, made repeatable.
##
## The game's first rule is that a child tapping at random must never destroy
## anything: not a built piece, a planted tree, a coin, an item, a bought
## machine or a save. Every one of those was once lost to a single stray tap,
## and each was found by a person noticing. This boots the real game (main.tscn,
## on a fixed seed, with saving switched off), gives the child a lot to lose,
## and then taps at random for a few thousand frames, the way a toddler does:
## short presses, on whatever buttons are showing and on any bit of screen, with
## the stick and the build palette included.
##
## Time is the one thing made artificial. A HoldRing counts the frame's real
## delta, and on a loaded machine one frame can last longer than the second a
## hold needs, which would let a "tap" complete one. So the rings are stepped
## here by a fixed sixtieth of a second per frame instead, which is also what
## makes a run the same on every machine. Now and then a press is held for
## longer than a ring needs (a "parent's" press). Those must work, and the harness
## records what they spent, so the checks that follow cannot pass merely because
## nothing ever went through.
##
## What counts as a loss is anything that goes down without a completed hold or
## an answered question in the same frame: coins, a thing owned, an item in the
## bag, a built piece, a tree, a felled-tree record, a machine standing in the
## valley. A piece put up, or an item spent putting it up, is the child building,
## not losing.
##
## Run it alone, with far more frames, with:
##   godot --headless --script src/dev/toddler_fuzz_run.gd -- --frames=4000

const FRAME := 1.0 / 60.0
const TAP_SECONDS := Vector2(0.1, 0.3)
## Long enough to complete any HoldRing, and shorter than the reset button's.
const PARENT_HOLD_SECONDS := 1.25
const SEED := 20260903
const TestHouse := preload("res://src/dev/test_house.gd")

## What the run found, one line each. Empty means the child lost nothing.
var failures: Array[String] = []
## What the run did, for the log: taps, holds that completed, what they spent.
var report := {}

var _tree: SceneTree
var _main: Node
var _rng := RandomNumberGenerator.new()
var _frame := 0
var _phase := ""
var _last_tap := ""
## Events that would be a loss if nobody meant them, and whether somebody did.
var _pending: Array[String] = []
var _meant := false
var _meant_log: Array[String] = []
var _built_this_frame := 0
## Coins came in this frame: feeding an animal pays, and is the game, not a loss.
var _earned_this_frame := false
var _planted: Dictionary = {}
var _before := {}
var _taps := 0
## The last few taps, said in a failure so a stuck child can be traced.
var _recent: Array[String] = []
var _holds_completed := 0

## Boot the game, give the child a lot to lose, and tap for `frames` frames
## spread over every place and mode the child can be in.
func run(tree: SceneTree, frames: int, probe_every_phase := false, only: Array = []) -> void:
	# `only` names the phases to visit; none means all. The café and the shop are
	# four hundred metres out, and streaming the ground there is most of a
	# minute, so the suite stays near home and the stand-alone run goes everywhere.
	_tree = tree
	_rng.seed = SEED
	await _boot()
	if _main == null:
		return
	_stock_the_child()
	_listen()
	_before = _snapshot()
	var phases: Array = only if not only.is_empty() else [
		&"home", &"home_building", &"cafe", &"fairground", &"campfire", &"shop", &"settings",
	]
	var each := maxi(frames / phases.size(), 1)
	for phase: StringName in phases:
		await _enter(phase)
		await _sweep()
		await _tap_about(each)
		_reconcile()
		if phase == &"campfire":
			await _positive_control()
		if probe_every_phase:
			await _check_can_walk(String(phase))
	_release_everything()
	await _check_can_walk("the end")
	_compare(_before, _snapshot())
	report["taps"] = _taps
	report["holds_completed"] = _holds_completed
	report["meant"] = _meant_log
	_main.queue_free()
	await _tree.process_frame
	_main = null
	var main_script: GDScript = load("res://src/main.gd")
	main_script.set("forced_seed", 0)

func _boot() -> void:
	var main_script: GDScript = load("res://src/main.gd")
	# Not --seed= on a command line, which a check does not have. A forced seed
	# also stops the game reading or writing the child's own save.
	main_script.set("forced_seed", SEED)
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	_tree.root.add_child(_main)
	var waited := 0
	while _main.get("hud") == null and waited < 600:
		await _tree.process_frame
		waited += 1
	if _main.get("hud") == null:
		failures.append("the game never reached the valley (no interface after %d frames)" % waited)
		_main.queue_free()
		_main = null
		return
	# Streaming a few chunks a frame: the ground must exist under the child
	# before anything is tried on it.
	await _settle_ground(900)

func _settle_ground(limit: int) -> void:
	var world: World = _main.get("world")
	var waited := 0
	while waited < limit and not world.terrain.is_idle():
		await _tree.process_frame
		waited += 1
	for _i in 4:
		await _tree.process_frame

## Rich enough that every loss is a loss: coins and tickets, an axe, bought
## machines, a bag of everything, a furnished house, grown trees, a horse.
func _stock_the_child() -> void:
	var wallet: Wallet = _main.get("wallet")
	var inventory: Inventory = _main.get("inventory")
	var world: World = _main.get("world")
	var player: Player = _main.get("player")
	wallet.earn(900)
	# Bought as the game buys them, so a machine stands outside the shop and
	# the purse and the world agree.
	for item: StringName in [
		ShopStock.AXE, ShopStock.BICYCLE, ShopStock.WHISTLE, ShopStock.SHEARS,
		ShopStock.LANTERN, ShopStock.BOTTLE,
	]:
		_main.call("_on_buy", item)
	(_main.get("hud") as Hud).set_shop_open(false, wallet.coins, wallet.owned)
	wallet.earn(400)
	wallet.tickets = 3
	for kind in ItemKinds.ALL:
		inventory.add(kind, 300)

	var build: BuildMode = _main.get("build_mode")
	var field: HeightField = world.field
	var near: Vector3 = player.global_position + Vector3(0.0, 0.0, 14.0)
	var origin: Vector3 = TestHouse.find_site(build, field, near)
	if not origin.is_finite():
		failures.append("setup: no ground near the spawn for the child's house")
		return
	var steps := TestHouse.build(build, field, origin)
	var pieces := 0
	for step in steps:
		if bool(step["built"]):
			pieces += 1
	build.set_active(false)
	report["house_pieces"] = pieces
	_planted_trees(origin)
	# A campfire beside the house, for the phase that stands at one.
	var fire_at := origin + Vector3(7.5, 0.0, 1.0)
	fire_at.y = field.height_at(fire_at.x, fire_at.z)
	var structures: Structures = _main.get("structures")
	structures.place(BuildKinds.CAMPFIRE, fire_at, 0.0)
	_main.call("_refresh_fires")
	report["fire_at"] = fire_at
	report["house_origin"] = origin
	# A horse standing by the house, so the ride button has something to offer.
	var horse_at := origin + Vector3(-5.0, 0.0, 3.0)
	horse_at.y = field.height_at(horse_at.x, horse_at.z)
	world.mounts.place(world.mounts.free_id(MountKinds.HORSE), horse_at, 0.0)

## Three saplings, grown at once, so there are trees to lose and their reward
## is already in the purse.
func _planted_trees(origin: Vector3) -> void:
	var structures: Structures = _main.get("structures")
	var field: HeightField = (_main.get("world") as World).field
	for i in 3:
		var at := origin + Vector3(-8.0 + 2.5 * float(i), 0.0, 9.0)
		at.y = field.height_at(at.x, at.z)
		structures.place(BuildKinds.SAPLING if i < 2 else BuildKinds.PINE, at, 0.0)
	structures.advance_offline(Structures.MAX_OFFLINE_GROWTH)

## Every way a loss can be seen as it happens.
func _listen() -> void:
	var wallet: Wallet = _main.get("wallet")
	var inventory: Inventory = _main.get("inventory")
	var structures: Structures = _main.get("structures")
	var hud: Hud = _main.get("hud")
	var state := {"coins": wallet.coins, "owned": wallet.owned.duplicate(), "tickets": wallet.tickets}
	wallet.changed.connect(func(total: int) -> void:
		var lost: int = int(state["coins"]) - total
		state["coins"] = total
		if lost < 0:
			_earned_this_frame = true
		if lost > 0:
			_pending.append("%d coins went" % lost)
		for item: StringName in state["owned"]:
			if wallet.count_of(item) < int(state["owned"][item]):
				_pending.append("a %s was given up" % item)
		state["owned"] = wallet.owned.duplicate()
		if wallet.tickets < int(state["tickets"]):
			_pending.append("a ticket was used")
		state["tickets"] = wallet.tickets)
	var bag := {}
	for kind in ItemKinds.ALL:
		bag[kind] = inventory.count(kind)
	inventory.changed.connect(func(kind: StringName, total: int) -> void:
		if total < int(bag.get(kind, 0)):
			_pending.append("%d %s left the bag" % [int(bag.get(kind, 0)) - total, kind])
		bag[kind] = total)
	structures.removed.connect(func(kind: StringName, _at: Vector3) -> void:
		_pending.append("a %s was taken down" % kind))
	structures.placed.connect(func(_kind: StringName, _at: Vector3) -> void:
		_built_this_frame += 1)
	hud.reset_requested.connect(func() -> void:
		failures.append("[%s] the whole valley was reset by a tap (last: %s)" % [_phase, _last_tap]))
	hud.confirmed.connect(func() -> void:
		_meant = true
		_meant_log.append("%s: answered yes" % _phase))
	_attach_rings()

## Every hold ring in the interface: stepped by hand, and noted when complete.
func _attach_rings() -> void:
	for ring in _rings():
		if ring.has_meta(&"fuzzed"):
			continue
		ring.set_meta(&"fuzzed", true)
		# Not the engine's frame, which can be a second long on a loaded machine.
		ring.process_mode = Node.PROCESS_MODE_DISABLED
		ring.completed.connect(func() -> void:
			_meant = true
			_holds_completed += 1
			_meant_log.append("%s: held %s" % [_phase, _name_of(ring.get_parent() as BaseButton)]))

func _rings() -> Array[HoldRing]:
	var found: Array[HoldRing] = []
	_collect_rings(_main.get("hud") as Node, found)
	return found

func _collect_rings(node: Node, into: Array[HoldRing]) -> void:
	for child in node.get_children():
		if child is HoldRing:
			into.append(child)
		_collect_rings(child, into)

# --- places -----------------------------------------------------------------

func _enter(phase: StringName) -> void:
	_reconcile()
	_phase = String(phase)
	var hud: Hud = _main.get("hud")
	var player: Player = _main.get("player")
	var world: World = _main.get("world")
	var wallet: Wallet = _main.get("wallet")
	var build: BuildMode = _main.get("build_mode")
	_release_everything()
	hud.set_building(false)
	hud.set_shop_open(false, wallet.coins, wallet.owned)
	hud._menu.visible = false
	if player.riding != &"":
		_main.call("_on_ride")
	var camp := world.field.camp_centre()
	match phase:
		&"home", &"home_building", &"campfire":
			var at: Vector3 = report["house_origin"] + Vector3(-1.0, 0.0, 6.0)
			if phase == &"campfire":
				at = report["fire_at"] + Vector3(-1.5, 0.0, 0.0)
			await _go_to(at)
			if phase == &"home_building":
				hud.set_building(true)
		&"cafe":
			await _go_to(_a_spot_at(&"cafe", camp, Places.CAFE))
		&"fairground":
			var booth := world.park.booth_at()
			await _go_to(booth + Vector3(-1.5, 0.0, 2.2))
			# The kiosk's own question on the screen, as the ticket hold leaves it.
			_main.set("_asked", &"buy")
			hud.ask(Text.format("ask_buy_ride", [Park.RIDE_PRICE]))
		&"shop":
			await _go_to(_a_spot_at(&"shop", camp, Places.SHOP))
			hud.set_shop_open(true, wallet.coins, wallet.owned)
			hud._shop_tapped(ShopStock.BICYCLE)
		&"settings":
			await _go_to(report["house_origin"] + Vector3(-1.0, 0.0, 6.0))
			hud._menu.visible = true
			hud._danger.visible = true
	build.set_active(hud._building)
	_attach_rings()
	for _i in 6:
		await _tree.process_frame

func _a_spot_at(place: StringName, camp: Vector3, expected: StringName) -> Vector3:
	var world: World = _main.get("world")
	var centre := PlaceSpec.centre_of(place, camp)
	for ring in 12:
		for step in 8:
			var angle := TAU * float(step) / 8.0
			var at := centre + Vector3(cos(angle), 0.0, sin(angle)) * float(ring) * 1.5
			if world.places.nearest(at) == expected:
				return at
	return centre

func _go_to(at: Vector3) -> void:
	var player: Player = _main.get("player")
	var world: World = _main.get("world")
	var ground := world.field.height_at(at.x, at.z)
	player.global_position = Vector3(at.x, maxf(at.y, ground) + 1.2, at.z)
	player.velocity = Vector3.ZERO
	world.follow(player.global_position)
	await _settle_ground(900)

# --- the taps ---------------------------------------------------------------

func _tap_about(frames: int) -> void:
	var spent := 0
	while spent < frames:
		var seconds := _rng.randf_range(TAP_SECONDS.x, TAP_SECONDS.y)
		# One press in forty is a grown-up's, held until a ring completes.
		var parent := _rng.randi() % 40 == 0
		if parent:
			seconds = PARENT_HOLD_SECONDS
		var target := _pick_target()
		spent += await _press(target[0], String(target[1]), seconds, parent)

## One short tap on every button that is showing, so that no button is left to
## chance: a random run can miss a rarely offered one for a whole phase.
func _sweep() -> void:
	for button in _visible_buttons(_main.get("hud") as Hud):
		if not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled:
			continue
		await _press(
			button.get_global_rect().get_center(), "button %s" % _name_of(button),
			_rng.randf_range(TAP_SECONDS.x, TAP_SECONDS.y), false
		)

## The other half of "nothing is lost by a tap": what a hold is for must still
## work, or every check above passes merely because nothing goes through. At the
## campfire, with wood in the bag, holding the fire button must burn a log.
func _positive_control() -> void:
	var hud: Hud = _main.get("hud")
	var inventory: Inventory = _main.get("inventory")
	var fire: Button = hud._fire_button
	for _i in 6:
		await _tree.process_frame
	if not fire.is_visible_in_tree():
		failures.append("control: the fire button is not offered beside a campfire with wood in the bag")
		return
	var wood := inventory.count(ItemKinds.WOOD)
	var held := _holds_completed
	await _press(fire.get_global_rect().get_center(), "button _fire_button (held)", PARENT_HOLD_SECONDS, true)
	if _holds_completed != held + 1 or inventory.count(ItemKinds.WOOD) != wood - 1:
		failures.append("control: holding the fire button did not burn a log (wood %d -> %d)" % [
			wood, inventory.count(ItemKinds.WOOD)
		])

## A button that is showing, or a place on the screen, or the stick.
func _pick_target() -> Array:
	var hud: Hud = _main.get("hud")
	var view := _tree.root.get_visible_rect().size
	var dice := _rng.randf()
	var buttons := _visible_buttons(hud)
	if dice < 0.55 and not buttons.is_empty():
		var button: BaseButton = buttons[_rng.randi() % buttons.size()]
		var rect := button.get_global_rect()
		var at := rect.position + Vector2(
			_rng.randf_range(0.15, 0.85) * rect.size.x, _rng.randf_range(0.15, 0.85) * rect.size.y
		)
		return [at, "button %s" % _name_of(button)]
	if dice < 0.70:
		var stick: Control = hud._stick
		var rect := stick.get_global_rect()
		return [
			rect.position + Vector2(_rng.randf() * rect.size.x, _rng.randf() * rect.size.y),
			"the stick",
		]
	var at := Vector2(_rng.randf() * view.x, _rng.randf() * view.y)
	return [at, "screen %d,%d" % [int(at.x), int(at.y)]]

## What the HUD calls it (_fire_button), which is what a reader can search for;
## the engine's own name for a button made in code is a number.
func _name_of(button: BaseButton) -> String:
	var hud: Hud = _main.get("hud")
	for property in hud.get_property_list():
		var key: String = property["name"]
		if key.begins_with("_") and int(property["type"]) == TYPE_OBJECT and hud.get(key) == button:
			return key
	if not button.text.is_empty():
		return "'%s'" % button.text
	return String(button.name)

func _visible_buttons(node: Node) -> Array[BaseButton]:
	var found: Array[BaseButton] = []
	_collect_buttons(node, found)
	return found

func _collect_buttons(node: Node, into: Array[BaseButton]) -> void:
	for child in node.get_children():
		if child is BaseButton and (child as BaseButton).is_visible_in_tree() and not (child as BaseButton).disabled:
			into.append(child)
		_collect_buttons(child, into)

## Press, wait, lift: as a finger does. Returns the frames it took.
func _press(at: Vector2, what: String, seconds: float, steady: bool) -> int:
	_last_tap = what
	_recent.append(what)
	if _recent.size() > 6:
		_recent.pop_front()
	_taps += 1
	var viewport := _tree.root
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = at
	viewport.push_input(down, true)
	var frames := maxi(int(round(seconds / FRAME)), 1)
	var rings: Array[HoldRing] = []
	for ring in _rings():
		if ring.is_holding():
			rings.append(ring)
	for i in frames:
		# A finger that wanders is part of a toddler's tap, and a ring now lets go
		# of a finger that slides off its button. A hold made on purpose keeps
		# still, as a parent's thumb does, or the control could never go through.
		if what == "the stick" or (not steady and _rng.randf() < 0.1):
			var drag := InputEventScreenDrag.new()
			drag.index = 0
			drag.position = at + Vector2(_rng.randf_range(-60.0, 60.0), _rng.randf_range(-60.0, 60.0))
			drag.relative = drag.position - at
			drag.screen_relative = drag.relative
			viewport.push_input(drag, true)
		for ring in rings:
			ring._process(FRAME)
		await _next_frame()
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = at
	viewport.push_input(up, true)
	await _next_frame()
	return frames + 1

func _next_frame() -> void:
	await _tree.process_frame
	_frame += 1
	_reconcile()
	_watch_the_child()

func _release_everything() -> void:
	for index in 3:
		var up := InputEventScreenTouch.new()
		up.index = index
		up.pressed = false
		_tree.root.push_input(up, true)

## What happened since the last frame, judged: meant, or lost.
func _reconcile() -> void:
	if not _pending.is_empty() and not _meant:
		# Bag items spent on a piece just put up are building, and on an animal that
		# paid for its supper are the game's loop of care: neither is a loss.
		var wanted: Array[String] = []
		for event in _pending:
			if (_built_this_frame > 0 or _earned_this_frame) and event.ends_with("left the bag"):
				continue
			wanted.append(event)
		for event in wanted:
			failures.append("[%s] %s with no hold or answer (last tap: %s)" % [_phase, event, _last_tap])
	_pending.clear()
	_meant = false
	_built_this_frame = 0
	_earned_this_frame = false

func _watch_the_child() -> void:
	var player: Player = _main.get("player")
	var world: World = _main.get("world")
	var ground := world.field.height_at(player.global_position.x, player.global_position.z)
	if player.global_position.y < ground - 1.5 and not player.is_carried and not player.strapped_in:
		var line := "[%s] the child is under the ground (%.1f below it, after: %s)" % [
			_phase, ground - player.global_position.y, _last_tap
		]
		if not failures.has(line):
			failures.append(line)

# --- what must still be true ------------------------------------------------

func _snapshot() -> Dictionary:
	var structures: Structures = _main.get("structures")
	var world: World = _main.get("world")
	var wallet: Wallet = _main.get("wallet")
	var pieces := {}
	for entry in structures.to_data():
		var key := "%s@%.2f,%.2f,%.2f" % [entry["kind"], entry["x"], entry["y"], entry["z"]]
		pieces[key] = int(pieces.get(key, 0)) + 1
	var machines := {}
	for kind: StringName in [MountKinds.BICYCLE, MountKinds.MOTORCYCLE, MountKinds.QUAD]:
		machines[kind] = world.mounts.count_of_kind(kind)
	return {
		"pieces": pieces,
		"coins": wallet.coins,
		"owned": wallet.owned.duplicate(),
		"felled": world.felled.to_data().size(),
		"machines": machines,
	}

func _compare(before: Dictionary, after: Dictionary) -> void:
	var gone: Array[String] = []
	for key: String in before["pieces"]:
		if int((after["pieces"] as Dictionary).get(key, 0)) < int(before["pieces"][key]):
			gone.append(key)
	if not gone.is_empty():
		failures.append("built pieces or trees missing at the end: %s" % ", ".join(gone.slice(0, 6)))
	for item: StringName in before["owned"]:
		if int((after["owned"] as Dictionary).get(item, 0)) < int(before["owned"][item]):
			failures.append("%s no longer owned at the end" % item)
	if int(after["felled"]) > int(before["felled"]):
		failures.append("%d trees were felled that were standing" % (int(after["felled"]) - int(before["felled"])))
	for kind: StringName in before["machines"]:
		if int((after["machines"] as Dictionary)[kind]) < int((before["machines"] as Dictionary)[kind]):
			failures.append("a %s no longer stands in the valley" % kind)
	# Coins may have gone up (a tree grown, a day done); down only through a
	# purchase that needed a hold or an answer, and each of those is logged.
	report["coins"] = [before["coins"], after["coins"]]

## Not stuck: with the child standing on their own two feet, some direction lets
## them walk at least a stride.
func _check_can_walk(where: String) -> void:
	var player: Player = _main.get("player")
	if player.riding != &"":
		_main.call("_on_ride")
	for _i in 3:
		await _tree.physics_frame
	if player.strapped_in or player.is_carried:
		return
	var start := player.global_position
	var best := 0.0
	var tried: Array[String] = []
	for action: StringName in [
		InputActions.MOVE_FORWARD, InputActions.MOVE_BACK, InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT,
	]:
		var from := player.global_position
		Input.action_press(action, 1.0)
		# Physics ticks, not rendered frames: on a quick machine a frame is a
		# millisecond and two dozen of them are not one tick of walking.
		for _i in 30:
			await _tree.physics_frame
		Input.action_release(action)
		var moved := Vector2(player.global_position.x - from.x, player.global_position.z - from.z).length()
		tried.append("%s %.2f m" % [action, moved])
		best = maxf(best, moved)
		if best > 1.0:
			break
	if best < 0.5:
		var ground := (_main.get("world") as World).field.height_at(start.x, start.z)
		failures.append(
			"the child is stuck at %s: no direction moved them half a metre (at %v, ground %.1f, physics %s, waiting for ground %s, on floor %s, seat '%s', riding '%s', velocity %v; tried %s; last taps %s; touching %s)" % [
				where, start, ground, player.is_physics_processing(),
				_main.get("_waiting_for_ground"), player.is_on_floor(),
				player.seat_pose, player.riding, player.velocity, ", ".join(tried), " | ".join(_recent), _touching(player),
			]
		)

## What the child's body is pressed against, for the trace of a stuck child.
func _touching(player: Player) -> String:
	var names: Array[String] = []
	for i in player.get_slide_collision_count():
		var collider := player.get_slide_collision(i).get_collider() as Node
		names.append(String(collider.name) if collider != null else "?")
	return ",".join(names)
