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
## Where the boat's two thwarts are along it, and where its oars cross the
## gunwales: the child rows from the thwart at the oars, which is the one under
## them when they step in.
const BOAT_THWARTS: Array[float] = [-0.6, 0.1]
const BOAT_OARS_Z := 0.1
const BOAT_SEAT := 0.25

## Water deeper than this and a horse swims rather than wades: about where it
## would be off its feet.
##
## The same number as the draught below, so that a horse going from wading to
## swimming is not put up or down a hand's breadth by it; the pony's belly is
## 0.52 m up, and at this depth the water is over it.
const HORSE_SWIMS_AT := 0.7
## How deep a swimming horse floats: the barrel half under, the withers
## and head clear.
const HORSE_DRAUGHT := 0.7
## How high the saddle's seat is above the pony's own feet: the rider's origin,
## which is where the child's pelvis rests. Taken from where the saddle is
## actually drawn (the cloth and seat laid on the back, see `_horse_saddle`), so that where a rider sits is worked out from the horse
## rather than guessed at with a second number that can drift away from the
## first. A child's pony: the withers are 1.16 m up and this is level with them.
const HORSE_SADDLE_Y := 1.12

## The box a standing mount takes up, as (size, centre height): what a child
## bumps into instead of walking through it. Only while it stands — a mount
## being ridden is carried under the child and must not push them.
static func body_box(kind: StringName) -> Array:
	match kind_of(kind):
		HORSE:
			# As wide as the pony and the child's knees either side of it.
			return [Vector3(0.6, 1.3, 1.5), 0.65]
		BOAT:
			return [Vector3(1.4, 0.55, 3.5), 0.05]
		MOTORCYCLE:
			return [Vector3(0.72, 1.35, 2.3), 0.68]
		QUAD:
			# Wider than it is long, which is what a quad is and what makes it
			# read as one from behind. Grown with the mesh, so the room it
			# takes up and the thing a child sees stay the same object.
			#
			# 1.7 across, because that is where the outside of the tyres is:
			# at 1.35 a child walked twenty centimetres into each wheel.
			return [Vector3(1.7, 1.25, 2.3) * QUAD_SCALE, 0.6 * QUAD_SCALE]
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

## How far apart a machine's axles are.
##
## What a steered machine actually does is roll: the back wheel follows the
## front one, and how fast the whole thing comes round is the speed divided by
## the wheelbase, times the tangent of the angle the bars are at. A long
## machine turns lazily, a short one sharply, and neither turns at all standing
## still — which is the thing a rider feels and the thing this game got wrong.
static func wheelbase(kind: StringName) -> float:
	match kind_of(kind):
		MOTORCYCLE:
			return 1.4
		QUAD:
			return 1.25
		_:
			return 1.05

## How hard a machine holds the ground sideways: how fast whatever is across
## the wheels is scrubbed off, per second.
##
## Four wheels hold best, a bicycle's narrow tyres least. Not infinite for any
## of them — a machine perfectly rigid to its own heading twitches whenever the
## heading twitches — but high enough that a corner is a corner rather than a
## drift across ice, which is what it was.
static func grip(kind: StringName) -> float:
	match kind_of(kind):
		QUAD:
			return 9.5
		MOTORCYCLE:
			# Higher than it was. With loose grip the body came round faster
			# than the path curved, and a machine whose nose leads its own
			# line reads as pivoting rather than cornering — which is what was
			# left of the spin-on-the-spot after the rest of it was fixed.
			return 13.0
		_:
			return 11.0

## How much bigger the quad is drawn than it was designed. A machine a child
## sits astride with a wheel at each corner looked like a toy beside the
## motorcycle at the size it was first built.
const QUAD_SCALE := 1.15

## How far the bars go over at full lock.
const FULL_LOCK := deg_to_rad(38.0)

## How hard each machine pulls away, as a share of Player.MACHINE_PULL (which is
## the motorcycle's). A child pedalling a bicycle does not leap to eight metres
## a second in under a second the way an engine does, and a small child who
## pushes the stick to the rim should be carried up to speed, not thrown into
## it: the bicycle takes a little under two seconds to reach nine tenths of its
## top speed from rest, the quad two, the motorcycle about the same.
static func pull_share(kind: StringName) -> float:
	match kind_of(kind):
		BICYCLE:
			return 0.5
		QUAD:
			return 0.6
		_:
			return 0.85

## How firmly the brakes bite, as a multiple of how hard the machine pulls away.
## Stronger than the pull, because stopping is the thing that has to be
## trusted, and still a slide of a second and a half rather than a stop dead:
## a child thrown forward by a halt that takes no time at all will not do it
## twice.
const BRAKE_SHARE := 1.3

## How far each machine leans into a corner, against the lean a motorcycle takes
## (Player.RIDE_BANK). A bicycle is nearly upright at a crawl and leans well over
## at speed, so it takes more than the motorcycle, whose weight is low; a quad
## sits on four wheels and does not lean into a corner at all, which is half of
## what makes it feel like a quad.
static func lean_share(kind: StringName) -> float:
	match kind_of(kind):
		BICYCLE:
			return 1.7
		QUAD:
			return 0.0
		_:
			return 1.0

## How hard the engine of whatever is being ridden is working, for the sound:
## nought at a standstill to one at its own full pelt, and -1 for a machine with
## no engine at all, which is how the sound is told to stay silent. Only the
## motorcycle and the quad have one; a bicycle is heard as tyres and a freewheel
## (Ambience.cycling), not as a motor.
static func engine_effort(kind: StringName, pace: float) -> float:
	var of := kind_of(kind)
	if of != MOTORCYCLE and of != QUAD:
		return -1.0
	return clampf(pace / speed(of), 0.0, 1.0)

