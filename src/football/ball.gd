class_name Ball
extends RigidBody3D

## A football.
##
## Real physics rather than a scripted arc, because the whole appeal of kicking
## a ball is that it does what a ball does: it rolls, it bounces off a post, it
## rattles along the ground when you scuff it. A child feels the difference
## between a simulated ball and an animated one immediately, even if he could
## never say what it was.
##
## The tuning is deliberately not realistic. A regulation ball is heavy and
## dead; this is a plastic size-three on a school field — light, lively, and
## forgiving of a bad touch.

const RADIUS := 0.24
const MASS := 0.42

## How much speed survives a bounce. High enough to be fun, low enough that the
## ball settles instead of pinging around the pitch forever. A football dropped
## on grass comes back to a third of its height or so, which is about 0.55.
##
## The physics server does not multiply the two bodies' bounciness: Jolt takes
## the larger. So this is also the floor under every post and net — nothing the
## ball hits can be deader than this — and the net is made dead in
## `_integrate_forces` below rather than by its material.
const BOUNCE := 0.55

## Rolling drag. Without it a ball on level ground never stops, and a pitch
## strewn with balls that will not settle is unplayable.
## Rolling drag. Lowered along with the kick ceiling — a hard shot that stops
## dead after ten metres reads as hitting an invisible wall.
const ROLL_DAMP := 0.32
const SPIN_DAMP := 1.35

## The range of kick strength, from the gentlest tap to a full swing.
##
## The floor matters as much as the ceiling: a child needs to be able to nudge
## the ball two metres to line up a shot, and if the softest possible kick sends
## it forty metres then dribbling is impossible and the pitch is useless.
const KICK_SPEED_MIN := 3.2
## The ceiling is set by the pitch, not by taste: a full swing from the halfway
## line has to reach the goal, or the only way to score is to dribble the ball
## in, and shooting stops being worth trying.
const KICK_SPEED_MAX := 26.0

## How long the button must be held to go from the softest kick to the hardest.
## Short enough that a full-power shot is one deliberate press rather than a
## wait, long enough that a quick tap is reliably gentle.
const CHARGE_TIME := 0.85

## Running at the ball adds to whatever the charge gave. Kept as a bonus rather
## than folded into the charge so that a six-year-old who never holds the button
## still has a way to hit it hard: just run at it.
const SPRINT_BONUS := 4.5

## How much of the kick goes upward, from a flat drive along the ground to a
## lofted chip. Chosen by where the camera is looking, so aiming high is done
## by looking up.
const LIFT_FLAT := 0.02
const LIFT_HIGH := 1.35

## How close the player must be to strike it: the ball's centre may be this far
## plus its radius from the child, along the ground.
##
## It is what a foot can honestly reach. A child's leg is 0.47 m, so the toe is
## about 0.4 m from the hip with the leg straight; the kick lunges 0.4 m forward
## (RigMotion.KICK_LUNGE) and the ball's own radius is 0.24 m, which comes to
## about a metre. At 1.9 the ball used to leave from two metres away while
## the leg had barely moved. It still exceeds the 0.58 at which a child and a
## ball touch (radius 0.34 plus 0.24), so there is room to stand beside it.
const KICK_REACH := 0.86

## How far above the child's feet a ball can be and still be struck: a
## knee-high volley, but not a chip sailing overhead, which used to be kickable
## from anywhere underneath it.
const KICK_RISE := 1.0

## Below this speed the ball counts as at rest.
const AT_REST_SPEED := 0.35

## How far from the ring a basketball is thrown at it rather than kicked along
## the ground, and how long the throw is in the air, by distance. Gravity here
## is two and a half times Earth's, so these are short: at 1.15 s a throw from
## the edge of the range still peaks two and a half metres over the ring, and
## any longer sent the ball up like a flare.
const THROW_RANGE := 9.0
const THROW_TIME_NEAR := 0.85
const THROW_TIME_FAR := 1.15
## How far off the mark a careless throw lands, and a careful one. Even the
## careless one is inside the ring most of the time, because a six-year-old
## taps the button and should still see the ball go in.
const THROW_SLACK_LOOSE := 0.26
const THROW_SLACK_TIGHT := 0.05

## Emitted with the strength of the kick, from 0 to 1, and its loft, also 0 to
## 1. The interface uses these to say what is about to happen.
signal kicked(strength: float, loft: float)

var home := Vector3.ZERO

## What a ball looks like. A football is white with dark panels; a basketball is
## orange with dark seams. Same physics — a child kicks both.
enum Look {FOOTBALL, BASKETBALL}

var look: Look = Look.FOOTBALL

