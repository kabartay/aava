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
## Forty of them across fifty-six metres is a board every metre and a half,
## which reads as planking at the scale a child walks at; at half that many
## they were slabs.
const BOARDS := 40

## Planking, and the two stringers under it that the planking is laid on.
const DECK_THICKNESS := 0.18
const BEAM_DEPTH := 0.34

## How many trestles stand under the deck.
const TRESTLES := 5

## How far past each abutment the walkable surface is carried, down into the
## bank. There must be no seam where the planks meet the ground: a lip of a
## centimetre at the bottom of a run-up is what a wheel catches on.
const DECK_RUN_IN := 1.2

## How far above the planks the handrail's solid part begins.
const RAIL_CLEARANCE := 0.08
const RAIL_POSTS := 17

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

	# Two stringers the length of the crossing, laid along under the planks.
	# They are what a timber bridge is actually built of — the planks are
	# nailed to them — and without them the deck read as a row of slabs
	# hovering over the water with nothing joining them up.
	for side: float in [-1.0, 1.0]:
		var beam_z := BridgeSpec.CENTRE_Z + side * (BridgeSpec.HALF_WIDTH - 0.75)
		for piece in BOARDS:
			var from_x := river_x - BridgeSpec.HALF_SPAN + step * float(piece)
			var to_x := from_x + step
			var from_y := _field.bridge_deck_at(from_x, BridgeSpec.CENTRE_Z)
			var to_y := _field.bridge_deck_at(to_x, BridgeSpec.CENTRE_Z)
			var beam := BoxMesh.new()
			beam.size = Vector3(
				Vector2(step, to_y - from_y).length() * 1.04, BEAM_DEPTH, 0.30
			)
			Bridge._add(
				tool, beam,
				Transform3D(
					Bridge._slope(to_y - from_y, step),
					Vector3(
						(from_x + to_x) * 0.5,
						(from_y + to_y) * 0.5 - DECK_THICKNESS - BEAM_DEPTH * 0.5,
						beam_z
					)
				),
				TIMBER_DARK
			)

	for board in BOARDS:
		var from_x := river_x - BridgeSpec.HALF_SPAN + step * float(board)
		var to_x := from_x + step
		var from_y := _field.bridge_deck_at(from_x, BridgeSpec.CENTRE_Z)
		var to_y := _field.bridge_deck_at(to_x, BridgeSpec.CENTRE_Z)
		# Hung *under* the walking line rather than centred on it. The boards
		# used to straddle the deck height, which put the surface a sixth of a
		# metre above where every other part of the game believed it was —
		# including the two ends, where the deck is supposed to meet the bank
		# flush and instead met it with a step up.
		var middle := Vector3(
			(from_x + to_x) * 0.5,
			(from_y + to_y) * 0.5 - DECK_THICKNESS * 0.5,
			BridgeSpec.CENTRE_Z
		)
		# Tilted to its own piece of the arch, and tilted the right way up.
		# This was built about Vector3.FORWARD, which is the negative Z axis,
		# so every board leaned *against* the slope it was meant to follow: the
		# deck came out a sawtooth, and the whole crossing had to be jumped up
		# board by board. The sign of an axis is not a detail.
		var tilt := Bridge._slope(to_y - from_y, step)
		var length := Vector2(step, to_y - from_y).length()
		var plank := BoxMesh.new()
		# A hair short of its share, so there is a seam between one board and
		# the next: a deck with no lines across it is a ramp, not planking.
		plank.size = Vector3(length * 0.90, DECK_THICKNESS, BridgeSpec.HALF_WIDTH * 2.0)
		# Alternating shades, so the deck reads as boards laid side by side and
		# not as one long brown slab.
		var shade := TIMBER if board % 2 == 0 else TIMBER_DARK
		Bridge._add(tool, plank, Transform3D(tilt, middle), shade)

	# The deck a foot actually meets is one surface, not twenty-eight boxes.
	#
	# It was twenty-eight: each plank carried its own collider, each tilted to
	# its own piece of the arch and each a little longer than its share so the
	# joins would not gape. Two tilted boxes that overlap do not make a ramp —
	# the upper corner of each one stands proud of its neighbour's face, and
	# what a child walks over is a row of low steps. It had to be jumped up,
	# every plank, the whole way across.
	#
	# So the boards are scenery, and the thing that holds a foot up is a single
	# swept surface along the same arch: top, underside and two sides, joined
	# at every seam, with nothing standing above the walking line anywhere.
	_lay_the_deck(body, river_x, step)

	# Trestles down to the riverbed, in pairs with a brace across them, so the
	# deck is plainly held up by something. Only where there is a useful drop
	# under it — a leg a handspan long, out on the bank, reads as a mistake.
	for leg in TRESTLES:
		var at_x := river_x + lerpf(-0.78, 0.78, float(leg) / float(TRESTLES - 1)) * BridgeSpec.HALF_SPAN
		var deck := _field.bridge_deck_at(at_x, BridgeSpec.CENTRE_Z)
		var ground := _field.height_at(at_x, BridgeSpec.CENTRE_Z)
		var drop := deck - ground - DECK_THICKNESS - BEAM_DEPTH
		if drop < 1.0:
			continue
		var foot := ground + drop * 0.5
		for side: float in [-1.0, 1.0]:
			var post := CylinderMesh.new()
			post.top_radius = 0.20
			post.bottom_radius = 0.26
			post.height = drop
			post.radial_segments = 8
			post.rings = 1
			var at := Vector3(
				at_x, foot, BridgeSpec.CENTRE_Z + side * (BridgeSpec.HALF_WIDTH - 0.75)
			)
			# Splayed a little, the way a trestle stands, rather than two
			# posts dropped straight down.
			Bridge._add(
				tool, post,
				Transform3D(Basis(Vector3.BACK, side * -0.06), at),
				TIMBER_DARK
			)
		# The brace across the pair, up under the beams.
		var brace := BoxMesh.new()
		brace.size = Vector3(0.16, 0.16, (BridgeSpec.HALF_WIDTH - 0.75) * 2.0)
		Bridge._add(
			tool, brace,
			Transform3D(Basis(), Vector3(at_x, ground + drop * 0.78, BridgeSpec.CENTRE_Z)),
			TIMBER
		)

	# The handrails: posts with a rail along the top and a second one halfway
	# down, both sides. Solid, so a machine that wanders is turned back by them
	# rather than dropped in the river.
	for side: float in [-1.0, 1.0]:
		var rail_z := BridgeSpec.CENTRE_Z + side * (BridgeSpec.HALF_WIDTH - BridgeSpec.RAIL_INSET)
		for post_index in RAIL_POSTS:
			var along := float(post_index) / float(RAIL_POSTS - 1)
			var at_x := river_x + lerpf(-1.0, 1.0, along) * (BridgeSpec.HALF_SPAN - 0.6)
			var deck := _field.bridge_deck_at(at_x, BridgeSpec.CENTRE_Z)
			var post := BoxMesh.new()
			post.size = Vector3(0.14, BridgeSpec.RAIL_HEIGHT + 0.12, 0.14)
			Bridge._add(
				tool, post,
				Transform3D(Basis(), Vector3(at_x, deck + BridgeSpec.RAIL_HEIGHT * 0.5, rail_z)),
				TIMBER_DARK
			)
			# A cap on each post, which is the detail that stops a handrail
			# reading as a row of sticks.
			var cap := BoxMesh.new()
			cap.size = Vector3(0.22, 0.07, 0.22)
			Bridge._add(
				tool, cap,
				Transform3D(Basis(), Vector3(
					at_x, deck + BridgeSpec.RAIL_HEIGHT + 0.20, rail_z
				)),
				TIMBER
			)

		# The rails themselves, in the same pieces the deck is cut into so they
		# follow the arch.
		for piece in BOARDS:
			var from_x := river_x - BridgeSpec.HALF_SPAN + step * float(piece)
			var to_x := from_x + step
			var from_y := _field.bridge_deck_at(from_x, BridgeSpec.CENTRE_Z)
			var to_y := _field.bridge_deck_at(to_x, BridgeSpec.CENTRE_Z)
			var tilt := Bridge._slope(to_y - from_y, step)
			var length := Vector2(step, to_y - from_y).length()
			for height: float in [BridgeSpec.RAIL_HEIGHT, BridgeSpec.RAIL_HEIGHT * 0.52]:
				var rail := BoxMesh.new()
				rail.size = Vector3(
					length * 1.02, 0.14 if height > BridgeSpec.RAIL_HEIGHT * 0.9 else 0.10, 0.18
				)
				Bridge._add(
					tool, rail,
					Transform3D(tilt, Vector3(
						(from_x + to_x) * 0.5, (from_y + to_y) * 0.5 + height, rail_z
					)),
					TIMBER
				)

