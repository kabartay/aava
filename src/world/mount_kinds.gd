class_name MountKinds
extends RefCounted

## The two things a child can ride, and how they differ.
##
## One file rather than two because a horse and a bicycle are the same problem:
## something that carries the player faster, turns more slowly, and changes what
## the camera should be doing. Writing that twice would mean fixing every bug in
## it twice.
##
## Where they differ is the interesting part. The horse can cross the river and
## climb; the bicycle is faster on the flat and refuses a steep slope. That is
## the whole reason to own both.

const HORSE := &"horse"
const BICYCLE := &"bicycle"
## A boat: the one mount that goes where the others cannot at all — across
## the pond — and nowhere else. Five of them wait at the big pond's shore.
const BOAT := &"boat"

const ALL: Array[StringName] = [HORSE, BICYCLE, BOAT]

## There is one horse and one bicycle, but several boats, so a mount is named
## by an id — "horse", or "boat:2" — and everything that wants to know what
## the thing *is* asks `kind_of`. Ids without a colon are their own kind.
static func kind_of(id: StringName) -> StringName:
	var text := String(id)
	var colon := text.find(":")
	return id if colon < 0 else StringName(text.substr(0, colon))

## The id of the n-th boat.
static func boat_id(index: int) -> StringName:
	return StringName("%s:%d" % [BOAT, index])

## Which boat an id is, or -1 for anything that is not one.
static func boat_index(id: StringName) -> int:
	var text := String(id)
	if not text.begins_with(String(BOAT) + ":"):
		return -1
	return text.substr(text.find(":") + 1).to_int()

## One hull colour per boat, so a child can say "the red one".
const BOAT_COLOURS: Array[Color] = [
	Color(0.84, 0.26, 0.22), Color(0.22, 0.44, 0.80), Color(0.30, 0.62, 0.32),
	Color(0.95, 0.78, 0.22), Color(0.92, 0.92, 0.88),
]
## How deep the hull sits, and how high above the water a child sits in it.
const BOAT_DRAFT := 0.3
const BOAT_SEAT := 0.25

## The box a standing mount takes up, as (size, centre height): what a child
## bumps into instead of walking through it. Only while it stands — a mount
## being ridden is carried under the child and must not push them.
static func body_box(kind: StringName) -> Array:
	match kind_of(kind):
		HORSE:
			return [Vector3(0.9, 2.1, 2.9), 1.15]
		BOAT:
			return [Vector3(1.4, 0.55, 3.5), 0.05]
		_:
			return [Vector3(0.5, 1.0, 1.9), 0.55]

const INFO := {
	HORSE: {
		# Fast, but the real reason to ride one is that it fords the river and
		# takes hills a bicycle cannot.
		"speed": 9.4,
		"turn": 2.6,
		"max_slope": 0.62,
		"fords": true,
		"floats": false,
		# Up to the saddle: the child's feet at the stirrups, body above the
		# horse's back. At 1.26 the rider was inside the horse to the neck.
		"eye": 2.1,
		"colour": Color(0.42, 0.29, 0.20),
	},
	BICYCLE: {
		# Faster than the horse on level ground and useless off it, which is
		# what a bicycle is.
		"speed": 11.2,
		"turn": 2.0,
		"max_slope": 0.28,
		"fords": false,
		"floats": false,
		"eye": 0.45,
		"colour": Color(0.90, 0.28, 0.24),
	},
	BOAT: {
		# Slower than a horse and much faster than swimming, which is the
		# whole comparison a boat is in. Turns like a boat: slowly.
		"speed": 6.0,
		"turn": 1.4,
		"max_slope": 9.0,
		"fords": true,
		"floats": true,
		"eye": 0.15,
		"colour": Color(0.84, 0.26, 0.22),
	},
}

static func speed(kind: StringName) -> float:
	return float(INFO[kind_of(kind)]["speed"])

static func turn_rate(kind: StringName) -> float:
	return float(INFO[kind_of(kind)]["turn"])

static func max_slope(kind: StringName) -> float:
	return float(INFO[kind_of(kind)]["max_slope"])

static func fords_water(kind: StringName) -> bool:
	return bool(INFO[kind_of(kind)]["fords"])

## Whether this mount rides on the water rather than the ground: a boat.
static func floats(kind: StringName) -> bool:
	return bool(INFO[kind_of(kind)]["floats"])