## Half the width of a mount, and nothing at all on foot. What the world uses
## to decide how much room the thing being ridden needs — a tree is as wide as
## the horse walking into it.
static func girth(kind: StringName) -> float:
	if kind == &"":
		return 0.0
	# Remembered per id. Every animal that is walking asks about every mount in
	# the meadow, every frame (see Mounts.blocks), and each answer was a string
	# cut apart, a name made from the pieces and a fresh array and vector, to
	# get a number that never changes.
	var known = _girths.get(kind)
	if known != null:
		return known
	var half := (body_box(kind)[0] as Vector3).x * 0.5
	_girths[kind] = half
	return half

static var _girths: Dictionary = {}

## How many ids have had their girth remembered. For the checks.
static func girths_known() -> int:
	return _girths.size()

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
		#
		# HORSE_SADDLE_Y, not a number of its own. That constant was written
		# precisely so the seat is taken from where the saddle is drawn rather
		# than guessed at "with a second number that can drift away from the
		# first" — and then nothing ever called it, and the second number sat
		# here fourteen centimetres lower, which is a rider sunk into the
		# horse's back.
		"eye": HORSE_SADDLE_Y,
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
		# The best machine here for a bank, and stopping just short of what a
		# child manages on their own feet. An engine and a knobbly tyre is
		# exactly the thing for getting up a slope, and it would be a strange
		# machine that cost three hundred coins and stopped at the first one.
		#
		# It said 0.95, which was meant to read as "about what a child can
		# walk up" and does not: a child walks up 52 degrees, and 0.95 in these
		# units is 61. Everything a machine can reach, a child has to be able
		# to reach on foot — see Mounts.steepest_ground.
		"max_slope": 0.68,
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
		# Slower to come round than the numbers first said. At two and a
		# quarter radians a second a quad turned a full circle in under three
		# seconds, which at twelve metres a second is not a corner but a
		# skid — the rider is flung round rather than steering.
		"turn": 1.35,
		# Just under the motorcycle, and for the same reason it is not higher:
		# a machine may go wherever a child's own feet could follow it, and no
		# further. At 0.78 it went onto 55-degree banks a child slides off,
		# which is how one came to be left standing on a hillside its owner
		# could not walk back up to.
		"max_slope": 0.66,
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
			# Built at the size it was drawn and then grown, rather than every
			# number in it changed by hand: a machine scaled whole keeps its
			# proportions, and proportions are what a child recognises.
			_grow(tool, QUAD_SCALE)
		_:
			_bicycle(tool)
	tool.generate_normals()
	tool.set_material(AnimalKinds.fur_material())
	return tool.commit()

## The body and its wheels, baked into one mesh: what a machine looks like
## laid out on a shop floor, rather than what it looks like ridden.
##
## build_node hangs the wheels on a machine as separate MeshInstance3D
## children, which is right for something that has to turn them as it rolls.
## The shop floor is not built that way — the whole room is one static mesh,
## assembled by copying each thing's vertices into it at a transform, see
## _add_as_drawn in places.gd — so a machine shown there has to be one mesh
## too. build_mesh alone is the body without its wheels, and using it for the
## shop's display is exactly how three bicycles, a motorcycle and a quad came
## to be standing on the shop floor with nothing under them.
static func display_mesh(kind: StringName) -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_bake_into(tool, build_mesh(kind), Transform3D())
	if kind_of(kind) == BICYCLE or kind_of(kind) == MOTORCYCLE:
		var tyre := two_wheeler_wheel_mesh(kind)
		for spot in wheel_spots(kind):
			_bake_into(tool, tyre, Transform3D(Basis(), spot))
	elif kind_of(kind) == QUAD:
		var wheel_mesh := quad_wheel_mesh()
		for spot in QUAD_WHEELS:
			_bake_into(tool, wheel_mesh, Transform3D(Basis(), spot * QUAD_SCALE))
	tool.generate_normals()
	tool.set_material(AnimalKinds.fur_material())
	return tool.commit()

## Copy one mesh's triangles into another SurfaceTool, at a transform. The
## same operation _add_as_drawn does for the whole shop floor, kept here as
## well because a machine's own wheel positions are this file's to know.
static func _bake_into(tool: SurfaceTool, mesh: Mesh, where: Transform3D) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices = arrays[Mesh.ARRAY_INDEX]
	if indices == null:
		for i in vertices.size():
			tool.set_color(colours[i] if i < colours.size() else Color.WHITE)
			tool.add_vertex(where * vertices[i])
		return
	for index in indices as PackedInt32Array:
		tool.set_color(colours[index] if index < colours.size() else Color.WHITE)
		tool.add_vertex(where * vertices[index])

## Where the horse's head and tail pivot, in the body's frame: the head and
## neck turn about the shoulder, the tail about the root of the dock.
const HORSE_HEAD_PIVOT := Vector3(0.0, 0.90, -0.40)
const HORSE_TAIL_PIVOT := Vector3(0.0, 1.0, 0.62)

## Where the rump is and how big, so the tail's root can be checked against
## the body it grows out of rather than against a number written twice.
const HORSE_RUMP_CENTRE := Vector3(0.0, 0.90, 0.46)
const HORSE_RUMP_RADIUS := 0.24

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
	#
	# Its length is about a third of the body's, and it is slim at the dock —
	# a hand's width, a fifth of the head's — with the hair filling out below.
	# The first chain was as thick at the root as the head and a half again
	# as long, so the tail looked as big as the head.
	#
	# A pony's is full: the hair thickens below the dock to a hand's width
	# either side, and falls to the hocks.
	78.0, 0.09, 0.022,
	100.0, 0.08, 0.026,
	135.0, 0.12, 0.032,
	158.0, 0.14, 0.06,
	170.0, 0.11, 0.055,
]
const HORSE_TAIL_STRIDE := 3

