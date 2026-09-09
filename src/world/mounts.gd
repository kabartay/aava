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
	node.rotation.y = facing
	_nodes[kind] = node
	_positions[kind] = grounded

## Where a mount rests: on the ground, or, for a boat, on the water wherever
## the ground is under it. A boat left in the shallows sat on the bed with
## its hull half under, until this.
func _rest_height(kind: StringName, at: Vector3) -> float:
	var ground := field.height_at(at.x, at.z)
	if MountKinds.floats(kind):
		return maxf(ground, HeightField.WATER_LEVEL)
	# A horse in water over its head swims: it floats with most of its barrel
	# under and its withers clear, rather than walking along the bottom. It
	# used to walk the bottom while its rider floated at the surface, and the
	# two came apart with a gap of open water between them.
	if swims(kind) and HeightField.WATER_LEVEL - ground > MountKinds.HORSE_SWIMS_AT:
		return HeightField.WATER_LEVEL - MountKinds.HORSE_DRAUGHT
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
	return HeightField.WATER_LEVEL - field.height_at(at.x, at.z) > MountKinds.HORSE_SWIMS_AT

## Where a rider *stands* while their mount swims — which is where the horse
## itself is, not where its saddle is.
##
## A rider's body is drawn `MountKinds.eye_lift` above their own position:
## on land they stand on the ground the horse stands on and the drawing puts
## them in the saddle. Held at the saddle's own height instead, that lift was
## added a second time and the child floated a body's length above the horse.
static func saddle_afloat() -> float:
	return HeightField.WATER_LEVEL - MountKinds.HORSE_DRAUGHT

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
			var under := HeightField.WATER_LEVEL - field.height_at(probe.x, probe.z)
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
	node.rotation.y = facing
	_positions[riding] = spot
	# How fast it is going is worked out in _process, where there is a delta
	# worth dividing by. It was worked out here from get_process_delta_time(),
	# which in a headless check is the editor's idle rate — 0.14 s — so a
	# horse carried three metres a second was measured at a third of one, and
	# the gait check passed a horse that barely moved its legs.
	_carried_to = spot

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
	for i in count:
		var spot: Vector3
		if i == 0:
			# The near one is put a few paces off, but it has to stand on the
			# same kind of ground as the rest: the fixed offset it used to get
			# put it in the shallows of the river on this seed, and nobody
			# noticed because nothing checked.
			spot = _nearby_grazing_spot(camp, near)
		else:
			var bearing := TAU * float(i - 1) / float(maxi(count - 1, 1)) + 0.6
			spot = _grazing_spot(camp, bearing, 140.0 + 60.0 * float(i % 3))
		place(MountKinds.horse_id(i), spot, randf() * TAU)

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
	var fallback := camp + out * wanted
	while walked < wanted + 220.0:
		var at := camp + out * walked
		if _stands_here(camp, at):
			return at
		walked += 12.0
	return fallback

## Would a horse stand here? Dry and well clear of the river, gentle enough to
## graze on, below the trees, out of the fenced places and not in a thicket.
func _stands_here(camp: Vector3, at: Vector3) -> bool:
	var ground := field.height_at(at.x, at.z)
	if ground < HeightField.WATER_LEVEL + 1.2 or ground > HeightField.TREELINE - 30.0:
		return false
	if field.steepness_at(at.x, at.z) > 0.3:
		return false
	if PlaceSpec.reserved(at.x, at.z, camp):
		return false
	if field.forest_density_at(at.x, at.z) > 0.35:
		return false
	return absf(at.x - field.river_centre_x(at.z)) > 24.0

## How many horses are turned out. For the checks.
func horse_count() -> int:
	var count := 0
	for kind in _nodes:
		if MountKinds.kind_of(kind) == MountKinds.HORSE and is_instance_valid(_nodes[kind]):
			count += 1
	return count

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

## How long a horse keeps its head down, and how long it lifts it to look
## around: a grazing animal is mostly nose-down with the occasional glance up,
## and the difference between those two is the whole of what grazing looks
## like from across a meadow.
const GRAZE_DOWN := deg_to_rad(52.0)
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
			var wanted := 0.0 if looking_up else GRAZE_DOWN
			head.rotation.x = lerp_angle(head.rotation.x, wanted, 1.0 - exp(-2.5 * delta))
		var tail := body.get_node_or_null("Tail") as Node3D
		if tail != null:
			tail.rotation.y = sin((_grazing_time + offset) * 1.3) * 0.14

## Whether a horse has its head down grazing right now. For the checks.
func head_angle(kind: StringName) -> float:
	if not exists(kind):
		return 0.0
	var body := (_nodes[kind] as Node3D).get_node_or_null("Body") as Node3D
	if body == null:
		return 0.0
	var head := body.get_node_or_null("Head") as Node3D
	return 0.0 if head == null else head.rotation.x

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
		return field.height_at(at.x, at.z) < HeightField.WATER_LEVEL - MountKinds.BOAT_DRAFT
	# Not into the swimming pool. A horse fords a river, but the pool is a
	# hole with walls: one ridden into it stuck in the excavation while its
	# rider floated free of it.
	if PlaceSpec.excavation(at.x, at.z, field.camp_centre()) > 0.4:
		return false
	if MountKinds.fords_water(kind):
		return field.steepness_at(at.x, at.z) <= MountKinds.max_slope(kind)
	if at.y < HeightField.WATER_LEVEL + 0.4:
		return false
	return field.steepness_at(at.x, at.z) <= MountKinds.max_slope(kind)

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
		place(id, Vector3(float(entry[0]), float(entry[1]), float(entry[2])))
