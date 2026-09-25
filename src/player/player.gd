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

## How far under the ground a child has to be before the game puts them back on
## top of it.
##
## The world builds its collision around wherever the player is, and the player
## is put down before any of it exists — so on a slow phone there are a few
## seconds at the start of every session with nothing under their feet. Usually
## the ground arrives first. When it does not they fall, and they keep falling:
## a save was found at minus seventy thousand metres, with a child turning on
## the spot in the dark wondering where the game had gone.
##
## Four metres, because the deepest water here is two and the deepest hole a
## child can stand in is the swimming pool at 1.9.
const CAUGHT_BELOW := 4.0

## The steepest ground a child gets up on their own feet. Anything past this is
## a slope they slide off, and it is what every mount's own limit is measured
## against — a machine that climbs better than legs would be a strange thing to
## put in a valley children are meant to walk about in.
const CLIMBS_TO := deg_to_rad(52.0)

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

## A height the body is held at, whatever the water or the ground would do —
## a rider sitting in the saddle of a swimming horse, or one following the
## ground their horse is walking on. Left at this sentinel when nothing is
## holding them, which is nearly always.
const NOT_HELD := -1e9
var held_at_height := NOT_HELD

## How hard the body is pulled to the height it is held at, and how far it may
## drift before it is simply put there.
##
## A gentle spring is right for climbing into a boat and wrong for galloping
## downhill: the ground under a horse at full pace drops several metres a
## second, a spring this soft lags by half of one, and the rider hangs that far
## above the saddle — reported from the phone as being torn off the horse on a
## slope. The clamp is what actually fixes it; the spring only smooths what is
## left.
const HOLD_SPRING := 8.0
const HOLD_SLACK := 0.12
var held_spring := HOLD_SPRING

## How quickly a rider settles to the height of the ground under the machine.
## Fast enough to stay with it over a bank, slow enough that a stone is a
## nudge rather than a launch.
const HOLD_FOLLOW := 14.0
var is_swimming := false

## Multiplies the next jump. 1.0 everywhere but on the trampoline, where the
## game sets it higher while the child stands on the mat.
var jump_boost := 1.0

## How high the child's body is lifted while riding, so they sit on the mount
## rather than standing inside it. Eased, so mounting looks like climbing on.
var _ride_lift := 0.0
## How far the body is dropped into the water while swimming, and how far it
## is tipped forward.
var _swim_sink := 0.0
var _swim_lean := 0.0
var _ride_lean := 0.0
## The bow, and how far the string is drawn back: nothing while it hangs at
## the child's side, one at full draw.
var _bow: Node3D
var _bow_string: Node3D
var _bow_arrow: Node3D
var _draw_shown := 0.0

## Called by the game when somebody gets on: a machine starts out pointing the
## way the child was facing, not the way the last rider left it.
func take_the_handlebars(facing: float) -> void:
	_ride_heading = facing

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

## Paddling a stopped machine round with your feet: how slowly, and below what
## speed it is allowed at all. Slow enough that it never reads as spinning.
const PADDLE_RATE := 0.55
const PADDLE_BELOW := 1.2

## How hard a machine pulls, and how slowly it gives its speed back when the
## throttle is released. Coasting is the slower of the two by a long way,
## which is what weight feels like.
const MACHINE_PULL := 9.0
const MACHINE_COAST := 2.2

## Reverse, as a share of what the machine does forwards.
const REVERSE_SHARE := 0.32

## Which way a steered machine is pointing. Kept here rather than read back
## off the drawn body, because the body eases towards it and steering off an
## eased value compounds into a wobble.
var _ride_heading := 0.0
## Where the bars are, which is not where the thumb is: they take time to go
## over and they come back to centre when it lifts.
var _bars := 0.0

## How fast the bars move, in lock per second. Quick enough to feel direct,
## slow enough that a flicked stick is a lean rather than a swerve.
const BARS_SPEED := 3.4

