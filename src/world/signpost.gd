class_name Signpost
extends Node3D

## The street signs at the camp, where the four roads meet.
##
## The valley's paths were anonymous: worn earth going off in four directions,
## and a child had to remember which was which or walk one to find out. Naming
## them turns a junction into a place — and a place with a name is somewhere
## you say you are, which is most of what makes a made-up valley feel lived in.
##
## Built in the Paris manner, because that is what it is modelled on: dark blue
## enamel plates with a white keyline and a white arrow, stacked on a post, one
## for each way out; and a plaque over the top naming the square itself, which
## needs no arrow because you are standing in it.
##
## Where each road actually goes is asked of Paths, not written down here, so a
## sign cannot end up pointing at a place its road no longer leads to.

## Where the post stands, measured from the camp: a few paces west of its
## middle, on the open ground of the square itself. Chosen by standing there.
const OFFSET := Vector3(-5.2, 0.0, -0.2)

const POLE_RADIUS := 0.125
## Tall enough to be a landmark rather than a notice: twice the height it was,
## so the plates and the plaque are seen across the meadow and over whatever a
## child builds around them. The plates grow with it — a sign twice as far up
## and the same size is a sign nobody can read.
const POLE_HEIGHT := 9.6

## The plates. Thickness is the enamel and its frame; the length of each one is
## worked out from the name on it, so a long name is a long sign rather than
## small writing.
const PLATE_HEIGHT := 0.66
const PLATE_DEPTH := 0.13
const PLATE_PER_LETTER := 0.165
const PLATE_MARGIN := 1.45

const BLUE := Color(0.10, 0.20, 0.38)
const OFF_WHITE := Color(0.92, 0.93, 0.90)
const POLE_GREY := Color(0.62, 0.61, 0.56)
## The green of an enamel street plaque, which is the one colour on the whole
## post that is not blue or white.
const PLAQUE_GREEN := Color(0.11, 0.26, 0.18)

## What the square itself is called.
const PLACE_NAME := "PLACE DES SPORTS"

## The roads out, in the order they are stacked — the tallest plate at the top,
## as they are stacked in a street. `toward` names what the road leads to, and
## is resolved through Paths so the sign turns with the road.
const ROADS: Array[Dictionary] = [
	{"name": "Boulevard Berzeg", "toward": &"playground"},
	{"name": "Avenue Kabard", "toward": &"cafe"},
	{"name": "Rue des Parents", "toward": &"bridge"},
	{"name": "Impasse de Kassag", "toward": &"pool"},
]

var _field: HeightField

func _init(height_field: HeightField) -> void:
	name = "Signpost"
	_field = height_field
	_build()

## Where the post stands, on the ground.
func where() -> Vector3:
	var at := _field.camp_centre() + OFFSET
	at.y = _field.height_at(at.x, at.z)
	return at

## How far from the middle of the post nothing may stand: the post's own
## collision, a child's own width, and a hand's breadth so they are not left
## leaning on it.
const KEEP_CLEAR := POLE_RADIUS * 1.6 + Player.RADIUS + 0.25

## Move a point out from under the post, if it is under it.
##
## The post was put exactly where a child was standing, and they loaded back in
## inside it and could not walk out: a solid thing that appears around somebody
## traps them. Anything that puts a child into the world asks this first, and a
## child already there is stepped out along the line they were pushed from —
## towards the camp when they are dead centre, because that is where they were
## going anyway.
func push_clear(at: Vector3) -> Vector3:
	var foot := where()
	var out := Vector2(at.x - foot.x, at.z - foot.z)
	if out.length() >= KEEP_CLEAR:
		return at
	if out.length() < 0.01:
		var camp := _field.camp_centre()
		out = Vector2(camp.x - foot.x, camp.z - foot.z)
		if out.length() < 0.01:
			out = Vector2(1.0, 0.0)
	out = out.normalized() * KEEP_CLEAR
	var moved := Vector3(foot.x + out.x, at.y, foot.z + out.y)
	moved.y = maxf(moved.y, _field.height_at(moved.x, moved.z))
	return moved

## What a road on this post points at.
func destination(toward: StringName) -> Vector3:
	var camp := _field.camp_centre()
	if toward == &"bridge":
		# The road east: over the crossing and on to the shop. It is pointed at
		# the bridge rather than at the shop, because the bridge is the part of
		# the journey a child has to find — after that the path does the rest.
		return Vector3(
			_field.river_centre_x(BridgeSpec.CENTRE_Z), 0.0, BridgeSpec.CENTRE_Z
		)
	return Paths.end_of(toward, camp)

