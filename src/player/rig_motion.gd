class_name RigMotion
extends RefCounted

## How a child on the shared rig (Character) moves: a walk and a run, breathing
## and a glance round, a jump, a kick, swimming strokes, a dive and a cheer, all
## worked out each frame from a handful of numbers and written straight onto the
## joints. There are no animation files: a pose is a few sines and a few
## weights, which is also why it is cheap. A frame is a few rotations per joint
## and no allocation (the joints are looked up once, and everything else is a
## float), and the checks hold it to that.
##
## The owner (the player's own body, or a visitor) sets the inputs below and
## calls step(). The rig is turned as a whole by its owner for the swim and
## ride leans; nothing here leans the rig itself, only the joints inside it, so
## a stroke is made relative to the lean and never against it.
##
## Turning a joint about X by a positive angle swings what hangs from it
## forwards (the rig faces -Z): a thigh forward, a shin kicked back is negative.
## About Z a positive angle moves a limb towards +X, which is out for the right
## arm and in for the left.

## What the owner tells it, every frame.
var speed := 0.0
var airborne := false
var swimming := false
var diving := false
## Held on a mount or a ride: the stride stops and the arms stay quiet.
var riding := false
## How the child is carried, if they are sitting: the name of a pose in SeatPose
## (a mount's kind, or a ride's name), or empty on foot. Blended in and out in a
## fraction of a second, so getting on and off is a settling and not a jump.
var seat: StringName = &""
## How fast whatever carries the child is going, in metres a second: the horse's
## stride, the bicycle's pedals and the boat's strokes keep time with it.
var gait := 0.0
## For a ride, where the seat is in the world: the place its pose is written
## about (the origin is where the child's feet would stand on the footing, the
## basis the way the seat faces and tips). The rig is moved and turned to it, so
## that the hips are on the seat and not where the child happened to be
## standing. A mount needs none: the rig is already at its saddle.
var seat_placed := false
var seat_place := Transform3D()
## Winding up a kick, and how far.
var winding := false
var charge := 0.0

var _rig: Node3D
var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _upper: Array[Node3D] = []
var _fore: Array[Node3D] = []
var _thigh: Array[Node3D] = []
var _shin: Array[Node3D] = []
var _foot: Array[Node3D] = []
var _hand: Array[Node3D] = []
## The meshes of the upper arms and forearms, left then right, which are drawn
## longer when the seat is further off than an arm reaches.
var _arm_mesh: Array[Node3D] = []
var _hips_rest := 0.0
## How far the hips hang below their joint, for this rig's own pelvis.
var _pelvis := SeatPose.PELVIS
## The arm's own lengths as built: shoulder to elbow, and elbow to wrist.
var _arm_a := 0.16
var _arm_b := 0.15

## Eased state.
var _speed := 0.0
var _phase := 0.0
var _clock := 0.0
var _air := 0.0
var _swim := 0.0
var _dive := 0.0
var _squash := 0.0
var _wind := 0.0
var _kick_age := -1.0
var _cheer := 0.0
## Sitting: how far into the pose (0 to 1), which pose it is, whether the limbs
## have been left in it, and the clocks of what moves while it is held.
var _sit := 0.0
var _sat: StringName = &""
var _posed := false
var _bounce := 0.0
var _pedal := 0.0
var _stroke := 0.0
## A swing: how far its seat is tipped, last frame (a pendulum's seat leans
## front-high at the front of its swing), whether that is known, and how much
## the legs are stretched out (1) or tucked in under it (0).
var _tilt := 0.0
var _tilt_known := false
var _pump := 0.5
## What the seat's place has added to the rig so far, taken off again as it goes.
var _applied := Vector3.ZERO
var _placed := false
## What the limb solver hands back, so that a frame allocates nothing.
var _first := Quaternion()
var _second := Quaternion()
var _second_basis := Basis()

## How long the kick's follow-through takes to die away, in seconds, and how
## long a cheer lasts.
const KICK_FOLLOW := 0.55
const CHEER_FOR := 1.5

