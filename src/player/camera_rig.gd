class_name CameraRig
extends Node3D

## Third-person camera.
##
## SpringArm3D rewrites its direct children's global position on every physics
## tick with no smoothing at all, so hanging the camera off it directly makes
## the view jitter at the physics rate. Instead the arm carries an empty tip
## marker, and the camera is a top-level node chasing that marker with
## exponential smoothing in _process. That separation is the whole reason the
## view glides instead of ticking.

## How far behind the player the camera sits by default, and the range it can be
## pulled to.
##
## The near end is close enough to see what your hands are doing when placing a
## wall; the far end is high and wide enough to look at the valley rather than
## at yourself. Both ends are the point: one control does "let me see this
## properly" and "let me see where I am".
const ARM_LENGTH := 5.4
const ARM_MIN := 2.2
const ARM_MAX := 18.0

## How fast the wheel and the pinch move it. The wheel is per notch; the pinch
## is per unit of change in the distance between two fingers.
const ZOOM_PER_NOTCH := 1.4
const ZOOM_PER_PIXEL := 0.035

## How quickly the arm eases to a new length. Instant zoom is disorienting;
## this is fast enough not to feel like waiting.
const ZOOM_LAMBDA := 9.0
const SHOULDER_HEIGHT := 1.35
const AIM_HEIGHT := 1.15

## Vertical limits. Straight down is disallowed because it puts the camera
## inside the ground and disorients a small child instantly.
const PITCH_MIN := deg_to_rad(-58.0)
const PITCH_MAX := deg_to_rad(24.0)

## Radians per screen pixel of drag.
const DRAG_SENSITIVITY := 0.0055

## How quickly the camera catches up. Higher is tighter and more nauseating.
const FOLLOW_LAMBDA := 11.0
const AIM_LAMBDA := 14.0

## The arm itself shortens instantly the physics tick it hits a wall — that
## part has to be instant, or the camera spends a frame on the far side of the
## wall it just found. This is how fast the visible camera then catches up to
## that shortened length. Pulling back out afterwards still eases at the
## ordinary FOLLOW_LAMBDA, since there is no wall to render through in that
## direction — only snapping in needs to be this quick.
const RETRACT_LAMBDA := 45.0

const FOV_WALK := 66.0
const FOV_RUN := 74.0

## Raised while riding, so a child on a horse looks over its head rather than
## through it. Eased rather than snapped: mounting should feel like rising, and
## an instant jump of a metre reads as a glitch.
const LIFT_LAMBDA := 6.0

var _eye_lift := 0.0
var _eye_lift_target := 0.0

var yaw := 0.0
var pitch := deg_to_rad(-16.0)

## Where the camera is being pulled to, and where it actually is. Kept apart so
## the arm eases rather than jumping.
var wanted_distance := ARM_LENGTH
var _distance := ARM_LENGTH

var camera: Camera3D

var _arm: SpringArm3D
var _tip: Node3D
var _aim := Vector3.ZERO
var _player: Player
var _tip_distance := ARM_LENGTH

func _init(player: Player) -> void:
	_player = player
	position.y = SHOULDER_HEIGHT + _eye_lift

	_arm = SpringArm3D.new()
	_arm.spring_length = ARM_LENGTH
	# The arm sweeps a sphere so the camera slides over terrain instead of
	# clipping through a hillside when the player backs into a slope.
	_arm.shape = SphereShape3D.new()
	(_arm.shape as SphereShape3D).radius = 0.45
	_arm.margin = 0.2
	add_child(_arm)

	_tip = Node3D.new()
	_arm.add_child(_tip)

	camera = Camera3D.new()
	# top_level detaches the camera from this rig's transform, which is what lets
	# it lag behind the arm rather than being nailed to it.
	camera.top_level = true
	camera.fov = FOV_WALK
	camera.far = 4000.0
	add_child(camera)

func _ready() -> void:
	# The arm sweeps a sphere backwards from the player's shoulder, and without
	# this it hits the player's own capsule first and collapses to nothing —
	# the camera ends up inside the head, which is exactly what it looks like.
	_arm.add_excluded_object(_player.get_rid())

	rotation.y = yaw
	_arm.rotation.x = pitch
	# Start settled, or the first frame shows the camera flying in from the origin.
	camera.global_position = _tip.global_position
	_aim = _player.global_position + Vector3.UP * (AIM_HEIGHT + _eye_lift)
	camera.look_at(_aim, Vector3.UP)

