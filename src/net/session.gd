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
## The other child has been served a dish, which stands on a table at this spot.
signal remote_meal(dish: int, position: Vector3)
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
## The host says it already had this pickup when this phone's child took it
## too, so it was never theirs to keep (see `report_picked`).
signal pick_refused(id: String)
## The host laid pickups again, out of sight (see `report_restocked`).
signal remote_restocked(ids: PackedStringArray)
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

## The rides, which are the host's. A ride's state as the host has it, told to a
## guest (see RideSync): `age` is how old it is on arrival, in seconds. A child
## on another phone sitting down in a seat of a ride (or leaving it: seat -1),
## what they say they are doing to a ride (see RideSync.flags_of), and what they
## ask the host's ride to do (the host only).
signal remote_ride_state(ride: int, state: PackedFloat32Array, age: float)
signal remote_ride_seat(from: int, ride: int, seat: Vector3)
signal remote_ride_flags(from: int, ride: int, flags: int)
signal remote_ride_ask(from: int, ride: int, what: int, arg: int)
## Somebody paid at the pool's turnstile, and it turned for them.
signal remote_turnstile(from: int)
## Somebody's game has said, and agrees, that it is the same version as this.
signal peer_agreed(id: int)

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

## What two phones must agree on before they say anything else to each other:
## the version of the messages. Godot numbers a node's messages by sorting
## their names, so two builds with different messages would run each other's
## wrong ones. Raised whenever a message is added, changed or removed.
const PROTOCOL := 3
const HELLO_MAGIC := "AAVA"
## How long a phone is given to say hello before its game is taken to be one
## that does not (an older version).
const HELLO_PATIENCE := 8.0

## How many rides a message can name, and the most numbers a ride's state is.
const RIDE_COUNT := 5
const RIDE_FLOATS := 8
## What a guest can ask a ride to do.
const ASK_BOOK := 0
const ASK_BOARD := 1
const ASK_STEP_OFF := 2
const MAX_SEAT := 15

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

## What each guest said they are riding, by peer id, and nothing for one on foot.
## Kept with the positions, because what a guest is doing on a mount is part of
## where they are: the football judges a guest's body by it.
var guest_mounts: Dictionary = {}

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

## For the checks: a delay and a jitter (seconds) on what travels over a link,
## so that a link can be as slow and as uneven as a family's Wi-Fi.
var link_latency := 0.0
var link_jitter := 0.0
## And the share of the messages sent unreliably (a ride's slow beat) that a
## link loses on the way, as a bad Wi-Fi does. Reliable ones are only ever late.
var link_loss := 0.0
var _link_clock := 0.0
var _link_last_due := 0.0
var _link_pending: Array = []
var _link_rng := RandomNumberGenerator.new()

## The version each phone said it is, by peer id, for those that did.
var peer_protocol: Dictionary = {}
var _hello_wait: Dictionary = {}

var _peer: ENetMultiplayerPeer = null
## A port other than the usual one. Only the checks use it.
var port_override := 0
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
	var error := _peer.create_server(port_override if port_override > 0 else PORT, MAX_GUESTS)
	if error != OK:
		_peer = null
		failed.emit(_explain(error))
		return false

	multiplayer.multiplayer_peer = _peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_listen_for_hello()
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
	var error := _peer.create_client(address, port_override if port_override > 0 else PORT)
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
	_listen_for_hello()
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
	peer_protocol.clear()
	_hello_wait.clear()
	_buckets.clear()
	_link_pending.clear()
	if _peer != null:
		_peer.close()
		_peer = null
	if not is_inside_tree() or multiplayer == null:
		role = Role.ALONE
		guests.clear()
		guest_looks.clear()
		guest_positions.clear()
		guest_mounts.clear()
		return
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	for signal_name: StringName in [
		&"peer_connected", &"peer_disconnected", &"connected_to_server",
		&"connection_failed", &"server_disconnected", &"peer_packet",
	]:
		for connection in multiplayer.get_signal_connection_list(signal_name):
			multiplayer.disconnect(signal_name, connection["callable"])
	var was := role
	role = Role.ALONE
	guests.clear()
	guest_looks.clear()
	guest_positions.clear()
	guest_mounts.clear()
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
	if _hello_wait.is_empty():
		return
	for id: int in _hello_wait.keys():
		# A frame that lasted a minute because the phone was put away is not a
		# minute of silence from the other one.
		_hello_wait[id] = float(_hello_wait[id]) + minf(delta, 0.25)
		if float(_hello_wait[id]) > HELLO_PATIENCE:
			_refuse_version(id)

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
## and 64 for diving, and 128 for reaching out to an animal (feeding, stroking,
## milking), which the other phone draws as the same reach to the nearest one.
## A child on foot at a standstill is zero. A phone that has not been updated
## masks the top bit off and sees an ordinary pace.
static func motion_code(speed: float, swimming: bool, diving: bool, tending := false) -> int:
	var code := clampi(int(roundf(maxf(speed, 0.0) * 2.0)), 0, 31)
	if tending:
		code += 128
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