## How much higher the player sits than when standing.
static func eye_lift(kind: StringName) -> float:
	return float(INFO[kind_of(kind)]["eye"])

static func colour(kind: StringName) -> Color:
	var index := boat_index(kind)
	if index >= 0:
		return BOAT_COLOURS[index % BOAT_COLOURS.size()]
	return INFO[kind_of(kind)]["colour"]

static func label(kind: StringName) -> String:
	return Text.of("mount_%s" % kind_of(kind))

## A horse: a barrel body on four legs with a neck and a head, built from the
## same primitives as the animals so it belongs to the same world.
static func build_mesh(kind: StringName) -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind_of(kind):
		HORSE:
			_horse(tool)
		BOAT:
			_boat(tool, colour(kind))
		_:
			_bicycle(tool)
	tool.generate_normals()
	tool.set_material(AnimalKinds.fur_material())
	return tool.commit()

## Where the horse's head and tail pivot, in the body's frame: the head and
## neck turn about the shoulder, the tail about the root of the dock.
const HORSE_HEAD_PIVOT := Vector3(0.0, 1.872, -0.744)
const HORSE_TAIL_PIVOT := Vector3(0.0, 1.56, 1.224)

## Where the rump is and how big, so the tail's root can be checked against
## the body it grows out of rather than against a number written twice.
const HORSE_RUMP_CENTRE := Vector3(0.0, 1.632, 0.864)
const HORSE_RUMP_RADIUS := 0.528

## The tail, as a chain of segments read end to end: how far each is tipped
## back from straight up, how long it is, and how thick at its start.
##
## It was two cylinders placed at two chosen points, and the points did not
## meet: there was a third of a metre of air between the dock and the switch,
## and the end of the horse's tail hung behind it unattached. A chain cannot
## do that — each piece starts where the last one ended.
const HORSE_TAIL_CHAIN: Array[float] = [
	# tilt from vertical (degrees), length, radius at the start
	#
	# A horse's tail leaves the rump about level and is falling within a hand's
	# width: it is heavy hair hanging, not a raised plume. The first chain went
	# up at 62 degrees before coming down, which gave it a cocked, doglike
	# curl — the thing that looked wrong from the saddle.
	78.0, 0.22, 0.16,
	104.0, 0.24, 0.15,
	132.0, 0.28, 0.13,
	154.0, 0.30, 0.11,
	168.0, 0.30, 0.09,
]
const HORSE_TAIL_STRIDE := 3

## A horse, a fifth bigger than the first one and with what makes a horse a
## horse: a fuller chest and rump, a blaze on the face, eyes, pointed ears, a
## mane in locks down the neck, a tail in two pieces, socks and hooves — and
## a saddle on a red blanket, with stirrups, because a horse a child rides
## should look like one that is ridden. Built in parts — body, head, tail,
## legs — so the head can nod and the tail swing as it moves; `build_mesh`
## bakes them into one for a still picture.
static func _horse(tool: SurfaceTool) -> void:
	# Baked into one mesh, every part keeps its own place on the horse, so
	# nothing is measured from a pivot: pivot zero. The legs are here too —
	# they were left out when they became nodes, and the one-piece horse
	# stood on nothing, which is what the screenshot tool drew.
	_horse_body(tool)
	_horse_head(tool, Vector3.ZERO)
	_horse_tail(tool, Vector3.ZERO)
	for hip in HORSE_HIPS:
		_horse_leg(tool, hip, Vector3.ZERO)

