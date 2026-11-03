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
## Held on a mount or a ride: the stride stops and the arms stay quiet. Sitting
## properly is for a later pass.
var riding := false
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
var _hips_rest := 0.0

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

## How long the kick's follow-through takes to die away, in seconds, and how
## long a cheer lasts.
const KICK_FOLLOW := 0.55
const CHEER_FOR := 1.5

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
	_hips_rest = _hips.position.y
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
	_speed = lerpf(_speed, 0.0 if riding else speed, 1.0 - exp(-8.0 * delta))
	_air = move_toward(_air, 1.0 if airborne and not swimming else 0.0, 9.0 * delta)
	_swim = move_toward(_swim, 1.0 if swimming else 0.0, 4.0 * delta)
	_dive = move_toward(_dive, 1.0 if (swimming and diving) else 0.0, 3.0 * delta)
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