## A dish was set down on a table, so that the other child sees it there and
## watches it eaten: its place on the menu (see Dishes.index_of) and the spot on
## the table. Nothing else about the meal crosses the wire — the coins and the
## energy are this child's own.
func report_meal(dish: int, at: Vector3) -> void:
	if is_connected_to_anyone():
		_send_meal.rpc(dish, at)

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
##
## The host is the arbiter. A guest's pick-up is the child's at once, so it
## feels instant, but it is only provisional: it goes to the host alone, which
## either passes it on to the other guests or, if the host's valley had already
## given that thing away, answers `pick_refused` and the guest's phone takes it
## back out of the bag. Told to everybody, as it was, two children who walked
## onto one stick in the same instant were each paid for it.
func report_picked(id: String) -> void:
	if not is_connected_to_anyone():
		return
	if _link != null:
		_link._take_picked(HOST_ID if role == Role.HOSTING else _link_id, id)
	elif role == Role.VISITING:
		_send_picked.rpc_id(HOST_ID, id)
	else:
		_send_picked.rpc(id)

## The host laid taken pickups again, and says which. Only the host decides:
## a guest's phone never lays one itself, so the two valleys cannot disagree
## about what lies where, and a stick cannot be there for one child and gone for
## the other.
func report_restocked(ids: PackedStringArray) -> void:
	if role != Role.HOSTING or ids.is_empty() or not is_connected_to_anyone():
		return
	if _link != null:
		_link._take_restocked(HOST_ID, ids)
	else:
		_send_restocked.rpc(ids)

## The host's answer to "is this stick already gone here?", set by the game. A
## session on its own knows nothing of the valley, so it asks.
var pickup_is_gone := Callable()

## A mount was got off, and left where it now stands. Its way there was told
## as its rider's position; this is where it stays.
##
## A guest tells the host alone. The host puts the machine on clear ground and
## tells everybody, the guest included, the spot it chose; a guest's raw spot
## used to be passed on to the other guests first, so they saw the machine in
## a tree or a wall for an instant and then jump.
func report_parked(id: StringName, at: Vector3, facing: float) -> void:
	if not is_connected_to_anyone():
		return
	if role == Role.VISITING and _link == null:
		_send_parked.rpc_id(HOST_ID, String(id), at, facing)
	else:
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

## The rides are the host's. For each, the host tells every guest its state:
## whole and reliably when something that matters changed (a phase, a booking),
## and unreliably as a slow beat in between, which corrects the clocks. A few
## numbers each: see the rides' `sync_state`.
func report_ride_state(ride: int, state: PackedFloat32Array, reliable: bool) -> void:
	if role != Role.HOSTING or not is_connected_to_anyone() or not _a_ride(ride):
		return
	if _link != null:
		var other := _link
		_to_link(func() -> void: other._take_ride_state(HOST_ID, ride, state), not reliable)
		return
	for id in agreed_guests():
		if reliable:
			_send_ride_state.rpc_id(id, ride, state)
		else:
			_send_ride_beat.rpc_id(id, ride, state)

## This child has sat down in a seat of a ride, or got up (seat.x is -1), so the
## other phones draw them in it: seat.x is the seat, the rest where in it for the
## rides that say (the wheel). A guest tells the host, which tells the others.
func report_ride_seat(ride: int, seat: Vector3) -> void:
	if not is_connected_to_anyone() or not _a_ride(ride):
		return
	if _link != null:
		var other := _link
		var from := HOST_ID if role == Role.HOSTING else _link_id
		_to_link(func() -> void: other._take_ride_seat(from, ride, seat))
	elif role == Role.VISITING:
		if int(peer_protocol.get(HOST_ID, 0)) == PROTOCOL:
			_send_ride_seat.rpc_id(HOST_ID, ride, seat)
	else:
		for id in agreed_guests():
			_send_ride_seat.rpc_id(id, ride, seat)

## What this child is doing to a ride, as the ride packs it (`sync_flags`): a
## guest tells the host, which decides what the ride does. Reliable.
func report_ride_flags(ride: int, flags: int) -> void:
	if not is_following() or not _a_ride(ride):
		return
	if _link != null:
		var other := _link
		_to_link(func() -> void: other._take_ride_flags(_link_id, ride, flags))
	elif int(peer_protocol.get(HOST_ID, 0)) == PROTOCOL:
		_send_ride_flags.rpc_id(HOST_ID, ride, flags)