## A child's pony, with what makes a horse a horse: a deep round barrel, a thick
## arched neck that is one skin with the chest, a blaze on the face, eyes,
## pointed ears, a mane along the crest and a forelock, a full tail, socks and
## rounded hooves — and a saddle on a red cloth with stirrups and a bridle with
## reins that sag, because a horse a child rides should look like one that is
## ridden. Built in parts — body, head, tail,
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
	_horse_reins(tool, [horse_rein_way(-1.0), horse_rein_way(1.0)])
	for i in HORSE_HIPS.size():
		_horse_leg(tool, HORSE_HIPS[i], Vector3.ZERO, hide)

## The barrel, chest, shoulder and rump, the saddle and its reins.
static func _horse_body(tool: SurfaceTool, hide := colour(HORSE)) -> void:
	# The barrel, the chest, the shoulder, the withers and the rump are one
	# skin from the chest to the dock, deeper than it is wide, as a horse is;
	# see HorseNatural.
	HorseNatural.body(tool, hide)
	_horse_saddle(tool)

## The saddle: a red cloth laid over the back with a leather saddle on it, a
## raised pommel and cantle with the seat dipping between, skirts hanging down
## the barrel's sides, and a leather and iron on each side at the child's foot.
##
## It was a stack of boxes on a flat slab, hanging in the air a hand above the
## back and at the withers inside it. Every ring here is put at the back's own
## height at its place (HorseNatural.back_at), so the cloth lies on the curve of
## the back, and the seat's top is HORSE_SADDLE_Y, where the child sits.
static func _horse_saddle(tool: SurfaceTool) -> void:
	var leather := Color(0.36, 0.22, 0.12)
	var blanket := Color(0.80, 0.22, 0.20)
	var hoof := Color(0.15, 0.12, 0.10)
	var cloth_rings: Array = []
	for row: Array in [[-0.24, 0.10], [-0.10, 0.19], [0.14, 0.205], [0.30, 0.12]]:
		var z := float(row[0])
		cloth_rings.append(AnimalLoft.key(Vector3(0.0, HorseNatural.back_at(z) - 0.03, z), float(row[1]), 0.045, 0.09, 3.0))
	var cloth := AnimalLoft.make(cloth_rings, Vector3.UP, 8, 1, 0.02, 0.02)
	cloth.cap_rings = [0.7]
	cloth.paint = AnimalNatural._flat(blanket)
	cloth.emit(tool)
	# Where the top of the saddle is at each place along it, as how far above
	# the cloth, and how wide. The seat's own top is the child's.
	var seat_rings: Array = []
	for row: Array in [[-0.17, 0.07, 0.05], [-0.09, 0.03, 0.10], [0.04, -1.0, 0.13], [0.16, 0.035, 0.14], [0.25, 0.075, 0.12]]:
		var z := float(row[0])
		var top := HORSE_SADDLE_Y if float(row[1]) < 0.0 else HorseNatural.back_at(z) + 0.015 + float(row[1])
		seat_rings.append(AnimalLoft.key(Vector3(0.0, top - 0.03, z), float(row[2]), 0.03, 0.085, 2.8))
	var seat := AnimalLoft.make(seat_rings, Vector3.UP, 8, 1, 0.02, 0.02)
	seat.cap_rings = [0.7]
	seat.paint = AnimalNatural._flat(leather)
	seat.emit(tool)
	for side in PackedFloat32Array([-1.0, 1.0]):
		# Short leathers, a child's: they hang from under the skirt to an iron
		# at the foot, wherever the pose puts it (the shortest of the five
		# children has a leg 0.29 m from hip to ankle), and the iron is round the
		# ball of the foot, a hand's breadth outside the barrel.
		var foot := horse_stirrup(side)
		var from := Vector3(side * 0.17, HORSE_SADDLE_Y - 0.06, foot.z)
		var to := Vector3(foot.x, foot.y - 0.05, foot.z)
		var run := to - from
		var strap := BoxMesh.new()
		strap.size = Vector3(0.025, run.length(), 0.015)
		_add(tool, strap, Transform3D(Basis(Vector3.BACK, atan2(-run.x, run.y)), from + run * 0.5), leather)
		var tread := BoxMesh.new()
		tread.size = Vector3(0.075, 0.014, 0.065)
		_add(tool, tread, Transform3D(Basis(), to + Vector3(0.0, -0.01, 0.0)), hoof)

## The reins, each from the bit back to the rider's hand. A straight line
## between them ran through the neck, which is wider than the rein is far from
## its middle, so each goes round it: from the bit, out past the cheek, along
## the side of the neck, and in over the withers to the hand. A rein is a line
## of corners, `ways` being one for each; they are their own node, because the
## ridden horse's are drawn again at every frame, the bit going with the head
## and the hand with the rider's.
static func _horse_reins(tool: SurfaceTool, ways: Array) -> void:
	var leather := Color(0.36, 0.22, 0.12)
	for way: Array in ways:
		# One thin tube through all the corners, rather than a cylinder to a
		# leg of it: a few joined pieces share their rings, so a bend is a bend
		# and not a gap, and a rein is a fifth of the triangles.
		var keys: Array = []
		for corner: Vector3 in way:
			keys.append(AnimalLoft.key(corner, 0.009, 0.009, 0.009))
		var rein := AnimalLoft.make(keys, Vector3.UP, 3, 1, 0.0, 0.0)
		rein.paint = AnimalNatural._flat(leather)
		rein.emit(tool)

## The ridden horse's reins as they are now: the bit turned with the head by
## `head_turn` (about X, as the head node is) and the hands moved by `sway`.
static func horse_reins_mesh(head_turn: float, sway: Vector3) -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ways: Array = []
	var turn := Basis(Vector3.RIGHT, head_turn)
	for side in PackedFloat32Array([-1.0, 1.0]):
		var way := horse_rein_way(side)
		for corner in 2:
			way[corner] = turn * (way[corner] - HORSE_HEAD_PIVOT) + HORSE_HEAD_PIVOT
		way[way.size() - 1] += sway
		ways.append(way)
	_horse_reins(tool, ways)
	tool.generate_normals()
	tool.set_material(AnimalKinds.fur_material())
	return tool.commit()

