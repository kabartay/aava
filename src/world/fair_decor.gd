class_name FairDecor
extends RefCounted

## What makes the fairground's grounds look like a fair rather than a sandy
## field with rides in it: a paved avenue and a paved ring round the carousel,
## lamp posts with strings of bunting between them, picture signs for the
## rides, a row of stalls along the eastern fence, benches and bins.
##
## Everything here is drawn into the meshes Park already builds (the still
## "Ground" mesh in vertex colour, and the "Lamps" mesh, whose one emissive
## material is what comes alight at dusk), so the whole of it costs two draw
## calls and no per-frame work beyond one multiplier at dusk.
##
## Nothing a child walks along is solid. The lamps, signs, benches and bins
## have no collider at all, the pavement is paint, and the stalls — which are
## solid, like the kiosk — stand on the open sand against the eastern fence,
## clear of every ride's footprint and of the avenue (see `footprints` and
## `keep_out`, which the checks read).

## The avenue: a paved strip from the gate northwards between the rides on
## its two sides. Its middle line is west of the carousel's ramp and east of
## the coaster's piles, which is the one lane that is free all the way.
const AVENUE_X := 75.0
const AVENUE_HALF := 1.9
const AVENUE_FROM := 13.0
const AVENUE_TO := -148.0
## How high the paint lies over the sand. Enough for the depth buffer at the
## far end of the ground, nothing a child's foot would catch on.
const PAVE_LIFT := 0.04

## The lamps stand either side of the avenue, one pair every so many metres.
const LAMP_STEP := 16.0
const LAMP_HEIGHT := 4.2

## The stalls: along the eastern side, facing the avenue.
const STALL_X := 91.4
const STALL_Z: Array[float] = [-20.0, -34.0, -48.0, -80.0, -96.0]
const STALL_HALF_DEPTH := 0.95
const STALL_HALF_WIDTH := 1.6
const STALL_HEIGHT := 2.3

## The fairground's palette: the carousel's red and cream, its gold, and the
## sky blue and green of the drum and the wheel, so that the grounds read as
## the same hand as the rides.
const RED := Color(0.88, 0.30, 0.30)
const CREAM := Color(0.97, 0.93, 0.82)
const GOLD := Color(0.96, 0.78, 0.22)
const BLUE := Color(0.30, 0.52, 0.80)
const GREEN := Color(0.36, 0.70, 0.46)
const PINK := Color(0.96, 0.50, 0.62)
const IRON := Color(0.26, 0.28, 0.34)
const WOOD := Color(0.62, 0.44, 0.28)
const PAVER_A := Color(0.80, 0.70, 0.58)
const PAVER_B := Color(0.72, 0.60, 0.48)
const PAVER_EDGE := Color(0.60, 0.40, 0.34)
const PENNANTS: Array[Color] = [
	Color(0.92, 0.30, 0.32), Color(0.98, 0.80, 0.26), Color(0.30, 0.56, 0.86),
	Color(0.40, 0.76, 0.50), Color(0.96, 0.52, 0.66),
]
const BULB := Color(1.0, 0.92, 0.55)

## What each stall sells, in the order they stand: the picture on its sign is
## the product, so nobody needs to read.
const STALL_KINDS: Array[StringName] = [
	&"popcorn", &"balloons", &"icecream", &"rings", &"lemonade",
]

## Everything the decoration put down, for the checks: each entry is
## {"kind": StringName, "at": Vector2, "radius": float, "solid": bool}.
var props: Array[Dictionary] = []

## The ground the rides own, as {"at": Vector2, "half": Vector2} boxes (a
## circle is the box that holds it, which errs on the safe side). Nothing is
## put down inside one of these, solid or not.
static func keep_out() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var c := Park.CAROUSEL_AT
	out.append({"at": Vector2(c.x, c.z), "half": Vector2.ONE * (Carousel.RADIUS + 2.8)})
	var w := Park.WALKWAY_AT
	out.append({"at": Vector2(w.x, w.z), "half": Vector2(Walkway.WIDTH + Walkway.GAP + 1.0, Walkway.LENGTH * 0.5 + 1.5)})
	var t := Park.TRAMPOLINE_AT
	out.append({"at": Vector2(t.x, t.z), "half": Vector2.ONE * (Park.TRAMPOLINE_RADIUS + 1.2)})
	var f := Park.WHEEL_AT
	out.append({"at": Vector2(f.x, f.z), "half": Vector2(6.0, FerrisWheel.RADIUS + 2.0)})
	var k := Park.COASTER_AT
	out.append({"at": Vector2(k.x, k.z), "half": Vector2(RollerCoaster.HALF_WIDTH + 1.0, RollerCoaster.HALF_LENGTH)})
	# The coaster's boarding platform and its ramps, which stand out east of the
	# track right up against the avenue's western kerb.
	out.append({"at": Vector2(k.x + 9.3, k.z + 56.0), "half": Vector2(1.6, 13.0)})
	var d := Park.DROP_TOWER_AT
	out.append({"at": Vector2(d.x, d.z), "half": Vector2.ONE * (DropTower.PLATFORM_SIZE * 0.5 + 1.0)})
	var s := Park.PIRATE_SHIP_AT
	out.append({"at": Vector2(s.x, s.z), "half": Vector2(PirateShip.FRAME_SPREAD + 1.5, 9.0)})
	return out

