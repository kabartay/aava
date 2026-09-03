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

## How far behind the player the camera sits, and where it aims.
const ARM_LENGTH := 5.4
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

const FOV_WALK := 66.0
const FOV_RUN := 74.0

var yaw := 0.0
var pitch := deg_to_rad(-16.0)

var camera: Camera3D

var _arm: SpringArm3D
var _tip: Node3D
var _aim := Vector3.ZERO
var _player: Player

func _init(player: Player) -> void:
	_player = player
	position.y = SHOULDER_HEIGHT

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
	_aim = _player.global_position + Vector3.UP * AIM_HEIGHT
	camera.look_at(_aim, Vector3.UP)

func _process(delta: float) -> void:
	rotation.y = yaw
	_arm.rotation.x = pitch

	# get_global_transform_interpolated reads the player's smoothed position
	# rather than its last physics snapshot, so the camera does not inherit the
	# 60 Hz staircase of the body it is following.
	var anchor := _player.get_global_transform_interpolated().origin

	var follow := 1.0 - exp(-FOLLOW_LAMBDA * delta)
	camera.global_position = camera.global_position.lerp(_tip.global_position, follow)

	var aim_target := anchor + Vector3.UP * AIM_HEIGHT
	_aim = _aim.lerp(aim_target, 1.0 - exp(-AIM_LAMBDA * delta))
	if camera.global_position.distance_squared_to(_aim) > 0.04:
		camera.look_at(_aim, Vector3.UP)

	# A small widening at a run. Barely noticeable consciously, and the single
	# cheapest way to make running feel faster than walking.
	var wanted_fov := lerpf(FOV_WALK, FOV_RUN, _player.run_fraction())
	camera.fov = lerpf(camera.fov, wanted_fov, 1.0 - exp(-6.0 * delta))

	_player.camera_yaw = yaw

## Screen drag from the touch layer, in pixels.
func orbit(drag: Vector2) -> void:
	yaw -= drag.x * DRAG_SENSITIVITY
	pitch = clampf(pitch - drag.y * DRAG_SENSITIVITY, PITCH_MIN, PITCH_MAX)
