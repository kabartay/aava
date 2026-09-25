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
## The fastest thing in the valley, and the only one nothing else likes: an
## engine going past is an engine going past, and every animal within earshot
## leaves. That is the whole trade — you get there first and there is nothing
## there when you arrive.
const MOTORCYCLE := &"motorcycle"
## Four fat wheels and a seat you sit astride: slower than the motorcycle and
## far steadier, which is the machine a six-year-old is allowed on.
const QUAD := &"quad"
## A boat: the one mount that goes where the others cannot at all — across
## the pond — and nowhere else. Five of them wait at the big pond's shore.
const BOAT := &"boat"

const ALL: Array[StringName] = [HORSE, BICYCLE, MOTORCYCLE, QUAD, BOAT]

## There is one horse and one bicycle, but several boats, so a mount is named
## by an id — "horse", or "boat:2" — and everything that wants to know what
## the thing *is* asks `kind_of`. Ids without a colon are their own kind.
static func kind_of(id: StringName) -> StringName:
	var text := String(id)
	var colon := text.find(":")
	return id if colon < 0 else StringName(text.substr(0, colon))

## The id of the n-th boat, and of the n-th horse. There is a herd now
## rather than one animal, so a horse is named the way a boat is.
static func boat_id(index: int) -> StringName:
	return StringName("%s:%d" % [BOAT, index])

static func horse_id(index: int) -> StringName:
	return StringName("%s:%d" % [HORSE, index])

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

## A coat per horse: bay, chestnut, black, grey, dun. Five horses all the
## same colour are one horse standing in five places.
const HORSE_COATS: Array[Color] = [
	Color(0.42, 0.29, 0.20), Color(0.55, 0.31, 0.16), Color(0.20, 0.18, 0.17),
	Color(0.68, 0.66, 0.63), Color(0.72, 0.60, 0.38),
]
## How deep the hull sits, and how high above the water a child sits in it.
const BOAT_DRAFT := 0.3
const BOAT_SEAT := 0.25

## Water deeper than this and a horse swims rather than wades: about where it
## would be off its feet.
const HORSE_SWIMS_AT := 1.1
## How deep a swimming horse floats: most of the barrel under, the withers
## and head clear.
const HORSE_DRAUGHT := 1.35
## How high the saddle sits above the horse's own feet. Taken from where the
## saddle is actually drawn (1.87 in the body's units, scaled by 1.2), so
## that where a rider sits is worked out from the horse rather than guessed
## at with a second number that can drift away from the first.
const HORSE_SADDLE_Y := 1.87 * 1.2

## The box a standing mount takes up, as (size, centre height): what a child
## bumps into instead of walking through it. Only while it stands — a mount
## being ridden is carried under the child and must not push them.
static func body_box(kind: StringName) -> Array:
	match kind_of(kind):
		HORSE:
			return [Vector3(0.9, 2.1, 2.9), 1.15]
		BOAT:
			return [Vector3(1.4, 0.55, 3.5), 0.05]
		MOTORCYCLE:
			return [Vector3(0.72, 1.35, 2.3), 0.68]
		QUAD:
			# Wider than it is long, which is what a quad is and what makes it
			# read as one from behind.
			return [Vector3(1.35, 1.25, 1.95), 0.6]
		_:
			return [Vector3(0.5, 1.0, 1.9), 0.55]

## Is this a thing with wheels, which has to be steered rather than pointed?
##
## A child on foot goes wherever the stick points, instantly, and so did a
## child on a motorcycle: push the stick sideways and the machine span on the
## spot like a shopping trolley. A bicycle and a motorcycle turn by leaning
## into a corner, which means the faster you are going the more ground the turn
## takes and standing still you cannot turn at all. A horse is not in this
## list: a horse can and does turn where it stands.
static func steers(kind: StringName) -> bool:
	var of := kind_of(kind)
	# The quad belongs here too, and was left out: it span on the spot exactly
	# the way the motorcycle used to, which is the thing four wheels on the
	# ground cannot do.
	return of == BICYCLE or of == MOTORCYCLE or of == QUAD

