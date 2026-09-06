class_name Player
extends CharacterBody3D

## The player.
##
## How this feels is not a detail. Walking is what the child does for most of
## every session, so the difference between "a box that slides" and "someone
## walking" is most of the game's quality. Hence acceleration curves, coyote
## time, a jump buffer, and a body that does not stutter over rolling ground.

const WALK_SPEED := 3.4
const RUN_SPEED := 6.6
const GROUND_ACCELERATION := 26.0
const GROUND_FRICTION := 22.0
const AIR_ACCELERATION := 7.0
## How fast the visual body turns to face the way it is moving, on foot. A
## mount uses its own, slower rate instead — see MountKinds.turn_rate().
const TURN_LAMBDA := 14.0
const JUMP_VELOCITY := 8.2
const FALL_GRAVITY_MULTIPLIER := 1.6

## Grace period after walking off an edge during which a jump still works.
## Children mash the button slightly late, constantly, and without this the game
## simply feels broken to them.
const COYOTE_TIME := 0.13

## Grace period before landing during which a jump is remembered and fires on
## touchdown. The other half of the same problem.
const JUMP_BUFFER := 0.14

## Swimming. The river was a wall before this: walk in and you sank to the bed
## and trudged along the bottom, which read as a bug and made the far bank
## unreachable without a horse. Water is now something a child floats in.
##
## Deliberately forgiving: there is no drowning, no stamina, and no way to be
## dragged under. Water in a game for a six-year-old should be a place, not a
## hazard.
const SWIM_DEPTH := 1.05
## The gap between "deep enough to start swimming" and "shallow enough to
## start walking again" — see the note where this is used.
const SWIM_HYSTERESIS := 0.15
const SWIM_SPEED := 2.6
## How hard the water pushes back up towards the surface. Strong enough that a
## child who jumps in bobs back up on their own.
const BUOYANCY := 9.0
## The most the water lets you sink or rise, so bobbing does not turn into
## bouncing.
const SWIM_DAMP := 0.86

## How far below the surface buoyancy keeps growing. Past this the water simply
## lifts at its strongest rather than harder still — see the note where it is
## used.
const MAX_LIFT_DEPTH := 0.9

## The fastest anyone rises in water, whatever the depth. Well under the jump
## velocity, so surfacing is a bob and never a launch.
const MAX_RISE := 3.4

const HEIGHT := 1.55
const RADIUS := 0.34

signal moved(world_position: Vector3)

## Emitted the instant the body leaves the ground and the instant it arrives.
## The sound belongs to whoever owns audio, not to the controller.
signal jumped()
signal landed(speed: float)

var camera_yaw := 0.0

## Set by the game while a child is on the swing or going down the slide. The
## player is placed rather than steered for these: they are rides, and a ride
## that fights the stick is a ride a child cannot enjoy.
##
## Carried rather than parented, for the same reason a mount is: a body
## parented to a moving node inherits its rotation and fights its own gravity.
var carried_to := Vector3.ZERO
var is_carried := false

## How deep the water is at the player's feet, set by the game each frame. The
## player knows nothing about where the river or the pool are; it is told.
var water_depth := 0.0
var is_swimming := false

## How high the child's body is lifted while riding, so they sit on the mount
## rather than standing inside it. Eased, so mounting looks like climbing on.
var _ride_lift := 0.0

## What the player is riding, or an empty name when on foot. Set by the game.
##
## Riding replaces the speed and the turn rate rather than parenting the player
## to a mount: a character body parented to a moving node inherits its rotation
## and fights its own gravity, which is a much larger problem than the one it
## solves.
var riding := &""

## Set by the game from the player's energy. False means walk-only.
var may_run := true
## Read back by the game to decide what energy the movement actually cost.
var is_running := false
var is_moving := false

var _coyote := 0.0
var _buffered_jump := 0.0
var _gravity := 24.0
var _last_reported := Vector3(1e9, 1e9, 1e9)
var _visual: Node3D

func _init() -> void:
	# Measured on rolling procedural terrain: at a run, the default snap length
	# of 0.1 lets the body leave the floor for a frame dozens of times a minute,
	# which reads as a stutter. Half a metre removes it entirely.
	floor_snap_length = 0.5
	floor_constant_speed = true
	floor_max_angle = deg_to_rad(52.0)
	safe_margin = 0.02
	slide_on_ceiling = false

	var shape := CapsuleShape3D.new()
	shape.height = HEIGHT
	shape.radius = RADIUS
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = HEIGHT * 0.5
	add_child(collider)

func _ready() -> void:
	_visual = _build_visual()
	add_child(_visual)