static func _clear(at: Vector2, radius: float) -> bool:
	for box: Dictionary in keep_out():
		var centre: Vector2 = box["at"]
		var half: Vector2 = box["half"]
		if absf(at.x - centre.x) < half.x + radius and absf(at.y - centre.y) < half.y + radius:
			return false
	var booth := Vector2(ParkSpec.gate().x + Park.BOOTH_OFFSET.x, ParkSpec.gate().z + Park.BOOTH_OFFSET.z)
	if at.distance_to(booth) < radius + 3.0:
		return false
	return ParkSpec.buildable(at.x, at.y)

## Draw it all. `tool` is Park's ground, `glowing` its lamp mesh, `solid` the
## body whose colliders the stalls are added to.
func build(tool: SurfaceTool, glowing: SurfaceTool, solid: StaticBody3D) -> void:
	_pave_avenue(tool)
	_pave_carousel_ring(tool)
	_pave_gate_apron(tool)
	_lamps_and_bunting(tool, glowing)
	_gate_bulbs(glowing)
	_signs(tool)
	_stalls(tool, glowing, solid)
	_benches_and_bins(tool)

# ---------------------------------------------------------------- pavement

func _pave_avenue(tool: SurfaceTool) -> void:
	var y := ParkSpec.LEVEL + PAVE_LIFT
	var tile := 2.0
	var columns := 3
	var width := AVENUE_HALF * 2.0 / float(columns)
	var rows := int((AVENUE_FROM - AVENUE_TO) / tile)
	for row in rows:
		var z0 := AVENUE_FROM - float(row) * tile
		var z1 := z0 - tile
		for column in columns:
			var x0 := AVENUE_X - AVENUE_HALF + float(column) * width
			_flat(tool, x0, z0, x0 + width - 0.06, z1 + 0.06, y,
				PAVER_A if (row + column) % 2 == 0 else PAVER_B)
	# The kerb: a painted edge on each side, the same terracotta as the
	# kiosk's roof line, so the strip has an outline from fifty metres.
	for side: float in [-1.0, 1.0]:
		var edge := AVENUE_X + side * (AVENUE_HALF + 0.12)
		_flat(tool, minf(edge, edge + 0.0) - 0.12, AVENUE_FROM, edge + 0.12, AVENUE_TO, y + 0.005, PAVER_EDGE)

func _pave_carousel_ring(tool: SurfaceTool) -> void:
	var c := Park.CAROUSEL_AT
	var y := ParkSpec.LEVEL + PAVE_LIFT
	var inner := Carousel.RADIUS + 2.7
	var outer := inner + 1.5
	var sectors := 40
	for sector in sectors:
		var a0 := TAU * float(sector) / float(sectors)
		var a1 := TAU * float(sector + 1) / float(sectors)
		var colour := RED if sector % 2 == 0 else CREAM
		# Half-way round the ring, a tile's worth lighter: a mosaic, not a stripe.
		_ring_piece(tool, c.x, c.z, inner, outer, a0, a1, y, colour)

func _pave_gate_apron(tool: SurfaceTool) -> void:
	var gate := ParkSpec.gate()
	var y := ParkSpec.LEVEL + PAVE_LIFT
	var half := ParkSpec.GATE_WIDTH * 0.5
	var tile := 1.75
	for row in 4:
		for column in 4:
			var x0 := gate.x - half + float(column) * (half * 2.0 / 4.0)
			var z0 := gate.z + 2.2 - float(row) * tile
			if z0 - tile < ParkSpec.SOUTH - 9.0 and row > 3:
				continue
			_flat(tool, x0, z0, x0 + half * 0.5 - 0.06, z0 - tile + 0.06, y + 0.004,
				PAVER_A if (row + column) % 2 == 0 else PAVER_B)

