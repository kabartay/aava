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

## Two frames side by side, two seats on each, so two children — or a child and
## a visitor from another phone — can swing together rather than take turns.
## A frame is SWING_WIDTH across between its posts and SWING_BAR high; the two
## frames stand a frame and a half apart so two pairs of children swinging are
## two swings, not one crowd. Seats hang so a child's feet just clear the
## ground.
const SWING_WIDTH := 4.3
const SWING_BAR := 3.72
const SWING_POST := 3.9
const SWING_ROPE := 2.75
const SWING_FRAMES: Array[float] = [-7.5, 3.25]
const SWING_SEATS: Array[float] = [-1.05, 1.05]
## How close a child has to be to a seat to be the one pushing it.
const SWING_REACH := 3.0

## The slide. A child who steps onto the top is carried down it, because a slide
## you can only stand next to is scenery.
const SLIDE_SPEED := 4.2
## Three metres up and nearly six along: a real slide, with a ladder to the top
## of it. The first one was a metre and a half of ramp and read as unfinished.
## A couple of paces from the nearer swing frame's post, so the slide belongs
## to the same playground without a child on the swing kicking someone on the
## ladder.
const SLIDE_TOP := Vector3(8.5, 3.0, -2.65)
const SLIDE_FOOT := Vector3(8.5, 0.22, 3.0)
## How close to the top of the slide a child has to be to start sliding.
const SLIDE_GRAB := 1.1
## Where the ladder's foot is, relative to its top: three metres up over this
## much ground is a slope of about forty-eight degrees, under the fifty-two the
## character can walk, so the ladder is climbed by walking at it.
const LADDER_RUN := Vector3(0.0, -SLIDE_TOP.y, -2.7)
## Where the benches stand: in front of the swings, one per frame, far enough
## forward that a child on a full swing does not reach them.
const BENCHES: Array[float] = [-7.5, 3.25]
const BENCH_Z := 6.2

var field: HeightField

var _camp := Vector3.ZERO
var _spots: Dictionary = {}
## Every seat: where it hangs from, the node that swings, and how much swing is
## left in it. The local child rides at most one of them at a time.
var _seats: Array[Dictionary] = []
var _rider := -1
## The playground's collision and furniture, kept so a check can count them.
var _solid: StaticBody3D = null
var _benches := 0

## How far an empty seat stirs in the wind, and how slowly. A swing that hangs
## perfectly still reads as a model of a swing; one that moves a hand's width
## every few seconds reads as a swing.
const IDLE_SWAY := 0.035
const IDLE_SWAY_SPEED := 0.8
var _wind_time := 0.0

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
		var distance: float
		if place == PLAYGROUND:
			# The playground is big now, and what it offers is a swing: the
			# button belongs beside the seats, not at the geometric middle of
			# the pad, where a child standing at the slide would be offered a
			# swing they cannot reach.
			distance = _nearest_seat_distance(at)
			if distance >= SWING_REACH:
				continue
		else:
			var flat: Vector3 = _spots[place] - at
			flat.y = 0.0
			distance = flat.length()
		if distance < best_distance:
			best_distance = distance
			best = place
	return best

## How far the nearest swing seat is, on the ground.
func _nearest_seat_distance(at: Vector3) -> float:
	var nearest_seat := INF
	for seat in _seats:
		var pivot: Vector3 = seat["pivot"]
		nearest_seat = minf(nearest_seat, Vector2(pivot.x - at.x, pivot.z - at.z).length())
	return nearest_seat

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

## Push the seat a child is standing at. Returns true if there was one in
## reach — a swing across the field cannot be pushed from here.
func push_swing(near: Vector3) -> bool:
	var best := -1
	var best_distance := SWING_REACH
	for i in _seats.size():
		var pivot: Vector3 = _seats[i]["pivot"]
		var flat := Vector2(pivot.x - near.x, pivot.z - near.z).length()
		if flat < best_distance:
			best_distance = flat
			best = i
	if best < 0:
		return false
	_seats[best]["swing"] = SWING_TIME
	_rider = best
	return true

