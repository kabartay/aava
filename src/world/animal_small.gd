class_name AnimalSmall
extends RefCounted

## The squirrel and the beaver, drawn as smooth skins like the cat and the cow.
##
## `AnimalNatural` hands these two kinds here. The squirrel sits up: its body
## is one loft that rises from the haunches to the neck, so that the spine is
## nearly upright, and its tail is a bushy loft that goes back, up and curls
## forward over it. The beaver is a heavy round barrel low to the ground, with
## small ears, orange front teeth and a flat paddle of a tail, patterned like
## scales, that is part of the body.
##
## Written in units of the animal's size, like everything in `AnimalNatural`.
## The animal faces -Z and stands on Y = 0.

const SQUIRREL := &"squirrel"
const BEAVER := &"beaver"

const CREAM := Color(0.95, 0.88, 0.74)
const ORANGE := Color(0.96, 0.52, 0.10)

## How long a squirrel's arm is, in units of its size: it holds its hands up to
## its chest and does not reach the ground with them.
const ARM := 0.62

static func body(kind: StringName, coat: Color, s: float, tool: SurfaceTool) -> void:
	if kind == SQUIRREL:
		var loft := AnimalLoft.make(AnimalNatural._rings(s, [
			# From the haunches up to the neck, leaning forward.
			[0.0, 0.62, 0.66, 0.54, 0.50, 0.50, 2.2], [0.0, 1.02, 0.42, 0.58, 0.54, 0.54, 2.2],
			[0.0, 1.46, 0.06, 0.50, 0.46, 0.46, 2.2], [0.0, 1.80, -0.26, 0.36, 0.32, 0.32],
		]), Vector3.UP, 12, 2, 0.3 * s, 0.15 * s)
		loft.paint = func(_p: Vector3, _along: float, a: float) -> Color:
			var c := AnimalNatural._shade(coat, a, 0.12, 0.0)
			# A cream waistcoat from the chin down the front.
			return c.lerp(CREAM, smoothstep(-0.25, -0.75, cos(a)))
		loft.emit(tool)
		return
	var barrel := AnimalLoft.make(AnimalNatural._section(s, [
		[-1.15, 1.35, 0.40, 0.44], [-0.65, 1.62, 0.26, 0.66], [-0.05, 1.68, 0.20, 0.74],
		[0.55, 1.60, 0.20, 0.76], [1.05, 1.40, 0.28, 0.66], [1.38, 1.10, 0.38, 0.44],
	]), Vector3.UP, 12, 2, 0.3 * s, 0.3 * s)
	barrel.paint = func(_p: Vector3, _along: float, a: float) -> Color:
		return AnimalNatural._shade(coat, a, 0.16, 0.0).lerp(coat.lightened(0.22), smoothstep(-0.2, -0.8, cos(a)))
	barrel.emit(tool)
	# The paddle: flat, broad and rounded at the end, rooted inside the rump and
	# scaled in diamonds. The diamonds are the paint alternating from one vertex
	# to the next both ways, which the smooth shading turns into a lattice.
	var paddle := AnimalLoft.make(AnimalNatural._rings(s, [
		[0.0, 0.68, 1.0, 0.24, 0.15, 0.15], [0.0, 0.50, 1.4, 0.34, 0.10, 0.10],
		[0.0, 0.36, 1.8, 0.48, 0.06, 0.06], [0.0, 0.30, 2.15, 0.52, 0.05, 0.05],
		[0.0, 0.28, 2.42, 0.36, 0.04, 0.04],
	]), Vector3.UP, 8, 3, 0.0, 0.12 * s)
	var skin := coat.darkened(0.42)
	paddle.paint = func(_p: Vector3, along: float, a: float) -> Color:
		var scale_edge := smoothstep(-0.2, 0.2, sin(along * 56.0) * sin(a * 4.0))
		return skin.lerp(skin.lightened(0.3), scale_edge * smoothstep(0.1, 0.3, along))
	paddle.emit(tool)

static func head(kind: StringName, coat: Color, s: float, tool: SurfaceTool) -> Vector3:
	if kind == SQUIRREL:
		return _squirrel_head(coat, s, tool)
	return _beaver_head(coat, s, tool)