## A guest asks the host's ride for something: to be booked, to be boarded at an
## animal, to be let off.
func report_ride_ask(ride: int, what: int, arg: int) -> void:
	if not is_following() or not _a_ride(ride):
		return
	if _link != null:
		var other := _link
		_to_link(func() -> void: other._take_ride_ask(_link_id, ride, what, arg))
	elif int(peer_protocol.get(HOST_ID, 0)) == PROTOCOL:
		_send_ride_ask.rpc_id(HOST_ID, ride, what, arg)

## This child paid at the pool's turnstile: it turns on the other phones too.
## Only the turning is told; whether it lets anybody through is each phone's own.
func report_turnstile() -> void:
	if not is_connected_to_anyone():
		return
	if _link != null:
		var other := _link
		var from := HOST_ID if role == Role.HOSTING else _link_id
		_to_link(func() -> void: other._take_turnstile(from))
	elif role == Role.VISITING:
		if int(peer_protocol.get(HOST_ID, 0)) == PROTOCOL:
			_send_turnstile.rpc_id(HOST_ID)
	else:
		for id in agreed_guests():
			_send_turnstile.rpc_id(id)

## Guests that said hello and are the same version: the only ones the rides
## and the turnstile are told to.
func agreed_guests() -> Array[int]:
	var out: Array[int] = []
	if _link != null or role != Role.HOSTING:
		return out
	for id: int in guests:
		if int(peer_protocol.get(id, 0)) == PROTOCOL:
			out.append(id)
	return out

## Is somebody here for the rides to be told to? The host's, with a link or a
## guest who is the same version.
func has_ride_company() -> bool:
	if role != Role.HOSTING or not is_connected_to_anyone():
		return false
	if _link != null:
		return not guests.is_empty()
	return not agreed_guests().is_empty()

## Is this the guest of a host whose rides are the rides? Following, and the
## host is the same version, so that it sends them.
func can_follow_rides() -> bool:
	if not is_following():
		return false
	return _link != null or int(peer_protocol.get(HOST_ID, 0)) == PROTOCOL

## How long a message from `from` took to get here, as well as it can be told:
## half the round trip the connection measures, or the delay a check gave the link.
func delay_from(from: int) -> float:
	if _link != null:
		return _link.link_latency
	if _peer == null:
		return 0.0
	var other := _peer.get_peer(from)
	if other == null:
		return 0.0
	return clampf(float(other.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)) * 0.0005, 0.0, 0.5)

static func _a_ride(ride: int) -> bool:
	return ride >= 0 and ride < RIDE_COUNT

## Hand `sent` to the other end of a link, after the delay and jitter a check
## asked for: never out of order, as a real connection does not.
func _to_link(sent: Callable, lossy := false) -> void:
	if lossy and link_loss > 0.0 and _link_rng.randf() < link_loss:
		return
	if link_latency <= 0.0 and link_jitter <= 0.0:
		sent.call()
		return
	var due := maxf(_link_clock + link_latency + _link_rng.randf() * link_jitter, _link_last_due)
	_link_last_due = due
	_link_pending.append([due, sent])

## Let `delta` seconds pass on a link with a delay. For the checks.
func link_step(delta: float) -> void:
	_link_clock += delta
	var waiting: Array = []
	for entry: Array in _link_pending:
		if float(entry[0]) <= _link_clock:
			(entry[1] as Callable).call()
		else:
			waiting.append(entry)
	_link_pending = waiting

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

## Flood protection: what each kind of message may come to, per sender, as
## [burst, per second]. A bucket holds `burst` messages and fills at the rate;
## a message with nothing to spend is dropped, quietly. Every figure is several
## times what a game plays at (positions go at 12 a second, the rides' beats at
## one each), and the bursts are what a phone that stood still for ten seconds
## and then caught up can legitimately say in one breath.
const LIMITS := {
	# Bursts of about thirteen seconds of what a phone sends at its pace
	# (positions at 12 a second, balls at up to 30): a phone that stalled for
	# four or five seconds, as one put in a pocket does, hands over everything
	# the other sent meanwhile in one breath, and the last of it was refused.
	&"position": [160.0, 40.0],
	&"balls": [160.0, 30.0],
	&"animals": [12.0, 6.0],
	&"scores": [12.0, 3.0],
	&"kick": [20.0, 10.0],
	&"new_game": [3.0, 0.5],
	&"built": [400.0, 60.0],
	&"removed": [400.0, 60.0],
	&"felled": [100.0, 20.0],
	&"meal": [8.0, 1.0],
	&"dam_stick": [8.0, 0.5],
	&"time": [4.0, 0.5],
	&"name": [10.0, 2.0],
	&"valley": [1200.0, 400.0],
	&"shared": [8.0, 1.0],
	&"picked": [80.0, 12.0],
	&"pick_refused": [80.0, 12.0],
	&"restocked": [6.0, 0.2],
	&"parked": [30.0, 8.0],
	&"ride_state": [120.0, 70.0],
	&"ride_seat": [20.0, 10.0],
	&"ride_flags": [40.0, 20.0],
	&"ride_ask": [20.0, 5.0],
	&"turnstile": [6.0, 0.5],
	&"voice": [80.0, 30.0],
}