## The barrel, chest, shoulder and rump, the saddle and its reins.
static func _horse_body(tool: SurfaceTool) -> void:
	var s := 1.2
	var hide: Color = colour(HORSE)
	var leather := Color(0.36, 0.22, 0.12)
	var blanket := Color(0.80, 0.22, 0.20)
	var hoof := Color(0.15, 0.12, 0.10)

	# The barrel: deeper than it is wide, as a horse is — a body as wide as it
	# is deep reads as a barrel on legs, which is what it was.
	var body := SphereMesh.new()
	body.radius = 0.52 * s
	body.height = 1.0 * s
	body.radial_segments = 14
	body.rings = 8
	_add(tool, body, Transform3D(
		Basis().scaled(Vector3(0.86, 1.0, 1.75)), Vector3(0.0, 1.32 * s, 0.0)
	), hide)
	# The belly, hanging a little below the barrel's own line.
	var belly := SphereMesh.new()
	belly.radius = 0.4 * s
	belly.height = 0.7 * s
	belly.radial_segments = 10
	belly.rings = 6
	_add(tool, belly, Transform3D(
		Basis().scaled(Vector3(0.9, 0.8, 1.5)), Vector3(0.0, 1.06 * s, 0.06 * s)
	), hide.darkened(0.06))
	var chest := SphereMesh.new()
	chest.radius = 0.42 * s
	chest.height = 0.84 * s
	chest.radial_segments = 12
	chest.rings = 7
	_add(tool, chest, Transform3D(Basis().scaled(Vector3(1.0, 1.05, 1.0)), Vector3(0.0, 1.26 * s, -0.74 * s)), hide)
	var shoulder := SphereMesh.new()
	shoulder.radius = 0.34 * s
	shoulder.height = 0.68 * s
	shoulder.radial_segments = 10
	shoulder.rings = 6
	_add(tool, shoulder, Transform3D(Basis(), Vector3(0.0, 1.56 * s, -0.62 * s)), hide)
	# The withers: the rise where the neck meets the back, and the one line
	# that separates a horse's outline from a pony's or a donkey's.
	var withers := SphereMesh.new()
	withers.radius = 0.24 * s
	withers.height = 0.4 * s
	withers.radial_segments = 8
	withers.rings = 5
	_add(tool, withers, Transform3D(
		Basis().scaled(Vector3(0.8, 1.0, 1.6)), Vector3(0.0, 1.7 * s, -0.44 * s)
	), hide)
	var rump := SphereMesh.new()
	rump.radius = 0.44 * s
	rump.height = 0.88 * s
	rump.radial_segments = 12
	rump.rings = 7
	_add(tool, rump, Transform3D(Basis(), Vector3(0.0, 1.36 * s, 0.72 * s)), hide)

	var pad := BoxMesh.new()
	pad.size = Vector3(0.74 * s, 0.05 * s, 0.82 * s)
	_add(tool, pad, Transform3D(Basis(), Vector3(0.0, 1.78 * s, 0.04 * s)), blanket)
	var seat := BoxMesh.new()
	seat.size = Vector3(0.44 * s, 0.14 * s, 0.54 * s)
	_add(tool, seat, Transform3D(Basis(), Vector3(0.0, 1.87 * s, 0.04 * s)), leather)
	var pommel := SphereMesh.new()
	pommel.radius = 0.07 * s
	pommel.height = 0.14 * s
	pommel.radial_segments = 6
	pommel.rings = 3
	_add(tool, pommel, Transform3D(Basis(), Vector3(0.0, 1.98 * s, -0.2 * s)), leather)
	var cantle := BoxMesh.new()
	cantle.size = Vector3(0.4 * s, 0.12 * s, 0.08 * s)
	_add(tool, cantle, Transform3D(Basis(), Vector3(0.0, 1.97 * s, 0.29 * s)), leather)
	for side in PackedFloat32Array([-1.0, 1.0]):
		var strap := BoxMesh.new()
		strap.size = Vector3(0.05 * s, 0.34 * s, 0.05 * s)
		_add(tool, strap, Transform3D(Basis(), Vector3(side * 0.44 * s, 1.6 * s, 0.04 * s)), leather)
		var stirrup := BoxMesh.new()
		stirrup.size = Vector3(0.1 * s, 0.09 * s, 0.05 * s)
		_add(tool, stirrup, Transform3D(Basis(), Vector3(side * 0.44 * s, 1.4 * s, 0.04 * s)), hoof)
		# A rein from the bit back to the pommel: a thin cylinder laid along
		# the line between them.
		var bit := Vector3(side * 0.16 * s, 2.0 * s, -1.36 * s)
		var pommel_at := Vector3(side * 0.06 * s, 2.0 * s, -0.2 * s)
		var run := pommel_at - bit
		var rein := CylinderMesh.new()
		rein.top_radius = 0.012 * s
		rein.bottom_radius = 0.012 * s
		rein.height = run.length()
		rein.radial_segments = 4
		rein.rings = 1
		_add(tool, rein, Transform3D(
			Basis.looking_at(run.normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5),
			bit + run * 0.5 + Vector3(0.0, -0.06 * s, 0.0)
		), leather)