func _init(start: Vector3, which: Look = Look.FOOTBALL) -> void:
	look = which
	home = start
	position = start

	mass = MASS
	# Continuous collision detection: a struck ball crosses more than its own
	# diameter in one physics tick, and without this it tunnels straight
	# through a goalpost instead of hitting it.
	continuous_cd = true
	# Bounces off a hoop's pole and a swing's post, not only the ground.
	collision_mask = TerrainSpec.LAYER_GROUND | TerrainSpec.LAYER_PROPS | TerrainSpec.LAYER_VISITORS
	# On the props layer, not the default ground layer: the camera's arm stops
	# at the ground and the walls, and a ball left behind the child on the
	# ground layer shoved the camera in to nothing whenever it rolled between
	# the two. The player still meets it, because the player's mask has props.
	collision_layer = TerrainSpec.LAYER_PROPS
	# Told what it has touched, so `_integrate_forces` can tell a net from a post.
	contact_monitor = true
	max_contacts_reported = 4
	can_sleep = true
	linear_damp = ROLL_DAMP
	angular_damp = SPIN_DAMP

	var bounce := PhysicsMaterial.new()
	bounce.bounce = BOUNCE
	bounce.friction = 0.55
	physics_material_override = bounce

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = RADIUS
	shape.shape = sphere
	add_child(shape)

	var mesh := MeshInstance3D.new()
	mesh.mesh = _build_mesh(look)
	var skin := StandardMaterial3D.new()
	skin.vertex_color_use_as_albedo = true
	skin.vertex_color_is_srgb = true
	skin.roughness = 0.62
	mesh.material_override = skin
	add_child(mesh)

## A ball with dark panels, so that spin is visible. A plain white sphere
## rolling looks exactly like a plain white sphere sitting still, and half the
## pleasure of kicking something is watching it turn over.
##
## The panels are painted into the sphere's own vertex colours rather than added
## as separate blobs. Blobs were tried first and were a mistake: a sphere sunk
## into a sphere still bulges, and twelve of them turned a football into a
## blackberry. Colouring the vertices it already has costs no geometry and
## cannot bulge by construction.
func _build_mesh(which: Look) -> Mesh:
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	sphere.radial_segments = 24
	sphere.rings = 14

	var arrays := sphere.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	# The twelve vertices of an icosahedron, which is where a real ball's
	# pentagons sit.
	var golden := (1.0 + sqrt(5.0)) * 0.5
	var seeds: Array[Vector3] = []
	var base: Array[Vector3] = [
		Vector3(0.0, 1.0, golden), Vector3(0.0, -1.0, golden),
		Vector3(1.0, golden, 0.0), Vector3(-1.0, golden, 0.0),
		Vector3(golden, 0.0, 1.0), Vector3(golden, 0.0, -1.0),
	]
	var sides := PackedFloat32Array([1.0, -1.0])
	for direction in base:
		for side in sides:
			seeds.append(direction.normalized() * side)

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in indices.size():
		var vertex := vertices[indices[i]]
		var unit := vertex.normalized()
		# Nearest panel centre decides the colour, so panels meet along the
		# midlines between them the way stitching does.
		var nearest := -1.0
		for seed_direction in seeds:
			nearest = maxf(nearest, unit.dot(seed_direction))
		if which == Look.BASKETBALL:
			# Seams: the three great circles where the unit vector is nearly in
			# a coordinate plane. Orange between them, the way the real thing is.
			var seam := (
				absf(unit.x) < 0.07 or absf(unit.y) < 0.07 or absf(unit.z) < 0.07
			)
			tool.set_color(Color(0.16, 0.10, 0.06) if seam else Color(0.86, 0.43, 0.14))
		else:
			var panel := nearest > 0.905
			tool.set_color(Color(0.13, 0.14, 0.18) if panel else Color(0.96, 0.96, 0.94))
		tool.add_vertex(vertex)
	tool.generate_normals()
	return tool.commit()

## Strike the ball. `strength` and `loft` both run from 0 to 1: strength is how
## long the button was held, loft is how far the finger slid up on it. `turn` is
## how far, in radians, the finger slid sideways: positive is to the child's right.
##
## Returns the resulting speed in metres per second, or zero if the striker was
## not close enough to reach it.
func kick(from: Vector3, facing: Vector3, sprinting: bool, strength := 1.0, loft := 0.25, look := Vector3.ZERO, turn := 0.0) -> float:
	if not within_reach(position, from):
		return 0.0

	var launch := launch_velocity(position, from, facing, sprinting, strength, loft, look, turn)
	var speed := launch.length()
	strike(launch, strength, loft)
	return speed