## For the checks: a clock to spend by, in seconds, in place of the real one.
var rate_clock := -1.0
var _buckets: Dictionary = {}
## How many messages of each kind were let through and dropped, for the checks
## and for finding out why a phone was ignored.
var spent: Dictionary = {}
var dropped: Dictionary = {}

func _rate_now() -> float:
	return rate_clock if rate_clock >= 0.0 else float(Time.get_ticks_msec()) * 0.001

## May `from` say one more of `kind`? Spends it if so.
func admit(kind: StringName, from: int) -> bool:
	var limit: Array = LIMITS.get(kind, [])
	if limit.is_empty():
		return true
	var now := _rate_now()
	var key := "%d/%s" % [from, kind]
	var bucket: Array = _buckets.get(key, [float(limit[0]), now])
	var tokens := minf(float(limit[0]), float(bucket[0]) + maxf(now - float(bucket[1]), 0.0) * float(limit[1]))
	if tokens < 1.0:
		_buckets[key] = [tokens, now]
		dropped[kind] = int(dropped.get(kind, 0)) + 1
		return false
	_buckets[key] = [tokens - 1.0, now]
	spent[kind] = int(spent.get(kind, 0)) + 1
	return true

## Whether this message, arriving by rpc, is to be looked at at all: from
## somebody who has said hello as the same version (nothing else is believed:
## a stranger on the Wi-Fi that skips the hello gets no further), and not
## faster than the kind allows. Gives the sender, 0 for a check calling a
## handler directly, or -1 to ignore it.
func _admit(kind: StringName) -> int:
	var from := _sender()
	if from == 0:
		return 0
	if _link == null and not peer_protocol.has(from):
		dropped[&"unwelcome"] = int(dropped.get(&"unwelcome", 0)) + 1
		return -1
	return from if admit(kind, from) else -1

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _send_position(at: Vector3, facing: float, mount := "", motion := 0) -> void:
	if not believable(at) or not is_finite(facing):
		return
	var from := _admit(&"position")
	if from < 0:
		return
	_take_position(_sender(), at, facing, mount, motion)

func _take_position(from: int, at: Vector3, facing: float, mount: String, motion: int) -> void:
	guest_positions[from] = at
	var riding := mount_named(mount)
	if riding == &"":
		guest_mounts.erase(from)
	else:
		guest_mounts[from] = riding
	# Eight bits and no more: anything else a stranger sends is not a pace.
	guest_moving.emit(from, motion & 255)
	guest_moved.emit(from, at, facing, riding)

## Two children got on the same machine in the same moment, each phone having
## seen its own child first. The host's child keeps it, and a guest whose
## machine the host names gives way, so both phones come to the same answer
## without a word more being sent: the host ignores the guest's claim and the
## guest, seeing the host's, gets off. `following` is whether this phone is a
## guest's, `rider` the peer id of the child said to be on it.
static func gives_way_on_a_mount(following: bool, rider: int) -> bool:
	return following and rider == HOST_ID

## The highest number in a mount's id: a herd of twenty is the most the valley
## has, and a machine bought is numbered from nought (see Mounts.free_id).
const MAX_MOUNT_NUMBER := 63

## The longest name of a kind of thing built that is believed: far past any of
## this game's own, so that nothing a stranger sends is made into a StringName
## and passed about at length.
const MAX_KIND_LENGTH := 48

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
	if colon >= 0:
		# A number as the game writes one: no sign, no padding, and no more than
		# a valley has ever numbered. A parked mount of an id this phone has not
		# heard of is put into the valley (and saved with it), so "bicycle:+3"
		# and "bicycle:3" were two machines and "horse:99999" a new one each.
		var number := text.substr(colon + 1)
		if not number.is_valid_int() or str(number.to_int()) != number:
			return &""
		if number.to_int() < 0 or number.to_int() > MAX_MOUNT_NUMBER:
			return &""
	return StringName(text)

