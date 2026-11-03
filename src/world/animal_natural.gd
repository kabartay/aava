class_name AnimalNatural
extends RefCounted

## The cat, the dog, the sheep and the cow, drawn as smooth skins.
##
## Each used to be spheres, cylinders and boxes standing against one another,
## and showed it: a seam where the neck met the body, a ridge where a leg
## began, a patch that was a flat blob stuck on. Now the body is one loft from
## the rump to the chest (see AnimalLoft), the head carries on from a neck
## that is hidden inside it, the legs are tapered lofts that bend at the knee
## and the hock and end in a hoof or a paw, and every colour — the darker back
## and paler belly, the cow's patches, the cat's stripes, the dog's bib — is
## painted on the vertices of the same surface.
##
## Everything here is written in units of the animal's size, the same unit
## `AnimalKinds` uses, and multiplied out at the last moment. The animal faces
## -Z, stands on Y = 0, and the first number of a body row is how far along it
## (negative towards the nose).

const CAT := &"cat"
const DOG := &"dog"
const SHEEP := &"sheep"
const COW := &"cow"

static func is_natural(kind: StringName) -> bool:
	return kind == CAT or kind == DOG or kind == SHEEP or kind == COW or is_small(kind)

## The squirrel and the beaver, which `AnimalSmall` draws.
static func is_small(kind: StringName) -> bool:
	return kind == AnimalSmall.SQUIRREL or kind == AnimalSmall.BEAVER

static var _noises: Dictionary = {}

## Smooth noise, one per seed and frequency, shared: it is only read.
static func _noise(seed_value: int, frequency: float) -> FastNoiseLite:
	var key := "%d/%.2f" % [seed_value, frequency]
	if not _noises.has(key):
		var noise := FastNoiseLite.new()
		noise.seed = seed_value
		noise.frequency = frequency
		_noises[key] = noise
	return _noises[key]

## A darker back and a paler belly: the one thing every coat has.
static func _shade(colour: Color, angle: float, back: float, belly: float) -> Color:
	var up := cos(angle)
	if up >= 0.0:
		return colour.darkened(back * up)
	return colour.lightened(belly * -up)

## Body rows [along, top, bottom, half-width, squareness?] as keys: a ring is
## the ellipse that fits between the top and the bottom.
static func _section(s: float, rows: Array) -> Array:
	var out: Array = []
	for row: Array in rows:
		var squareness := float(row[4]) if row.size() > 4 else 2.2
		var half := (float(row[1]) - float(row[2])) * 0.5
		var mid := (float(row[1]) + float(row[2])) * 0.5
		out.append(AnimalLoft.key(Vector3(0.0, mid, float(row[0])) * s, float(row[3]) * s, half * s, half * s, squareness))
	return out

## Rows [x, y, z, across, up, down, squareness?] as keys.
static func _rings(s: float, rows: Array) -> Array:
	var out: Array = []
	for row: Array in rows:
		var squareness := float(row[6]) if row.size() > 6 else 2.0
		out.append(AnimalLoft.key(
			Vector3(float(row[0]), float(row[1]), float(row[2])) * s,
			float(row[3]) * s, float(row[4]) * s, float(row[5]) * s, squareness
		))
	return out

## A tapered thing that is not part of the body: an ear, a horn, a whisker.
static func _leaf(
	tool: SurfaceTool, from: Vector3, steps: Array, widths: Array, thickness: Array, reference: Vector3,
	tip: float, around: int, paint: Callable
) -> AnimalLoft:
	var rings: Array = []
	var at := from
	for i in steps.size():
		at += steps[i] as Vector3
		rings.append(AnimalLoft.key(at, float(widths[i]), float(thickness[i]), float(thickness[i])))
	var loft := AnimalLoft.make(rings, reference, around, 1, 0.0, tip)
	loft.cap_rings = [0.7]
	loft.paint = paint
	loft.emit(tool)
	return loft

static func _flat(colour: Color) -> Callable:
	return func(_p: Vector3, _along: float, _angle: float) -> Color: return colour

## An eye: small and dark, with a pinprick of light so it looks back. The cat's
## is green with an upright pupil, the sheep's amber, because a black bead in
## a black face is no eye at all.
static func _eye(
	tool: SurfaceTool, head: AnimalLoft, t: float, angle: float, radius: float, iris: Color, slit: bool, pupil := false
) -> void:
	var ring := head.at(t)
	var centre: Vector3 = ring["c"]
	var p := head.surface(t, angle)
	var out := (p - centre).normalized()
	var at := p + out * radius * 0.2
	AnimalLoft.ball(tool, at, Vector3(radius, radius, radius * 0.8), iris)
	if slit:
		AnimalLoft.ball(tool, at + out * radius * 0.7, Vector3(radius * 0.28, radius * 0.85, radius * 0.3), Color(0.04, 0.04, 0.04))
	if pupil:
		# A round dark pupil in a lighter iris: the iris is the rim that shows
		# on a coat as dark as the pupil.
		AnimalLoft.ball(tool, at + out * radius * 0.5, Vector3(radius * 0.55, radius * 0.55, radius * 0.4), Color(0.04, 0.03, 0.03))
	var glint := Color(0.96, 0.96, 0.96)
	AnimalLoft.ball(tool, at + out * radius * 0.8 + Vector3(0.0, radius * 0.4, 0.0), Vector3(radius * 0.26, radius * 0.26, radius * 0.2), glint, 3)