## A placeholder body, built from primitives. It exists so that movement can be
## judged now; CC0 character models replace it without touching the controller.
func _build_visual() -> Node3D:
	var root := Node3D.new()

	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.height = HEIGHT * 0.66
	capsule.radius = RADIUS
	body.mesh = capsule
	# Half its own height, so the body rests on the ground plane instead of
	# hovering a hand's width above it.
	body.position.y = HEIGHT * 0.33
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.30, 0.47, 0.72)
	cloth.roughness = 0.9
	body.material_override = cloth
	root.add_child(body)

	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.21
	sphere.height = 0.42
	head.mesh = sphere
	head.position.y = HEIGHT * 0.79
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.93, 0.78, 0.62)
	skin.roughness = 0.85
	head.material_override = skin
	root.add_child(head)

	# A nose, purely so that which way the character is facing is unmistakable
	# while the controller is being tuned.
	var nose := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.06
	cone.height = 0.14
	nose.mesh = cone
	nose.rotation = Vector3(deg_to_rad(-90.0), 0.0, 0.0)
	nose.position = Vector3(0.0, HEIGHT * 0.79, -0.20)
	nose.material_override = skin
	root.add_child(nose)

	return root

func _process(delta: float) -> void:
	if _charging:
		kick_charge = minf(kick_charge + delta / Ball.CHARGE_TIME, 1.0)

func _physics_process(delta: float) -> void:
	if is_carried:
		# Eased rather than snapped, so a swing reads as an arc rather than as
		# the child teleporting between two points.
		var to_seat := carried_to - global_position
		velocity = to_seat / maxf(delta, 0.001) * 0.35
		move_and_slide()
		return

	# get_gravity() is zero on the first physics frame, before the server has
	# populated the body's state, so the last good value is kept.
	var measured := get_gravity()
	if measured.length_squared() > 0.0:
		_gravity = -measured.y

	# How deep the water is here, if there is any. Set by the game each frame,
	# because the player knows nothing about rivers or pools.
	#
	# Two thresholds, not one: buoyancy pushes towards the surface until depth
	# settles at exactly SWIM_DEPTH, which is the same value a single threshold
	# would switch back to walking at — so a child standing still at the edge
	# of deep water would flicker between the two every frame. Entering and
	# leaving swimming at different depths gives that equilibrium a place to
	# rest on the swimming side of the line instead of straddling it.
	var afloat := water_depth > (SWIM_DEPTH if not is_swimming else SWIM_DEPTH - SWIM_HYSTERESIS)
	if is_swimming != afloat:
		is_swimming = afloat

	var grounded := is_on_floor() and not afloat
	_coyote = COYOTE_TIME if grounded else maxf(0.0, _coyote - delta)
	_buffered_jump = maxf(0.0, _buffered_jump - delta)
	if Input.is_action_just_pressed(InputActions.JUMP):
		_buffered_jump = JUMP_BUFFER

	if afloat:
		# Pushed towards the surface rather than pulled to the bed, and damped
		# so the child settles at the waterline instead of bobbing forever.
		#
		# The lift is capped. Without a cap it is proportional to how far below
		# the surface you are, and the river reaches 3.8 m: that gave 24.8 m/s²
		# upward — more than gravity — so a child who waded into a deep stretch
		# was fired into the sky the moment they broke the surface and the water
		# stopped holding them. Water lifts you to the top; it does not throw
		# you off it.
		var to_surface := clampf(water_depth - SWIM_DEPTH, 0.0, MAX_LIFT_DEPTH)
		velocity.y += BUOYANCY * to_surface * delta
		velocity.y *= SWIM_DAMP
		# And a hard ceiling on how fast anyone can be moving upwards while in
		# water, so no combination of depth and frame time can accumulate into
		# a launch.
		velocity.y = minf(velocity.y, MAX_RISE)

		# Jump becomes a stroke upwards, which is how a child expects to get
		# out of a pool.
		if _buffered_jump > 0.0:
			velocity.y = maxf(velocity.y, JUMP_VELOCITY * 0.42)
			_buffered_jump = 0.0
	elif not grounded:
		# Falling faster than rising is what makes a hop read as a jump rather
		# than a slow-motion float back down. The rise itself is untouched, so
		# jump height — and the rocks it has to clear — does not change.
		var falling_multiplier := FALL_GRAVITY_MULTIPLIER if velocity.y < 0.0 else 1.0
		velocity.y -= _gravity * falling_multiplier * delta

	if _buffered_jump > 0.0 and _coyote > 0.0 and not afloat:
		velocity.y = JUMP_VELOCITY
		_buffered_jump = 0.0
		_coyote = 0.0
		jumped.emit()

	var input := Input.get_vector(
		InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT,
		InputActions.MOVE_FORWARD, InputActions.MOVE_BACK
	)
	# Movement is relative to where the camera looks, which is the only scheme a
	# child reads instantly: push the stick up, go the way you are looking.
	var basis := Basis(Vector3.UP, camera_yaw)
	var wish := basis * Vector3(input.x, 0.0, input.y)

	# How far the stick is pushed is how fast you go. Normalising the direction
	# and throwing the magnitude away — which is what this did — meant a barely
	# nudged stick ran at exactly the same speed as a stick pushed to the rim,
	# so there was no way to creep up on anything or to walk gently.
	var push := clampf(wish.length(), 0.0, 1.0)
	if push > 0.001:
		wish /= wish.length()

	# Pushing past three quarters breaks into a run without touching sprint,
	# which is how a thumbstick is expected to behave and means a six-year-old
	# never has to find a second control to run.
	var top := lerpf(WALK_SPEED, RUN_SPEED, smoothstep(0.72, 1.0, push))
	if Input.is_action_pressed(InputActions.SPRINT):
		top = RUN_SPEED
		push = maxf(push, 1.0)

	if afloat:
		# One speed in water, and slower than walking. Swimming should feel like
		# crossing something rather than like a faster way to travel.
		top = SWIM_SPEED * minf(push, 1.0)
	elif riding != &"":
		# A mount has one speed, reached by pushing the stick, and no walk/run
		# distinction — a child on a horse is not choosing a gait.
		top = MountKinds.speed(riding) * minf(push, 1.0)
	elif not may_run:
		# Too tired to run, but never too tired to walk. Energy shapes the pace
		# of a day; it must not strand a child halfway up a hill.
		top = minf(top, WALK_SPEED)
	# Riding is not running: it must not drain the child's own energy.
	is_running = riding == &"" and top > WALK_SPEED + 0.01 and wish.length_squared() > 0.01

	var target := wish * top * minf(push, 1.0)
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)

	var rate := GROUND_ACCELERATION if grounded else AIR_ACCELERATION
	if wish.length_squared() < 0.01 and grounded:
		rate = GROUND_FRICTION
	horizontal = horizontal.move_toward(target, rate * delta)
	is_moving = horizontal.length_squared() > 0.35

	velocity.x = horizontal.x
	velocity.z = horizontal.z

	# move_and_slide reads delta itself; pre-multiplying makes speed depend on
	# frame rate, which is the classic way to get a controller that feels fine
	# on a desktop and wrong on a tablet.
	var falling := velocity.y
	move_and_slide()
	# Landing is the frame the body was airborne and now is not.
	if not grounded and is_on_floor() and falling < -1.0:
		landed.emit(absf(falling))

	if horizontal.length_squared() > 0.05:
		var facing := atan2(-horizontal.x, -horizontal.z)
		# A mount turns more slowly than a child on foot — its own body has to
		# come round, not just the rider's shoulders — so it uses the mount's
		# own turn rate rather than the walking one.
		var turn_lambda := MountKinds.turn_rate(riding) if riding != &"" else TURN_LAMBDA
		_visual.rotation.y = lerp_angle(_visual.rotation.y, facing, 1.0 - exp(-turn_lambda * delta))

	var wanted_lift := MountKinds.eye_lift(riding) if riding != &"" else 0.0
	_ride_lift = lerpf(_ride_lift, wanted_lift, 1.0 - exp(-6.0 * delta))
	_visual.position.y = _ride_lift

	# The world streams around wherever the player is, but only when they have
	# actually gone somewhere worth regenerating for.
	if global_position.distance_squared_to(_last_reported) > 16.0:
		_last_reported = global_position
		moved.emit(global_position)