## The corners of one rein, from the bit to the pommel, in the body's frame;
## `side` is -1 for the left rein and 1 for the right. Read by the drawing and
## by the checks, which hold it outside the neck.
static func horse_rein_way(side: float) -> Array[Vector3]:
	# Out past the cheek, and then slack: the rein hangs in a curve between
	# the bit and the hand, a hand's breadth outside the neck at its lowest, and
	# rises to the hand over the withers.
	return [
		Vector3(side * 0.08, 1.20, -1.22), Vector3(side * 0.17, 1.20, -1.06),
		Vector3(side * 0.20, 1.16, -0.86), Vector3(side * 0.20, 1.18, -0.62),
		Vector3(side * 0.15, 1.25, -0.40), horse_rein_hand(side),
	]

## Where a rider's foot is in the stirrup, in the body's frame: the ankle, as the
## pose puts it (SeatPose), which is where the iron is drawn round and the leather
## runs to.
static func horse_stirrup(side: float) -> Vector3:
	var foot: Vector3 = SeatPose.POSES[HORSE]["foot"]
	return Vector3(side * absf(foot.x), HORSE_SADDLE_Y + foot.y, foot.z)

## Where a rider's hand holds a rein, in the body's frame: the grip the seat's
## pose gives (SeatPose, written about the saddle), so that the rein ends in the
## hand and not at the pommel a hand's breadth below it.
static func horse_rein_hand(side: float) -> Vector3:
	var grip: Vector3 = SeatPose.POSES[HORSE]["hand"]
	return Vector3(side * absf(grip.x), HORSE_SADDLE_Y + grip.y, grip.z)

## The neck and head, with the mane, the forelock, the ears and the face,
## relative to the shoulder they pivot about.
static func _horse_head(tool: SurfaceTool, pivot: Vector3, hide := colour(HORSE)) -> void:
	HorseNatural.head(tool, pivot, hide)

## The tail: a loft down the chain of joints below, ending in a switch of hair,
## relative to where it joins the rump.
static func _horse_tail(tool: SurfaceTool, pivot: Vector3, hide := colour(HORSE)) -> void:
	HorseNatural.tail(tool, pivot, hide)

## Every joint of the tail, from its root outwards, in the tail's own frame —
## the root is the origin. Read by the drawing above and by the checks, so the
## shape cannot be asserted against numbers that only the check believes.
static func horse_tail_joints() -> PackedVector3Array:
	var out := PackedVector3Array([Vector3.ZERO])
	var at := Vector3.ZERO
	var i := 0
	while i < HORSE_TAIL_CHAIN.size():
		var tilt := deg_to_rad(HORSE_TAIL_CHAIN[i])
		var length := HORSE_TAIL_CHAIN[i + 1]
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
	var key := "%s/%s" % [part, hide.to_html()]
	if _horse_meshes.has(key):
		return _horse_meshes[key]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	match part:
		"head":
			_horse_head(tool, HORSE_HEAD_PIVOT, hide)
		"tail":
			_horse_tail(tool, HORSE_TAIL_PIVOT, hide)
		"reins":
			_horse_reins(tool, [horse_rein_way(-1.0), horse_rein_way(1.0)])
		_:
			_horse_body(tool, hide)
	tool.generate_normals()
	tool.set_material(AnimalKinds.fur_material())
	_horse_meshes[key] = tool.commit()
	return _horse_meshes[key]

## Where the horse's four legs hang from, in the body's frame: the hips and
## shoulders, at the height the leg mesh pivots from. Order: front-left,
## front-right, hind-left, hind-right.
const HORSE_HIPS: Array[Vector3] = [
	Vector3(-0.115, 0.80, -0.40), Vector3(0.115, 0.80, -0.40),
	Vector3(-0.115, 0.80, 0.46), Vector3(0.115, 0.80, 0.46),
]

## One horse leg, built with its pivot at the hip so that turning the node
## about X swings the leg forward and back. The legs used to be part of the
## baked horse and stood stiff at a gallop, which from the saddle read as a
## horse on wheels.
##
## Four of them now, by `index` into `HORSE_HIPS`: a front leg is not a hind
## leg, and each leans in at the top towards the middle of the horse, so a left
## leg is the mirror of a right one. Kept, by coat, since every horse of one
## coat can wear the same legs.
static func horse_leg(hide := colour(HORSE), index := 0) -> Mesh:
	var key := "leg%d/%s" % [index, hide.to_html()]
	if _horse_meshes.has(key):
		return _horse_meshes[key]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Relative to its own hip, whichever hip it is drawn from.
	_horse_leg(tool, HORSE_HIPS[index], HORSE_HIPS[index], hide)
	tool.generate_normals()
	tool.set_material(AnimalKinds.fur_material())
	_horse_meshes[key] = tool.commit()
	return _horse_meshes[key]

## Horse parts already built, by part and coat: twenty horses wear five coats.
static var _horse_meshes: Dictionary = {}

## A leg hanging from `hip`, drawn in coordinates relative to `pivot`: a heavy
## upper leg that lies within the flank, a knee, a slender cannon bone, a
## fetlock and a hoof, as one skin. A horse's leg is thick at the top and thin
## at the bottom by a factor of two, and that taper — with a joint showing
## where it changes — is most of what tells a leg from a table leg.
static func _horse_leg(tool: SurfaceTool, hip: Vector3, pivot: Vector3, hide := colour(HORSE)) -> void:
	HorseNatural.leg(tool, hip.z < 0.0, hip, pivot, hide, signf(hip.x))