## The front of the head, where the nose is, and the directions across and up
## there.
static func _nose(head: AnimalLoft, cap: float) -> Dictionary:
	var ring := head.at(float(head.keys.size() - 1))
	ring["tip"] = (ring["c"] as Vector3) + (ring["T"] as Vector3) * cap
	return ring

static func _nostrils(tool: SurfaceTool, nose: Dictionary, spread: float, size: float, colour: Color) -> void:
	for side in PackedFloat32Array([-1.0, 1.0]):
		var at: Vector3 = (nose["tip"] as Vector3) - (nose["T"] as Vector3) * size * 0.9 + (nose["S"] as Vector3) * side * spread
		AnimalLoft.ball(tool, at, Vector3(size, size * 0.8, size * 0.7), colour, 5)

# ----------------------------------------------------------------- the body

## The trunk, from the rump to the chest. The sheep's fleece and tail and the
## cow's udder belong to it and are drawn here too.
static func body(kind: StringName, variant: int, coat: Color, s: float, tool: SurfaceTool) -> void:
	if is_small(kind):
		return AnimalSmall.body(kind, coat, s, tool)
	var loft: AnimalLoft
	match kind:
		COW:
			loft = AnimalLoft.make(_section(s, [
				[-1.22, 1.62, 0.84, 0.44], [-0.92, 1.78, 0.76, 0.60], [-0.5, 1.84, 0.72, 0.62],
				[0.0, 1.78, 0.70, 0.62], [0.5, 1.80, 0.80, 0.58], [0.95, 1.78, 1.0, 0.62],
				[1.22, 1.68, 1.08, 0.46],
			]), Vector3.UP, 12, 2, 0.26 * s, 0.2 * s)
			loft.paint = _cow_paint(variant, coat, s)
		SHEEP:
			loft = AnimalLoft.make(_section(s, [
				[-1.0, 1.80, 0.96, 0.52, 2.4], [-0.55, 2.02, 0.80, 0.74, 2.4], [0.0, 2.06, 0.76, 0.80, 2.4],
				[0.55, 2.02, 0.80, 0.78, 2.4], [1.0, 1.86, 0.90, 0.62, 2.4],
			]), Vector3.UP, 16, 3, 0.38 * s, 0.34 * s)
			# A fleece is not a smooth egg: pushed in and out by a slow noise,
			# and a little darker where it is pushed in, so it reads as locks
			# of wool and not as a bubble.
			var lumps := _noise(7 + variant * 13, 2.2)
			loft.bump = func(p: Vector3) -> float:
				return lumps.get_noise_3d(p.x / s, p.y / s, p.z / s) * 0.07
			loft.paint = func(p: Vector3, _along: float, a: float) -> Color:
				var q := lumps.get_noise_3d(p.x / s, p.y / s, p.z / s)
				return _shade(coat, a, 0.03, 0.0).darkened(clampf(0.1 - q * 0.25, 0.0, 0.2))
		DOG:
			loft = AnimalLoft.make(_section(s, [
				[-1.08, 1.70, 0.90, 0.46], [-0.72, 1.90, 0.66, 0.62], [-0.25, 1.86, 0.74, 0.58],
				[0.25, 1.80, 0.90, 0.52], [0.75, 1.82, 0.90, 0.54], [1.1, 1.66, 1.04, 0.42],
			]), Vector3.UP, 12, 2, 0.28 * s, 0.26 * s)
			loft.paint = _dog_paint(coat, s)
		_:
			loft = AnimalLoft.make(_section(s, [
				[-1.15, 1.40, 0.62, 0.38], [-0.75, 1.54, 0.52, 0.48], [-0.1, 1.50, 0.54, 0.46],
				[0.5, 1.48, 0.64, 0.42], [1.0, 1.52, 0.58, 0.48], [1.3, 1.40, 0.66, 0.38],
			]), Vector3.UP, 12, 2, 0.28 * s, 0.26 * s)
			loft.paint = _cat_paint(variant, coat, s)
	loft.emit(tool)
	if kind == COW:
		# The udder: a pink bag between the hind legs.
		var bag := AnimalLoft.make(_rings(s, [
			[0.0, 0.88, 0.5, 0.10, 0.10, 0.10], [0.0, 0.74, 0.68, 0.19, 0.18, 0.18], [0.0, 0.84, 0.88, 0.12, 0.12, 0.12],
		]), Vector3.UP, 6, 1, 0.06 * s, 0.08 * s)
		bag.cap_rings = [0.7]
		bag.paint = _flat(Color(0.94, 0.78, 0.76))
		bag.emit(tool)
	elif kind == SHEEP:
		# A short woolly tail, hanging.
		var dock := AnimalLoft.make(_rings(s, [
			[0.0, 1.76, 1.2, 0.12, 0.12, 0.12], [0.0, 1.62, 1.44, 0.1, 0.1, 0.1], [0.0, 1.42, 1.5, 0.07, 0.09, 0.09],
		]), Vector3(0.3, 0.2, 1.0), 8, 1, 0.1 * s, 0.08 * s)
		dock.cap_rings = [0.7]
		dock.paint = _flat(coat.darkened(0.04))
		dock.emit(tool)

