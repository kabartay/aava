class_name Session
extends Node

## Playing in the same valley from two devices.
##
## The ground costs nothing to send. The height field is a pure function of a
## seed, so both machines generate an identical valley from the map name alone —
## no terrain, no collision, no trees ever cross the network. That is the single
## biggest thing this design gets for free, and it is why the world was built
## around a seed in the first place.
##
## What does travel is small: where the other children are standing, and the
## handful of things that change the valley — a piece built, a tree felled, a
## stick given to the beavers. Those are the contents of the world file, and
## they are sent as they happen rather than as a stream of state.
##
## Authority sits with the host, and deliberately not much of it. This is a game
## for brothers, not a competitive shooter: there is no cheating to prevent, and
## a child whose piece is refused by a distant authority because of latency has
## been told the game is broken. So a guest places its own pieces immediately
## and tells the host; the host keeps the record and passes it on. The worst a
## collision can do is put two pieces in one square, which the build rules
## already refuse locally.

signal opened(port: int)
signal joined()
signal failed(reason: String)
signal closed()

## Somebody arrived or left. `who` is the display name they chose.
signal guest_arrived(id: int, who: String, shirt: int)
signal guest_left(id: int, who: String)

## A connection ended, whether or not it ever said who it was. For whatever
## was keyed by peer id before anybody was announced — a voice, say.
signal peer_gone(id: int)

## Somebody already here changed their name or their shirt in their own
## settings. Both travel together, because both answer "who is that".
signal guest_renamed(id: int, who: String, shirt: int)

## The valley changed, on some other machine. The game applies these exactly as
## if the local child had done them.
## `extent` is how many squares a whole roof covers; one for everything else.
## `material` is what a wall is made of; the plaster look for anything else.
signal remote_built(kind: StringName, position: Vector3, spin: float, extent: Vector2i, material: StringName)
## `kind` is what was taken down, or empty from a phone that does not say.
signal remote_removed(position: Vector3, kind: StringName)
signal remote_felled(position: Vector3)
signal remote_dam_stick(site: float)
signal remote_time_of_day(fraction: float)
## The host's whole valley as it stands, told to a guest on arrival: every
## piece built (as saved) and every tree felled.
signal remote_valley(pieces: Array, stumps: Array)

## Where another child is, so they can be drawn. `mount` is the id of what they
## are riding, or empty on foot.
signal guest_moved(id: int, position: Vector3, facing: float, mount: StringName)

## How somebody is moving, as `motion_code` packs it, so that they can be drawn
## walking, running or swimming and not gliding. A signal of its own, sent just
## before guest_moved, so that what listens to that is as it was.
signal guest_moving(id: int, code: int)

## What the host's valley holds besides the things built, told to a guest on
## arrival: the pickups already taken, the dams (finished, and sticks so far)
## and where every mount stands — `{id: [x, y, z, facing]}`.
signal remote_shared(taken: PackedStringArray, built: Array, progress: Dictionary, mounts: Dictionary)
## Somebody picked something up, by the id the valley gives it.
signal remote_picked(id: String)
## A mount was left standing by somebody who got off it.
signal remote_parked(id: StringName, position: Vector3, facing: float)
## Where the host's animals are, for a guest: four numbers each — where it was
## born (which is what names it on both phones) and where it stands now.
signal remote_animals(states: PackedFloat32Array)

## The football, which is the host's. Every ball's state as the host sees it
## (see report_balls for the layout); the score, with the end a goal went into
## or -1 when nothing was scored; and, to the host only, a guest's kick and a
## guest's wish to start the game again.
signal remote_balls(states: PackedFloat32Array)
signal remote_football_scores(blue: int, red: int, goal: int)
signal remote_kick(from: int, ball: int, velocity: Vector3)
signal remote_new_game(from: int)

## A single fixed port, because the alternative is asking a six-year-old to type
## one. High enough to need no privileges, and not one anything common uses.
const PORT := 27717

## Two brothers and a friend. Small on purpose: this is a family game, and a
## smaller number means a smaller surface to get wrong.
const MAX_GUESTS := 3

## How often a position is sent. Twelve times a second is smooth enough for
## walking pace once interpolated, and a twentieth of the traffic of every
## frame.
const MOVE_INTERVAL := 1.0 / 12.0

enum Role { ALONE, HOSTING, VISITING }

var role := Role.ALONE
var who := ""

## Which shirt this child picked for themselves, as an index into the palette,
## or -1 for whoever has not picked one.
var shirt := -1

## Who this child chose to be drawn as: [character, skin, hair], see
## Character.clean. The plain figure for a child who never chose.
var look: Array = [0, 0, 0]

## Who each guest said they are, by peer id, for the guests whose version
## said so. A guest missing from here is the plain figure. Kept beside
## `guests` and not inside the arrival signal, which has three values and is
## listened to as such.
var guest_looks: Dictionary = {}