# ----------------------------------------------------------- lamps, bunting

func _lamp_spots() -> Array[Vector2]:
	var spots: Array[Vector2] = []
	var z := AVENUE_FROM - 1.0
	while z > AVENUE_TO + 2.0:
		for side: float in [-1.0, 1.0]:
			# On the kerb's outside, a little way off the paving.
			var spot := Vector2(AVENUE_X + side * (AVENUE_HALF + 0.55), z)
			if _clear(spot, 0.3):
				spots.append(spot)
		z -= LAMP_STEP
	return spots

func _lamps_and_bunting(tool: SurfaceTool, glowing: SurfaceTool) -> void:
	var spots := _lamp_spots()
	for spot in spots:
		_lamp(tool, glowing, spot)
		props.append({"kind": &"lamp", "at": spot, "radius": 0.2, "solid": false})
	# Bunting: along each side from lamp to the next one, and across the
	# avenue from a lamp to its partner on the other side every other station.
	var colour_index := 0
	for spot in spots:
		for other in spots:
			var along := is_equal_approx(other.x, spot.x) and is_equal_approx(spot.y - other.y, LAMP_STEP)
			var across := is_equal_approx(other.y, spot.y) and other.x > spot.x + 1.0 \
				and int(roundf((AVENUE_FROM - spot.y) / LAMP_STEP)) % 2 == 0
			if along or across:
				_bunting(tool, Vector3(spot.x, ParkSpec.LEVEL + LAMP_HEIGHT - 0.15, spot.y),
					Vector3(other.x, ParkSpec.LEVEL + LAMP_HEIGHT - 0.15, other.y), colour_index)
				colour_index += 1

func _lamp(tool: SurfaceTool, glowing: SurfaceTool, spot: Vector2) -> void:
	var base := Vector3(spot.x, ParkSpec.LEVEL, spot.y)
	var foot := CylinderMesh.new()
	foot.top_radius = 0.17
	foot.bottom_radius = 0.24
	foot.height = 0.5
	foot.radial_segments = 6
	foot.rings = 1
	Park._add(tool, foot, Transform3D(Basis(), base + Vector3(0.0, 0.25, 0.0)), IRON)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.06
	pole.bottom_radius = 0.09
	pole.height = LAMP_HEIGHT - 0.5
	pole.radial_segments = 6
	pole.rings = 1
	Park._add(tool, pole, Transform3D(Basis(), base + Vector3(0.0, 0.5 + pole.height * 0.5, 0.0)), IRON)
	# A gold ring where the lantern sits, and the lantern's red cap.
	var collar := CylinderMesh.new()
	collar.top_radius = 0.2
	collar.bottom_radius = 0.2
	collar.height = 0.07
	collar.radial_segments = 8
	collar.rings = 1
	Park._add(tool, collar, Transform3D(Basis(), base + Vector3(0.0, LAMP_HEIGHT - 0.1, 0.0)), GOLD)
	var cap := CylinderMesh.new()
	cap.top_radius = 0.0
	cap.bottom_radius = 0.34
	cap.height = 0.32
	cap.radial_segments = 8
	cap.rings = 1
	Park._add(tool, cap, Transform3D(Basis(), base + Vector3(0.0, LAMP_HEIGHT + 0.38, 0.0)), RED)
	Park._add(tool, _ball(0.07), Transform3D(Basis(), base + Vector3(0.0, LAMP_HEIGHT + 0.58, 0.0)), GOLD)
	# The globe: pale paint by day, the glow at dusk.
	var globe := _ball(0.24)
	Park._add(tool, globe, Transform3D(Basis(), base + Vector3(0.0, LAMP_HEIGHT + 0.12, 0.0)), Color(0.98, 0.94, 0.78))
	Park._add(glowing, _ball(0.27), Transform3D(Basis(), base + Vector3(0.0, LAMP_HEIGHT + 0.12, 0.0)), BULB)

static func _ball(radius: float) -> SphereMesh:
	var ball := SphereMesh.new()
	ball.radius = radius
	ball.height = radius * 2.0
	ball.radial_segments = 8
	ball.rings = 5
	return ball

