class_name Park
extends Node3D

## The fairground east of the river: a fenced sandy ground with five rides on
## it.
##
## Where it stands and how its floor is made flat is ParkSpec's business, the
## way the pitch's is Pitch's. This builds what stands on that floor: the
## fence and its gateway, and the rides themselves, each of which is its own
## class because each one moves in its own way.
##
## Everything a child can stand on that moves is an AnimatableBody3D. Godot
## carries a character body standing on one of those, so a child on the
## carousel goes round with it and a child in a gondola goes up with it,
## without the game having to know they are there.

## Where each ride stands. Written here rather than inside the rides, so the
## fairground's plan can be read in one place — and checked against the fence
## and against one another.
const CAROUSEL_AT := Vector3(84.0, 0.0, 1.0)
## Away from the coaster, over towards the eastern fence: the belts stood five
## metres off the track's own piles and read as part of it.
const WALKWAY_AT := Vector3(85.0, 0.0, -25.0)
## Up beside the big wheel: the two things a child does standing up, together
## at the far end of the ground.
const TRAMPOLINE_AT := Vector3(85.0, 0.0, -62.0)
const WHEEL_AT := Vector3(82.0, 0.0, -84.0)
## The coaster runs down the western side, along the river, the whole length of
## the ground.
const COASTER_AT := Vector3(64.0, 0.0, -70.0)

## The big trampoline: twice the one on the playground, which is 3.5 m across.
const TRAMPOLINE_RADIUS := 7.0
const TRAMPOLINE_TOP := 1.05
## How much of a fall it gives back, and the least bounce it will give a child
## who merely steps onto it.
const TRAMPOLINE_REBOUND := 0.72
const TRAMPOLINE_JUMP := 2.1

const FENCE_HEIGHT := 1.5
const FENCE_STEP := 4.0
const FENCE_COLOUR := Color(0.36, 0.30, 0.26)
const FENCE_CAP := Color(0.62, 0.24, 0.22)

## The kiosk: where rides are paid for. On the right hand as you walk in,
## just inside the fence, because that is where a ticket office is.
## A metre further in than it stood: the kiosk had a stride of sand between it
## and the fence behind it, which is not room to walk round a building.
const BOOTH_OFFSET := Vector3(6.4, 0.0, -4.4)
const BOOTH_WIDTH := 3.0
const BOOTH_DEPTH := 2.4
const BOOTH_HEIGHT := 2.9
## How close a child has to be to buy.
const BOOTH_REACH := 4.0

## What one ride costs, and which rides charge at all. The trampoline and the
## walkways are free: they are the two a child uses while working out what the
## place is, and charging for them would make the fairground a shop.
const RIDE_PRICE := 10
const PAID_RIDES: Array[StringName] = [&"carousel", &"wheel", &"coaster"]

static func charges_for(ride: StringName) -> bool:
	return PAID_RIDES.has(ride)

## What the gateway says.
const PARK_NAME_TOP := "PARC"
const PARK_NAME := "DES MERVEILLES"

var _field: HeightField
var carousel: Carousel
var walkway: Walkway
var wheel: FerrisWheel
var coaster: RollerCoaster

func _init(height_field: HeightField) -> void:
	name = "Park"
	_field = height_field

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var solid := StaticBody3D.new()
	solid.name = "Solid"
	add_child(solid)

	_build_fence(tool, solid)
	_build_booth(tool, solid)
	_build_trampoline(tool, solid)

	tool.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.85
	tool.set_material(material)
	var built := MeshInstance3D.new()
	built.name = "Ground"
	built.mesh = tool.commit()
	add_child(built)

	carousel = Carousel.new(_at(CAROUSEL_AT))
	add_child(carousel)
	walkway = Walkway.new(_at(WALKWAY_AT))
	add_child(walkway)
	wheel = FerrisWheel.new(_at(WHEEL_AT))
	add_child(wheel)
	coaster = RollerCoaster.new(_at(COASTER_AT))
	add_child(coaster)

## A spot on the fairground's own floor.
func _at(spot: Vector3) -> Vector3:
	return Vector3(spot.x, ParkSpec.LEVEL, spot.z)

## How far the fairground moves somebody standing on one of its rides, this
## frame. The game adds this to wherever they are.
##
## Godot carries a character along a platform that slides and abandons them on
## one that turns or that is moved by hand, so every ride here says for itself
## how far it has taken its passengers. It also means the answer can be tested
## without a screen, which is the only way any of this was ever going to be
## known to work.
func carry(at: Vector3, delta: float) -> Vector3:
	if not ParkSpec.inside(at.x, at.z):
		return Vector3.ZERO
	_carrier = &""
	for ride: Array in [
		[&"carousel", carousel], [&"walkway", walkway],
		[&"wheel", wheel], [&"coaster", coaster],
	]:
		var moved: Vector3 = (ride[1] as Node).call("carry", at, delta)
		if moved != Vector3.ZERO:
			_carrier = ride[0]
			return moved
	return Vector3.ZERO