static func _squirrel_head(coat: Color, s: float, tool: SurfaceTool) -> Vector3:
	var skull := AnimalLoft.make(AnimalNatural._rings(s, [
		[0.0, 1.80, -0.26, 0.30, 0.30, 0.30], [0.0, 2.02, -0.42, 0.34, 0.33, 0.32],
		[0.0, 2.10, -0.66, 0.36, 0.34, 0.31], [0.0, 2.02, -0.90, 0.22, 0.20, 0.17],
		[0.0, 1.96, -1.04, 0.11, 0.11, 0.09],
	]), Vector3.UP, 12, 2, 0.0, 0.07 * s)
	var nose := AnimalNatural._nose(skull, 0.07 * s)
	var tip: Vector3 = nose["tip"]
	skull.paint = func(p: Vector3, _along: float, a: float) -> Color:
		var c := AnimalNatural._shade(coat, a, 0.08, 0.0)
		# Pale cheeks and chin, and a paler muzzle.
		c = c.lerp(CREAM, smoothstep(-0.2, -0.8, cos(a)))
		return c.lerp(CREAM, 0.6 * smoothstep(0.34 * s, 0.14 * s, p.distance_to(tip)))
	skull.emit(tool)
	AnimalLoft.ball(tool, tip - (nose["T"] as Vector3) * 0.02 * s, Vector3(0.06, 0.05, 0.05) * s, Color(0.12, 0.07, 0.07), 5)
	for side in PackedFloat32Array([-1.0, 1.0]):
		AnimalNatural._eye(tool, skull, 2.25, side * 1.2, 0.065 * s, Color(0.07, 0.05, 0.05), false)
		# Ears that stand up from the back of the head, and end in a long dark
		# tuft that is the part of a red squirrel anybody remembers.
		var ear_at := skull.surface(1.45, side * 0.75) + Vector3(-side * 0.02, -0.04, 0.0) * s
		var tuft_from := ear_at.y + 0.2 * s
		AnimalNatural._leaf(tool, ear_at, [Vector3.ZERO, Vector3(side * 0.03, 0.16, 0.0) * s, Vector3(side * 0.01, 0.12, 0.0) * s, Vector3(0.0, 0.16, 0.0) * s],
			[0.14 * s, 0.13 * s, 0.07 * s, 0.03 * s], [0.03 * s, 0.025 * s, 0.015 * s, 0.01 * s], Vector3(0.0, 0.0, 1.0), 0.04 * s, 5,
			func(p: Vector3, _along: float, a: float) -> Color:
				var c := coat.darkened(0.1).lerp(Color(0.86, 0.60, 0.56), smoothstep(-0.2, -0.7, cos(a)) * smoothstep(tuft_from, ear_at.y, p.y))
				return c.lerp(coat.darkened(0.55), smoothstep(tuft_from - 0.02 * s, tuft_from + 0.08 * s, p.y)))
	return skull.at(0.0)["c"]

static func _beaver_head(coat: Color, s: float, tool: SurfaceTool) -> Vector3:
	var skull := AnimalLoft.make(AnimalNatural._rings(s, [
		[0.0, 1.20, -0.85, 0.40, 0.38, 0.38], [0.0, 1.30, -1.15, 0.46, 0.40, 0.40],
		[0.0, 1.26, -1.45, 0.42, 0.36, 0.36], [0.0, 1.14, -1.72, 0.26, 0.22, 0.20],
		[0.0, 1.08, -1.86, 0.15, 0.14, 0.12],
	]), Vector3.UP, 12, 2, 0.0, 0.08 * s)
	var nose := AnimalNatural._nose(skull, 0.08 * s)
	var tip: Vector3 = nose["tip"]
	skull.paint = func(p: Vector3, _along: float, a: float) -> Color:
		var c := AnimalNatural._shade(coat, a, 0.14, 0.0)
		return c.lerp(coat.lightened(0.28), smoothstep(0.5 * s, 0.2 * s, p.distance_to(tip)))
	skull.emit(tool)
	AnimalLoft.ball(tool, tip - (nose["T"] as Vector3) * 0.03 * s, Vector3(0.1, 0.07, 0.06) * s, Color(0.1, 0.07, 0.07), 5)
	for side in PackedFloat32Array([-1.0, 1.0]):
		AnimalNatural._eye(tool, skull, 1.9, side * 1.15, 0.045 * s, Color(0.06, 0.05, 0.05), false)
		# Small round ears, set low and far back, hardly out of the fur.
		var ear_at := skull.surface(1.25, side * 0.95) + Vector3(-side * 0.02, -0.02, 0.0) * s
		AnimalNatural._leaf(tool, ear_at, [Vector3.ZERO, Vector3(side * 0.03, 0.08, 0.0) * s],
			[0.09 * s, 0.07 * s], [0.03 * s, 0.025 * s], Vector3(0.0, 0.0, 1.0), 0.03 * s, 6, AnimalNatural._flat(coat.darkened(0.3)))
		# The two orange front teeth, hanging from the lip.
		AnimalNatural._leaf(tool, (tip - (nose["T"] as Vector3) * 0.06 * s) + Vector3(side * 0.045 * s, -0.045 * s, 0.0),
			[Vector3.ZERO, Vector3(0.0, -0.09, -0.01) * s], [0.045 * s, 0.04 * s], [0.035 * s, 0.03 * s],
			Vector3(0.0, 0.0, 1.0), 0.02 * s, 5, AnimalNatural._flat(ORANGE))
	return skull.at(0.0)["c"]