## Half the width of a mount, and nothing at all on foot. What the world uses
## to decide how much room the thing being ridden needs — a tree is as wide as
## the horse walking into it.
static func girth(kind: StringName) -> float:
	if kind == &"":
		return 0.0
	return (body_box(kind)[0] as Vector3).x * 0.5

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
		# Half what the motorcycle does, which is what a bicycle is next to
		# one: a child pedalling is not a machine, and eleven metres a second
		# read as a bicycle with an engine in it. Slower than a horse at a
		# gallop, too, and still the fastest way across flat ground because it
		# never needs catching or feeding.
		"speed": 8.25,
		"turn": 2.0,
		"max_slope": 0.28,
		"fords": false,
		"floats": false,
		"eye": 0.45,
		"colour": Color(0.90, 0.28, 0.24),
	},
	MOTORCYCLE: {
		# Half again as fast as the bicycle on the flat, and no better off it:
		# a machine with an engine still has two narrow wheels. It turns worse
		# than anything else here, because at that speed it has to — a
		# motorcycle that pivots on the spot is a bicycle that goes fast.
		"speed": 16.5,
		"turn": 1.5,
		# The best climber here, by some way: steeper than a horse with a
		# saddle on it and not far off what a child manages on their own feet.
		# An engine and a knobbly tyre is exactly the thing for getting up a
		# bank, and it would be a strange machine that cost three hundred coins
		# and stopped at the first slope.
		"max_slope": 0.95,
		"fords": false,
		"floats": false,
		"eye": 0.62,
		"colour": Color(0.16, 0.20, 0.30),
	},
	QUAD: {
		# Between the two, and steadier than either: four wheels on the ground
		# means it turns at any speed rather than leaning into a corner, and
		# it climbs nearly as well as the motorcycle because the grip is in
		# the tyres rather than in the speed. The machine for a child who
		# finds the motorcycle too quick and the bicycle too slow.
		"speed": 12.0,
		"turn": 2.2,
		"max_slope": 0.78,
		"fords": false,
		"floats": false,
		"eye": 0.72,
		# Purple, which nothing else in the valley is: the bicycle is red, the
		# motorcycle near-black, the horses brown. A machine is recognised at
		# two hundred metres by its colour long before its shape.
		"colour": Color(0.52, 0.33, 0.74),
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
	var boat := boat_index(kind)
	if boat >= 0:
		return BOAT_COLOURS[boat % BOAT_COLOURS.size()]
	var horse := which(kind)
	if kind_of(kind) == HORSE and horse >= 0:
		return HORSE_COATS[horse % HORSE_COATS.size()]
	return INFO[kind_of(kind)]["colour"]

## Which one of its kind an id names — "horse:2" is the third horse — or -1
## for an id with no number on it.
static func which(id: StringName) -> int:
	var text := String(id)
	var colon := text.find(":")
	if colon < 0:
		return -1
	return text.substr(colon + 1).to_int()

static func label(kind: StringName) -> String:
	return Text.of("mount_%s" % kind_of(kind))

## A horse: a barrel body on four legs with a neck and a head, built from the
## same primitives as the animals so it belongs to the same world.
static func build_mesh(kind: StringName) -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind_of(kind):
		HORSE:
			_horse(tool, colour(kind))
		BOAT:
			_boat(tool, colour(kind))
		MOTORCYCLE:
			_motorcycle(tool)
		QUAD:
			_quad(tool)
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
static func _horse(tool: SurfaceTool, hide := colour(HORSE)) -> void:
	# Baked into one mesh, every part keeps its own place on the horse, so
	# nothing is measured from a pivot: pivot zero. The legs are here too —
	# they were left out when they became nodes, and the one-piece horse
	# stood on nothing, which is what the screenshot tool drew.
	_horse_body(tool, hide)
	_horse_head(tool, Vector3.ZERO, hide)
	_horse_tail(tool, Vector3.ZERO, hide)
	for hip in HORSE_HIPS:
		_horse_leg(tool, hip, Vector3.ZERO, hide)

## The barrel, chest, shoulder and rump, the saddle and its reins.
static func _horse_body(tool: SurfaceTool, hide := colour(HORSE)) -> void:
	var s := 1.2
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
static func _horse_head(tool: SurfaceTool, pivot: Vector3, hide := colour(HORSE)) -> void:
	var s := 1.2
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
	# Nostrils and a soft muzzle. A horse's face is read at the nose — it is
	# what a child reaches for — and this one ended in a blank end of a box.
	var soft_nose := SphereMesh.new()
	soft_nose.radius = 0.17 * s
	soft_nose.height = 0.26 * s
	soft_nose.radial_segments = 8
	soft_nose.rings = 4
	_add(tool, soft_nose, Transform3D(
		Basis().scaled(Vector3(1.0, 0.9, 1.1)), Vector3(0.0, 1.98 * s, -1.52 * s) - pivot
	), hide.darkened(0.12))
	for side: float in [-1.0, 1.0]:
		var nostril := SphereMesh.new()
		nostril.radius = 0.045 * s
		nostril.height = 0.07 * s
		nostril.radial_segments = 6
		nostril.rings = 3
		_add(tool, nostril, Transform3D(
			Basis().scaled(Vector3(0.8, 1.2, 0.6)),
			Vector3(side * 0.08 * s, 2.0 * s, -1.62 * s) - pivot
		), hoof)

	var forelock := BoxMesh.new()
	forelock.size = Vector3(0.12 * s, 0.1 * s, 0.24 * s)
	_add(tool, forelock, Transform3D(Basis(), Vector3(0.0, 2.34 * s, -1.18 * s) - pivot), dark)

## The tail in two pieces, relative to where it joins the rump.
static func _horse_tail(tool: SurfaceTool, pivot: Vector3, hide := colour(HORSE)) -> void:
	var s := 1.2
	var dark := hide.darkened(0.3)
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
static func horse_part(part: String, hide := colour(HORSE)) -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	match part:
		"head":
			_horse_head(tool, HORSE_HEAD_PIVOT, hide)
		"tail":
			_horse_tail(tool, HORSE_TAIL_PIVOT, hide)
		_:
			_horse_body(tool, hide)
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
static func horse_leg(hide := colour(HORSE)) -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Relative to its own hip, every leg is the same leg, so which hip is
	# passed here does not matter as long as it is the pivot too.
	_horse_leg(tool, HORSE_HIPS[0], HORSE_HIPS[0], hide)
	tool.generate_normals()
	tool.set_material(AnimalKinds.fur_material())
	return tool.commit()

## A leg hanging from `hip`, drawn in coordinates relative to `pivot`.
##
## Two segments rather than one post: a heavy upper leg, a knee, a slender
## cannon bone, a pastern and a hoof. A horse's leg is thick at the top and
## thin at the bottom by a factor of two, and that taper — with a joint
## showing where it changes — is most of what tells a leg from a table leg.
static func _horse_leg(tool: SurfaceTool, hip: Vector3, pivot: Vector3, hide := colour(HORSE)) -> void:
	var s := 1.2
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
		var hide := colour(kind)
		body.mesh = horse_part("body", hide)
		var head := MeshInstance3D.new()
		head.name = "Head"
		head.mesh = horse_part("head", hide)
		head.position = HORSE_HEAD_PIVOT
		body.add_child(head)
		var tail := MeshInstance3D.new()
		tail.name = "Tail"
		tail.mesh = horse_part("tail", hide)
		tail.position = HORSE_TAIL_PIVOT
		body.add_child(tail)
		var leg_mesh := horse_leg(hide)
		for i in HORSE_HIPS.size():
			var leg := MeshInstance3D.new()
			leg.name = "Leg%d" % i
			leg.mesh = leg_mesh
			leg.position = HORSE_HIPS[i]
			body.add_child(leg)
	return root

## A motorcycle, facing -Z like everything else that is ridden.
##
## Built from the bicycle outwards, because that is what tells the two apart at
## a glance: same silhouette, everything heavier. Fat tyres instead of thin
## hoops, an engine block where the pedals were, a fuel tank along the top
## tube, a long seat, a headlamp, and a pipe down the side. Nothing here is
## mechanical — it is a shape a six-year-old can name from across a field.
static func _motorcycle(tool: SurfaceTool) -> void:
	var paint: Color = colour(MOTORCYCLE)
	var rubber := Color(0.12, 0.12, 0.14)
	var steel := Color(0.46, 0.48, 0.52)
	var chrome := Color(0.88, 0.90, 0.94)
	var leather := Color(0.11, 0.11, 0.13)

	var back := Vector3(0.0, 0.42, 0.74)
	var front := Vector3(0.0, 0.42, -0.78)
	# Fatter tyres and more spokes than the bicycle: same wheel, different
	# machine, which is exactly how the two should differ.
	_wheel(tool, back, 0.42, 0.12, 8, rubber, steel)
	_wheel(tool, front, 0.42, 0.11, 8, rubber, steel)

	# Mudguards over both wheels, which is most of what makes a motorcycle look
	# built rather than assembled: a curve following the tyre.
	for wheel: Array in [[front, -1.0, 0.11], [back, 1.0, 0.12]]:
		var hub_at: Vector3 = wheel[0]
		for piece in 5:
			var sweep := deg_to_rad(-52.0 + float(piece) * 26.0) * float(wheel[1])
			var plate := BoxMesh.new()
			plate.size = Vector3(float(wheel[2]) * 2.4, 0.05, 0.22)
			_add(tool, plate, Transform3D(
				Basis(Vector3.RIGHT, sweep),
				hub_at + Vector3(0.0, cos(sweep) * 0.5, -sin(sweep) * 0.5)
			), paint)

	# The engine: a crankcase with a cylinder leaning forward out of it, finned.
	var crankcase := BoxMesh.new()
	crankcase.size = Vector3(0.34, 0.3, 0.44)
	_add(tool, crankcase, Transform3D(Basis(), Vector3(0.0, 0.42, 0.08)), steel.darkened(0.25))
	var barrel := BoxMesh.new()
	barrel.size = Vector3(0.3, 0.34, 0.26)
	_add(tool, barrel, Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(16.0)), Vector3(0.0, 0.7, -0.04)
	), steel)
	for fin in 4:
		var rib := BoxMesh.new()
		rib.size = Vector3(0.38, 0.03, 0.32)
		_add(tool, rib, Transform3D(
			Basis(Vector3.RIGHT, deg_to_rad(16.0)), Vector3(0.0, 0.6 + float(fin) * 0.08, -0.03)
		), chrome)

	# The frame: a spine from the head to the back, and the swingarm.
	var head_low := Vector3(0.0, 0.78, -0.58)
	var head_high := Vector3(0.0, 1.12, -0.5)
	var spine := Vector3(0.0, 1.0, 0.36)
	_tube(tool, head_low, spine, 0.055, paint.darkened(0.25))
	_tube(tool, head_low, head_high, 0.06, steel)
	for side in PackedFloat32Array([-1.0, 1.0]):
		_tube(tool, Vector3(side * 0.1, 0.42, 0.2), back + Vector3(side * 0.12, 0.0, 0.0), 0.04, steel)
		# The shock absorber up to the seat rails.
		_tube(tool, back + Vector3(side * 0.12, 0.0, 0.0), Vector3(side * 0.12, 0.92, 0.5), 0.045, chrome)
		# Front forks, with a fat slider at the bottom.
		_tube(tool, head_low, front + Vector3(side * 0.1, 0.0, 0.0), 0.045, chrome)

	# The tank: two spheres blended, wider at the front, so it has a waist.
	var tank := SphereMesh.new()
	tank.radius = 0.26
	tank.height = 0.42
	tank.radial_segments = 12
	tank.rings = 7
	_add(tool, tank, Transform3D(
		Basis().scaled(Vector3(0.9, 1.0, 1.3)), Vector3(0.0, 1.0, -0.24)
	), paint)
	var tank_tail := SphereMesh.new()
	tank_tail.radius = 0.2
	tank_tail.height = 0.34
	tank_tail.radial_segments = 10
	tank_tail.rings = 6
	_add(tool, tank_tail, Transform3D(
		Basis().scaled(Vector3(0.85, 1.0, 1.2)), Vector3(0.0, 1.02, 0.06)
	), paint)
	# A stripe along it, which is what makes a painted tank read as painted.
	var stripe := BoxMesh.new()
	stripe.size = Vector3(0.1, 0.02, 0.7)
	_add(tool, stripe, Transform3D(Basis(), Vector3(0.0, 1.22, -0.16)), Color(0.92, 0.90, 0.86))

	# The seat: a long saddle with a step up to the pillion and a tail behind.
	var saddle := BoxMesh.new()
	saddle.size = Vector3(0.3, 0.12, 0.52)
	_add(tool, saddle, Transform3D(Basis(), Vector3(0.0, 1.06, 0.4)), leather)
	var pillion := BoxMesh.new()
	pillion.size = Vector3(0.28, 0.12, 0.3)
	_add(tool, pillion, Transform3D(Basis(), Vector3(0.0, 1.14, 0.72)), leather)
	var tail := BoxMesh.new()
	tail.size = Vector3(0.24, 0.16, 0.2)
	_add(tool, tail, Transform3D(Basis(), Vector3(0.0, 1.12, 0.92)), paint)
	var lamp_back := BoxMesh.new()
	lamp_back.size = Vector3(0.14, 0.08, 0.05)
	_add(tool, lamp_back, Transform3D(Basis(), Vector3(0.0, 1.12, 1.02)), Color(0.86, 0.22, 0.20))

	# Bars, grips, mirrors and a headlamp in its shell.
	var bars_at := head_high + Vector3(0.0, 0.08, -0.04)
	_tube(tool, bars_at + Vector3(-0.34, 0.0, 0.0), bars_at + Vector3(0.34, 0.0, 0.0), 0.032, chrome)
	for side in PackedFloat32Array([-1.0, 1.0]):
		_tube(
			tool, bars_at + Vector3(side * 0.22, 0.0, 0.0),
			bars_at + Vector3(side * 0.34, 0.0, 0.05), 0.042, leather
		)
		_tube(
			tool, bars_at + Vector3(side * 0.2, 0.0, 0.0),
			bars_at + Vector3(side * 0.26, 0.2, -0.02), 0.018, chrome
		)
		var glass := BoxMesh.new()
		glass.size = Vector3(0.12, 0.08, 0.02)
		_add(tool, glass, Transform3D(
			Basis(), bars_at + Vector3(side * 0.26, 0.21, -0.02)
		), Color(0.74, 0.82, 0.88))
	var shell := SphereMesh.new()
	shell.radius = 0.16
	shell.height = 0.3
	shell.radial_segments = 10
	shell.rings = 6
	_add(tool, shell, Transform3D(
		Basis().scaled(Vector3(1.0, 1.0, 0.8)), Vector3(0.0, 1.0, -0.7)
	), paint)
	var lens := CylinderMesh.new()
	lens.top_radius = 0.12
	lens.bottom_radius = 0.12
	lens.height = 0.04
	lens.radial_segments = 12
	_add(tool, lens, Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(90.0)), Vector3(0.0, 1.0, -0.8)
	), Color(0.97, 0.95, 0.76))

	# The exhaust: a header off the barrel curving back into a silencer.
	_tube(tool, Vector3(0.1, 0.5, -0.16), Vector3(0.2, 0.34, 0.2), 0.05, chrome)
	_tube(tool, Vector3(0.2, 0.34, 0.2), Vector3(0.24, 0.38, 0.86), 0.07, chrome)
	var can := CylinderMesh.new()
	can.top_radius = 0.085
	can.bottom_radius = 0.075
	can.height = 0.3
	can.radial_segments = 8
	_add(tool, can, Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(86.0)), Vector3(0.24, 0.4, 0.94)
	), chrome)

	# Footrests and a kickstand, so it stands rather than balancing.
	for side in PackedFloat32Array([-1.0, 1.0]):
		var rest := CylinderMesh.new()
		rest.top_radius = 0.028
		rest.bottom_radius = 0.028
		rest.height = 0.2
		rest.radial_segments = 6
		_add(tool, rest, Transform3D(
			Basis(Vector3.FORWARD, deg_to_rad(90.0)), Vector3(side * 0.24, 0.36, 0.3)
		), steel)
	_tube(tool, Vector3(-0.16, 0.36, 0.22), Vector3(-0.3, 0.03, 0.34), 0.03, steel)

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

