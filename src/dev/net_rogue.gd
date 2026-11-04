extends SceneTree

## Real sockets, real processes, and a phone that does not behave: the checks
## that cannot be run inside one process, because what is being tested is what
## the engine's own multiplayer hands to the game's handlers.
##
##   godot --headless --script src/dev/net_rogue.gd -- --role=host --mode=attack --port=N
##   godot --headless --script src/dev/net_rogue.gd -- --role=host --mode=meter  --port=N
##
## `attack`: the host is joined by a phone that never says hello (and sends
## rpcs all the same) and by one that does and then floods it with garbage and
## with the host's own messages. The host must hear none of the garbage, must
## drop the one that did not say hello, and must be up and answering at the end.
##
## `meter`: one honest guest does each of the game's chatty things in turn, and
## each side prints, and holds itself to, how many bytes a second it sent and
## received while it did.
##
## Each process prints lines starting "NETROGUE" and ends with
## "NETROGUE <role> ok" or "NETROGUE <role> FAILED: ...".

class Rogue:
	extends Session
	## A phone of an older game, or somebody's laptop: it says no hello.
	var mute := false

	func _send_hello(id: int) -> void:
		if not mute:
			super._send_hello(id)

const LIMIT := 70.0
const PHASE := 2.5
## What each phase of the meter may cost the side that does the talking, in
## bytes a second both ways. Generous: a limit that has to be raised every time
## the weather changes is one that gets deleted.
const BUDGET := {
	"idle": 400.0, "walk": 1500.0, "build": 1500.0, "ball": 4500.0,
	"animals": 5000.0, "rides": 1500.0,
}
var _result := "user://netrogue_%d_%s.txt"
var _role := "host"
var _mode := "attack"
var _name := ""
var _port := 0
var _session: Rogue
var _pids: Array[int] = []
var _time := 0.0
var _failed := ""
var _agreed_at := -1.0
var _heard: Dictionary = {}
var _positions_ok := true
var _joined_ids: Array[int] = []
var _gone_ids: Array[int] = []
var _flooded := false
var _last_join := 0.0
var _last_phase := ""
var _marks: Dictionary = {}

func _initialize() -> void:
	Engine.max_fps = 60
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			_role = argument.trim_prefix("--role=")
		if argument.begins_with("--mode="):
			_mode = argument.trim_prefix("--mode=")
		if argument.begins_with("--port="):
			_port = argument.trim_prefix("--port=").to_int()
	_name = "%s-%s" % [_role, _mode]
	_session = Rogue.new()
	_session.port_override = _port
	_session.mute = _role == "mute"
	root.add_child(_session)
	for signal_name: StringName in [
		&"remote_built", &"remote_removed", &"remote_felled", &"remote_meal",
		&"remote_dam_stick", &"remote_time_of_day", &"remote_valley", &"remote_shared",
		&"remote_picked", &"pick_refused", &"remote_parked", &"remote_animals",
		&"remote_balls", &"remote_football_scores", &"remote_kick", &"remote_new_game",
		&"remote_ride_state", &"remote_ride_seat", &"remote_ride_flags", &"remote_ride_ask",
		&"remote_turnstile",
	]:
		_session.connect(signal_name, _count.bind(signal_name))
	_session.remote_built.connect(func(
		_kind: StringName, at: Vector3, spin: float, _extent: Vector2i, _material: StringName
	) -> void:
		if not Session.believable(at) or not is_finite(spin):
			_positions_ok = false)
	_session.guest_moved.connect(func(_id: int, at: Vector3, facing: float, _mount: StringName) -> void:
		if not Session.believable(at) or not is_finite(facing):
			_positions_ok = false)
	_session.peer_agreed.connect(func(_id: int) -> void:
		if _agreed_at < 0.0:
			_agreed_at = _time)
	_session.failed.connect(func(reason: String) -> void: print("NETROGUE %s: session failed: %s" % [_name, reason]))
	print("NETROGUE %s started" % _name)

func _count(...args: Array) -> void:
	var which: StringName = args[args.size() - 1]
	_heard[which] = int(_heard.get(which, 0)) + 1