## Everyone else currently in the valley, by peer id.
var guests: Dictionary = {}

## Where each guest last said they were, for the host to judge a kick by.
var guest_positions: Dictionary = {}

## The host's peer id, which is always 1 in Godot's multiplayer.
const HOST_ID := 1

## How many floats one ball takes in a football update: where it is, how fast
## it is going, and how it is turned (a quaternion).
const BALL_FLOATS := 10
## More balls than the pitch has by a wide margin; a longer update is nonsense.
const MAX_BALLS := 8

## Another session in this same process, standing in for the network, so the
## checks can run a host and a guest back to back without a socket. Never set
## in the game itself.
var _link: Session = null
## The peer id a guest on a link has, as the host it is linked to sees it. A real
## guest has a peer id of its own; the host is always HOST_ID.
var _link_id := 2

var _peer: ENetMultiplayerPeer = null
var _since_move := 0.0
var _last_sent := Vector3(1e9, 1e9, 1e9)
var _last_facing := 0.0
var _last_mount := &""
var _last_motion := 0

## The valley as it arrives in parts, kept until the last part is in.
var _part_pieces: Array = []
var _part_stumps: Array = []

func _init() -> void:
	name = "Session"

func is_networked() -> bool:
	return role != Role.ALONE

## Connected and able to send. A guest whose join is still in flight, or has
## failed, is `is_networked()` but has nobody to talk to — sending then produced
## a "built a wall" from a game that had never joined anything.
func is_connected_to_anyone() -> bool:
	if _link != null:
		return is_networked()
	if not is_networked() or _peer == null:
		return false
	if not is_inside_tree() or multiplayer == null:
		return false
	return _peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

## Is there somebody actually in the valley with this child? A host with an open
## door and nobody through it is connected, and has no one to share anything
## with. Somebody counts once they have said who they are, which is also when
## the game draws them.
func has_company() -> bool:
	return is_connected_to_anyone() and not guests.is_empty()

func is_host() -> bool:
	return role == Role.HOSTING

## Is this child in somebody else's valley, with the connection up? Then the
## host's game is the game, and what the host says about the football is what
## is true. A join still in flight, or one that failed, does not count: that
## child is in their own valley still.
func is_following() -> bool:
	return role == Role.VISITING and is_connected_to_anyone()

## Open this valley to the other device. Returns false if the port is busy,
## which on a family network almost always means the game is already running.
func host(display_name: String, wearing := -1, looking := []) -> bool:
	if not _ready_to_connect():
		return false
	close()
	who = display_name
	shirt = wearing
	look = Character.clean(looking)
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_server(PORT, MAX_GUESTS)
	if error != OK:
		_peer = null
		failed.emit(_explain(error))
		return false

	multiplayer.multiplayer_peer = _peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	role = Role.HOSTING
	opened.emit(PORT)
	return true

## Walk into somebody else's valley.
func join(address: String, display_name: String, wearing := -1, looking := []) -> bool:
	if not _ready_to_connect():
		return false
	if address.strip_edges().is_empty():
		failed.emit("no address to join")
		return false
	close()
	who = display_name
	shirt = wearing
	look = Character.clean(looking)
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_client(address, PORT)
	if error != OK:
		_peer = null
		failed.emit(_explain(error))
		return false

	multiplayer.multiplayer_peer = _peer
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connect_failed)
	multiplayer.server_disconnected.connect(_on_host_left)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	role = Role.VISITING
	return true

## The MultiplayerAPI belongs to the scene tree, so it does not exist until this
## node is inside one. Calling host() or join() before then produced a null
## access rather than an honest failure, which is how a headless test found it
## and a child would not have.
func _ready_to_connect() -> bool:
	if not is_inside_tree() or multiplayer == null:
		failed.emit("the game is not ready to connect yet")
		return false
	return true

func close() -> void:
	_part_pieces.clear()
	_part_stumps.clear()
	if _peer != null:
		_peer.close()
		_peer = null
	if not is_inside_tree() or multiplayer == null:
		role = Role.ALONE
		guests.clear()
		guest_looks.clear()
		guest_positions.clear()
		return
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	for signal_name: StringName in [
		&"peer_connected", &"peer_disconnected", &"connected_to_server",
		&"connection_failed", &"server_disconnected",
	]:
		for connection in multiplayer.get_signal_connection_list(signal_name):
			multiplayer.disconnect(signal_name, connection["callable"])
	var was := role
	role = Role.ALONE
	guests.clear()
	guest_looks.clear()
	guest_positions.clear()
	if was != Role.ALONE:
		closed.emit()