## The neck and head, with the mane, the bridle and the face, relative to
## the shoulder they pivot about.
static func _horse_head(tool: SurfaceTool, pivot: Vector3) -> void:
	var s := 1.2
	var hide: Color = colour(HORSE)
	var dark := hide.darkened(0.3)
	var pale := Color(0.93, 0.90, 0.84)
	var hoof := Color(0.15, 0.12, 0.10)
	var leather := Color(0.36, 0.22, 0.12)
	var neck_tilt := Basis(Vector3.RIGHT, deg_to_rad(-38.0))

	var neck := CylinderMesh.new()
	neck.top_radius = 0.19 * s
	neck.bottom_radius = 0.30 * s
	neck.height = 0.9 * s
	neck.radial_segments = 8
	_add(tool, neck, Transform3D(neck_tilt, Vector3(0.0, 1.8 * s, -0.74 * s) - pivot), hide)
	var head := SphereMesh.new()
	head.radius = 0.21 * s
	head.height = 0.5 * s
	head.radial_segments = 8
	head.rings = 5
	_add(tool, head, Transform3D(
		Basis().scaled(Vector3(1.0, 1.0, 1.55)), Vector3(0.0, 2.1 * s, -1.12 * s) - pivot
	), hide)
	var muzzle := SphereMesh.new()
	muzzle.radius = 0.14 * s
	muzzle.height = 0.26 * s
	muzzle.radial_segments = 8
	muzzle.rings = 4
	_add(tool, muzzle, Transform3D(Basis(), Vector3(0.0, 2.02 * s, -1.42 * s) - pivot), hide.lightened(0.12))
	var blaze := BoxMesh.new()
	blaze.size = Vector3(0.07 * s, 0.3 * s, 0.02 * s)
	_add(tool, blaze, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-20.0)), Vector3(0.0, 2.15 * s, -1.33 * s) - pivot), pale)
	var noseband := TorusMesh.new()
	noseband.inner_radius = 0.13 * s
	noseband.outer_radius = 0.16 * s
	noseband.rings = 6
	noseband.ring_segments = 10
	_add(tool, noseband, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, 2.03 * s, -1.34 * s) - pivot), leather)
	var brow := TorusMesh.new()
	brow.inner_radius = 0.2 * s
	brow.outer_radius = 0.23 * s
	brow.rings = 6
	brow.ring_segments = 10
	_add(tool, brow, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, 2.14 * s, -1.02 * s) - pivot), leather)
	for side in PackedFloat32Array([-1.0, 1.0]):
		var eye := SphereMesh.new()
		eye.radius = 0.04 * s
		eye.height = 0.08 * s
		eye.radial_segments = 6
		eye.rings = 3
		_add(tool, eye, Transform3D(Basis(), Vector3(side * 0.16 * s, 2.17 * s, -1.2 * s) - pivot), hoof)
		var nostril := SphereMesh.new()
		nostril.radius = 0.022 * s
		nostril.height = 0.044 * s
		nostril.radial_segments = 5
		nostril.rings = 3
		_add(tool, nostril, Transform3D(Basis(), Vector3(side * 0.06 * s, 2.0 * s, -1.55 * s) - pivot), dark)
		var ear := CylinderMesh.new()
		ear.top_radius = 0.0
		ear.bottom_radius = 0.06 * s
		ear.height = 0.22 * s
		ear.radial_segments = 5
		ear.rings = 1
		_add(tool, ear, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(14.0)), Vector3(side * 0.09 * s, 2.36 * s, -1.02 * s) - pivot), dark)
		var cheek := BoxMesh.new()
		cheek.size = Vector3(0.02 * s, 0.03 * s, 0.34 * s)
		_add(tool, cheek, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-12.0)), Vector3(side * 0.2 * s, 2.1 * s, -1.18 * s) - pivot), leather)
	# The mane: seven locks of unequal length down the crest, which is what
	# makes it hair rather than a fin.
	var mane := RandomNumberGenerator.new()
	mane.seed = 5150
	for i in 7:
		var t := 0.06 + float(i) * 0.145
		var along := Vector3(0.0, 1.5 * s, -0.42 * s).lerp(Vector3(0.0, 2.3 * s, -1.02 * s), t)
		var lock := BoxMesh.new()
		lock.size = Vector3(
			0.085 * s,
			(0.30 + mane.randf_range(-0.06, 0.12)) * s,
			(0.20 + mane.randf_range(-0.03, 0.06)) * s
		)
		_add(tool, lock, Transform3D(
			neck_tilt * Basis(Vector3.UP, mane.randf_range(-0.12, 0.12)),
			along + neck_tilt * Vector3(0.0, 0.0, 0.15 * s) - pivot
		), dark)
	var forelock := BoxMesh.new()
	forelock.size = Vector3(0.12 * s, 0.1 * s, 0.24 * s)
	_add(tool, forelock, Transform3D(Basis(), Vector3(0.0, 2.34 * s, -1.18 * s) - pivot), dark)