## A string of pennants hanging in a shallow curve from one point to another.
func _bunting(tool: SurfaceTool, from: Vector3, to: Vector3, colour_index: int) -> void:
	var length := from.distance_to(to)
	var count := maxi(4, int(length / 0.55))
	var sag := minf(0.8, length * 0.07)
	for piece in count:
		var t0 := float(piece) / float(count)
		var t1 := float(piece + 1) / float(count)
		var a := _on_string(from, to, t0, sag)
		var b := _on_string(from, to, t1, sag)
		var middle := (a + b) * 0.5
		var colour := PENNANTS[(colour_index + piece) % PENNANTS.size()]
		var tip := middle + Vector3(0.0, -0.42, 0.0)
		Park._tri(tool, a, b, tip, colour)
		Park._tri(tool, b, a, tip, colour)
		# The cord, as a thin double-sided ribbon.
		var up := Vector3(0.0, 0.025, 0.0)
		Park._tri(tool, a, b, b + up, IRON)
		Park._tri(tool, a, b + up, a + up, IRON)
		Park._tri(tool, b, a, b + up, IRON)
		Park._tri(tool, a, a + up, b + up, IRON)

static func _on_string(from: Vector3, to: Vector3, t: float, sag: float) -> Vector3:
	var p := from.lerp(to, t)
	p.y -= sag * 4.0 * t * (1.0 - t)
	return p

func _gate_bulbs(glowing: SurfaceTool) -> void:
	# Bulbs along the gateway's beam and a ring of them up each post: the
	# fairground's door says "open" from the road at dusk.
	var gate := ParkSpec.gate()
	var half := ParkSpec.GATE_WIDTH * 0.5
	for i in 15:
		var x := gate.x - half - 0.2 + float(i) * (ParkSpec.GATE_WIDTH + 0.4) / 14.0
		Park._add(glowing, _ball(0.1), Transform3D(Basis(), Vector3(x, ParkSpec.LEVEL + 4.78, gate.z - 0.27)),
			BULB if i % 2 == 0 else Color(0.98, 0.70, 0.30))
	for side: float in [-1.0, 1.0]:
		for i in 9:
			Park._add(glowing, _ball(0.08), Transform3D(Basis(),
				Vector3(gate.x + side * half, ParkSpec.LEVEL + 0.6 + float(i) * 0.5, gate.z - 0.34)),
				BULB if i % 2 == 0 else Color(0.98, 0.70, 0.30))

# ------------------------------------------------------------------- signs

## A picture sign for each ride, on a post by the avenue: a round board with
## the ride drawn on it, because a six-year-old reads pictures. It faces the
## avenue, and stands on its outer side, clear of the paving.
func _signs(tool: SurfaceTool) -> void:
	var rides: Array = [
		[&"carousel", 3.0, 1.0], [&"coaster", -24.0, 1.0], [&"wheel", -100.0, 1.0],
		[&"drop_tower", -140.0, 1.0], [&"pirate_ship", -146.0, -1.0],
	]
	for ride: Array in rides:
		var side: float = ride[2]
		var spot := Vector2(AVENUE_X + side * (AVENUE_HALF + 1.2), ride[1])
		if not _clear(spot, 0.3):
			# The carousel's own ground is a keep-out; its sign stands on the
			# avenue's west kerb instead.
			spot.x = AVENUE_X - (AVENUE_HALF + 1.2)
			if not _clear(spot, 0.3):
				continue
		_sign(tool, ride[0], spot, -side)
		props.append({"kind": &"sign", "at": spot, "radius": 0.25, "solid": false})

