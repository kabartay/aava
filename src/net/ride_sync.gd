class_name RideSync
extends Node

## The five rides, on two phones.
##
## A ride is one machine with one clock, and there are two phones looking at it.
## So the host's ride is the ride: the host tells each guest its state (the
## phase and its clock, whether it is booked, where it stands: a few numbers,
## see each ride's `sync_state`), and a guest's phone runs the same ride on a
## clock the host steers: a little faster when it is behind, a little slower
## when it is ahead, a jump only for a ride nobody is in that is far out (on
## arriving). What is told:
##
##   host -> guests   a ride's state, reliably when something that matters changed
##                    (a phase, a booking, a gondola called) and once a second
##                    otherwise, unreliably, to correct the clocks
##   anybody -> all   where in a ride this child sits (a seat), on change
##   guest -> host    what this child does to a ride (keeps it at the ground,
##                    is in a gondola or a car), and a booking or a boarding
##
## The straps and bars stay each phone's own. A guest's bars come down before its
## ring moves, whatever the host's ring does, and its rider is strapped until
## they are up again: those rules are the ride's (see DropTower, PirateShip) and
## following the host only ever decides when a ride may go, never that it must.

## The rides in the order a message names them.
const RIDES: Array[StringName] = [&"carousel", &"wheel", &"coaster", &"drop_tower", &"pirate_ship"]

## How often the host looks for a change, and how often each ride's state is
## told whether or not it changed. The rides' beats are spread across the second.
const SCAN := 0.1
const BEAT := 1.0
## How long a seat must be the same before it is told, so that a child
## walking across a cushion is not somebody sitting down.
const SEAT_STEADY := 0.15

var _session: Session
var _park: Park
## Where this phone's own child is, asked every time it is needed.
var local_position := Callable()

var _since_scan := 0.0
var _beat_due: Array[float] = []
var _signature: Array[int] = []
var _flags_sent: Array[int] = []
var _following := false
## Where this child sits, as last told, and what it is changing to.
var _seat_told := Vector3(-1.0, 0.0, 0.0)
var _seat_told_ride := -1
var _seat_now := Vector3(-1.0, 0.0, 0.0)
var _seat_now_ride := -1
var _seat_steady := 0.0
## Where each other child sits: peer id -> [ride, seat].
var _seats: Dictionary = {}

func _init() -> void:
	name = "RideSync"
	for _i in Session.RIDE_COUNT:
		_beat_due.append(float(_i) * BEAT / float(Session.RIDE_COUNT))
		_signature.append(-1)
		_flags_sent.append(0)

## Take hold of the rides and the session.
func attach(session: Session, park: Park) -> void:
	_session = session
	_park = park
	session.remote_ride_state.connect(_on_state)
	session.remote_ride_seat.connect(_on_seat)
	session.remote_ride_flags.connect(_on_flags)
	session.remote_ride_ask.connect(_on_ask)
	session.peer_gone.connect(_forget)
	session.guest_arrived.connect(_on_arrived)
	session.closed.connect(_on_closed)
	for index in RIDES.size():
		var ride := ride_at(index)
		if ride.has_signal(&"sync_asked"):
			ride.connect(&"sync_asked", func(what: int, arg: int) -> void:
				_session.report_ride_ask(index, what, arg))

func ride_at(index: int) -> Node:
	match index:
		0:
			return _park.carousel
		1:
			return _park.wheel
		2:
			return _park.coaster
		3:
			return _park.drop_tower
	return _park.pirate_ship

func _process(delta: float) -> void:
	step(delta)

## One tick. Apart from `_process` so that the checks can run it by hand.
func step(delta: float) -> void:
	if _session == null or _park == null:
		return
	var follow := _session.can_follow_rides()
	if follow != _following:
		_following = follow
		for index in RIDES.size():
			var ride := ride_at(index)
			if follow:
				ride.set(&"sync_following", true)
			else:
				ride.call(&"sync_release")
		if not follow:
			_seats.clear()
		# Whatever this child was sitting in is told again to whoever is there now.
		_seat_told_ride = -2
	_since_scan += delta
	var scanning := _since_scan >= SCAN
	if scanning:
		_since_scan = 0.0
	if _session.has_ride_company():
		_host_tells(delta, scanning)
	if _session.is_following() and scanning:
		_guest_tells()
	_watch_my_seat(delta)