## A cow is white with dark or brown patches, as regions of the one surface:
## where a slow noise of the position rises above a level, that is a patch.
## The noise is seeded by the coat, so no two coats are marked alike, and it is
## read in three dimensions, so a patch carries over the back and down both
## flanks and the two sides are not mirrors.
static func _cow_paint(variant: int, coat: Color, s: float) -> Callable:
	var patch: Color = AnimalKinds.COW_PATCH if variant % 2 == 0 else Color(0.42, 0.27, 0.18)
	var noise := _noise(31 + variant * 97, 0.5)
	return func(p: Vector3, _along: float, a: float) -> Color:
		var base := _shade(coat, a, 0.06, 0.08)
		var v := noise.get_noise_3d(p.x / s * 1.3, p.y / s * 1.6, p.z / s)
		return base.lerp(_shade(patch, a, 0.1, 0.2), smoothstep(0.1, 0.2, v))

## A dog is darker along the back and paler under the belly, with a pale bib
## down the chest.
static func _dog_paint(coat: Color, s: float) -> Callable:
	return func(p: Vector3, _along: float, a: float) -> Color:
		var c := _shade(coat, a, 0.12, 0.1)
		var bib := smoothstep(-0.6 * s, -0.95 * s, p.z) * smoothstep(0.2, -0.5, cos(a))
		return c.lerp(coat.lightened(0.5), bib)

## A tabby: dark bands across the back that fade down the flanks, a pale belly
## and a white bib. The bands are broken up by noise, so they wander as a cat's
## do instead of lying like the rungs of a ladder.
static func _cat_paint(variant: int, coat: Color, s: float) -> Callable:
	var noise := _noise(5 + variant * 41, 3.0)
	var cream := Color(0.96, 0.93, 0.86)
	return func(p: Vector3, _along: float, a: float) -> Color:
		var c := _shade(coat, a, 0.06, 0.0)
		var wander := noise.get_noise_3d(p.x / s, p.y / s, p.z / s) * 0.7
		var band := smoothstep(0.1, 0.5, sin(p.z / s * 9.0 + wander * 3.0))
		var reach := smoothstep(0.1, 0.65, cos(a) + wander * 0.4)
		c = c.lerp(coat.darkened(0.38), band * reach)
		var belly := smoothstep(-0.2, -0.7, cos(a))
		var bib := smoothstep(-0.7 * s, -1.0 * s, p.z) * smoothstep(0.5, -0.2, cos(a))
		return c.lerp(cream, maxf(belly, bib))

# ----------------------------------------------------------------- the head

## The neck and the head, as one skin from the shoulder to the nose, drawn
## about the animal's own middle: `AnimalKinds` moves it to its joint. The neck
## starts inside the body, at the joint, so that turning the head never opens
## a gap. Returns the joint.
static func head(kind: StringName, variant: int, coat: Color, s: float, tool: SurfaceTool) -> Vector3:
	if is_small(kind):
		return AnimalSmall.head(kind, coat, s, tool)
	match kind:
		COW:
			return _cow_head(variant, coat, s, tool)
		SHEEP:
			return _sheep_head(variant, coat, s, tool)
		DOG:
			return _dog_head(variant, coat, s, tool)
	return _cat_head(variant, coat, s, tool)