## Is the local child on a moving swing?
func swinging() -> bool:
	return _rider >= 0 and float(_seats[_rider]["swing"]) > 0.0

## Where a child on the swing should be right now, or an empty vector when they
## are not on one. Returned rather than applied, because the player owns its own
## position and a node that moves the player from outside fights the character
## controller — the same reason a mount follows rather than carries.
func swing_rider_at() -> Vector3:
	if not swinging():
		return Vector3.ZERO
	var seat: Dictionary = _seats[_rider]
	var pivot: Vector3 = seat["pivot"]
	return pivot + Vector3(0.0, -SWING_ROPE, 0.0).rotated(Vector3.RIGHT, _swing_angle(float(seat["swing"])))

## Where each seat hangs at rest, in world space. For the checks, and for
## anything that wants to send a child to a swing.
func seat_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for seat in _seats:
		var pivot: Vector3 = seat["pivot"]
		out.append(pivot + Vector3(0.0, -SWING_ROPE, 0.0))
	return out

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

func _swing_angle(swing: float) -> float:
	var strength := swing / SWING_TIME
	return sin(swing * 4.4) * SWING_ARC * strength

func _process(delta: float) -> void:
	_wind_time += delta
	for i in _seats.size():
		var seat: Dictionary = _seats[i]
		var node: Node3D = seat["node"]
		if not is_instance_valid(node):
			continue
		var left := float(seat["swing"])
		if left <= 0.0:
			# Stirring in the wind, each seat on its own phase so the four do not
			# swing in step like a metronome.
			node.rotation.x = sin(_wind_time * IDLE_SWAY_SPEED + float(i) * 1.7) * IDLE_SWAY
			continue
		left = maxf(0.0, left - delta)
		seat["swing"] = left
		# Decaying arc, so the swing slows to a stop instead of stopping dead.
		node.rotation.x = _swing_angle(left)
		if left <= 0.0 and _rider == i:
			_rider = -1

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

