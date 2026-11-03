class_name Ducks
extends Node3D

## Ducks on the ponds.
##
## Decoration, and deliberately nothing else: they give no coins, want nothing,
## and cannot be stroked or fed. Every other living thing in this valley is a
## small errand — the squirrel wants a cone, the dog wants a stick — and a place
## where everything that moves is a task to be done is a place to work rather
## than a place to be. A duck paddling about is worth having for its own sake.
##
## They are not animals in the `Animals` sense for the same reason: that node
## is about wanting, cooling down and paying out, and none of it applies here.
## What they need is a pond, a heading, and something to stop them paddling up
## the bank.

## How many are on each pond. Four reads as "some ducks"; one reads as a duck
## that has lost the others.
const PER_POND := 5

## How fast they paddle and how sharply they turn. Slow: a duck that moves like
## a fish reads as a bath toy being pushed about.
const SPEED := 0.55
const TURN := 0.8
## How far out into the pond they keep, as a fraction of its basin. They turn
## back at this, so nobody watches a duck walk up a bank.
const KEEP_WITHIN := 0.78
## How wide a duck is to bump into. Small, but not nothing: swimming straight
## through one reads as the duck not being there, which is what it was.
const GIRTH := 0.22

## How far they bob, and how fast.
const BOB := 0.035
const BOB_SPEED := 1.4
## How far a duck rocks from side to side as it paddles, in radians.
const SWAY := 0.05

## A few ducks on the river as well, upstream of the bridge. The river carries
## them gently downstream; when one has drifted too far from where it started
## it turns and paddles back, harder than it paddles about, because it has the
## current to beat. Stuck at the same walking pace they would never get home.
const ON_THE_RIVER := 3
const RIVER_DUCKS_AT_Z := -34.0
## How far downstream of its home a river duck drifts before it paddles back,
## how far across the river it may stray, and how near home counts as home.
const LEASH := 9.0
const RIVER_ABREAST := 5.0
const HOME_ENOUGH := 2.0

var _ducks: Array[Dictionary] = []
var _field: HeightField
var _material: StandardMaterial3D
var _drake: Mesh
var _hen: Mesh
## A paler drake and a darker hen, so a pond of five is not five copies.
var _drake_pale: Mesh
var _hen_dark: Mesh

func _init() -> void:
	# Animated in _process, so the engine's physics interpolation must not
	# touch it. See LESSONS.md: with interpolation on, a node's transform is
	# sampled once a physics tick and drawn a tick late, which throws away
	# everything moved between ticks — sixty-hertz motion on a hundred-and-
	# twenty-hertz screen, which is the flicker a child described as the world
	# coming in frames.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	name = "Ducks"
	# Built here rather than in _ready: a headless check uses this without ever
	# starting the scene tree. See LESSONS.md.
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.roughness = 0.7
	_drake = _build(true)
	_hen = _build(false)
	_drake_pale = _build(true, 0.1)
	_hen_dark = _build(false, -0.1)

