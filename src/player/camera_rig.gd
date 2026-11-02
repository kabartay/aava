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
## Eighty degrees, not ninety: at ninety the arm points straight up, its own
## "forward" and "up" vectors line up, and the basis built from them spins
## without warning — the view a child dragged towards and found unusable
## rather than merely steep. Eighty is close enough to overhead to watch the
## top of the drop tower or the coaster's climb without ever reaching the
## one angle that breaks.
const PITCH_MAX := deg_to_rad(80.0)

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
	# The camera is driven every drawn frame, and must not be interpolated.
	#
	# Physics interpolation is on for the whole project, because
	# get_global_transform_interpolated() — which is how this rig follows a
	# body that moves at sixty hertz without inheriting its staircase —
	# requires it. But a node the game itself moves in _process is a different
	# case: the engine samples its transform once a physics tick and draws it
	# a tick late, throwing away every frame of smoothing done in between. So
	# all of this rig's careful per-frame easing was being quantised back to
	# sixty hertz and delayed, which on a fast screen is exactly the flicker a
	# child described as the world arriving in frames.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	position.y = SHOULDER_HEIGHT + _eye_lift

	_arm = SpringArm3D.new()
	_arm.spring_length = ARM_LENGTH
	# The arm sweeps a sphere so the camera slides over terrain instead of
	# clipping through a hillside when the player backs into a slope.
	_arm.shape = SphereShape3D.new()
	(_arm.shape as SphereShape3D).radius = 0.45
	_arm.margin = 0.2
	# The ground and walls stop the camera; furniture does not — see TerrainSpec.
	_arm.collision_mask = TerrainSpec.LAYER_GROUND | TerrainSpec.LAYER_WALLS
	add_child(_arm)

	_tip = Node3D.new()
	_arm.add_child(_tip)

	camera = Camera3D.new()
	# top_level detaches the camera from this rig's transform, which is what lets
	# it lag behind the arm rather than being nailed to it.
	camera.top_level = true
	# top_level detaches it from this rig's transform, and interpolation mode
	# is inherited down the tree rather than through the transform, so it is
	# set here as well rather than assumed.
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
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

## Looking out of the child's own eyes rather than over their shoulder.
##
## The same rig, not a second camera: the yaw and pitch a thumb has already set
## are what the head is pointed by, so switching views does not reset where a
## child was looking. What changes is where the camera sits — at the eyes
## instead of at the end of the arm — and that the body it is inside is not
## drawn, because from there the back of a head fills the screen.
func set_first_person(on: bool) -> void:
	if first_person == on:
		return
	first_person = on
	_player.show_body(not on)

## Strapped into a ride: the camera stops letting the ride push it about.
##
## The arm sweeps a sphere backwards and stops against anything solid, which
## is right in a wood and wrong in a coaster car — the car's own floor, its
## walls and the seat back are all solid, so the camera collapsed to nothing
## and the view of the ride was the inside of a restraint. Riding, it holds
## its length and passes through the car, and stands a little further back so
## the train and the track ahead are both in shot. That is the view a child
## climbed in for.
func set_riding(on: bool) -> void:
	if _riding == on:
		return
	_riding = on
	# Nothing stops it while riding; the ordinary ground-and-walls mask back
	# afterwards.
	_arm.collision_mask = (
		0 if on else (TerrainSpec.LAYER_GROUND | TerrainSpec.LAYER_WALLS)
	)
	_arm.spring_length = RIDE_ARM if on else _distance

## How far back the camera sits while riding, and how quickly it comes round
## to face the way the ride is going.
const RIDE_ARM := 7.2
## Slow on purpose. A camera nailed to the train's heading cannot be looked
## away from, and half of a coaster is looking at the drop you are about to go
## down; slow enough that a thumb wins for a few seconds, and then it comes
## back round to the front by itself. Holding the view forward by hand, all
## the way round, was the complaint.
const RIDE_LOOK := 1.1

## Told, while riding, which way the ride is pointed.
func look_along(heading: float, delta: float) -> void:
	if not _riding:
		return
	yaw = lerp_angle(yaw, heading, 1.0 - exp(-RIDE_LOOK * delta))

var _riding := false

## Whether the roof is off over the child's head right now — the same
## condition that takes it off, asked here too.
##
## A spring arm that starts already touching what it is meant to stop against
## sometimes fails to register the touch at all, rather than reporting a
## length of zero — a known rough edge of casting a shape from a point already
## inside another. A child standing with their back to a café wall and turning
## to face it found the arm sail straight through at its full 5.4 m and out
## the other side, and from out there the building was both outside-in and
## roofless, since the roof had been taken off for a child who — as far as the
## game could tell — was still standing under where it had been. Indoors, the
## arm is kept short enough that even a miss cannot reach past an exterior
## wall from anywhere the room is wide enough to stand in.
var _indoors := false
const INDOOR_ARM := 2.2