## The deck's collision: one continuous prism swept along the arch.
##
## A trimesh rather than a pile of boxes, because a pile of boxes cannot be
## made flush — tilt two of them differently and their corners cross. The
## surface is generated from the same `bridge_deck_at` every other part of the
## game reads, so where the deck is and where a foot lands are one number.
##
## It runs a little past each abutment and down into the bank, so there is no
## seam at all between the planks and the ground: a gap of even a centimetre at
## the end is a lip, and a lip at the bottom of a run-up is what a motorcycle
## catches on.
func _lay_the_deck(body: StaticBody3D, river_x: float, step: float) -> void:
	_sweep(body, river_x, step, BridgeSpec.CENTRE_Z, BridgeSpec.HALF_WIDTH,
		-DECK_THICKNESS, 0.0, DECK_RUN_IN)
	# The handrails are swept the same way, for the same reason: tilted boxes
	# laid end to end dip at their corners, and a corner that dips below the
	# planks is a thing a wheel running along the rail catches on.
	for side: float in [-1.0, 1.0]:
		_sweep(
			body, river_x, step,
			BridgeSpec.CENTRE_Z + side * (BridgeSpec.HALF_WIDTH - BridgeSpec.RAIL_INSET),
			0.11, RAIL_CLEARANCE, BridgeSpec.RAIL_HEIGHT, 0.0
		)