## Does the network itself carry a guest's message to the other guests? Godot's
## multiplayer relays through the server by default (`server_relay`): each guest
## is told of the others and an rpc to everyone reaches them directly. Where that
## is so, the host passing a message on as well delivers it twice, and a stick
## for the beavers counted twice is a dam finished one stick early.
func _network_relays() -> bool:
	if not is_inside_tree() or multiplayer == null:
		return false
	var scene := multiplayer as SceneMultiplayer
	return scene != null and scene.server_relay

## Where the network does not relay, a guest only ever talks to the host. So
## when one guest builds, fells or picks something up, the host is the only
## phone that hears, and a second guest in the valley never sees it unless the
## host passes it on. Who the host should pass a message to: every other guest
## who has said who they are, and nobody at all for a guest or a linked check,
## nor where the network has already delivered it to them.
func others_than(from: int) -> Array[int]:
	var out: Array[int] = []
	if role != Role.HOSTING or _link != null or _network_relays():
		return out
	for id: int in guests:
		if id != from:
			out.append(id)
	return out

## For the checks: the peer a handler is to believe it is hearing from, when
## it is called directly and there is no rpc to ask.
var check_sender := 0

## Who sent the message being handled; nobody when a check calls a handler
## directly, outside the tree and so without a multiplayer to ask.
func _sender() -> int:
	if check_sender != 0:
		return check_sender
	return multiplayer.get_remote_sender_id() if is_inside_tree() and multiplayer != null else 0

## Is this from the host? 0 is no sender at all, which is how a check calls a
## handler directly. Another guest's message relayed through the host is not
## the host's, and must not set the score.
func _from_the_host(from: int) -> bool:
	return role == Role.VISITING and (from == HOST_ID or from == 0)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _send_balls(states: PackedFloat32Array) -> void:
	if _admit(&"balls") < 0:
		return
	_take_balls(_sender(), states)

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
	if _admit(&"scores") < 0:
		return
	_take_football_scores(_sender(), blue, red, goal)

func _take_football_scores(from: int, blue: int, red: int, goal: int) -> void:
	if not _from_the_host(from):
		return
	if blue < 0 or red < 0 or blue > 99999 or red > 99999 or goal < -1 or goal > 1:
		return
	remote_football_scores.emit(blue, red, goal)

@rpc("any_peer", "call_remote", "reliable")
func _send_kick(ball: int, velocity: Vector3) -> void:
	if _admit(&"kick") < 0:
		return
	_take_kick(_sender(), ball, velocity)

func _take_kick(from: int, ball: int, velocity: Vector3) -> void:
	# Only a host is asked to kick, and only by somebody who is in the valley.
	if role != Role.HOSTING or not guests.has(from):
		return
	if ball < 0 or ball >= MAX_BALLS or not believable(velocity):
		return
	remote_kick.emit(from, ball, velocity)

@rpc("any_peer", "call_remote", "reliable")
func _send_new_game() -> void:
	if _admit(&"new_game") < 0:
		return
	_take_new_game(_sender())

func _take_new_game(from: int) -> void:
	if role != Role.HOSTING or not guests.has(from):
		return
	remote_new_game.emit(from)

@rpc("any_peer", "call_remote", "reliable")
func _send_built(
	kind: String, at: Vector3, spin: float, extent := Vector2i.ONE, material := ""
) -> void:
	if not believable(at) or not is_finite(spin) or kind.length() > MAX_KIND_LENGTH:
		return
	if _admit(&"built") < 0:
		return
	# A room no bigger than one tap of the roof could ever cover here.
	if (
		extent.x < 1 or extent.y < 1
		or extent.x > HouseParts.ROOM_LONGEST or extent.y > HouseParts.ROOM_LONGEST
	):
		return
	# Whatever arrives as a material is one of ours or it is plaster.
	remote_built.emit(StringName(kind), at, spin, extent, HouseParts.material_from(material))
	for id in others_than(_sender()):
		_send_built.rpc_id(id, kind, at, spin, extent, material)

@rpc("any_peer", "call_remote", "reliable")
func _send_removed(at: Vector3, kind := "") -> void:
	if not believable(at) or kind.length() > MAX_KIND_LENGTH or _admit(&"removed") < 0:
		return
	remote_removed.emit(at, StringName(kind))
	for id in others_than(_sender()):
		_send_removed.rpc_id(id, at, kind)