## `face` is the side the board looks towards, along x (+1 east, -1 west).
func _sign(tool: SurfaceTool, ride: StringName, spot: Vector2, face: float) -> void:
	var base := Vector3(spot.x, ParkSpec.LEVEL, spot.y)
	var post := CylinderMesh.new()
	post.top_radius = 0.06
	post.bottom_radius = 0.08
	post.height = 2.4
	post.radial_segments = 6
	post.rings = 1
	Park._add(tool, post, Transform3D(Basis(), base + Vector3(0.0, 1.2, 0.0)), WOOD)
	var turn := Basis(Vector3.BACK, PI * 0.5)
	var centre := base + Vector3(face * 0.02, 2.55, 0.0)
	var board := CylinderMesh.new()
	board.top_radius = 0.62
	board.bottom_radius = 0.62
	board.height = 0.08
	board.radial_segments = 14
	board.rings = 1
	Park._add(tool, board, Transform3D(turn, centre), CREAM)
	var rim := CylinderMesh.new()
	rim.top_radius = 0.68
	rim.bottom_radius = 0.68
	rim.height = 0.06
	rim.radial_segments = 14
	rim.rings = 1
	Park._add(tool, rim, Transform3D(turn, centre - Vector3(face * 0.01, 0.0, 0.0)), RED)
	# The picture, in front of the board: `p(dz, dy)` is a spot on its face.
	var front := centre + Vector3(face * 0.06, 0.0, 0.0)
	var across := Vector3(0.0, 0.0, -face)
	match ride:
		&"carousel":
			var roof := CylinderMesh.new()
			roof.top_radius = 0.0
			roof.bottom_radius = 0.46
			roof.height = 0.3
			roof.radial_segments = 8
			roof.rings = 1
			Park._add(tool, roof, Transform3D(Basis(), front + Vector3(0.0, 0.26, 0.0)), RED)
			for side: float in [-1.0, 0.0, 1.0]:
				_stick(tool, front + across * (side * 0.27) + Vector3(0.0, -0.08, 0.0), 0.5, GOLD, 0.04)
			Park._add(tool, _ball(0.1), Transform3D(Basis(), front + Vector3(0.0, -0.3, 0.0)), PINK)
		&"coaster":
			var loop := TorusMesh.new()
			loop.inner_radius = 0.2
			loop.outer_radius = 0.27
			loop.rings = 14
			loop.ring_segments = 5
			Park._add(tool, loop, Transform3D(turn, front + Vector3(0.0, 0.08, 0.0)), BLUE)
			_stick(tool, front + Vector3(0.0, -0.34, 0.0) + across * 0.0, 0.0, BLUE, 0.0)
			var rail := BoxMesh.new()
			rail.size = Vector3(0.05, 0.06, 0.95)
			Park._add(tool, rail, Transform3D(Basis(), front + Vector3(0.0, -0.3, 0.0)), BLUE)
			Park._add(tool, _ball(0.07), Transform3D(Basis(), front + Vector3(0.0, 0.36, 0.0) * 0.0 + across * 0.0 + Vector3(0.0, -0.18, 0.0)), RED)
		&"wheel":
			var ring := TorusMesh.new()
			ring.inner_radius = 0.34
			ring.outer_radius = 0.4
			ring.rings = 16
			ring.ring_segments = 5
			Park._add(tool, ring, Transform3D(turn, front), BLUE)
			for spoke in 3:
				var bar := BoxMesh.new()
				bar.size = Vector3(0.04, 0.04, 0.7)
				Park._add(tool, bar, Transform3D(Basis(Vector3.RIGHT, PI * float(spoke) / 3.0), front), BLUE)
			for dot in 6:
				var a := TAU * float(dot) / 6.0
				Park._add(tool, _ball(0.06), Transform3D(Basis(),
					front + Vector3(0.0, cos(a) * 0.4, sin(a) * 0.4)), RED if dot % 2 == 0 else GOLD)
		&"drop_tower":
			var tower := BoxMesh.new()
			tower.size = Vector3(0.07, 0.9, 0.07)
			Park._add(tool, tower, Transform3D(Basis(), front), BLUE)
			var car := BoxMesh.new()
			car.size = Vector3(0.08, 0.14, 0.36)
			Park._add(tool, car, Transform3D(Basis(), front + Vector3(0.0, 0.22, 0.0)), RED)
			Park._add(tool, car, Transform3D(Basis(), front + Vector3(0.0, -0.3, 0.0)), GOLD)
			var arrow := CylinderMesh.new()
			arrow.top_radius = 0.0
			arrow.bottom_radius = 0.1
			arrow.height = 0.18
			arrow.radial_segments = 4
			arrow.rings = 1
			Park._add(tool, arrow, Transform3D(Basis(), front + across * 0.3 + Vector3(0.0, -0.1, 0.0)), GREEN)
		&"pirate_ship":
			var hull := BoxMesh.new()
			hull.size = Vector3(0.08, 0.16, 0.8)
			Park._add(tool, hull, Transform3D(Basis(), front + Vector3(0.0, -0.22, 0.0)), RED)
			_stick(tool, front + Vector3(0.0, 0.0, 0.0), 0.62, WOOD, 0.04)
			Park._tri(tool, front + Vector3(0.03, 0.28, 0.0), front + Vector3(0.03, -0.08, 0.0) + across * 0.34,
				front + Vector3(0.03, -0.08, 0.0), CREAM)
			Park._tri(tool, front + Vector3(0.03, 0.28, 0.0), front + Vector3(0.03, -0.08, 0.0),
				front + Vector3(0.03, -0.08, 0.0) + across * 0.34, CREAM)

## A thin upright of a given height whose middle is at `at`.
func _stick(tool: SurfaceTool, at: Vector3, height: float, colour: Color, thickness: float) -> void:
	if height <= 0.0:
		return
	var box := BoxMesh.new()
	box.size = Vector3(thickness, height, thickness)
	Park._add(tool, box, Transform3D(Basis(), at), colour)