## Whether a ball at `at` is where a child at `from` (their feet) can strike it.
static func within_reach(at: Vector3, from: Vector3) -> bool:
	var offset := at - from
	var rise := offset.y
	offset.y = 0.0
	return offset.length() <= KICK_REACH + RADIUS and rise <= KICK_RISE

## How much of its speed a ball keeps each tick it is touching netting. The
## material cannot make the net dead (see BOUNCE), so this does: a shot that hits
## the back of the goal drops where it hit.
const NET_KEEPS := 0.12

## A ball that struck a post, the bar or a wall at more than this should leave it
## with the bounce of that surface, and is made to if the engine took it away. The
## continuous collision pass that stops a fast ball at the surface hands back only
## about a quarter to a third of what the material asks (measured 0.30 of the
## speed off a post at 11.9 m/s, against 0.8 for the woodwork), and for one shot
## in four it left the ball nearly dead at the post's foot instead of ringing off it.
const REBOUND_FROM := 3.0

## How fast the ball was going at the start of the last two steps: the engine
## has already cut or turned it by the time `_integrate_forces` sees the contact,
## and the cut comes a step before the turn.
var _seen := Vector3.ZERO
var _seen_earlier := Vector3.ZERO

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var before := _seen
	var earlier := _seen_earlier
	_seen_earlier = _seen
	_seen = state.linear_velocity
	for i in state.get_contact_count():
		var other := state.get_contact_collider_object(i) as Node
		if other != null and other.is_in_group(Goal.NET_GROUP):
			state.linear_velocity *= NET_KEEPS
			state.angular_velocity *= NET_KEEPS
			return
	var worst := 0.0
	var way := Vector3.ZERO
	for i in state.get_contact_count():
		var solid := state.get_contact_collider_object(i) as CollisionObject3D
		# The grass has its own bounce, which the engine gets right.
		if solid == null or (solid.collision_layer & TerrainSpec.LAYER_GROUND) != 0:
			continue
		# The surface's own normal, turned to face the ball: from the contact
		# point alone it is unreliable when the ball has sunk into a post.
		var outward := state.get_contact_local_normal(i)
		if outward.dot(state.transform.origin - state.get_contact_local_position(i)) < 0.0:
			outward = -outward
		var closing := maxf(-before.dot(outward), -earlier.dot(outward))
		if closing < REBOUND_FROM:
			continue
		var kept := BOUNCE
		var body := solid as PhysicsBody3D
		if body != null and body.physics_material_override != null:
			kept = maxf(kept, body.physics_material_override.bounce)
		var short := kept * closing - state.linear_velocity.dot(outward)
		if short > worst:
			worst = short
			way = outward
	if worst > 0.0:
		state.linear_velocity += way * worst

## Give the ball a launch velocity, however it was worked out: by a kick on this
## phone, or by the host on behalf of a guest who asked for it.
func strike(launch: Vector3, strength: float, loft: float) -> void:
	var charged := clampf(strength, 0.0, 1.0)

	sleeping = false
	# The velocity is set outright rather than applied as an impulse. An impulse
	# is only integrated when the physics server steps the body, so a ball that
	# has not been stepped yet — on the first frame, or in a headless check —
	# silently absorbs the kick and stays put. Setting velocity is also the
	# truthful model here: a kick replaces the ball's motion, it does not add to
	# whatever it was already doing.
	linear_velocity = launch
	angular_velocity = spin_of(launch, loft)

	kicked.emit(charged, clampf(loft, 0.0, 1.0))

## How a ball turns as it leaves the foot, in radians a second. A flat drive
## leaves rolling over the way it is going, as fast as it would roll on the
## grass (speed over radius), so it does not skid for the first metres; a chip
## leaves with a gentler backspin, which is what a foot under the ball gives.
## The sign was the wrong way round before, so that a drive visibly spun
## backwards until the grass turned it, and at a quarter of the true rate.
static func spin_of(launch: Vector3, loft: float) -> Vector3:
	var direction := Vector3(launch.x, 0.0, launch.z).normalized()
	var rolling := launch.length() / RADIUS
	return direction.cross(Vector3.UP) * rolling * lerpf(-1.0, 0.35, clampf(loft, 0.0, 1.0))

## What a launch velocity says about the kick that made it, undoing
## launch_velocity: how hard the button was held, and how high it was aimed. For
## a host that is told only the velocity but still wants the spin to look right.
static func strength_of(launch: Vector3) -> float:
	var swing := maxf(launch.length() - KICK_SPEED_MIN, 0.0) / (KICK_SPEED_MAX - KICK_SPEED_MIN)
	return clampf(sqrt(swing), 0.0, 1.0)