## A mount as a node: a body, and for the horse four legs hung from the hips
## that Mounts swings as it moves. The mesh alone is not enough for something
## that has to move its legs.
static func build_node(kind: StringName) -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = bicycle_part_mesh(BikePart.FRAME) if kind_of(kind) == BICYCLE else build_mesh(kind)
	root.add_child(body)
	if kind_of(kind) == BICYCLE:
		_hang_the_bicycle_parts(root)
	elif kind_of(kind) == MOTORCYCLE:
		var tyre := two_wheeler_wheel_mesh(kind)
		var spots := wheel_spots(kind)
		for i in spots.size():
			var wheel := MeshInstance3D.new()
			wheel.name = "Wheel%d" % i
			wheel.mesh = tyre
			wheel.position = spots[i]
			root.add_child(wheel)
	if kind_of(kind) == QUAD:
		# Four wheels that turn. They were part of the one mesh, so a quad
		# crossing a meadow slid along on tyres that never moved — which is
		# the first thing anybody notices about a machine that is supposed to
		# be rolling.
		var wheel_mesh := quad_wheel_mesh()
		for i in QUAD_WHEELS.size():
			var wheel := MeshInstance3D.new()
			wheel.name = "Wheel%d" % i
			wheel.mesh = wheel_mesh
			wheel.position = QUAD_WHEELS[i] * QUAD_SCALE
			root.add_child(wheel)
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
		var reins := MeshInstance3D.new()
		reins.name = "Reins"
		reins.mesh = horse_part("reins", hide)
		body.add_child(reins)
		for i in HORSE_HIPS.size():
			var leg := MeshInstance3D.new()
			leg.name = "Leg%d" % i
			leg.mesh = horse_leg(hide, i)
			leg.position = HORSE_HIPS[i]
			body.add_child(leg)
	return root

## The bicycle's own moving parts, hung on the ridden body: the cranks at the
## bottom bracket, and the steering at the head tube, so that the bars and the
## forks go over about it; the front wheel is turned with them by Mounts.
static func _hang_the_bicycle_parts(root: Node3D) -> void:
	var cranks := MeshInstance3D.new()
	cranks.name = "Cranks"
	cranks.mesh = bicycle_part_mesh(BikePart.CRANKS)
	cranks.position = BICYCLE_BRACKET
	root.add_child(cranks)
	var steer := Node3D.new()
	steer.name = "Steer"
	steer.position = BICYCLE_HEAD_LOW
	var bars := MeshInstance3D.new()
	bars.name = "Bars"
	bars.mesh = bicycle_part_mesh(BikePart.STEER)
	steer.add_child(bars)
	root.add_child(steer)
	# Both wheels stay the body's own children, like every other wheel here;
	# the front one is moved round the head tube by Mounts as the bars go over
	# (see Mounts._turn_the_wheels), in step with the steering node.
	var tyre := two_wheeler_wheel_mesh(BICYCLE)
	for i in BICYCLE_WHEELS.size():
		var wheel := MeshInstance3D.new()
		wheel.name = "Wheel%d" % i
		wheel.mesh = tyre
		wheel.position = BICYCLE_WHEELS[i]
		root.add_child(wheel)

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

	var back := MOTORCYCLE_WHEELS[1]
	var front := MOTORCYCLE_WHEELS[0]
	# The wheels are not drawn here. They are nodes of their own, so they turn
	# — a machine crossing a meadow on tyres that never move is the first
	# thing anybody notices.

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
	# Foot pegs high on the frame, where a child's short leg reaches (they were
	# the grown rider's, down by the exhaust): the sole rests on each, 0.9 up.
	for side in PackedFloat32Array([-1.0, 1.0]):
		var peg := BoxMesh.new()
		peg.size = Vector3(0.14, 0.03, 0.09)
		_add(tool, peg, Transform3D(Basis(), Vector3(side * 0.24, 0.88, 0.20)), chrome)
		_tube(tool, Vector3(side * 0.12, 0.9, 0.2), Vector3(side * 0.18, 0.88, 0.2), 0.03, steel)
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
	# The head tube is 0.08 further back than a grown rider's, which brings the
	# grips to within a child's arm of a child sitting at the front of the saddle.
	var head_low := Vector3(0.0, 0.78, -0.50)
	var head_high := Vector3(0.0, 1.12, -0.42)
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

	# Two thwarts to sit on. The one a child rows from is at 0.1, level with the
	# oars and under the child's own feet, where they stand when they step in;
	# it was at 0.65, a long slide aft of the place they were put.
	for z in BOAT_THWARTS:
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
		# Tipped 22 degrees, not 12: the handles come up to a child's hands as
		# they sit (0.34 over the boat's origin at 0.22 out), and the blades
		# go a little into the water, which is what an oar is for.
		var lay := Basis(Vector3.FORWARD, side * deg_to_rad(90.0 + 22.0))
		_add(tool, oar, Transform3D(lay, Vector3(side * 0.75, top + 0.08, BOAT_OARS_Z)), wood)
		var blade := BoxMesh.new()
		blade.size = Vector3(0.5, 0.03, 0.16)
		_add(tool, blade, Transform3D(lay * Basis(Vector3.FORWARD, deg_to_rad(-90.0)), Vector3(side * 1.75, top - 0.32, BOAT_OARS_Z)), wood)