static func _cow_head(variant: int, coat: Color, s: float, tool: SurfaceTool) -> Vector3:
	var skull := AnimalLoft.make(_rings(s, [
		# Long and narrow, a wedge: wide across the brow, tapering along a
		# straight face to a broad, blunt muzzle that is held level and not
		# dropped like a pig's snout.
		# Not a horse's long face: a cow's head is deep and short, and carried
		# a little lower than the poll, so the muzzle drops towards the grass.
		[0.0, 1.30, -1.00, 0.38, 0.40, 0.40], [0.0, 1.42, -1.34, 0.31, 0.37, 0.36],
		[0.0, 1.46, -1.62, 0.28, 0.35, 0.33], [0.0, 1.36, -1.90, 0.22, 0.28, 0.26],
		[0.0, 1.22, -2.12, 0.19, 0.22, 0.21], [0.0, 1.13, -2.28, 0.20, 0.18, 0.18, 2.8],
	]), Vector3.UP, 12, 2, 0.0, 0.08 * s)
	var nose := _nose(skull, 0.08 * s)
	var patch: Color = AnimalKinds.COW_PATCH if variant % 2 == 0 else Color(0.42, 0.27, 0.18)
	var noise := _noise(31 + variant * 97, 0.5)
	var tip: Vector3 = nose["tip"]
	skull.paint = func(p: Vector3, _along: float, a: float) -> Color:
		var base := _shade(coat, a, 0.05, 0.05)
		var v := noise.get_noise_3d(p.x / s * 1.3, p.y / s * 1.6, p.z / s)
		base = base.lerp(_shade(patch, a, 0.1, 0.2), smoothstep(0.1, 0.2, v))
		# A broad pink muzzle.
		return base.lerp(Color(0.90, 0.68, 0.68), smoothstep(0.3 * s, 0.18 * s, p.distance_to(tip)))
	skull.emit(tool)
	_nostrils(tool, nose, 0.075 * s, 0.032 * s, Color(0.36, 0.2, 0.22))
	for side in PackedFloat32Array([-1.0, 1.0]):
		# The eyes are on the sides of the head, at the brow, looking out and
		# not forward as a pig's do.
		_eye(tool, skull, 2.15, side * 1.38, 0.05 * s, Color(0.07, 0.05, 0.05), false)
		# Ears out to the sides below the horns, leaves a little drooped.
		var ear_at := skull.surface(1.6, side * 1.5) + Vector3(-side * 0.04, 0.0, 0.0) * s
		_leaf(tool, ear_at, [Vector3.ZERO, Vector3(side * 0.16, 0.02, 0.02) * s, Vector3(side * 0.16, -0.08, 0.04) * s],
			[0.09 * s, 0.13 * s, 0.06 * s], [0.03 * s, 0.026 * s, 0.018 * s], Vector3.UP, 0.05 * s, 5,
			func(_p: Vector3, _along: float, _angle: float) -> Color: return coat.darkened(0.12))
		# Short horns, curving up and out.
		var horn_at := skull.surface(1.75, side * 0.85) + Vector3(0.0, -0.02, 0.0) * s
		_leaf(tool, horn_at, [Vector3.ZERO, Vector3(side * 0.1, 0.09, -0.02) * s, Vector3(side * 0.07, 0.14, -0.03) * s],
			[0.055 * s, 0.042 * s, 0.026 * s], [0.055 * s, 0.042 * s, 0.026 * s], Vector3(0.3, 0.2, 1.0), 0.06 * s, 4,
			func(p: Vector3, _along: float, _angle: float) -> Color:
				return Color(0.92, 0.88, 0.76).lerp(Color(0.3, 0.27, 0.24), smoothstep(horn_at.y + 0.17 * s, horn_at.y + 0.24 * s, p.y)))
	return skull.at(0.0)["c"]

static func _sheep_head(variant: int, coat: Color, s: float, tool: SurfaceTool) -> Vector3:
	var face := AnimalKinds.SHEEP_FACE
	var skull := AnimalLoft.make(_rings(s, [
		[0.0, 1.42, -0.95, 0.42, 0.38, 0.38], [0.0, 1.55, -1.35, 0.38, 0.36, 0.36],
		[0.0, 1.68, -1.65, 0.30, 0.30, 0.28], [0.0, 1.66, -1.85, 0.21, 0.24, 0.22],
		[0.0, 1.52, -2.06, 0.16, 0.18, 0.15], [0.0, 1.38, -2.22, 0.14, 0.13, 0.13, 2.5],
	]), Vector3.UP, 12, 2, 0.0, 0.09 * s)
	var nose := _nose(skull, 0.09 * s)
	var tip: Vector3 = nose["tip"]
	# The wool goes up the neck and stops behind the ears, a little further
	# along on top: that fringe is the topknot.
	skull.paint = func(p: Vector3, _along: float, a: float) -> Color:
		var forward := -p.z / s - 1.55 - 0.18 * maxf(cos(a), 0.0)
		var wool := smoothstep(0.32, 0.0, forward)
		var c := face.lerp(face.lightened(0.1), smoothstep(0.35 * s, 0.15 * s, p.distance_to(tip)))
		return c.lerp(coat.darkened(0.03), wool)
	skull.emit(tool)
	for side in PackedFloat32Array([-1.0, 1.0]):
		_eye(tool, skull, 3.55, side * 1.1, 0.04 * s, Color(0.78, 0.62, 0.22), false)
		var ear_at := skull.surface(3.1, side * 1.45) + Vector3(-side * 0.03, 0.0, 0.0) * s
		_leaf(tool, ear_at, [Vector3.ZERO, Vector3(side * 0.14, -0.02, 0.02) * s, Vector3(side * 0.18, -0.1, 0.04) * s],
			[0.1 * s, 0.13 * s, 0.06 * s], [0.025 * s, 0.022 * s, 0.016 * s], Vector3.UP, 0.05 * s, 6, _flat(face.lightened(0.04)))
	return skull.at(0.0)["c"]

