class_name PitchMarkings
extends Node3D

## The paint on the pitch and the flags in its corners.
##
## The lines used to be painted into the terrain's vertex colours, which cannot
## work at this size: the ground is sampled every metre and a line is eleven
## centimetres wide, so a line was either missed or smeared across a whole
## quad. They are geometry instead: every line is a flat ribbon in ONE mesh, laid
## a hand's breadth above the grass, so it is as sharp as the screen and costs
## one draw call and no per-frame work. The ribbon follows the ground height at
## every vertex, so it would stay on the grass were the pitch ever not level.
##
## Like the rest of the football ground this node sits at the origin and its
## children carry world coordinates.

## How far the paint floats above the grass, in metres. Three centimetres is
## far more than the depth buffer can confuse with the terrain at a camera's
## furthest reach, and far less than a child's boot can see.
const LIFT := 0.03

## No stretch of a ribbon is longer than this between height samples.
const MAX_SEGMENT := 2.0

## The flag cloth: a triangle on the pole, this long and this tall.
const CLOTH_LENGTH := 0.5
const CLOTH_HEIGHT := 0.3
const CLOTH_COLOUR := Color(1.0, 0.78, 0.08)
const POLE_COLOUR := Color(0.96, 0.96, 0.94)

var _flags: Array[Flag] = []

func _init(field: HeightField) -> void:
	position = Vector3.ZERO
	name = "PitchMarkings"
	var centre := Pitch.centre()

	var paint := MeshInstance3D.new()
	paint.name = "Lines"
	paint.mesh = build_paint(centre, func(x: float, z: float) -> float: return field.height_at(x, z))
	paint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(paint)

	var cloth := _cloth_mesh()
	for spot in Pitch.corner_flag_spots():
		var foot := Vector3(centre.x + spot.x, 0.0, centre.z + spot.y)
		foot.y = field.height_at(foot.x, foot.z)
		var flag := Flag.new()
		flag.name = "CornerFlag"
		flag.position = foot + Vector3.UP * (Pitch.FLAG_POLE_HEIGHT - CLOTH_HEIGHT * 0.5 - 0.03)
		var piece := MeshInstance3D.new()
		piece.mesh = cloth
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flag.add_child(piece)
		add_child(flag)
		_flags.append(flag)

	var poles := MeshInstance3D.new()
	poles.name = "Poles"
	poles.mesh = _poles_mesh(centre, field)
	poles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(poles)

## How many corner flags stand on the pitch. For the checks.
func flag_count() -> int:
	return _flags.size()

## Where each flag's pole stands, on the ground. For the checks.
func flag_feet() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for flag in _flags:
		out.append(Vector3(flag.position.x, 0.0, flag.position.z))
	return out

## The paint as one mesh: ribbons for the lines, small discs for the spots.
## `height` answers the grass height at (x, z). Static and free of the scene so
## the checks can build it and look at every vertex.
static func build_paint(centre: Vector3, height: Callable) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := Pitch.LINE_WIDTH * 0.5
	for line in Pitch.marking_lines():
		_ribbon(tool, _resampled(line), half, centre, height)
	for spot in Pitch.marking_spots():
		_disc(tool, spot, Pitch.SPOT_RADIUS, centre, height)
	var mesh := tool.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = TerrainSpec.COLOR_PITCH_LINE
	material.roughness = 1.0
	# Seen from above only, but a ribbon's winding is not worth being wrong about.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	return mesh