## How hard the bars are over, and how far the machine is laid into the corner.
var _last_steer := 0.0
var _ride_bank := 0.0

## How far a machine leans at full lock and full speed. Twenty degrees: enough
## to be plainly leaning, little enough that a child never reads it as falling.
const RIDE_BANK := deg_to_rad(20.0)

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
	floor_max_angle = CLIMBS_TO
	safe_margin = 0.02
	slide_on_ceiling = false
	# The ground, and the thin props the camera is allowed to see through.
	collision_mask = TerrainSpec.LAYER_GROUND | TerrainSpec.LAYER_PROPS

	var shape := CapsuleShape3D.new()
	shape.height = HEIGHT
	shape.radius = RADIUS
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = HEIGHT * 0.5
	add_child(collider)

func _ready() -> void:
	# Only if nothing has needed it sooner. Handing the child something to
	# carry builds the body early, and building it twice leaves one of them
	# standing in the other.
	if _visual == null:
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

	# The bow, held out at the child's left side and drawn as the string is
	# pulled. Hidden until they nock an arrow: a bow carried everywhere would
	# be in the way of every other thing they do.
	_bow = _build_bow()
	_bow.visible = false
	root.add_child(_bow)

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
	# Sitting on something that floats: neither swimming nor falling, held at
	# the height of the saddle. Without this the horse swam and the child
	# swam separately, a metre apart, with open water between them.
	var held := held_at_height > NOT_HELD * 0.5
	var afloat := water_depth > (SWIM_DEPTH if not is_swimming else SWIM_DEPTH - SWIM_HYSTERESIS)
	if held:
		afloat = false
	# In a boat the water is under the hull, not the child: no swimming, no
	# falling, the body held at the seat's height above the waterline.
	var boating := riding != &"" and MountKinds.floats(riding)
	if boating:
		afloat = false
	if is_swimming != afloat:
		is_swimming = afloat

	var grounded := (is_on_floor() and not afloat) or boating or held
	_coyote = COYOTE_TIME if grounded else maxf(0.0, _coyote - delta)
	_buffered_jump = maxf(0.0, _buffered_jump - delta)
	if Input.is_action_just_pressed(InputActions.JUMP):
		_buffered_jump = JUMP_BUFFER

	if held and velocity.y <= JUMP_VELOCITY * 0.25:
		# Carried to the saddle rather than sprung to it.
		#
		# A spring is a spring: hand it a step in the ground — the edge of a
		# levelled place, a stone under one wheel — and it converts that step
		# into upward speed and throws the rider. What a rider actually does is
		# stay with the machine, so the height is followed directly and the
		# vertical speed is simply spent. Smoothed, so a slope is a slope
		# rather than a staircase.
		#
		# A jump still escapes it: a child who has just pushed off is rising
		# under their own power, and the hold lets go until they come down.
		global_position.y = lerpf(
			global_position.y, held_at_height, 1.0 - exp(-HOLD_FOLLOW * delta)
		)
		velocity.y = 0.0
	elif boating:
		# Sprung to the seat rather than snapped, so getting in reads as
		# climbing in and a wave of the pond's surface would read as a wave.
		var seat := HeightField.WATER_LEVEL + MountKinds.BOAT_SEAT
		velocity.y = (seat - global_position.y) * 8.0
	elif afloat:
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

	if _buffered_jump > 0.0 and _coyote > 0.0 and not afloat and not boating:
		velocity.y = JUMP_VELOCITY * jump_boost
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

	# Unless it has wheels. Then the stick is a throttle and a handlebar: up
	# and down is how hard you are going, left and right is how hard you are
	# turning, and the machine goes where it is pointed. Pointing it is what
	# takes time and ground — which is the whole difference between riding a
	# motorcycle and carrying one.
	var steering := riding != &"" and MountKinds.steers(riding)
	var reversing := false
	if steering:
		var throttle := -input.y
		var steer := input.x
		var pace := Vector2(velocity.x, velocity.z).length()
		var top_speed := MountKinds.speed(riding)
		reversing = throttle < -0.05
		# Which way it is actually going, not merely how fast: a machine
		# backing up steers the other way round, exactly as a car does.
		var heading_now := Vector3(-sin(_ride_heading), 0.0, -cos(_ride_heading))
		var signed_pace := Vector3(velocity.x, 0.0, velocity.z).dot(heading_now)
		# The bars take time to go over, and come back to centre when the
		# thumb comes off. A stick read straight through to full lock is why
		# steering felt like flicking a switch: a rider turns the bars, and
		# turning them is itself a movement with a speed of its own.
		var wanted_lock := steer
		# Less lock at speed. A machine that can be put on full lock at twenty
		# metres a second is a machine that spits its rider off every time a
		# thumb twitches; the faster it goes the less the bars will move, which
		# is also what a rider does without thinking about it.
		wanted_lock *= lerpf(1.0, 0.28, clampf(pace / maxf(top_speed, 0.01), 0.0, 1.0))
		_bars = move_toward(_bars, wanted_lock, BARS_SPEED * delta)

		# How fast it comes round: the speed divided by the wheelbase, times
		# the tangent of the angle the bars are at. That is what rolling on
		# wheels does, and it has three consequences a rider feels at once —
		# standing still it does not turn at all, creeping it turns very
		# sharply, and at speed the same lock sweeps a much bigger circle.
		#
		# It used to be a rate per second scaled by a "bite" that rose with
		# speed, which at low speed span the machine on the spot like a
		# shopping trolley: a quad, sitting still, could be rotated on its own
		# axis with the stick.
		var lock := tan(_bars * MountKinds.FULL_LOCK)
		var turning := signed_pace / MountKinds.wheelbase(riding) * lock
		# Capped at what the machine will actually do, so a bicycle shot down a
		# hill cannot be flicked round faster than a bicycle can be.
		turning = clampf(turning, -MountKinds.turn_rate(riding), MountKinds.turn_rate(riding))
		# And paddling: with the throttle held and the machine all but stopped,
		# it can still be walked round — slowly — the way you shuffle a
		# motorcycle out of a corner with your feet. Ridden nose-first into a
		# wood, a machine with no paddle is wedged there for ever.
		if absf(throttle) > 0.1 and pace < PADDLE_BELOW:
			turning += _bars * PADDLE_RATE * (1.0 - pace / PADDLE_BELOW)
		_ride_heading -= turning * delta
		_last_steer = _bars
		var forward := Vector3(-sin(_ride_heading), 0.0, -cos(_ride_heading))
		wish = forward * throttle

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
		# The stick chooses the gait. Up to three quarters it goes from a walk
		# to a trot — the mount's speed at most — and past that the mount
		# stretches out to a canter, a little faster than its speed. It had
		# one speed reached at any push, and a child could neither dawdle on
		# the horse nor let it go.
		var gait := smoothstep(0.0, 0.72, push) * 0.75 + smoothstep(0.72, 1.0, push) * 0.4
		top = MountKinds.speed(riding) * gait
		# Backing up is slow, but it is a pace rather than a crawl. It used to
		# be capped by squashing the stick push — and the push is applied twice
		# further down, once through the gait and once again to the target, so
		# a third of a push came out as a tenth of the speed. Backing a
		# motorcycle out of a wood at a twentieth of its speed is
		# indistinguishable from being stuck. The cap belongs on the speed,
		# where it means what it says.
		if reversing:
			top = MountKinds.speed(riding) * REVERSE_SHARE
	elif not may_run:
		# Too tired to run, but never too tired to walk. Energy shapes the pace
		# of a day; it must not strand a child halfway up a hill.
		top = minf(top, WALK_SPEED)
	# Riding is not running: it must not drain the child's own energy.
	is_running = riding == &"" and top > WALK_SPEED + 0.01 and wish.length_squared() > 0.01

	# How hard the stick is pushed has already been spent on a mount — it chose
	# the gait — so it must not be spent a second time here, which quietly
	# squared it and made every pace short of full throttle far slower than it
	# looked.
	var target := wish * top * (1.0 if riding != &"" else minf(push, 1.0))
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)

	var rate := GROUND_ACCELERATION if grounded else AIR_ACCELERATION
	if wish.length_squared() < 0.01 and grounded:
		rate = GROUND_FRICTION
	# A machine has weight. It gathers speed rather than reaching it, and when
	# the throttle is let go it rolls on instead of stopping where it is — a
	# motorcycle that halts the instant a thumb lifts is a shopping trolley
	# with an engine noise.
	if steering:
		rate = MACHINE_PULL if wish.length_squared() > 0.01 else MACHINE_COAST
	horizontal = horizontal.move_toward(target, rate * delta)
	is_moving = horizontal.length_squared() > 0.35

	# Wheels do not slide sideways.
	#
	# The machine's heading was being turned while its velocity kept pointing
	# where it had been going, and the two were only reconciled by the slow
	# pull of the throttle — so a quad taking a corner drifted like a car on
	# ice, and on a slope it slid. A wheel rolls: what is across it is scrubbed
	# off. The scrubbing is not total, because a machine that is perfectly
	# rigid to its heading twitches every time the heading twitches, but it is
	# most of it, and on four wheels it is nearly all of it.
	if steering:
		var heading := Vector3(-sin(_ride_heading), 0.0, -cos(_ride_heading))
		var along := heading * horizontal.dot(heading)
		var sideways := horizontal - along
		var grip := MountKinds.grip(riding)
		horizontal = along + sideways * exp(-grip * delta)

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

	# A steered machine points where it is steered, not where it happens to be
	# sliding: it leads the turn rather than following it, which is what makes
	# it feel like a machine rather than a boat.
	if steering:
		_visual.rotation.y = lerp_angle(
			_visual.rotation.y, _ride_heading, 1.0 - exp(-13.0 * delta)
		)
		# And it leans into the corner. A machine that changes direction bolt
		# upright reads as a chess piece being slid; the lean is what the eye
		# actually uses to tell that something is turning hard, and it grows
		# with speed because that is what leaning is for.
		var pace := Vector2(velocity.x, velocity.z).length()
		var hard := _last_steer * clampf(pace / maxf(MountKinds.speed(riding) * 0.6, 0.01), 0.0, 1.0)
		_ride_bank = lerpf(_ride_bank, hard * RIDE_BANK, 1.0 - exp(-6.0 * delta))
	else:
		_ride_bank = lerpf(_ride_bank, 0.0, 1.0 - exp(-6.0 * delta))
		_bars = move_toward(_bars, 0.0, BARS_SPEED * delta)
	_visual.rotation.z = _ride_bank

	var wanted_lift := MountKinds.eye_lift(riding) if riding != &"" else 0.0
	_ride_lift = lerpf(_ride_lift, wanted_lift, 1.0 - exp(-6.0 * delta))
	_settle_in_water(delta)
	_visual.position.y = _ride_lift - _swim_sink - _swim_bob()

	# The world streams around wherever the player is, but only when they have
	# actually gone somewhere worth regenerating for.
	# Every four metres on foot, and every metre on something with an engine.
	#
	# This is what the world streams against — the solid trunks, the solid
	# animals, the rocks — and at sixteen metres a second four metres is a
	# third of a second of travel: a motorcycle arrived at trees whose
	# colliders had not been put there yet, and went through them. What a child
	# reported as "the quad passes through trees" was the pool being a quarter
	# of a second behind the machine.
	var report_after := 16.0 if riding == &"" else 1.0
	if global_position.distance_squared_to(_last_reported) > report_after:
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
## How the body sits in the water: dropped to the chest and tipped forward,
## bobbing a little, so that swimming looks like swimming.
##
## Buoyancy already held the body at the right height for its *collider* —
## which meant a child stood in the water up to the knees with the whole of
## them above the surface, and from the phone it was not clear they were
## swimming at all. The collider is left alone; what moves is what is drawn.
const SWIM_SINK := 0.52
const SWIM_LEAN := deg_to_rad(22.0)
const SWIM_BOB := 0.05
const SWIM_SETTLE := 4.0

