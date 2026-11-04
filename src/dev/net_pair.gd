extends SceneTree

## Two real Godot processes playing football together over localhost, through the
## game's own Session and FootballGround: one hosts, one joins.
##
##   godot --headless --script src/dev/net_pair.gd -- --role=host --spawn
##
## The host starts the guest as a second process by itself (or start each by hand
## with --role=host and --role=guest). Each prints lines starting "NETPAIR" and
## ends with "NETPAIR <role> ok" or "NETPAIR <role> FAILED: ...". The host waits
## for the guest; the guest stands by a ball and kicks it by asking the host; each
## then checks what it sees: the host that the ball moved, the guest that the
## host's ball arrived where the host has it.

const LIMIT := 25.0
var GUEST_RESULT := "user://netpair_guest.txt"
var _guest_pid := 0
## A port other than the usual one, so that two runs (or two agents) do not
## meet on one: `--port=NNNNN` for the host, passed on to the guest it starts.
var _port := 0
var _park: Park
var _rides: RideSync
var _ride_messages := 0

var _role := "host"
var _session: Session
var _ground: FootballGround
var _field: HeightField
var _time := 0.0
var _stage := 0
var _stage_time := 0.0
var _failed := ""
var _ball_start := Vector3.ZERO
var _kicked_at := Vector3.ZERO
var _saw_mount := false

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			_role = argument.trim_prefix("--role=")
		if argument.begins_with("--port="):
			_port = argument.trim_prefix("--port=").to_int()
	if _port > 0:
		GUEST_RESULT = "user://netpair_guest_%d.txt" % _port
	_field = HeightField.new(20260903)
	_session = Session.new()
	_session.port_override = _port
	root.add_child(_session)
	# The rides, as the game has them: the host's are the rides.
	_park = Park.new(_field)
	root.add_child(_park)
	_rides = RideSync.new()
	_rides.attach(_session, _park)
	root.add_child(_rides)
	_session.remote_ride_state.connect(func(_ride: int, _state: PackedFloat32Array, _age: float) -> void:
		_ride_messages += 1)
	_ground = FootballGround.new(_field)
	root.add_child(_ground)
	_ground.attach(_session)
	# What the guest says it rides arrives over a real socket as an optional third
	# value, which a check in one process cannot show.
	_session.guest_moved.connect(func(_id: int, _at: Vector3, _facing: float, mount: StringName) -> void:
		if mount == &"horse:1":
			_saw_mount = true)
	_session.failed.connect(func(reason: String) -> void: print("NETPAIR %s: session failed: %s" % [_role, reason]))
	# No terrain collision in this process: a floor under the pitch.
	var centre := Pitch.centre()
	var surface := _field.height_at(centre.x, centre.z)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = TerrainSpec.LAYER_GROUND
	var slab := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80.0, 1.0, 80.0)
	slab.shape = box
	floor_body.add_child(slab)
	floor_body.position = Vector3(centre.x, surface - 0.5, centre.z)
	root.add_child(floor_body)
	print("NETPAIR %s started" % _role)

## Opening or joining waits for the first frame: the tree's multiplayer is not
## there yet while the script is still being initialised.
func _connect() -> void:
	if _role == "host":
		if not _session.host("Host"):
			_fail("could not host")
		elif OS.get_cmdline_user_args().has("--spawn"):
			# One command is enough: the host starts the guest as a second
			# process of its own, and reads its verdict from a file at the end.
			DirAccess.remove_absolute(ProjectSettings.globalize_path(GUEST_RESULT))
			_guest_pid = OS.create_process(OS.get_executable_path(), [
				"--headless", "--path", ProjectSettings.globalize_path("res://"),
				"--script", "res://src/dev/net_pair.gd", "--", "--role=guest", "--port=%d" % _port,
			])
			print("NETPAIR host: started guest process %d" % _guest_pid)
	else:
		_session.join("127.0.0.1", "Guest")

func _fail(why: String) -> void:
	if _failed.is_empty():
		_failed = why