## The tail in two pieces, relative to where it joins the rump.
static func _horse_tail(tool: SurfaceTool, pivot: Vector3) -> void:
	var s := 1.2
	var dark: Color = colour(HORSE).darkened(0.3)
	var joints := horse_tail_joints()
	var i := 0
	var piece := 0
	while i < HORSE_TAIL_CHAIN.size():
		var length := HORSE_TAIL_CHAIN[i + 1] * s
		var thick := HORSE_TAIL_CHAIN[i + 2] * s
		var thin := (HORSE_TAIL_CHAIN[i + HORSE_TAIL_STRIDE + 2] * s
			if i + HORSE_TAIL_STRIDE < HORSE_TAIL_CHAIN.size() else thick * 0.7)
		var from := joints[piece] + HORSE_TAIL_PIVOT - pivot
		var to := joints[piece + 1] + HORSE_TAIL_PIVOT - pivot
		var run := to - from
		var hair := CylinderMesh.new()
		hair.top_radius = thin
		hair.bottom_radius = thick
		hair.height = length
		hair.radial_segments = 7
		hair.rings = 1
		# A cylinder stands along its own Y; laid along this piece of the tail.
		_add(tool, hair, Transform3D(
			Basis.looking_at(run.normalized(), Vector3.RIGHT) * Basis(Vector3.RIGHT, PI * 0.5),
			from + run * 0.5
		), dark)
		# A ball at the joint, so no seam opens where two pieces meet.
		var joint := SphereMesh.new()
		joint.radius = thin * 1.1
		joint.height = thin * 2.2
		joint.radial_segments = 6
		joint.rings = 3
		_add(tool, joint, Transform3D(Basis(), to), dark)
		i += HORSE_TAIL_STRIDE
		piece += 1
	# The switch: the long hair at the end, in four strands that hang and
	# spread a little rather than one blob on the end of a stick.
	var tip := joints[joints.size() - 1] + HORSE_TAIL_PIVOT - pivot
	var spread := RandomNumberGenerator.new()
	spread.seed = 8181
	for strand in 4:
		var hair := CylinderMesh.new()
		hair.top_radius = 0.02 * s
		hair.bottom_radius = 0.05 * s
		hair.height = (0.34 + spread.randf_range(-0.06, 0.1)) * s
		hair.radial_segments = 5
		hair.rings = 1
		# Hanging, fanned a little across the horse and a little behind it.
		var lean := Basis(Vector3.RIGHT, deg_to_rad(spread.randf_range(4.0, 16.0)))
		lean = lean * Basis(Vector3.FORWARD, deg_to_rad(spread.randf_range(-10.0, 10.0)))
		_add(tool, hair, Transform3D(
			lean,
			tip + Vector3(
				(float(strand) - 1.5) * 0.035 * s,
				-hair.height * 0.42,
				spread.randf_range(-0.02, 0.03) * s
			)
		), dark)

## Every joint of the tail, from its root outwards, in the tail's own frame —
## the root is the origin. Read by the drawing above and by the checks, so the
## shape cannot be asserted against numbers that only the check believes.
static func horse_tail_joints() -> PackedVector3Array:
	var s := 1.2
	var out := PackedVector3Array([Vector3.ZERO])
	var at := Vector3.ZERO
	var i := 0
	while i < HORSE_TAIL_CHAIN.size():
		var tilt := deg_to_rad(HORSE_TAIL_CHAIN[i])
		var length := HORSE_TAIL_CHAIN[i + 1] * s
		# Rotating +Y about X by a positive angle tips it towards +Z, which is
		# behind the horse: 90 degrees is a tail held straight out.
		at += Vector3(0.0, cos(tilt), sin(tilt)) * length
		out.append(at)
		i += HORSE_TAIL_STRIDE
	return out