## Every address this machine can be reached on, so a child can be told which
## one to type — or, better, so it can be shown as a number to read aloud.
static func local_addresses() -> Array[String]:
	var out: Array[String] = []
	for address in IP.get_local_addresses():
		# IPv4 on a private network only. A public address is not something to
		# put in front of a child, and IPv6 is not something to read aloud.
		if not address.contains("."):
			continue
		if address.begins_with("127."):
			continue
		# A phone with USB debugging on carries extra virtual interfaces (a
		# reverse-tether link to the computer, a not-yet-configured radio) that
		# report an address ending in .0 or .255 — the subnet and broadcast
		# addresses, never a real host. Picking one of those as "this device's
		# address" produces a code nobody can ever connect to. The Wi-Fi
		# address a family network actually needs is always a host address.
		if address.ends_with(".0") or address.ends_with(".255"):
			continue
		if (
			address.begins_with("192.168.")
			or address.begins_with("10.")
			or _is_private_172(address)
		):
			out.append(address)
	return out

## The number a child reads out, and the number the other child types in.
##
## A full address is fifteen characters of dots and digits: unreadable at six,
## and a typing task at ten. But two devices on one family network always share
## the first three parts of it — 192.168.1.x — so the only part that actually
## differs is the last number, between 1 and 254.
##
## So the host shows one number, large, and the guest types that same number.
## Three digits instead of fifteen characters, and no punctuation at all.
static func code_for(address: String) -> int:
	var parts := address.split(".")
	if parts.size() != 4:
		return 0
	return parts[3].to_int()

## Turn a code back into an address, using this machine's own network as the
## prefix — which is exactly the assumption that makes the short code work.
static func address_for_code(code: int) -> String:
	if code < 1 or code > 254:
		return ""
	for address in local_addresses():
		var parts := address.split(".")
		if parts.size() == 4:
			return "%s.%s.%s.%d" % [parts[0], parts[1], parts[2], code]
	return ""

## The code to show a child who is hosting, or 0 if this machine is not on a
## network at all — which is worth saying plainly rather than showing a zero.
static func own_code() -> int:
	var addresses := local_addresses()
	if addresses.is_empty():
		return 0
	return code_for(addresses[0])

static func _is_private_172(address: String) -> bool:
	if not address.begins_with("172."):
		return false
	var parts := address.split(".")
	if parts.size() < 2:
		return false
	var second := parts[1].to_int()
	return second >= 16 and second <= 31

func _process(delta: float) -> void:
	_since_move += delta

## Tell everyone else where this child is. Called every frame by the game; sends
## at most MOVE_INTERVAL apart, and only when they have actually moved.
##
## `mount` is what they are riding, if anything, so the other phone draws a
## child on a horse and not one running at sixteen metres a second. It is a
## third value that is only sent when there is one: a phone that has not been
## updated reads the two it has always read, and sends none.
##
## `motion` (see motion_code) is a fourth, under the same rule: zero, which is
## standing still on foot, is not sent, and a receiver that is not told reads
## it as zero. So a child who stops sends one more message to say so.
func report_position(at: Vector3, facing: float, mount := &"", motion := 0) -> void:
	if not is_connected_to_anyone() or _since_move < MOVE_INTERVAL:
		return
	# A child turning on the spot is changing what the other phone draws too,
	# and so is one getting on or off at a standstill, or starting to run.
	if (
		at.distance_squared_to(_last_sent) < 0.01
		and absf(angle_difference(facing, _last_facing)) < 0.1
		and mount == _last_mount
		and motion == _last_motion
	):
		return
	_since_move = 0.0
	_last_sent = at
	_last_facing = facing
	_last_mount = mount
	_last_motion = motion
	if motion != 0:
		_send_position.rpc(at, facing, String(mount), motion)
	elif mount == &"":
		_send_position.rpc(at, facing)
	else:
		_send_position.rpc(at, facing, String(mount))

## How a child is moving, in one small number: their speed in half metres a
## second (to 15 m/s, a motorcycle) in the low five bits, and 32 for swimming
## and 64 for diving. A child on foot at a standstill is zero.
static func motion_code(speed: float, swimming: bool, diving: bool) -> int:
	var code := clampi(int(roundf(maxf(speed, 0.0) * 2.0)), 0, 31)
	if swimming:
		code += 32
		if diving:
			code += 64
	return code

## The speed in metres a second that a code says.
static func motion_speed(code: int) -> float:
	return float(code & 31) * 0.5