func set_indoors(on: bool) -> void:
	_indoors = on

## How far back the arm is actually allowed to reach this frame. Riding, it
## keeps its own length whatever the zoom is set to: see set_riding. Indoors,
## it is capped short regardless of the zoom too: see set_indoors. A function
## of its own rather than a line inside _process, so a check can ask it what
## it would do without also asking for a physics frame that has not happened,
## which is what calling _process itself needs.
func _arm_length() -> float:
	var reach := _distance + _steep_pitch_bonus()
	if _riding:
		return maxf(reach, RIDE_ARM)
	if _indoors:
		return minf(reach, INDOOR_ARM)
	return reach

## Extra length the arm is given as the pitch climbs towards PITCH_MAX.
##
## The arm orbits the child's own shoulder, so tipping it towards overhead
## swings the camera round to behind and slightly below them at the same
## distance it stood at looking ahead — close enough, from there, that their
## own head filled the frame and the body below it was out of shot entirely.
## Standing further back as the pitch climbs keeps the whole of them in view
## the way looking up at a tower while standing well clear of its foot does.
func _steep_pitch_bonus() -> float:
	var steepness := clampf(inverse_lerp(deg_to_rad(40.0), PITCH_MAX, pitch), 0.0, 1.0)
	return steepness * 5.0

## The cap in _arm_length() above is a backstop for the length itself, and
## does nothing about the direction: a room narrower than the cap still lets
## the arm reach the far wall through the near one. This is the second
## backstop, for the spring arm's own sweep rather than for how far it is
## allowed to reach.
##
## The arm sweeps a sphere 0.45 m across, and a child standing square against
## an interior wall is only the player's own radius — 0.34 m — clear of it, so
## the sphere starts the sweep already touching the wall before it has swept
## anywhere at all. A shape that starts a sweep already touching what it is
## meant to stop against is exactly the case sweeps are worst at — some report
## the touch, and some report nothing until they have moved clear of it and
## come back — and report nothing is what let the arm through: not because it
## reached past its cap, but because the wall it swept toward never registered
## at all. A plain ray cast from the same point, which starts clear of
## anything since the point itself is 0.34 m off the wall rather than touching
## it, is asked the same question afterwards and answered reliably; this
## catches what the sweep missed without replacing it.
func _ray_shortened_length(wanted: float) -> float:
	var viewport := get_viewport()
	var space := viewport.world_3d.direct_space_state if viewport != null else null
	if space == null:
		return wanted
	var from := _arm.global_position
	# Along +Z: that is the way a SpringArm3D reaches, and the camera hangs at
	# the end of it looking back down -Z at the child. Cast along -Z it was
	# asking about the wall in front of the child, never the one behind.
	var to := from + _arm.global_transform.basis.z * wanted
	var query := PhysicsRayQueryParameters3D.create(from, to, _arm.collision_mask)
	query.exclude = [_player.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return wanted
	return maxf(from.distance_to(hit.position) - _arm.margin, 0.1)

## Where the eyes are, measured from the feet.
const EYE_HEIGHT := Player.HEIGHT * 0.92

var first_person := false

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
	_arm.spring_length = _arm_length()
	if _indoors:
		_arm.spring_length = _ray_shortened_length(_arm.spring_length)

	# Pulled far back, the camera also tips down a little on its own, because a
	# wide shot of a valley taken from waist height is mostly grass. This is why
	# zooming out reads as "look at the world" rather than "stand further away".
	var pulled_back := smoothstep(ARM_LENGTH, ARM_MAX, _distance)
	_arm.rotation.x = pitch - deg_to_rad(14.0) * pulled_back

	# get_global_transform_interpolated reads the player's smoothed position
	# rather than its last physics snapshot, so the camera does not inherit the
	# 60 Hz staircase of the body it is following.
	var anchor := _player.get_global_transform_interpolated().origin

	if first_person:
		# At the eyes, pointed where the thumb is pointing. No spring arm, no
		# lag and no aim point: a head does not trail behind itself.
		camera.global_position = anchor + Vector3.UP * (EYE_HEIGHT + _eye_lift)
		camera.global_transform.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
		camera.fov = lerpf(
			camera.fov, lerpf(FOV_WALK, FOV_RUN, _player.run_fraction()),
			1.0 - exp(-6.0 * delta)
		)
		# The aim point comes along too. It is only eased in the branch below,
		# so left alone here it stayed wherever it was when the child looked
		# out of their own eyes, and stepping back out after a walk had the
		# camera swing round to look at a spot they left a hundred metres ago.
		_aim = anchor + Vector3.UP * (AIM_HEIGHT + _eye_lift)
		_player.camera_yaw = yaw
		return

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