func _settle_in_water(delta: float) -> void:
	var wanted := SWIM_SINK if is_swimming else 0.0
	_swim_sink = lerpf(_swim_sink, wanted, 1.0 - exp(-SWIM_SETTLE * delta))
	_swim_lean = lerpf(_swim_lean, SWIM_LEAN if is_swimming else 0.0, 1.0 - exp(-SWIM_SETTLE * delta))
	_visual.rotation.x = _swim_lean

## Riding the surface, which is what tells a child the water is water. An
## offset worked out fresh each frame, never added into `_swim_sink`: added
## to the state it would be smoothed, re-added and smoothed again, and the
## body sank by a hand's width a second. The animals' flying-into-the-air
## bug was this same mistake — see LESSONS.md.
func _swim_bob() -> float:
	if _swim_sink < 0.01:
		return 0.0
	return sin(float(Time.get_ticks_msec()) * 0.0022) * SWIM_BOB * (_swim_sink / SWIM_SINK)

## Show or hide the drawn body. Hidden when the camera is inside the head,
## where a body is the back of a skull filling the screen.
##
## Only what is drawn: the collider, the lantern in the hand and everything
## else carry on exactly as before, because a child in first person is still a
## child standing in a valley.
func show_body(shown: bool) -> void:
	if _visual != null:
		_visual.visible = shown