## Two swing frames, a slide with a ladder, a hedge round the lot and a tree at
## each corner — a playground rather than a swing standing in a field.
func _build_playground(at: Vector3) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var timber := Color(0.62, 0.44, 0.28)
	var metal := Color(0.74, 0.76, 0.80)
	var paint := Color(0.94, 0.58, 0.26)

	for frame_x in SWING_FRAMES:
		# Two A-frames and a crossbar.
		for side in PackedFloat32Array([-1.0, 1.0]):
			for lean in PackedFloat32Array([-1.0, 1.0]):
				var post := CylinderMesh.new()
				post.top_radius = 0.07
				post.bottom_radius = 0.09
				post.height = SWING_POST
				post.radial_segments = 6
				post.rings = 1
				_add(tool, post, Transform3D(
					Basis(Vector3.RIGHT, deg_to_rad(lean * 13.0)),
					Vector3(frame_x + side * SWING_WIDTH * 0.5, SWING_POST * 0.485, lean * 0.44)
				), timber)
		var bar := CylinderMesh.new()
		bar.top_radius = 0.06
		bar.bottom_radius = 0.06
		bar.height = SWING_WIDTH
		bar.radial_segments = 6
		bar.rings = 1
		_add(tool, bar, Transform3D(
			Basis(Vector3.FORWARD, deg_to_rad(90.0)), Vector3(frame_x, SWING_BAR, 0.0)
		), timber)
		# Metal caps where the bar meets each A, and a foot beam holding each
		# pair of legs together at the ground — the joinery that makes it read
		# as built rather than as three cylinders leaning on each other.
		for side in PackedFloat32Array([-1.0, 1.0]):
			var cap := CylinderMesh.new()
			cap.top_radius = 0.085
			cap.bottom_radius = 0.085
			cap.height = 0.22
			cap.radial_segments = 8
			cap.rings = 1
			_add(tool, cap, Transform3D(
				Basis(Vector3.FORWARD, deg_to_rad(90.0)), Vector3(frame_x + side * SWING_WIDTH * 0.5, SWING_BAR, 0.0)
			), metal)
			var beam := BoxMesh.new()
			beam.size = Vector3(0.14, 0.10, 1.3)
			_add(tool, beam, Transform3D(Basis(), Vector3(frame_x + side * SWING_WIDTH * 0.5, 0.05, 0.0)), timber)

	# The slide. A platform on four legs at the top, a ladder up the back of
	# it, and a long shallow ramp with rails down the front.
	var top := SLIDE_TOP
	var foot := SLIDE_FOOT
	var platform := BoxMesh.new()
	platform.size = Vector3(1.3, 0.12, 1.3)
	var platform_at := Vector3(top.x, top.y, top.z - 0.65)
	_add(tool, platform, Transform3D(Basis(), platform_at), paint)
	for dx in PackedFloat32Array([-0.55, 0.55]):
		for dz in PackedFloat32Array([-0.55, 0.55]):
			var leg := CylinderMesh.new()
			leg.top_radius = 0.06
			leg.bottom_radius = 0.07
			leg.height = top.y
			leg.radial_segments = 6
			leg.rings = 1
			_add(tool, leg, Transform3D(
				Basis(), Vector3(platform_at.x + dx, top.y * 0.5, platform_at.z + dz)
			), metal)
	# The ladder leans up the back of the platform at an angle a child can
	# climb by walking — which is how climbing works here: a collider the shape
	# of the ladder lets the character walk up it, and the rails and rungs are
	# what that looks like.
	var climb_top := Vector3(top.x, top.y, platform_at.z - 0.65)
	var climb_foot := climb_top + LADDER_RUN
	var climb := climb_top - climb_foot
	var climb_basis := Basis.looking_at(climb.normalized(), Vector3.UP)
	for dx in PackedFloat32Array([-0.42, 0.42]):
		var rail := CylinderMesh.new()
		rail.top_radius = 0.035
		rail.bottom_radius = 0.035
		rail.height = climb.length() + 0.5
		rail.radial_segments = 5
		rail.rings = 1
		# A cylinder stands along Y; turned to lie along the climb.
		_add(tool, rail, Transform3D(
			climb_basis * Basis(Vector3.RIGHT, PI * 0.5),
			climb_foot + climb * 0.5 + Vector3(dx, 0.0, 0.0)
		), metal)
	var rungs := int(climb.length() / 0.4)
	for i in rungs:
		var rung := BoxMesh.new()
		rung.size = Vector3(0.84, 0.06, 0.07)
		var along := (float(i) + 0.5) / float(rungs)
		_add(tool, rung, Transform3D(Basis(), climb_foot + climb * along), metal)
	# The ramp, from the front of the platform to the foot.
	var run := Vector3(top.x, top.y - 0.02, top.z)
	var drop := foot - run
	var length := drop.length()
	var ramp := BoxMesh.new()
	ramp.size = Vector3(0.9, 0.09, length)
	var ramp_at := run + drop * 0.5
	# The box's own Z axis laid along the descent, from the platform down to
	# the foot. Built this way rather than from an angle because the first
	# version rotated by that angle with the wrong sign, and the slide went up
	# from its platform into the air — a mirror image that no check saw, since
	# the constants said one thing and the mesh did another.
	var ramp_basis := Basis.looking_at(drop.normalized(), Vector3.UP)
	_add(tool, ramp, Transform3D(ramp_basis, ramp_at), paint)
	for dx in PackedFloat32Array([-0.44, 0.44]):
		var side_rail := BoxMesh.new()
		side_rail.size = Vector3(0.06, 0.18, length)
		_add(tool, side_rail, Transform3D(ramp_basis, ramp_at + ramp_basis * Vector3(dx, 0.12, 0.0)), paint)

	tool.generate_normals()
	tool.set_material(_material())

	var frame := MeshInstance3D.new()
	frame.mesh = tool.commit()
	frame.transform = Transform3D(Basis(), at)
	add_child(frame)

	# What a child bumps into and stands on. The posts and the platform's legs
	# are solid, the platform can be stood on, and the ladder is a slope to walk
	# up. The slide's ramp is deliberately not solid: the ride carries the child
	# along it, and a collider there would fight the carrying.
	var solid := StaticBody3D.new()
	solid.transform = Transform3D(Basis(), at)
	for frame_x in SWING_FRAMES:
		for side in PackedFloat32Array([-1.0, 1.0]):
			for lean in PackedFloat32Array([-1.0, 1.0]):
				var post_shape := CylinderShape3D.new()
				post_shape.radius = 0.11
				post_shape.height = SWING_POST
				_collide(solid, post_shape, Transform3D(
					Basis(Vector3.RIGHT, deg_to_rad(lean * 13.0)),
					Vector3(frame_x + side * SWING_WIDTH * 0.5, SWING_POST * 0.485, lean * 0.44)
				))
	var deck := BoxShape3D.new()
	deck.size = Vector3(1.3, 0.12, 1.3)
	_collide(solid, deck, Transform3D(Basis(), platform_at))
	for dx in PackedFloat32Array([-0.55, 0.55]):
		for dz in PackedFloat32Array([-0.55, 0.55]):
			var leg_shape := CylinderShape3D.new()
			leg_shape.radius = 0.08
			leg_shape.height = top.y
			_collide(solid, leg_shape, Transform3D(
				Basis(), Vector3(platform_at.x + dx, top.y * 0.5, platform_at.z + dz)
			))
	var climb_shape := BoxShape3D.new()
	climb_shape.size = Vector3(1.0, 0.16, climb.length() + 0.3)
	_collide(solid, climb_shape, Transform3D(climb_basis, climb_foot + climb * 0.5))

	# Two benches facing the swings, for whoever is watching. A playground is
	# also where the grown-ups sit.
	for bench_x in BENCHES:
		_build_bench(at, Vector3(bench_x, 0.0, BENCH_Z), solid)
	_benches = BENCHES.size()

	add_child(solid)
	_solid = solid

	# Each seat is its own node so it can swing. Pivoted at the crossbar, so
	# rotating it arcs the seat rather than spinning it in place.
	_seats.clear()
	for frame_x in SWING_FRAMES:
		for seat_x in SWING_SEATS:
			var pivot_at := at + Vector3(frame_x + seat_x, SWING_BAR, 0.0)
			var pivot := Node3D.new()
			pivot.transform = Transform3D(Basis(), pivot_at)
			add_child(pivot)

			var seat_tool := SurfaceTool.new()
			seat_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			var chain := Color(0.46, 0.48, 0.52)
			for side in PackedFloat32Array([-0.34, 0.34]):
				# A chain: a thin dark line broken into links, hung from a ring
				# on the bar, so it reads as chain rather than as a rod.
				var links := 9
				for link in links:
					var piece := CylinderMesh.new()
					piece.top_radius = 0.018
					piece.bottom_radius = 0.018
					piece.height = SWING_ROPE / float(links) * 0.78
					piece.radial_segments = 5
					piece.rings = 1
					var y := -SWING_ROPE * (float(link) + 0.5) / float(links)
					_add(seat_tool, piece, Transform3D(Basis(), Vector3(side, y, 0.0)), chain)
				var ring := TorusMesh.new()
				ring.inner_radius = 0.03
				ring.outer_radius = 0.06
				ring.rings = 6
				ring.ring_segments = 8
				# A torus lies in XZ; turned about X to hang in the swing's plane.
				_add(seat_tool, ring, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(side, -0.03, 0.0)), metal)
			# A belt seat: two slabs meeting at a shallow angle, so it sags in the
			# middle the way rubber does under a child, in one of two colours so
			# two children on one frame each know which is theirs.
			var rubber := (
				Color(0.20, 0.22, 0.26) if int(seat_x * 10.0) < 0 else Color(0.62, 0.22, 0.20)
			)
			for half in PackedFloat32Array([-1.0, 1.0]):
				var slab := BoxMesh.new()
				slab.size = Vector3(0.44, 0.06, 0.30)
				_add(seat_tool, slab, Transform3D(
					Basis(Vector3.FORWARD, half * deg_to_rad(9.0)),
					Vector3(half * 0.21, -SWING_ROPE + 0.02, 0.0)
				), rubber)
			seat_tool.generate_normals()
			seat_tool.set_material(_material())

			var seat_node := MeshInstance3D.new()
			seat_node.mesh = seat_tool.commit()
			pivot.add_child(seat_node)
			_seats.append({"pivot": pivot_at, "node": seat_node, "swing": 0.0})

	_plant_hedge(at)

