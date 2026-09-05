class_name Places
extends Node3D

## The playground, the swimming pool and the café.
##
## These exist because the valley was large and evenly interesting, which means
## nowhere in particular was worth going. Everything a child could do, they
## could do wherever they happened to be standing. A destination is a place that
## offers something the rest of the valley does not.
##
## One file for all three because they are the same problem: a fixed structure
## standing on levelled ground, with a small rule about what happens when a
## child is inside it. What differs is only that rule.
##
## The playground is deliberately the simplest thing in the game. It is the
## two-year-old's entry point: he cannot work the stick reliably, but he can
## press a button and watch something happen.

signal used(place: StringName)

const PLAYGROUND := &"playground"
const POOL := &"pool"
const CAFE := &"cafe"

const ALL: Array[StringName] = [PLAYGROUND, POOL, CAFE]

## How close a child must be for a place to offer itself.
const REACH := 5.5

## What a plate of food at the café costs, and what it restores. Priced so that
## a hungry child can afford it from one round of looking after animals.
const MEAL_PRICE := 3
const MEAL_RESTORE := 0.55

## The pool's shape lives in PlaceSpec, because the height field digs the hole
## and cannot depend on this file. Mirrored here so callers have one name.
const POOL_DEPTH := PlaceSpec.POOL_DEPTH
const POOL_HALF := PlaceSpec.POOL_HALF

## How high the swing carries a child, how long one push lasts, and how far the
## seat swings at the top of its arc.
const SWING_LIFT := 1.6
const SWING_TIME := 3.2
const SWING_ARC := 0.85

## The slide. A child who steps onto the top is carried down it, because a slide
## you can only stand next to is scenery.
const SLIDE_SPEED := 4.2
const SLIDE_TOP := Vector3(3.4, 1.72, -1.35)
const SLIDE_FOOT := Vector3(3.4, 0.18, 1.5)
## How close to the top of the slide a child has to be to start sliding.
const SLIDE_GRAB := 1.1

var field: HeightField

var _camp := Vector3.ZERO
var _spots: Dictionary = {}
var _swing_seat: Node3D = null
var _swing := 0.0

func _init(height_field: HeightField) -> void:
	field = height_field

## Put the three places around the camp. Called once.
func stand_up(camp: Vector3) -> void:
	_camp = camp
	# Positions come from PlaceSpec, which is also what the height field levels
	# and excavates against. Repeating the offsets here would let the buildings
	# drift off their own flat ground the first time one was moved.
	for place in ALL:
		_place(place, PlaceSpec.centre_of(place, camp))

func position_of(place: StringName) -> Vector3:
	return _spots.get(place, Vector3.ZERO)

func exists(place: StringName) -> bool:
	return _spots.has(place)

## The place a child is standing in, or an empty name.
func nearest(at: Vector3) -> StringName:
	var best := &""
	var best_distance := REACH
	for place in _spots:
		var flat: Vector3 = _spots[place] - at
		flat.y = 0.0
		var distance := flat.length()
		if distance < best_distance:
			best_distance = distance
			best = place
	return best

## How deep the water is at a point, counting the pool. Zero everywhere else.
##
## The pool is a hole in the ground filled to the brim rather than a box of
## water sitting on it, so its surface is at ground level and a child walks in
## rather than climbing over a lip.
func water_depth_at(x: float, z: float) -> float:
	if not _spots.has(POOL):
		return 0.0
	# The same function the terrain used to dig the hole, so the water is
	# exactly as deep as the ground is low. Two separate formulas here would
	# drift, and a child would float above the floor or stand in the water.
	return PlaceSpec.excavation(x, z, _camp)

## How deep a body at `at` is submerged, counting the river and the pool.
##
## Deliberately not "how deep is the water here": those agree only while a child
## is standing on the bottom. Asking the wrong one ignores the player's own
## height, so a child who floats up and breaks the surface is still reported as
## being in water — buoyancy keeps pushing, gravity is never applied, and they
## rise for as long as the game is left running. A tablet found one 1,445 m up.
##
## Returns zero when the body is above the surface, which is what makes gravity
## start again.
func submersion(at: Vector3, body_height: float) -> float:
	var ground := field.height_at(at.x, at.z)
	var feet := at.y - body_height * 0.5

	var surface := -1e9
	# The river: its surface is the world's water line, wherever the bed is
	# below it.
	if ground < HeightField.WATER_LEVEL:
		surface = HeightField.WATER_LEVEL
	# The pool: filled to the brim of the ground it was dug from, so its surface
	# is that ground plus what was excavated out of it.
	var dug := water_depth_at(at.x, at.z)
	if dug > 0.0:
		surface = maxf(surface, ground + dug)

	if surface < -1e8:
		return 0.0
	return maxf(0.0, surface - feet)

## Push the swing. Returns true if there was a swing to push.
func push_swing() -> bool:
	if _swing_seat == null or not is_instance_valid(_swing_seat):
		return false
	_swing = SWING_TIME
	used.emit(PLAYGROUND)
	return true