static func _dog_head(variant: int, coat: Color, s: float, tool: SurfaceTool) -> Vector3:
	var skull := AnimalLoft.make(_rings(s, [
		[0.0, 1.50, -0.85, 0.36, 0.32, 0.32], [0.0, 1.78, -1.12, 0.31, 0.30, 0.30],
		[0.0, 2.0, -1.32, 0.30, 0.30, 0.29], [0.0, 2.1, -1.55, 0.33, 0.32, 0.29],
		[0.0, 2.0, -1.80, 0.24, 0.22, 0.20], [0.0, 1.92, -1.98, 0.20, 0.17, 0.15, 2.6],
	]), Vector3.UP, 12, 2, 0.0, 0.1 * s)
	var nose := _nose(skull, 0.1 * s)
	var tip: Vector3 = nose["tip"]
	# The collar is a band round the neck, found by how far along the neck a
	# vertex is, painted red and pushed out a little so that it stands proud.
	var neck := skull.at(1.0)
	var neck_at: Vector3 = neck["c"]
	var neck_along: Vector3 = neck["T"]
	var side_patch := 1.0 if variant % 2 == 0 else -1.0
	var eye_patch := Vector3(side_patch * 0.25, 2.12, -1.72) * s
	skull.bump = func(p: Vector3) -> float:
		return 0.07 * smoothstep(0.1 * s, 0.05 * s, absf((p - neck_at).dot(neck_along)))
	skull.paint = func(p: Vector3, _along: float, a: float) -> Color:
		var c := _shade(coat, a, 0.1, 0.1)
		c = c.lerp(coat.lightened(0.3), smoothstep(0.55 * s, 0.3 * s, p.distance_to(tip)))
		c = c.lerp(coat.darkened(0.45), smoothstep(0.24 * s, 0.14 * s, p.distance_to(eye_patch)))
		return c.lerp(Color(0.80, 0.18, 0.16), smoothstep(0.075 * s, 0.05 * s, absf((p - neck_at).dot(neck_along))))
	skull.emit(tool)
	AnimalLoft.ball(tool, (nose["tip"] as Vector3) - (nose["T"] as Vector3) * 0.03 * s, Vector3(0.075, 0.06, 0.05) * s, Color(0.06, 0.05, 0.05))
	for side in PackedFloat32Array([-1.0, 1.0]):
		_eye(tool, skull, 3.3, side * 1.1, 0.055 * s, Color(0.78, 0.52, 0.2), false, true)
		# A floppy ear: hung from the top of the skull, swinging out and down.
		var ear_at := skull.surface(3.0, side * 0.85) + Vector3(-side * 0.03, 0.0, 0.0) * s
		_leaf(tool, ear_at, [Vector3.ZERO, Vector3(side * 0.12, -0.04, 0.04) * s, Vector3(side * 0.1, -0.2, 0.05) * s, Vector3(side * 0.05, -0.2, 0.03) * s],
			[0.14 * s, 0.2 * s, 0.2 * s, 0.13 * s], [0.035 * s, 0.035 * s, 0.032 * s, 0.025 * s], Vector3.RIGHT, 0.06 * s, 6,
			_flat(coat.darkened(0.3)))
	return skull.at(0.0)["c"]

static func _cat_head(variant: int, coat: Color, s: float, tool: SurfaceTool) -> Vector3:
	var skull := AnimalLoft.make(_rings(s, [
		[0.0, 1.22, -0.95, 0.34, 0.30, 0.30], [0.0, 1.42, -1.30, 0.31, 0.29, 0.29],
		[0.0, 1.54, -1.58, 0.36, 0.33, 0.31], [0.0, 1.56, -1.80, 0.44, 0.37, 0.33],
		[0.0, 1.48, -2.00, 0.29, 0.24, 0.22], [0.0, 1.40, -2.12, 0.14, 0.11, 0.10],
	]), Vector3.UP, 12, 2, 0.0, 0.06 * s)
	var nose := _nose(skull, 0.06 * s)
	var tip: Vector3 = nose["tip"]
	var cream := Color(0.96, 0.93, 0.86)
	var noise := _noise(5 + variant * 41, 3.0)
	skull.paint = func(p: Vector3, _along: float, a: float) -> Color:
		var c := _shade(coat, a, 0.05, 0.0)
		# Stripes on the forehead and cheeks, and a pale chin and muzzle.
		var wander := noise.get_noise_3d(p.x / s, p.y / s, p.z / s)
		c = c.lerp(coat.darkened(0.35), smoothstep(0.1, 0.5, sin(p.x / s * 14.0 + wander * 2.0)) * smoothstep(0.4, 0.8, cos(a)) * 0.8)
		c = c.lerp(cream, smoothstep(0.3 * s, 0.1 * s, p.distance_to(tip)) * 0.85)
		return c.lerp(cream, smoothstep(-0.3, -0.8, cos(a)))
	skull.emit(tool)
	AnimalLoft.ball(tool, (nose["tip"] as Vector3) - (nose["T"] as Vector3) * 0.02 * s, Vector3(0.045, 0.035, 0.03) * s, Color(0.80, 0.50, 0.50), 5)
	for side in PackedFloat32Array([-1.0, 1.0]):
		_eye(tool, skull, 3.55, side * 1.0, 0.075 * s, Color(0.58, 0.78, 0.28), true)
		# A pointed ear: a triangle standing up, with the pink inside facing
		# forward.
		var ear_at := skull.surface(2.85, side * 0.8) + Vector3(-side * 0.04, -0.03, 0.0) * s
		_leaf(tool, ear_at, [Vector3.ZERO, Vector3(side * 0.05, 0.17, 0.0) * s, Vector3(side * 0.07, 0.2, -0.02) * s],
			[0.17 * s, 0.13 * s, 0.01 * s], [0.04 * s, 0.03 * s, 0.015 * s], Vector3(0.0, 0.0, 1.0), 0.03 * s, 6,
			func(_p: Vector3, _along: float, a: float) -> Color:
				return coat.darkened(0.12).lerp(Color(0.88, 0.62, 0.64), smoothstep(-0.3, -0.7, cos(a))))
		# Whiskers.
		for row in 2:
			var from := (nose["tip"] as Vector3) - (nose["T"] as Vector3) * 0.1 * s + (nose["S"] as Vector3) * side * 0.06 * s + Vector3(0.0, 0.01 - 0.04 * float(row), 0.0) * s
			_leaf(tool, from, [Vector3.ZERO, Vector3(side * 0.3, 0.03 - 0.06 * float(row), 0.0) * s],
				[0.008 * s, 0.003 * s], [0.008 * s, 0.003 * s], Vector3.UP, 0.0, 3, _flat(cream))
	return skull.at(0.0)["c"]