## The four things that change a valley. Each is sent as it happens.
##
## A wall's edge and storey are already in its position and spin, so only a
## whole roof, which covers a room, says how big it is. Everything else is sent
## with the same three values as ever, so a phone that has not been updated
## still builds what this one built. A wall of a material that is not the old
## plaster look says what it is made of, in a fifth value; one that is plaster
## is sent as it always was.
func report_built(
	kind: StringName, at: Vector3, spin: float, extent := Vector2i.ONE,
	material := HouseParts.DEFAULT_MATERIAL
) -> void:
	if not is_connected_to_anyone():
		return
	if material != HouseParts.DEFAULT_MATERIAL:
		_send_built.rpc(String(kind), at, spin, extent, String(material))
	elif extent == Vector2i.ONE:
		_send_built.rpc(String(kind), at, spin)
	else:
		_send_built.rpc(String(kind), at, spin, extent)

## A removal says what it took down as well as where: a table and the chair
## pulled up to it stand on one spot, and a bed on the floor beneath it, so the
## place alone could take down the wrong one of the two. A phone that has not
## been updated sends and reads only the place, as it always did.
func report_removed(at: Vector3, kind := &"") -> void:
	if not is_connected_to_anyone():
		return
	if kind == &"":
		_send_removed.rpc(at)
	else:
		_send_removed.rpc(at, String(kind))

func report_felled(at: Vector3) -> void:
	if is_connected_to_anyone():
		_send_felled.rpc(at)

func report_dam_stick(site: float) -> void:
	if is_connected_to_anyone():
		_send_dam_stick.rpc(site)

## The football is the host's. The host simulates the balls and tells every
## guest where they are: for each ball in the pitch's order, its position, its
## velocity and its turn as a quaternion — BALL_FLOATS numbers. Unreliable, since
## the next update corrects a lost one a twelfth of a second later.
func report_balls(states: PackedFloat32Array) -> void:
	if role != Role.HOSTING or not is_connected_to_anyone():
		return
	if _link != null:
		_link._take_balls(HOST_ID, states)
	else:
		_send_balls.rpc(states)

## The score, and which end a goal went into (-1 for none: a new game, or the
## score told to somebody who has just arrived). Reliable, because a lost goal
## is a score that is wrong until the next one. `to_peer` is one guest, or 0 for all.
func report_football_scores(blue: int, red: int, goal := -1, to_peer := 0) -> void:
	if role != Role.HOSTING or not is_connected_to_anyone():
		return
	if _link != null:
		_link._take_football_scores(HOST_ID, blue, red, goal)
	elif to_peer == 0:
		_send_football_scores.rpc(blue, red, goal)
	else:
		_send_football_scores.rpc_id(to_peer, blue, red, goal)

## A guest asks the host to kick a ball: which one, and the launch velocity its
## own aim preview worked out. The host decides whether to believe it.
func report_kick(ball: int, velocity: Vector3) -> void:
	if not is_following():
		return
	if _link != null:
		_link._take_kick(_link_id, ball, velocity)
	else:
		_send_kick.rpc_id(HOST_ID, ball, velocity)

## A guest asks the host to start the football over.
func report_new_game() -> void:
	if not is_following():
		return
	if _link != null:
		_link._take_new_game(_link_id)
	else:
		_send_new_game.rpc_id(HOST_ID)

## This child has renamed themselves, or changed their shirt. Sent to everyone
## already here, so what is over their head changes where it is being read
## rather than at the next time somebody joins.
func report_name(display_name: String, chose: int, looking := []) -> void:
	who = display_name
	shirt = chose
	look = Character.clean(looking)
	if is_connected_to_anyone():
		_send_name.rpc(display_name, chose, look)

## The sky, which is one sky for everyone in the valley.
##
## Sent by the host to a guest the moment they arrive — a child hosting at dusk
## and a child joining at noon on their own machine's clock would otherwise each
## see a different afternoon, standing next to each other. And sent to everybody
## whenever somebody sleeps, because sleeping jumps this machine's clock to dawn
## and would put the two children back in different halves of the day. Anyone
## may send that one: a valley where only the host can bring the morning is a
## valley where the younger brother's bed does nothing.
func report_time_of_day(fraction: float, to_peer := 0) -> void:
	if not is_connected_to_anyone():
		return
	if to_peer == 0:
		_send_time_of_day.rpc(fraction)
	else:
		_send_time_of_day.rpc_id(to_peer, fraction)

## What the host has built and felled, to a guest who has just arrived. Without
## it the guest walks into the host's valley carrying their own: a house the
## host cannot see, and a forest the host has already cut down.
##
## Sent in parts, however much there is. It was one message that the other end
## threw away whole when it held more than MAX_PIECES, so a child who had
## built a great deal brought a brother into an empty valley and neither phone
## said so. A part is small enough to be a reasonable thing to refuse; the
## guest keeps them until the last says it is the last.
func report_valley(pieces: Array, stumps: Array, to_peer: int) -> void:
	if role != Role.HOSTING or not is_connected_to_anyone():
		return
	var at_piece := 0
	var at_stump := 0
	while true:
		var some_pieces := pieces.slice(at_piece, at_piece + PIECES_PER_PART)
		var some_stumps := stumps.slice(at_stump, at_stump + STUMPS_PER_PART)
		at_piece += PIECES_PER_PART
		at_stump += STUMPS_PER_PART
		var more := at_piece < pieces.size() or at_stump < stumps.size()
		if _link != null:
			_link._take_valley(HOST_ID, some_pieces, some_stumps, more)
		elif more:
			_send_valley.rpc_id(to_peer, some_pieces, some_stumps, true)
		else:
			_send_valley.rpc_id(to_peer, some_pieces, some_stumps)
		if not more:
			return