## A spoked wheel standing upright: tyre, rim, hub and spokes, at a given
## place along the machine. Every wheel in this file is built here, so a
## bicycle's and a motorcycle's differ in their numbers rather than in their
## code — and spokes are what stop a wheel reading as a black doughnut.
static func _wheel(
	tool: SurfaceTool, at: Vector3, tyre_radius: float, tyre_width: float,
	spokes: int, rubber: Color, metal: Color
) -> void:
	# A torus and a cylinder both stand about +Y. A machine here faces -Z, so
	# its wheels turn about X: the axle lies across the frame, and the wheel's
	# own plane is the one the frame is drawn in. Turning them about X instead
	# — which is what the first version did, copying the note on the old
	# bicycle — stands each wheel across the machine like a roundabout, and
	# from the saddle the bicycle reads as two discs bolted on sideways.
	var upright := Basis(Vector3.FORWARD, deg_to_rad(90.0))
	var tyre := TorusMesh.new()
	tyre.inner_radius = tyre_radius - tyre_width
	tyre.outer_radius = tyre_radius
	tyre.rings = 16
	tyre.ring_segments = 8
	_add(tool, tyre, Transform3D(upright, at), rubber)
	# The rim just inside the tyre, a shade brighter, so the two read apart.
	var rim := TorusMesh.new()
	rim.inner_radius = tyre_radius - tyre_width - 0.03
	rim.outer_radius = tyre_radius - tyre_width + 0.01
	rim.rings = 16
	rim.ring_segments = 5
	_add(tool, rim, Transform3D(upright, at), metal)
	var hub := CylinderMesh.new()
	hub.top_radius = tyre_width * 0.75
	hub.bottom_radius = tyre_width * 0.75
	hub.height = tyre_width * 1.6
	hub.radial_segments = 8
	_add(tool, hub, Transform3D(upright, at), metal)
	for spoke in spokes:
		# Spokes lie in the wheel's plane, which is the one containing Y and Z,
		# so they are turned about X.
		var angle := PI * float(spoke) / float(spokes)
		var bar := CylinderMesh.new()
		bar.top_radius = 0.012
		bar.bottom_radius = 0.012
		bar.height = (tyre_radius - tyre_width) * 2.0
		bar.radial_segments = 4
		_add(tool, bar, Transform3D(Basis(Vector3.RIGHT, angle), at), metal)