## How long it takes to settle into a seat or to climb out of one, in seconds.
const SIT_TIME := 0.2

func _init(rig: Node3D) -> void:
	_rig = rig
	_hips = rig.find_child("Hips", true, false)
	_torso = rig.find_child("Torso", true, false)
	_head = rig.find_child("Head", true, false)
	for tag: String in ["L", "R"]:
		_upper.append(rig.find_child("UpperArm" + tag, true, false))
		_fore.append(rig.find_child("Forearm" + tag, true, false))
		_thigh.append(rig.find_child("Thigh" + tag, true, false))
		_shin.append(rig.find_child("Shin" + tag, true, false))
		_foot.append(rig.find_child("Foot" + tag, true, false))
		_hand.append(rig.find_child("Hand" + tag, true, false))
		_arm_mesh.append(_upper[_upper.size() - 1].get_node("Mesh"))
		_arm_mesh.append(_fore[_fore.size() - 1].get_node("Mesh"))
	_hips_rest = _hips.position.y
	_arm_a = -_fore[0].position.y
	_arm_b = -_hand[0].position.y
	var pelvis := _hips.get_node_or_null("Mesh") as MeshInstance3D
	if pelvis != null and pelvis.mesh != null:
		# As far as the girl's skort hangs (0.16): a hem that is let through the
		# seat is a skirt sunk in the saddle, and she is put up on it instead.
		_pelvis = clampf(-pelvis.mesh.get_aabb().position.y, SeatPose.PELVIS, 0.17)
	# Children out of step with one another, so that a row of them is not a
	# chorus line: the clock starts at a place of its own.
	_clock = float(rig.get_instance_id() % 997) * 0.01

## How far a thigh swings each way at this speed, in radians: nothing standing
## still, a stroll's worth at a walk, nearly a run's at a run. One place for the
## walk and for the check that holds it to growing with speed.
static func stride_of(pace: float) -> float:
	return clampf(0.10 + pace * 0.12, 0.0, 0.9) * smoothstep(0.0, 0.8, pace)

## How far through the kick's swing the foot is, `seconds` after the ball left:
## 1 at the very moment it leaves, and falling from there. The peak is the
## release, not the end of a swing that began with it, because the ball is
## already gone: a foot that arrives after the ball is a kick that missed.
static func kick_swing_at(seconds: float) -> float:
	return exp(-maxf(seconds, 0.0) * 7.0) if seconds <= KICK_FOLLOW else 0.0

## The ball has just left the child's foot.
func kick() -> void:
	_kick_age = 0.0
	_wind = 0.0

## The child's side has scored.
func cheer() -> void:
	_cheer = CHEER_FOR

## The child has just landed, this hard (metres a second).
func land(impact: float) -> void:
	_squash = clampf(impact / 10.0, 0.35, 1.0)

## How far through the kick the foot is now. For the checks.
func kick_swing() -> float:
	return kick_swing_at(_kick_age) if _kick_age >= 0.0 else 0.0

