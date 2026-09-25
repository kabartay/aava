class_name Mounts
extends Node3D

## The horse that waits in the valley, and the bicycle once it is bought.
##
## Both are one node holding a mesh and a position. Riding is not a physics
## problem here: the player keeps its own body and the mount follows it, which
## avoids the whole class of bugs where a character controller is parented to a
## moving object and inherits its rotation.
##
## The horse stands where the world puts it and stays there until ridden. The
## bicycle appears at the camp once bought, because a bicycle that spawns
## wherever you happened to be standing feels like a cheat rather than a thing
## you own.

signal mounted(kind: StringName)
signal dismounted(kind: StringName)

## How close you must be to get on.
const REACH := 3.2

var field: HeightField
var riding := &""

## Whether the child owns a saddle. Set by the game from the purse, because a
## horse does not know what is in a shop and Mounts must not depend on one.
##
## A saddled horse takes ground a bareback one slides off: the steep shoulders
## between the valley floor and the shelves above it. It is the only thing in
## the shop that makes the map bigger rather than the journey shorter.
var saddled := false

## How much steeper a slope a saddle lets a horse take.
const SADDLE_GRIP := 0.22

var _nodes: Dictionary = {}
var _positions: Dictionary = {}

func _init(height_field: HeightField) -> void:
	field = height_field

## Put a mount into the world. Called for the horse and the boats at the
## start, and for the bicycle when it is bought. `kind` is a mount id — see
## MountKinds.kind_of. `facing` turns it, for a boat pointed out at the water.
func place(kind: StringName, at: Vector3, facing := 0.0) -> void:
	if _nodes.has(kind):
		var existing: Node3D = _nodes[kind]
		if is_instance_valid(existing):
			existing.queue_free()

	var node := MountKinds.build_node(kind)
	# Solid while it stands. The horse could be walked through, which from
	# the phone read as the horse not being there.
	var body := StaticBody3D.new()
	body.name = "Solid"
	body.collision_layer = TerrainSpec.LAYER_PROPS
	var box: Array = MountKinds.body_box(kind)
	var shape := BoxShape3D.new()
	shape.size = box[0]
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = Vector3(0.0, float(box[1]), 0.0)
	body.add_child(collider)
	node.add_child(body)
	add_child(node)
	var grounded := at
	grounded.y = _rest_height(kind, at)
	node.global_position = grounded
	# A parked machine lies on the ground it is parked on. One height sample
	# put the whole thing at the height of its middle, so on a slope one end
	# was buried and the other in the air.
	node.transform.basis = _lie_on_the_ground(grounded, facing, kind)
	_nodes[kind] = node
	_positions[kind] = grounded

## Where a mount rests: on the ground, or, for a boat, on the water wherever
## the ground is under it. A boat left in the shallows sat on the bed with
## its hull half under, until this.
func _rest_height(kind: StringName, at: Vector3) -> float:
	var ground := field.height_at(at.x, at.z)
	var level := field.water_level_at(at.x, at.z)
	if MountKinds.floats(kind):
		return maxf(ground, level)
	# A horse in water over its head swims: it floats with most of its barrel
	# under and its withers clear, rather than walking along the bottom. It
	# used to walk the bottom while its rider floated at the surface, and the
	# two came apart with a gap of open water between them.
	if swims(kind) and level - ground > MountKinds.HORSE_SWIMS_AT:
		return level - MountKinds.HORSE_DRAUGHT
	return ground

## Whether this mount swims when the water is deep: a horse does, a bicycle
## does not go in at all, and a boat is already on the surface.
static func swims(kind: StringName) -> bool:
	return MountKinds.fords_water(kind) and not MountKinds.floats(kind)

## Is this mount swimming where it stands right now? Read by the game, which
## has to hold the rider in the saddle rather than let them float free.
func afloat(kind: StringName, at: Vector3) -> bool:
	if not swims(kind):
		return false
	return (
		field.water_level_at(at.x, at.z) - field.height_at(at.x, at.z)
		> MountKinds.HORSE_SWIMS_AT
	)

## Where a rider *stands* while their mount swims — which is where the horse
## itself is, not where its saddle is.
##
## A rider's body is drawn `MountKinds.eye_lift` above their own position:
## on land they stand on the ground the horse stands on and the drawing puts
## them in the saddle. Held at the saddle's own height instead, that lift was
## added a second time and the child floated a body's length above the horse.
static func saddle_afloat(level := HeightField.WATER_LEVEL) -> float:
	return level - MountKinds.HORSE_DRAUGHT