static func loft_of(launch: Vector3) -> float:
	var flat := Vector2(launch.x, launch.z).length()
	if flat < 0.0001:
		return 1.0 if launch.y > 0.0 else 0.0
	return clampf(inverse_lerp(LIFT_FLAT, LIFT_HIGH, launch.y / flat), 0.0, 1.0)

## Draw a ball that is following the host where the host says it is. The
## physics server is told as well as the node, or the ball would jump back to its
## last simulated place the moment it is let go.
func show_at(where: Vector3, turn: Quaternion) -> void:
	position = where
	basis = Basis(turn)
	PhysicsServer3D.body_set_state(
		get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(Basis(turn), where)
	)

## The fastest launch a kick can give: a full swing at a sprint.
const KICK_SPEED_CEILING := KICK_SPEED_MAX + SPRINT_BONUS

## Let the host's valley move this ball, or take it back. While another phone
## is the one simulating the game this ball is only drawn where it is told: it
## stays where it is put, and neither pushes nor is pushed by anything here, or
## this phone would argue with the host's about where the ball is.
func follow_the_host(on: bool) -> void:
	if on == freeze:
		return
	if on:
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		freeze = true
		collision_layer = 0
		collision_mask = 0
		# A frozen body keeps the velocity it had. Left going, a ball that was
		# rolling when the visit began would be let go again at that pace.
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		return
	freeze = false
	collision_layer = TerrainSpec.LAYER_PROPS
	collision_mask = TerrainSpec.LAYER_GROUND | TerrainSpec.LAYER_PROPS | TerrainSpec.LAYER_VISITORS
	sleeping = false

## How far from the ball the run-up line stops counting and the child's own
## facing takes over, and how far it has fully handed over.
const RUN_UP_NEAR := 1.2
const RUN_UP_FAR := 2.0

## Where a kick from `from` at a ball at `at` goes along the ground when the
## child has not slid the finger: the way they face. The game passes no `look`;
## it is an optional second opinion, kept for callers that still have one.
##
## Where a camera looking along `look` would send a kick from `from` at a ball at
## `at`, along the ground. The ball straight ahead of the view goes the way the
## view points. A child who walked at a ball that is off to one side of the view
## still kicks it the way they walked, so between ten and eighty degrees of
## difference the two are blended, turning smoothly from one to the other and
## never jumping; past eighty degrees it is the run-up line alone.
static func aim_direction(at: Vector3, from: Vector3, facing: Vector3, look := Vector3.ZERO) -> Vector3:
	var offset := at - from
	offset.y = 0.0
	var flat_look := Vector3(look.x, 0.0, look.z)
	var run := offset.normalized() if offset.length_squared() > 0.02 else Vector3.ZERO
	# Close in, the line from the child to the ball says nothing about where they
	# mean it to go: a child standing beside the ball, or a step past it, would
	# send it sideways or straight back at themselves. Within a stride of the
	# ball it is the way the child faces that counts, fading to the line between
	# them from a couple of metres out, where it really is the run-up.
	var flat_facing := Vector3(facing.x, 0.0, facing.z)
	if run != Vector3.ZERO and flat_facing.length_squared() > 0.0001:
		var close := 1.0 - smoothstep(RUN_UP_NEAR, RUN_UP_FAR, offset.length())
		var mixed := run.lerp(flat_facing.normalized(), close)
		run = mixed.normalized() if mixed.length_squared() > 0.0001 else flat_facing.normalized()
	if flat_look.length_squared() < 0.0001:
		return run if run != Vector3.ZERO else facing
	flat_look = flat_look.normalized()
	if run == Vector3.ZERO:
		return flat_look
	var off := run.angle_to(flat_look)
	var run_weight := smoothstep(deg_to_rad(10.0), deg_to_rad(80.0), off)
	if run_weight >= 1.0:
		return run
	return flat_look.slerp(run, run_weight)

## The velocity a kick gives a ball at `at`, from a striker at `from`. Pure,
## so the aim preview can draw where the ball will go before it is kicked and
## be right about it — the same arithmetic, in one place.
##
## Which way it goes is `aim_direction`: with no `look`, the way the child faces
## close to the ball and the run-up line from further out, and then turned by
## `turn` radians (positive to the right) — the sideways slide of the finger on
## the kick button. `loft` is the upward slide. Strength is
## squared, so the first half of the hold barely adds anything and the last
## quarter adds a lot — winding up rather than being dragged up to speed.
static func launch_velocity(at: Vector3, from: Vector3, facing: Vector3, sprinting: bool, strength: float, loft: float, look := Vector3.ZERO, turn := 0.0) -> Vector3:
	var direction := aim_direction(at, from, facing, look)
	if not is_zero_approx(turn):
		# Positive is to the right, and a positive turn about up is to the left.
		direction = direction.rotated(Vector3.UP, -turn)
	var charged := clampf(strength, 0.0, 1.0)
	var speed := lerpf(KICK_SPEED_MIN, KICK_SPEED_MAX, charged * charged)
	if sprinting:
		speed += SPRINT_BONUS
	var lift := lerpf(LIFT_FLAT, LIFT_HIGH, clampf(loft, 0.0, 1.0))
	return (direction + Vector3.UP * lift).normalized() * speed