## Is the drawn body showing? For the checks.
func body_shown() -> bool:
	return _visual == null or _visual.visible

## Carry something: a lantern, and anything else a child holds.
##
## It goes on the body rather than on the character itself, so it turns when
## the child turns and sinks when they swim. Hung on the character, a lit
## lantern stayed at standing height while the swimmer went down, and a glowing
## lamp floating beside a half-submerged head looks like the head coming off —
## which is exactly how it was reported.
func hold(thing: Node3D) -> void:
	if _visual == null:
		_visual = _build_visual()
		add_child(_visual)
	_visual.add_child(thing)

## Is this being carried on the body? For the checks.
func is_held(thing: Node3D) -> bool:
	return _visual != null and thing.get_parent() == _visual

## Lean with the slope while riding: down the hill going down, back going
## up, the way a rider does. The body alone leans — the collider stays
## upright, since a capsule tipped over catches on everything.
const RIDE_LEAN_LIMIT := deg_to_rad(22.0)

func lean_with_the_ground(riding_now: bool, field: HeightField, delta: float) -> void:
	var wanted := 0.0
	if riding_now:
		var ahead := facing() * 2.0
		var front := field.height_at(global_position.x + ahead.x, global_position.z + ahead.z)
		var back := field.height_at(global_position.x - ahead.x, global_position.z - ahead.z)
		# Rising ground ahead tips the rider back, falling ground tips them
		# forward; the rise over four metres is the slope.
		wanted = clampf(atan2(back - front, 4.0), -RIDE_LEAN_LIMIT, RIDE_LEAN_LIMIT)
	_ride_lean = lerpf(_ride_lean, wanted, 1.0 - exp(-5.0 * delta))
	_visual.rotation.x = _swim_lean + _ride_lean

