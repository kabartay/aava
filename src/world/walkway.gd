class_name Walkway
extends Node3D

## The two moving walkways: flat belts that carry you along, side by side and
## running opposite ways, so a child can ride up one and back down the other.
##
## Nothing about them moves. A belt is a static body with a constant velocity
## written on it, which is how a conveyor is made: Godot pushes whatever stands
## on it at that speed, and the slats only have to look like they are going
## somewhere. A belt built out of moving parts would be fifteen metres of
## physics for an effect that is one line.

## How long each belt is, how far apart they stand, and how fast they run. Two
## metres a second is a brisk walk — faster than that and a six-year-old cannot
## get off at the end.
## Half again as long as it was: fifteen metres of belt is over in seven
## seconds, and the point of a moving walkway is the stretch where you are
## being carried and doing nothing.
const LENGTH := 30.0
const WIDTH := 1.7
const GAP := 0.9
const SPEED := 2.0
const TOP := 0.32
## How long the ramp onto a belt is. Long enough that its slope is a walk: a
## third of a metre over two is about one in six.
const RAMP_LENGTH := 2.0

const TREAD := Color(0.26, 0.28, 0.32)
const SLAT := Color(0.34, 0.37, 0.42)
const SIDE := Color(0.58, 0.55, 0.52)
const ARROW := Color(0.95, 0.85, 0.35)

var _sides: StaticBody3D
## The scrolling treads of each belt.
var _belts: Array[Dictionary] = []

## How many treads a belt carries, and how far apart they lie.
const TREAD_SPACING := 1.6
const TREADS := int(LENGTH / TREAD_SPACING)

func _init(at: Vector3) -> void:
	name = "Walkway"
	position = at

	_sides = StaticBody3D.new()
	_sides.name = "Sides"
	add_child(_sides)

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	for side in 2:
		# One each way: the left belt carries you north, the right one south.
		var heading := 1.0 if side == 0 else -1.0
		var offset := (WIDTH + GAP) * (float(side) - 0.5)
		_build_belt(tool, offset, heading)

	tool.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.7
	tool.set_material(material)
	var drawn := MeshInstance3D.new()
	drawn.name = "Belts"
	drawn.mesh = tool.commit()
	add_child(drawn)

func _build_belt(tool: SurfaceTool, offset: float, heading: float) -> void:
	# The tread, and the ramps at each end so a child walks on rather than
	# steps up.
	var tread := BoxMesh.new()
	tread.size = Vector3(WIDTH, 0.18, LENGTH)
	Park._add(tool, tread, Transform3D(Basis(), Vector3(offset, TOP - 0.09, 0.0)), TREAD)

	# The ramps at each end, and they are solid.
	#
	# They were scenery: a painted slope with nothing behind it, and the belt
	# itself a step a third of a metre high. A character body does not climb
	# steps — it climbs slopes — so a child walked into the end of a walkway
	# and stopped, and the ride could not be got onto at all.
	for end: float in [-1.0, 1.0]:
		var rise := atan2(TOP, RAMP_LENGTH)
		var ramp := BoxMesh.new()
		ramp.size = Vector3(WIDTH, 0.12, Vector2(RAMP_LENGTH, TOP).length())
		# Tipped so the outer end meets the sand and the inner end meets the
		# belt. The sign was the other way round at first, which built a wedge
		# rising away from the ride: a wall at the mouth of it.
		var stand := Transform3D(
			Basis(Vector3.RIGHT, end * rise),
			# Half the slab's thickness down from the slope's middle, so its
			# *top* runs from the sand to the belt. At -0.02 the surface stood
			# four centimetres proud all the way, a lip at the sand and a step
			# onto the belt, which is exactly what the ramps are there to avoid.
			Vector3(offset, TOP * 0.5 - 0.06, end * (LENGTH * 0.5 + RAMP_LENGTH * 0.5))
		)
		Park._add(tool, ramp, stand, SIDE)
		Park._solid(_sides, ramp.size, stand)

	# The treads, and an arrow every few metres pointing the way the belt runs.
	#
	# They move. A belt that carries a child while its slats stand still reads
	# as a painted strip that happens to push you, and the first thing anybody
	# asked about these was whether they were working at all. They are drawn
	# as one multimesh each and scrolled along, which costs one draw call and
	# is the whole difference between a machine and a floor.
	#
	# The arrows used to be built from the belt's own heading and came out
	# pointing back up it, which is worse than no arrow: a child reads the
	# arrow, steps on, and is carried the other way.
	var treads := MultiMeshInstance3D.new()
	treads.name = "Treads%s" % ("North" if heading > 0.0 else "South")
	var pattern := MultiMesh.new()
	pattern.transform_format = MultiMesh.TRANSFORM_3D
	pattern.mesh = _tread_mesh(heading)
	pattern.instance_count = TREADS
	treads.multimesh = pattern
	treads.position = Vector3(offset, TOP + 0.02, 0.0)
	add_child(treads)
	_belts.append({"node": treads, "heading": heading, "along": 0.0})

	# The sides, which are what makes it read as a walkway rather than a strip
	# of paint, and a handrail along each.
	for edge: float in [-1.0, 1.0]:
		# Standing on the sand, not hung from the belt's height: started at
		# `TOP` it left a third of a metre of daylight under a wall that
		# looked like a kerb, and the belt beside it floated.
		var wall := BoxMesh.new()
		wall.size = Vector3(0.14, TOP + 0.72, LENGTH)
		Park._add(
			tool, wall,
			Transform3D(Basis(), Vector3(offset + edge * (WIDTH * 0.5 + 0.07), (TOP + 0.72) * 0.5, 0.0)),
			SIDE
		)
		# Solid, so a child steps onto a belt at its ends rather than walking
		# in through its side onto the edge of a moving floor.
		Park._solid(
			_sides, wall.size,
			Transform3D(Basis(), Vector3(offset + edge * (WIDTH * 0.5 + 0.07), (TOP + 0.72) * 0.5, 0.0))
		)
		# The handrail rests on the wall's top, which is TOP + 0.72: it hung a
		# centimetre above it.
		var rail := BoxMesh.new()
		rail.size = Vector3(0.10, 0.10, LENGTH)
		Park._add(
			tool, rail,
			Transform3D(Basis(), Vector3(offset + edge * (WIDTH * 0.5 + 0.07), TOP + 0.76, 0.0)),
			TREAD
		)

	# And the belt itself: a static body that pushes whatever stands on it.
	var belt := StaticBody3D.new()
	belt.name = "Belt%s" % ("North" if heading > 0.0 else "South")
	# Negative z is north in this valley, so a belt heading north runs -z.
	belt.constant_linear_velocity = Vector3(0.0, 0.0, -heading * SPEED)
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH, 0.18, LENGTH)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = Vector3(offset, TOP - 0.09, 0.0)
	belt.add_child(collider)
	add_child(belt)