## Put ducks on every pond. Called once, with the seed, so the same world has
## the same ducks in the same places on both children's phones.
func settle(world_seed: int, height_field: HeightField = null) -> void:
	_field = height_field
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(world_seed, 7717, 41))
	for pond in Lakes.count():
		var centre := Vector2(
			Lakes.at(pond, Lakes.POND_X), Lakes.at(pond, Lakes.POND_Z)
		)
		var long_axis := Lakes.at(pond, Lakes.POND_LONG)
		var short_axis := Lakes.at(pond, Lakes.POND_SHORT)
		var angle := Lakes.at(pond, Lakes.POND_ANGLE)
		var level := Lakes.at(pond, Lakes.POND_LEVEL)
		for i in PER_POND:
			# Somewhere out on the open water, in the pond's own frame so that
			# an oval pond gets an oval spread rather than a circular one.
			var bearing := rng.randf() * TAU
			var out := sqrt(rng.randf()) * KEEP_WITHIN
			var local := Vector2(
				cos(bearing) * out * long_axis, sin(bearing) * out * short_axis
			).rotated(angle)
			var node := MeshInstance3D.new()
			node.mesh = _mesh_for(i)
			node.position = Vector3(centre.x + local.x, level, centre.y + local.y)
			node.rotation.y = rng.randf() * TAU
			# Solid, like everything else that is really there. A duck you swim
			# straight through is a picture of a duck.
			var body := StaticBody3D.new()
			body.collision_layer = TerrainSpec.LAYER_PROPS
			body.set_meta(TerrainSpec.ANIMALS_IGNORE, true)
			var shape := CapsuleShape3D.new()
			shape.radius = GIRTH
			shape.height = GIRTH * 2.6
			var collider := CollisionShape3D.new()
			collider.shape = shape
			collider.position = Vector3(0.0, GIRTH * 0.6, 0.0)
			body.add_child(collider)
			node.add_child(body)
			add_child(node)
			_ducks.append({
				"node": node,
				"pond": pond,
				"heading": node.rotation.y,
				"phase": rng.randf() * TAU,
			})
	if _field != null:
		for i in ON_THE_RIVER:
			var z := RIVER_DUCKS_AT_Z - float(i) * 6.0
			var home := Vector2(
				_field.river_centre_x(z) + (rng.randf() - 0.5) * 2.0 * RIVER_ABREAST * 0.5, z
			)
			var node := MeshInstance3D.new()
			node.mesh = _mesh_for(i)
			node.position = Vector3(home.x, _field.water_level_at(home.x, z), home.y)
			node.rotation.y = rng.randf() * TAU
			var body := StaticBody3D.new()
			body.collision_layer = TerrainSpec.LAYER_PROPS
			body.set_meta(TerrainSpec.ANIMALS_IGNORE, true)
			var shape := CapsuleShape3D.new()
			shape.radius = GIRTH
			shape.height = GIRTH * 2.6
			var collider := CollisionShape3D.new()
			collider.shape = shape
			collider.position = Vector3(0.0, GIRTH * 0.6, 0.0)
			body.add_child(collider)
			node.add_child(body)
			add_child(node)
			_ducks.append({
				"node": node,
				"pond": -1,
				"home": home,
				"returning": false,
				"heading": node.rotation.y,
				"phase": rng.randf() * TAU,
			})

## Which mesh the i-th duck wears: drakes and hens alternate, and every second
## of each is cast a little differently.
func _mesh_for(i: int) -> Mesh:
	var second := (i / 2) % 2 == 1
	if i % 2 == 0:
		return _drake_pale if second else _drake
	return _hen_dark if second else _hen

func _process(delta: float) -> void:
	var stamp := PerfLog.stamp()
	for duck in _ducks:
		_paddle(duck, delta)
	PerfLog.note("ducks", stamp)

## One duck: forward along its heading, turning away from the bank when it gets
## near one, bobbing as it goes.
func _paddle(duck: Dictionary, delta: float) -> void:
	var node: Node3D = duck["node"]
	if not is_instance_valid(node):
		return
	var pond: int = duck["pond"]
	if pond < 0:
		_paddle_on_the_river(duck, delta)
		return
	var centre := Vector2(
		Lakes.at(pond, Lakes.POND_X), Lakes.at(pond, Lakes.POND_Z)
	)
	var heading: float = duck["heading"]
	var here := Vector2(node.position.x, node.position.z)

	# How far out it is, in the pond's own frame: 1.0 is the water's edge.
	var reach := _reach_of(here - centre, pond)
	# The bob and the sway run on this clock, so it ticks whether or not the
	# duck is turning back: it used to stop at the bank, and the duck froze
	# mid-bob until it was clear again.
	duck["phase"] = float(duck["phase"]) + delta * 0.6
	if reach > KEEP_WITHIN:
		# Turn towards the middle rather than snapping round: a duck that
		# reverses on the spot reads as a duck hitting a wall.
		var inward := (centre - here).angle()
		# Headings here are the node's own rotation about Y, where zero faces
		# -Z; the bearing above is measured in the XZ plane from +X. The
		# quarter turn between them is the difference, and leaving it out sent
		# every duck round the shore rather than into the middle.
		var wanted := -inward - PI * 0.5
		heading = lerp_angle(heading, wanted, 1.0 - exp(-TURN * 2.5 * delta))
	else:
		# A slow wander, each duck on its own clock.
		heading += sin(float(duck["phase"])) * TURN * delta

	duck["heading"] = heading
	node.rotation.y = heading
	node.rotation.z = sin(float(duck["phase"]) * BOB_SPEED * 1.3) * SWAY
	var forward := Vector3(-sin(heading), 0.0, -cos(heading))
	node.position += forward * SPEED * delta
	node.position.y = (
		Lakes.at(pond, Lakes.POND_LEVEL)
		+ sin(float(duck["phase"]) * BOB_SPEED + node.position.x) * BOB
	)