# ------------------------------------------------------------------ stalls

func _stalls(tool: SurfaceTool, glowing: SurfaceTool, solid: StaticBody3D) -> void:
	for index in STALL_Z.size():
		var spot := Vector2(STALL_X, STALL_Z[index])
		if not _clear(spot, 2.0):
			continue
		_stall(tool, glowing, solid, spot, STALL_KINDS[index], index)
		props.append({"kind": &"stall", "at": spot, "radius": 2.0, "solid": true})

func _stall(
	tool: SurfaceTool, glowing: SurfaceTool, solid: StaticBody3D, spot: Vector2,
	kind: StringName, index: int
) -> void:
	var base := Vector3(spot.x, ParkSpec.LEVEL, spot.y)
	var body_colour := [BLUE, RED, GREEN, GOLD, PINK][index % 5] as Color
	var stripe: Color = [CREAM, CREAM, CREAM, RED, CREAM][index % 5]
	var awning: Color = [RED, BLUE, PINK, BLUE, GOLD][index % 5]

	# Counter, back wall and the two sides.
	var counter := BoxMesh.new()
	counter.size = Vector3(0.7, 1.0, STALL_HALF_WIDTH * 2.0)
	Park._add(tool, counter, Transform3D(Basis(), base + Vector3(-0.6, 0.5, 0.0)), body_colour)
	var top := BoxMesh.new()
	top.size = Vector3(0.95, 0.07, STALL_HALF_WIDTH * 2.0 + 0.12)
	Park._add(tool, top, Transform3D(Basis(), base + Vector3(-0.66, 1.03, 0.0)), CREAM)
	var back := BoxMesh.new()
	back.size = Vector3(0.1, STALL_HEIGHT, STALL_HALF_WIDTH * 2.0)
	Park._add(tool, back, Transform3D(Basis(), base + Vector3(STALL_HALF_DEPTH - 0.05, STALL_HEIGHT * 0.5, 0.0)), body_colour.darkened(0.12))
	for side: float in [-1.0, 1.0]:
		var wall := BoxMesh.new()
		wall.size = Vector3(STALL_HALF_DEPTH * 2.0, STALL_HEIGHT, 0.1)
		Park._add(tool, wall, Transform3D(Basis(), base + Vector3(0.0, STALL_HEIGHT * 0.5, side * (STALL_HALF_WIDTH - 0.05))), body_colour.darkened(0.06))
		# A front post at the end of the counter, up to the awning.
		_stick(tool, base + Vector3(-1.05, 1.1, side * (STALL_HALF_WIDTH - 0.05)), 2.2, CREAM, 0.1)

	# The awning: stripes across a tilted roof, with a scalloped valance and a
	# bulb in each scallop. Higher at the back, so rain runs off the front.
	var tilt := Basis(Vector3.BACK, 0.16)
	var roof_at := base + Vector3(-0.25, 2.45, 0.0)
	var strips := 8
	var strip := STALL_HALF_WIDTH * 2.0 / float(strips)
	for piece in strips:
		var z := -STALL_HALF_WIDTH + (float(piece) + 0.5) * strip
		var slab := BoxMesh.new()
		slab.size = Vector3(2.5, 0.08, strip)
		var colour := awning if piece % 2 == 0 else stripe
		Park._add(tool, slab, Transform3D(tilt, roof_at + tilt * Vector3(0.0, 0.0, z)), colour)
		var lip := roof_at + tilt * Vector3(-1.25, 0.0, 0.0)
		var left := lip + Vector3(0.0, 0.0, z - strip * 0.5)
		var right := lip + Vector3(0.0, 0.0, z + strip * 0.5)
		var tip := lip + Vector3(-0.02, -0.32, z)
		Park._tri(tool, left, right, tip, colour)
		Park._tri(tool, right, left, tip, colour)
		Park._add(glowing, _ball(0.06), Transform3D(Basis(), tip + Vector3(-0.06, -0.04, 0.0)), BULB)

	# Wares on the counter, so it is not an empty shelf.
	var shelf := base + Vector3(-0.66, 1.07, 0.0)
	for item in 5:
		var z := -STALL_HALF_WIDTH + 0.4 + float(item) * (STALL_HALF_WIDTH * 2.0 - 0.8) / 4.0
		var ware := CylinderMesh.new()
		ware.top_radius = 0.14
		ware.bottom_radius = 0.11
		ware.height = 0.26
		ware.radial_segments = 7
		ware.rings = 1
		Park._add(tool, ware, Transform3D(Basis(), shelf + Vector3(0.0, 0.13, z)), PENNANTS[(index + item) % PENNANTS.size()])

	# The sign on the awning: the product, drawn.
	_stall_picture(tool, kind, base + Vector3(-0.55, 3.35, 0.0))

	# Solid like the kiosk: one box for the body (the awning is above head height).
	Park._solid(solid, Vector3(STALL_HALF_DEPTH * 2.0 + 0.2, STALL_HEIGHT, STALL_HALF_WIDTH * 2.0),
		Transform3D(Basis(), base + Vector3(0.0, STALL_HEIGHT * 0.5 + 0.0, 0.0)))