## The squirrel's tail only: the beaver's paddle is part of its body.
static func tail(coat: Color, s: float, tool: SurfaceTool) -> void:
	# From inside the haunch, back, up and curling forward over the back. It is
	# seen from the side, so it is broad in the plane of the curl and a little
	# thinner across.
	var loft := AnimalLoft.make(AnimalNatural._rings(s, [
		[0.0, 0.75, 0.62, 0.22, 0.20, 0.20], [0.0, 0.82, 1.02, 0.30, 0.26, 0.26],
		[0.0, 1.25, 1.34, 0.36, 0.30, 0.30], [0.0, 1.85, 1.38, 0.40, 0.32, 0.32],
		[0.0, 2.36, 1.12, 0.38, 0.32, 0.32], [0.0, 2.62, 0.72, 0.30, 0.26, 0.26],
		[0.0, 2.58, 0.45, 0.15, 0.14, 0.14],
	]), Vector3.RIGHT, 8, 2, 0.0, 0.12 * s)
	loft.paint = func(_p: Vector3, along: float, _a: float) -> Color:
		# Lighter at the tip, and ringed faintly like a tail that is combed.
		var c := coat.darkened(0.04).lerp(coat.lightened(0.3), smoothstep(0.55, 1.0, along))
		return c.darkened(0.08 * smoothstep(0.2, 0.7, sin(along * 30.0)))
	loft.emit(tool)

## The rows of one leg, how far its foot reaches below the sole row, its paint
## and its length, for `AnimalNatural.leg`. `height` is the hip's height above
## the ground; a squirrel's arm is `ARM` long whatever it is.
static func leg(kind: StringName, front: bool, coat: Color, s: float, height: float, hip: Vector3) -> Array:
	var h := height / s
	var sole := 0.07
	var rows: Array
	var paint: Callable
	if kind == SQUIRREL:
		if front:
			h = ARM
			rows = [
				[0.0, 0.2, 0.0, 0.15, 0.17, 0.17], [0.0, -0.1, -0.04, 0.10, 0.11, 0.11],
				[0.0, -0.35, -0.14, 0.075, 0.08, 0.08], [0.0, -(ARM - sole), -0.22, 0.09, 0.1, 0.1],
			]
		else:
			# A big haunch, a thin ankle and a long foot that lies forward.
			rows = [
				[0.0, 0.30, 0.05, 0.22, 0.32, 0.30], [0.0, -0.10, 0.04, 0.20, 0.26, 0.24],
				[0.0, -0.45, -0.02, 0.09, 0.10, 0.09], [0.0, -(h - sole), -0.12, 0.10, 0.09, 0.30],
			]
		var reach := h
		paint = func(p: Vector3, _t: float, _a: float) -> Color:
			return coat.darkened(0.06).lerp(coat.darkened(0.3), smoothstep(-0.3, -reach + 0.1, (p.y - hip.y) / s))
	else:
		if front:
			rows = [
				[0.0, 0.30, 0.0, 0.20, 0.28, 0.28], [0.0, -0.10, 0.0, 0.19, 0.24, 0.24],
				[0.0, -0.45, 0.0, 0.13, 0.15, 0.15], [0.0, -(h - sole), -0.06, 0.13, 0.12, 0.2],
			]
		else:
			rows = [
				[0.0, 0.30, 0.06, 0.22, 0.32, 0.32], [0.0, -0.10, 0.05, 0.21, 0.28, 0.27],
				[0.0, -0.45, 0.02, 0.14, 0.16, 0.16], [0.0, -(h - sole), -0.1, 0.15, 0.12, 0.30],
			]
		var reach := h
		paint = func(p: Vector3, _t: float, _a: float) -> Color:
			return coat.darkened(0.14).lerp(coat.darkened(0.55), smoothstep(-0.4, -reach + 0.1, (p.y - hip.y) / s))
	return [rows, sole, paint, h]