@rpc("any_peer", "call_remote", "reliable")
func _send_meal(dish: int, at: Vector3) -> void:
	if not believable(at) or Dishes.from_index(dish) == &"" or _admit(&"meal") < 0:
		return
	remote_meal.emit(dish, at)
	for id in others_than(_sender()):
		_send_meal.rpc_id(id, dish, at)

@rpc("any_peer", "call_remote", "reliable")
func _send_felled(at: Vector3) -> void:
	if not believable(at) or _admit(&"felled") < 0:
		return
	remote_felled.emit(at)
	for id in others_than(_sender()):
		_send_felled.rpc_id(id, at)

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
	if _admit(&"valley") < 0:
		return
	_take_valley(_sender(), pieces, stumps, more)

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
		# Rebuilt as [x, z] or [x, z, 1], the only shapes the stumps read back:
		# a third value of any other type was passed on and read as a number.
		var stump: Array = [x, z]
		if entry.size() >= 3 and typeof(entry[2]) == TYPE_INT and entry[2] == 1:
			stump.append(1)
		clean_stumps.append(stump)
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
	if _admit(&"shared") < 0:
		return
	_take_shared(_sender(), taken, built, progress, mounts)

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
	var of_a_kind: Dictionary = {}
	for key: Variant in mounts:
		var entry: Variant = mounts[key]
		if typeof(key) != TYPE_STRING or mount_named(key) == &"":
			continue
		# No more of a kind than a valley holds (see Mounts.MAX_OF_A_KIND).
		var kind := MountKinds.kind_of(StringName(key))
		if int(of_a_kind.get(kind, 0)) >= Mounts.MAX_OF_A_KIND:
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
			of_a_kind[kind] = int(of_a_kind.get(kind, 0)) + 1
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
	if not is_pickup_id(id) or _admit(&"picked") < 0:
		return
	_take_picked(_sender(), id)

func _take_picked(from: int, id: String) -> void:
	if not is_pickup_id(id):
		return
	# A guest only believes the host (or a check calling straight in).
	if role == Role.VISITING and from != 0 and from != HOST_ID:
		return
	if role == Role.HOSTING and from != 0 and from != HOST_ID and pickup_is_gone.is_valid() \
			and bool(pickup_is_gone.call(id)):
		# The host's child, or another guest, had it first. No word to anyone
		# else: nothing changed for them.
		if _link != null:
			_link._take_pick_refused(HOST_ID, id)
		elif is_connected_to_anyone():
			_send_pick_refused.rpc_id(from, id)
		return
	remote_picked.emit(id)
	if role != Role.HOSTING or from == 0 or from == HOST_ID:
		return
	# Guests send to the host alone, so passing it on is the host's job whether
	# or not the network relays other messages.
	for other in _peers_but(from):
		_send_picked.rpc_id(other, id)

## Every peer connected but one, from the network itself rather than from the
## guests who have introduced themselves: a stick is gone for a guest still
## being introduced as much as for the rest.
func _peers_but(from: int) -> Array[int]:
	var out: Array[int] = []
	if _link != null or not is_inside_tree() or multiplayer == null:
		return out
	for id: int in multiplayer.get_peers():
		if id != from:
			out.append(id)
	return out

## More at once than one pass of the host's restocking lays.
const MAX_RESTOCKED := 64

@rpc("any_peer", "call_remote", "reliable")
func _send_restocked(ids: PackedStringArray) -> void:
	if ids.size() > MAX_RESTOCKED or _admit(&"restocked") < 0:
		return
	_take_restocked(_sender(), ids)

## Only the host is believed, and only about names a pickup has.
func _take_restocked(from: int, ids: PackedStringArray) -> void:
	if not _from_the_host(from) or ids.size() > MAX_RESTOCKED:
		return
	var clean := PackedStringArray()
	for id in ids:
		if is_pickup_id(id):
			clean.append(id)
	if not clean.is_empty():
		remote_restocked.emit(clean)

@rpc("any_peer", "call_remote", "reliable")
func _send_pick_refused(id: String) -> void:
	if _admit(&"pick_refused") < 0:
		return
	_take_pick_refused(_sender(), id)

func _take_pick_refused(from: int, id: String) -> void:
	if is_pickup_id(id) and _from_the_host(from):
		pick_refused.emit(id)