## How far the rider is leaning with the slope. For the checks.
func ride_lean() -> float:
	return _ride_lean

## How far the machine is laid into the corner it is taking. For the checks.
func ride_bank() -> float:
	return _ride_bank

## How deep the drawn body is sitting, and how far it is tipped. For the
## checks — the collider does not move, so nothing else can see this.
func swim_sink() -> float:
	return _swim_sink

func swim_lean() -> float:
	return _swim_lean

## A bow: a curved stave held out at the side, a string, and an arrow on it.
## Simple on purpose — at the size it is drawn, what has to read is the shape
## of the thing and the fact that the string moves.
func _build_bow() -> Node3D:
	var bow := Node3D.new()
	bow.name = "Bow"
	# Out to the left and forward a little, at the height of the hands.
	bow.position = Vector3(-0.34, HEIGHT * 0.60, -0.18)
	var timber := StandardMaterial3D.new()
	timber.albedo_color = Color(0.48, 0.32, 0.18)
	timber.roughness = 0.9
	var pale := StandardMaterial3D.new()
	pale.albedo_color = Color(0.92, 0.90, 0.84)
	pale.roughness = 0.7

	# The stave, in five short segments bent into an arc, because a bow that
	# is a straight stick is a stick.
	for i in 5:
		var t := float(i) / 4.0
		var angle := lerpf(-0.62, 0.62, t)
		var limb := MeshInstance3D.new()
		var wood := CylinderMesh.new()
		wood.top_radius = 0.022
		wood.bottom_radius = 0.022
		wood.height = 0.2
		wood.radial_segments = 5
		limb.mesh = wood
		limb.material_override = timber
		limb.transform = Transform3D(
			Basis(Vector3.FORWARD, angle * 0.5),
			Vector3(sin(angle) * 0.1, cos(angle) * 0.36, 0.0) - Vector3(0.0, 0.36, 0.0) + Vector3(0.0, 0.36, 0.0)
		)
		limb.position = Vector3(-absf(sin(angle)) * 0.06, lerpf(-0.38, 0.38, t), 0.0)
		bow.add_child(limb)

	_bow_string = Node3D.new()
	var string := MeshInstance3D.new()
	var cord := CylinderMesh.new()
	cord.top_radius = 0.006
	cord.bottom_radius = 0.006
	cord.height = 0.78
	cord.radial_segments = 4
	string.mesh = cord
	string.material_override = pale
	_bow_string.add_child(string)
	bow.add_child(_bow_string)

	_bow_arrow = MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.012
	shaft.bottom_radius = 0.012
	shaft.height = 0.62
	shaft.radial_segments = 4
	_bow_arrow.mesh = shaft
	_bow_arrow.material_override = timber
	# Lying along the line of sight, which is -Z.
	_bow_arrow.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, 0.0, -0.1))
	bow.add_child(_bow_arrow)
	return bow