## A duck on the river: carried with the water, wandering about while it is near
## home, and paddling back upstream once it has gone too far downstream or too
## far across. The water carries it by the same current that carries a swimmer.
func _paddle_on_the_river(duck: Dictionary, delta: float) -> void:
	var node: Node3D = duck["node"]
	var home: Vector2 = duck["home"]
	var heading: float = duck["heading"]
	var here := Vector2(node.position.x, node.position.z)
	var current := _field.river_current_at(here.x, here.y)
	var downstream := Vector2(_field.river_slope(here.y), 1.0).normalized()
	var away := here - home
	var returning: bool = duck["returning"]
	if away.dot(downstream) > LEASH or absf(here.x - _field.river_centre_x(here.y)) > RIVER_ABREAST:
		returning = true
	elif away.length() < HOME_ENOUGH:
		returning = false
	duck["returning"] = returning

	duck["phase"] = float(duck["phase"]) + delta * 0.6
	var effort := SPEED
	if returning:
		# Headings are the node's rotation about Y, where zero faces -Z.
		var wanted := atan2(away.x, away.y)
		heading = lerp_angle(heading, wanted, 1.0 - exp(-TURN * 2.5 * delta))
		effort += current.length() * 1.5
	else:
		heading += sin(float(duck["phase"])) * TURN * delta
	duck["heading"] = heading
	node.rotation.y = heading
	node.rotation.z = sin(float(duck["phase"]) * BOB_SPEED * 1.3) * SWAY
	var forward := Vector3(-sin(heading), 0.0, -cos(heading))
	node.position += (forward * effort + Vector3(current.x, 0.0, current.y)) * delta
	node.position.y = (
		_field.water_level_at(node.position.x, node.position.z)
		+ sin(float(duck["phase"]) * BOB_SPEED + node.position.x) * BOB
	)

## How far out a point is in a pond's frame, where 1.0 is the water's edge.
func _reach_of(offset: Vector2, pond: int) -> float:
	var turned := offset.rotated(-Lakes.at(pond, Lakes.POND_ANGLE))
	var along := turned.x / Lakes.at(pond, Lakes.POND_LONG)
	var across := turned.y / Lakes.at(pond, Lakes.POND_SHORT)
	return sqrt(along * along + across * across)