@rpc("any_peer", "call_remote", "reliable")
func _send_parked(id: String, at: Vector3, facing: float) -> void:
	if mount_named(id) == &"" or not believable(at) or not is_finite(facing):
		return
	if _admit(&"parked") < 0:
		return
	var from := _sender()
	if role == Role.VISITING and from != 0 and from != HOST_ID:
		return
	# Not passed on: the host puts it on clear ground and tells everybody where
	# (see Main._on_remote_parked), the sender too.
	remote_parked.emit(StringName(id), at, facing)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _send_animals(states: PackedFloat32Array) -> void:
	if _admit(&"animals") < 0:
		return
	_take_animals(_sender(), states)

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
func _send_ride_state(ride: int, state: PackedFloat32Array) -> void:
	if _admit(&"ride_state") < 0:
		return
	_take_ride_state(_sender(), ride, state)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _send_ride_beat(ride: int, state: PackedFloat32Array) -> void:
	if _admit(&"ride_state") < 0:
		return
	_take_ride_state(_sender(), ride, state)

func _take_ride_state(from: int, ride: int, state: PackedFloat32Array) -> void:
	if not _from_the_host(from) or not _a_ride(ride):
		return
	if state.is_empty() or state.size() > RIDE_FLOATS:
		return
	for number in state:
		if not is_finite(number) or absf(number) > BELIEVABLE_REACH:
			return
	remote_ride_state.emit(ride, state, delay_from(HOST_ID if from == 0 else from))

@rpc("any_peer", "call_remote", "reliable")
func _send_ride_seat(ride: int, seat: Vector3) -> void:
	if _admit(&"ride_seat") < 0:
		return
	_take_ride_seat(_sender(), ride, seat)

func _take_ride_seat(from: int, ride: int, seat: Vector3) -> void:
	if not _a_ride(ride) or not seat.is_finite():
		return
	if seat.x < -1.0 or seat.x > MAX_SEAT or absf(seat.y) > 10.0 or absf(seat.z) > 10.0:
		return
	# A guest believes the host (or a check calling straight in) and a host
	# believes the guests it has met.
	if role == Role.VISITING and from != 0 and from != HOST_ID:
		return
	if role == Role.HOSTING and from != 0 and not guests.has(from):
		return
	remote_ride_seat.emit(from, ride, seat)
	if role != Role.HOSTING or from == 0 or from == HOST_ID or _link != null:
		return
	if not is_connected_to_anyone():
		return
	# A guest tells the host alone; telling the other guests is the host's job.
	for id in agreed_guests():
		if id != from:
			_send_ride_seat.rpc_id(id, ride, seat)

@rpc("any_peer", "call_remote", "reliable")
func _send_ride_flags(ride: int, flags: int) -> void:
	if _admit(&"ride_flags") < 0:
		return
	_take_ride_flags(_sender(), ride, flags)

func _take_ride_flags(from: int, ride: int, flags: int) -> void:
	if role != Role.HOSTING or not guests.has(from) or not _a_ride(ride):
		return
	if flags < 0 or flags > 0xFFFF:
		return
	remote_ride_flags.emit(from, ride, flags)

@rpc("any_peer", "call_remote", "reliable")
func _send_ride_ask(ride: int, what: int, arg: int) -> void:
	if _admit(&"ride_ask") < 0:
		return
	_take_ride_ask(_sender(), ride, what, arg)

func _take_ride_ask(from: int, ride: int, what: int, arg: int) -> void:
	if role != Role.HOSTING or not guests.has(from) or not _a_ride(ride):
		return
	if what < ASK_BOOK or what > ASK_STEP_OFF or arg < 0 or arg > 255:
		return
	remote_ride_ask.emit(from, ride, what, arg)

@rpc("any_peer", "call_remote", "reliable")
func _send_turnstile() -> void:
	if _admit(&"turnstile") < 0:
		return
	_take_turnstile(_sender())

func _take_turnstile(from: int) -> void:
	if role == Role.VISITING and from != 0 and from != HOST_ID:
		return
	if role == Role.HOSTING and from != 0 and not guests.has(from):
		return
	remote_turnstile.emit(from)
	if role != Role.HOSTING or from == 0 or from == HOST_ID or _link != null:
		return
	if not is_connected_to_anyone():
		return
	for id in agreed_guests():
		if id != from:
			_send_turnstile.rpc_id(id)

@rpc("any_peer", "call_remote", "reliable")
func _send_dam_stick(site: float) -> void:
	if not is_finite(site) or absf(site) > BELIEVABLE_REACH or _admit(&"dam_stick") < 0:
		return
	remote_dam_stick.emit(site)
	for id in others_than(_sender()):
		_send_dam_stick.rpc_id(id, site)

@rpc("any_peer", "call_remote", "reliable")
func _send_time_of_day(fraction: float) -> void:
	if not is_finite(fraction) or _admit(&"time") < 0:
		return
	remote_time_of_day.emit(fposmod(fraction, 1.0))
	for id in others_than(_sender()):
		_send_time_of_day.rpc_id(id, fraction)