## Launch `count` boats round the shore of a pond, each where the water is
## about `depth` deep — wading depth, so a child walks out to one — and each
## pointed out across the water. The shore is found by walking out from the
## middle of the pond along each bearing until the bed comes up to the depth.
func launch_boats(pond: int, count: int, depth := 0.7) -> void:
	var offset := pond * Lakes.POND_STRIDE
	var centre := Vector3(Lakes.PONDS[offset], 0.0, Lakes.PONDS[offset + 1])
	var reach := Lakes.PONDS[offset + 2] * (1.0 + Lakes.WOBBLE) + 4.0
	for i in count:
		var bearing := TAU * float(i) / float(count) + 0.4
		var direction := Vector3(cos(bearing), 0.0, sin(bearing))
		# The spot whose water is nearest the wading depth wanted, rather than
		# the last one deeper than it: the pond's shelf steepened when the
		# valley's dry ground was held above the waterline, and a half-metre
		# stride along it could step straight past the depth being looked for.
		var spot := centre
		var closest := 1e9
		var walked := 0.25
		while walked < reach:
			var probe := centre + direction * walked
			var under := field.water_level_at(probe.x, probe.z) - field.height_at(probe.x, probe.z)
			if under > 0.0 and absf(under - depth) < closest:
				closest = absf(under - depth)
				spot = probe
			walked += 0.25
		# Facing the middle of the pond: rotation about Y that sends -Z to
		# -direction.
		place(MountKinds.boat_id(i), spot, atan2(direction.x, direction.z))

## How many boats there are. For the checks.
func boat_count() -> int:
	var count := 0
	for kind in _nodes:
		if MountKinds.boat_index(kind) >= 0 and is_instance_valid(_nodes[kind]):
			count += 1
	return count

func exists(kind: StringName) -> bool:
	return _nodes.has(kind) and is_instance_valid(_nodes[kind])

func position_of(kind: StringName) -> Vector3:
	return _positions.get(kind, Vector3.ZERO)

## The mount within reach, or an empty name. Never returns one already ridden.
## Sell one of a kind back: the one at the shop door if there is one there,
## and otherwise the one furthest from the child — that being the one they have
## decided they are not walking back for.
func sell_one(kind: StringName, from: Vector3) -> bool:
	var chosen := &""
	var furthest := -1.0
	for id in _nodes:
		if MountKinds.kind_of(id) != kind or not is_instance_valid(_nodes[id]):
			continue
		var node: Node3D = _nodes[id]
		var distance := node.global_position.distance_to(from)
		if distance > furthest:
			furthest = distance
			chosen = id
	if chosen == &"":
		return false
	var node: Node3D = _nodes[chosen]
	if is_instance_valid(node):
		node.queue_free()
	_nodes.erase(chosen)
	return true

## How many of a kind are standing in the world.
func count_of_kind(kind: StringName) -> int:
	var many := 0
	for id in _nodes:
		if MountKinds.kind_of(id) == kind and is_instance_valid(_nodes[id]):
			many += 1
	return many

## The id for one more of a kind: "bicycle:2" for the third bicycle.
##
## Machines used to be named by their kind alone, so there could only ever be
## one of each — buying a second bicycle replaced the first, wherever it was
## standing. They are numbered the way the boats and the horses are now.
func free_id(kind: StringName) -> StringName:
	for index in 16:
		var id := StringName("%s:%d" % [kind, index])
		if not _nodes.has(id) or not is_instance_valid(_nodes[id]):
			return id
	return StringName("%s:%d" % [kind, 16])

func nearest(player_position: Vector3) -> StringName:
	if riding != &"":
		return &""
	var best := &""
	var best_distance := REACH
	for kind in _nodes:
		if not is_instance_valid(_nodes[kind]):
			continue
		var flat: Vector3 = _positions[kind] - player_position
		flat.y = 0.0
		var distance := flat.length()
		if distance < best_distance:
			best_distance = distance
			best = kind
	return best

func mount(kind: StringName) -> bool:
	if riding != &"" or not exists(kind):
		return false
	riding = kind
	_settling = &""
	_set_solid(kind, false)
	_waiting_to_be_solid.erase(kind)
	# Its pace starts at nothing rather than at whatever it was last ridden
	# at, or a horse got on again breaks straight into a gallop on the spot.
	_pace = 0.0
	_carried_to = _positions[kind]
	_paced_from = _positions[kind]
	# The mount stays visible and is carried along under the child. Hiding it
	# was the first version, on the reasoning that the player "becomes" the
	# horse — but the child's own body is still drawn, so what a rider actually
	# saw was the horse vanishing and themselves running very fast.
	mounted.emit(kind)
	return true