## A ring of bushes round the playground with a gap either side to walk in
## through, and a tree at each corner. Planted here, by the place, rather than
## left to the forest: the forest is kept off the flat ground on purpose, so
## without this a playground stood on a bald patch.
func _plant_hedge(at: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741
	var hedge_radius := 14.5
	var bushes: Array[Transform3D] = []
	var count := 38
	for i in count:
		var angle := TAU * float(i) / float(count)
		# Gaps in the hedge facing towards and away from the camp's side, so
		# the path arrives at an opening rather than at a bush.
		var to_gap := minf(absf(angle_difference(angle, 0.0)), absf(angle_difference(angle, PI)))
		if to_gap < 0.30:
			continue
		var radius := hedge_radius + rng.randf_range(-0.5, 0.5)
		var spot := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var world := at + spot
		spot.y = field.height_at(world.x, world.z) - at.y - 0.1
		var scale := rng.randf_range(0.8, 1.2)
		bushes.append(Transform3D(
			Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(scale, scale * 0.85, scale)), spot
		))
	_scatter(PlantMeshes.broadleaf(1.6), bushes, at)

	var trees: Array[Transform3D] = []
	for corner in 4:
		var angle := PI * 0.25 + PI * 0.5 * float(corner)
		var spot := Vector3(cos(angle), 0.0, sin(angle)) * 17.5
		var world := at + spot
		spot.y = field.height_at(world.x, world.z) - at.y - 0.15
		trees.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), spot))
	_scatter(PlantMeshes.broadleaf(4.8), trees, at)