## The host: state on change, and a beat for each ride in its turn.
func _host_tells(delta: float, scanning: bool) -> void:
	for index in RIDES.size():
		var ride := ride_at(index)
		_beat_due[index] -= delta
		var changed := false
		if scanning:
			var signature: int = ride.call(&"sync_signature")
			changed = signature != _signature[index]
			_signature[index] = signature
		if changed or _beat_due[index] <= 0.0:
			_beat_due[index] = BEAT
			_session.report_ride_state(index, ride.call(&"sync_state"), changed)

## A guest: what this child does to each ride, when it changes.
func _guest_tells() -> void:
	if not _session.can_follow_rides():
		return
	for index in RIDES.size():
		var flags: int = ride_at(index).call(&"sync_flags")
		if flags != _flags_sent[index]:
			_flags_sent[index] = flags
			_session.report_ride_flags(index, flags)

## Where this child sits, told when it has been the same for a moment.
func _watch_my_seat(delta: float) -> void:
	if not _session.is_connected_to_anyone():
		return
	var at: Vector3 = local_position.call() if local_position.is_valid() else Vector3.INF
	var ride := -1
	var seat := Vector3(-1.0, 0.0, 0.0)
	if at.is_finite() and ParkSpec.inside(at.x, at.z):
		for index in RIDES.size():
			var found: Vector3 = ride_at(index).call(&"sync_seat_of", at)
			if found.x >= 0.0:
				ride = index
				seat = found
				break
	if ride != _seat_now_ride or int(seat.x) != int(_seat_now.x):
		_seat_steady = 0.0
	else:
		_seat_steady += delta
	_seat_now_ride = ride
	_seat_now = seat
	if _seat_steady < SEAT_STEADY:
		return
	var changed := (
		ride != _seat_told_ride or int(seat.x) != int(_seat_told.x)
		or (ride >= 0 and seat.distance_squared_to(_seat_told) > 0.01)
	)
	if not changed:
		return
	var left := _seat_told_ride
	_seat_told_ride = ride
	_seat_told = seat
	# Got up from one ride before sitting in the next, or just got up.
	if left >= 0 and left != ride:
		_session.report_ride_seat(left, Vector3(-1.0, 0.0, 0.0))
	if ride >= 0:
		_session.report_ride_seat(ride, seat)

# --- what arrives -----------------------------------------------------------

func _on_state(ride: int, state: PackedFloat32Array, age: float) -> void:
	if not _following:
		return
	ride_at(ride).call(&"sync_apply", state, age)

func _on_seat(from: int, ride: int, seat: Vector3) -> void:
	if seat.x < 0.0:
		var was: Array = _seats.get(from, [])
		if was.size() == 2 and int(was[0]) == ride:
			_seats.erase(from)
		return
	_seats[from] = [ride, seat]

func _on_flags(from: int, ride: int, flags: int) -> void:
	ride_at(ride).call(&"sync_set_flags", from, flags)

func _on_ask(from: int, ride: int, what: int, arg: int) -> void:
	var node := ride_at(ride)
	if node.has_method(&"sync_ask"):
		node.call(&"sync_ask", from, what, arg)

## Somebody has left, or lost the connection: whatever they were holding up or
## sitting in is let go, so that no ride waits for a child who is not there.
func _forget(id: int) -> void:
	_seats.erase(id)
	for index in RIDES.size():
		ride_at(index).call(&"sync_forget", id)

func _on_arrived(_id: int, _who: String, _shirt: int) -> void:
	# A guest who has just come is told every ride at once, and where this child
	# sits, rather than at the next beat.
	for index in RIDES.size():
		_signature[index] = -1
	_seat_told_ride = -2

func _on_closed() -> void:
	_seats.clear()
	for index in RIDES.size():
		_flags_sent[index] = 0
		_signature[index] = -1

## Where somebody else is sitting, for drawing them: the pose (see SeatPose) and
## the seat as the ride stands now on this phone, or nothing if they are not in
## a ride.
func seat_of_guest(id: int) -> Dictionary:
	var entry: Array = _seats.get(id, [])
	if entry.size() != 2 or _park == null:
		return {}
	var ride := int(entry[0])
	var seat: Vector3 = entry[1]
	var place: Transform3D = ride_at(ride).call(&"seat_world", int(seat.x), Vector2(seat.y, seat.z))
	return {"pose": RIDES[ride], "place": place}

## Where somebody else was said to sit: [ride, seat] or empty. For the checks.
func seat_told_of(id: int) -> Array:
	return _seats.get(id, [])
