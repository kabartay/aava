class_name AnimalLoft
extends RefCounted

## A smooth shape swept along a curve: the way an animal's body, neck, head,
## legs and tail are made now.
##
## They used to be spheres, cylinders and boxes laid next to each other, and
## every place two of them met was a seam, a lump or a crease that no amount of
## tuning would round off — an animal is one skin. A loft is one skin: a ring
## of vertices (an ellipse, or squarer than one) is set at each key along a
## spline, the rings are joined to their neighbours with *shared* vertices, so
## the normals run smoothly from one to the next, and the two ends close in a
## rounded cap. Colour belongs to the vertex, so it can change along the body
## and round it.
##
## A key is seven numbers, in a PackedFloat32Array: the centre of the ring
## (x, y, z), its half-width across, its height above the centre and below it —
## separate, so a belly can be flatter than a back — and how square it is
## (2 an ellipse, more a rounded box). `key()` writes one.
##
## The ring's "up" is the reference direction with the spine's own direction
## taken out of it, so a body is swept with the reference up, a leg with it
## pointing along the animal, an ear with it through the thin way.

const KEY_SIZE := 7

var keys: Array = []
var reference := Vector3.UP
var segments := 12
## Rings between one key and the next.
var steps := 2
## How far the shape carries on beyond its first and last key before it closes,
## along the way the spine was heading. Zero closes it flat.
var cap_start := 0.0
var cap_end := 0.0
## Colour for a vertex: Callable(position, along 0..1, angle round the ring) ->
## Color. The angle is 0 on the ring's upper side and PI on its lower.
var paint := Callable()
## How far to push a vertex out of its ring, as a fraction of its distance from
## the centre: Callable(position) -> float. For a fleece that is not quite round.
var bump := Callable()

## Where the whole shape is moved to, so a leg built about its hip can be
## baked into a body at that hip.
var origin := Vector3.ZERO
## Rings of a cap, as how far along the cap each sits. The radius there is the
## ellipse's: the square root of what is left. Few of them: an animal is about
## fifteen hundred triangles, and the big shapes are what is looked at.
var cap_rings: Array = [0.55, 0.88]

static func key(centre: Vector3, across: float, up: float, down: float, squareness := 2.0) -> PackedFloat32Array:
	return PackedFloat32Array([centre.x, centre.y, centre.z, across, up, down, squareness])

static func make(
	rings: Array, reference_dir: Vector3, around := 12, between := 2, start := 0.0, end := 0.0
) -> AnimalLoft:
	var loft := AnimalLoft.new()
	loft.keys = rings
	loft.reference = reference_dir
	loft.segments = around
	loft.steps = between
	loft.cap_start = start
	loft.cap_end = end
	return loft

## The ring's numbers at a place along the spine, 0 at the first key and
## `keys.size() - 1` at the last, by Catmull-Rom through the keys.
func _blend(t: float) -> PackedFloat32Array:
	var last := keys.size() - 1
	t = clampf(t, 0.0, float(last))
	var i := mini(int(floor(t)), last - 1)
	var f := t - float(i)
	var p0: PackedFloat32Array = keys[maxi(i - 1, 0)]
	var p1: PackedFloat32Array = keys[i]
	var p2: PackedFloat32Array = keys[i + 1]
	var p3: PackedFloat32Array = keys[mini(i + 2, last)]
	var out := PackedFloat32Array()
	out.resize(KEY_SIZE)
	for k in KEY_SIZE:
		out[k] = 0.5 * (
			2.0 * p1[k] + (p2[k] - p0[k]) * f
			+ (2.0 * p0[k] - 5.0 * p1[k] + 4.0 * p2[k] - p3[k]) * f * f
			+ (3.0 * p1[k] - p0[k] - 3.0 * p2[k] + p3[k]) * f * f * f
		)
	return out

## Everything about the ring at `t`: its centre, the three directions of its
## frame (along the spine, across, and up), and its sizes.
func at(t: float) -> Dictionary:
	var k := _blend(t)
	var last := float(keys.size() - 1)
	var behind := _blend(maxf(t - 0.02, 0.0))
	var ahead := _blend(minf(t + 0.02, last))
	var along := Vector3(ahead[0] - behind[0], ahead[1] - behind[1], ahead[2] - behind[2]).normalized()
	var up := reference - along * reference.dot(along)
	if up.length_squared() < 0.0001:
		# The spine runs along the reference: any way across will do.
		up = along.cross(Vector3.RIGHT) if absf(along.x) < 0.9 else along.cross(Vector3.UP)
	up = up.normalized()
	var across := along.cross(up).normalized()
	return {
		"c": Vector3(k[0], k[1], k[2]) + origin, "T": along, "S": across, "U": up,
		"rx": maxf(k[3], 0.001), "ru": maxf(k[4], 0.001), "rd": maxf(k[5], 0.001),
		"n": maxf(k[6], 1.5),
	}

## A point on the skin at `t` and angle `a` (0 on top, PI under, PI/2 to the
## +across side), pushed `out` further from the spine.
func surface(t: float, a: float, out := 0.0) -> Vector3:
	var ring := at(t)
	var p := _ring_point(ring, a, 1.0, Vector3.ZERO)
	var from: Vector3 = ring["c"]
	return p + (p - from).normalized() * out

func _ring_point(ring: Dictionary, a: float, shrink: float, shift: Vector3) -> Vector3:
	var s := sin(a)
	var c := cos(a)
	var power := 2.0 / float(ring["n"])
	var x := float(ring["rx"]) * signf(s) * pow(absf(s), power) * shrink
	var y := (float(ring["ru"]) if c >= 0.0 else float(ring["rd"])) * signf(c) * pow(absf(c), power) * shrink
	var centre: Vector3 = ring["c"]
	var side: Vector3 = ring["S"]
	var up: Vector3 = ring["U"]
	return centre + shift + side * x + up * y

