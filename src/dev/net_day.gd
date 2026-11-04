class_name NetDay
extends Node

## A long scripted session of two children, one phone each, in two real Godot
## processes over localhost: the whole game (main.tscn) on each, a host and a
## guest. Started by net_pair.gd with `--mode=day`; see there for how to run it.
##
## Both run the same script, each doing its own part of every phase, and meet at
## a barrier at the end of each: each writes down what it sees (a small JSON
## file in user://), reads what the other wrote, and the two are compared. Every
## divergence, engine error and rpc the limits refused is logged as a line
## starting "NETDAY DIVERGE", "NETDAY WARN" or "NETDAY THROTTLED"; the verdict is
## the last line, "NETDAY <role> ok" or "NETDAY <role> FAILED: ...".

const SEED := 20260903
## Wall-clock ceiling for any single wait, and for the whole run. Game time at
## --fixed-fps runs as fast as the machine allows, so it is no measure of how
## long a peer has had to start.
const WAIT_LIMIT_MSEC := 240000

var role := "host"
var port := 29500
var tree: SceneTree
var dir := ""
var game: Node
var session: Session
var world: World
var player: Player
var hud: Hud
var wallet: Wallet
var inventory: Inventory
var structures: Structures
var visitors: Visitors

var diverged: Array[String] = []
var phases_done := 0
var _started := 0
var _frames := 0
var _stamp := 0
var _last_tick := 0
const FRAME_USEC := 16667
var _log_file: FileAccess

func _init(the_tree: SceneTree, the_role: String, the_port: int, the_stamp: int) -> void:
	tree = the_tree
	role = the_role
	port = the_port
	_stamp = the_stamp
	dir = "user://netday_%d_%d" % [port, the_stamp]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))

func say(line: String) -> void:
	var stamped := "NETDAY %s [%d f] %s" % [role, _frames, line]
	print(stamped)

func diverge(what: String) -> void:
	diverged.append(what)
	say("DIVERGE " + what)

# --- frames and waiting --------------------------------------------------------

## One frame, held to the pace of a real phone: --fixed-fps lets a machine run a
## game faster than the wall clock, which would make the two processes disagree
## about how long a second is, and make the rate limits (which count wall time)
## see traffic no phone ever sends.
func tick() -> void:
	await tree.physics_frame
	_frames += 1
	var want := _last_tick + FRAME_USEC
	var now := Time.get_ticks_usec()
	if now < want:
		OS.delay_usec(want - now)
		now = want
	_last_tick = now

func frames(count: int) -> void:
	for _i in count:
		await tick()

## Frames until `done` is true, at most `limit`. Returns whether it became true.
func until(done: Callable, limit: int) -> bool:
	for _i in limit:
		if bool(done.call()):
			return true
		await tick()
	return bool(done.call())

func _wall_over() -> bool:
	return Time.get_ticks_msec() - _started > WAIT_LIMIT_MSEC * 4

# --- the barrier ---------------------------------------------------------------

func _path_of(who: String, tag: String) -> String:
	return "%s/%s_%s.json" % [dir, who, tag]

## Write what this side sees, wait for the other side's, return it. Frames keep
## running while waiting, so the network does too.
func barrier(tag: String, mine: Dictionary) -> Dictionary:
	var file := FileAccess.open(_path_of(role, tag), FileAccess.WRITE)
	file.store_string(JSON.stringify(mine))
	file.close()
	var other := "guest" if role == "host" else "host"
	var path := _path_of(other, tag)
	var began := Time.get_ticks_msec()
	while not FileAccess.file_exists(path):
		await tick()
		if Time.get_ticks_msec() - began > WAIT_LIMIT_MSEC:
			diverge("barrier %s: the %s never arrived" % [tag, other])
			return {}
	# Let the writer finish.
	await frames(2)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

# --- boot ----------------------------------------------------------------------

func boot() -> bool:
	_started = Time.get_ticks_msec()
	var main_script: GDScript = load("res://src/main.gd")
	main_script.set("forced_seed", SEED)
	var fresh: Node = (load("res://main.tscn") as PackedScene).instantiate()
	tree.root.add_child(fresh)
	# The game's own scene, as it is when played: leaving a visit reloads it.
	tree.current_scene = fresh
	return await adopt(fresh)

## Take hold of a freshly started game: wait for it, and learn its parts.
func adopt(fresh: Node) -> bool:
	game = fresh
	var ready := await until(func() -> bool: return is_instance_valid(game) and game.get("hud") != null and game.get("_world_ready") == true, 3000)
	if not ready:
		say("FAILED the game never became ready")
		return false
	session = game.get("session")
	session.port_override = port
	world = game.get("world")
	player = game.get("player")
	hud = game.get("hud")
	wallet = game.get("wallet")
	inventory = game.get("inventory")
	structures = game.get("structures")
	visitors = game.get("visitors")
	var idle := await until(func() -> bool: return world.terrain.is_idle(), 900)
	await frames(30)
	hear()
	say("booted (ground idle: %s)" % str(idle))
	return true