func _next(stage: int) -> void:
	_stage = stage
	_stage_time = 0.0

func _process(delta: float) -> bool:
	if _time == 0.0:
		_connect()
	_time += delta
	_stage_time += delta
	if _time > LIMIT:
		_fail("timed out in stage %d" % _stage)
	if not _failed.is_empty():
		return _finish()
	return _host_step() if _role == "host" else _guest_step()

func _finish() -> bool:
	var verdict := "NETPAIR %s ok" % _role if _failed.is_empty() else "NETPAIR %s FAILED: %s" % [_role, _failed]
	print(verdict)
	if _role == "guest":
		var file := FileAccess.open(GUEST_RESULT, FileAccess.WRITE)
		file.store_string(verdict)
		file.close()
	elif _guest_pid > 0:
		# The guest finishes a little after the host; wait for what it said.
		var waited := 0.0
		while not FileAccess.file_exists(GUEST_RESULT) and waited < 8.0:
			OS.delay_msec(200)
			waited += 0.2
		var said := "no word from the guest"
		if FileAccess.file_exists(GUEST_RESULT):
			said = FileAccess.get_file_as_string(GUEST_RESULT)
		print(said)
		if not said.ends_with(" ok") and _failed.is_empty():
			_failed = "guest: " + said
	_session.close()
	quit(0 if _failed.is_empty() else 1)
	return true

func _centre_ball() -> Ball:
	return _ground._balls[1]

func _host_step() -> bool:
	match _stage:
		0:
			if _session.has_company():
				print("NETPAIR host: guest arrived, I am side %d" % _ground.my_side())
				if _ground.my_side() != 0:
					_fail("host is not blue with a guest")
				_ball_start = _centre_ball().position
				_next(1)
		1:
			# The guest kicks the ball by asking; wait for it to move.
			if _centre_ball().position.distance_to(_ball_start) > 3.0:
				print("NETPAIR host: the ball moved %.1f m" % _centre_ball().position.distance_to(_ball_start))
				if not _session.has_ride_company():
					_fail("the host has nobody its rides are told to (no hello agreed)")
				_next(2)
			elif _stage_time > 15.0:
				_fail("the guest's kick never moved the ball")
		2:
			# Stay up a moment so the guest can see the ball settle.
			if _stage_time > 4.0:
				if not _saw_mount:
					_fail("the guest's mount never arrived with its position")
				return _finish()
	return false

func _guest_step() -> bool:
	match _stage:
		0:
			if _session.is_following():
				print("NETPAIR guest: joined, I am side %d" % _ground.my_side())
				if _ground.my_side() != 1:
					_fail("guest is not red")
				_next(1)
		1:
			# Let the host's balls arrive, then stand beside the centre ball.
			var ball := _centre_ball()
			var foot := ball.position + Vector3(-1.0, -Ball.RADIUS, 0.0)
			_session.report_position(foot, 0.0, &"horse:1")
			if _stage_time > 2.0:
				_kicked_at = ball.position
				_ground.kick(ball, foot, Vector3.RIGHT, false, 1.0, 0.25, Vector3.RIGHT)
				print("NETPAIR guest: kicked at %s" % str(_kicked_at))
				_next(2)
		2:
			var ball := _centre_ball()
			if ball.position.distance_to(_kicked_at) > 3.0 and _stage_time > 1.0:
				print("NETPAIR guest: I see the ball %.1f m from where I kicked it" % ball.position.distance_to(_kicked_at))
				_next(3)
			elif _stage_time > 10.0:
				_fail("the host's ball never reached this phone")
		3:
			if _stage_time > 2.0:
				if not _session.can_follow_rides() or not _park.drop_tower.sync_following:
					_fail("the guest's rides do not follow the host's")
				elif _ride_messages < 3:
					_fail("only %d ride messages reached the guest" % _ride_messages)
				else:
					print("NETPAIR guest: %d ride messages, rides follow the host's" % _ride_messages)
				return _finish()
	return false