## A quad bike, facing -Z.
##
## The silhouette is the whole job: four fat tyres set wide at the corners, a
## body slung low between them, a seat you sit astride and wide bars. Nothing
## else in the valley is square on four wheels, so at any distance it is
## unmistakably not the motorcycle — which matters, because the two stand side
## by side in the shop and cost different money.
static func _quad(tool: SurfaceTool) -> void:
	var paint := colour(QUAD)
	var rubber := Color(0.11, 0.11, 0.12)
	var tread := Color(0.16, 0.16, 0.17)
	var metal := Color(0.62, 0.64, 0.68)
	var dark := paint.darkened(0.5)
	var seat_colour := Color(0.18, 0.17, 0.20)

	# Wheels at the corners, and knobbly: a quad's tyres are its whole
	# character, and a smooth torus reads as a shopping trolley castor. The
	# lugs are short blocks laid round the tread, which is cheap and, at the
	# distance a child sees one, exactly right.
	for side: float in [-1.0, 1.0]:
		for end: float in [-1.0, 1.0]:
			var hub_at := Vector3(side * 0.56, 0.36, end * 0.68)
			_wheel(tool, hub_at, 0.36, 0.17, 5, rubber, metal)
			for lug in 10:
				var angle := TAU * float(lug) / 10.0
				var knob := BoxMesh.new()
				knob.size = Vector3(0.2, 0.1, 0.07)
				_add(
					tool, knob,
					Transform3D(
						Basis(Vector3.RIGHT, angle),
						hub_at + Vector3(0.0, cos(angle) * 0.33, sin(angle) * 0.33)
					),
					tread
				)
			# The suspension arm from the chassis out to the hub, so the wheels
			# are held on rather than hovering beside the body.
			var arm := BoxMesh.new()
			arm.size = Vector3(0.36, 0.09, 0.12)
			_add(
				tool, arm,
				Transform3D(Basis(), Vector3(side * 0.34, 0.38, end * 0.68)),
				metal
			)

	# The chassis: a low tub between the wheels, narrowing to a nose.
	var body := BoxMesh.new()
	body.size = Vector3(0.7, 0.28, 1.34)
	_add(tool, body, Transform3D(Basis(), Vector3(0.0, 0.52, 0.0)), paint)
	var nose := BoxMesh.new()
	nose.size = Vector3(0.56, 0.24, 0.56)
	_add(
		tool, nose,
		Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-14.0)), Vector3(0.0, 0.6, -0.82)),
		paint
	)
	var snout := BoxMesh.new()
	snout.size = Vector3(0.4, 0.18, 0.3)
	_add(
		tool, snout,
		Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-20.0)), Vector3(0.0, 0.62, -1.12)),
		dark
	)

	# Mudguards: wide, with a lip, curved by stacking three plates round the
	# top of each wheel rather than one flat slab.
	for side: float in [-1.0, 1.0]:
		for end: float in [-1.0, 1.0]:
			for plate in 3:
				var lean := deg_to_rad(-26.0 + 26.0 * float(plate))
				var guard := BoxMesh.new()
				guard.size = Vector3(0.5, 0.07, 0.34)
				_add(
					tool, guard,
					Transform3D(
						Basis(Vector3.RIGHT, lean),
						Vector3(
							side * 0.56,
							0.72 + cos(lean) * 0.02,
							end * 0.68 + sin(lean) * 0.3
						)
					),
					paint.lightened(0.16)
				)

	# Footwells between the wheels, which is where the feet go and the one
	# part of a quad that is not on a motorcycle at all.
	for side: float in [-1.0, 1.0]:
		var board := BoxMesh.new()
		board.size = Vector3(0.3, 0.06, 0.66)
		_add(tool, board, Transform3D(Basis(), Vector3(side * 0.44, 0.42, 0.0)), dark)

	# The seat: a step-through saddle with a raised back, and the tank in
	# front of it.
	var seat := BoxMesh.new()
	seat.size = Vector3(0.4, 0.2, 0.62)
	_add(
		tool, seat,
		Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-5.0)), Vector3(0.0, 0.76, 0.14)),
		seat_colour
	)
	var seat_back := BoxMesh.new()
	seat_back.size = Vector3(0.4, 0.22, 0.14)
	_add(
		tool, seat_back,
		Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-16.0)), Vector3(0.0, 0.9, 0.44)),
		seat_colour
	)
	var tank := BoxMesh.new()
	tank.size = Vector3(0.34, 0.28, 0.4)
	_add(tool, tank, Transform3D(Basis(), Vector3(0.0, 0.8, -0.3)), paint.darkened(0.2))

	# Bars on a raked stem, with grips and levers.
	var stem := CylinderMesh.new()
	stem.top_radius = 0.045
	stem.bottom_radius = 0.06
	stem.height = 0.46
	stem.radial_segments = 6
	_add(
		tool, stem,
		Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-16.0)), Vector3(0.0, 0.98, -0.5)),
		metal
	)
	var bars := CylinderMesh.new()
	bars.top_radius = 0.032
	bars.bottom_radius = 0.032
	bars.height = 0.9
	bars.radial_segments = 6
	_add(
		tool, bars,
		Transform3D(Basis(Vector3.BACK, deg_to_rad(90.0)), Vector3(0.0, 1.18, -0.58)),
		metal
	)
	for side: float in [-1.0, 1.0]:
		var grip := CylinderMesh.new()
		grip.top_radius = 0.052
		grip.bottom_radius = 0.052
		grip.height = 0.16
		grip.radial_segments = 6
		_add(
			tool, grip,
			Transform3D(Basis(Vector3.BACK, deg_to_rad(90.0)), Vector3(side * 0.36, 1.18, -0.58)),
			seat_colour
		)
		var lever := BoxMesh.new()
		lever.size = Vector3(0.14, 0.025, 0.05)
		_add(
			tool, lever,
			Transform3D(Basis(Vector3.UP, side * deg_to_rad(16.0)), Vector3(side * 0.24, 1.14, -0.66)),
			metal
		)
	# A crossbar pad, the way a quad's bars are braced.
	var pad := BoxMesh.new()
	pad.size = Vector3(0.22, 0.1, 0.1)
	_add(tool, pad, Transform3D(Basis(), Vector3(0.0, 1.13, -0.5)), paint.lightened(0.2))

	# Twin headlights on the nose, a rack over the tail, and an exhaust down
	# the right-hand side: the three details that say this one works.
	for side: float in [-1.0, 1.0]:
		var lamp := CylinderMesh.new()
		lamp.top_radius = 0.085
		lamp.bottom_radius = 0.085
		lamp.height = 0.06
		lamp.radial_segments = 8
		_add(
			tool, lamp,
			Transform3D(Basis(Vector3.RIGHT, deg_to_rad(74.0)), Vector3(side * 0.17, 0.86, -1.2)),
			Color(0.98, 0.95, 0.76)
		)
	for bar in 3:
		var rail := CylinderMesh.new()
		rail.top_radius = 0.022
		rail.bottom_radius = 0.022
		rail.height = 0.54
		rail.radial_segments = 5
		_add(
			tool, rail,
			Transform3D(
				Basis(Vector3.BACK, deg_to_rad(90.0)),
				Vector3(0.0, 0.84, 0.62 + float(bar) * 0.13)
			),
			metal
		)
	for post: float in [-1.0, 1.0]:
		var leg := CylinderMesh.new()
		leg.top_radius = 0.02
		leg.bottom_radius = 0.02
		leg.height = 0.2
		leg.radial_segments = 5
		_add(tool, leg, Transform3D(Basis(), Vector3(post * 0.24, 0.74, 0.7)), metal)
	var pipe := CylinderMesh.new()
	pipe.top_radius = 0.055
	pipe.bottom_radius = 0.07
	pipe.height = 0.9
	pipe.radial_segments = 7
	_add(
		tool, pipe,
		Transform3D(Basis(Vector3.RIGHT, deg_to_rad(84.0)), Vector3(0.3, 0.52, 0.42)),
		metal.darkened(0.3)
	)