## After a visit ends the game reloads its scene: wait for the new one.
func after_reload(old_id: int) -> bool:
	var came := await until(func() -> bool: return tree.current_scene != null and tree.current_scene.get_instance_id() != old_id, 1200)
	if not came:
		say("FAILED no new scene after the reload")
		return false
	return await adopt(tree.current_scene)

func hear() -> void:
	session.remote_meal.connect(func(_dish: int, _at: Vector3) -> void: note("meal"))
	session.remote_built.connect(func(_k: StringName, _p: Vector3, _s: float, _e: Vector2i, _m: StringName) -> void: note("built"))
	session.remote_removed.connect(func(_p: Vector3, _k: StringName) -> void: note("removed"))
	session.pick_refused.connect(func(_id: String) -> void: note("pick_refused"))
	session.remote_picked.connect(func(_id: String) -> void: note("remote_picked"))
	session.failed.connect(func(reason: String) -> void: say("session failed: " + reason))

## The host opens; the guest joins, as the game's own two buttons do.
func connect_up() -> bool:
	if role == "host":
		game.call("_on_host_requested")
		var came := await until(func() -> bool: return session.has_company(), 6000)
		return came
	# What Main._on_join_requested does, for a loopback address.
	if not session.join("127.0.0.1", game.call("_display_name"), game.get("_shirt"), game.get("_look")):
		return false
	game.set("_arriving", true)
	game.set("_host_at", Vector3.INF)
	game.set("_placed", false)
	game.set("_valley_received", false)
	return await until(func() -> bool:
		return session.is_following() and not game.get("_arriving"), 6000)

# --- what a side sees ---------------------------------------------------------

func vec(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]

func unvec(a: Variant) -> Vector3:
	if a is Array and (a as Array).size() == 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.INF

## Everything this phone knows that the other phone has a view of.
func observe() -> Dictionary:
	var out: Dictionary = {}
	out["me"] = {
		"pos": vec(player.global_position),
		"name": String(game.call("_display_name")),
		"shirt": int(game.get("_shirt")),
		"look": (game.get("_look") as Array).duplicate(),
		"coins": wallet.coins,
		"tickets": wallet.tickets,
		"mount": String(player.riding),
		"aboard": String(game.get("_aboard")),
	}
	# Those the other phone draws of the other child.
	var seen: Dictionary = {}
	for id: int in visitors._visitors.keys():
		var record: Dictionary = visitors._visitors[id]
		var node: Node3D = record["node"]
		var label := ""
		for child in node.get_children():
			if child is Label3D:
				label = (child as Label3D).text
		seen[str(id)] = {
			"pos": vec(node.position), "name": label, "shirt": (record["shirt"] as Color).to_html(),
			"look": (record["look"] as Array).duplicate(), "mount": String(record.get("mount", &"")),
			"seen": bool(record["seen"]),
		}
	out["seen"] = seen
	var taken: Array = world.pickups.taken.keys()
	taken.sort()
	out["taken"] = taken
	var pieces: Array = []
	for record: Dictionary in structures._records:
		var at: Vector3 = record["position"]
		pieces.append("%s@%.1f,%.1f,%.1f" % [record["kind"], at.x, at.y, at.z])
	pieces.sort()
	out["pieces"] = pieces
	var balls: Array = []
	for ball: Ball in world.football._balls:
		balls.append(vec(ball.position))
	out["balls"] = balls
	out["score"] = [int(world.football.blue), int(world.football.red)]
	var park := world.park
	out["rides"] = {
		"tower": park.drop_tower.sync_clock(), "ship": park.pirate_ship.sync_clock(),
		"wheel": park.wheel.turned(),
		"tower_rest": park.drop_tower.at_rest(), "ship_rest": park.pirate_ship.at_rest(),
	}
	out["items"] = inventory.to_data()
	out["dropped"] = session.dropped.duplicate()
	out["spent"] = session.spent.duplicate()
	return out

# --- moving the child -----------------------------------------------------------

## Put the child down at a spot on the ground, and let the valley come up under
## them first.
func put_at(spot: Vector3) -> void:
	player.global_position = Vector3(spot.x, maxf(spot.y, world.field.height_at(spot.x, spot.z)) + 0.2, spot.z)
	player.velocity = Vector3.ZERO
	world.follow(player.global_position)
	await until(func() -> bool: return world.terrain.is_idle(), 900)
	await frames(10)