func _fail(why: String) -> void:
	if _failed.is_empty():
		_failed = why

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("NETROGUE %s ok: %s" % [_name, message])
	else:
		print("NETROGUE %s FAIL: %s" % [_name, message])
		_fail(message)

func _connect() -> void:
	if _role == "host":
		if not _session.host("Host"):
			_fail("could not host")
			return
		for role in _expected_guests():
			var pid := OS.create_process(OS.get_executable_path(), [
				"--headless", "--path", ProjectSettings.globalize_path("res://"),
				"--script", "res://src/dev/net_rogue.gd", "--",
				"--role=%s" % role, "--mode=%s" % _mode, "--port=%d" % _port,
			])
			_pids.append(pid)
		_session.multiplayer.peer_connected.connect(func(id: int) -> void:
			_joined_ids.append(id)
			_last_join = _time)
		_session.multiplayer.peer_disconnected.connect(func(id: int) -> void: _gone_ids.append(id))
	else:
		_session.join("127.0.0.1", _role.capitalize())

func _process(delta: float) -> bool:
	if _time == 0.0:
		_connect()
	_time += delta
	if _time > LIMIT:
		_fail("timed out")
	if not _failed.is_empty():
		return _finish()
	match _mode:
		"attack":
			return _host_attack(delta) if _role == "host" else _guest_attack()
		_:
			return _meter()

func _finish() -> bool:
	var verdict := "NETROGUE %s ok" % _name if _failed.is_empty() else "NETROGUE %s FAILED: %s" % [_name, _failed]
	print(verdict)
	if _role != "host":
		var file := FileAccess.open(_result % [_port, _role], FileAccess.WRITE)
		file.store_string(verdict)
		file.close()
	else:
		# The door is shut first: a guest that stays until it is shown out would
		# otherwise be waited for for ever.
		_session.close()
		var waited := 0.0
		for role in _expected_guests():
			var path := _result % [_port, role]
			while not FileAccess.file_exists(path) and waited < 15.0:
				OS.delay_msec(200)
				waited += 0.2
			var said := "no word from the %s" % role
			if FileAccess.file_exists(path):
				said = FileAccess.get_file_as_string(path)
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			print(said)
			if not said.ends_with(" ok") and _failed.is_empty():
				_failed = "%s: %s" % [role, said]
		for pid in _pids:
			OS.kill(pid)
	_session.close()
	quit(0 if _failed.is_empty() else 1)
	return true

func _expected_guests() -> Array[String]:
	var out: Array[String] = []
	if _mode == "attack":
		out.append("mute")
		out.append("flood")
	else:
		out.append("meter")
	return out

# --- attack -------------------------------------------------------------------

func _host_attack(_delta: float) -> bool:
	# Long enough for the mute one to be given up on (HELLO_PATIENCE) and for
	# the flood to have arrived and been dealt with.
	if _joined_ids.size() < 2 or _time < _last_join + Session.HELLO_PATIENCE + 4.0:
		return false
	var built := int(_heard.get(&"remote_built", 0))
	# Spent from a bucket that holds LIMITS' burst and fills for the seconds
	# the flood has had.
	var limit: Array = Session.LIMITS[&"built"]
	var most := int(float(limit[0]) + float(limit[1]) * _time) + 2
	_expect(built > 0, "the flood reached the host")
	_expect(built <= most, "no more than %d builds are taken in a flood (took %d)" % [most, built])
	_expect(int(_session.dropped.get(&"built", 0)) > 0, "the rest of a flood is dropped (%d)" % int(_session.dropped.get(&"built", 0)))
	_expect(_positions_ok, "nothing that is not a place got through")
	for hostile: StringName in [
		&"remote_valley", &"remote_shared", &"remote_animals", &"remote_balls",
		&"remote_football_scores", &"pick_refused", &"remote_ride_state",
	]:
		_expect(int(_heard.get(hostile, 0)) == 0, "a guest cannot send the host %s" % hostile)
	_expect(int(_heard.get(&"remote_felled", 0)) >= 1, "an honest message after the flood is heard")
	_expect(int(_session.dropped.get(&"unwelcome", 0)) >= 10, "a phone that skipped hello is not heard (%d)" % int(_session.dropped.get(&"unwelcome", 0)))
	_expect(_joined_ids.size() == 2, "both phones connected")
	var strangers: Array[int] = []
	for id in _joined_ids:
		if not _session.guests.has(id):
			strangers.append(id)
	_expect(strangers.size() == 1 and _gone_ids.has(strangers[0]), "the phone that never said hello was let go")
	_expect(_session.guests.size() == 1, "and the one that did is still here")
	_expect(_session.is_connected_to_anyone(), "the host is still up")
	return _finish()

