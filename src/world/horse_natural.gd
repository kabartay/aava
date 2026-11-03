class_name HorseNatural
extends RefCounted

## The horse's body, neck and head, mane, tail and legs as smooth painted skins,
## made with the same loft as the animals (see AnimalLoft).
##
## It used to be a stack of spheres and cylinders: a chest, a shoulder, a
## withers, a barrel and a rump each a separate ball, a neck that was a tube
## and a head that was a box with a ball on the end. `MountKinds` still owns
## everything that has to stay put for the rider — the saddle, the pivots, the
## hips and the tail's chain of joints — and this file draws only the animal.
## Everything is written in metres, in the pony's own frame: facing -Z, its feet
## on y = 0, its withers 1.16 m up.
##
## A pony, not a horse. It was drawn for a grown rider and then made a fifth
## bigger, so that a child sat 2.2 m up on a beast whose withers were over
## their head, like a toy on a shelf. A child's pony stands about half that:
## the saddle is at a child's chin when they stand beside it, the body is short
## and deep, the neck thick and the legs strong rather than long.

const S := 1.0

static func _rings(rows: Array) -> Array:
	return AnimalNatural._rings(S, rows)

## The barrel's loft, before it is painted.
static func _barrel() -> AnimalLoft:
	return AnimalLoft.make(AnimalNatural._section(S, [
		[-0.66, 1.00, 0.60, 0.13], [-0.50, 1.13, 0.52, 0.19], [-0.30, 1.16, 0.47, 0.215],
		[-0.05, 1.07, 0.47, 0.225], [0.22, 1.075, 0.51, 0.225], [0.44, 1.10, 0.60, 0.21],
		[0.62, 1.05, 0.69, 0.17],
	]), Vector3.UP, 10, 2, 0.1 * S, 0.1 * S)

## How high the skin of the back is along the middle line at `z`, so that the
## saddle and its cloth are laid on the back as it is drawn rather than at a
## height written down beside it.
static func back_at(z: float) -> float:
	var loft := _barrel()
	var low := 0.0
	var high := float(loft.keys.size() - 1)
	for _step in 24:
		var middle := (low + high) * 0.5
		if (loft.at(middle)["c"] as Vector3).z < z:
			low = middle
		else:
			high = middle
	return loft.surface(low, 0.0).y

## The barrel, shoulders, withers and rump as one body from the chest to the
## dock.
static func body(tool: SurfaceTool, hide: Color) -> void:
	# A pony is deep and not wide: the chest drops lowest at the girth, the
	# belly tucks up a little towards the flank, the back runs level from the
	# withers to a rounded croup and the rump turns down to the dock. The
	# barrel is 0.45 m across at the ribs, deep and round, so that a child's
	# legs can hang down outside it. The breast carries up into the neck (see
	# `head`, whose first rings lie inside it), so that the chest rises to the
	# withers and the crest goes on up from them without a notch.
	var loft := _barrel()
	loft.cap_rings = [0.7]
	loft.paint = func(_p: Vector3, _along: float, a: float) -> Color:
		return AnimalNatural._shade(hide, a, 0.05, 0.1)
	loft.emit(tool)