## Walk to a spot at a child's pace, a step a frame.
func walk_to(target: Vector3, speed := 6.0, limit := 3600) -> void:
	for _i in limit:
		var here := player.global_position
		var gap := target - here
		gap.y = 0.0
		if gap.length() < 0.5:
			break
		var next := here + gap.normalized() * minf(speed / 60.0, gap.length())
		next.y = maxf(world.field.height_at(next.x, next.z) + 0.15, here.y if gap.length() < 1.0 else 0.0)
		player.global_position = next
		player.velocity = Vector3.ZERO
		await frames(1)

func expect(ok: bool, what: String) -> void:
	if not ok:
		diverge(what)

# --- the checkpoint -------------------------------------------------------------

## Both sides write down what they see; each compares the other's truth with
## what it draws. `moving` is the distance two readings of a position may be
## apart when somebody is on the move or on a ride.
func checkpoint(tag: String, tolerance := 2.0) -> Dictionary:
	# Arrive, then look at the same moment: both sides stand and wait for the
	# other, and sample together half a second later.
	await barrier(tag + "_here", {})
	await frames(30)
	var mine := observe()
	var theirs := await barrier(tag, mine)
	if theirs.is_empty():
		return {}
	say("checkpoint %s" % tag)
	var other_id := "1" if role == "guest" else ""
	var seen: Dictionary = {}
	for id: String in (mine["seen"] as Dictionary):
		if other_id.is_empty() or id == other_id:
			seen = mine["seen"][id]
	if seen.is_empty():
		diverge("%s: I draw nobody at all" % tag)
	else:
		var truth: Dictionary = theirs["me"]
		var gap := unvec(seen["pos"]).distance_to(unvec(truth["pos"]))
		if gap > tolerance:
			diverge("%s: the other child stands %.1f m from where I draw them (truth %s, drawn %s)" % [tag, gap, str(truth["pos"]), str(seen["pos"])])
		if String(seen["name"]) != String(truth["name"]):
			diverge("%s: I draw the name '%s', they are '%s'" % [tag, seen["name"], truth["name"]])
		var wanted_shirt := visitors.shirt_for(1 if role == "guest" else int(mine["seen"].keys()[0]), int(truth["shirt"])).to_html()
		if String(seen["shirt"]) != wanted_shirt:
			diverge("%s: the shirt I draw is %s, theirs says %s" % [tag, seen["shirt"], wanted_shirt])
		if Character.clean(seen["look"]) != Character.clean(truth["look"]):
			diverge("%s: the look I draw is %s, theirs is %s" % [tag, str(seen["look"]), str(truth["look"])])
		if String(seen["mount"]) != String(truth["mount"]):
			diverge("%s: I draw them on '%s', they are on '%s'" % [tag, seen["mount"], truth["mount"]])
	if (mine["taken"] as Array) != (theirs["taken"] as Array):
		diverge("%s: pickups taken differ (%d here, %d there)" % [tag, (mine["taken"] as Array).size(), (theirs["taken"] as Array).size()])
	if (mine["pieces"] as Array) != (theirs["pieces"] as Array):
		diverge("%s: built pieces differ (%d here, %d there)" % [tag, (mine["pieces"] as Array).size(), (theirs["pieces"] as Array).size()])
	if int(mine["score"][0]) != int(theirs["score"][0]) or int(mine["score"][1]) != int(theirs["score"][1]):
		diverge("%s: the score differs (%s here, %s there)" % [tag, str(mine["score"]), str(theirs["score"])])
	var mine_balls: Array = mine["balls"]
	var their_balls: Array = theirs["balls"]
	if mine_balls.size() != their_balls.size():
		diverge("%s: %d balls here, %d there" % [tag, mine_balls.size(), their_balls.size()])
	else:
		for i in mine_balls.size():
			var gap := unvec(mine_balls[i]).distance_to(unvec(their_balls[i]))
			if gap > 2.5:
				diverge("%s: ball %d is %.1f m apart" % [tag, i, gap])
	var gaps := {
		"tower": absf(wrapf(float(mine["rides"]["tower"]) - float(theirs["rides"]["tower"]) + DropTower.SYNC_LOOP * 0.5, 0.0, DropTower.SYNC_LOOP) - DropTower.SYNC_LOOP * 0.5),
		"ship": absf(wrapf(float(mine["rides"]["ship"]) - float(theirs["rides"]["ship"]) + PirateShip.SYNC_LOOP * 0.5, 0.0, PirateShip.SYNC_LOOP) - PirateShip.SYNC_LOOP * 0.5),
	}
	# A ride at rest holds its clock where its rider or its wait puts it (a held
	# boat sits HELD_LEAD behind the clock a following one keeps), so only
	# rides that are running are measured.
	var tower_runs := not bool(mine["rides"]["tower_rest"]) and not bool(theirs["rides"]["tower_rest"])
	var ship_runs := not bool(mine["rides"]["ship_rest"]) and not bool(theirs["rides"]["ship_rest"])
	if (tower_runs and float(gaps["tower"]) > 1.5) or (ship_runs and float(gaps["ship"]) > 1.5):
		diverge("%s: ride clocks are apart (tower %.2f s, ship %.2f s)" % [tag, gaps["tower"], gaps["ship"]])
	for kind: String in (mine["dropped"] as Dictionary):
		if kind != "unwelcome":
			say("THROTTLED %s: %d %s dropped so far" % [tag, int(mine["dropped"][kind]), kind])
	phases_done += 1
	return theirs