## `line` with extra points so no stretch is longer than MAX_SEGMENT.
static func _resampled(line: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array([line[0]])
	for i in range(1, line.size()):
		var from := line[i - 1]
		var to := line[i]
		var pieces := maxi(1, int(ceil(from.distance_to(to) / MAX_SEGMENT)))
		for k in range(1, pieces + 1):
			out.append(from.lerp(to, float(k) / float(pieces)))
	return out

static func _lift(at: Vector2, centre: Vector3, height: Callable) -> Vector3:
	var x := centre.x + at.x
	var z := centre.z + at.y
	return Vector3(x, float(height.call(x, z)) + LIFT, z)

## A strip of width 2 * half along `line`, mitred at the bends so a corner of a
## box is a square corner and not two overlapping rectangles' notch.
static func _ribbon(tool: SurfaceTool, line: PackedVector2Array, half: float, centre: Vector3, height: Callable) -> void:
	var closed := line[0].is_equal_approx(line[line.size() - 1])
	var count := line.size() - 1 if closed else line.size()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in count:
		var before := Vector2.ZERO
		var after := Vector2.ZERO
		if i > 0:
			before = (line[i] - line[i - 1]).normalized()
		elif closed:
			before = (line[0] - line[count - 1]).normalized()
		if i < line.size() - 1:
			after = (line[i + 1] - line[i]).normalized()
		elif closed:
			after = (line[0] - line[count - 1]).normalized()
		if before == Vector2.ZERO:
			before = after
		if after == Vector2.ZERO:
			after = before
		var n1 := Vector2(-before.y, before.x)
		var n2 := Vector2(-after.y, after.x)
		var mitre := n1 + n2
		# 1 + n1.n2 is zero only for a line doubling straight back on itself.
		var scale := half / maxf(0.2, 1.0 + n1.dot(n2))
		left.append(line[i] + mitre * scale)
		right.append(line[i] - mitre * scale)
	var segments := count if closed else count - 1
	for i in segments:
		var j := (i + 1) % count
		var a := _lift(left[i], centre, height)
		var b := _lift(right[i], centre, height)
		var c := _lift(left[j], centre, height)
		var d := _lift(right[j], centre, height)
		for v: Vector3 in [a, b, c, c, b, d]:
			tool.set_normal(Vector3.UP)
			tool.add_vertex(v)

static func _disc(tool: SurfaceTool, at: Vector2, radius: float, centre: Vector3, height: Callable) -> void:
	var middle := _lift(at, centre, height)
	var sides := 16
	for i in sides:
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		for v: Vector3 in [
			middle,
			_lift(at + Vector2(cos(a0), sin(a0)) * radius, centre, height),
			_lift(at + Vector2(cos(a1), sin(a1)) * radius, centre, height),
		]:
			tool.set_normal(Vector3.UP)
			tool.add_vertex(v)

## The cloth of every flag, shared: a triangle hanging from the pole at the
## node's origin and pointing along +x, which is what Flag turns to the wind.
static func _cloth_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v: Vector3 in [
		Vector3(0.0, CLOTH_HEIGHT * 0.5, 0.0),
		Vector3(0.0, -CLOTH_HEIGHT * 0.5, 0.0),
		Vector3(CLOTH_LENGTH, 0.0, 0.0),
	]:
		tool.set_normal(Vector3.BACK)
		tool.add_vertex(v)
	var mesh := tool.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = CLOTH_COLOUR
	material.roughness = 0.8
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	return mesh

## The four poles as one mesh. No collision: a pole two and a half centimetres
## thick is not worth a body, and a child can neither be trapped by it nor
## need it.
func _poles_mesh(centre: Vector3, field: HeightField) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 6
	for spot in Pitch.corner_flag_spots():
		var x := centre.x + spot.x
		var z := centre.z + spot.y
		var base := Vector3(x, field.height_at(x, z), z)
		var r := Pitch.FLAG_POLE_RADIUS
		for i in sides:
			var a0 := TAU * float(i) / float(sides)
			var a1 := TAU * float(i + 1) / float(sides)
			var p0 := Vector3(cos(a0) * r, 0.0, sin(a0) * r)
			var p1 := Vector3(cos(a1) * r, 0.0, sin(a1) * r)
			var up := Vector3.UP * Pitch.FLAG_POLE_HEIGHT
			var normal := (p0 + p1).normalized()
			for v: Vector3 in [p0, p1, p0 + up, p0 + up, p1, p1 + up]:
				tool.set_normal(normal)
				tool.add_vertex(base + v)
	var mesh := tool.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = POLE_COLOUR
	material.roughness = 0.6
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	return mesh