func _stall_picture(tool: SurfaceTool, kind: StringName, at: Vector3) -> void:
	var turn := Basis(Vector3.BACK, PI * 0.5)
	var plate := CylinderMesh.new()
	plate.top_radius = 0.62
	plate.bottom_radius = 0.62
	plate.height = 0.08
	plate.radial_segments = 14
	plate.rings = 1
	Park._add(tool, plate, Transform3D(turn, at), CREAM)
	var rim := CylinderMesh.new()
	rim.top_radius = 0.68
	rim.bottom_radius = 0.68
	rim.height = 0.06
	rim.radial_segments = 14
	rim.rings = 1
	Park._add(tool, rim, Transform3D(turn, at + Vector3(0.01, 0.0, 0.0)), GOLD)
	# A short post down to the awning so the board is not hung in the air.
	_stick(tool, at + Vector3(0.0, -0.78, 0.0), 0.34, WOOD, 0.08)
	var f := at + Vector3(-0.07, 0.0, 0.0)
	match kind:
		&"popcorn":
			var bucket := CylinderMesh.new()
			bucket.top_radius = 0.26
			bucket.bottom_radius = 0.18
			bucket.height = 0.36
			bucket.radial_segments = 8
			bucket.rings = 1
			Park._add(tool, bucket, Transform3D(Basis(), f + Vector3(0.0, -0.17, 0.0)), RED)
			for puff in 6:
				var a := TAU * float(puff) / 6.0
				Park._add(tool, _ball(0.13), Transform3D(Basis(),
					f + Vector3(0.0, 0.1 + 0.05 * float(puff % 2), cos(a) * 0.15)), Color(1.0, 0.97, 0.80))
		&"balloons":
			var colours: Array[Color] = [RED, BLUE, GOLD]
			for balloon in 3:
				var dz := (float(balloon) - 1.0) * 0.27
				var dy := 0.12 + (0.08 if balloon == 1 else 0.0)
				Park._add(tool, _ball(0.17), Transform3D(Basis(), f + Vector3(0.0, dy, dz)), colours[balloon])
				_stick(tool, f + Vector3(0.0, dy - 0.3, dz * 0.5), 0.34, IRON, 0.015)
		&"icecream":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.2
			cone.bottom_radius = 0.0
			cone.height = 0.42
			cone.radial_segments = 8
			cone.rings = 1
			Park._add(tool, cone, Transform3D(Basis(), f + Vector3(0.0, -0.2, 0.0)), Color(0.90, 0.68, 0.36))
			Park._add(tool, _ball(0.21), Transform3D(Basis(), f + Vector3(0.0, 0.06, 0.0)), PINK)
			Park._add(tool, _ball(0.16), Transform3D(Basis(), f + Vector3(0.0, 0.27, 0.0)), CREAM)
		&"rings":
			var hoop := TorusMesh.new()
			hoop.inner_radius = 0.14
			hoop.outer_radius = 0.22
			hoop.rings = 12
			hoop.ring_segments = 5
			for k in 3:
				Park._add(tool, hoop, Transform3D(turn, f + Vector3(0.0, -0.22 + float(k) * 0.14, (float(k) - 1.0) * 0.06)),
					[RED, BLUE, GREEN][k] as Color)
			_stick(tool, f + Vector3(0.0, 0.0, 0.0), 0.62, WOOD, 0.06)
		&"lemonade":
			var glass := CylinderMesh.new()
			glass.top_radius = 0.22
			glass.bottom_radius = 0.16
			glass.height = 0.5
			glass.radial_segments = 8
			glass.rings = 1
			Park._add(tool, glass, Transform3D(Basis(), f + Vector3(0.0, -0.08, 0.0)), Color(1.0, 0.92, 0.45))
			var slice := _ball(0.15)
			Park._add(tool, slice, Transform3D(Basis(Vector3.RIGHT, 0.0) * Basis.from_scale(Vector3(1.0, 1.0, 0.45)), f + Vector3(0.0, 0.22, 0.2)), GOLD)
			_stick(tool, f + Vector3(0.0, 0.2, -0.12), 0.5, RED, 0.03)