# --- the day --------------------------------------------------------------------

## How much game time the whole session is to cover, at least, in minutes.
var minutes := 10.0
var _meals_heard := 0
var _heard: Dictionary = {}

func note(kind: String) -> void:
	_heard[kind] = int(_heard.get(kind, 0)) + 1

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--minutes="):
			minutes = argument.trim_prefix("--minutes=").to_float()
	if not await boot():
		finish("the game did not boot")
		return
	if not await connect_up():
		finish("could not connect")
		return
	# What the day needs in the bag, the same on both sides.
	wallet.tickets = 40
	wallet.earn(900)
	inventory.add(&"stick", 60)
	inventory.add(&"stone", 10)
	await frames(60 * 6)
	await checkpoint("joined", 3.0)
	await phase_walk()
	await phase_rides()
	await phase_horse()
	await phase_pickups()
	await phase_shop_and_cafe()
	await phase_build()
	await phase_football()
	await phase_identity()
	await phase_leave_and_rejoin()
	await phase_freeze()
	await phase_chatter()
	await phase_host_quits_on_a_ride()
	finish("")

func far_from(spot: Vector3, near_by: float) -> Vector3:
	return spot + Vector3(near_by, 0.0, 0.0)

func phase_walk() -> void:
	say("== walk")
	var shop := world.places.position_of(Places.SHOP)
	var cafe := world.places.position_of(Places.CAFE)
	# Far places are reached by being put down a stone's throw from them: the
	# valley is hundreds of metres across and a walk there is no test of this.
	if role == "host":
		await put_at(shop + Vector3(0.0, 0.0, 40.0))
		await walk_to(shop + Vector3(0.0, 0.0, 14.0))
	else:
		await put_at(cafe + Vector3(0.0, 0.0, 40.0))
		await walk_to(cafe + Vector3(0.0, 0.0, 14.0))
	await checkpoint("walked", 3.0)

func board_ride(ride: StringName, seat: int) -> bool:
	var park := world.park
	var ride_node: Node = park.drop_tower if ride == &"drop_tower" else park.pirate_ship
	# At rest, early in its wait: a ride that is about to go is not boarded.
	await until(func() -> bool: return ride_node.at_rest() and float(ride_node._phase_time) < 1.0, 6000)
	var seats: Array[Transform3D] = ride_node.seats()
	var at := seats[seat % seats.size()].origin
	player.global_position = Vector3(at.x, maxf(at.y, world.field.height_at(at.x, at.z)) + 0.1, at.z)
	player.velocity = Vector3.ZERO
	world.follow(player.global_position)
	await until(func() -> bool: return world.terrain.is_idle(), 900)
	await frames(20)
	game.set("_asked", &"ride")
	game.set("_asked_ride", ride)
	game.call("_on_answered", true)
	return await until(func() -> bool: return player.strapped_in, 3000)

func ride_to_the_end(limit := 6000) -> bool:
	return await until(func() -> bool: return not player.strapped_in, limit)

func phase_rides() -> void:
	say("== rides")
	var park := world.park
	# Both on the tower, one seat each.
	await put_at(park.booth_at())
	var tickets_before := wallet.tickets
	var strapped := await board_ride(&"drop_tower", 0 if role == "host" else 1)
	expect(strapped, "the tower never strapped the %s in" % role)
	# Midway up, both are in the air and each draws the other there.
	await until(func() -> bool: return park.drop_tower.ring_height() > DropTower.GROUND_Y + 15.0, 3000)
	await checkpoint("tower together", 6.0)
	await ride_to_the_end()
	expect(wallet.tickets == tickets_before - 1, "a ticket per ride: %d -> %d" % [tickets_before, wallet.tickets])
	await frames(120)
	# Different rides: the host goes on the ship, the guest on the tower.
	tickets_before = wallet.tickets
	if role == "host":
		strapped = await board_ride(&"pirate_ship", 0)
	else:
		strapped = await board_ride(&"drop_tower", 0)
	expect(strapped, "the ride never strapped the %s in (different rides)" % role)
	await frames(60 * 12)
	await checkpoint("different rides", 8.0)
	await ride_to_the_end()
	await frames(120)
	await put_at(park.booth_at())
	await checkpoint("rides over", 3.0)