## The rest of what the host's valley holds, to a guest who has just arrived:
## which pickups are already gone, how far each dam has got, and where every
## mount stands. Without it the guest looks for sticks that are not there,
## sees a river the host has dammed running free, and finds a horse where the
## host left it an hour ago.
func report_shared(
	taken: PackedStringArray, built: Array, progress: Dictionary, mounts: Dictionary,
	to_peer: int
) -> void:
	if role != Role.HOSTING or not is_connected_to_anyone():
		return
	# Sites travel as pairs of numbers: a dictionary keyed by a float is a
	# thing only this game's own save knows how to read back.
	var sticks: Array = []
	for site: Variant in progress:
		sticks.append([float(site), int(progress[site])])
	if _link != null:
		_link._take_shared(HOST_ID, taken, built, sticks, mounts)
	else:
		_send_shared.rpc_id(to_peer, taken, built, sticks, mounts)

## Something was picked up here, and is gone for both. `id` is the one the
## valley gave it, which is the same on both phones.
func report_picked(id: String) -> void:
	if is_connected_to_anyone():
		_send_picked.rpc(id)

## A mount was got off, and left where it now stands. Its way there was told
## as its rider's position; this is where it stays.
func report_parked(id: StringName, at: Vector3, facing: float) -> void:
	if is_connected_to_anyone():
		_send_parked.rpc(String(id), at, facing)

## Where the host's animals are, for a guest. Like the football, the animals
## are the host's: each guest's own would otherwise wander off in a direction
## of its own, and two children would be feeding two different cows. Four
## numbers an animal (see `remote_animals`), unreliably, since the next
## update corrects a lost one.
func report_animals(states: PackedFloat32Array) -> void:
	if role != Role.HOSTING or not is_connected_to_anyone() or states.is_empty():
		return
	if _link != null:
		_link._take_animals(HOST_ID, states)
	else:
		_send_animals.rpc(states)

# --- what arrives ---------------------------------------------------------
#
# `call_remote` on every one of these, so a machine never applies its own
# message a second time: the local change has already happened by the time it
# is sent. `unreliable_ordered` for positions, because a dropped position is
# corrected by the next one a twelfth of a second later; `reliable` for the
# things that change the valley, because a dropped house is a lost afternoon.

## Is this a place in the valley, or something no machine running this game
## would ever send?
##
## Everything here that arrives from another phone ends up stored — a piece in
## the structures, a stump in the felled list — and from there written into the
## world's save. A NaN or an infinity in that file is a file JSON cannot read
## back, and a save that cannot be read is a valley that starts empty and is
## then overwritten. So nothing that is not a finite place within reach of the
## valley gets past this door.
const BELIEVABLE_REACH := 20000.0

static func believable(at: Vector3) -> bool:
	return (
		at.is_finite()
		and absf(at.x) < BELIEVABLE_REACH
		and absf(at.y) < BELIEVABLE_REACH
		and absf(at.z) < BELIEVABLE_REACH
	)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _send_position(at: Vector3, facing: float, mount := "", motion := 0) -> void:
	if not believable(at) or not is_finite(facing):
		return
	var from := multiplayer.get_remote_sender_id()
	guest_positions[from] = at
	# Seven bits and no more: anything else a stranger sends is not a pace.
	guest_moving.emit(from, motion & 127)
	guest_moved.emit(from, at, facing, mount_named(mount))

## What somebody says they are riding, or nothing. An id is "horse:3" or
## "bicycle:0": a kind this game has, and at most a number after it. Anything
## else is on foot, because it is drawn as a mesh and looked up in tables.
static func mount_named(text: String) -> StringName:
	if text.length() > 16:
		return &""
	var colon := text.find(":")
	var kind := text if colon < 0 else text.substr(0, colon)
	if not MountKinds.ALL.has(StringName(kind)):
		return &""
	if colon >= 0 and not text.substr(colon + 1).is_valid_int():
		return &""
	return StringName(text)

## Is this from the host? 0 is no sender at all, which is how a check calls a
## handler directly. Another guest's message relayed through the host is not
## the host's, and must not set the score.
func _from_the_host(from: int) -> bool:
	return role == Role.VISITING and (from == HOST_ID or from == 0)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _send_balls(states: PackedFloat32Array) -> void:
	_take_balls(multiplayer.get_remote_sender_id(), states)