func step(delta: float) -> void:
	if not is_instance_valid(_rig):
		return
	# A limb left in a seat's pose by the last frame is cleared first: the stride
	# below writes only the angles it uses, and one left over from a quaternion
	# would be a twist the walk knew nothing about.
	if _posed:
		for side in 2:
			_thigh[side].rotation = Vector3.ZERO
			_shin[side].rotation = Vector3.ZERO
			_foot[side].rotation = Vector3.ZERO
			_upper[side].rotation = Vector3.ZERO
			_fore[side].rotation = Vector3.ZERO
	# Sitting, nothing swims, jumps or strides: the pose is the whole of it.
	var sitting := seat != &"" and SeatPose.POSES.has(seat)
	var swimming_now := swimming and not sitting
	_speed = lerpf(_speed, 0.0 if (riding or sitting) else speed, 1.0 - exp(-8.0 * delta))
	_air = move_toward(_air, 1.0 if airborne and not swimming_now and not sitting else 0.0, 9.0 * delta)
	_swim = move_toward(_swim, 1.0 if swimming_now else 0.0, 4.0 * delta)
	_dive = move_toward(_dive, 1.0 if (swimming_now and diving) else 0.0, 3.0 * delta)
	_squash = move_toward(_squash, 0.0, 4.5 * delta)
	_cheer = maxf(_cheer - delta, 0.0)
	_clock += delta

	# The kick: the wind-up while the button is held, the swing from the moment
	# of the release. The swing is read before its age moves on, so that the
	# first frame drawn after the ball leaves is the peak.
	var swing := 0.0
	if _kick_age >= 0.0:
		swing = kick_swing_at(_kick_age)
		_kick_age += delta
		if _kick_age > KICK_FOLLOW:
			_kick_age = -1.0
	elif winding:
		_wind = lerpf(_wind, 0.3 + 0.7 * clampf(charge, 0.0, 1.0), 1.0 - exp(-14.0 * delta))
	else:
		_wind = move_toward(_wind, 0.0, 6.0 * delta)
	var kicking := minf(maxf(swing, _wind) * 4.0, 1.0)

	var grounded := 1.0 - _air
	var amp := stride_of(_speed) * grounded * (1.0 - _swim)
	_phase += (5.0 + 2.6 * _speed) * delta
	if _phase > TAU:
		_phase -= TAU
	var s := sin(_phase)
	var c := cos(_phase)
	var still := (1.0 - clampf(_speed, 0.0, 1.0)) * grounded * (1.0 - _swim)
	var breath := sin(_clock * 1.7)
	var cheering := clampf(_cheer * 3.0, 0.0, 1.0)
	var pump := sin(_clock * 17.0)
	var hop := absf(sin(_clock * 9.0))

	# Idle: the chest rises and falls, and now and then the head turns to look
	# round, one way and then the other. Not while moving, nor while cheering.
	var turn := fposmod(_clock, 7.0)
	var glance := 0.0
	if turn > 4.5 and turn < 6.0:
		glance = sin((turn - 4.5) / 1.5 * PI) * (0.75 if int(_clock / 7.0) % 2 == 0 else -0.75)
	_head.rotation.y = glance * still * (1.0 - cheering)
	_head.rotation.x = -0.12 * amp

	# The body: leaning into a run, twisting with the stride, a little lower
	# where the legs are furthest apart, crouching on landing.
	_torso.rotation.x = (
		-0.28 * amp + 0.018 * breath * still + 0.12 * _wind - 0.10 * swing - 0.10 * _squash
	)
	_torso.rotation.y = 0.15 * amp * s
	_hips.position.y = (
		_hips_rest - 0.07 * amp * (1.0 - absf(c)) + 0.10 * hop * cheering - 0.03 * _squash
	)
	_rig.scale = Vector3(1.0 + 0.08 * _squash, 1.0 - 0.15 * _squash, 1.0 + 0.08 * _squash)

	for side in 2:
		var sign_of := 1.0 if side == 0 else -1.0
		var outward := -1.0 if side == 0 else 1.0
		# Opposite legs half a stride apart.
		var ss := s * sign_of
		var cc := c * sign_of

		var thigh := amp * ss
		var shin := -amp * 1.2 * maxf(0.0, cc)
		var arm := -amp * 1.1 * ss + 0.04 * breath * still
		var elbow := 0.12 + amp * 0.9
		var flare := 0.05 + 0.02 * breath * still

		# Swimming: the arms go round like a crawl, one half a turn behind the
		# other, and the legs flutter. Slower when treading water.
		if _swim > 0.0:
			var stroke := _clock * (3.2 + 1.6 * _speed) * 2.0 + (0.0 if side == 0 else PI)
			var flutter := sin(_clock * 14.0 + (0.0 if side == 0 else PI))
			thigh = lerpf(thigh, 0.35 * flutter, _swim)
			shin = lerpf(shin, -0.25 - 0.2 * flutter, _swim)
			arm = lerpf(arm, fposmod(stroke, TAU), _swim * (1.0 - _dive))
			elbow = lerpf(elbow, 0.3, _swim)
			flare = lerpf(flare, 0.12, _swim)
			# Diving: the arms together over the head, the legs straight and
			# kicking a little.
			arm = lerpf(arm, 2.9, _dive)
			flare = lerpf(flare, 0.10, _dive)
			thigh = lerpf(thigh, 0.12 * flutter, _dive)
			shin = lerpf(shin, -0.1, _dive)
			elbow = lerpf(elbow, 0.0, _dive)

		# A jump: knees up, arms thrown up and out. The landing's squash bends
		# the knees as well as shortening the whole.
		if _air > 0.0:
			thigh = lerpf(thigh, 0.95 if side == 0 else 0.55, _air)
			shin = lerpf(shin, -1.4 if side == 0 else -0.9, _air)
			arm = lerpf(arm, 2.0, _air)
			flare = lerpf(flare, 0.55, _air)
			elbow = lerpf(elbow, 0.3, _air)
		thigh += 0.55 * _squash
		shin -= 1.0 * _squash

		# The kick is the right leg's, with the left arm across.
		if side == 1:
			thigh = lerpf(thigh, -0.75 * _wind + 1.4 * swing, kicking)
			shin = lerpf(shin, -1.3 * _wind - 0.2 * swing, kicking)
		else:
			arm = lerpf(arm, 0.7 * _wind - 0.5 * swing, kicking)

		# A cheer: arms up in a V and pumping, the knees giving at each hop.
		if cheering > 0.0:
			arm = lerpf(arm, 2.7 + 0.25 * pump, cheering)
			flare = lerpf(flare, 0.45, cheering)
			elbow = lerpf(elbow, 0.35, cheering)
			shin = lerpf(shin, -0.4 * (1.0 - hop), cheering * 0.8)

		_thigh[side].rotation.x = thigh
		_shin[side].rotation.x = shin
		_foot[side].rotation.x = -0.7 * (thigh + shin) * grounded + 0.4 * _squash
		_upper[side].rotation.x = arm
		_upper[side].rotation.z = outward * flare
		_fore[side].rotation.x = elbow

	_seat_step(delta, sitting)