## Carry the mount along under the rider. Called every frame while riding.
##
## The mount follows rather than the player being parented to it, for the same
## reason as everywhere else here: a body parented to a moving node inherits its
## rotation and fights its own gravity.
func carry(at: Vector3, facing: float) -> void:
	if riding == &"" or not exists(riding):
		return
	var node: Node3D = _nodes[riding]
	var spot := at
	spot.y = _rest_height(riding, at)
	node.global_position = spot
	# A ridden machine is simply pointed where its rider is pointed.
	#
	# It was being tipped to the ground under it here as well, and that broke
	# two things at once: everything else in this file reads `node.rotation.y`
	# to know which way a mount faces, and the Euler decomposition of a basis
	# with pitch and roll in it is not the heading that was put in. Parked
	# machines are tipped — see `place` — and ridden ones are not.
	node.rotation = Vector3(0.0, facing, 0.0)
	_positions[riding] = spot
	# How fast it is going is worked out in _process, where there is a delta
	# worth dividing by. It was worked out here from get_process_delta_time(),
	# which in a headless check is the editor's idle rate — 0.14 s — so a
	# horse carried three metres a second was measured at a third of one, and
	# the gait check passed a horse that barely moved its legs.
	_carried_to = spot

## The way a machine sits on the ground it is standing on: pointed along
## `facing`, pitched to the slope under its wheels and rolled to the slope
## across them.
##
## Sampled at the machine's own size rather than at a fixed distance: a quad is
## wider than a bicycle and should notice a rut a bicycle straddles.
func _lie_on_the_ground(at: Vector3, facing: float, kind: StringName) -> Basis:
	var turn := Basis(Vector3.UP, facing)
	var ahead := turn * Vector3(0.0, 0.0, -1.0)
	var across := turn * Vector3(1.0, 0.0, 0.0)
	var half_long: float = (MountKinds.body_box(kind)[0] as Vector3).z * 0.5
	var half_wide := maxf(MountKinds.girth(kind), 0.2)

	var front := field.height_at(at.x + ahead.x * half_long, at.z + ahead.z * half_long)
	var back := field.height_at(at.x - ahead.x * half_long, at.z - ahead.z * half_long)
	var right := field.height_at(at.x + across.x * half_wide, at.z + across.z * half_wide)
	var left := field.height_at(at.x - across.x * half_wide, at.z - across.z * half_wide)

	# Held to a limit, so that a wheel over a boulder does not stand the
	# machine on its nose.
	var pitch := clampf(atan2(back - front, half_long * 2.0), -LIE_LIMIT, LIE_LIMIT)
	var roll := clampf(atan2(right - left, half_wide * 2.0), -LIE_LIMIT, LIE_LIMIT)
	return turn * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, roll)

## How far a machine will tip to the ground under it.
const LIE_LIMIT := deg_to_rad(26.0)

## How fast the ridden mount is going, smoothed, and where in its stride it is.
var _pace := 0.0
var _stride := 0.0
var _idle := 0.0
## Where `carry` last put the ridden mount, and where it was the frame
## before: the two and the frame's own delta are what its speed is.
var _carried_to := Vector3.ZERO
var _paced_from := Vector3.ZERO

## Stride length in metres per full cycle, and how far a leg swings at full
## pace. A trot: the diagonal pairs move together.
const STRIDE_METRES := 2.6
const LEG_SWING := deg_to_rad(32.0)