func _scatter(mesh: Mesh, transforms: Array[Transform3D], at: Vector3) -> void:
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = _material()
	instance.transform = Transform3D(Basis(), at)
	add_child(instance)

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
## A bench: plank seat, plank back, two end frames. Faces -Z, towards the
## swings, and is solid, so it can be walked round but not through.
func _build_bench(at: Vector3, local: Vector3, solid: StaticBody3D) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wood := Color(0.58, 0.42, 0.26)
	var iron := Color(0.30, 0.31, 0.34)
	var seat := BoxMesh.new()
	seat.size = Vector3(1.7, 0.07, 0.42)
	_add(tool, seat, Transform3D(Basis(), local + Vector3(0.0, 0.46, 0.0)), wood)
	var back := BoxMesh.new()
	back.size = Vector3(1.7, 0.36, 0.06)
	_add(tool, back, Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(-12.0)), local + Vector3(0.0, 0.74, 0.24)
	), wood)
	for side in PackedFloat32Array([-0.75, 0.75]):
		var leg := BoxMesh.new()
		leg.size = Vector3(0.06, 0.46, 0.40)
		_add(tool, leg, Transform3D(Basis(), local + Vector3(side, 0.23, 0.0)), iron)
		var upright := BoxMesh.new()
		upright.size = Vector3(0.06, 0.44, 0.06)
		_add(tool, upright, Transform3D(
			Basis(Vector3.RIGHT, deg_to_rad(-12.0)), local + Vector3(side, 0.70, 0.24)
		), iron)
	tool.generate_normals()
	tool.set_material(_material())
	var mesh := MeshInstance3D.new()
	mesh.mesh = tool.commit()
	mesh.transform = Transform3D(Basis(), at)
	add_child(mesh)

	var block := BoxShape3D.new()
	block.size = Vector3(1.7, 0.95, 0.5)
	_collide(solid, block, Transform3D(Basis(), local + Vector3(0.0, 0.475, 0.08)))

## How many benches stand at the playground, and how many solid pieces there
## are to bump into. For the checks.
func bench_count() -> int:
	return _benches

func solid_shape_count() -> int:
	return 0 if _solid == null else _solid.get_child_count()

static func _collide(body: StaticBody3D, shape: Shape3D, where: Transform3D) -> void:
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.transform = where
	body.add_child(collider)

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