## Names are exchanged once on arrival rather than sent with every message.
@rpc("any_peer", "call_remote", "reliable")
func _send_name(display_name: String, chose: int, looking := []) -> void:
	if display_name.length() > 200 or _admit(&"name") < 0:
		return
	_take_name(_sender(), display_name, chose, looking)

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

## How long a connection is kept when the other end says nothing, in
## milliseconds: [timeout limit, at least, at most]. The engine's own answer is
## five to thirty seconds, and a phone put down to answer a call, or a screen
## that locked, is silent for as long as it takes (an Android game is not
## running in the background), so the other child found themselves alone in an
## empty valley and the first one came back to "the other game closed".
## A minute covers that; a Wi-Fi that really has gone is still noticed.
const PATIENCE_LIMIT := 32
const PATIENCE_LEAST := 15000
const PATIENCE_MOST := 60000

## Make the connection to one peer patient. Does nothing off a real connection.
func _be_patient_with(id: int) -> void:
	if _peer == null:
		return
	var other := _peer.get_peer(id)
	if other != null:
		other.set_timeout(PATIENCE_LIMIT, PATIENCE_LEAST, PATIENCE_MOST)

## A peer's buckets go when it does, so that a child who comes back is not
## refused for what the last connection spent, and so that the table of
## buckets cannot grow with every peer that ever connected.
func _forget_rates_of(id: int) -> void:
	for key: String in _buckets.keys():
		if key.begins_with("%d/" % id):
			_buckets.erase(key)

func _on_peer_connected(id: int) -> void:
	# Nothing but a hello until the other phone has said which version it is:
	# see PROTOCOL. What used to go here goes when that is agreed.
	_hello_wait[id] = 0.0
	_send_hello(id)

## The other phone is the same version: now they are introduced.
func _greet(id: int) -> void:
	# Nobody to greet on a session that is not on a connection (a check).
	if _peer == null:
		return
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

func _listen_for_hello() -> void:
	var scene := multiplayer as SceneMultiplayer
	if scene != null and not scene.peer_packet.is_connected(_on_peer_packet):
		scene.peer_packet.connect(_on_peer_packet)

## The hello is not an rpc, which is the point of it: an rpc is numbered by the
## sorted names of the messages a build has, and a build with other messages
## would take it for something else. A plain packet is the same in every build.
func _send_hello(id: int) -> void:
	var scene := multiplayer as SceneMultiplayer
	if scene == null:
		return
	var packet := HELLO_MAGIC.to_ascii_buffer()
	packet.append(PROTOCOL)
	scene.send_bytes(packet, id, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0)

func _on_peer_packet(id: int, packet: PackedByteArray) -> void:
	if packet.size() != HELLO_MAGIC.length() + 1:
		return
	if packet.slice(0, HELLO_MAGIC.length()) != HELLO_MAGIC.to_ascii_buffer():
		return
	take_hello(id, packet[HELLO_MAGIC.length()])

## What a hello says. Apart from the packet so that it can be tried without a
## second machine.
func take_hello(id: int, protocol: int) -> void:
	if not _hello_wait.has(id):
		return
	_hello_wait.erase(id)
	if protocol != PROTOCOL:
		_refuse_version(id)
		return
	peer_protocol[id] = protocol
	# Only a host holds a connection of its own to each guest, and a guest to
	# the host: the other guests are reached through the host.
	if role == Role.HOSTING or id == HOST_ID:
		_be_patient_with(id)
	_greet(id)
	peer_agreed.emit(id)

## A phone that is another version of the game (or says nothing) is not talked
## to. A host lets it go; a guest goes home and says it could not connect.
func _refuse_version(id: int) -> void:
	_hello_wait.erase(id)
	if role == Role.HOSTING:
		if _peer != null:
			_peer.disconnect_peer(id)
	elif role == Role.VISITING:
		# Only the host's word is the visit's. Another guest who is silent, or
		# another version, is a stranger on the Wi-Fi and not the end of this
		# child's game: it is simply never listened to (see `_admit`). A guest
		# that went home at the silence of one the host had already turned away
		# was how one phone could knock another out of a valley.
		if id != HOST_ID and _link == null:
			return
		close()
		failed.emit("the other game is another version")

func _on_peer_disconnected(id: int) -> void:
	_forget_rates_of(id)
	peer_protocol.erase(id)
	_hello_wait.erase(id)
	peer_gone.emit(id)
	guest_positions.erase(id)
	guest_mounts.erase(id)
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
		"the other game is another version":
			return &"fail_connect"
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