func _process(delta: float) -> void:
	# Every horse nobody is riding grazes, whether or not one of them is being
	# ridden: four horses frozen mid-mouthful while you ride the fifth is worse
	# than none of them grazing at all.
	_graze(delta)
	if riding == &"":
		_settle_the_last_one(delta)
		return
	if not exists(riding) or MountKinds.kind_of(riding) != MountKinds.HORSE:
		return
	var body := (_nodes[riding] as Node3D).get_node_or_null("Body") as Node3D
	if body == null:
		return
	# The pace, from how far it was carried since the last frame. Smoothed, so
	# one odd frame does not kick the legs.
	if delta > 0.0:
		var moved := Vector2(_carried_to.x - _paced_from.x, _carried_to.z - _paced_from.z).length() / delta
		_pace = lerpf(_pace, minf(moved, 14.0), 1.0 - exp(-8.0 * delta))
		_paced_from = _carried_to
	# A stationary horse settles its legs and stands; a moving one strides,
	# faster the faster it goes, and its body rises and falls with each beat.
	var effort := clampf(_pace / MountKinds.speed(MountKinds.HORSE), 0.0, 1.3)
	# A trot up to about half pace, breaking into a gallop above it: at a
	# trot the diagonal pairs move together; at a gallop the front legs reach
	# together and the hind legs drive together a beat behind, the stride
	# lengthens, and the whole body rocks and lifts. Blended, so the change
	# of gait is a change and not a switch.
	var gallop := smoothstep(0.5, 0.95, effort)
	var stride_metres := lerpf(STRIDE_METRES, STRIDE_METRES * 1.7, gallop)
	_stride = fmod(_stride + delta * TAU * _pace / stride_metres, TAU)
	var reach := LEG_SWING * clampf(effort * 1.6, 0.0, 1.0) * lerpf(1.0, 1.5, gallop)
	if effort < 0.02:
		reach = 0.0
	for i in MountKinds.HORSE_HIPS.size():
		var leg := body.get_node_or_null("Leg%d" % i) as Node3D
		if leg == null:
			continue
		var diagonal := 1.0 if (i == 0 or i == 3) else -1.0
		var trot_swing := sin(_stride) * diagonal
		var is_front := i < 2
		var gallop_swing := sin(_stride if is_front else _stride + PI * 0.55) * (1.0 if is_front else -0.85)
		var swing := lerpf(trot_swing, gallop_swing, gallop) * reach
		leg.rotation.x = lerp_angle(leg.rotation.x, swing, 1.0 - exp(-14.0 * delta))
	body.position.y = absf(sin(_stride)) * lerpf(0.07, 0.16, gallop) * effort
	body.rotation.x = sin(_stride) * lerpf(0.02, 0.06, gallop) * effort
	# The head nods with the stride and the tail swings behind; standing,
	# both stir a little, because a horse is never quite still.
	var head := body.get_node_or_null("Head") as Node3D
	if head != null:
		var idle_nod := sin(_idle * 0.9) * 0.03
		head.rotation.x = lerp_angle(head.rotation.x, sin(_stride + 0.6) * 0.06 * effort + idle_nod, 1.0 - exp(-10.0 * delta))
	var tail := body.get_node_or_null("Tail") as Node3D
	if tail != null:
		var sway := sin(_stride * 0.5) * 0.18 * effort + sin(_idle * 1.3) * 0.08
		tail.rotation.y = lerp_angle(tail.rotation.y, sway, 1.0 - exp(-8.0 * delta))
		tail.rotation.x = lerp_angle(tail.rotation.x, -0.15 * effort, 1.0 - exp(-4.0 * delta))
	_idle += delta

## Where the ridden horse's legs are, for the checks: the swing of each, in
## radians.
func leg_swings() -> Array[float]:
	var out: Array[float] = []
	if riding == &"" or not exists(riding):
		return out
	var body := (_nodes[riding] as Node3D).get_node_or_null("Body") as Node3D
	if body == null:
		return out
	for i in MountKinds.HORSE_HIPS.size():
		var leg := body.get_node_or_null("Leg%d" % i) as Node3D
		out.append(0.0 if leg == null else leg.rotation.x)
	return out

## Get off. The mount is left standing beside where the player got off, which
## is how a child expects to find it again — beside, not underneath: put down
## on the spot and made solid in the same frame, its body had the child
## inside it, and the physics server pushed them up into the air with the
## horse stuck under their feet. It becomes solid again once the child has
## stepped clear; see `watch`.
func dismount(at: Vector3, facing := 0.0) -> StringName:
	if riding == &"":
		return &""
	var kind := riding
	riding = &""
	# Its legs are wherever the last stride left them. A horse got off at a
	# gallop stood with its hind legs cocked out behind it for ever, because
	# nothing moved them once nobody was riding it.
	_settling = kind
	var node: Node3D = _nodes[kind]
	if is_instance_valid(node):
		# A stride to the rider's right: forward is (-sin, 0, -cos), so right
		# is (cos, 0, -sin).
		var spot := at + Vector3(cos(facing), 0.0, -sin(facing)) * STEP_ASIDE
		spot.y = _rest_height(kind, spot)
		node.global_position = spot
		node.rotation.y = facing
		_positions[kind] = spot
	_waiting_to_be_solid[kind] = true
	dismounted.emit(kind)
	return kind