## One part of the horse as a mesh of its own, for the parts that move.
##
## A moving part is drawn relative to the joint it turns about, because its
## node sits at that joint: the two together put it back where it belongs.
## Built with pivot zero at first, which meant the offset was applied twice —
## the node moved it up to the shoulder and the mesh was already there — and
## the head and tail hung half a metre off the horse.
static func horse_part(part: String) -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	match part:
		"head":
			_horse_head(tool, HORSE_HEAD_PIVOT)
		"tail":
			_horse_tail(tool, HORSE_TAIL_PIVOT)
		_:
			_horse_body(tool)
	tool.generate_normals()
	tool.set_material(AnimalKinds.fur_material())
	return tool.commit()

## Where the horse's four legs hang from, in the body's frame: the hips and
## shoulders, at the height the leg mesh pivots from. Order: front-left,
## front-right, hind-left, hind-right.
const HORSE_HIPS: Array[Vector3] = [
	Vector3(-0.36, 1.56, -0.744), Vector3(0.36, 1.56, -0.744),
	Vector3(-0.36, 1.56, 0.744), Vector3(0.36, 1.56, 0.744),
]

## One horse leg, built with its pivot at the hip so that turning the node
## about X swings the leg forward and back. The legs used to be part of the
## baked horse and stood stiff at a gallop, which from the saddle read as a
## horse on wheels.
static func horse_leg() -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Relative to its own hip, every leg is the same leg, so which hip is
	# passed here does not matter as long as it is the pivot too.
	_horse_leg(tool, HORSE_HIPS[0], HORSE_HIPS[0])
	tool.generate_normals()
	tool.set_material(AnimalKinds.fur_material())
	return tool.commit()

## A leg hanging from `hip`, drawn in coordinates relative to `pivot`.
##
## Two segments rather than one post: a heavy upper leg, a knee, a slender
## cannon bone, a pastern and a hoof. A horse's leg is thick at the top and
## thin at the bottom by a factor of two, and that taper — with a joint
## showing where it changes — is most of what tells a leg from a table leg.
static func _horse_leg(tool: SurfaceTool, hip: Vector3, pivot: Vector3) -> void:
	var s := 1.2
	var hide: Color = colour(HORSE)
	var dark := hide.darkened(0.3)
	var pale := Color(0.93, 0.90, 0.84)
	var hoof := Color(0.15, 0.12, 0.10)
	var top := hip - pivot

	# The upper leg: heavy, and the same hide as the body, since a horse's
	# forearm and gaskin are muscle rather than the dark of its legs.
	var upper := CylinderMesh.new()
	upper.top_radius = 0.15 * s
	upper.bottom_radius = 0.09 * s
	upper.height = 0.66 * s
	upper.radial_segments = 7
	_add(tool, upper, Transform3D(Basis(), top + Vector3(0.0, -0.33 * s, 0.0)), hide.darkened(0.12))

	# The knee, a knuckle where the taper changes.
	var knee := SphereMesh.new()
	knee.radius = 0.095 * s
	knee.height = 0.17 * s
	knee.radial_segments = 6
	knee.rings = 3
	_add(tool, knee, Transform3D(Basis(), top + Vector3(0.0, -0.68 * s, 0.0)), dark)

	# The cannon bone: slender, and darker, which is how most horses' legs go.
	var cannon := CylinderMesh.new()
	cannon.top_radius = 0.07 * s
	cannon.bottom_radius = 0.055 * s
	cannon.height = 0.44 * s
	cannon.radial_segments = 6
	_add(tool, cannon, Transform3D(Basis(), top + Vector3(0.0, -0.92 * s, 0.0)), dark)

	# A white sock over the fetlock, the pastern sloping forward into it, and
	# the hoof.
	var sock := CylinderMesh.new()
	sock.top_radius = 0.075 * s
	sock.bottom_radius = 0.075 * s
	sock.height = 0.16 * s
	sock.radial_segments = 6
	_add(tool, sock, Transform3D(Basis(), top + Vector3(0.0, -1.13 * s, 0.0)), pale)
	var pastern := CylinderMesh.new()
	pastern.top_radius = 0.07 * s
	pastern.bottom_radius = 0.085 * s
	pastern.height = 0.12 * s
	pastern.radial_segments = 6
	_add(tool, pastern, Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(-14.0)), top + Vector3(0.0, -1.24 * s, -0.02 * s)
	), pale)
	var foot := CylinderMesh.new()
	foot.top_radius = 0.09 * s
	foot.bottom_radius = 0.105 * s
	foot.height = 0.1 * s
	foot.radial_segments = 7
	_add(tool, foot, Transform3D(Basis(), top + Vector3(0.0, -1.33 * s, -0.03 * s)), hoof)

