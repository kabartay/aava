class_name Bridge
extends Node3D

## The bridge over the river, built once when the world is.
##
## Timber: a deck of planks on trestles, with a handrail down each side. The
## rails are solid, not scenery — a motorcycle ridden into one bounces off it
## rather than going over the parapet, which is the whole reason a real bridge
## has them.
##
## Where it stands and what shape it is are BridgeSpec's business; this builds
## what that describes. The height field is asked for the ground under each end
## so the deck lands on it, and every other part of the game that needs to know
## where the deck is asks the height field rather than this node — so a bridge
## that is not built yet, in a headless check, still reports the same deck.

## How many boards the deck is cut into. Each is tilted to the slope at its own
## place on the arch, so the surface is a curve rather than a flight of steps.
const BOARDS := 28

const DECK_THICKNESS := 0.34
const RAIL_POSTS := 15

const TIMBER := Color(0.46, 0.33, 0.21)
const TIMBER_DARK := Color(0.33, 0.24, 0.16)
const STONE := Color(0.46, 0.45, 0.43)

var _field: HeightField

func _init(height_field: HeightField) -> void:
	name = "Bridge"
	_field = height_field
	_build()

func _build() -> void:
	var river_x := _field.river_centre_x(BridgeSpec.CENTRE_Z)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := StaticBody3D.new()
	body.name = "Solid"
	add_child(body)

	var step := BridgeSpec.HALF_SPAN * 2.0 / float(BOARDS)
	for board in BOARDS:
		var from_x := river_x - BridgeSpec.HALF_SPAN + step * float(board)
		var to_x := from_x + step
		var from_y := _field.bridge_deck_at(from_x, BridgeSpec.CENTRE_Z)
		var to_y := _field.bridge_deck_at(to_x, BridgeSpec.CENTRE_Z)
		var middle := Vector3((from_x + to_x) * 0.5, (from_y + to_y) * 0.5, BridgeSpec.CENTRE_Z)
		# Tilted to its own piece of the arch. Laid flat, the boards would step
		# down from one another and a bicycle would ride over a staircase.
		var tilt := Basis(Vector3.FORWARD, atan2(to_y - from_y, step))
		var length := Vector2(step, to_y - from_y).length()
		var plank := BoxMesh.new()
		plank.size = Vector3(length * 1.02, DECK_THICKNESS, BridgeSpec.HALF_WIDTH * 2.0)
		# Alternating shades, so the deck reads as boards laid side by side and
		# not as one long brown slab.
		var shade := TIMBER if board % 2 == 0 else TIMBER_DARK
		Bridge._add(tool, plank, Transform3D(tilt, middle), shade)
		_solid(body, plank.size, Transform3D(tilt, middle))

	# Trestles down to the riverbed, in pairs, so the deck is plainly held up
	# by something. Only where there is a useful drop under it — a leg a
	# handspan long, out on the bank, reads as a mistake.
	for leg in 5:
		var at_x := river_x + lerpf(-0.72, 0.72, float(leg) / 4.0) * BridgeSpec.HALF_SPAN
		var deck := _field.bridge_deck_at(at_x, BridgeSpec.CENTRE_Z)
		var ground := _field.height_at(at_x, BridgeSpec.CENTRE_Z)
		var drop := deck - ground
		if drop < 1.2:
			continue
		for side: float in [-1.0, 1.0]:
			var post := CylinderMesh.new()
			post.top_radius = 0.26
			post.bottom_radius = 0.34
			post.height = drop
			post.radial_segments = 7
			post.rings = 1
			var at := Vector3(
				at_x, ground + drop * 0.5, BridgeSpec.CENTRE_Z + side * (BridgeSpec.HALF_WIDTH - 0.5)
			)
			Bridge._add(tool, post, Transform3D(Basis(), at), STONE if drop > 3.0 else TIMBER_DARK)

	# The handrails: posts with a rail along the top, both sides, solid.
	for side: float in [-1.0, 1.0]:
		var rail_z := BridgeSpec.CENTRE_Z + side * (BridgeSpec.HALF_WIDTH - BridgeSpec.RAIL_INSET)
		for post_index in RAIL_POSTS:
			var along := float(post_index) / float(RAIL_POSTS - 1)
			var at_x := river_x + lerpf(-1.0, 1.0, along) * (BridgeSpec.HALF_SPAN - 0.6)
			var deck := _field.bridge_deck_at(at_x, BridgeSpec.CENTRE_Z)
			var post := BoxMesh.new()
			post.size = Vector3(0.20, BridgeSpec.RAIL_HEIGHT, 0.20)
			Bridge._add(
				tool, post,
				Transform3D(Basis(), Vector3(at_x, deck + BridgeSpec.RAIL_HEIGHT * 0.5, rail_z)),
				TIMBER_DARK
			)

		# The rail itself, in the same pieces the deck is cut into so it
		# follows the arch. Solid, so a machine that wanders is turned back by
		# it rather than dropped in the river.
		var rail_step := BridgeSpec.HALF_SPAN * 2.0 / float(BOARDS)
		for piece in BOARDS:
			var from_x := river_x - BridgeSpec.HALF_SPAN + rail_step * float(piece)
			var to_x := from_x + rail_step
			var from_y := _field.bridge_deck_at(from_x, BridgeSpec.CENTRE_Z)
			var to_y := _field.bridge_deck_at(to_x, BridgeSpec.CENTRE_Z)
			var tilt := Basis(Vector3.FORWARD, atan2(to_y - from_y, rail_step))
			var length := Vector2(rail_step, to_y - from_y).length()
			var middle := Vector3(
				(from_x + to_x) * 0.5,
				(from_y + to_y) * 0.5 + BridgeSpec.RAIL_HEIGHT,
				rail_z
			)
			var rail := BoxMesh.new()
			rail.size = Vector3(length * 1.02, 0.16, 0.22)
			Bridge._add(tool, rail, Transform3D(tilt, middle), TIMBER)
			var barrier := Vector3(length * 1.02, BridgeSpec.RAIL_HEIGHT, 0.22)
			_solid(
				body, barrier,
				Transform3D(tilt, middle - Vector3(0.0, BridgeSpec.RAIL_HEIGHT * 0.5, 0.0))
			)

	tool.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.88
	tool.set_material(material)

	var timbers := MeshInstance3D.new()
	timbers.mesh = tool.commit()
	add_child(timbers)

func _solid(body: StaticBody3D, size: Vector3, where: Transform3D) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.transform = where
	body.add_child(collider)

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