## Turn `count` horses out across the valley: one near the camp, so the first
## afternoon has one to find, and the rest spread evenly round it at a
## distance, each on dry, gentle, unreserved ground.
##
## Spread by bearing rather than at random: five horses scattered at random
## cluster, and a child who walks half an hour in one direction should find
## one there rather than four behind them.
func turn_out_horses(count: int, camp: Vector3, near: Vector3) -> void:
	# Spread over the whole valley rather than round one ring: with five of
	# them a single ring read as a spread, and with twenty it reads as a fence.
	# Two rings and a drift outwards, each horse on its own bearing.
	for i in count:
		var spot: Vector3
		if i == 0:
			# The near one is put a few paces off, but it has to stand on the
			# same kind of ground as the rest: the fixed offset it used to get
			# put it in the shallows of the river on this seed, and nobody
			# noticed because nothing checked.
			spot = _nearby_grazing_spot(camp, near)
		else:
			# The golden angle, so however many there are they never line up.
			var bearing := TAU * float(i) * 0.618 + 0.6
			spot = _grazing_spot(camp, bearing, 110.0 + 24.0 * float(i % 7))
		# Facing worked out from where it stands rather than drawn at random:
		# two children on two phones share a valley, and a horse cannot be
		# facing two ways at once.
		place(MountKinds.horse_id(i), spot, fmod(spot.x * 0.37 + spot.z * 0.11, TAU))

## Somewhere within sight of where a child wakes up that a horse would stand.
## Tries a few paces off first, then rings further out.
func _nearby_grazing_spot(camp: Vector3, near: Vector3) -> Vector3:
	var offered := near + Vector3(7.0, 0.0, -5.0)
	if _stands_here(camp, offered):
		return offered
	for ring in 3:
		var out := 9.0 + 5.0 * float(ring)
		for step in 12:
			var bearing := TAU * float(step) / 12.0
			var at := near + Vector3(cos(bearing), 0.0, sin(bearing)) * out
			if _stands_here(camp, at):
				return at
	return offered

## Somewhere along a bearing from the camp that a horse would stand: dry,
## gentle, out of the places, and not in the middle of a wood. Walks outwards
## from the wanted distance until it finds one.
func _grazing_spot(camp: Vector3, bearing: float, wanted: float) -> Vector3:
	var out := Vector3(cos(bearing), 0.0, sin(bearing))
	var walked := wanted
	while walked < wanted + 220.0:
		var at := camp + out * walked
		if _stands_here(camp, at):
			return at
		walked += 12.0
	# Nothing along that bearing: cast about round the spot it should have
	# been. The old answer was to give up and return the point anyway, which
	# stood horses in the river and in the lake — with five of them the bearing
	# nearly always found somewhere, and with twenty it does not.
	for ring in 8:
		var radius := 20.0 + 25.0 * float(ring)
		for step in 16:
			var around := TAU * float(step) / 16.0 + float(ring)
			var at := camp + out * wanted + Vector3(cos(around), 0.0, sin(around)) * radius
			if _stands_here(camp, at):
				return at
	return _nearby_grazing_spot(camp, camp + out * (wanted * 0.4))

## Would a horse stand here? Dry and well clear of the river, gentle enough to
## graze on, below the trees, out of the fenced places and not in a thicket.
func _stands_here(camp: Vector3, at: Vector3) -> bool:
	# Not in a pond. A raised pond's bed is well above the world's waterline,
	# so a test against that alone called the middle of the lake dry meadow and
	# turned a horse out in it — where a child swimming past was trapped
	# between the animal and the bank.
	if field.is_pond(at.x, at.z):
		return false
	var ground := field.height_at(at.x, at.z)
	if ground < field.water_level_at(at.x, at.z) + 1.2 or ground > HeightField.TREELINE - 30.0:
		return false
	if field.steepness_at(at.x, at.z) > 0.3:
		return false
	if PlaceSpec.reserved(at.x, at.z, camp):
		return false
	if field.forest_density_at(at.x, at.z) > 0.35:
		return false
	return absf(at.x - field.river_centre_x(at.z)) > 24.0

## Is this somewhere a mount is stuck in the water?
##
## A pond, and only a pond. The river is fordable and a horse left standing in
## it is a horse where its rider left it — but a pond is still water with a
## bank round it, and a solid animal out in the middle of one is something a
## swimming child gets trapped against.
func _is_in_water(at: Vector3) -> bool:
	return field.is_pond(at.x, at.z)