## Dribbling. A child on a phone runs at one of two paces, a walk and the full
## RUN_SPEED of 6.6 m/s, so taking a ball along has to work at every pace up to
## that, not only a jog: the ball is held a short way in front of the feet and
## steered onto the line the child is running, which turns with them. It used to
## be eased only below 4.6 m/s and a child at full stick hit the ball with the
## body instead, which sent it off at the run pace and a bit over, along the line
## from the body to the ball: a boot, and a sideways squirt whenever the ball was
## not exactly ahead.
##
## Below this the child is standing, not dribbling: a slow ball is stopped at
## their feet (TRAP_SPEED) and a fast one bounces off.
const TOUCH_MIN_SPEED := 0.3
## How far from the feet a ball can be and still be taken along: this much and a
## tenth of a metre for each metre a second of the child's pace, since a faster
## child meets the ball in a stride and has to be able to take it up before the
## body is on it.
const TOUCH_REACH := 1.25
const TOUCH_REACH_PER_PACE := 0.1
## Where the ball is held, ahead of the feet: just clear of the capsule's own 0.58
## of contact, and well inside the kick's reach (KICK_REACH plus the ball's
## radius), so a child who stops has it where they can strike it.
const TOUCH_AHEAD := 0.75
## How strongly the ball is steered onto its place, in metres a second for each
## metre it is out; and how quickly it takes up the pace it is steered to, per
## second. The grip is applied as 1 - e^(-grip * delta), so a frame twice as long
## takes twice the step and the ball does the same at 30, 60 and 120 Hz.
const TOUCH_SPRING := 10.0
const TOUCH_GRIP := 22.0
## The most the steering adds to the child's own pace, in metres a second: a ball
## well out of place is brought back at a walking pace over the child's, never
## whipped across (which sent it past the child and, being then faster than the
## child, out of the touch altogether). Less than TOUCH_LEAVES.
const TOUCH_CATCH_UP := 2.0
## A ball already travelling with the child (at least this fraction of their
## pace) is kept while it is beside them, so it follows a turn; one lying still
## has to be in front of them (within about 70 degrees) to be taken at all.
const TOUCH_CARRIED := 0.5
const TOUCH_CONE := 0.35
const TOUCH_CARRIED_CONE := -0.25
## A ball moving away from the child faster than this over their own pace has
## been kicked (or passed) and is left alone. A carried ball runs ahead of a
## child who is braking or turning by up to two metres a second (the pace dips
## by 30% through a quarter turn); this is more than that.
const TOUCH_LEAVES := 3.5
## A ball whose centre is above this over the feet, or rising faster than
## TOUCH_LOFT_SPEED, is in the air: the feet go under it.
const TOUCH_LOFT := 0.6
const TOUCH_LOFT_SPEED := 1.5
## A standing child traps a ball within KICK_REACH plus its radius that is moving
## slower than this: it is braked to rest at TRAP_BRAKE a second (a fraction of
## its pace, exponentially) and stopped when it is slower than TRAP_STOP.
const TRAP_SPEED := 3.0
const TRAP_BRAKE := 12.0
const TRAP_STOP := 0.15

## How much of its pace a ball rolled at a standing child gives back when it hits
## the body: nothing for a soft pass (it stops at the feet), half of it
## from PUSH_BOUNCE_FROM up, in between smoothly. Over TRAP_SPEED the ball is
## then not stopped again by the trap.
const PUSH_BOUNCE := 0.5
const PUSH_SOFT := 3.0
const PUSH_BOUNCE_FROM := 5.0
## How fast a ball is eased out from under a child who has stepped onto it.
const PUSH_OUT := 1.0
## How hard a ball that has sunk into a child running with it is nudged back out
## to the front, in metres a second for each metre it has sunk.
const PUSH_LEAD := 3.0
## How much of the line the body pushes a ball along is the way the child runs,
## when they are running: pushed along the line from body to ball alone it
## squirted off to the side whenever the ball was off the line of the run.
const PUSH_RUN_LINE := 0.8