## Add the loft to `tool` as plain triangles with a colour at every corner. The
## caller generates the normals once everything is in: vertices at one place
## are smoothed together, and the ones here are shared exactly.
func emit(tool: SurfaceTool) -> void:
	var rings: Array[PackedVector3Array] = []
	var tones: Array[PackedColorArray] = []
	var specs: Array = []
	var last := keys.size() - 1
	var first := at(0.0)
	var final := at(float(last))
	if cap_start > 0.0:
		for i in cap_rings.size():
			var u: float = cap_rings[cap_rings.size() - 1 - i]
			specs.append([0.0, sqrt(1.0 - u * u), -(first["T"] as Vector3) * cap_start * u])
	for i in last:
		for s in steps:
			specs.append([float(i) + float(s) / float(steps), 1.0, Vector3.ZERO])
	specs.append([float(last), 1.0, Vector3.ZERO])
	if cap_end > 0.0:
		for u: float in cap_rings:
			specs.append([float(last), sqrt(1.0 - u * u), (final["T"] as Vector3) * cap_end * u])
	var count := specs.size()
	for r in count:
		var spec: Array = specs[r]
		var ring := at(float(spec[0]))
		var points := PackedVector3Array()
		var colours := PackedColorArray()
		for j in segments:
			var angle := TAU * float(j) / float(segments)
			var p := _ring_point(ring, angle, float(spec[1]), spec[2])
			if bump.is_valid():
				var from: Vector3 = (ring["c"] as Vector3) + (spec[2] as Vector3)
				p = from + (p - from) * (1.0 + float(bump.call(p)))
			points.append(p)
			colours.append(_tone(p, float(r) / float(count + 1), angle))
		rings.append(points)
		tones.append(colours)
	# The two poles close the ends: one vertex each, shared by a fan.
	var start_pole: Vector3 = (first["c"] as Vector3) - (first["T"] as Vector3) * cap_start
	var end_pole: Vector3 = (final["c"] as Vector3) + (final["T"] as Vector3) * cap_end
	var start_tone := _tone(start_pole, 0.0, 0.0)
	var end_tone := _tone(end_pole, 1.0, 0.0)

	# Which way round to wind the triangles is found from the shape itself
	# rather than worked out from the frame: Godot faces a triangle that runs
	# clockwise as seen from outside, so its right-hand normal points inward.
	var flip := false
	var mid := count / 2
	var probe_a: Vector3 = rings[mid][0]
	var probe_b: Vector3 = rings[mid][1]
	var probe_c: Vector3 = rings[mid + 1 if mid + 1 < count else mid - 1][0]
	var middle_ring: Dictionary = at(float((specs[mid] as Array)[0]))
	var outward := probe_a - (middle_ring["c"] as Vector3)
	var sense := (probe_b - probe_a).cross(probe_c - probe_a).dot(outward)
	if mid + 1 >= count:
		sense = -sense
	flip = sense > 0.0

	for r in count + 1:
		for j in segments:
			var j2 := (j + 1) % segments
			var a: Vector3
			var b: Vector3
			var c: Vector3
			var d: Vector3
			var ta: Color
			var tb: Color
			var tc: Color
			var td: Color
			if r == 0:
				a = start_pole; b = start_pole
				ta = start_tone; tb = start_tone
			else:
				a = rings[r - 1][j]; b = rings[r - 1][j2]
				ta = tones[r - 1][j]; tb = tones[r - 1][j2]
			if r == count:
				c = end_pole; d = end_pole
				tc = end_tone; td = end_tone
			else:
				c = rings[r][j2]; d = rings[r][j]
				tc = tones[r][j2]; td = tones[r][j]
			# The quad a, b, c, d, as two triangles; the one that has
			# collapsed to a point at a pole is left out.
			if r != 0:
				_triangle(tool, a, ta, b, tb, d, td, flip)
			if r != count:
				_triangle(tool, b, tb, c, tc, d, td, flip)

func _triangle(
	tool: SurfaceTool, a: Vector3, ta: Color, b: Vector3, tb: Color, c: Vector3, tc: Color, flip: bool
) -> void:
	tool.set_color(ta)
	tool.add_vertex(a)
	if flip:
		tool.set_color(tc)
		tool.add_vertex(c)
		tool.set_color(tb)
		tool.add_vertex(b)
	else:
		tool.set_color(tb)
		tool.add_vertex(b)
		tool.set_color(tc)
		tool.add_vertex(c)

func _tone(p: Vector3, along: float, angle: float) -> Color:
	if paint.is_valid():
		return paint.call(p, along, angle)
	return Color.WHITE

## A small ellipsoid, for an eye or a nostril: a loft of its own along Z.
static func ball(tool: SurfaceTool, centre: Vector3, radii: Vector3, colour: Color, around := 6) -> void:
	var rings: Array = []
	# Two rings and a point at each end, which is a diamond on paper and a
	# bead at the size of an eye, for a quarter of the triangles of a sphere.
	for z: float in [-0.5, 0.5]:
		rings.append(key(centre + Vector3(0.0, 0.0, z * radii.z), radii.x * 0.87, radii.y * 0.87, radii.y * 0.87))
	var loft := make(rings, Vector3.UP, around, 1, radii.z * 0.5, radii.z * 0.5)
	loft.cap_rings = []
	loft.paint = func(_p: Vector3, _along: float, _angle: float) -> Color: return colour
	loft.emit(tool)