func phase_horse() -> void:
	say("== horse")
	var horse := &""
	for id: StringName in world.mounts._nodes.keys():
		if MountKinds.kind_of(id) == MountKinds.HORSE and world.mounts.exists(id):
			horse = id
			break
	if horse == &"":
		say("WARN no horse in the valley")
		return
	var at: Vector3 = world.mounts.position_of(horse)
	say("horse %s at %s" % [horse, str(at)])
	# The guest is set beside where the host will be.
	await put_at(at + Vector3(2.0 if role == "host" else 4.0, 0.0, 0.0))
	await checkpoint("at the horse", 3.0)
	if role == "host":
		hud.ride_pressed.emit()
		expect(player.riding == horse or player.riding != &"", "the host did not mount")
		await frames(30)
		for leg: Vector3 in [Vector3(30, 0, 0), Vector3(30, 0, 30), Vector3(0, 0, 30), Vector3(0, 0, 0)]:
			await walk_to(at + leg, 9.0, 600)
	else:
		for leg: Vector3 in [Vector3(30, 0, 0), Vector3(30, 0, 30), Vector3(0, 0, 30), Vector3(0, 0, 0)]:
			await walk_to(at + leg + Vector3(2.5, 0.0, 0.0), 6.0, 900)
	await checkpoint("riding and walking beside", 6.0)
	if role == "host":
		hud.ride_pressed.emit()
		await frames(60)
	await checkpoint("horse got off", 3.0)

## What the other side says about itself, at a moment both choose.
func exchange(tag: String, mine: Dictionary) -> Dictionary:
	await barrier(tag + "_here", {})
	return await barrier(tag, mine)

func item_total() -> int:
	var total := 0
	for kind: String in inventory.to_data():
		total += int(inventory.to_data()[kind])
	return total

func phase_pickups() -> void:
	say("== pickups")
	var park_side := world.park.booth_at() + Vector3(0.0, 0.0, 90.0)
	await put_at(park_side)
	await until(func() -> bool: return world.pickups.is_idle(), 900)
	await frames(60)
	var records: Array[Dictionary] = []
	for record: Dictionary in world.pickups._active:
		records.append(record)
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["id"]) < String(b["id"]))
	# The first with company: a cluster to share out.
	var cluster: Array[Dictionary] = []
	for record: Dictionary in records:
		var near: Array[Dictionary] = []
		for other: Dictionary in records:
			if (other["position"] as Vector3).distance_to(record["position"]) < 14.0:
				near.append(other)
		if near.size() >= 8:
			cluster = near
			break
	if cluster.size() < 8:
		say("WARN no cluster of pickups here (%d around)" % records.size())
		return
	cluster = cluster.slice(0, 10)
	var ids: Array[String] = []
	for record: Dictionary in cluster:
		ids.append(String(record["id"]))
	say("sharing out %d pickups starting at %s" % [cluster.size(), ids[0]])
	var taken_before := world.pickups.taken.size()
	var items_before := item_total()
	var theirs := await exchange("pickups ready", {"ids": ids})
	if theirs.has("ids") and theirs["ids"] != ids:
		diverge("the two phones see different pickups here: %s vs %s" % [str(ids), str(theirs["ids"])])
	# The same one at the same moment: both put down on it after a shared beat.
	await barrier("pickups_same_here", {})
	var shared_at: Vector3 = cluster[0]["position"]
	player.global_position = shared_at + Vector3(0.0, 0.3, 0.0)
	player.velocity = Vector3.ZERO
	await frames(180)
	# Then the rest, from opposite ends, meeting in the middle.
	var order: Array[int] = []
	if role == "host":
		for i in range(1, 7):
			order.append(i)
	else:
		for i in range(cluster.size() - 1, 3, -1):
			order.append(i)
	for i: int in order:
		await walk_to(cluster[i]["position"], 7.0, 600)
		await frames(10)
	await frames(120)
	var mine := {"gain": item_total() - items_before, "taken": world.pickups.taken.size() - taken_before}
	var other := await exchange("pickups gain", mine)
	var union_taken := world.pickups.taken.size() - taken_before
	say("pickups: I gained %d, they gained %d, %d ids taken here (refusals heard %d)" % [mine["gain"], int(other.get("gain", -1)), union_taken, int(_heard.get("pick_refused", 0))])
	var total_gain := int(mine["gain"]) + int(other.get("gain", 0))
	if total_gain != union_taken:
		diverge("pickups: the two bags gained %d things between them but %d were taken from the valley" % [total_gain, union_taken])
	await checkpoint("picked up", 3.0)