func _take_balls(from: int, states: PackedFloat32Array) -> void:
	if not _from_the_host(from):
		return
	var count := states.size() / BALL_FLOATS
	if states.size() % BALL_FLOATS != 0 or count < 1 or count > MAX_BALLS:
		return
	# Positions, velocities and the turn alike: finite, and nowhere near the
	# edge of the world, as for any place that arrives from another phone.
	for number in states:
		if not is_finite(number) or absf(number) > BELIEVABLE_REACH:
			return
	remote_balls.emit(states)

@rpc("any_peer", "call_remote", "reliable")
func _send_football_scores(blue: int, red: int, goal: int) -> void:
	_take_football_scores(multiplayer.get_remote_sender_id(), blue, red, goal)

func _take_football_scores(from: int, blue: int, red: int, goal: int) -> void:
	if not _from_the_host(from):
		return
	if blue < 0 or red < 0 or blue > 99999 or red > 99999 or goal < -1 or goal > 1:
		return
	remote_football_scores.emit(blue, red, goal)

@rpc("any_peer", "call_remote", "reliable")
func _send_kick(ball: int, velocity: Vector3) -> void:
	_take_kick(multiplayer.get_remote_sender_id(), ball, velocity)

func _take_kick(from: int, ball: int, velocity: Vector3) -> void:
	# Only a host is asked to kick, and only by somebody who is in the valley.
	if role != Role.HOSTING or not guests.has(from):
		return
	if ball < 0 or ball >= MAX_BALLS or not believable(velocity):
		return
	remote_kick.emit(from, ball, velocity)

@rpc("any_peer", "call_remote", "reliable")
func _send_new_game() -> void:
	_take_new_game(multiplayer.get_remote_sender_id())

func _take_new_game(from: int) -> void:
	if role != Role.HOSTING or not guests.has(from):
		return
	remote_new_game.emit(from)

@rpc("any_peer", "call_remote", "reliable")
func _send_built(
	kind: String, at: Vector3, spin: float, extent := Vector2i.ONE, material := ""
) -> void:
	if not believable(at) or not is_finite(spin):
		return
	# A room no bigger than one tap of the roof could ever cover here.
	if (
		extent.x < 1 or extent.y < 1
		or extent.x > HouseParts.ROOM_LONGEST or extent.y > HouseParts.ROOM_LONGEST
	):
		return
	# Whatever arrives as a material is one of ours or it is plaster.
	remote_built.emit(StringName(kind), at, spin, extent, HouseParts.material_from(material))

@rpc("any_peer", "call_remote", "reliable")
func _send_removed(at: Vector3, kind := "") -> void:
	if not believable(at):
		return
	remote_removed.emit(at, StringName(kind))

@rpc("any_peer", "call_remote", "reliable")
func _send_felled(at: Vector3) -> void:
	if not believable(at):
		return
	remote_felled.emit(at)

## More pieces in one message than anybody builds in an afternoon; a longer
## list is nonsense. A phone that has not been updated sends the whole valley
## in one, so this stays what it was.
const MAX_PIECES := 20000
## And more stumps than a forest has trees near enough to fell.
const MAX_STUMPS := 40000
## How much goes in one part of a valley sent in parts.
const PIECES_PER_PART := 500
const STUMPS_PER_PART := 2000
## What a whole valley may come to over all its parts. Far beyond any child's
## building, and there only so that a peer that never says "last" cannot make
## this phone keep everything it is sent.
const MAX_PIECES_IN_ALL := 400000
const MAX_STUMPS_IN_ALL := 800000

@rpc("any_peer", "call_remote", "reliable")
func _send_valley(pieces: Array, stumps: Array, more := false) -> void:
	_take_valley(multiplayer.get_remote_sender_id(), pieces, stumps, more)