## Which ride carried somebody on the last call to `carry`, or nothing. The
## game asks so it can take a ticket for the ones that charge.
var _carrier: StringName = &""

func carrier() -> StringName:
	return _carrier

## Which ride is a child standing on, whether or not it happens to be moving
## this instant? A carousel at a standstill between turns, or a coaster
## waiting at the platform, is still a ride somebody is aboard.
func ride_under(at: Vector3) -> StringName:
	if not ParkSpec.inside(at.x, at.z):
		return &""
	var deck := carousel.position
	if Vector2(at.x - deck.x, at.z - deck.z).length() < Carousel.RADIUS \
			and at.y > deck.y + Carousel.FLOOR_HEIGHT - 0.3:
		return &"carousel"
	for index in FerrisWheel.GONDOLAS:
		var car := wheel.gondola(index)
		var local := at - car.global_position
		if absf(local.x) < 1.2 and absf(local.z) < 1.0 and local.y > -0.4 and local.y < 2.2:
			return &"wheel"
	for index in coaster.car_count():
		var seat := coaster.car_at(index)
		var inside := seat.global_transform.affine_inverse() * at
		if absf(inside.x) < 0.95 and absf(inside.z) < 0.65 and inside.y > -0.4 and inside.y < 2.0:
			return &"coaster"
	return &""

## Where the ticket kiosk stands.
func booth_at() -> Vector3:
	var gate := ParkSpec.gate()
	return Vector3(gate.x + BOOTH_OFFSET.x, ParkSpec.LEVEL, gate.z + BOOTH_OFFSET.z)

## Is a child close enough to the kiosk to buy a ride?
func at_the_booth(at: Vector3) -> bool:
	var booth := booth_at()
	return Vector2(at.x - booth.x, at.z - booth.z).length() < BOOTH_REACH

## The kiosk: a hut with a counter and a window, and a board over it saying
## what a ride costs. Small — it is a ticket office, not a building — and its
## counter faces the gate, so a child meets it on the way in.
func _build_booth(tool: SurfaceTool, solid: StaticBody3D) -> void:
	var at := booth_at()
	var hut := Color(0.86, 0.36, 0.30)
	var trim := Color(0.96, 0.92, 0.84)

	var body := BoxMesh.new()
	body.size = Vector3(BOOTH_WIDTH, BOOTH_HEIGHT, BOOTH_DEPTH)
	var middle := at + Vector3(0.0, BOOTH_HEIGHT * 0.5, 0.0)
	Park._add(tool, body, Transform3D(Basis(), middle), hut)
	Park._solid(solid, body.size, Transform3D(Basis(), middle))

	# The window, cut as a dark recess rather than a hole: a box the size of
	# the opening, set into the face, which is how every other window in this
	# valley is drawn.
	var window := BoxMesh.new()
	window.size = Vector3(BOOTH_WIDTH * 0.62, 0.9, 0.12)
	Park._add(
		tool, window,
		Transform3D(Basis(), at + Vector3(0.0, 1.55, BOOTH_DEPTH * 0.5 + 0.02)),
		Color(0.12, 0.14, 0.18)
	)
	# The counter under it, and the shelf a child puts their coins on.
	var counter := BoxMesh.new()
	counter.size = Vector3(BOOTH_WIDTH * 0.86, 0.14, 0.55)
	Park._add(
		tool, counter,
		Transform3D(Basis(), at + Vector3(0.0, 1.05, BOOTH_DEPTH * 0.5 + 0.2)),
		trim
	)
	# A little roof with an overhang, which is what tells a child across the
	# fairground that this is where you pay.
	var roof := CylinderMesh.new()
	roof.top_radius = 0.0
	roof.bottom_radius = BOOTH_WIDTH * 0.95
	roof.height = 0.85
	roof.radial_segments = 4
	roof.rings = 1
	Park._add(
		tool, roof,
		Transform3D(
			Basis(Vector3.UP, PI * 0.25), at + Vector3(0.0, BOOTH_HEIGHT + 0.35, 0.0)
		),
		Color(0.32, 0.30, 0.34)
	)
	# And the price, on a plate over the window, in the valley's own enamel.
	var board := at + Vector3(0.0, BOOTH_HEIGHT + 1.0, BOOTH_DEPTH * 0.5 - 0.1)
	Plaque.build(tool, 0.0, board, 3.0, 0.92, 0.0, 0.10)
	# A coaster drawn on the plate rather than the word for one: a hump of
	# track with a train going over it, which a six-year-old reads without
	# reading. The price goes beside it, where a price goes.
	var drawn_at := board + Vector3(-0.78, -0.02, 0.09)
	for piece in 14:
		var along := float(piece) / 13.0
		var hump := sin(along * PI) * 0.26
		var next := sin((float(piece) + 1.0) / 13.0 * PI) * 0.26
		var rail := BoxMesh.new()
		rail.size = Vector3(0.11, 0.05, 0.04)
		Park._add(
			tool, rail,
			Transform3D(
				Basis(Vector3.BACK, atan2(next - hump, 0.1)),
				drawn_at + Vector3(-0.55 + along * 1.1, hump - 0.16, 0.0)
			),
			Plaque.OFF_WHITE
		)
		# The piers under it, every few pieces.
		if piece % 4 != 1:
			continue
		var pier := BoxMesh.new()
		pier.size = Vector3(0.04, hump + 0.22, 0.03)
		Park._add(
			tool, pier,
			Transform3D(Basis(), drawn_at + Vector3(-0.55 + along * 1.1, (hump - 0.16) * 0.5 - 0.14, 0.0)),
			Plaque.OFF_WHITE
		)
	# The train, three little cars over the crown of the hump.
	for car in 3:
		var along := 0.42 + float(car) * 0.1
		var hump := sin(along * PI) * 0.26
		var box := BoxMesh.new()
		box.size = Vector3(0.09, 0.09, 0.05)
		Park._add(
			tool, box,
			Transform3D(
				Basis(Vector3.BACK, 0.35 - float(car) * 0.35),
				drawn_at + Vector3(-0.55 + along * 1.1, hump - 0.08, 0.01)
			),
			FENCE_CAP
		)
	Plaque.write(self, 0.0, board, [
		["%d" % RIDE_PRICE, -0.02, 0.0042],
	])

