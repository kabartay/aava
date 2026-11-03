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

## Where another child is, so they can be drawn.
signal guest_moved(id: int, position: Vector3, facing: float)

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
func host(display_name: String, wearing := -1) -> bool:
	if not _ready_to_connect():
		return false
	close()
	who = display_name
	shirt = wearing
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
func join(address: String, display_name: String, wearing := -1) -> bool:
	if not _ready_to_connect():
		return false
	if address.strip_edges().is_empty():
		failed.emit("no address to join")
		return false
	close()
	who = display_name
	shirt = wearing
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
	if _peer != null:
		_peer.close()
		_peer = null
	if not is_inside_tree() or multiplayer == null:
		role = Role.ALONE
		guests.clear()
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
func report_position(at: Vector3, facing: float) -> void:
	if not is_connected_to_anyone() or _since_move < MOVE_INTERVAL:
		return
	if at.distance_squared_to(_last_sent) < 0.01:
		return
	_since_move = 0.0
	_last_sent = at
	_send_position.rpc(at, facing)

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
func report_name(display_name: String, chose: int) -> void:
	who = display_name
	shirt = chose
	if is_connected_to_anyone():
		_send_name.rpc(display_name, chose)

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
func _send_position(at: Vector3, facing: float) -> void:
	if not believable(at) or not is_finite(facing):
		return
	var from := multiplayer.get_remote_sender_id()
	guest_positions[from] = at
	guest_moved.emit(from, at, facing)

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
func _send_name(display_name: String, chose: int) -> void:
	var from := multiplayer.get_remote_sender_id()
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
	if known:
		guest_renamed.emit(from, safe, wearing)
	else:
		guest_arrived.emit(from, safe, wearing)

func _on_peer_connected(id: int) -> void:
	# Our name and shirt go to them; theirs come back the same way.
	_send_name.rpc_id(id, who, shirt)
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
	guest_left.emit(id, name)

func _on_connected() -> void:
	joined.emit()

func _on_connect_failed() -> void:
	close()
	failed.emit("could not reach that valley")

func _on_host_left() -> void:
	close()
	failed.emit("the other game closed")

## Errors a child might actually hit, in words rather than codes.
static func _explain(error: int) -> String:
	match error:
		ERR_ALREADY_IN_USE:
			return "the game is already open on this device"
		ERR_CANT_CREATE:
			return "could not open the valley"
		_:
			return "could not connect"