## How much higher the camera sits than when on foot.
func set_eye_lift(metres: float) -> void:
	_eye_lift_target = maxf(metres, 0.0)

func _process(delta: float) -> void:
	_eye_lift = lerpf(
		_eye_lift, _eye_lift_target, 1.0 - exp(-LIFT_LAMBDA * delta)
	)
	position.y = SHOULDER_HEIGHT + _eye_lift

	rotation.y = yaw
	_arm.rotation.x = pitch

	_distance = lerpf(_distance, wanted_distance, 1.0 - exp(-ZOOM_LAMBDA * delta))
	_arm.spring_length = _distance

	# Pulled far back, the camera also tips down a little on its own, because a
	# wide shot of a valley taken from waist height is mostly grass. This is why
	# zooming out reads as "look at the world" rather than "stand further away".
	var pulled_back := smoothstep(ARM_LENGTH, ARM_MAX, _distance)
	_arm.rotation.x = pitch - deg_to_rad(14.0) * pulled_back

	# get_global_transform_interpolated reads the player's smoothed position
	# rather than its last physics snapshot, so the camera does not inherit the
	# 60 Hz staircase of the body it is following.
	var anchor := _player.get_global_transform_interpolated().origin

	# Fast in, slow out: if the arm just pulled closer — a wall or a hillside —
	# the camera catches up quickly rather than lingering for a few frames on
	# the wrong side of what it just found.
	var tip_distance := _arm.global_position.distance_to(_tip.global_position)
	var retracting := tip_distance < _tip_distance - 0.001
	_tip_distance = tip_distance
	var follow := 1.0 - exp(-(RETRACT_LAMBDA if retracting else FOLLOW_LAMBDA) * delta)
	camera.global_position = camera.global_position.lerp(_tip.global_position, follow)

	var aim_target := anchor + Vector3.UP * (AIM_HEIGHT + _eye_lift)
	_aim = _aim.lerp(aim_target, 1.0 - exp(-AIM_LAMBDA * delta))
	if camera.global_position.distance_squared_to(_aim) > 0.04:
		camera.look_at(_aim, Vector3.UP)

	# A small widening at a run. Barely noticeable consciously, and the single
	# cheapest way to make running feel faster than walking. Close in, the field
	# of view narrows as well, which is what stops a near camera from bending
	# the character into a fisheye.
	var closeness := 1.0 - smoothstep(ARM_MIN, ARM_LENGTH, _distance)
	var wanted_fov := lerpf(FOV_WALK, FOV_RUN, _player.run_fraction()) - 10.0 * closeness
	camera.fov = lerpf(camera.fov, wanted_fov, 1.0 - exp(-6.0 * delta))

	_player.camera_yaw = yaw

## Where the camera is looking, as 0 for straight along the ground and 1 for as
## high as the camera will go. This is what aims a kick: look up to chip it,
## look down to drive it flat. Nothing new to learn, because looking around is
## already how you see anything.
func aim_height() -> float:
	# The camera looks down for most of its range, which is right for walking
	# around but means "level" sits well up the range. Only the upper part maps
	# to loft, so a normal walking view gives a normal low shot.
	return clampf(inverse_lerp(deg_to_rad(-24.0), PITCH_MAX, pitch), 0.0, 1.0)

## Screen drag from the touch layer, in pixels.
func orbit(drag: Vector2) -> void:
	yaw -= drag.x * DRAG_SENSITIVITY
	pitch = clampf(pitch - drag.y * DRAG_SENSITIVITY, PITCH_MIN, PITCH_MAX)

## Pull the camera in or push it out. Positive pulls closer.
##
## Taken as a delta rather than an absolute so that a mouse wheel, a pinch and
## anything added later all feed the same value and cannot disagree about where
## the camera should be.
func zoom(amount: float) -> void:
	wanted_distance = clampf(wanted_distance - amount, ARM_MIN, ARM_MAX)

## How far out the camera is, from 0 at the closest to 1 at the widest. Used by
## the interface to show the zoom, and by anything that should behave
## differently when the player is surveying rather than walking.
func zoom_fraction() -> float:
	return clampf(inverse_lerp(ARM_MIN, ARM_MAX, _distance), 0.0, 1.0)