## Where the big trampoline's mat is.
func trampoline_mat() -> Vector3:
	return _at(TRAMPOLINE_AT) + Vector3(0.0, TRAMPOLINE_TOP, 0.0)

## Is a child standing on the mat? The playground's trampoline answers the same
## question for its own; this is the big one.
func on_trampoline(at: Vector3) -> bool:
	var mat := trampoline_mat()
	var flat := Vector2(at.x - mat.x, at.z - mat.z).length()
	return flat < TRAMPOLINE_RADIUS and absf(at.y - mat.y) < 0.8

## The fence: posts and two rails all the way round, with a gap in the southern
## side for the way in. A fairground with no edge is a field with rides in it.
func _build_fence(tool: SurfaceTool, solid: StaticBody3D) -> void:
	var corners: Array[Vector2] = [
		Vector2(ParkSpec.WEST, ParkSpec.SOUTH),
		Vector2(ParkSpec.WEST, ParkSpec.NORTH),
		Vector2(ParkSpec.EAST, ParkSpec.NORTH),
		Vector2(ParkSpec.EAST, ParkSpec.SOUTH),
	]
	var gate := ParkSpec.gate()
	for side in corners.size():
		var from := corners[side]
		var to := corners[(side + 1) % corners.size()]
		var run := to - from
		var steps := maxi(2, int(run.length() / FENCE_STEP))
		for step in steps + 1:
			var along := float(step) / float(steps)
			var here := from + run * along
			# The gateway: no fence across the way in.
			if absf(here.y - ParkSpec.SOUTH) < 0.01 and absf(here.x - gate.x) < ParkSpec.GATE_WIDTH * 0.5:
				continue
			_post(tool, solid, here, FENCE_HEIGHT, 0.12)
		# The rails, in the same pieces as the posts so they follow the line.
		for rail: float in [FENCE_HEIGHT * 0.92, FENCE_HEIGHT * 0.52]:
			for step in steps:
				var a := from + run * (float(step) / float(steps))
				var b := from + run * (float(step + 1) / float(steps))
				var middle := (a + b) * 0.5
				if absf(middle.y - ParkSpec.SOUTH) < 0.01 and absf(middle.x - gate.x) < ParkSpec.GATE_WIDTH * 0.5 + FENCE_STEP * 0.5:
					continue
				_rail(tool, solid, a, b, rail)

	_build_gateway(tool, solid, gate)

## The way in: two tall posts with a beam across them and the park's name on
## it, so arriving at the fairground is arriving somewhere.
func _build_gateway(tool: SurfaceTool, solid: StaticBody3D, gate: Vector3) -> void:
	var half := ParkSpec.GATE_WIDTH * 0.5
	var height := 5.2
	for side: float in [-1.0, 1.0]:
		_post(
			tool, solid, Vector2(gate.x + side * half, gate.z), height, 0.3, FENCE_CAP
		)
	var beam := BoxMesh.new()
	beam.size = Vector3(ParkSpec.GATE_WIDTH + 0.6, 0.55, 0.36)
	Park._add(
		tool, beam,
		Transform3D(Basis(), Vector3(gate.x, ParkSpec.LEVEL + height - 0.3, gate.z)),
		FENCE_CAP
	)
	# The name, on an enamel plate over the gate — the same plate the square
	# and the bridge wear, because one valley has one signwriter.
	var centre := Vector3(gate.x, ParkSpec.LEVEL + height + 0.85, gate.z)
	Plaque.build(tool, 0.0, centre, 5.0, 1.35, 0.52)
	Plaque.write(self, 0.0, centre, [
		[PARK_NAME_TOP, 0.30, 0.0046],
		[PARK_NAME, -0.28, 0.0030],
	])