## One prism swept along the arch: a strip of the crossing, from `bottom` to
## `top` measured off the walking surface, centred on `z_at` and `half_z` wide.
func _sweep(
	body: StaticBody3D, river_x: float, step: float,
	z_at: float, half_z: float, bottom: float, top: float, run_in: float
) -> void:
	var faces := PackedVector3Array()
	var from_x := river_x - BridgeSpec.HALF_SPAN - run_in
	var to_x := river_x + BridgeSpec.HALF_SPAN + run_in
	var near_z := z_at - half_z
	var far_z := z_at + half_z
	var pieces := int(ceil((to_x - from_x) / step))
	for piece in pieces:
		var near_x := from_x + (to_x - from_x) * float(piece) / float(pieces)
		var far_x := from_x + (to_x - from_x) * float(piece + 1) / float(pieces)
		var near := _surface_at(near_x)
		var far := _surface_at(far_x)
		# Top, underside, and the two sides: a closed box, so a body meets it
		# the same way from above, below or the side.
		Bridge._quad(faces,
			Vector3(near_x, near + top, near_z), Vector3(far_x, far + top, near_z),
			Vector3(far_x, far + top, far_z), Vector3(near_x, near + top, far_z))
		Bridge._quad(faces,
			Vector3(near_x, near + bottom, far_z), Vector3(far_x, far + bottom, far_z),
			Vector3(far_x, far + bottom, near_z), Vector3(near_x, near + bottom, near_z))
		for z: float in [near_z, far_z]:
			Bridge._quad(faces,
				Vector3(near_x, near + bottom, z), Vector3(far_x, far + bottom, z),
				Vector3(far_x, far + top, z), Vector3(near_x, near + top, z))

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)

## The walking surface at a point along the crossing, carried on past the two
## abutments by following the ground instead of the arch.
func _surface_at(x: float) -> float:
	var deck := _field.bridge_deck_at(x, BridgeSpec.CENTRE_Z)
	if is_nan(deck):
		return _field.height_at(x, BridgeSpec.CENTRE_Z)
	return deck

## The tilt of one piece of the arch: a rotation about the axis that runs
## across the crossing, so that the piece rises along it.
##
## About Vector3.BACK, not Vector3.FORWARD. Forward is the negative Z axis, and
## rotating about it turns everything the other way — which is how the whole
## deck came out as a sawtooth that had to be jumped up board by board.
static func _slope(rise: float, run: float) -> Basis:
	return Basis(Vector3.BACK, atan2(rise, run))

## Two triangles, wound the same way round.
static func _quad(faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	faces.append(a)
	faces.append(b)
	faces.append(c)
	faces.append(a)
	faces.append(c)
	faces.append(d)

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