func swinging() -> bool:
	return _swing > 0.0

## Where a child on the swing should be right now, or an empty vector when the
## swing is still. Returned rather than applied, because the player owns its own
## position and a node that moves the player from outside fights the character
## controller — the same reason a mount follows rather than carries.
func swing_rider_at() -> Vector3:
	if _swing <= 0.0 or not _spots.has(PLAYGROUND):
		return Vector3.ZERO
	var pivot: Vector3 = _spots[PLAYGROUND] + Vector3(0.0, 2.86, 0.0)
	var angle := _swing_angle()
	# The seat hangs 1.9 m below the bar; the rider sits on it.
	return pivot + Vector3(0.0, -1.9, 0.0).rotated(Vector3.RIGHT, angle)

## Where the top of the slide is, in world space.
func slide_top() -> Vector3:
	if not _spots.has(PLAYGROUND):
		return Vector3.ZERO
	return _spots[PLAYGROUND] + SLIDE_TOP

## Where the foot of the slide is.
func slide_foot() -> Vector3:
	if not _spots.has(PLAYGROUND):
		return Vector3.ZERO
	return _spots[PLAYGROUND] + SLIDE_FOOT

## Is a child standing at the top of the slide, ready to go down?
func at_slide_top(at: Vector3) -> bool:
	if not _spots.has(PLAYGROUND):
		return false
	return at.distance_to(slide_top()) < SLIDE_GRAB

func _swing_angle() -> float:
	var strength := _swing / SWING_TIME
	return sin(_swing * 4.4) * SWING_ARC * strength

func _process(delta: float) -> void:
	if _swing <= 0.0:
		return
	_swing = maxf(0.0, _swing - delta)
	if _swing_seat == null or not is_instance_valid(_swing_seat):
		return
	# Decaying arc, so the swing slows to a stop instead of stopping dead.
	_swing_seat.rotation.x = _swing_angle()

func _place(place: StringName, at: Vector3) -> void:
	var spot := at
	spot.y = field.height_at(at.x, at.z)
	_spots[place] = spot
	match place:
		PLAYGROUND:
			_build_playground(spot)
		POOL:
			_build_pool(spot)
		CAFE:
			_build_cafe(spot)

## A frame with a hanging seat, and a slide beside it.
func _build_playground(at: Vector3) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var timber := Color(0.62, 0.44, 0.28)
	var metal := Color(0.74, 0.76, 0.80)

	# Two A-frames and a crossbar.
	for side in PackedFloat32Array([-1.0, 1.0]):
		for lean in PackedFloat32Array([-1.0, 1.0]):
			var post := CylinderMesh.new()
			post.top_radius = 0.07
			post.bottom_radius = 0.09
			post.height = 3.0
			post.radial_segments = 6
			post.rings = 1
			_add(tool, post, Transform3D(
				Basis(Vector3.RIGHT, deg_to_rad(lean * 13.0)),
				Vector3(side * 1.5, 1.45, lean * 0.34)
			), timber)

	var bar := CylinderMesh.new()
	bar.top_radius = 0.06
	bar.bottom_radius = 0.06
	bar.height = 3.3
	bar.radial_segments = 6
	bar.rings = 1
	_add(tool, bar, Transform3D(
		Basis(Vector3.FORWARD, deg_to_rad(90.0)), Vector3(0.0, 2.86, 0.0)
	), timber)

	# The slide: a ramp on two short legs, in a colour a child will pick out
	# from across the valley.
	var slide := BoxMesh.new()
	slide.size = Vector3(0.9, 0.09, 3.2)
	_add(tool, slide, Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(-26.0)), Vector3(3.4, 0.9, 0.0)
	), Color(0.94, 0.58, 0.26))

	for step in PackedFloat32Array([0.0, 1.0, 2.0]):
		var rung := BoxMesh.new()
		rung.size = Vector3(0.8, 0.07, 0.24)
		_add(tool, rung, Transform3D(
			Basis(), Vector3(3.4, 0.42 + step * 0.42, -1.5 + step * 0.16)
		), metal)

	tool.generate_normals()
	tool.set_material(_material())

	var frame := MeshInstance3D.new()
	frame.mesh = tool.commit()
	frame.transform = Transform3D(Basis(), at)
	add_child(frame)

	# The seat is its own node so it can swing. Pivoted at the crossbar, so
	# rotating it arcs the seat rather than spinning it in place.
	var pivot := Node3D.new()
	pivot.transform = Transform3D(Basis(), at + Vector3(0.0, 2.86, 0.0))
	add_child(pivot)

	var seat_tool := SurfaceTool.new()
	seat_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in PackedFloat32Array([-0.42, 0.42]):
		var rope := CylinderMesh.new()
		rope.top_radius = 0.022
		rope.bottom_radius = 0.022
		rope.height = 1.9
		rope.radial_segments = 5
		rope.rings = 1
		_add(seat_tool, rope, Transform3D(Basis(), Vector3(side, -0.95, 0.0)), metal)

	var seat := BoxMesh.new()
	seat.size = Vector3(1.0, 0.08, 0.36)
	_add(seat_tool, seat, Transform3D(Basis(), Vector3(0.0, -1.9, 0.0)), Color(0.34, 0.58, 0.86))
	seat_tool.generate_normals()
	seat_tool.set_material(_material())

	_swing_seat = MeshInstance3D.new()
	(_swing_seat as MeshInstance3D).mesh = seat_tool.commit()
	pivot.add_child(_swing_seat)