# ----------------------------------------------------------------- the tail

## The tail of a cat, a dog or a cow, drawn about the animal's middle like the
## head and moved to its root by `AnimalKinds`. The first ring is at the root,
## inside the rump.
static func tail(kind: StringName, coat: Color, s: float, tool: SurfaceTool) -> void:
	if is_small(kind):
		return AnimalSmall.tail(coat, s, tool)
	var tuft := Color(0.96, 0.94, 0.9)
	var loft: AnimalLoft
	match kind:
		CAT:
			# Long, and up in a question mark with its tip leaning forward;
			# banded, with a white tip.
			loft = AnimalLoft.make(_rings(s, [
				# It starts well inside the rump, as thick as the rump is
				# there and running on from its slope, and thins as it
				# goes: no knob where it comes out.
				[0.0, 1.14, 1.0, 0.24, 0.24, 0.24], [0.0, 1.16, 1.4, 0.19, 0.19, 0.19],
				[0.0, 1.24, 1.74, 0.15, 0.15, 0.15], [0.0, 1.5, 1.98, 0.13, 0.13, 0.13],
				[0.0, 1.88, 2.04, 0.12, 0.12, 0.12], [0.0, 2.25, 1.92, 0.105, 0.105, 0.105],
				[0.0, 2.5, 1.7, 0.09, 0.09, 0.09],
			]), Vector3(0.7, 0.2, 0.5), 6, 2, 0.0, 0.1 * s)
			loft.paint = func(_p: Vector3, along: float, _a: float) -> Color:
				var band := smoothstep(0.2, 0.6, sin(along * 46.0))
				var c := coat.darkened(0.08).lerp(coat.darkened(0.4), band * smoothstep(0.1, 0.2, along))
				return c.lerp(tuft, smoothstep(0.86, 0.94, along))
		DOG:
			loft = AnimalLoft.make(_rings(s, [
				[0.0, 1.45, 1.156, 0.12, 0.12, 0.12], [0.0, 1.58, 1.5, 0.10, 0.10, 0.10],
				[0.0, 1.85, 1.68, 0.085, 0.085, 0.085], [0.0, 2.2, 1.62, 0.065, 0.065, 0.065],
				[0.0, 2.4, 1.45, 0.055, 0.055, 0.055],
			]), Vector3(0.7, 0.2, 0.5), 6, 2, 0.0, 0.08 * s)
			loft.paint = func(_p: Vector3, along: float, _a: float) -> Color:
				return coat.darkened(0.05).lerp(coat.lightened(0.25), smoothstep(0.7, 0.9, along))
		_:
			# A cow's: a rope hanging down the back of her legs with a tuft.
			loft = AnimalLoft.make(_rings(s, [
				[0.0, 1.50, 1.25, 0.06, 0.06, 0.06], [0.0, 1.45, 1.52, 0.05, 0.05, 0.05],
				[0.0, 1.1, 1.58, 0.042, 0.042, 0.042], [0.0, 0.76, 1.56, 0.04, 0.04, 0.04],
				[0.0, 0.6, 1.55, 0.1, 0.12, 0.12],
			]), Vector3(0.7, 0.2, 0.5), 6, 1, 0.0, 0.1 * s)
			loft.paint = func(p: Vector3, _along: float, _a: float) -> Color:
				return coat.darkened(0.1).lerp(AnimalKinds.COW_PATCH, smoothstep(0.78 * s, 0.68 * s, p.y))
	loft.emit(tool)