## The nearest dry ground, searched outwards in rings. A mount found in the
## water is put on the bank rather than deleted: it is somebody's horse.
##
## Dry ground, not good grazing. The first version asked `_stands_here`, which
## wants ground a good metre above the water because that is where a horse is
## worth turning out — and a lake's beach stands half a metre above it, so
## every bank round the pond was refused and the horse stayed in the water.
func _walk_out_of_the_water(at: Vector3) -> Vector3:
	for ring in 30:
		var out := 4.0 + 5.0 * float(ring)
		for step in 16:
			var bearing := TAU * float(step) / 16.0
			var spot := at + Vector3(cos(bearing), 0.0, sin(bearing)) * out
			if _is_dry_footing(spot):
				return spot
	return at

## Somewhere a mount can simply stand: out of the water and not up a cliff.
func _is_dry_footing(at: Vector3) -> bool:
	if field.is_pond(at.x, at.z):
		return false
	if field.height_at(at.x, at.z) < field.water_level_at(at.x, at.z) + 0.2:
		return false
	return field.steepness_at(at.x, at.z) < 0.5

## How many horses are turned out. For the checks.
func horse_count() -> int:
	var count := 0
	for kind in _nodes:
		if MountKinds.kind_of(kind) == MountKinds.HORSE and is_instance_valid(_nodes[kind]):
			count += 1
	return count

## The last place riding was allowed, so that being put down never means being
## put down inside a hillside.
##
## A mount ridden somewhere it cannot go sets its rider on their feet, which is
## right — better than being stranded halfway up a cliff. But it did it where
## they were standing, and where they were standing was the slope that refused
## them: on a motorcycle a child ended up in the ground rather than on it.
var _last_good := Vector3(1e9, 1e9, 1e9)

## Remember somewhere a mount was happy. Called every frame by the game.
func note_good_ground(at: Vector3) -> void:
	_last_good = at

## Where to put a rider who has to be put down: the last ground their mount was
## willing to stand on, or where they are if there is no such place yet.
func safe_ground(at: Vector3) -> Vector3:
	if _last_good.x > 1e8:
		return at
	return _last_good

## How far aside a dismounted mount is put, and how far the child must be
## from it before it becomes something to bump into again.
const STEP_ASIDE := 1.8
const CLEAR_OF_IT := 2.4

## Mounts that have been got off and are not solid yet, by kind.
var _waiting_to_be_solid: Dictionary = {}

## Called every frame with where the child is. A mount just got off becomes
## solid again once they are clear of it.
func watch(player_position: Vector3) -> void:
	if _waiting_to_be_solid.is_empty():
		return
	for kind in _waiting_to_be_solid.keys():
		if not exists(kind):
			_waiting_to_be_solid.erase(kind)
			continue
		var flat: Vector3 = _positions[kind] - player_position
		flat.y = 0.0
		if flat.length() > CLEAR_OF_IT:
			_set_solid(kind, true)
			_waiting_to_be_solid.erase(kind)

## Bring a mount that has just been got off back to standing: legs straight,
## body level, head and tail still. Eased rather than snapped, so a horse
## that stops reads as one settling rather than one switching off.
var _settling := &""

func _settle_the_last_one(delta: float) -> void:
	if _settling == &"" or not exists(_settling):
		_settling = &""
		return
	var body := (_nodes[_settling] as Node3D).get_node_or_null("Body") as Node3D
	if body == null:
		_settling = &""
		return
	var weight := 1.0 - exp(-6.0 * delta)
	var still := true
	for i in MountKinds.HORSE_HIPS.size():
		var leg := body.get_node_or_null("Leg%d" % i) as Node3D
		if leg == null:
			continue
		leg.rotation.x = lerp_angle(leg.rotation.x, 0.0, weight)
		if absf(leg.rotation.x) > 0.005:
			still = false
	body.position.y = lerpf(body.position.y, 0.0, weight)
	body.rotation.x = lerpf(body.rotation.x, 0.0, weight)
	var head := body.get_node_or_null("Head") as Node3D
	if head != null:
		head.rotation.x = lerp_angle(head.rotation.x, 0.0, weight)
	var tail := body.get_node_or_null("Tail") as Node3D
	if tail != null:
		tail.rotation.y = lerp_angle(tail.rotation.y, 0.0, weight)
		tail.rotation.x = lerp_angle(tail.rotation.x, 0.0, weight)
	if still and absf(body.position.y) < 0.005:
		_settling = &""