## A bicycle, facing -Z.
##
## Built as a bicycle is built rather than as a silhouette of one: two spoked
## wheels, a diamond frame with a head tube and forks, chainstays reaching back
## to the rear axle, a chainring with cranks and pedals, bars with grips on a
## stem, and a saddle on a post. It was five fat tubes and two hoops before,
## which read as a bicycle only because nothing else in the valley has two
## wheels.
##
## Tubes stay thicker than a real bicycle\'s. At the distance a child sees one
## across a valley, four centimetres of steel is less than a pixel and the
## machine disappears; five to six reads as a bicycle.
static func _bicycle(tool: SurfaceTool) -> void:
	var frame: Color = colour(BICYCLE)
	var rubber := Color(0.13, 0.13, 0.15)
	var metal := Color(0.80, 0.82, 0.86)
	var grip := Color(0.18, 0.18, 0.20)

	var back := Vector3(0.0, 0.40, 0.66)
	var front := Vector3(0.0, 0.40, -0.66)
	_wheel(tool, back, 0.40, 0.055, 6, rubber, metal)
	_wheel(tool, front, 0.40, 0.055, 6, rubber, metal)

	# The diamond: bottom bracket low in the middle, seat tube up from it, down
	# tube forward to the head tube, top tube between the two.
	var bracket := Vector3(0.0, 0.34, 0.16)
	var head_low := Vector3(0.0, 0.62, -0.5)
	var head_high := Vector3(0.0, 0.98, -0.42)
	var seat_top := Vector3(0.0, 1.06, 0.3)
	_tube(tool, bracket, head_low, 0.055, frame)
	_tube(tool, bracket, seat_top, 0.05, frame)
	_tube(tool, head_high, seat_top, 0.05, frame)
	_tube(tool, head_low, head_high, 0.06, frame)
	# Chainstays and seatstays: the triangle behind, which is the half of a
	# bicycle everyone forgets and the half that makes it read as one.
	for side in PackedFloat32Array([-1.0, 1.0]):
		_tube(tool, bracket, back + Vector3(side * 0.06, 0.0, 0.0), 0.032, frame)
		_tube(tool, seat_top, back + Vector3(side * 0.06, 0.0, 0.0), 0.028, frame)
		# Forks down to the front axle.
		_tube(tool, head_low, front + Vector3(side * 0.06, 0.0, 0.0), 0.034, metal)

	# Chainring and cranks, with a pedal on each.
	var ring := CylinderMesh.new()
	ring.top_radius = 0.13
	ring.bottom_radius = 0.13
	ring.height = 0.02
	ring.radial_segments = 12
	_add(tool, ring, Transform3D(Basis(Vector3.FORWARD, deg_to_rad(90.0)), bracket), metal)
	for side in PackedFloat32Array([-1.0, 1.0]):
		var crank := BoxMesh.new()
		crank.size = Vector3(0.035, 0.24, 0.05)
		_add(tool, crank, Transform3D(
			Basis(Vector3.RIGHT, side * deg_to_rad(40.0)),
			bracket + Vector3(side * 0.09, 0.0, 0.0)
		), metal)
		var pedal := BoxMesh.new()
		pedal.size = Vector3(0.09, 0.03, 0.17)
		_add(tool, pedal, Transform3D(
			Basis(), bracket + Vector3(side * 0.13, side * -0.1, side * 0.07)
		), grip)

	# Bars on a stem, with grips at the ends.
	_tube(tool, head_high, head_high + Vector3(0.0, 0.1, -0.08), 0.04, metal)
	var bars_at := head_high + Vector3(0.0, 0.1, -0.08)
	_tube(tool, bars_at + Vector3(-0.28, 0.0, 0.0), bars_at + Vector3(0.28, 0.0, 0.0), 0.028, metal)
	for side in PackedFloat32Array([-1.0, 1.0]):
		_tube(
			tool, bars_at + Vector3(side * 0.18, 0.0, 0.0),
			bars_at + Vector3(side * 0.28, 0.0, 0.04), 0.036, grip
		)

	# Saddle on its post: a nose and a seat, not a brick.
	_tube(tool, seat_top, seat_top + Vector3(0.0, 0.1, 0.02), 0.032, metal)
	var seat := BoxMesh.new()
	seat.size = Vector3(0.17, 0.06, 0.26)
	_add(tool, seat, Transform3D(Basis(), seat_top + Vector3(0.0, 0.16, 0.04)), grip)
	var nose := BoxMesh.new()
	nose.size = Vector3(0.07, 0.05, 0.16)
	_add(tool, nose, Transform3D(Basis(), seat_top + Vector3(0.0, 0.16, -0.12)), grip)
	# A bell, because every child\'s bicycle has one.
	var bell := CylinderMesh.new()
	bell.top_radius = 0.035
	bell.bottom_radius = 0.035
	bell.height = 0.04
	bell.radial_segments = 8
	_add(tool, bell, Transform3D(Basis(), bars_at + Vector3(-0.1, 0.05, 0.0)), Color(0.86, 0.72, 0.32))

## A length of tube between two points, which is how every frame here is
## described: a cylinder is defined by its middle and its axis, and writing
## that out at each of a dozen joints is where frames come apart.
static func _tube(
	tool: SurfaceTool, from: Vector3, to: Vector3, radius: float, colour_of: Color
) -> void:
	var along := to - from
	var length := along.length()
	if length < 0.001:
		return
	var tube := CylinderMesh.new()
	tube.top_radius = radius
	tube.bottom_radius = radius
	tube.height = length
	tube.radial_segments = 6
	# A cylinder stands along +Y; turn that onto the line between the points.
	var up := Vector3.UP
	var axis := up.cross(along.normalized())
	var basis := Basis()
	if axis.length() > 0.0001:
		basis = Basis(axis.normalized(), up.angle_to(along.normalized()))
	elif along.y < 0.0:
		basis = Basis(Vector3.RIGHT, PI)
	_add(tool, tube, Transform3D(basis, (from + to) * 0.5), colour_of)

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