## What the child's body does to a ball it is touching, flat along the ground.
## The ball and the child's capsule do not collide with one another in the
## physics server (the capsule stopped dead against the ball, a running child
## stood still, and one that kept going climbed onto it): this is the whole of
## their meeting. A ball that the body is closing on leaves with the body's own
## pace and a little over, along the way the child runs (or, for a standing
## child, the line between them); a ball coming at a standing child stops if it
## is soft and bounces off if it is hard; the ball's height is never touched, so
## a body can neither pass through the ball nor launch it into the air.
##
## The body is taken to have swept the ground it covered in `delta`, not only to
## stand where it ends: a frame that takes a tenth of a second (a chunk of
## valley arriving) moves a running child most of a metre, and a ball in that
## stride was stepped over.
static func pushed_velocity(at: Vector3, ball_v: Vector3, from: Vector3, foot_v: Vector3, delta := 0.0) -> Vector3:
	var rise := at.y - from.y
	if rise > KICK_RISE or rise < -0.5:
		return ball_v
	var run := Vector3(foot_v.x, 0.0, foot_v.z)
	var stride := run * clampf(delta, 0.0, 0.25)
	var started := Vector3(from.x, 0.0, from.z) - stride
	var along := 1.0
	if stride.length_squared() > 0.000001:
		along = clampf((Vector3(at.x, 0.0, at.z) - started).dot(stride) / stride.length_squared(), 0.0, 1.0)
	var nearest := started + stride * along
	var offset := Vector3(at.x, 0.0, at.z) - nearest
	var contact := Player.RADIUS + RADIUS
	var gap := offset.length()
	if gap > contact:
		return ball_v
	var way := offset / gap if gap > 0.01 else Vector3.ZERO
	# The body went over the ball in this very frame: it is pushed on ahead of
	# them, along the way they were going.
	if along < 1.0 and run.length_squared() > 0.01 and (at - from).dot(run) < 0.0:
		way = run.normalized()
	if way == Vector3.ZERO:
		if run.length_squared() < 0.01:
			return ball_v
		way = run.normalized()
	# A running child sends the ball along their run, not off at a tangent.
	if run.length_squared() > 1.0:
		var heading := run.normalized()
		if way.dot(heading) > 0.0:
			way = way.lerp(heading, PUSH_RUN_LINE).normalized()
	var body_n := foot_v.dot(way)
	var ball_n := ball_v.dot(Vector3(way.x, 0.0, way.z))
	var want := ball_n
	if ball_n - body_n < 0.0:
		# Closing: leave at the body's pace plus a rebound of the ball's own
		# pace toward the body (none of a soft pass); a running child meeting a
		# ball at rest is not bounced off it at 1.25 times their pace.
		var coming := maxf(-ball_n, 0.0)
		want = body_n + coming * PUSH_BOUNCE * smoothstep(PUSH_SOFT, PUSH_BOUNCE_FROM, coming)
	if gap < contact - 0.08:
		want = maxf(want, PUSH_OUT)
	if body_n > 0.5:
		want = maxf(want, body_n + (contact - gap) * PUSH_LEAD)
	return ball_v + way * (want - ball_n)

## What a ball at `at` moving at `ball_v` does in this step, for a child at
## `from` moving at `foot_v`. Pure, so the host can apply it for its own child
## and for each guest's body, and a guest's phone can show the same thing.
##
## A ball a running child is at or has beside them is taken along and steered
## onto the child's line a short way ahead of the feet; once the child stands it
## is stopped at their feet if it is slow. A ball leaving faster than the child
## (a kick, a pass) or in the air is left alone, except that the body is never
## passed through it (pushed_velocity).
static func touch_velocity(at: Vector3, ball_v: Vector3, from: Vector3, foot_v: Vector3, delta: float) -> Vector3:
	var rise := at.y - from.y
	if rise > TOUCH_LOFT or ball_v.y > TOUCH_LOFT_SPEED:
		return ball_v
	var run := Vector3(foot_v.x, 0.0, foot_v.z)
	var pace := run.length()
	var flat_v := Vector3(ball_v.x, 0.0, ball_v.z)
	var offset := Vector3(at.x - from.x, 0.0, at.z - from.z)
	var gap := offset.length()
	var out := offset / gap if gap > 0.01 else Vector3.ZERO
	var kept := ball_v
	if pace >= TOUCH_MIN_SPEED:
		var way := run / pace
		var reach := TOUCH_REACH + TOUCH_REACH_PER_PACE * pace
		var leaving := flat_v.length() > pace + TOUCH_LEAVES and flat_v.dot(out) > 0.0
		var ahead := out.dot(way)
		var carried := flat_v.dot(way) > pace * TOUCH_CARRIED
		if rise >= -0.5 and gap <= reach and not leaving and ahead > (TOUCH_CARRIED_CONE if carried else TOUCH_CONE):
			var spot := Vector3(from.x, 0.0, from.z) + way * TOUCH_AHEAD
			var steer := (spot - Vector3(at.x, 0.0, at.z)) * TOUCH_SPRING
			steer = steer.limit_length(TOUCH_CATCH_UP)
			var want := run + steer
			var grip := 1.0 - exp(-TOUCH_GRIP * clampf(delta, 0.0, 0.25))
			var flat := flat_v.lerp(want, grip)
			kept = Vector3(flat.x, ball_v.y, flat.z)
	elif gap <= KICK_REACH + RADIUS and flat_v.length() < TRAP_SPEED:
		# Stopped: a slow ball near the feet is brought to rest where it is.
		var slowed := flat_v * exp(-TRAP_BRAKE * clampf(delta, 0.0, 0.25))
		if slowed.length() < TRAP_STOP:
			slowed = Vector3.ZERO
		kept = Vector3(slowed.x, ball_v.y, slowed.z)
	# The body is never passed through, however the ball is being handled.
	return pushed_velocity(at, kept, from, foot_v, delta)