func _post(
	tool: SurfaceTool, solid: StaticBody3D, at: Vector2, height: float, width: float,
	colour := FENCE_COLOUR
) -> void:
	var post := BoxMesh.new()
	post.size = Vector3(width, height, width)
	var middle := Vector3(at.x, ParkSpec.LEVEL + height * 0.5, at.y)
	Park._add(tool, post, Transform3D(Basis(), middle), colour)
	Park._solid(solid, post.size, Transform3D(Basis(), middle))

func _rail(tool: SurfaceTool, solid: StaticBody3D, a: Vector2, b: Vector2, at: float) -> void:
	var run := b - a
	var turn := Basis(Vector3.UP, atan2(-run.y, run.x))
	var rail := BoxMesh.new()
	rail.size = Vector3(run.length() + 0.1, 0.12, 0.08)
	var middle := Vector3((a.x + b.x) * 0.5, ParkSpec.LEVEL + at, (a.y + b.y) * 0.5)
	Park._add(tool, rail, Transform3D(turn, middle), FENCE_COLOUR)
	Park._solid(solid, rail.size, Transform3D(turn, middle))

## The big trampoline: the playground's, at twice the size. A frame on legs
## with a dark mat stretched across it, and springs round the rim.
func _build_trampoline(tool: SurfaceTool, solid: StaticBody3D) -> void:
	var at := _at(TRAMPOLINE_AT)
	var frame := TorusMesh.new()
	frame.inner_radius = TRAMPOLINE_RADIUS - 0.12
	frame.outer_radius = TRAMPOLINE_RADIUS + 0.10
	frame.rings = 28
	frame.ring_segments = 8
	Park._add(
		tool, frame,
		Transform3D(Basis(), at + Vector3(0.0, TRAMPOLINE_TOP, 0.0)),
		Color(0.24, 0.26, 0.30)
	)

	var mat := CylinderMesh.new()
	mat.top_radius = TRAMPOLINE_RADIUS - 0.10
	mat.bottom_radius = TRAMPOLINE_RADIUS - 0.10
	mat.height = 0.08
	mat.radial_segments = 28
	mat.rings = 1
	Park._add(
		tool, mat,
		Transform3D(Basis(), at + Vector3(0.0, TRAMPOLINE_TOP - 0.05, 0.0)),
		Color(0.13, 0.15, 0.20)
	)
	# The mat is solid, so a child stands on it; the bounce is the game's
	# business, in exactly the way the playground's is.
	var pad := CylinderShape3D.new()
	pad.radius = TRAMPOLINE_RADIUS - 0.10
	pad.height = 0.16
	var collider := CollisionShape3D.new()
	collider.shape = pad
	collider.position = at + Vector3(0.0, TRAMPOLINE_TOP - 0.05, 0.0)
	solid.add_child(collider)

	# Legs, and a safety net of uprights round it: the only thing here a child
	# can fall off, at this size, is this.
	for leg in 8:
		var angle := TAU * float(leg) / 8.0
		var spot := Vector2(cos(angle), sin(angle)) * (TRAMPOLINE_RADIUS - 0.25)
		var post := CylinderMesh.new()
		post.top_radius = 0.09
		post.bottom_radius = 0.11
		post.height = TRAMPOLINE_TOP
		post.radial_segments = 7
		post.rings = 1
		var stand := Transform3D(
			Basis(), at + Vector3(spot.x, TRAMPOLINE_TOP * 0.5, spot.y)
		)
		Park._add(tool, post, stand, Color(0.24, 0.26, 0.30))
		# Solid, like the legs of anything else a child walks up to.
		Park._solid(solid, Vector3(0.24, TRAMPOLINE_TOP, 0.24), stand)

## Finish a surface and hang it on a node. Every ride builds its still parts
## and its moving parts into separate tools and then calls this, so the whole
## fairground is a handful of meshes rather than a hundred.
static func commit(tool: SurfaceTool, parent: Node3D, drawn_name: String) -> void:
	tool.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.8
	tool.set_material(material)
	var mesh := tool.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		return
	var drawn := MeshInstance3D.new()
	drawn.name = drawn_name
	drawn.mesh = mesh
	parent.add_child(drawn)

static func _solid(body: StaticBody3D, size: Vector3, where: Transform3D) -> void:
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