## A duck: a body sitting low in the water, a raised tail, a neck and a head
## with a bill. The drake has the green head and the white collar; the hen is
## brown all over, which is what tells the two apart at any distance.
func _build(drake: bool, cast := 0.0) -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# `cast` lightens (positive) or darkens (negative) the plumage.
	var brown := Color(0.52, 0.40, 0.28)
	brown = brown.lightened(cast) if cast >= 0.0 else brown.darkened(-cast)
	var body_colour := Color(0.62, 0.56, 0.48).lightened(maxf(cast, 0.0)) if drake else brown
	var head_colour := Color(0.16, 0.44, 0.24) if drake else brown.darkened(0.12)
	var bill := Color(0.92, 0.78, 0.30)

	# The body: one smooth skin sitting half in the water, so what shows is the
	# back and not a floating egg, from the tail that is cocked up behind it
	# round the full breast to the foot of the neck. See AnimalLoft.
	var body := AnimalLoft.make([
		AnimalLoft.key(Vector3(0.0, 0.14, 0.30), 0.025, 0.012, 0.012),
		AnimalLoft.key(Vector3(0.0, 0.10, 0.24), 0.06, 0.035, 0.035),
		AnimalLoft.key(Vector3(0.0, 0.06, 0.14), 0.125, 0.09, 0.08),
		AnimalLoft.key(Vector3(0.0, 0.04, 0.0), 0.15, 0.11, 0.10),
		AnimalLoft.key(Vector3(0.0, 0.07, -0.13), 0.125, 0.11, 0.09),
		AnimalLoft.key(Vector3(0.0, 0.14, -0.19), 0.07, 0.085, 0.075),
	], Vector3.UP, 8, 2, 0.03, 0.02)
	var dusk := body_colour.darkened(0.25)
	var speculum := Color(0.20, 0.32, 0.62)
	body.paint = func(_p: Vector3, along: float, angle: float) -> Color:
		# Darker on the back and paler under the breast, and darker again on
		# the raised tail.
		var c := body_colour.darkened(0.12 * maxf(cos(angle), 0.0)).lightened(0.15 * maxf(-cos(angle), 0.0))
		c = c.lerp(dusk, smoothstep(0.3, 0.12, along))
		# The folded wing lies along the side: a little darker than the flank,
		# with the blue patch every mallard shows at its hind edge, and a white
		# bar either side of it. Without it the back is one bare, plain skin.
		var side := smoothstep(0.35, 0.8, absf(sin(angle))) * smoothstep(-0.5, 0.0, cos(angle))
		var wing := side * smoothstep(0.2, 0.3, along) * smoothstep(0.78, 0.66, along)
		c = c.darkened(0.14 * wing)
		# (The skin has a ring every sixteenth of its length, so a band is as
		# wide as that or it falls between two and is not drawn.)
		var from_patch := absf(along - 0.375)
		c = c.lerp(Color(0.94, 0.94, 0.92), side * smoothstep(0.02, 0.06, from_patch) * smoothstep(0.11, 0.07, from_patch) * 0.45)
		return c.lerp(speculum, side * smoothstep(0.06, 0.02, from_patch))
	body.emit(tool)
	# The neck and head, forward and up, in one skin with a collar painted on
	# the drake's neck.
	var neck := AnimalLoft.make([
		AnimalLoft.key(Vector3(0.0, 0.13, -0.19), 0.06, 0.06, 0.06),
		AnimalLoft.key(Vector3(0.0, 0.19, -0.2), 0.045, 0.045, 0.045),
		AnimalLoft.key(Vector3(0.0, 0.25, -0.21), 0.05, 0.05, 0.05),
		AnimalLoft.key(Vector3(0.0, 0.272, -0.24), 0.062, 0.06, 0.055),
		AnimalLoft.key(Vector3(0.0, 0.265, -0.28), 0.036, 0.034, 0.03),
	], Vector3.UP, 8, 2, 0.0, 0.015)
	var collar := Color(0.94, 0.93, 0.90)
	neck.paint = func(p: Vector3, _along: float, _angle: float) -> Color:
		if drake:
			return head_colour.lerp(collar, smoothstep(0.045, 0.02, absf(p.y - 0.165)))
		return head_colour
	neck.emit(tool)
	# The bill, flat and broad, with a rounded tip.
	var beak := AnimalLoft.make([
		AnimalLoft.key(Vector3(0.0, 0.262, -0.27), 0.03, 0.013, 0.012),
		AnimalLoft.key(Vector3(0.0, 0.256, -0.31), 0.034, 0.011, 0.01),
		AnimalLoft.key(Vector3(0.0, 0.25, -0.34), 0.026, 0.008, 0.007),
	], Vector3.UP, 6, 1, 0.0, 0.012)
	beak.paint = func(_p: Vector3, _along: float, _angle: float) -> Color: return bill
	beak.emit(tool)
	for side in PackedFloat32Array([-1.0, 1.0]):
		AnimalLoft.ball(tool, Vector3(side * 0.05, 0.285, -0.25), Vector3(0.016, 0.016, 0.014), Color(0.05, 0.05, 0.05), 5)

	tool.generate_normals()
	tool.set_material(_material)
	return tool.commit()

## How many ducks are afloat. For the checks.
func count() -> int:
	return _ducks.size()

## Where one is, and which pond it belongs to. For the checks.
func duck_position(index: int) -> Vector3:
	return (_ducks[index]["node"] as Node3D).position

func duck_pond(index: int) -> int:
	return _ducks[index]["pond"]

## Whether a duck is something a child bumps into. For the checks.
func is_solid(index: int) -> bool:
	var node: Node3D = _ducks[index]["node"]
	for child in node.get_children():
		var body := child as StaticBody3D
		if body != null and body.collision_layer == TerrainSpec.LAYER_PROPS:
			return body.get_child_count() > 0
	return false