## A mount as a node: a body, and for the horse four legs hung from the hips
## that Mounts swings as it moves. The mesh alone is not enough for something
## that has to move its legs.
static func build_node(kind: StringName) -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = build_mesh(kind)
	root.add_child(body)
	if kind_of(kind) == HORSE:
		# The body alone here; the head and tail are their own nodes, so that
		# one can nod and the other swing.
		body.mesh = horse_part("body")
		var head := MeshInstance3D.new()
		head.name = "Head"
		head.mesh = horse_part("head")
		head.position = HORSE_HEAD_PIVOT
		body.add_child(head)
		var tail := MeshInstance3D.new()
		tail.name = "Tail"
		tail.mesh = horse_part("tail")
		tail.position = HORSE_TAIL_PIVOT
		body.add_child(tail)
		var leg_mesh := horse_leg()
		for i in HORSE_HIPS.size():
			var leg := MeshInstance3D.new()
			leg.name = "Leg%d" % i
			leg.mesh = leg_mesh
			leg.position = HORSE_HIPS[i]
			body.add_child(leg)
	return root

## A rowing boat, facing -Z like everything else that is ridden: a hull with a
## pointed bow and a flat stern, a pale wooden inside with two thwarts to sit
## on, and a pair of oars lying across the gunwales. The waterline is the
## node's origin, so the hull sits BOAT_DRAFT deep.
static func _boat(tool: SurfaceTool, hull: Color) -> void:
	var wood := Color(0.78, 0.64, 0.42)
	var dark := hull.darkened(0.3)
	var top := 0.5 - BOAT_DRAFT
	var middle := top - 0.25

	# An open hull — a bottom, two sides and a transom, with two boards angled
	# in to a point for the bow — rather than a solid block: the first version
	# was a box, whose top face hid the inside, and the boat read as a red
	# brick with oars on it.
	var bottom := BoxMesh.new()
	bottom.size = Vector3(1.24, 0.1, 2.0)
	_add(tool, bottom, Transform3D(Basis(), Vector3(0.0, middle - 0.2, 0.25)), hull)
	for side in PackedFloat32Array([-1.0, 1.0]):
		var wall := BoxMesh.new()
		wall.size = Vector3(0.08, 0.5, 2.0)
		_add(tool, wall, Transform3D(Basis(), Vector3(side * 0.6, middle, 0.25)), hull)
		var board := BoxMesh.new()
		board.size = Vector3(0.08, 0.5, 1.22)
		_add(tool, board, Transform3D(
			Basis(Vector3.UP, side * deg_to_rad(-30.6)),
			Vector3(side * 0.31, middle, -1.275)
		), hull)
	var stern := BoxMesh.new()
	stern.size = Vector3(1.28, 0.5, 0.08)
	_add(tool, stern, Transform3D(Basis(), Vector3(0.0, middle, 1.21)), hull)
	# The bow's bottom: a wedge, made of a box turned to lie along each board.
	var bow_bottom := BoxMesh.new()
	bow_bottom.size = Vector3(0.7, 0.1, 1.05)
	_add(tool, bow_bottom, Transform3D(Basis(), Vector3(0.0, middle - 0.2, -1.2)), hull)
	# The pale inside: a floor you can see between the thwarts.
	var floor_board := BoxMesh.new()
	floor_board.size = Vector3(1.1, 0.04, 1.95)
	_add(tool, floor_board, Transform3D(Basis(), Vector3(0.0, middle - 0.14, 0.25)), wood)
	var bow_floor := BoxMesh.new()
	bow_floor.size = Vector3(0.55, 0.04, 0.9)
	_add(tool, bow_floor, Transform3D(Basis(), Vector3(0.0, middle - 0.14, -1.1)), wood)
	var stem := CylinderMesh.new()
	stem.top_radius = 0.05
	stem.bottom_radius = 0.05
	stem.height = 0.62
	stem.radial_segments = 6
	_add(tool, stem, Transform3D(Basis(), Vector3(0.0, middle + 0.06, -1.76)), dark)

	# Gunwales, a shade darker, along both sides and across the stern.
	for side in PackedFloat32Array([-1.0, 1.0]):
		var rail := BoxMesh.new()
		rail.size = Vector3(0.1, 0.07, 2.0)
		_add(tool, rail, Transform3D(Basis(), Vector3(side * 0.62, top, 0.25)), dark)
	var transom := BoxMesh.new()
	transom.size = Vector3(1.3, 0.07, 0.1)
	_add(tool, transom, Transform3D(Basis(), Vector3(0.0, top, 1.25)), dark)

	# Two thwarts to sit on.
	for z in PackedFloat32Array([-0.35, 0.65]):
		var thwart := BoxMesh.new()
		thwart.size = Vector3(1.2, 0.06, 0.3)
		_add(tool, thwart, Transform3D(Basis(), Vector3(0.0, top - 0.12, z)), wood)

	# Oars across the gunwales, blades out over the water.
	for side in PackedFloat32Array([-1.0, 1.0]):
		var oar := CylinderMesh.new()
		oar.top_radius = 0.03
		oar.bottom_radius = 0.03
		oar.height = 2.3
		oar.radial_segments = 5
		# A cylinder stands along Y; laid across the boat and tipped down a
		# little on the outboard side.
		var lay := Basis(Vector3.FORWARD, side * deg_to_rad(90.0 + 12.0))
		_add(tool, oar, Transform3D(lay, Vector3(side * 0.75, top + 0.08, 0.1)), wood)
		var blade := BoxMesh.new()
		blade.size = Vector3(0.5, 0.03, 0.16)
		_add(tool, blade, Transform3D(lay * Basis(Vector3.FORWARD, deg_to_rad(-90.0)), Vector3(side * 1.75, top - 0.14, 0.1)), wood)