## The neck and head with the mane, the forelock, the ears and the face, drawn
## about `pivot`, the foot of the neck.
static func head(tool: SurfaceTool, pivot: Vector3, hide: Color) -> void:
	var dark := hide.darkened(0.3)
	# The hair is darker than the hide, so a mane shows against a neck.
	var hair := hide.darkened(0.55)
	var pale := Color(0.93, 0.90, 0.84)
	var mine := SurfaceTool.new()
	mine.begin(Mesh.PRIMITIVE_TRIANGLES)
	# One skin from the chest to the muzzle: the neck starts inside the breast,
	# as thick as the chest is there, and is thick all the way up, a pony's
	# being as deep as it is long; it arches to the poll, and the head is
	# carried down from it to a soft, square muzzle. The first rings lie inside
	# the body so that no edge of the neck shows on the chest. The first ring's
	# top is below the back's (1.07 against 1.13 m): it used to be level with it
	# (1.16 m), so the neck ran flush along the back and drew a crease where the
	# two skins met at the withers.
	var skull := AnimalLoft.make(_rings([
		[0.0, 0.90, -0.22, 0.17, 0.17, 0.26], [0.0, 1.00, -0.46, 0.165, 0.20, 0.22],
		[0.0, 1.15, -0.64, 0.155, 0.20, 0.20], [0.0, 1.28, -0.76, 0.14, 0.18, 0.18],
		[0.0, 1.39, -0.88, 0.13, 0.15, 0.19, 2.2], [0.0, 1.36, -1.04, 0.11, 0.12, 0.16, 2.3],
		[0.0, 1.27, -1.19, 0.08, 0.095, 0.10, 2.4], [0.0, 1.20, -1.30, 0.078, 0.08, 0.08, 2.6],
	]), Vector3.UP, 10, 1, 0.0, 0.05 * S)
	var nose := AnimalNatural._nose(skull, 0.05 * S)
	var tip: Vector3 = nose["tip"]
	skull.paint = func(p: Vector3, _along: float, a: float) -> Color:
		# Shaded as the body is, so that no change of tone marks where the
		# neck comes out of the chest.
		var c := AnimalNatural._shade(hide, a, 0.05, 0.1)
		# A white blaze down the face, and a soft pale muzzle.
		var face := smoothstep(-1.1 * S, -1.3 * S, p.z) * smoothstep(0.03 * S, 0.015 * S, absf(p.x)) * smoothstep(0.3, 0.8, cos(a))
		c = c.lerp(pale, face)
		return c.lerp(hide.lightened(0.15), smoothstep(0.2 * S, 0.08 * S, p.distance_to(tip)))
	skull.emit(mine)
	AnimalLoft.ball(mine, tip - (nose["T"] as Vector3) * 0.02 * S, Vector3(0.1, 0.04, 0.04) * S, dark.darkened(0.3), 5)
	for side in PackedFloat32Array([-1.0, 1.0]):
		AnimalNatural._eye(mine, skull, 4.8, side * 1.35, 0.033 * S, Color(0.08, 0.05, 0.05), false)
		# Ears: upright, pointed, a little forward.
		var ear_at := skull.surface(4.0, side * 0.75) + Vector3(-side * 0.01, 0.0, 0.0) * S
		AnimalNatural._leaf(mine, ear_at, [Vector3.ZERO, Vector3(side * 0.012, 0.07, -0.008) * S, Vector3(side * 0.0, 0.045, -0.015) * S],
			[0.05 * S, 0.045 * S, 0.012 * S], [0.018 * S, 0.014 * S, 0.006 * S], Vector3(0.0, 0.0, 1.0), 0.02 * S, 4,
			AnimalNatural._flat(dark))
	# The bridle, on the head and so turning with it: a browband across the
	# forehead below the ears and a noseband round the muzzle, in leather.
	var leather := Color(0.30, 0.18, 0.10)
	for band: Array in [[4.4, 0.012], [6.35, 0.014]]:
		var ring := skull.at(float(band[0]))
		var centre: Vector3 = ring["c"]
		var along: Vector3 = ring["T"]
		var strap := AnimalLoft.make([
			AnimalLoft.key(centre - along * float(band[1]), float(ring["rx"]) * 1.06, float(ring["ru"]) * 1.06, float(ring["rd"]) * 1.06, float(ring["n"])),
			AnimalLoft.key(centre + along * float(band[1]), float(ring["rx"]) * 1.06, float(ring["ru"]) * 1.06, float(ring["rd"]) * 1.06, float(ring["n"])),
		], Vector3.UP, 8, 1, 0.0, 0.0)
		strap.paint = AnimalNatural._flat(leather)
		strap.emit(mine)
	# The mane: a ridge of hair along the crest from the poll to the withers.
	var mane := AnimalLoft.make(_rings([
		[0.0, 1.52, -0.90, 0.04, 0.05, 0.05], [0.0, 1.42, -0.76, 0.055, 0.06, 0.08],
		[0.0, 1.31, -0.64, 0.06, 0.06, 0.09], [0.0, 1.19, -0.52, 0.06, 0.06, 0.09],
		[0.0, 1.09, -0.40, 0.05, 0.05, 0.07],
	]), Vector3.UP, 6, 1, 0.03 * S, 0.03 * S)
	mane.cap_rings = [0.7]
	mane.paint = AnimalNatural._flat(hair)
	mane.emit(mine)
	# The forelock, falling between the ears over the brow.
	var forelock := AnimalLoft.make(_rings([
		[0.0, 1.56, -0.90, 0.03, 0.03, 0.03], [0.0, 1.53, -1.00, 0.03, 0.03, 0.03],
		[0.0, 1.47, -1.08, 0.025, 0.025, 0.025],
	]), Vector3.UP, 5, 1, 0.0, 0.025 * S)
	forelock.cap_rings = [0.7]
	forelock.paint = AnimalNatural._flat(hair)
	forelock.emit(mine)
	mine.generate_normals()
	tool.append_from(mine.commit(), 0, Transform3D(Basis(), -pivot))