## A spoked wheel standing upright: tyre, rim, hub and spokes, at a given
## place along the machine. Every wheel in this file is built here, so a
## bicycle's and a motorcycle's differ in their numbers rather than in their
## code — and spokes are what stop a wheel reading as a black doughnut.
## Scale everything already in a surface about the origin.
##
## Used to grow a machine whole after it is drawn: changing forty numbers by
## hand is how proportions drift, and the proportions are the machine.
static func _grow(tool: SurfaceTool, by: float) -> void:
	var mesh := tool.commit()
	var faces := mesh.get_faces()
	tool.clear()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var arrays := mesh.surface_get_arrays(0)
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for i in faces.size():
		if i < colours.size():
			tool.set_color(colours[i])
		tool.add_vertex(faces[i] * by)

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

	# The wheels are not drawn here: they are their own nodes, so they can
	# turn. What is drawn is what holds them on.
	for side: float in [-1.0, 1.0]:
		for end: float in [-1.0, 1.0]:
			var arm := BoxMesh.new()
			arm.size = Vector3(0.36, 0.09, 0.12)
			_add(
				tool, arm,
				Transform3D(Basis(), Vector3(side * 0.34, QUAD_AXLE, end * 0.68)),
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
		# Raised from 0.42 to 0.66: the boards were half a metre under the
		# seat, further than a child's leg is long.
		var board := BoxMesh.new()
		board.size = Vector3(0.3, 0.06, 0.66)
		_add(tool, board, Transform3D(Basis(), Vector3(side * 0.44, 0.66, 0.0)), dark)

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
		Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-16.0)), Vector3(0.0, 0.98, -0.36)),
		metal
	)
	var bars := CylinderMesh.new()
	bars.top_radius = 0.032
	bars.bottom_radius = 0.032
	bars.height = 0.9
	bars.radial_segments = 6
	_add(
		tool, bars,
		Transform3D(Basis(Vector3.BACK, deg_to_rad(90.0)), Vector3(0.0, 1.18, -0.40)),
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
			Transform3D(Basis(Vector3.BACK, deg_to_rad(90.0)), Vector3(side * 0.36, 1.18, -0.40)),
			seat_colour
		)
		var lever := BoxMesh.new()
		lever.size = Vector3(0.14, 0.025, 0.05)
		_add(
			tool, lever,
			Transform3D(Basis(Vector3.UP, side * deg_to_rad(16.0)), Vector3(side * 0.24, 1.14, -0.48)),
			metal
		)
	# A crossbar pad, the way a quad's bars are braced.
	var pad := BoxMesh.new()
	pad.size = Vector3(0.22, 0.1, 0.1)
	_add(tool, pad, Transform3D(Basis(), Vector3(0.0, 1.13, -0.36)), paint.lightened(0.2))

	# A bumper across the nose and a warm stripe down the tank. The quad is
	# purple and black, and against grass and sky that is two dark shapes at
	# phone size; a tube of bright steel across the front gives the nose an edge,
	# and the orange stripe (red over blue, green over blue) is what the eye
	# finds first, on the one colour nothing else in the valley wears.
	var bumper := Color(0.80, 0.82, 0.86)
	var stripe := Color(0.96, 0.58, 0.16)
	for post: float in [-1.0, 1.0]:
		var upright := CylinderMesh.new()
		upright.top_radius = 0.025
		upright.bottom_radius = 0.025
		upright.height = 0.3
		upright.radial_segments = 6
		_add(tool, upright, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-70.0)), Vector3(post * 0.32, 0.62, -1.28)), bumper)
	var bumper_bar := CylinderMesh.new()
	bumper_bar.top_radius = 0.03
	bumper_bar.bottom_radius = 0.03
	bumper_bar.height = 0.74
	bumper_bar.radial_segments = 6
	_add(tool, bumper_bar, Transform3D(Basis(Vector3.BACK, deg_to_rad(90.0)), Vector3(0.0, 0.62, -1.42)), bumper)
	var tank_stripe := BoxMesh.new()
	tank_stripe.size = Vector3(0.1, 0.02, 0.38)
	_add(tool, tank_stripe, Transform3D(Basis(), Vector3(0.0, 0.945, -0.3)), stripe)
	var seat_stripe := BoxMesh.new()
	seat_stripe.size = Vector3(0.1, 0.02, 0.56)
	_add(tool, seat_stripe, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-5.0)), Vector3(0.0, 0.875, 0.14)), stripe)

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

## Where each two-wheeler's wheels are, and how big. Front first.
const BICYCLE_WHEELS: Array[Vector3] = [
	Vector3(0.0, 0.40, -0.66), Vector3(0.0, 0.40, 0.66),
]
const BICYCLE_WHEEL_RADIUS := 0.40
const MOTORCYCLE_WHEELS: Array[Vector3] = [
	Vector3(0.0, 0.42, -0.78), Vector3(0.0, 0.42, 0.74),
]
const MOTORCYCLE_WHEEL_RADIUS := 0.42

## How big the wheels of whatever this is are, for working out how fast they
## should be going round. Nought for anything that has none.
static func wheel_radius(kind: StringName) -> float:
	match kind_of(kind):
		BICYCLE:
			return BICYCLE_WHEEL_RADIUS
		MOTORCYCLE:
			return MOTORCYCLE_WHEEL_RADIUS
		QUAD:
			return QUAD_WHEEL_RADIUS * QUAD_SCALE
		_:
			return 0.0

## Where the wheels of whatever this is sit, in its own frame.
static func wheel_spots(kind: StringName) -> Array[Vector3]:
	match kind_of(kind):
		BICYCLE:
			return BICYCLE_WHEELS
		MOTORCYCLE:
			return MOTORCYCLE_WHEELS
		QUAD:
			var out: Array[Vector3] = []
			for spot in QUAD_WHEELS:
				out.append(spot * QUAD_SCALE)
			return out
		_:
			return [] as Array[Vector3]

## One wheel of a two-wheeler, drawn on its own so it can be turned. A
## motorcycle's is fatter and has more spokes than a bicycle's: the same wheel,
## a different machine, which is exactly how the two should differ.
static func two_wheeler_wheel_mesh(kind: StringName) -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	if kind_of(kind) == MOTORCYCLE:
		_wheel(
			tool, Vector3.ZERO, MOTORCYCLE_WHEEL_RADIUS, 0.12, 8,
			Color(0.10, 0.10, 0.11), Color(0.72, 0.74, 0.78)
		)
	else:
		_wheel(
			tool, Vector3.ZERO, BICYCLE_WHEEL_RADIUS, 0.065, 10,
			Color(0.13, 0.13, 0.15), Color(0.80, 0.82, 0.86)
		)
	tool.generate_normals()
	tool.set_material(AnimalKinds.fur_material())
	return tool.commit()