# ----------------------------------------------------------------- the legs

## How far, in units of the animal's size, the top of a leg is drawn in from
## its hip towards the middle,
## and how much longer fore and aft it is made there. A dog's or a cat's haunch
## is already as long as its rump is deep, and any more stands out behind it.
const LEAN := {
	COW: [0.17, 0.5], DOG: [0.12, 0.12], SHEEP: [0.12, 0.3], CAT: [0.1, 0.08],
	&"squirrel": [0.1, 0.1], &"beaver": [0.12, 0.2],
}

## One leg, about its hip and hanging from it: thick where it is buried in the
## body, thin at the foot, bent at the knee or the hock, and ending in a hoof
## or a paw whose sole is exactly `height` below the hip, so the animal stands
## on it. `hip` moves it to where it hangs, for a body that bakes its legs in.
static func leg(
	kind: StringName, front: bool, variant: int, coat: Color, s: float, height: float, tool: SurfaceTool, hip := Vector3.ZERO,
	side := 1.0
) -> void:
	var h := height / s
	var rows: Array
	var sole := 0.07
	var paint: Callable
	var dark := Color(0.14, 0.12, 0.12)
	match kind:
		AnimalSmall.SQUIRREL, AnimalSmall.BEAVER:
			var spec := AnimalSmall.leg(kind, front, coat, s, height, hip)
			rows = spec[0]
			sole = spec[1]
			paint = spec[2]
			h = spec[3]
		COW:
			if front:
				rows = [
					[0.0, 0.30, 0.0, 0.16, 0.22, 0.22], [0.0, -0.15, 0.0, 0.15, 0.19, 0.18], [0.0, -0.55, 0.0, 0.115, 0.125, 0.12],
					[0.0, -0.78, -0.01, 0.12, 0.14, 0.12], [0.0, -0.95, 0.0, 0.085, 0.09, 0.085],
					[0.0, -(h - sole), -0.015, 0.11, 0.13, 0.12],
				]
			else:
				rows = [
					[0.0, 0.30, 0.08, 0.18, 0.28, 0.28], [0.0, -0.10, 0.05, 0.18, 0.25, 0.23], [0.0, -0.45, 0.0, 0.14, 0.17, 0.15],
					[0.0, -0.75, 0.10, 0.11, 0.15, 0.11], [0.0, -0.97, 0.05, 0.085, 0.09, 0.085],
					[0.0, -(h - sole), 0.01, 0.11, 0.13, 0.12],
				]
			var patch: Color = AnimalKinds.COW_PATCH if variant % 2 == 0 else Color(0.42, 0.27, 0.18)
			var noise := _noise(31 + variant * 97, 0.5)
			var along := -1.02 if front else 1.02
			paint = func(p: Vector3, _t: float, _a: float) -> Color:
				var q := (p - hip) / s
				var v := noise.get_noise_3d((q.x + 0.46) * 1.3, (q.y + 1.19) * 1.6, q.z + along)
				var c := coat.darkened(0.05).lerp(patch, smoothstep(0.1, 0.2, v) * smoothstep(-0.7, -0.3, q.y))
				return c.lerp(Color(0.13, 0.11, 0.11), smoothstep(-(h - 0.22), -(h - 0.12), q.y))
		SHEEP:
			if front:
				rows = [
					[0.0, 0.25, 0.0, 0.15, 0.17, 0.17], [0.0, -0.10, 0.0, 0.10, 0.11, 0.11], [0.0, -0.30, 0.0, 0.065, 0.07, 0.07],
					[0.0, -0.45, -0.005, 0.06, 0.07, 0.06], [0.0, -(h - sole - 0.08), 0.0, 0.05, 0.052, 0.05],
					[0.0, -(h - sole), 0.0, 0.06, 0.075, 0.07],
				]
			else:
				rows = [
					[0.0, 0.25, 0.04, 0.18, 0.2, 0.2], [0.0, -0.10, 0.03, 0.12, 0.13, 0.13], [0.0, -0.28, 0.0, 0.07, 0.08, 0.07],
					[0.0, -0.45, 0.07, 0.065, 0.09, 0.06], [0.0, -(h - sole - 0.08), 0.04, 0.05, 0.055, 0.05],
					[0.0, -(h - sole), 0.035, 0.06, 0.075, 0.07],
				]
			var face := AnimalKinds.SHEEP_FACE
			paint = func(p: Vector3, _t: float, _a: float) -> Color:
				var y := p.y - hip.y
				return face.lerp(coat.darkened(0.03), smoothstep(-0.16, -0.04, y)).lerp(Color(0.1, 0.09, 0.1), smoothstep(-(h - 0.14), -(h - 0.07), y))
		DOG:
			if front:
				rows = [
					[0.0, 0.30, 0.0, 0.20, 0.24, 0.24], [0.0, -0.10, 0.0, 0.16, 0.19, 0.18], [0.0, -0.45, 0.0, 0.115, 0.125, 0.115],
					[0.0, -0.80, 0.0, 0.092, 0.10, 0.092], [0.0, -0.90, -0.01, 0.092, 0.1, 0.092],
					[0.0, -(h - sole), -0.05, 0.125, 0.09, 0.17],
				]
			else:
				rows = [
					[0.0, 0.30, 0.10, 0.22, 0.30, 0.30], [0.0, -0.10, 0.05, 0.21, 0.27, 0.24], [0.0, -0.40, -0.08, 0.15, 0.16, 0.15],
					[0.0, -0.80, 0.06, 0.10, 0.14, 0.095], [0.0, -0.92, 0.03, 0.085, 0.09, 0.085],
					[0.0, -(h - sole), -0.02, 0.12, 0.09, 0.16],
				]
			paint = func(p: Vector3, _t: float, _a: float) -> Color:
				var y := p.y - hip.y
				return coat.darkened(0.1).lerp(coat.lightened(0.25), smoothstep(-(h - 0.3), -(h - 0.15), y))
		_:
			if front:
				rows = [
					[0.0, 0.30, 0.0, 0.17, 0.19, 0.19], [0.0, -0.10, 0.0, 0.125, 0.14, 0.14], [0.0, -0.35, 0.0, 0.09, 0.095, 0.09],
					[0.0, -0.55, 0.0, 0.082, 0.085, 0.082], [0.0, -0.68, -0.01, 0.085, 0.085, 0.085],
					[0.0, -(h - sole), -0.05, 0.10, 0.08, 0.14],
				]
			else:
				rows = [
					[0.0, 0.30, 0.12, 0.22, 0.25, 0.25], [0.0, -0.05, 0.08, 0.18, 0.21, 0.19], [0.0, -0.30, -0.05, 0.10, 0.11, 0.10],
					[0.0, -0.55, 0.10, 0.075, 0.11, 0.07], [0.0, -0.69, 0.05, 0.075, 0.08, 0.075],
					[0.0, -(h - sole), -0.02, 0.10, 0.08, 0.14],
				]
			var white := Color(0.96, 0.94, 0.9)
			paint = func(p: Vector3, _t: float, _a: float) -> Color:
				var y := p.y - hip.y
				return coat.darkened(0.08).lerp(white, smoothstep(-(h - 0.32), -(h - 0.18), y))
	# The top of a cat's or a dog's leg wears the body's own colour — the bands
	# and the darker back, the paler belly — and gives way to the leg's colour
	# lower down. Plain coat against a striped or shaded flank showed the join
	# as a line where each leg came out. The body's paint is asked for the
	# height the vertex is at, as if it were on the flank there: an ellipse's
	# angle is its height over its half-depth.
	if kind == CAT or kind == DOG:
		var flank := _cat_paint(variant, coat, s) if kind == CAT else _dog_paint(coat, s)
		var middle := 1.03 if kind == CAT else 1.3
		var depth := 0.5 if kind == CAT else 0.56
		var lowest := -0.5 if kind == CAT else 0.0
		var feet := paint
		# The mesh is drawn about its hip, so the body's own frame is the
		# hip's height and place along the animal added back.
		var at_hip := Vector3(0.0, height, float(AnimalKinds._shape(kind)["long"]) * 0.6 * s * (-1.0 if front else 1.0))
		paint = func(p: Vector3, t: float, a: float) -> Color:
			var on_body := p - hip + at_hip
			var up := clampf((on_body.y / s - middle) / depth, lowest, 1.0)
			var carried: Color = flank.call(on_body, t, acos(up))
			return (feet.call(p, t, a) as Color).lerp(carried, smoothstep(-0.5, -0.12, (p.y - hip.y) / s))
	# The top is rounded, not cut flat: where it comes through the side of the
	# body it is the swell of a shoulder or a haunch, not the end of a pole.
	# A leg that is a tube set on the outside of the flank shows as a sleeve.
	# The top is a slab instead: long fore and aft, thin across, drawn in from
	# the hip towards the middle of the animal so that it lies within the body,
	# and giving its width back down the leg, so that the thigh or shoulder is
	# the swell of the flank and the leg comes out from under it. That leans
	# one way for the left leg and the other for the right, which is why a leg
	# is told which side it is on.
	var fit: Array = LEAN.get(kind, [0.12, 0.3])
	for row: Array in rows:
		var grown := smoothstep(-0.55, 0.05, float(row[1]))
		row[0] = -side * float(fit[0]) * grown
		row[3] = float(row[3]) * (1.0 - 0.3 * grown)
		row[4] = float(row[4]) * (1.0 + float(fit[1]) * grown)
		row[5] = float(row[5]) * (1.0 + float(fit[1]) * grown)
	var loft := AnimalLoft.make(_rings(s, rows), Vector3(0.0, 0.0, 1.0), 7, 1, 0.14 * s, sole * s)
	loft.cap_rings = [0.7]
	loft.origin = hip
	loft.paint = paint
	loft.emit(tool)
