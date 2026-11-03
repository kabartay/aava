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
## Everything is written in the horse's own unit, a fifth more than the first
## horse, and multiplied out by `S` at the last moment, so that it lines up with
## the saddle which is written in the same unit.

const S := 1.2

static func _rings(rows: Array) -> Array:
	return AnimalNatural._rings(S, rows)

## The barrel, shoulders, withers and rump as one body from the chest to the
## dock.
static func body(tool: SurfaceTool, hide: Color) -> void:
	var loft := AnimalLoft.make(AnimalNatural._section(S, [
		[-1.18, 1.52, 1.10, 0.30], [-0.80, 1.76, 0.98, 0.40], [-0.40, 1.84, 0.94, 0.42],
		[0.05, 1.78, 0.92, 0.43], [0.50, 1.76, 0.98, 0.42], [0.88, 1.72, 1.06, 0.44],
		[1.22, 1.52, 1.20, 0.32],
	]), Vector3.UP, 10, 2, 0.2 * S, 0.2 * S)
	loft.paint = func(_p: Vector3, _along: float, a: float) -> Color:
		return AnimalNatural._shade(hide, a, 0.05, 0.1)
	loft.emit(tool)

## The neck and head with the mane, the forelock, the ears and the face, drawn
## about `pivot`, the foot of the neck.
static func head(tool: SurfaceTool, pivot: Vector3, hide: Color) -> void:
	var dark := hide.darkened(0.3)
	var pale := Color(0.93, 0.90, 0.84)
	var mine := SurfaceTool.new()
	mine.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Long in the neck, which rises and arches forward to the poll, and long in
	# the head, which is carried down from it to a soft, square muzzle.
	var skull := AnimalLoft.make(_rings([
		[0.0, 1.56, -0.62, 0.30, 0.32, 0.32], [0.0, 1.84, -0.82, 0.22, 0.27, 0.26],
		[0.0, 2.14, -1.02, 0.17, 0.22, 0.21], [0.0, 2.30, -1.20, 0.19, 0.24, 0.20],
		[0.0, 2.27, -1.40, 0.17, 0.20, 0.21], [0.0, 2.17, -1.62, 0.13, 0.15, 0.17],
		[0.0, 2.06, -1.80, 0.11, 0.12, 0.12], [0.0, 1.97, -1.93, 0.125, 0.10, 0.10, 2.6],
	]), Vector3.UP, 10, 1, 0.0, 0.07 * S)
	var nose := AnimalNatural._nose(skull, 0.07 * S)
	var tip: Vector3 = nose["tip"]
	skull.paint = func(p: Vector3, _along: float, a: float) -> Color:
		var c := AnimalNatural._shade(hide, a, 0.05, 0.05)
		# A white blaze down the face, and a soft pale muzzle.
		var face := smoothstep(-1.35 * S, -1.6 * S, p.z) * smoothstep(0.04 * S, 0.02 * S, absf(p.x)) * smoothstep(0.3, 0.8, cos(a))
		c = c.lerp(pale, face)
		return c.lerp(hide.lightened(0.15), smoothstep(0.3 * S, 0.12 * S, p.distance_to(tip)))
	skull.emit(mine)
	AnimalLoft.ball(mine, tip - (nose["T"] as Vector3) * 0.03 * S, Vector3(0.12, 0.05, 0.05) * S, dark.darkened(0.3), 5)
	for side in PackedFloat32Array([-1.0, 1.0]):
		AnimalNatural._eye(mine, skull, 4.2, side * 1.35, 0.045 * S, Color(0.08, 0.05, 0.05), false)
		AnimalLoft.ball(mine, tip - (nose["T"] as Vector3) * 0.07 * S + (nose["S"] as Vector3) * side * 0.06 * S, Vector3(0.025, 0.035, 0.02) * S, Color(0.1, 0.08, 0.08), 4)
		# Ears: upright, pointed, a little forward.
		var ear_at := skull.surface(3.2, side * 0.8) + Vector3(-side * 0.02, 0.0, 0.0) * S
		AnimalNatural._leaf(mine, ear_at, [Vector3.ZERO, Vector3(side * 0.03, 0.14, -0.02) * S, Vector3(side * 0.0, 0.1, -0.03) * S],
			[0.07 * S, 0.065 * S, 0.02 * S], [0.025 * S, 0.02 * S, 0.01 * S], Vector3(0.0, 0.0, 1.0), 0.03 * S, 5,
			AnimalNatural._flat(dark))
	# The mane: a ridge of hair along the crest from the poll to the withers.
	var mane := AnimalLoft.make(_rings([
		[0.0, 2.40, -1.18, 0.035, 0.07, 0.04], [0.0, 2.30, -1.02, 0.045, 0.10, 0.06],
		[0.0, 2.12, -0.84, 0.05, 0.12, 0.07], [0.0, 1.98, -0.68, 0.05, 0.12, 0.07],
		[0.0, 1.90, -0.50, 0.04, 0.08, 0.05],
	]), Vector3.UP, 6, 1, 0.04 * S, 0.04 * S)
	mane.paint = AnimalNatural._flat(dark)
	mane.emit(mine)
	# The forelock, falling between the ears over the brow.
	var forelock := AnimalLoft.make(_rings([
		[0.0, 2.40, -1.26, 0.04, 0.04, 0.04], [0.0, 2.34, -1.32, 0.04, 0.04, 0.04],
		[0.0, 2.24, -1.34, 0.03, 0.03, 0.03],
	]), Vector3.UP, 5, 1, 0.0, 0.03 * S)
	forelock.cap_rings = [0.7]
	forelock.paint = AnimalNatural._flat(dark)
	forelock.emit(mine)
	mine.generate_normals()
	tool.append_from(mine.commit(), 0, Transform3D(Basis(), -pivot))