## Where a quad's four wheels are, how big they are, and how fat.
##
## Balloon tyres: two and a half times the section they had, which is what a
## quad runs and what stops the machine reading as a go-kart. A torus cannot
## simply be made fatter — its tube is the gap between its two radii, and past
## a point the inner radius goes negative — so a fat tyre here is three tori
## laid side by side across the hub with the lugs spanning all of them.
const QUAD_WHEEL_RADIUS := 0.4
## One radius up, so the tyre touches the ground rather than going into it: it
## was 0.38, which sank every wheel two centimetres.
const QUAD_AXLE := QUAD_WHEEL_RADIUS
const QUAD_WHEEL_HALF_WIDTH := 0.21
const QUAD_WHEELS: Array[Vector3] = [
	Vector3(-0.56, QUAD_AXLE, -0.68), Vector3(0.56, QUAD_AXLE, -0.68),
	Vector3(-0.56, QUAD_AXLE, 0.68), Vector3(0.56, QUAD_AXLE, 0.68),
]

static func quad_wheel_mesh() -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rubber := Color(0.11, 0.11, 0.12)
	var tread := Color(0.16, 0.16, 0.17)
	var metal := Color(0.62, 0.64, 0.68)
	for slice in 3:
		var across := (float(slice) - 1.0) * QUAD_WHEEL_HALF_WIDTH * 0.8
		_wheel(
			tool, Vector3(across, 0.0, 0.0) * QUAD_SCALE,
			QUAD_WHEEL_RADIUS * QUAD_SCALE, 0.15 * QUAD_SCALE, 5, rubber, metal
		)
	# The lugs, spanning the whole width of the tyre.
	for lug in 12:
		var angle := TAU * float(lug) / 12.0
		var knob := BoxMesh.new()
		knob.size = Vector3(
			QUAD_WHEEL_HALF_WIDTH * 2.1, 0.1, 0.08
		) * QUAD_SCALE
		_add(
			tool, knob,
			Transform3D(
				Basis(Vector3.RIGHT, angle),
				Vector3(0.0, cos(angle), sin(angle)) * (QUAD_WHEEL_RADIUS - 0.04) * QUAD_SCALE
			),
			tread
		)
	tool.generate_normals()
	tool.set_material(AnimalKinds.fur_material())
	return tool.commit()

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
static func _bicycle(tool: SurfaceTool, part := BikePart.ALL) -> void:
	var whole := part == BikePart.ALL
	var frame: Color = colour(BICYCLE)
	var metal := Color(0.80, 0.82, 0.86)
	var grip := Color(0.18, 0.18, 0.20)
	# What a child's hand and seat touch is warmer than the steel: cream grips
	# and a tan saddle read against both the red frame and a pale sky, where
	# near-black ones were two dark specks at phone size.
	var cream := Color(0.94, 0.88, 0.70)
	var leather := Color(0.62, 0.38, 0.20)

	var back := BICYCLE_WHEELS[1]
	var front := BICYCLE_WHEELS[0]
	# Drawn as their own nodes, like every other wheel here.

	# The diamond: bottom bracket low in the middle, seat tube up from it, down
	# tube forward to the head tube, top tube between the two.
	var bracket := BICYCLE_BRACKET
	# A child's bicycle, since a child's is the one it is: the saddle 0.55 up
	# (it was 1.22, a metre over the pedals, where a child's leg is 0.4), the
	# head tube and bars brought back to where a child's arm reaches, and the
	# top tube low and sloping to the seat tube, a step-through frame, so
	# that nothing of the diamond is above the hips: a rider's body went through
	# the old top tube and head tube.
	var head_low := BICYCLE_HEAD_LOW
	var head_high := BICYCLE_HEAD_HIGH
	var seat_top := Vector3(0.0, 0.43, 0.18)
	if whole or part == BikePart.FRAME:
		_tube(tool, bracket, head_low, 0.06, frame)
		_tube(tool, bracket, seat_top, 0.055, frame)
		_tube(tool, head_low + Vector3(0.0, 0.03, 0.0), seat_top + Vector3(0.0, 0.0, -0.02), 0.05, frame)
		_tube(tool, head_low, head_high, 0.065, frame)
		# Chainstays and seatstays: the triangle behind, which is the half of a
		# bicycle everyone forgets and the half that makes it read as one.
		for side in PackedFloat32Array([-1.0, 1.0]):
			_tube(tool, bracket, back + Vector3(side * 0.06, 0.0, 0.0), 0.034, frame)
			_tube(tool, seat_top, back + Vector3(side * 0.06, 0.0, 0.0), 0.03, frame)
		# The chain, a dark line from the chainring to the rear hub on the
		# right-hand side: the one part of the drive that is still when the
		# cranks turn, and what makes the cranks read as driving something.
		_tube(
			tool, bracket + Vector3(0.07, 0.07, 0.0),
			back + Vector3(0.05, 0.05, 0.0), 0.014, grip
		)
		# A red reflector behind the saddle on a short bracket: what a child sees
		# from behind, and the one touch of red-on-red that says "bicycle" from
		# the back. (Mudguards were tried here and read as stray red rails
		# floating over the wheels at phone size, so they are not drawn.)
		_tube(tool, seat_top, Vector3(0.0, 0.46, 0.34), 0.02, metal)
		var reflector := BoxMesh.new()
		reflector.size = Vector3(0.08, 0.08, 0.03)
		_add(tool, reflector, Transform3D(Basis(), Vector3(0.0, 0.46, 0.36)), Color(0.92, 0.18, 0.14))
		# Saddle on its post: a nose and a seat, not a brick.
		_tube(tool, seat_top, seat_top + Vector3(0.0, 0.07, 0.0), 0.034, metal)
		var seat := BoxMesh.new()
		seat.size = Vector3(0.19, 0.065, 0.28)
		_add(tool, seat, Transform3D(Basis(), seat_top + Vector3(0.0, 0.09, 0.03)), leather)
		var nose := BoxMesh.new()
		nose.size = Vector3(0.08, 0.055, 0.17)
		_add(tool, nose, Transform3D(Basis(), seat_top + Vector3(0.0, 0.095, -0.14)), leather)

	if whole or part == BikePart.CRANKS:
		# Chainring and cranks, with a pedal on each. Their own node when the
		# bicycle is ridden, so they can go round with the wheels (see
		# Mounts._turn_the_wheels); in the shop they are part of the one mesh.
		if part == BikePart.CRANKS:
			_origin = bracket
		var ring := CylinderMesh.new()
		ring.top_radius = 0.13
		ring.bottom_radius = 0.13
		ring.height = 0.02
		ring.radial_segments = 12
		_add(tool, ring, Transform3D(Basis(Vector3.FORWARD, deg_to_rad(90.0)), bracket + Vector3(0.07, 0.0, 0.0)), metal)
		# Three arms of a spider, so the ring is seen to turn.
		for spoke in 3:
			var arm := BoxMesh.new()
			arm.size = Vector3(0.012, 0.02, 0.26)
			_add(
				tool, arm,
				Transform3D(Basis(Vector3.RIGHT, TAU * float(spoke) / 3.0), bracket + Vector3(0.07, 0.0, 0.0)),
				grip
			)
		# At rest the left pedal is forward and the right one back, which is
		# where RigMotion puts the feet at a pedal phase of nought.
		for side in PackedFloat32Array([-1.0, 1.0]):
			var crank := BoxMesh.new()
			crank.size = Vector3(0.035, 0.05, PEDAL_REACH)
			_add(tool, crank, Transform3D(
				Basis(), bracket + Vector3(side * 0.09, 0.0, side * PEDAL_REACH * 0.5)
			), metal)
			var pedal := BoxMesh.new()
			pedal.size = Vector3(0.09, 0.03, 0.14)
			_add(tool, pedal, Transform3D(
				Basis(), bracket + Vector3(side * 0.14, 0.0, side * PEDAL_REACH)
			), grip)
		_origin = Vector3.ZERO

	if whole or part == BikePart.STEER:
		# Everything that goes over with the handlebars: the forks, the stem, bars, grips, lamp and bell. Hung on the head tube
		# in the ridden bicycle and turned about its axis.
		if part == BikePart.STEER:
			_origin = head_low
		for side in PackedFloat32Array([-1.0, 1.0]):
			# Forks down to the front axle.
			_tube(tool, head_low, front + Vector3(side * 0.06, 0.0, 0.0), 0.036, metal)
		# Bars on a stem, with grips at the ends.
		_tube(tool, head_high, head_high + Vector3(0.0, 0.08, -0.03), 0.042, metal)
		var bars_at := head_high + Vector3(0.0, 0.08, -0.03)
		_tube(tool, bars_at + Vector3(-0.28, 0.0, 0.0), bars_at + Vector3(0.28, 0.0, 0.0), 0.03, metal)
		for side in PackedFloat32Array([-1.0, 1.0]):
			_tube(
				tool, bars_at + Vector3(side * 0.18, 0.0, 0.0),
				bars_at + Vector3(side * 0.29, 0.0, 0.04), 0.04, cream
			)
		# A lamp on the front of the head tube, which is what a bicycle looks
		# back at you with, and a bell, because every child's bicycle has one.
		var lamp := CylinderMesh.new()
		lamp.top_radius = 0.045
		lamp.bottom_radius = 0.045
		lamp.height = 0.05
		lamp.radial_segments = 8
		_add(
			tool, lamp,
			Transform3D(Basis(Vector3.RIGHT, deg_to_rad(90.0)), head_high + Vector3(0.0, 0.0, -0.1)),
			Color(0.98, 0.95, 0.76)
		)
		var bell := CylinderMesh.new()
		bell.top_radius = 0.035
		bell.bottom_radius = 0.045
		bell.height = 0.045
		bell.radial_segments = 8
		_add(tool, bell, Transform3D(Basis(), bars_at + Vector3(-0.1, 0.05, 0.0)), Color(0.90, 0.74, 0.30))
		_origin = Vector3.ZERO

