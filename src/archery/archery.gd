class_name Archery
extends Node3D

## The bow, the arrows, and the straw butts they are aimed at.
##
## Target shooting only, and that is enforced by construction rather than by
## intention: an arrow is tested against the painted faces and against the
## ground, and against nothing else at all. There is no code path here that can
## reach a living thing, and a check in ci_check.gd reads this file to keep it
## that way. The creatures in this valley exist to be looked after, and a game
## that lets a child discover otherwise has already decided that for them.

signal hit_target(index: int, ring: int, points: int)
signal missed()

## How long an arrow flies before it gives up, and how long it lingers where it
## landed so a child can see where they hit.
const MAX_FLIGHT := 6.0
const LINGER := 2.5

## Arrow speed at a bare touch and at full draw.
const SPEED_MIN := 14.0
const SPEED_MAX := 44.0

const GRAVITY := 9.8

## Three butts, spread across and stepped back, so they are three different
## shots rather than the same shot three times.
const TARGET_COUNT := 3
const TARGET_SPACING := 7.0

## Radii of gold, red and white, and what each is worth. Hitting nearer the
## middle paying more is the entire game.
## Typed Arrays rather than Packed ones: a PackedFloat32Array literal is not a
## constant expression in GDScript, which is a trap this project has now fallen
## into twice — see LESSONS.md.
const RINGS: Array[float] = [0.24, 0.52, 0.86]
const RING_POINTS: Array[int] = [5, 3, 1]

var field: HeightField

var _origin := Vector3.ZERO
var _facing := Vector3.FORWARD
var _targets: Array[Dictionary] = []
var _arrows: Array[Dictionary] = []

func _init(height_field: HeightField) -> void:
	field = height_field

## Put the range somewhere flat. Called once, near the camp.
func stand_up(at: Vector3, facing: Vector3) -> void:
	_origin = at
	_origin.y = field.height_at(at.x, at.z)

	_facing = facing
	_facing.y = 0.0
	if _facing.length_squared() < 0.01:
		_facing = Vector3.FORWARD
	_facing = _facing.normalized()

	var across := Vector3(_facing.z, 0.0, -_facing.x)
	for i in TARGET_COUNT:
		var spot := (
			_origin
			+ _facing * (9.0 + float(i) * 4.5)
			+ across * (float(i) - 1.0) * TARGET_SPACING * 0.5
		)
		spot.y = field.height_at(spot.x, spot.z) + 1.05
		_targets.append({"centre": spot, "index": i})
		_build_butt(spot)

func target_count() -> int:
	return _targets.size()

func target_centre(index: int) -> Vector3:
	return _targets[index]["centre"]

func shooting_line() -> Vector3:
	return _origin

func arrows_in_flight() -> int:
	var flying := 0
	for arrow in _arrows:
		if not arrow["landed"]:
			flying += 1
	return flying

## Loose an arrow. `charge` is 0 to 1 from the drawn bow, and `aim_height` lifts
## the shot the same way the football kick does.
func loose(from: Vector3, direction: Vector3, charge: float, aim_height: float) -> void:
	var speed := lerpf(SPEED_MIN, SPEED_MAX, clampf(charge, 0.0, 1.0))

	var launch := direction
	if launch.length_squared() < 0.001:
		launch = _facing
	launch = launch.normalized()

	# The arrow leaves along the line the child is looking down, plus whatever
	# extra lift they asked for. An earlier version flattened the aim and then
	# added a fixed upward nudge, which sent every shot sailing 1.2 m over the
	# gold at nine metres: aiming at the middle guaranteed a miss. Where the
	# player looks is where it goes, and the drop over these distances is small
	# enough that a child can correct for it by eye.
	if not is_zero_approx(aim_height):
		launch = (launch + Vector3.UP * clampf(aim_height, -0.9, 0.9)).normalized()

	var node := _build_arrow()
	node.position = from
	_arrows.append({
		"at": from,
		"velocity": launch * speed,
		"age": 0.0,
		"landed": false,
		"rest": 0.0,
		"node": node,
	})

func _physics_process(delta: float) -> void:
	var finished: Array[Dictionary] = []

	for arrow in _arrows:
		var node: Node3D = arrow["node"]
		if not is_instance_valid(node):
			finished.append(arrow)
			continue

		if arrow["landed"]:
			# Counted separately from flight time, so a shot that lands early
			# still gets its full moment on display.
			arrow["rest"] = float(arrow["rest"]) + delta
			if float(arrow["rest"]) > LINGER:
				node.queue_free()
				finished.append(arrow)
			continue

		arrow["age"] = float(arrow["age"]) + delta

		var velocity: Vector3 = arrow["velocity"]
		velocity.y -= GRAVITY * delta
		var was: Vector3 = arrow["at"]
		var now := was + velocity * delta
		arrow["velocity"] = velocity
		arrow["at"] = now

		# Built rather than assigned, for the same reason as the butts: an arrow
		# loosed on the frame the range was created is not in the tree yet.
		node.position = now
		# Pointed along its flight, which is most of what makes it read as an
		# arrow rather than a stick sliding through the air.
		if velocity.length_squared() > 0.01:
			node.transform = Transform3D(
				Basis.looking_at(velocity.normalized(), Vector3.UP), now
			)

		var struck := _check_hit(was, now)
		if struck >= 0:
			arrow["landed"] = true
		elif now.y <= field.height_at(now.x, now.z):
			arrow["landed"] = true
			missed.emit()
		elif float(arrow["age"]) > MAX_FLIGHT:
			arrow["landed"] = true
			missed.emit()

	for done in finished:
		_arrows.erase(done)