## Show the bow, drawn as far as the string is pulled. Called by the game
## while the shoot button is held; `drawn` is 0 to 1.
func hold_the_bow(shown: bool, drawn: float) -> void:
	if _bow == null:
		return
	_bow.visible = shown
	_draw_shown = clampf(drawn, 0.0, 1.0)
	if not shown:
		return
	# The string and the arrow come back towards the child as it is drawn.
	var back := _draw_shown * 0.28
	_bow_string.position.z = back
	_bow_arrow.position.z = -0.1 + back

## How far the drawn bow is shown pulled. For the checks.
func bow_draw() -> float:
	return _draw_shown

func bow_shown() -> bool:
	return _bow != null and _bow.visible

## The direction the body is turned, as an angle. Read by a mount so it faces
## the same way its rider does.
func facing_angle() -> float:
	return _visual.rotation.y

func facing() -> Vector3:
	return Vector3(-sin(_visual.rotation.y), 0.0, -cos(_visual.rotation.y))

## Turn the body towards a direction while being carried, when there is no
## walking to turn it — down the slide, for one. Eased, like walking is.
func face(direction: Vector3) -> void:
	if direction.length_squared() < 0.0001:
		return
	_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-direction.x, -direction.z), 0.2)

func is_sprinting() -> bool:
	return Input.is_action_pressed(InputActions.SPRINT) and run_fraction() > 0.4

## Current planar speed as a fraction of a full run. Drives the camera's field
## of view and, later, animation blending.
func run_fraction() -> float:
	return clampf(Vector3(velocity.x, 0.0, velocity.z).length() / RUN_SPEED, 0.0, 1.0)