func phase_shop_and_cafe() -> void:
	say("== shop and cafe")
	var shop := world.places.position_of(Places.SHOP)
	var cafe := world.places.position_of(Places.CAFE)
	await put_at(shop + Vector3(0.0, 0.0, 14.0))
	await barrier("shop_here", {})
	var coins := wallet.coins
	var spend := 0
	if role == "host":
		for item: StringName in [ShopStock.BOTTLE, ShopStock.AXE, ShopStock.CHOCOLATE]:
			hud.shop_buy.emit(item)
			spend += ShopStock.price(item)
			await frames(20)
	else:
		for item: StringName in [ShopStock.LANTERN, ShopStock.WHISTLE, ShopStock.CHOCOLATE, ShopStock.CHOCOLATE]:
			hud.shop_buy.emit(item)
			spend += ShopStock.price(item)
			await frames(20)
	expect(wallet.coins == coins - spend, "shop: %d coins before, %d spent, %d left" % [coins, spend, wallet.coins])
	var other := await exchange("shop done", {"coins": wallet.coins, "spend": spend})
	say("shop: coins %d (spent %d); the other has %d" % [wallet.coins, spend, int(other.get("coins", -1))])
	await put_at(cafe + Vector3(0.0, 0.0, Places.CAFE_MID_Z + 1.0))
	expect(world.places.nearest(player.global_position) == Places.CAFE, "cafe: the child is not at the cafe (%s)" % str(world.places.nearest(player.global_position)))
	game.get("vitals").energy = 20.0
	var meals_before := int(_heard.get("meal", 0))
	var coins_before_meal := wallet.coins
	await barrier("cafe_here", {})
	hud.place_used.emit()
	await frames(240)
	expect(wallet.coins < coins_before_meal, "cafe: the meal cost nothing (%d)" % wallet.coins)
	await frames(120)
	say("cafe: ate for %d; meals heard from the other: %d" % [coins_before_meal - wallet.coins, int(_heard.get("meal", 0)) - meals_before])
	expect(int(_heard.get("meal", 0)) > meals_before, "cafe: the other child's meal never reached this phone")
	var after := await exchange("cafe done", {"coins": wallet.coins})
	await checkpoint("shop and cafe", 3.0)

func phase_build() -> void:
	say("== build")
	var base := world.park.booth_at() + Vector3(-120.0, 0.0, 120.0)
	base.y = world.field.height_at(base.x, base.z)
	await put_at(base + Vector3(0.0, 0.0, BuildMode.REACH + 8.0))
	var built_before := int(_heard.get("built", 0))
	var removed_before := int(_heard.get("removed", 0))
	await barrier("build_here", {})
	var sticks := inventory.count(&"stick")
	if role == "host":
		game.get("build_mode").set_active(true)
		game.get("build_mode").select(BuildKinds.FENCE)
		for i in 8:
			var spot := base + Vector3(float(i) * 1.5, 0.0, 0.0)
			player.global_position = Vector3(spot.x, world.field.height_at(spot.x, spot.z) + 0.2, spot.z + BuildMode.REACH)
			player.velocity = Vector3.ZERO
			game.get("camera_rig").yaw = 0.0
			game.get("build_mode").aim(player.global_position, 0.0)
			await frames(6)
			hud.build_place.emit()
			await frames(20)
		game.get("build_mode").set_active(false)
		var stood := structures._records.size()
		say("build: %d of 8 placings stood" % stood)
		expect(stood >= 4, "build: only %d pieces stand after eight placings" % stood)
		expect(inventory.count(&"stick") == sticks - 2 * stood, "build: the host's sticks %d -> %d for %d pieces" % [sticks, inventory.count(&"stick"), stood])
		await barrier("host_stood", {"n": stood})
	else:
		await walk_to(base + Vector3(5.0, 0.0, 6.0), 6.0, 600)
		var told: Dictionary = await barrier("host_stood", {})
		await frames(60)
		expect(int(_heard.get("built", 0)) - built_before == int(told.get("n", -1)), "build: %d pieces were told to the guest, the host put up %d" % [int(_heard.get("built", 0)) - built_before, int(told.get("n", -1))])
	await frames(60)
	await checkpoint("built", 3.0)
	if role == "guest":
		# The guest takes three of them down.
		for i in 3:
			var spot := base + Vector3(float(i) * 1.5, 0.0, 0.0)
			player.global_position = Vector3(spot.x, world.field.height_at(spot.x, spot.z) + 0.2, spot.z + 1.0)
			player.velocity = Vector3.ZERO
			await frames(10)
			hud.build_remove.emit()
			await frames(20)
	await frames(60)
	await checkpoint("removed", 3.0)
	if role == "host":
		expect(int(_heard.get("removed", 0)) - removed_before >= 3, "build: the host heard only %d removals" % (int(_heard.get("removed", 0)) - removed_before))