## Did the step from `was` to `now` cross a target face?
##
## Tested as a segment against the plane of the face, not as a point inside a
## volume: at 44 m/s an arrow covers most of a metre between physics frames, and
## a point test lets it pass clean through the gold and land in the grass
## behind. This is the same class of bug as a fast football tunnelling through a
## goalpost, which is why the balls use continuous collision detection.
func _check_hit(was: Vector3, now: Vector3) -> int:
	for target in _targets:
		var centre: Vector3 = target["centre"]
		var normal := -_facing
		var before := (was - centre).dot(normal)
		var after := (now - centre).dot(normal)
		# Same side of the face at both ends of the step: no crossing.
		if (before > 0.0) == (after > 0.0):
			continue

		var span := before - after
		if absf(span) < 0.0001:
			continue
		var crossing := was.lerp(now, clampf(before / span, 0.0, 1.0))
		var offset := (crossing - centre).length()
		if offset > RINGS[RINGS.size() - 1]:
			continue

		for ring in RINGS.size():
			if offset <= RINGS[ring]:
				hit_target.emit(int(target["index"]), ring, int(RING_POINTS[ring]))
				return int(target["index"])
	return -1

## A straw butt: a painted face on a stubby trestle, so a child can see what
## they are aiming at from the shooting line.
func _build_butt(centre: Vector3) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var straw := Color(0.86, 0.78, 0.54)
	var colours: Array[Color] = [
		Color(0.96, 0.80, 0.24), Color(0.86, 0.30, 0.26), Color(0.94, 0.94, 0.92),
	]

	# Largest first, each one a little proud of the last, so the rings do not
	# fight for the same depth and flicker.
	for ring in range(RINGS.size() - 1, -1, -1):
		var disc := CylinderMesh.new()
		disc.top_radius = RINGS[ring]
		disc.bottom_radius = RINGS[ring]
		disc.height = 0.08
		disc.radial_segments = 18
		disc.rings = 1
		_add(
			tool, disc,
			Transform3D(
				Basis(Vector3.RIGHT, deg_to_rad(90.0)),
				Vector3(0.0, 0.0, 0.03 * float(ring))
			),
			colours[ring]
		)

	var backing := CylinderMesh.new()
	backing.top_radius = RINGS[RINGS.size() - 1] + 0.09
	backing.bottom_radius = RINGS[RINGS.size() - 1] + 0.09
	backing.height = 0.20
	backing.radial_segments = 18
	backing.rings = 1
	_add(tool, backing, Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(90.0)), Vector3(0.0, 0.0, 0.20)
	), straw)

	for side in PackedFloat32Array([-1.0, 1.0]):
		var leg := CylinderMesh.new()
		leg.top_radius = 0.05
		leg.bottom_radius = 0.06
		leg.height = 1.05
		leg.radial_segments = 6
		leg.rings = 1
		_add(tool, leg, Transform3D(
			Basis(Vector3.RIGHT, deg_to_rad(side * 8.0)),
			Vector3(side * 0.38, -0.62, 0.18)
		), Color(0.46, 0.34, 0.22))

	tool.generate_normals()
	tool.set_material(_material())

	var butt := MeshInstance3D.new()
	butt.mesh = tool.commit()
	# The transform is built rather than assigned through global_position and
	# look_at, because those need the node to already be inside the tree — and
	# stand_up is called the moment the range is created. Same trap as the
	# footballs that appeared 56 m from where they were put; see LESSONS.md.
	butt.transform = Transform3D(
		Basis.looking_at(-_facing, Vector3.UP), centre
	)
	add_child(butt)

func _build_arrow() -> Node3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Built lying along -Z, because look_at points -Z down the line of flight.
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.014
	shaft.bottom_radius = 0.014
	shaft.height = 0.64
	shaft.radial_segments = 5
	shaft.rings = 1
	_add(tool, shaft, Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(90.0)), Vector3.ZERO
	), Color(0.74, 0.60, 0.40))

	var head := CylinderMesh.new()
	head.top_radius = 0.0
	head.bottom_radius = 0.028
	head.height = 0.11
	head.radial_segments = 5
	head.rings = 1
	_add(tool, head, Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(90.0)), Vector3(0.0, 0.0, -0.37)
	), Color(0.70, 0.72, 0.76))

	var fletch := BoxMesh.new()
	fletch.size = Vector3(0.006, 0.08, 0.13)
	_add(tool, fletch, Transform3D(Basis(), Vector3(0.0, 0.0, 0.27)), Color(0.90, 0.36, 0.32))

	tool.generate_normals()
	tool.set_material(_material())

	var node := MeshInstance3D.new()
	node.mesh = tool.commit()
	add_child(node)
	return node

## One material for the whole range. Vertex-coloured like everything else in the
## valley, and shipped with the mesh so nothing can attach the geometry without
## it — see LESSONS.md.
static func _material() -> StandardMaterial3D:
	if _shared == null:
		_shared = StandardMaterial3D.new()
		_shared.vertex_color_use_as_albedo = true
		_shared.vertex_color_is_srgb = true
		_shared.roughness = 0.86
	return _shared

static var _shared: StandardMaterial3D = null

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
