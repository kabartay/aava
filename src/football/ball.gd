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
const ROLL_DAMP := 0.55
const SPIN_DAMP := 1.35

## How hard the player kicks, and how much of that goes upward. The lift is what
## turns a shot into something you can put over a keeper — or over the bar.
const KICK_SPEED := 9.5
const KICK_LIFT := 0.38

## Running into the ball hits it harder. This is the entire skill of shooting,
## and it is worth more to a six-year-old than any charge-up meter.
const SPRINT_BONUS := 5.5

## How close the player must be to strike it.
##
## This has to exceed the distance at which the player's own capsule pushes the
## ball away, or walking up to a ball shoves it just out of range and it can
## never be kicked at all. Player radius 0.34 plus ball radius 0.24 is 0.58 of
## contact, so a reach of 1.9 leaves real room to stand next to it and swing.
const KICK_REACH := 1.9

## Below this speed the ball counts as at rest.
const AT_REST_SPEED := 0.35

signal kicked(power: float)

var home := Vector3.ZERO

func _init(start: Vector3) -> void:
	home = start
	position = start

	mass = MASS
	# Continuous collision detection: a struck ball crosses more than its own
	# diameter in one physics tick, and without this it tunnels straight
	# through a goalpost instead of hitting it.
	continuous_cd = true
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
	mesh.mesh = _build_mesh()
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
func _build_mesh() -> Mesh:
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
		var panel := nearest > 0.905
		tool.set_color(Color(0.13, 0.14, 0.18) if panel else Color(0.96, 0.96, 0.94))
		tool.add_vertex(vertex)
	tool.generate_normals()
	return tool.commit()

## Strike the ball away from the striker, with lift. Returns the power of the
## kick, or zero if the striker was not close enough.
func kick(from: Vector3, facing: Vector3, sprinting: bool) -> float:
	var offset := position - from
	offset.y = 0.0
	if offset.length() > KICK_REACH + RADIUS:
		return 0.0

	# Kick along the line from striker to ball, not along the way the striker
	# happens to be facing. A child aims by walking at the ball, and being sent
	# somewhere else because the camera had swung feels like a bug.
	var direction := offset.normalized() if offset.length_squared() > 0.02 else facing
	var speed := KICK_SPEED + (SPRINT_BONUS if sprinting else 0.0)
	var launch := (direction + Vector3.UP * KICK_LIFT).normalized() * speed

	sleeping = false
	# The velocity is set outright rather than applied as an impulse. An impulse
	# is only integrated when the physics server steps the body, so a ball that
	# has not been stepped yet — on the first frame, or in a headless check —
	# silently absorbs the kick and stays put. Setting velocity is also the
	# truthful model here: a kick replaces the ball's motion, it does not add to
	# whatever it was already doing.
	linear_velocity = launch
	# A little sidespin off the striking foot, so the ball visibly turns over.
	angular_velocity = direction.cross(Vector3.UP) * speed * 0.9

	kicked.emit(speed)
	return speed

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