static func _bicycle(tool: SurfaceTool) -> void:
	# Tubes are deliberately thicker than a real bicycle's. At the distance a
	# child sees it across a valley, 4 cm of steel is one pixel and the whole
	# machine reads as a discarded toy; 7 cm reads as a bicycle.
	var frame: Color = colour(BICYCLE)
	var rubber := Color(0.16, 0.16, 0.18)

	# A TorusMesh lies in the XZ plane, so a wheel needs rotating about X to
	# stand upright — not about Y, which merely spins a flat ring and leaves the
	# bicycle looking like two hoops dropped on the grass.
	for front in PackedFloat32Array([-1.0, 1.0]):
		var wheel := TorusMesh.new()
		wheel.inner_radius = 0.28
		wheel.outer_radius = 0.38
		wheel.rings = 14
		wheel.ring_segments = 7
		_add(tool, wheel, Transform3D(
			Basis(Vector3.RIGHT, deg_to_rad(90.0)), Vector3(0.0, 0.38, front * 0.62)
		), rubber)

	# Frame: two bars from the wheels up to the saddle, and the handlebars.
	var down_tube := CylinderMesh.new()
	down_tube.top_radius = 0.075
	down_tube.bottom_radius = 0.075
	down_tube.height = 1.05
	down_tube.radial_segments = 6
	_add(tool, down_tube, Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(58.0)), Vector3(0.0, 0.62, -0.28)
	), frame)

	var seat_tube := CylinderMesh.new()
	seat_tube.top_radius = 0.075
	seat_tube.bottom_radius = 0.075
	seat_tube.height = 0.86
	seat_tube.radial_segments = 6
	_add(tool, seat_tube, Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(-22.0)), Vector3(0.0, 0.68, 0.34)
	), frame)

	var top_tube := CylinderMesh.new()
	top_tube.top_radius = 0.07
	top_tube.bottom_radius = 0.07
	top_tube.height = 0.92
	top_tube.radial_segments = 6
	_add(tool, top_tube, Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(90.0)), Vector3(0.0, 0.94, 0.0)
	), frame)

	var bars := CylinderMesh.new()
	bars.top_radius = 0.06
	bars.bottom_radius = 0.06
	bars.height = 0.52
	bars.radial_segments = 6
	_add(tool, bars, Transform3D(
		Basis(Vector3.FORWARD, deg_to_rad(90.0)), Vector3(0.0, 1.06, -0.52)
	), rubber)

	var saddle := BoxMesh.new()
	saddle.size = Vector3(0.20, 0.10, 0.40)
	_add(tool, saddle, Transform3D(Basis(), Vector3(0.0, 1.12, 0.42)), rubber)

static func _add(tool: SurfaceTool, source: PrimitiveMesh, transform: Transform3D, colour: Color) -> void:
	var arrays := source.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for i in vertices.size():
			tool.set_color(colour)
			tool.add_vertex(transform * vertices[i])
		return
	for i in indices.size():
		tool.set_color(colour)
		tool.add_vertex(transform * vertices[indices[i]])