## Settle the body into the seat, or out of it: the pose is solved from where the
## hips, hands and feet go (see SeatPose), laid over what the stride and the
## swim have just written by `_sit`, so there is never a frame in which the child
## is in one and not the other.
func _seat_step(delta: float, sitting: bool) -> void:
	# Another pose is entered only from standing: one that is let go of first
	# and a new one taken up after, so a mount stepped straight onto a ride is
	# a settling and never a jump from one seat to the other.
	if sitting and _sat != seat and _sit <= 0.0:
		_sat = seat
	_sit = move_toward(_sit, 1.0 if (sitting and seat == _sat) else 0.0, delta / SIT_TIME)
	if _sit <= 0.0:
		_tilt_known = false
		if _posed:
			_rest_the_arms()
			_hips.position.x = 0.0
			_hips.position.z = 0.0
			_posed = false
		_place(0.0)
		return
	_posed = true
	var pose: Dictionary = SeatPose.POSES[_sat]
	var w := smoothstep(0.0, 1.0, _sit)
	var style: StringName = pose.get("style", &"")

	# What moves while it is held, keeping time with the carrier.
	var carry := clampf(gait / 3.0, 0.0, 1.0)
	_bounce += (4.0 + 0.8 * gait) * delta
	_stroke += (1.5 + 0.4 * gait) * delta
	if gait > 0.3:
		_pedal += gait * 1.1 * delta
	# A horse's stride rocks the body over the hips. The hips themselves stay on
	# the seat, which the horse lifts and lowers and the rider's carrier goes
	# with: a bob made here would be a bob against the saddle.
	var pitch := 0.0
	if style == &"rock":
		pitch = 0.05 * carry * sin(_bounce)
	# A swing is pumped with the legs the way a child does it: stretched out
	# and up while the seat is swinging forwards, tucked back under it on the
	# way back, so it is read from how the seat is tipping, which is what the
	# swing itself tells and needs nothing sent.
	if style == &"pump" and seat_placed:
		var tilt := asin(clampf((seat_place.basis.orthonormalized() * Vector3.FORWARD).y, -1.0, 1.0))
		var rate := (tilt - _tilt) / maxf(delta, 0.0001) if _tilt_known else 0.0
		_tilt = tilt
		_tilt_known = true
		_pump = lerpf(_pump, clampf(0.5 + 0.5 * rate / 0.6, 0.0, 1.0), 1.0 - exp(-10.0 * delta))
	else:
		_tilt_known = false
		_pump = 0.5

	var seat_at: Vector3 = pose["seat"]
	var hips_at := Vector3(seat_at.x, seat_at.y + _pelvis, seat_at.z)
	var reach: float = pose["reach"]
	var grip: Vector3 = pose["hand"]
	var lean: float = pose["lean"] + pitch
	# A body is as long as it is: the clay toy's chest is half again as tall as
	# the bear cub's, and the same lean that puts one's hands on the bars leaves
	# the other's in the air. So the lean is taken as far further forward as the
	# hands need, a tenth of a radian at a time, up to six tenths.
	var shoulder_at := _upper[0].position
	for _try in 7:
		var to_grip := grip - (hips_at + _torso.position + Basis(Vector3.RIGHT, -lean) * shoulder_at)
		if to_grip.length() <= (_arm_a + _arm_b) * reach * 0.96:
			break
		lean += 0.1
	var torso_basis := Basis(Vector3.RIGHT, -lean)
	var shoulder_origin := hips_at + _torso.position
	_hips.position = Vector3(hips_at.x * w, lerpf(_hips.position.y, hips_at.y, w), hips_at.z * w)
	_torso.rotation.x = lerpf(_torso.rotation.x, -lean, w)
	_torso.rotation.y = lerpf(_torso.rotation.y, 0.0, w)
	_head.rotation.x = lerpf(_head.rotation.x, float(pose["nod"]) + (lean - float(pose["lean"]) - pitch) * 0.8, w)

	var stretch := lerpf(1.0, reach, w)
	var ankle: Vector3 = pose["foot"]
	var knee: Vector3 = pose["knee"]
	var elbow: Vector3 = pose["elbow"]
	var toe: float = pose["toe"]
	var turn := _pedal
	var radius: float = pose.get("pedal_radius", 0.0)
	for side in 2:
		var mirror := -1.0 if side == 0 else 1.0
		# The left side is what the pose says, the right its mirror.
		var hand_goal := Vector3(grip.x * -mirror, grip.y, grip.z)
		var foot_goal := Vector3(ankle.x * -mirror, ankle.y, ankle.z)
		if style == &"pedal":
			# The right pedal is half a turn from the left, and the crank
			# goes round in the plane of the bicycle.
			var angle := turn + (0.0 if side == 0 else PI)
			foot_goal += Vector3(0.0, radius * sin(angle), -radius * cos(angle))
		elif style == &"pump":
			var tuck: Vector3 = pose["tuck"]
			var reach_out: Vector3 = pose["stretch"]
			foot_goal += tuck.lerp(reach_out, _pump)
		elif style == &"paddle":
			# A stroke each side, one half a turn behind the other, the hands
			# going forward and back and a little up and down.
			var angle := _stroke + (0.0 if side == 0 else PI)
			hand_goal += Vector3(0.05 * carry * mirror, 0.05 * carry * sin(angle), 0.13 * carry * cos(angle))
		# The arm, from the shoulder, to a hand's breadth short of the grip: the
		# wrist is what is placed, and the hand is round it.
		var shoulder := shoulder_origin + torso_basis * _upper[side].position
		var aim := (hand_goal - shoulder).normalized()
		_two_bones(torso_basis, shoulder, hand_goal - aim * 0.04, Vector3(elbow.x * -mirror, elbow.y, elbow.z), _arm_a * reach, _arm_b * reach)
		_upper[side].quaternion = _upper[side].quaternion.slerp(_first, w)
		_fore[side].quaternion = _fore[side].quaternion.slerp(_second, w)
		_fore[side].position.y = -_arm_a * stretch
		_hand[side].position.y = -_arm_b * stretch
		_arm_mesh[side * 2].scale.y = stretch
		_arm_mesh[side * 2 + 1].scale.y = stretch
		# The leg, from the hip.
		var hip := hips_at + _thigh[side].position
		_two_bones(Basis.IDENTITY, hip, foot_goal, Vector3(knee.x * -mirror, knee.y, knee.z), -_shin[side].position.y, -_foot[side].position.y)
		_thigh[side].quaternion = _thigh[side].quaternion.slerp(_first, w)
		_shin[side].quaternion = _shin[side].quaternion.slerp(_second, w)
		# The foot, turned to lie as the pose says whatever the leg above does.
		var sole := Basis(Vector3.RIGHT, toe)
		_foot[side].quaternion = _foot[side].quaternion.slerp((_second_basis.transposed() * sole).get_rotation_quaternion(), w)
	_place(w)