func phase_football() -> void:
	say("== football")
	var ground: FootballGround = world.football
	var centre := Pitch.centre()
	if role == "host":
		await put_at(centre + Vector3(-6.0, 0.0, 12.0))
	else:
		await put_at(centre + Vector3(2.0, 0.0, 0.0))
	await frames(120)
	await barrier("football_here", {})
	var scored := false
	var goal := Pitch.goal_centre(0)
	for round_index in 160:
		if int(ground.red) >= 1 or int(ground.blue) >= 1:
			scored = true
			break
		if role == "guest":
			var ball: Ball = ground._balls[1]
			var aim := goal - ball.position
			aim.y = 0.0
			var dir := aim.normalized()
			var foot := ball.position - dir * 0.9
			foot.y = ball.position.y - Ball.RADIUS
			player.global_position = Vector3(foot.x, foot.y + 0.1, foot.z)
			player.velocity = Vector3.ZERO
			await frames(4)
			ground.kick(ball, foot, dir, false, 1.0, 0.1, dir)
		await frames(30)
	await frames(90)
	say("football: score blue %d red %d" % [ground.blue, ground.red])
	expect(int(ground.red) >= 1 or role == "host", "football: the guest never scored")
	var other := await exchange("score", {"blue": int(ground.blue), "red": int(ground.red)})
	if other.has("red") and (int(other["red"]) < 1 and int(ground.red) < 1):
		diverge("football: nobody scored in 80 seconds")
	await frames(300)
	await checkpoint("football", 3.0)

func phase_identity() -> void:
	say("== identity")
	var new_name := "Zed%d" % (_stamp % 1000) if role == "guest" else "Ada%d" % (_stamp % 1000)
	await put_at(world.park.booth_at())
	await barrier("identity_here", {})
	if role == "guest":
		hud.language_chosen.emit(&"ru")
		await frames(30)
		hud = game.get("hud")
		expect(hud != null and is_instance_valid(hud), "identity: no interface after the language changed")
		hud.look_chosen.emit([2, 1, 1])
		await frames(10)
		hud.shirt_chosen.emit(3)
		await frames(10)
		hud.name_chosen.emit(new_name)
		await frames(30)
		hud.sound_changed.emit(40, 30, false)
		await frames(10)
		hud.language_chosen.emit(&"en")
		await frames(30)
		hud = game.get("hud")
	else:
		# Building mode kept across the rebuild of the interface.
		game.get("build_mode").set_active(true)
		hud.language_chosen.emit(&"ru")
		await frames(30)
		hud = game.get("hud")
		expect(game.get("build_mode").active, "identity: build mode was lost with the old interface")
		game.get("build_mode").set_active(false)
		hud.look_chosen.emit([1, 2, 0])
		await frames(10)
		hud.name_chosen.emit(new_name)
		await frames(30)
		hud.language_chosen.emit(&"en")
		await frames(30)
		hud = game.get("hud")
	await frames(60)
	await checkpoint("identity", 3.0)

func phase_leave_and_rejoin() -> void:
	say("== leave and rejoin")
	await barrier("leave_here", {})
	if role == "guest":
		var old_id := game.get_instance_id()
		game.call("_on_leave_requested")
		var reloaded := await after_reload(old_id)
		expect(reloaded, "the guest's game did not come home after leaving")
		await frames(120)
		await barrier("guest_away_back", {})
		# While away the host builds; the guest comes back and is shown it.
		await barrier("host_built_while_away", {})
		wallet.tickets = 40
		wallet.earn(500)
		expect(await connect_up(), "the guest could not rejoin")
	else:
		await until(func() -> bool: return not session.has_company(), 600)
		expect(visitors.count() == 0, "the host still draws %d visitors after the guest left" % visitors.count())
		expect(not session.has_company(), "the host still has company after the guest left")
		await barrier("guest_away_back", {})
		var base := world.park.booth_at() + Vector3(-120.0, 0.0, 130.0)
		game.get("build_mode").set_active(true)
		game.get("build_mode").select(BuildKinds.FENCE)
		for i in 3:
			var spot := base + Vector3(float(i) * 1.5, 0.0, 0.0)
			player.global_position = Vector3(spot.x, world.field.height_at(spot.x, spot.z) + 0.2, spot.z + BuildMode.REACH)
			player.velocity = Vector3.ZERO
			game.get("build_mode").aim(player.global_position, 0.0)
			await frames(6)
			hud.build_place.emit()
			await frames(20)
		game.get("build_mode").set_active(false)
		await barrier("host_built_while_away", {})
		await until(func() -> bool: return session.has_company(), 3000)
	await frames(300)
	await checkpoint("rejoined", 4.0)

