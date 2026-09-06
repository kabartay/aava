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
signal guest_arrived(id: int, who: String)
signal guest_left(id: int, who: String)

## The valley changed, on some other machine. The game applies these exactly as
## if the local child had done them.
signal remote_built(kind: StringName, position: Vector3, spin: float)
signal remote_removed(position: Vector3)
signal remote_felled(position: Vector3)
signal remote_dam_stick(site: float)

## Where another child is, so they can be drawn.
signal guest_moved(id: int, position: Vector3, facing: float)

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

## Everyone else currently in the valley, by peer id.
var guests: Dictionary = {}

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
	if not is_networked() or _peer == null:
		return false
	if not is_inside_tree() or multiplayer == null:
		return false
	return _peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func is_host() -> bool:
	return role == Role.HOSTING

## Open this valley to the other device. Returns false if the port is busy,
## which on a family network almost always means the game is already running.
func host(display_name: String) -> bool:
	if not _ready_to_connect():
		return false
	close()
	who = display_name
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
func join(address: String, display_name: String) -> bool:
	if not _ready_to_connect():
		return false
	if address.strip_edges().is_empty():
		failed.emit("no address to join")
		return false
	close()
	who = display_name
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
func report_built(kind: StringName, at: Vector3, spin: float) -> void:
	if is_connected_to_anyone():
		_send_built.rpc(String(kind), at, spin)

func report_removed(at: Vector3) -> void:
	if is_connected_to_anyone():
		_send_removed.rpc(at)

func report_felled(at: Vector3) -> void:
	if is_connected_to_anyone():
		_send_felled.rpc(at)

func report_dam_stick(site: float) -> void:
	if is_connected_to_anyone():
		_send_dam_stick.rpc(site)

# --- what arrives ---------------------------------------------------------
#
# `call_remote` on every one of these, so a machine never applies its own
# message a second time: the local change has already happened by the time it
# is sent. `unreliable_ordered` for positions, because a dropped position is
# corrected by the next one a twelfth of a second later; `reliable` for the
# things that change the valley, because a dropped house is a lost afternoon.

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _send_position(at: Vector3, facing: float) -> void:
	var from := multiplayer.get_remote_sender_id()
	guest_moved.emit(from, at, facing)

@rpc("any_peer", "call_remote", "reliable")
func _send_built(kind: String, at: Vector3, spin: float) -> void:
	remote_built.emit(StringName(kind), at, spin)

@rpc("any_peer", "call_remote", "reliable")
func _send_removed(at: Vector3) -> void:
	remote_removed.emit(at)

@rpc("any_peer", "call_remote", "reliable")
func _send_felled(at: Vector3) -> void:
	remote_felled.emit(at)

@rpc("any_peer", "call_remote", "reliable")
func _send_dam_stick(site: float) -> void:
	remote_dam_stick.emit(site)

## Names are exchanged once on arrival rather than sent with every message.
@rpc("any_peer", "call_remote", "reliable")
func _send_name(display_name: String) -> void:
	var from := multiplayer.get_remote_sender_id()
	# Validated on arrival: a name becomes a label on screen, and this is the
	# one piece of data that comes from another machine and is shown to a child.
	var safe := display_name.strip_edges()
	if not Profiles.is_valid_name(safe):
		safe = "?"
	guests[from] = safe
	guest_arrived.emit(from, safe)

func _on_peer_connected(id: int) -> void:
	# Our name goes to them; theirs comes back the same way.
	_send_name.rpc_id(id, who)

func _on_peer_disconnected(id: int) -> void:
	var name: String = guests.get(id, "?")
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