func _guest_attack() -> bool:
	if _role == "mute":
		return _mute_step()
	return _flood_step()

func _mute_step() -> bool:
	if _session.is_connected_to_anyone() and not _flooded and _time > 1.0:
		_flooded = true
		_marks["sent"] = _time
		for i in 40:
			_session._send_built.rpc_id(Session.HOST_ID, "wall", Vector3(float(i), 0.0, 0.0), 0.0)
			_session._send_felled.rpc_id(Session.HOST_ID, Vector3(float(i), 0.0, 0.0))
			_session._send_position.rpc_id(Session.HOST_ID, Vector3(float(i), 0.0, 0.0), 0.0)
			_session._send_name.rpc_id(Session.HOST_ID, "Mute", 0, [0, 0, 0])
		print("NETROGUE mute: sent its rpcs without a hello")
	# Gone: the host turned it away.
	if _flooded and not _session.is_connected_to_anyone() and _time > 3.0:
		return _finish()
	if _time > _marks.get("sent", _time) + Session.HELLO_PATIENCE + 8.0:
		_fail("never turned away")
	return false

func _flood_step() -> bool:
	if not _flooded:
		if _session.is_following() and _session.peer_protocol.has(Session.HOST_ID) and _time > 1.5:
			_flooded = true
			_flood()
			_marks["at"] = _time
		return false
	var waited: float = _time - float(_marks["at"])
	if waited > 2.5 and not _marks.has("honest"):
		_marks["honest"] = true
		# A bucket that is empty fills again: an honest word later is heard.
		_session._send_felled.rpc_id(Session.HOST_ID, Vector3(5.0, 0.0, 5.0))
	# Stays until the host is done and closes the door on it.
	if waited > 3.0 and not _session.is_connected_to_anyone():
		return _finish()
	return false

func _flood() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var host := Session.HOST_ID
	var s := _session
	for i in 3000:
		s._send_built.rpc_id(host, "wall", Vector3(float(i % 50), 0.0, float(i / 50)), 0.0)
	var bad: Array[float] = [NAN, INF, -INF, 1e30, -1e30, 0.0, 20000.0, 19999.0]
	for i in 400:
		var a := Vector3(bad[rng.randi() % bad.size()], bad[rng.randi() % bad.size()], rng.randf())
		var long := "x".repeat(rng.randi_range(0, 5000))
		s._send_built.rpc_id(host, long, a, bad[rng.randi() % bad.size()], Vector2i(rng.randi_range(-9, 99999), rng.randi_range(-9, 99999)), long)
		s._send_removed.rpc_id(host, a, long)
		s._send_meal.rpc_id(host, rng.randi_range(-100, 100), a)
		s._send_felled.rpc_id(host, a)
		s._send_position.rpc_id(host, a, bad[rng.randi() % bad.size()], long, rng.randi())
		s._send_kick.rpc_id(host, rng.randi_range(-5, 99), a)
		s._send_parked.rpc_id(host, long, a, NAN)
		s._send_dam_stick.rpc_id(host, bad[rng.randi() % bad.size()])
		s._send_time_of_day.rpc_id(host, bad[rng.randi() % bad.size()])
		s._send_picked.rpc_id(host, long)
		s._send_name.rpc_id(host, long, rng.randi(), [long, NAN, [1], {}])
		s._send_ride_seat.rpc_id(host, rng.randi_range(-3, 9), a)
		s._send_ride_flags.rpc_id(host, rng.randi_range(-3, 9), rng.randi())
		s._send_ride_ask.rpc_id(host, rng.randi_range(-3, 9), rng.randi_range(-3, 9), rng.randi())
		s._send_new_game.rpc_id(host)
		s._send_turnstile.rpc_id(host)
	# What only the host may say to a guest, said to the host.
	var floats := PackedFloat32Array()
	for i in 40:
		floats.append(rng.randf())
	for i in 60:
		s._send_balls.rpc_id(host, floats)
		s._send_animals.rpc_id(host, floats)
		s._send_ride_state.rpc_id(host, 1, floats)
		s._send_ride_beat.rpc_id(host, 1, floats)
		s._send_football_scores.rpc_id(host, 5, 5, 0)
		s._send_pick_refused.rpc_id(host, "1:2:3")
		s._send_valley.rpc_id(host, [{"kind": "wall", "x": 1.0}], [[1.0, 2.0]], false)
		s._send_shared.rpc_id(host, PackedStringArray(["1:2:3"]), [], [], {})
	print("NETROGUE flood: sent the lot")