func _build() -> void:
	var foot := where()
	position = foot

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var pole := CylinderMesh.new()
	pole.top_radius = POLE_RADIUS
	pole.bottom_radius = POLE_RADIUS * 1.25
	pole.height = POLE_HEIGHT
	pole.radial_segments = 10
	pole.rings = 1
	Signpost._add(
		tool, pole, Transform3D(Basis(), Vector3(0.0, POLE_HEIGHT * 0.5, 0.0)), POLE_GREY
	)

	# A collar under each plate, which is how these are actually mounted and
	# what stops the plates reading as boxes floating beside a stick.
	for road in ROADS.size():
		var collar := CylinderMesh.new()
		collar.top_radius = POLE_RADIUS * 1.7
		collar.bottom_radius = POLE_RADIUS * 1.7
		collar.height = 0.10
		collar.radial_segments = 10
		collar.rings = 1
		Signpost._add(
			tool, collar,
			Transform3D(Basis(), Vector3(0.0, _plate_height(road) - PLATE_HEIGHT * 0.62, 0.0)),
			POLE_GREY
		)

	for road in ROADS.size():
		_build_plate(tool, road)

	# The bracket the plaque stands on: a short neck off the top of the post,
	# with a collar under it. Without it the plaque floats a handspan over the
	# end of the pole.
	var neck := BoxMesh.new()
	neck.size = Vector3(0.14, BRACKET_HEIGHT + 0.08, 0.14)
	Signpost._add(
		tool, neck,
		Transform3D(Basis(), Vector3(0.0, POLE_HEIGHT + BRACKET_HEIGHT * 0.5 - 0.04, 0.0)),
		POLE_GREY
	)
	var cap := CylinderMesh.new()
	cap.top_radius = POLE_RADIUS * 1.5
	cap.bottom_radius = POLE_RADIUS * 1.5
	cap.height = 0.09
	cap.radial_segments = 12
	cap.rings = 1
	Signpost._add(
		tool, cap, Transform3D(Basis(), Vector3(0.0, POLE_HEIGHT, 0.0)), POLE_GREY
	)

	_build_plaque(tool)

	tool.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.55
	tool.set_material(material)

	var signs := MeshInstance3D.new()
	signs.name = "Signs"
	signs.mesh = tool.commit()
	add_child(signs)

	# Solid, like a real post. Thin: a child riding past should clip a post,
	# not a wall.
	var body := StaticBody3D.new()
	body.name = "Solid"
	var shape := CylinderShape3D.new()
	shape.radius = POLE_RADIUS * 1.6
	shape.height = POLE_HEIGHT
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = Vector3(0.0, POLE_HEIGHT * 0.5, 0.0)
	body.add_child(collider)
	add_child(body)

## How high the plate for one road is mounted: hung under the plaque and
## stacked downwards, far enough apart that no two of them touch when they
## cross.
##
## Measured from the plaque rather than from the top of the post, because that
## is the thing they must not run into. Written from the post's top, the
## topmost plate came out through the middle of the plaque — the square's name
## had a street sign growing out of it.
func _plate_height(road: int) -> float:
	return (
		POLE_HEIGHT - PLATE_HEIGHT * 0.5 - PLAQUE_GAP
		- float(road) * (PLATE_HEIGHT + 0.14)
	)

## The middle of the plaque: standing on top of the post, not threaded onto it.
##
## It used to be centred on the post's axis at a height the post still reached,
## so the pole came up through the middle of the enamel and cut the name in
## half. A plaque is screwed to the front of something; nothing goes through
## it. So the post stops, a short bracket carries on, and the plaque sits above
## the end of it.
func _plaque_centre() -> float:
	return POLE_HEIGHT + BRACKET_HEIGHT + PLAQUE_BODY * 0.5

## How long a plate has to be to hold its name and its arrow.
static func plate_length(road_name: String) -> float:
	return PLATE_MARGIN + PLATE_PER_LETTER * float(road_name.length())