func _take_valley(from: int, pieces: Array, stumps: Array, more := false) -> void:
	if not _from_the_host(from):
		return
	if pieces.size() > MAX_PIECES or stumps.size() > MAX_STUMPS:
		return
	# Rebuilt rather than passed on: a piece is read with
	# `Vector3(entry.get("x"), ...)`, which is a crash for anything that is not
	# a number, and a stump likewise.
	var clean_pieces: Array = []
	for entry: Variant in pieces:
		if typeof(entry) != TYPE_DICTIONARY or typeof(entry.get("kind")) != TYPE_STRING:
			continue
		var piece := {"kind": entry["kind"]}
		var good := true
		for key: String in ["x", "y", "z", "spin", "age", "across", "along"]:
			if not entry.has(key):
				continue
			var number: Variant = entry[key]
			if (
				(typeof(number) != TYPE_FLOAT and typeof(number) != TYPE_INT)
				or not is_finite(float(number)) or absf(float(number)) > BELIEVABLE_REACH
			):
				good = false
				break
			piece[key] = number
		if not good:
			continue
		if typeof(entry.get("material")) == TYPE_STRING:
			piece["material"] = entry["material"]
		clean_pieces.append(piece)
	var clean_stumps: Array = []
	for entry: Variant in stumps:
		if typeof(entry) != TYPE_ARRAY or entry.size() < 2:
			continue
		var x: Variant = entry[0]
		var z: Variant = entry[1]
		if typeof(x) != TYPE_FLOAT or typeof(z) != TYPE_FLOAT:
			continue
		if not is_finite(x) or not is_finite(z) or absf(x) > BELIEVABLE_REACH or absf(z) > BELIEVABLE_REACH:
			continue
		clean_stumps.append(entry.slice(0, 3))
	_part_pieces.append_array(clean_pieces)
	_part_stumps.append_array(clean_stumps)
	if _part_pieces.size() > MAX_PIECES_IN_ALL or _part_stumps.size() > MAX_STUMPS_IN_ALL:
		# Said, and the visit given up: a guest told nothing and left in a valley
		# of only half of what the host has is the silent failure this replaced.
		close()
		failed.emit("the valley is too big to bring")
		return
	if more:
		return
	var whole_pieces := _part_pieces
	var whole_stumps := _part_stumps
	_part_pieces = []
	_part_stumps = []
	remote_valley.emit(whole_pieces, whole_stumps)

## More pickups taken than a long afternoon's walking; a longer list is nonsense.
const MAX_TAKEN := 500000
## More animals in one update than a handful of tiles hold.
const MAX_ANIMALS := Animals.MAX_TOLD
const ANIMAL_FLOATS := Animals.STATE_FLOATS

@rpc("any_peer", "call_remote", "reliable")
func _send_shared(
	taken: PackedStringArray, built: Array, progress: Array, mounts: Dictionary
) -> void:
	_take_shared(multiplayer.get_remote_sender_id(), taken, built, progress, mounts)

func _take_shared(
	from: int, taken: PackedStringArray, built: Array, progress: Array, mounts: Dictionary
) -> void:
	if not _from_the_host(from):
		return
	if taken.size() > MAX_TAKEN or built.size() > 64 or progress.size() > 64 or mounts.size() > 256:
		return
	var clean_taken := PackedStringArray()
	for id in taken:
		if is_pickup_id(id):
			clean_taken.append(id)
	# A site is checked by the dams themselves when it is used, so what is
	# wanted here is only that it is a number that will not poison a save.
	var clean_built: Array = []
	for site: Variant in built:
		if (typeof(site) == TYPE_FLOAT or typeof(site) == TYPE_INT) and believable(Vector3(float(site), 0.0, 0.0)):
			clean_built.append(float(site))
	var clean_progress: Dictionary = {}
	for entry: Variant in progress:
		if typeof(entry) != TYPE_ARRAY or entry.size() < 2:
			continue
		var site: Variant = entry[0]
		var count: Variant = entry[1]
		if (typeof(site) != TYPE_FLOAT and typeof(site) != TYPE_INT) or typeof(count) != TYPE_INT:
			continue
		if believable(Vector3(float(site), 0.0, 0.0)) and count >= 0 and count < 1000:
			clean_progress[float(site)] = count
	var clean_mounts: Dictionary = {}
	for key: Variant in mounts:
		var entry: Variant = mounts[key]
		if typeof(key) != TYPE_STRING or mount_named(key) == &"":
			continue
		if typeof(entry) != TYPE_ARRAY or entry.size() < 4:
			continue
		var numbers: Array = []
		for number: Variant in entry.slice(0, 4):
			if (typeof(number) != TYPE_FLOAT and typeof(number) != TYPE_INT) or not is_finite(float(number)):
				break
			numbers.append(float(number))
		if numbers.size() == 4 and believable(Vector3(numbers[0], numbers[1], numbers[2])):
			clean_mounts[key] = numbers
	remote_shared.emit(clean_taken, clean_built, clean_progress, clean_mounts)

## Is this a name the valley gives a pickup — "tile x:tile z:number"? It is
## stored and saved, and read back as a key, so nothing else gets in.
static func is_pickup_id(id: String) -> bool:
	if id.length() > 24:
		return false
	var parts := id.split(":")
	if parts.size() != 3:
		return false
	for part in parts:
		if not part.is_valid_int():
			return false
	return true

@rpc("any_peer", "call_remote", "reliable")
func _send_picked(id: String) -> void:
	if is_pickup_id(id):
		remote_picked.emit(id)