## Each side's phone stalls for a few seconds, the other going on, and then
## everything it missed arrives at once.
func phase_freeze() -> void:
	say("== freeze")
	for who: String in ["guest", "host"]:
		await barrier("freeze_%s_here" % who, {})
		var dropped_before := session.dropped.duplicate()
		if role == who:
			OS.delay_msec(4500)
			await frames(5)
		else:
			# The other child walks about and builds meanwhile.
			var here := player.global_position
			for leg: Vector3 in [Vector3(15, 0, 0), Vector3(15, 0, 15), Vector3(0, 0, 15), Vector3(0, 0, 0)]:
				await walk_to(here + leg, 6.0, 200)
		await frames(180)
		var late: Array[String] = []
		for kind: StringName in session.dropped:
			if int(session.dropped[kind]) > int(dropped_before.get(kind, 0)) and kind != &"unwelcome":
				late.append("%s +%d" % [kind, int(session.dropped[kind]) - int(dropped_before.get(kind, 0))])
		if not late.is_empty():
			say("THROTTLED after the %s's freeze: %s" % [who, ", ".join(late)])
			diverge("a legitimate burst after the %s's stall was throttled: %s" % [who, ", ".join(late)])
		await checkpoint("after the %s froze" % who, 4.0)

## The rest of the afternoon: they wander, ride and pick up at random until
## the session has lasted as long as it was asked to.
func phase_chatter() -> void:
	say("== chatter")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + (0 if role == "host" else 1)
	# A count of rounds, not a clock: the two sides' frame counts differ, and a
	# loop that ended on one's clock would leave the other waiting at a barrier.
	var rounds := maxi(6, int(minutes * 1.2))
	for round in range(1, rounds + 1):
		var centre := Pitch.centre()
		var spot := centre + Vector3(rng.randf_range(-70.0, 70.0), 0.0, rng.randf_range(-70.0, 70.0))
		await walk_to(spot, 6.0, 1500)
		await frames(rng.randi_range(30, 200))
		if round % 3 == 0:
			await checkpoint("chatter %d" % round, 5.0)
		else:
			# Not in step: the next barrier is the same in both.
			await barrier("chatter_%d_beat" % round, {})

func phase_host_quits_on_a_ride() -> void:
	say("== host quits")
	var park := world.park
	await put_at(park.booth_at())
	await barrier("quit_here", {})
	var strapped := await board_ride(&"drop_tower", 0 if role == "host" else 1)
	expect(strapped, "quit: the %s never got strapped in" % role)
	await until(func() -> bool: return park.drop_tower.ring_height() > DropTower.GROUND_Y + 10.0, 3000)
	if role == "host":
		await barrier("quit_up", {})
		game.call("_write_save")
		say("saving and quitting while the guest is aloft")
		session.close()
		return
	await barrier("quit_up", {})
	var old_id := game.get_instance_id()
	var went := await until(func() -> bool: return not is_instance_id_valid(old_id) or tree.current_scene.get_instance_id() != old_id, 1800)
	expect(went, "quit: the guest still thinks it is in the host's valley two seconds' worth of frames after the host quit")
	var back := await after_reload(old_id)
	expect(back, "quit: the guest's game did not come home")
	await frames(600)
	expect(not player.strapped_in, "quit: the guest is still strapped to a ride after coming home")
	expect(not session.is_following(), "quit: the guest still follows a host")
	expect(not world.park.drop_tower.sync_following, "quit: the guest's tower still follows the vanished host")
	say("the guest is home, free, and its rides run on their own")

func finish(why: String) -> void:
	var verdict := "ok"
	if not why.is_empty():
		diverge(why)
	if not diverged.is_empty():
		verdict = "FAILED: %d divergences" % diverged.size()
	say("%s (%.1f game minutes)" % [verdict, float(_frames) / 3600.0])
	var file := FileAccess.open("%s/%s_verdict.txt" % [dir, role], FileAccess.WRITE)
	file.store_string("NETDAY %s %s" % [role, verdict])
	file.close()
	if role == "host":
		# The guest finishes in its own time: wait for it.
		var path := "%s/guest_verdict.txt" % dir
		var began := Time.get_ticks_msec()
		while not FileAccess.file_exists(path) and Time.get_ticks_msec() - began < 120000:
			OS.delay_msec(200)
		var said := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "NETDAY guest no word"
		print(said)
		if not said.ends_with(" ok"):
			verdict = "FAILED"
	if is_instance_valid(session):
		session.close()
	tree.quit(0 if verdict == "ok" else 1)