## Ask for a jump from the interface. It goes through the same buffer as the
## key, so a tapped button and a tapped key behave identically — including the
## grace period that lets a slightly early press still work on landing.
func request_jump() -> void:
	_buffered_jump = JUMP_BUFFER

## How long the kick button has been held, as 0 to 1.
##
## Kept here rather than in the ball or the interface because it is input state,
## and because both the touch button and the keyboard have to feed the same
## number or the two controls would kick differently.
var kick_charge := 0.0

var _charging := false

## Begin winding up a kick. Called on button press and on key down.
func start_charging() -> void:
	_charging = true
	kick_charge = 0.0

## Release, returning the charge that was built up.
func release_charge() -> float:
	var charged := kick_charge
	_charging = false
	kick_charge = 0.0
	return charged

func is_charging() -> bool:
	return _charging

## Which way the body is actually facing, on the ground plane. Used by the kick
## so that striking a ball you are standing on top of still sends it forwards.
## The direction the body is turned, as an angle. Read by a mount so it faces
## the same way its rider does.
func facing_angle() -> float:
	return _visual.rotation.y

func facing() -> Vector3:
	return Vector3(-sin(_visual.rotation.y), 0.0, -cos(_visual.rotation.y))

func is_sprinting() -> bool:
	return Input.is_action_pressed(InputActions.SPRINT) and run_fraction() > 0.4

## Current planar speed as a fraction of a full run. Drives the camera's field
## of view and, later, animation blending.
func run_fraction() -> float:
	return clampf(Vector3(velocity.x, 0.0, velocity.z).length() / RUN_SPEED, 0.0, 1.0)