@rpc("any_peer", "call_remote", "reliable")
func _send_parked(id: String, at: Vector3, facing: float) -> void:
	if mount_named(id) == &"" or not believable(at) or not is_finite(facing):
		return
	remote_parked.emit(StringName(id), at, facing)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _send_animals(states: PackedFloat32Array) -> void:
	_take_animals(multiplayer.get_remote_sender_id(), states)

func _take_animals(from: int, states: PackedFloat32Array) -> void:
	if not _from_the_host(from):
		return
	var count := states.size() / ANIMAL_FLOATS
	if states.size() % ANIMAL_FLOATS != 0 or count < 1 or count > MAX_ANIMALS:
		return
	for number in states:
		if not is_finite(number) or absf(number) > BELIEVABLE_REACH:
			return
	remote_animals.emit(states)

@rpc("any_peer", "call_remote", "reliable")
func _send_dam_stick(site: float) -> void:
	if not is_finite(site) or absf(site) > BELIEVABLE_REACH:
		return
	remote_dam_stick.emit(site)

@rpc("any_peer", "call_remote", "reliable")
func _send_time_of_day(fraction: float) -> void:
	if not is_finite(fraction):
		return
	remote_time_of_day.emit(fposmod(fraction, 1.0))

## Names are exchanged once on arrival rather than sent with every message.
@rpc("any_peer", "call_remote", "reliable")
func _send_name(display_name: String, chose: int, looking := []) -> void:
	_take_name(multiplayer.get_remote_sender_id(), display_name, chose, looking)

## What a name message says, whoever it came from. Apart from the rpc so that
## it can be tried without a second machine. `looking` is optional because a
## message from before there were characters has only the name and the shirt,
## and is still a good one: it is the plain figure.
func _take_name(from: int, display_name: String, chose: int, looking: Variant = []) -> void:
	# Validated on arrival: a name becomes a label on screen, and this is the
	# one piece of data that comes from another machine and is shown to a child.
	var safe := display_name.strip_edges()
	if not Profiles.is_valid_name(safe):
		safe = "?"
	# And a shirt becomes an index into an array, which is the other thing that
	# arrives from another machine — out of range would be a crash rather than
	# a wrong colour.
	var wearing := chose if chose >= 0 and chose < Visitors.SHIRTS.size() else -1
	# A name arriving from somebody already in the valley is a rename, not an
	# arrival: announcing "Amir joined" a second time and then quietly failing
	# to change the label over his head is the worst of both.
	var known := guests.has(from)
	guests[from] = safe
	# Three small numbers, each made to fit its list: the same care as the shirt.
	guest_looks[from] = Character.clean(looking)
	if known:
		guest_renamed.emit(from, safe, wearing)
	else:
		guest_arrived.emit(from, safe, wearing)

func _on_peer_connected(id: int) -> void:
	# Our name and shirt go to them; theirs come back the same way.
	_send_name.rpc_id(id, who, shirt, look)
	# And where we are goes with it. Positions are only sent when somebody has
	# actually moved, which is the right rule for traffic and the wrong one for
	# somebody who has just arrived: a new visitor is drawn at the world origin
	# until their first update lands, and the child hosting is by definition
	# standing still — holding the phone up, reading out the number. So the
	# brother who joins sees them buried at the middle of the valley rather
	# than standing where they are. Forgetting the last position sent makes the
	# next frame send one whether they have moved or not.
	_last_sent = Vector3(1e9, 1e9, 1e9)
	_since_move = MOVE_INTERVAL

func _on_peer_disconnected(id: int) -> void:
	peer_gone.emit(id)
	guest_positions.erase(id)
	# Somebody who dropped before saying who they were was never announced, so
	# there is nobody to say has left: "? left" came from a child nobody saw.
	if not guests.has(id):
		return
	var name: String = guests[id]
	guests.erase(id)
	guest_looks.erase(id)
	guest_left.emit(id, name)

func _on_connected() -> void:
	joined.emit()

func _on_connect_failed() -> void:
	close()
	failed.emit("could not reach that valley")

func _on_host_left() -> void:
	close()
	failed.emit("the other game closed")

## Which line of the game's own words says a `failed` reason to a child. The
## reasons are written in English for whoever reads a log, and put on the
## screen of a child who reads French or Russian.
static func words_for(reason: String) -> StringName:
	match reason:
		"could not reach that valley":
			return &"fail_unreachable"
		"the other game closed":
			return &"fail_host_closed"
		"the game is already open on this device":
			return &"fail_in_use"
		"the valley is too big to bring":
			return &"fail_too_big"
		"could not open the valley":
			return &"fail_open"
		_:
			return &"fail_connect"

## Errors a child might actually hit, in words rather than codes.
static func _explain(error: int) -> String:
	match error:
		ERR_ALREADY_IN_USE:
			return "the game is already open on this device"
		ERR_CANT_CREATE:
			return "could not open the valley"
		_:
			return "could not connect"