## Where the flattened arrowhead's middle lies, measured from a tread's own
## middle (which is 0.02 above the belt). The arrow is longer than the slat it
## is on, so it cannot rest on the slat: it was set 0.04 up, which left both of
## its ends hovering a few centimetres over the belt. Its underside is at about
## -0.023 here, which is the belt's own surface give or take three millimetres.
const ARROW_RISE := 0.0

## One tread: a slat across the belt, and on every sixth one an arrowhead
## pointing the way the belt is going.
func _tread_mesh(heading: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bar := BoxMesh.new()
	bar.size = Vector3(WIDTH - 0.12, 0.04, 0.26)
	Park._add(tool, bar, Transform3D(Basis(), Vector3.ZERO), SLAT)
	var head := CylinderMesh.new()
	head.top_radius = 0.0
	head.bottom_radius = 0.38
	head.height = 0.56
	head.radial_segments = 3
	head.rings = 1
	# North is -z in this valley, so a belt with a heading of one runs -z and
	# its arrow has to lie that way: the cylinder points along its own +y, and
	# turning it a quarter about x lays it along z.
	#
	# And then flattened, which is the part that was missing. A three-sided
	# cone laid on its side is a wedge with an edge along the top: from the
	# ground it read as a yellow fin standing up out of the belt rather than
	# as an arrow painted on it. Scaling after the turn squashes it into the
	# floor, where an arrow belongs.
	Park._add(
		tool, head,
		Transform3D(
			Basis(Vector3.RIGHT, heading * -PI * 0.5).scaled(Vector3(1.0, 0.12, 1.0)),
			Vector3(0.0, ARROW_RISE, 0.0)
		),
		ARROW
	)
	tool.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.7
	tool.set_material(material)
	return tool.commit()

func _physics_process(delta: float) -> void:
	for belt in _belts:
		var along := float(belt["along"]) + SPEED * delta
		if along > TREAD_SPACING:
			along -= TREAD_SPACING
		belt["along"] = along
		var node: MultiMeshInstance3D = belt["node"]
		var heading: float = belt["heading"]
		for tread in TREADS:
			node.multimesh.set_instance_transform(
				tread, Transform3D(Basis(), Vector3(0.0, 0.0, _tread_offset(along, heading, tread)))
			)

## Where one tread lies along its belt: laid out down it and scrolled along,
## wrapping round the far end, so what a child sees is treads going under their
## feet.
##
## Its own function because a multimesh cannot be read back without a screen —
## the transforms live on the rendering server — so this is the only part of
## the scroll a check can get at.
static func _tread_offset(along: float, heading: float, index: int) -> float:
	return -LENGTH * 0.5 + fposmod(
		TREAD_SPACING * float(index) + along * -heading, LENGTH
	)

## Where a tread on one of the belts is now. For the checks.
func tread_at(side: int, index: int) -> float:
	if side >= _belts.size():
		return 0.0
	return _tread_offset(float(_belts[side]["along"]), float(_belts[side]["heading"]), index)

## How far the park itself moves whoever is standing on a belt, this frame.
func carry(_at: Vector3, _delta: float) -> Vector3:
	# Nothing, on purpose: the belt's constant velocity already carries a body
	# standing on it at the belt's pace, still or walking, and adding the
	# distance here as well sent a child along at twice the speed the treads
	# were drawn at. The method stays so the park asks every ride alike.
	return Vector3.ZERO

## How fast a belt carries a child, and which way. For the checks. Found by
## name rather than by position among the children, which is a fact about the
## order things were built in and changes the day something else is added.
func carries(which: int) -> Vector3:
	var belt := get_node_or_null("Belt%s" % ("North" if which == 0 else "South")) as StaticBody3D
	return belt.constant_linear_velocity if belt != null else Vector3.ZERO