## The tail, from its root on the rump down the chain of joints that `MountKinds`
## keeps, and ending in a switch of long hair, drawn about `pivot`.
static func tail(tool: SurfaceTool, pivot: Vector3, hide: Color) -> void:
	var mine := SurfaceTool.new()
	mine.begin(Mesh.PRIMITIVE_TRIANGLES)
	var joints := MountKinds.horse_tail_joints()
	var chain := MountKinds.HORSE_TAIL_CHAIN
	var stride := MountKinds.HORSE_TAIL_STRIDE
	var rows: Array = []
	var last := chain[chain.size() - 1] * S * 0.8
	for i in joints.size():
		var at := joints[i] + MountKinds.HORSE_TAIL_PIVOT
		# Each joint is as thick as the piece that starts there: a slim dock
		# at the rump, which the long hair then fills out. The last, which
		# has no piece, is as full as the hair gets.
		var r := (chain[i * stride + 2] * S) if i * stride + 2 < chain.size() else last
		# The tail is swept downwards with the reference across it, so a
		# ring's "across" runs fore and aft and its "up" from side to side:
		# the hair is wider than it is deep.
		rows.append(AnimalLoft.key(at, r * 0.85, r * 1.1, r * 1.1))
	# The switch: the hair carries on down past the last joint, thinning to
	# a point.
	var end := joints[joints.size() - 1] + MountKinds.HORSE_TAIL_PIVOT
	rows.append(AnimalLoft.key(end + Vector3(0.0, -0.06, 0.012) * S, last * 0.9, last * 1.15, last * 1.15))
	rows.append(AnimalLoft.key(end + Vector3(0.0, -0.12, 0.015) * S, last * 0.4, last * 0.5, last * 0.5))
	var loft := AnimalLoft.make(rows, Vector3.RIGHT, 6, 1, 0.0, 0.06 * S)
	loft.paint = AnimalNatural._flat(hide.darkened(0.55))
	loft.emit(mine)
	mine.generate_normals()
	tool.append_from(mine.commit(), 0, Transform3D(Basis(), -pivot))

## One leg, hanging from `hip` and drawn about `pivot`: the thigh or the
## shoulder a slab that lies within the flank, the forearm or gaskin that thickens
## above the knee or hock, the slender cannon, the fetlock, and a rounded hoof
## whose sole is the height of the hip below it.
## `side` is -1 for a left leg and 1 for a right one: the top leans inwards.
static func leg(tool: SurfaceTool, front: bool, hip: Vector3, pivot: Vector3, hide: Color, side: float) -> void:
	# A hand's width into the turf, as the hooves always stood, so that on a
	# slope no hoof is left in the air.
	var h := hip.y / S + 0.012
	var sole := 0.035
	var rows: Array
	# The numbers are as drawn: no row is blown up afterwards, because a top
	# swollen to fit the flank stood out of it as a lump. The foreleg is
	# straight down from the shoulder to a knee and a long cannon; the hind leg
	# has the stifle forward, the gaskin running back to a hock that points
	# behind, and a long cannon slanting forward again to the fetlock. (Across
	# is how thick the leg is from side to side; up and down are how far it
	# reaches behind and before.)
	if front:
		# Straight down from the shoulder: the elbow, a long forearm, a knee
		# that stands out a little before and behind, a slim cannon, the
		# fetlock and the hoof.
		rows = [
			[0.0, 0.10, 0.0, 0.085, 0.105, 0.105], [0.0, -0.10, 0.0, 0.080, 0.095, 0.095],
			[0.0, -0.22, 0.0, 0.063, 0.072, 0.072], [0.0, -0.35, 0.0, 0.055, 0.064, 0.066],
			[0.0, -0.44, 0.0, 0.041, 0.045, 0.047], [0.0, -0.62, -0.004, 0.039, 0.043, 0.045],
			[0.0, -0.68, -0.010, 0.049, 0.055, 0.061],
			[0.0, -(h - sole), -0.025, 0.062, 0.066, 0.078],
		]
	else:
		# The thigh is the heaviest thing on a horse and tapers down the
		# gaskin to a hock that points behind; the cannon below it is long
		# and runs straight, a little forward, to the fetlock, and the foot
		# comes back under the hip.
		rows = [
			[0.0, 0.14, 0.02, 0.115, 0.175, 0.175], [0.0, -0.03, 0.03, 0.105, 0.155, 0.165],
			[0.0, -0.20, 0.08, 0.078, 0.105, 0.115], [0.0, -0.36, 0.15, 0.050, 0.066, 0.080],
			[0.0, -0.47, 0.12, 0.041, 0.047, 0.051], [0.0, -0.60, 0.07, 0.039, 0.043, 0.045],
			[0.0, -0.68, 0.04, 0.049, 0.055, 0.061],
			[0.0, -(h - sole), 0.02, 0.062, 0.066, 0.078],
		]
	# Only the top is drawn in towards the middle, so that it lies within the
	# flank and the leg comes out from under it.
	for row: Array in rows:
		row[0] = -side * 0.035 * smoothstep(-0.3, 0.1, float(row[1]))
	# Flat at the top, which is inside the body and which nobody sees.
	var loft := AnimalLoft.make(_rings(rows), Vector3(0.0, 0.0, 1.0), 7, 1, 0.0, sole * S)
	loft.cap_rings = [0.7]
	loft.origin = hip - pivot
	var dark := hide.darkened(0.3)
	var hoof := Color(0.15, 0.12, 0.10)
	# The hide runs down to the knee, the dark legs below it, and a hoof.
	loft.paint = func(p: Vector3, _t: float, _a: float) -> Color:
		var y := (p.y - (hip.y - pivot.y)) / S
		return hide.lerp(dark, smoothstep(-0.25, -0.4, y)).lerp(hoof, smoothstep(-(h - 0.1), -(h - 0.05), y))
	loft.emit(tool)