## How far the nose drops to graze, how long it stays down, and how long the
## horse lifts it to look around: a grazing animal is mostly nose-down with the
## occasional glance up, and the difference between those two is the whole of
## what grazing looks like from across a meadow.
##
## A drop, not a rotation: the head is drawn out along -Z, so turning the joint
## by a positive angle about +X throws the nose UP and back over the withers,
## which is what the first version did — a horse rearing its head at the sky
## rather than one eating grass. The angle goes in negative, and a check
## measures where the nose actually ends up rather than what the angle says.
##
## Sixty degrees is as far as it goes, and the limit is the horse rather than
## the number. The neck is about half the length a real horse of this height
## has, and the joint it turns on is the shoulder, so the further the nose
## drops the closer it comes to the chest: at fifty-two the muzzle hung level
## with the chest and read as an animal sniffing the air, and at seventy-four
## it folded into the chest and the neck disappeared. Sixty puts the nose a
## metre down and still clear in front of the body, which is what a check
## holds it to — derived from the body's own box, so a later, longer-necked
## horse can graze lower without anybody retuning a number by eye.
const GRAZE_DOWN := deg_to_rad(60.0)
const GRAZE_LOOKS_UP_EVERY := 9.0
const GRAZE_LOOKS_UP_FOR := 2.6

var _grazing_time := 0.0

## Every horse nobody is riding grazes: head down, up now and then, tail
## swinging. Cheap — a rotation each on a handful of nodes.
func _graze(delta: float) -> void:
	_grazing_time += delta
	for kind in _nodes:
		if MountKinds.kind_of(kind) != MountKinds.HORSE or kind == riding:
			continue
		# The one just got off is being eased back to standing; it can put its
		# head down once it has.
		if kind == _settling:
			continue
		var node = _nodes[kind]
		if not is_instance_valid(node):
			continue
		var body := (node as Node3D).get_node_or_null("Body") as Node3D
		if body == null:
			continue
		# Each on its own clock, so a field of horses does not lift its heads
		# in unison.
		var offset := float(MountKinds.which(kind)) * 3.1
		var cycle := fmod(_grazing_time + offset, GRAZE_LOOKS_UP_EVERY)
		var looking_up := cycle < GRAZE_LOOKS_UP_FOR
		var head := body.get_node_or_null("Head") as Node3D
		if head != null:
			var wanted := 0.0 if looking_up else -GRAZE_DOWN
			head.rotation.x = lerp_angle(head.rotation.x, wanted, 1.0 - exp(-2.5 * delta))
		var tail := body.get_node_or_null("Tail") as Node3D
		if tail != null:
			tail.rotation.y = sin((_grazing_time + offset) * 1.3) * 0.14

## How far a horse's nose is dropped from level, in radians: positive when it
## is down where the grass is. For the checks.
func head_angle(kind: StringName) -> float:
	var head := _head_of(kind)
	return 0.0 if head == null else -head.rotation.x

## Where the horse's nose is, in world space. This is what tells a head put
## down to graze from one thrown back over the withers — the angle alone
## cannot, which is how the first version of grazing shipped.
func nose_at(kind: StringName) -> Vector3:
	var head := _head_of(kind)
	if head == null or head.mesh == null:
		return Vector3.ZERO
	# The muzzle is the far end of the head's own box, out along -Z.
	var box := head.mesh.get_aabb()
	var muzzle := Vector3(box.get_center().x, box.get_center().y, box.position.z)
	return head.global_transform * muzzle

## How far the muzzle is out in front of the horse itself, along the way it is
## facing. This is the other half of telling grazing from rearing: turning the
## joint down brings the nose closer to the chest as well as lower, but it
## stays in front of the animal — a head thrown back over the withers does not.
func nose_ahead(kind: StringName) -> float:
	var head := _head_of(kind)
	if head == null:
		return 0.0
	var node: Node3D = _nodes[kind]
	var forward := Vector3.FORWARD.rotated(Vector3.UP, node.rotation.y)
	return (nose_at(kind) - node.global_position).dot(forward)

func _head_of(kind: StringName) -> MeshInstance3D:
	if not exists(kind):
		return null
	var body := (_nodes[kind] as Node3D).get_node_or_null("Body") as Node3D
	if body == null:
		return null
	return body.get_node_or_null("Head") as MeshInstance3D