## The softest strike the button gives: even the shortest tap has to move the
## ball, or a child taps it and concludes the button is broken. One number for the
## kick, the aim indicator and the arrow-keys alike.
const TAP_STRENGTH := 0.12

## How far a ball that stays on the grass rolls for each metre a second it leaves
## at, measured on a flat drive: 4.8 m from 3.5 m/s, 12.2 m from 8.9 m/s, 35.9 m
## from 26 m/s. The aim indicator draws the roll with it, up to ROLL_SHOWN.
const ROLL_PER_SPEED := 1.38
const ROLL_SHOWN := 12.0
## A kick that comes down within this far of the foot is a drive along the
## grass, not a lob, and is drawn as a roll.
const DRIVE_LANDS_WITHIN := 1.5
## Spacing of the dots along a roll.
const ROLL_DOT_GAP := 0.6

## The line the aim indicator draws for a kick that leaves at `launch` from a ball
## at `at`: the arc to where it first comes down when it is lofted, and when it
## is a drive along the grass the line it rolls along, to about where it stops. At
## the height of the ball's centre, as the ball itself travels. Built on `predict`,
## so the arc is the ball's own arithmetic, and on the same `launch` the kick
## uses; this adds nothing of its own to the direction or the speed.
static func aim_path(at: Vector3, launch: Vector3, damp: float, gravity: float, ground: Callable) -> PackedVector3Array:
	var path := predict(at, launch, damp, gravity, 2.6, 0.09, ground, true)
	var flat := Vector3(launch.x, 0.0, launch.z)
	if not path.is_empty():
		var end := path[path.size() - 1]
		if Vector2(end.x - at.x, end.z - at.z).length() >= DRIVE_LANDS_WITHIN:
			return path
	if flat.length_squared() < 0.0001:
		return path
	var way := flat.normalized()
	var reach := minf(flat.length() * ROLL_PER_SPEED, ROLL_SHOWN)
	var rolled := PackedVector3Array()
	var gone := ROLL_DOT_GAP
	while gone <= reach + 0.001:
		var x := at.x + way.x * gone
		var z := at.z + way.z * gone
		rolled.append(Vector3(x, float(ground.call(x, z)) + RADIUS, z))
		gone += ROLL_DOT_GAP
	if rolled.is_empty():
		var x := at.x + way.x * reach
		var z := at.z + way.z * reach
		rolled.append(Vector3(x, float(ground.call(x, z)) + RADIUS, z))
	return rolled

## Where a ball launched from `start` at `velocity` will be, every `step`
## seconds for up to `seconds`, under this world's gravity and the ball's
## drag — integrated the way the physics server does it, so the dots land
## where the ball does. Stops early where `ground` says the ball has landed: at
## the first dot below the grass, or with `exact`, at the point between that dot
## and the one before where it actually came down.
static func predict(start: Vector3, velocity: Vector3, damp: float, gravity: float, seconds: float, step: float, ground: Callable, exact := false) -> PackedVector3Array:
	var points := PackedVector3Array()
	var at := start
	var v := velocity
	var fine := 1.0 / 120.0
	var t := 0.0
	var since_point := step
	var last := start
	while t < seconds:
		v.y -= gravity * fine
		v *= maxf(0.0, 1.0 - damp * fine)
		at += v * fine
		t += fine
		since_point += fine
		if since_point >= step:
			since_point = 0.0
			var grass := float(ground.call(at.x, at.z)) + RADIUS
			if at.y < grass and exact:
				# The ball came down somewhere between the last dot and here, and
				# the ring belongs where it did, not a whole step beyond: at a
				# full swing that step is several metres.
				var drop := last.y - at.y
				var down := last.lerp(at, clampf((last.y - grass) / drop, 0.0, 1.0)) if drop > 0.0001 else last
				points.append(Vector3(down.x, float(ground.call(down.x, down.z)) + RADIUS, down.z))
				break
			if at.y < grass:
				points.append(Vector3(at.x, grass, at.z))
				break
			points.append(at)
			last = at
	return points