## A tiled rim around a hollow. The water itself is drawn by the water surface,
## which reads the depth from water_depth_at.
func _build_pool(at: Vector3) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var tile := Color(0.88, 0.92, 0.94)

	# No walls and no floor: the height field has already dug the hollow, and a
	# box of walls inside it would fight the terrain for the same pixels.
	for i in 4:
		var along := i % 2 == 0
		var sign_of := 1.0 if i < 2 else -1.0
		var rim := BoxMesh.new()
		if along:
			rim.size = Vector3(POOL_HALF * 2.0 + 0.7, 0.14, 0.7)
		else:
			rim.size = Vector3(0.7, 0.14, POOL_HALF * 2.0 + 0.7)
		var rim_at := Vector3(
			0.0 if along else sign_of * (POOL_HALF + 0.2),
			0.07,
			sign_of * (POOL_HALF + 0.2) if along else 0.0
		)
		_add(tool, rim, Transform3D(Basis(), rim_at), tile)

	tool.generate_normals()
	tool.set_material(_material())

	var pool := MeshInstance3D.new()
	pool.mesh = tool.commit()
	pool.transform = Transform3D(Basis(), at)
	add_child(pool)

	# The water in the pool: a flat pane at the brim, the same blue as the
	# river so the two read as the same substance.
	var pane := PlaneMesh.new()
	pane.size = Vector2(POOL_HALF * 2.0 - 0.1, POOL_HALF * 2.0 - 0.1)
	var surface := StandardMaterial3D.new()
	surface.albedo_color = Color(0.36, 0.62, 0.78, 0.72)
	surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	surface.roughness = 0.16
	surface.metallic = 0.25

	var water := MeshInstance3D.new()
	water.mesh = pane
	water.material_override = surface
	water.transform = Transform3D(Basis(), at + Vector3(0.0, -0.04, 0.0))
	add_child(water)

## A hut with a counter, a striped awning and two stools.
func _build_cafe(at: Vector3) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var wall := Color(0.90, 0.86, 0.76)
	var timber := Color(0.54, 0.38, 0.24)
	var stripe_a := Color(0.88, 0.34, 0.30)
	var stripe_b := Color(0.96, 0.94, 0.90)

	var hut := BoxMesh.new()
	hut.size = Vector3(3.4, 2.3, 2.6)
	_add(tool, hut, Transform3D(Basis(), Vector3(0.0, 1.15, 0.8)), wall)

	# A counter across the front, which is what makes it read as somewhere that
	# serves rather than as a shed.
	var counter := BoxMesh.new()
	counter.size = Vector3(3.6, 0.16, 0.8)
	_add(tool, counter, Transform3D(Basis(), Vector3(0.0, 1.02, -0.7)), timber)

	for side in PackedFloat32Array([-1.6, 1.6]):
		var leg := CylinderMesh.new()
		leg.top_radius = 0.07
		leg.bottom_radius = 0.07
		leg.height = 1.0
		leg.radial_segments = 6
		leg.rings = 1
		_add(tool, leg, Transform3D(Basis(), Vector3(side, 0.5, -0.7)), timber)

	# The awning, in stripes, because a striped awning says "café" from further
	# away than any amount of detail on the hut.
	for i in 6:
		var band := BoxMesh.new()
		band.size = Vector3(0.6, 0.07, 1.5)
		_add(tool, band, Transform3D(
			Basis(Vector3.RIGHT, deg_to_rad(-16.0)),
			Vector3(-1.5 + float(i) * 0.6, 2.24, -0.5)
		), stripe_a if i % 2 == 0 else stripe_b)

	for side in PackedFloat32Array([-1.2, 1.2]):
		var stool := CylinderMesh.new()
		stool.top_radius = 0.24
		stool.bottom_radius = 0.20
		stool.height = 0.62
		stool.radial_segments = 8
		stool.rings = 1
		_add(tool, stool, Transform3D(Basis(), Vector3(side, 0.31, -1.7)), timber)

	tool.generate_normals()
	tool.set_material(_material())

	var cafe := MeshInstance3D.new()
	cafe.mesh = tool.commit()
	cafe.transform = Transform3D(Basis(), at)
	add_child(cafe)

## One material for every place, vertex-coloured and shipped with the mesh so
## nothing can attach the geometry without it — see LESSONS.md.
static func _material() -> StandardMaterial3D:
	if _shared == null:
		_shared = StandardMaterial3D.new()
		_shared.vertex_color_use_as_albedo = true
		_shared.vertex_color_is_srgb = true
		_shared.roughness = 0.84
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