## How far a standing mount's legs are from straight, in radians. For the
## checks.
func legs_at_rest() -> float:
	if _settling == &"" and riding == &"":
		return 0.0
	var kind := _settling if _settling != &"" else riding
	if not exists(kind):
		return 0.0
	var body := (_nodes[kind] as Node3D).get_node_or_null("Body") as Node3D
	if body == null:
		return 0.0
	var worst := 0.0
	for i in MountKinds.HORSE_HIPS.size():
		var leg := body.get_node_or_null("Leg%d" % i) as Node3D
		if leg != null:
			worst = maxf(worst, absf(leg.rotation.x))
	return worst

## Whether a standing mount stops the child. Off while it is ridden, or the
## collider carried under the child would shove them along.
func _set_solid(kind: StringName, solid: bool) -> void:
	if not exists(kind):
		return
	var body := (_nodes[kind] as Node3D).get_node_or_null("Solid") as StaticBody3D
	if body != null:
		body.collision_layer = TerrainSpec.LAYER_PROPS if solid else 0

## Is this mount solid right now? For the checks.
func is_solid(kind: StringName) -> bool:
	if not exists(kind):
		return false
	var body := (_nodes[kind] as Node3D).get_node_or_null("Solid") as StaticBody3D
	return body != null and body.collision_layer != 0

## Whether the ground here can be ridden over on the current mount. A bicycle
## refuses a steep hill and deep water; a horse takes both; a boat wants
## water under its keel and nothing else — which is how it puts a child down
## on the far shore.
func can_ride_over(kind: StringName, at: Vector3) -> bool:
	if MountKinds.floats(kind):
		return (
			field.height_at(at.x, at.z)
			< field.water_level_at(at.x, at.z) - MountKinds.BOAT_DRAFT
		)
	# Not into the swimming pool, and not inside its fence either. A horse
	# fords a river, but the pool is a hole with walls: one ridden into it
	# stuck in the excavation while its rider floated free of it. Stopping at
	# the water's edge was not enough — the poolside inside the fence is
	# ordinary ground, so a horse could be ridden in through the gate and stand
	# among the loungers, and a rider who got in that way was never asked for a
	# ticket.
	# The bridge. It is the one place a wheeled machine may be over water, and
	# the one place the ground underneath it has nothing to say about whether
	# it can be ridden: the deck is level enough for anything, and the bank it
	# arches over is not.
	if field.is_on_the_bridge(at):
		return true

	var camp := field.camp_centre()
	# Nothing is ridden indoors. A quad went into the shop and stood between
	# the shelves, which is funny once and then is a machine parked on the
	# floor of a building a child has to walk round.
	if PlaceSpec.indoors(at.x, at.z, camp):
		return false
	if PlaceSpec.excavation(at.x, at.z, camp) > 0.4:
		return false
	if PlaceSpec.inside_the_pool_fence(at.x, at.z, camp):
		return false
	if MountKinds.fords_water(kind):
		return field.steepness_at(at.x, at.z) <= _grip(kind)
	if at.y < field.water_level_at(at.x, at.z) + 0.4:
		return false
	return field.steepness_at(at.x, at.z) <= _grip(kind)

## The steepest ground this mount will take here and now — its own limit, plus
## the saddle if there is one under the rider. Only a horse is helped: a girth
## does nothing for a bicycle.
func _grip(kind: StringName) -> float:
	var limit := MountKinds.max_slope(kind)
	if saddled and MountKinds.kind_of(kind) == MountKinds.HORSE:
		limit += SADDLE_GRIP
	return limit

func to_data() -> Dictionary:
	var out: Dictionary = {}
	for kind in _positions:
		var at: Vector3 = _positions[kind]
		out[String(kind)] = [at.x, at.y, at.z]
	return out

func from_data(data: Dictionary) -> void:
	for key in data:
		var entry = data[key]
		if not (entry is Array and entry.size() >= 3):
			continue
		var id := StringName(key)
		# Saves written before there was a herd name their one horse "horse".
		# It becomes the first of the herd rather than a sixth animal with no
		# number, which nothing else would ever look for.
		if id == MountKinds.HORSE:
			id = MountKinds.horse_id(0)
		var at := Vector3(float(entry[0]), float(entry[1]), float(entry[2]))
		# A horse saved standing in water comes out of it. Worlds written
		# before the ponds had their own water level have horses in the middle
		# of a lake — the test for dry ground compared against the world's
		# waterline, and a raised pond's bed is well above that — and a solid
		# animal out in the water is something a swimming child gets trapped
		# against. Boats stay where they are; a boat in a lake is a boat.
		if not MountKinds.floats(id) and _is_in_water(at):
			at = _walk_out_of_the_water(at)
		place(id, at)