func _build_plate(tool: SurfaceTool, road: int) -> void:
	var road_name: String = ROADS[road]["name"]
	var toward: StringName = ROADS[road]["toward"]
	var length := Signpost.plate_length(road_name)
	var at := _plate_height(road)

	# Turned to face along its own road, so that following the sign and
	# following the arrow are the same act.
	var heading := bearing_to(toward)
	var turn := Basis(Vector3.UP, heading)
	var middle := Vector3(length * 0.5 + POLE_RADIUS, at, 0.0)

	# The frame: a white plate, with the blue enamel laid on top of it a
	# fraction smaller, which is what draws the keyline round the edge.
	var frame := BoxMesh.new()
	frame.size = Vector3(length, PLATE_HEIGHT, PLATE_DEPTH)
	Signpost._add(tool, frame, Transform3D(turn, turn * middle), OFF_WHITE)

	var enamel := BoxMesh.new()
	enamel.size = Vector3(length - 0.10, PLATE_HEIGHT - 0.09, PLATE_DEPTH + 0.02)
	Signpost._add(tool, enamel, Transform3D(turn, turn * middle), BLUE)

	# The arrow, at the far end, pointing the way the plate does.
	for face: float in [1.0, -1.0]:
		var head := PLATE_HEIGHT * 0.30
		var tip := middle + Vector3(length * 0.5 - 0.16, 0.0, 0.0)
		var shaft := BoxMesh.new()
		shaft.size = Vector3(0.34, 0.08, 0.01)
		Signpost._add(
			tool, shaft,
			Transform3D(turn, turn * (tip + Vector3(-0.26, 0.0, face * (PLATE_DEPTH * 0.5 + 0.012)))),
			OFF_WHITE
		)
		# The head, drawn as three narrowing slices rather than as a triangle
		# mesh: a wedge built from boxes keeps the whole post to one surface.
		for slice in 4:
			var along := float(slice) / 4.0
			var slab := BoxMesh.new()
			slab.size = Vector3(0.05, head * 2.0 * (1.0 - along), 0.01)
			Signpost._add(
				tool, slab,
				Transform3D(turn, turn * (tip + Vector3(
					-0.06 + along * 0.2, 0.0, face * (PLATE_DEPTH * 0.5 + 0.012)
				))),
				OFF_WHITE
			)

	# The name, on both faces, so the sign reads from either side of the road.
	for face: float in [1.0, -1.0]:
		var label := Label3D.new()
		label.text = road_name
		label.font_size = 96
		label.pixel_size = PLATE_HEIGHT * 0.0052
		label.modulate = OFF_WHITE
		label.rotation.y = heading + (0.0 if face > 0.0 else PI)
		var out := turn * (middle + Vector3(-0.22, 0.0, 0.0))
		label.position = out + Vector3(0.0, 0.0, 0.0) + (turn * Vector3(
			0.0, 0.0, face * (PLATE_DEPTH * 0.5 + 0.02)
		))
		add_child(label)

## The bearing from the post to what a road leads to.
func bearing_to(toward: StringName) -> float:
	var there := destination(toward)
	var from := where()
	return atan2(-(there.z - from.z), there.x - from.x)

## The plaque over the top: the name of the square itself, which wants no arrow
## because a child reading it is standing in it.
##
## It was two plates crossed at right angles, so the name faced all four roads.
## That is not a thing anyone builds — a street plaque is one panel on one
## wall, and four of them back to back reads as a lantern with writing on it.
##
## So it is a single plaque, made the way the enamel ones in Paris are made: a
## green border with a round-topped arch, a white keyline inside it, a dark
## blue field, four bosses at the corners where it would be screwed to a wall,
## and the name broken across lines with the small words small. The arch
## carries the valley's name the way a real one carries its arrondissement.
##
## One panel, two faces, turned square to the camp: a child coming home reads
## it head-on, and a child leaving reads the back of it.
const PLAQUE_WIDTH := 3.4
const PLAQUE_BODY := 1.55
const PLAQUE_ARCH := 0.58
## The clear air between the plaque and the topmost street plate. A plaque
## resting on the signs reads as one more sign.
const PLAQUE_GAP := 0.60

## The short bracket between the top of the post and the foot of the plaque.
const BRACKET_HEIGHT := 0.22
## What the arch says, above the name: the valley this square is in.
const PLAQUE_ARCH_TEXT := "VALLÉE D'AAVA"

## Which way the plaque looks: at the camp. One panel has a front, and the
## front belongs to the direction a child arrives from.
func plaque_facing() -> float:
	var camp := _field.camp_centre()
	var foot := where()
	return atan2(-(camp.z - foot.z), camp.x - foot.x)

func _build_plaque(tool: SurfaceTool) -> void:
	var at := Vector3(0.0, _plaque_centre(), 0.0)
	# Square to the road from the camp, so the face a child meets first is the
	# front of the plaque rather than its edge.
	var yaw := plaque_facing() + PI * 0.5
	Plaque.build(tool, yaw, at, PLAQUE_WIDTH, PLAQUE_BODY, PLAQUE_ARCH)
	# The name broken across lines with the small word small, which is how a
	# street plaque is set, and the valley's name in the arch where a real one
	# carries its arrondissement.
	Plaque.write(self, yaw, at, [
		[PLAQUE_ARCH_TEXT, PLAQUE_BODY * 0.5 + PLAQUE_ARCH * 0.42, 0.0017],
		["PLACE", 0.40, 0.0034],
		["DES", 0.02, 0.0020],
		["SPORTS", -0.42, 0.0040],
	])

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