## The velocity `throw_to` would use for `target` before its wobble: for the
## aim preview.
func throw_velocity(target: Vector3) -> Vector3:
	var flat := Vector2(target.x - position.x, target.z - position.z).length()
	var flight := lerpf(THROW_TIME_NEAR, THROW_TIME_FAR, clampf(flat / THROW_RANGE, 0.0, 1.0))
	var wanted := target - position
	var gravity := Vector3(0.0, -gravity_strength(), 0.0)
	var damp := effective_linear_damp()
	if damp < 0.0001:
		return wanted / flight - gravity * flight * 0.5
	var settled := gravity / damp
	return settled + (wanted - settled * flight) * damp / (1.0 - exp(-damp * flight))

## Lob the ball so that it comes down on `target`, with `accuracy` from 0 to
## 1 tightening the aim. Returns the launch velocity.
##
## Gravity pulls and the air drags the whole way up and down, and with both
## acting the velocity that arrives at a point after a given time has a
## closed form:
##     v(t) = g/d + (v0 - g/d) e^(-dt)
##     x(t) = x0 + (g/d) t + (v0 - g/d)(1 - e^(-dt)) / d
## solved here for v0. Leaving the drag out, as the first attempt did, put
## every throw a hand's width short of the ring.
func throw_to(target: Vector3, accuracy: float) -> Vector3:
	var flat := Vector2(target.x - position.x, target.z - position.z).length()
	var flight := lerpf(THROW_TIME_NEAR, THROW_TIME_FAR, clampf(flat / THROW_RANGE, 0.0, 1.0))
	var slack := lerpf(THROW_SLACK_LOOSE, THROW_SLACK_TIGHT, clampf(accuracy, 0.0, 1.0))
	var wobble := Vector3(randf_range(-slack, slack), 0.0, randf_range(-slack, slack))
	var wanted := target + wobble - position

	var gravity := Vector3(0.0, -gravity_strength(), 0.0)
	var damp := effective_linear_damp()
	var launch: Vector3
	if damp < 0.0001:
		launch = wanted / flight - gravity * flight * 0.5
	else:
		var settled := gravity / damp
		launch = settled + (wanted - settled * flight) * damp / (1.0 - exp(-damp * flight))

	sleeping = false
	# Set outright, for the reason given in kick(): an impulse on a body that
	# has not been stepped yet is lost.
	linear_velocity = launch
	# Backspin, the way a shot leaves the fingers.
	var direction := Vector3(wanted.x, 0.0, wanted.z).normalized()
	angular_velocity = direction.cross(Vector3.UP) * -5.0
	return launch

## What pulls the ball down, in metres per second squared, as the project has
## set it — which is not 9.8 here.
func gravity_strength() -> float:
	return float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * gravity_scale

## The drag the physics server actually applies: the body's own plus, in the
## default combine mode, the world's.
func effective_linear_damp() -> float:
	var total := linear_damp
	if linear_damp_mode == RigidBody3D.DAMP_MODE_COMBINE:
		total += float(ProjectSettings.get_setting("physics/3d/default_linear_damp", 0.1))
	return total

func speed() -> float:
	return linear_velocity.length()

func at_rest() -> bool:
	return speed() < AT_REST_SPEED

## Put the ball back on a spot, dead. Used after a goal, and after it is kicked
## into the river, which will happen constantly.
func reset_to(where: Vector3) -> void:
	sleeping = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	var landing := where + Vector3.UP * RADIUS
	position = landing
	# A physics body keeps its old transform until the next tick unless the
	# server is told directly, and the ball visibly teleports twice.
	PhysicsServer3D.body_set_state(
		get_rid(),
		PhysicsServer3D.BODY_STATE_TRANSFORM,
		Transform3D(Basis(), landing)
	)

static func _add(tool: SurfaceTool, source: PrimitiveMesh, transform: Transform3D, color: Color) -> void:
	var arrays := source.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for i in vertices.size():
			tool.set_color(color)
			tool.add_vertex(transform * vertices[i])
		return
	for i in indices.size():
		tool.set_color(color)
		tool.add_vertex(transform * vertices[indices[i]])