## Two bones of length `a` and `b` hanging from `root` (both hang down at rest,
## which is the way the rig is built), reaching `goal`, with the middle joint
## pushed towards `bend`: an arm from a shoulder, a leg from a hip. A place
## further than the limb reaches is as far as it goes in that direction.
## Everything is in the rig's own frame, `parent` being the way what the first
## bone hangs from is turned in it. The answer is left in `_first` and
## `_second`, the local rotations of the two joints, and in `_second_basis`,
## which way the second bone is turned in the rig.
func _two_bones(parent: Basis, root: Vector3, goal: Vector3, bend: Vector3, a: float, b: float) -> void:
	var to := goal - root
	var length := to.length()
	var direction := to / length if length > 0.0001 else Vector3.DOWN
	var far := clampf(length, absf(a - b) + 0.01, (a + b) * 0.999)
	var along := (a * a - b * b + far * far) / (2.0 * far)
	var out := sqrt(maxf(a * a - along * along, 0.0))
	var side_way := bend - direction * bend.dot(direction)
	if side_way.length_squared() < 0.0001:
		side_way = Vector3.RIGHT - direction * Vector3.RIGHT.dot(direction)
	var middle := root + direction * along + side_way.normalized() * out
	var end := root + direction * far
	var first_bone := (middle - root) / a
	_first = Quaternion(Vector3.DOWN, parent.transposed() * first_bone)
	var first_basis := parent * Basis(_first)
	var second_bone := (end - middle) / b
	_second = Quaternion(Vector3.DOWN, first_basis.transposed() * second_bone)
	_second_basis = first_basis * Basis(_second)

## Put the rig where the seat is, by `w` of the way: moved to it, and turned to
## the way it faces and tips (the ship's seats swing, the swing's tilts). Only a
## ride has a place; what was added is taken off again as the weight falls.
func _place(w: float) -> void:
	if not _placed and not (seat_placed and w > 0.0):
		return
	var parent := _rig.get_parent() as Node3D
	if seat_placed and w > 0.0 and parent != null and parent.is_inside_tree():
		var local := parent.global_transform.affine_inverse() * seat_place
		var wanted := local.origin * w
		_rig.position += wanted - _applied
		_applied = wanted
		_rig.quaternion = Quaternion().slerp(local.basis.orthonormalized().get_rotation_quaternion(), w)
		_placed = true
	elif _placed:
		_rig.position -= _applied
		_applied = Vector3.ZERO
		_rig.quaternion = Quaternion()
		_placed = false

## Back to what the arms are as built, the sitting having stretched them.
func _rest_the_arms() -> void:
	for side in 2:
		_fore[side].position.y = -_arm_a
		_hand[side].position.y = -_arm_b
		_arm_mesh[side * 2].scale.y = 1.0
		_arm_mesh[side * 2 + 1].scale.y = 1.0
