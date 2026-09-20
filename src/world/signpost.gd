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

## Where the post stands, measured from the camp: a few paces east, in the open
## ground between the camp and the river, which is where the roads fork.
const OFFSET := Vector3(4.0, 0.0, 0.0)

const POLE_RADIUS := 0.075
## Tall enough that the lowest plate clears a child walking under it, and that
## four of them stack under the plaque.
const POLE_HEIGHT := 4.6

## The plates. Thickness is the enamel and its frame; the length of each one is
## worked out from the name on it, so a long name is a long sign rather than
## small writing.
const PLATE_HEIGHT := 0.46
const PLATE_DEPTH := 0.10
const PLATE_PER_LETTER := 0.115
const PLATE_MARGIN := 1.05

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

## How high the plate for one road is mounted. Stacked downwards from the top,
## far enough apart that no two of them touch when they cross.
func _plate_height(road: int) -> float:
	return POLE_HEIGHT - 0.75 - float(road) * (PLATE_HEIGHT + 0.09)

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
## because a child reading it is standing in it. Green enamel with a white
## keyline, the way a Paris street plaque is made.
func _build_plaque(tool: SurfaceTool) -> void:
	var at := POLE_HEIGHT - 0.28
	var length := PLATE_MARGIN * 0.9 + PLATE_PER_LETTER * 0.80 * float(PLACE_NAME.length())
	var height := 0.62
	# Two plaques back to back at right angles, so the name is readable from
	# any of the four roads.
	for quarter in 2:
		var turn := Basis(Vector3.UP, PI * 0.5 * float(quarter))
		var middle := turn * Vector3(0.0, at, 0.0)

		var green := BoxMesh.new()
		green.size = Vector3(length, height, 0.09)
		Signpost._add(tool, green, Transform3D(turn, middle), PLAQUE_GREEN)

		var field := BoxMesh.new()
		field.size = Vector3(length - 0.16, height - 0.15, 0.11)
		Signpost._add(tool, field, Transform3D(turn, middle), BLUE)

		# The white keyline inside the green, which is the detail that makes
		# one of these read as enamel rather than as a painted board.
		var keyline := BoxMesh.new()
		keyline.size = Vector3(length - 0.10, height - 0.09, 0.10)
		Signpost._add(tool, keyline, Transform3D(turn, middle), OFF_WHITE)

		for face: float in [1.0, -1.0]:
			var label := Label3D.new()
			label.text = PLACE_NAME
			label.font_size = 96
			label.pixel_size = 0.0020
			label.modulate = OFF_WHITE
			label.rotation.y = PI * 0.5 * float(quarter) + (0.0 if face > 0.0 else PI)
			label.position = middle + turn * Vector3(0.0, 0.0, face * 0.07)
			add_child(label)

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