# --- meter --------------------------------------------------------------------

## The phases, in order, and which side does the talking in each.
const PHASES: Array[String] = ["idle", "walk", "build", "ball", "animals", "rides"]

func _meter() -> bool:
	if _agreed_at < 0.0:
		if _time > 12.0:
			_fail("never agreed")
		return false
	var since := _time - _agreed_at - 1.0
	if since < 0.0:
		return false
	var index := int(since / PHASE)
	if index >= PHASES.size():
		return _finish()
	var phase := PHASES[index]
	var into := since - float(index) * PHASE
	_drive(phase)
	var host := _session._peer.host if _session._peer != null else null
	if host == null:
		return false
	# A half second to settle in, then two seconds measured.
	if into >= 0.25 and not _marks.has(phase):
		_marks[phase] = true
		host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA)
		host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA)
	if into >= PHASE - 0.25 and not _marks.has(phase + "_done"):
		_marks[phase + "_done"] = true
		var window := PHASE - 0.5
		var sent := float(host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA)) / window
		var got := float(host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA)) / window
		print("NETMETER %s %s sent=%.0f recv=%.0f B/s" % [_role, phase, sent, got])
		_expect(sent + got <= float(BUDGET[phase]), "%s costs %s %.0f B/s, budget %.0f" % [phase, _role, sent + got, float(BUDGET[phase])])
	return false

var _tick := 0.0
var _beats := 0

func _drive(phase: String) -> void:
	_tick += 1.0
	var host_side := _role == "host"
	var at := Vector3(10.0 + sin(_time * 3.0) * 5.0, 0.0, 10.0 + cos(_time * 3.0) * 5.0)
	match phase:
		"walk":
			if not host_side:
				_session.report_position(at, _time, &"", 10)
		"build":
			if not host_side and int(_tick) % 12 == 0:
				_session.report_built(&"wall", Vector3(_tick, 0.0, 3.0), 0.0)
		"ball":
			if host_side:
				var states := PackedFloat32Array()
				for b in 4:
					states.append_array(PackedFloat32Array([_tick * 0.01, 0.1, 3.0, 4.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0]))
				if int(_tick) % 5 == 0:
					_session.report_balls(states)
		"animals":
			if host_side and int(_tick) % 24 == 0:
				var states := PackedFloat32Array()
				for a in 60:
					states.append_array(PackedFloat32Array([float(a), float(a), _tick * 0.01, float(a)]))
				_session.report_animals(states)
		"rides":
			if host_side:
				var state := PackedFloat32Array([1.0, _tick * 0.01, 0.0, 0.0, 0.0])
				if int(_tick) % 60 == 0:
					for ride in Session.RIDE_COUNT:
						_session.report_ride_state(ride, state, false)
				if int(_tick) % 12 == 0:
					_session.report_ride_state(int(_tick / 12.0) % Session.RIDE_COUNT, state, true)