## The tail, from its root on the rump down the chain of joints that `MountKinds`
## keeps, and ending in a switch of long hair, drawn about `pivot`.
static func tail(tool: SurfaceTool, pivot: Vector3, hide: Color) -> void:
	var dark := hide.darkened(0.3)
	var mine := SurfaceTool.new()
	mine.begin(Mesh.PRIMITIVE_TRIANGLES)
	var joints := MountKinds.horse_tail_joints()
	var chain := MountKinds.HORSE_TAIL_CHAIN
	var stride := MountKinds.HORSE_TAIL_STRIDE
	var rows: Array = []
	var last := chain[chain.size() - 1] * S * 0.7
	for i in joints.size():
		var at := joints[i] + MountKinds.HORSE_TAIL_PIVOT
		# Each joint is as thick as the piece that starts there; the last,
		# which has no piece, as thin as the chain tapers to.
		var r := (chain[i * stride + 2] * S) if i * stride + 2 < chain.size() else last
		rows.append(AnimalLoft.key(at, r * 1.35, r * 1.35, r * 1.35))
	# The switch: the hair carries on down past the last joint, fuller before
	# it thins.
	var end := joints[joints.size() - 1] + MountKinds.HORSE_TAIL_PIVOT
	rows.append(AnimalLoft.key(end + Vector3(0.0, -0.22, 0.04) * S, last * 2.2, last * 2.2, last * 2.2))
	rows.append(AnimalLoft.key(end + Vector3(0.0, -0.42, 0.05) * S, last * 0.9, last * 0.9, last * 0.9))
	var loft := AnimalLoft.make(rows, Vector3.RIGHT, 6, 2, 0.0, 0.08 * S)
	loft.paint = AnimalNatural._flat(dark)
	loft.emit(mine)
	mine.generate_normals()
	tool.append_from(mine.commit(), 0, Transform3D(Basis(), -pivot))

## One leg, hanging from `hip` and drawn about `pivot`: the thigh or the
## shoulder a slab that lies within the flank, the knee or the hock, the slender
## cannon, the fetlock, and a hoof whose sole is the height of the hip below it.
## `side` is -1 for a left leg and 1 for a right one: the top leans inwards.
static func leg(tool: SurfaceTool, front: bool, hip: Vector3, pivot: Vector3, hide: Color, side: float) -> void:
	# A hand's width into the turf, as the hooves always stood, so that on a
	# slope no hoof is left in the air.
	var h := hip.y / S + 0.04
	var sole := 0.08
	var rows: Array
	if front:
		rows = [
			[0.0, 0.30, 0.0, 0.17, 0.22, 0.22], [0.0, -0.15, 0.0, 0.15, 0.18, 0.18],
			[0.0, -0.50, 0.0, 0.095, 0.11, 0.11], [0.0, -0.64, -0.01, 0.085, 0.09, 0.09],
			[0.0, -0.95, 0.0, 0.062, 0.07, 0.07],
			[0.0, -(h - sole), -0.02, 0.095, 0.10, 0.13],
		]
	else:
		rows = [
			[0.0, 0.30, 0.08, 0.20, 0.28, 0.28], [0.0, -0.10, 0.05, 0.18, 0.24, 0.22],
			[0.0, -0.45, -0.02, 0.11, 0.14, 0.12], [0.0, -0.72, 0.10, 0.09, 0.12, 0.09],
			[0.0, -1.0, 0.05, 0.062, 0.07, 0.07],
			[0.0, -(h - sole), 0.0, 0.095, 0.10, 0.13],
		]
	for row: Array in rows:
		var grown := smoothstep(-0.55, 0.05, float(row[1]))
		row[0] = -side * 0.12 * grown
		row[3] = float(row[3]) * (1.0 - 0.25 * grown)
		row[4] = float(row[4]) * (1.0 + 0.3 * grown)
		row[5] = float(row[5]) * (1.0 + 0.3 * grown)
	var loft := AnimalLoft.make(_rings(rows), Vector3(0.0, 0.0, 1.0), 8, 1, 0.14 * S, sole * S)
	loft.cap_rings = [0.7]
	loft.origin = hip - pivot
	var dark := hide.darkened(0.3)
	var hoof := Color(0.15, 0.12, 0.10)
	# The hide runs down to the knee, the dark legs below it, and a hoof.
	loft.paint = func(p: Vector3, _t: float, _a: float) -> Color:
		var y := (p.y - (hip.y - pivot.y)) / S
		return hide.darkened(0.05).lerp(dark, smoothstep(-0.4, -0.7, y)).lerp(hoof, smoothstep(-(h - 0.22), -(h - 0.1), y))
	loft.emit(tool)