# ------------------------------------------------------ benches and bins

func _benches_and_bins(tool: SurfaceTool) -> void:
	for z: float in [6.0, -30.0, -58.0, -84.0, -118.0]:
		# On the avenue's east side, facing it; a bench is nobody's wall.
		var spot := Vector2(AVENUE_X + AVENUE_HALF + 0.95, z)
		if not _clear(spot, 0.6):
			spot.x = AVENUE_X - AVENUE_HALF - 0.95
			if not _clear(spot, 0.6):
				continue
		var face := -1.0 if spot.x > AVENUE_X else 1.0
		_bench(tool, spot, face)
		props.append({"kind": &"bench", "at": spot, "radius": 0.6, "solid": false})
		var bin := Vector2(spot.x, z - 1.7)
		if _clear(bin, 0.3):
			_bin(tool, bin)
			props.append({"kind": &"bin", "at": bin, "radius": 0.3, "solid": false})

func _bench(tool: SurfaceTool, spot: Vector2, face: float) -> void:
	var base := Vector3(spot.x, ParkSpec.LEVEL, spot.y)
	var seat := BoxMesh.new()
	seat.size = Vector3(0.5, 0.07, 1.6)
	Park._add(tool, seat, Transform3D(Basis(), base + Vector3(0.0, 0.46, 0.0)), WOOD)
	var back := BoxMesh.new()
	back.size = Vector3(0.07, 0.4, 1.6)
	Park._add(tool, back, Transform3D(Basis(Vector3.BACK, -face * 0.12), base + Vector3(-face * 0.26, 0.75, 0.0)), RED)
	for side: float in [-1.0, 1.0]:
		var leg := BoxMesh.new()
		leg.size = Vector3(0.5, 0.46, 0.07)
		Park._add(tool, leg, Transform3D(Basis(), base + Vector3(0.0, 0.23, side * 0.7)), IRON)

func _bin(tool: SurfaceTool, spot: Vector2) -> void:
	var base := Vector3(spot.x, ParkSpec.LEVEL, spot.y)
	var drum := CylinderMesh.new()
	drum.top_radius = 0.27
	drum.bottom_radius = 0.22
	drum.height = 0.75
	drum.radial_segments = 8
	drum.rings = 1
	Park._add(tool, drum, Transform3D(Basis(), base + Vector3(0.0, 0.375, 0.0)), GREEN)
	var lid := CylinderMesh.new()
	lid.top_radius = 0.0
	lid.bottom_radius = 0.3
	lid.height = 0.2
	lid.radial_segments = 8
	lid.rings = 1
	Park._add(tool, lid, Transform3D(Basis(), base + Vector3(0.0, 0.85, 0.0)), CREAM)
	var band := CylinderMesh.new()
	band.top_radius = 0.275
	band.bottom_radius = 0.275
	band.height = 0.1
	band.radial_segments = 8
	band.rings = 1
	Park._add(tool, band, Transform3D(Basis(), base + Vector3(0.0, 0.5, 0.0)), GOLD)

# ----------------------------------------------------------------- paint

## A flat rectangle lying on the ground, facing up. x0 < x1 and z0 > z1 or
## either way round: the corners are sorted here.
static func _flat(tool: SurfaceTool, xa: float, za: float, xb: float, zb: float, y: float, colour: Color) -> void:
	var x0 := minf(xa, xb)
	var x1 := maxf(xa, xb)
	var z0 := minf(za, zb)
	var z1 := maxf(za, zb)
	Park._tri(tool, Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), colour)
	Park._tri(tool, Vector3(x0, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1), colour)

static func _ring_piece(
	tool: SurfaceTool, cx: float, cz: float, inner: float, outer: float,
	a0: float, a1: float, y: float, colour: Color
) -> void:
	var p0 := Vector3(cx + cos(a0) * inner, y, cz + sin(a0) * inner)
	var p1 := Vector3(cx + cos(a1) * inner, y, cz + sin(a1) * inner)
	var q0 := Vector3(cx + cos(a0) * outer, y, cz + sin(a0) * outer)
	var q1 := Vector3(cx + cos(a1) * outer, y, cz + sin(a1) * outer)
	# Angles run from +x towards +z, which is clockwise seen from above.
	Park._tri(tool, p0, q0, q1, colour)
	Park._tri(tool, p0, q1, p1, colour)
