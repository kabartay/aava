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
## ball settles instead of pinging around the pitch forever.
const BOUNCE := 0.62

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

## How close the player must be to strike it.
##
## This has to exceed the distance at which the player's own capsule pushes the
## ball away, or walking up to a ball shoves it just out of range and it can
## never be kicked at all. Player radius 0.34 plus ball radius 0.24 is 0.58 of
## contact, so a reach of 1.9 leaves real room to stand next to it and swing.
const KICK_REACH := 1.9

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
## long the button was held, loft is how high the camera was looking.
##
## Returns the resulting speed in metres per second, or zero if the striker was
## not close enough to reach it.
func kick(from: Vector3, facing: Vector3, sprinting: bool, strength := 1.0, loft := 0.25, look := Vector3.ZERO) -> float:
	var offset := position - from
	offset.y = 0.0
	if offset.length() > KICK_REACH + RADIUS:
		return 0.0

	var launch := launch_velocity(position, from, facing, sprinting, strength, loft, look)
	var speed := launch.length()
	strike(launch, strength, loft)
	return speed

## Give the ball a launch velocity, however it was worked out: by a kick on this
## phone, or by the host on behalf of a guest who asked for it.
func strike(launch: Vector3, strength: float, loft: float) -> void:
	var direction := Vector3(launch.x, 0.0, launch.z).normalized()
	var speed := launch.length()
	var charged := clampf(strength, 0.0, 1.0)

	sleeping = false
	# The velocity is set outright rather than applied as an impulse. An impulse
	# is only integrated when the physics server steps the body, so a ball that
	# has not been stepped yet — on the first frame, or in a headless check —
	# silently absorbs the kick and stays put. Setting velocity is also the
	# truthful model here: a kick replaces the ball's motion, it does not add to
	# whatever it was already doing.
	linear_velocity = launch
	# A little sidespin off the striking foot, so the ball visibly turns over.
	# Backspin on a lofted chip, topspin on a flat drive, because that is what
	# the striking foot would actually impart and it reads correctly in flight.
	angular_velocity = direction.cross(Vector3.UP) * speed * lerpf(1.1, -0.7, clampf(loft, 0.0, 1.0))

	kicked.emit(charged, clampf(loft, 0.0, 1.0))

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

## Where the camera looking along `look` sends a kick from `from` at a ball at
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
## Which way it goes is `aim_direction`: where the camera looks, `look`, so a
## child turns the view to aim; and the run-up line from striker to ball when
## no look is given or the ball is well off to one side of the view. Strength is
## squared, so the first half of the hold barely adds anything and the last
## quarter adds a lot — winding up rather than being dragged up to speed.
static func launch_velocity(at: Vector3, from: Vector3, facing: Vector3, sprinting: bool, strength: float, loft: float, look := Vector3.ZERO) -> Vector3:
	var direction := aim_direction(at, from, facing, look)
	var charged := clampf(strength, 0.0, 1.0)
	var speed := lerpf(KICK_SPEED_MIN, KICK_SPEED_MAX, charged * charged)
	if sprinting:
		speed += SPRINT_BONUS
	var lift := lerpf(LIFT_FLAT, LIFT_HIGH, clampf(loft, 0.0, 1.0))
	return (direction + Vector3.UP * lift).normalized() * speed

## A child jogging at a ball should be able to take it along rather than boot it
## away, so below this pace the ball is eased onto the child's own line: a
## gentle touch. Faster than this it is left to the physics, which is how a run
## at the ball still sends it far.
const TOUCH_SPEED := 4.6
## Below this the child is standing, not dribbling, and the ball is left alone.
const TOUCH_MIN_SPEED := 0.3
## How far from the feet a ball can be and still be taken along, and how far
## ahead of them it is kept: just clear of the capsule's own 0.58 of contact, so
## the ball rolls on in front instead of being shoved and chased.
const TOUCH_REACH := 1.25
const TOUCH_AHEAD := 0.85

## What a ball at `at` moving at `ball_v` does in this step, for a child at
## `from` moving at `foot_v`. Pure, so the host can apply it for its own child
## and for each guest's body, and a guest's phone can show the same thing. The
## slower the child, the stronger the pull, fading to nothing at TOUCH_SPEED,
## and only for a ball that is in front of them and on the ground.
static func touch_velocity(at: Vector3, ball_v: Vector3, from: Vector3, foot_v: Vector3, delta: float) -> Vector3:
	var run := Vector3(foot_v.x, 0.0, foot_v.z)
	var pace := run.length()
	if pace < TOUCH_MIN_SPEED or pace >= TOUCH_SPEED:
		return ball_v
	var offset := at - from
	var rise := offset.y
	offset.y = 0.0
	if offset.length() > TOUCH_REACH or rise > 0.8 or rise < -0.5:
		return ball_v
	var way := run / pace
	if offset.length() > 0.05 and offset.normalized().dot(way) < 0.5:
		return ball_v
	# Where the ball would like to be, and the pace that gets it there while
	# keeping up with the child.
	var spot := from + way * TOUCH_AHEAD
	var want := run + Vector3(spot.x - at.x, 0.0, spot.z - at.z) * 4.0
	var pull := (1.0 - smoothstep(2.0, TOUCH_SPEED, pace)) * clampf(delta * 10.0, 0.0, 1.0)
	var flat := Vector3(ball_v.x, 0.0, ball_v.z).lerp(want, pull)
	return Vector3(flat.x, ball_v.y, flat.z)

## Where a ball launched from `start` at `velocity` will be, every `step`
## seconds for up to `seconds`, under this world's gravity and the ball's
## drag — integrated the way the physics server does it, so the dots land
## where the ball does. Stops early where `ground` says the ball has landed.
static func predict(start: Vector3, velocity: Vector3, damp: float, gravity: float, seconds: float, step: float, ground: Callable) -> PackedVector3Array:
	var points := PackedVector3Array()
	var at := start
	var v := velocity
	var fine := 1.0 / 120.0
	var t := 0.0
	var since_point := step
	while t < seconds:
		v.y -= gravity * fine
		v *= maxf(0.0, 1.0 - damp * fine)
		at += v * fine
		t += fine
		since_point += fine
		if since_point >= step:
			since_point = 0.0
			if at.y < float(ground.call(at.x, at.z)) + RADIUS:
				points.append(Vector3(at.x, float(ground.call(at.x, at.z)) + RADIUS, at.z))
				break
			points.append(at)
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