## Which part of the bicycle a mesh is for: all of it (the shop floor), what is
## left once the cranks and the steering are taken off (the ridden body), the
## cranks, or the steering.
enum BikePart { ALL, FRAME, CRANKS, STEER }

## Where the bottom bracket is, and the two ends of the head tube, in the
## bicycle's own frame: what the cranks and the steering are hung from.
const BICYCLE_BRACKET := Vector3(0.0, 0.34, 0.16)
const BICYCLE_HEAD_LOW := Vector3(0.0, 0.56, -0.46)
const BICYCLE_HEAD_HIGH := Vector3(0.0, 0.80, -0.40)

## How long a crank is, which is also the radius of the circle a rider's feet go
## round (SeatPose's `pedal_radius`).
const PEDAL_REACH := 0.12

## The mesh of one part of the bicycle, for build_node.
static func bicycle_part_mesh(part: BikePart) -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_bicycle(tool, part)
	tool.generate_normals()
	tool.set_material(AnimalKinds.fur_material())
	return tool.commit()

## The line the handlebars turn about: up the head tube, leaning back.
static func bicycle_steering_axis() -> Vector3:
	return (BICYCLE_HEAD_HIGH - BICYCLE_HEAD_LOW).normalized()

## How many turns of the cranks to one turn of the wheel: the gearing. A child's
## single speed, a little under one to two, so that at a bicycle's top speed the
## cranks go round about one and a half times a second and a child can see
## each pedal.
const PEDAL_RATIO := 0.44

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

## Subtracted from everything `_add` places, so that a part drawn to be hung on
## a pivot (the bicycle's cranks and steering) is built round that pivot.
static var _origin := Vector3.ZERO

static func _add(tool: SurfaceTool, source: PrimitiveMesh, transform: Transform3D, colour: Color) -> void:
	transform.origin -= _origin
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
