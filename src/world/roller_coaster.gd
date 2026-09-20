class_name RollerCoaster
extends Node3D

## The big ride: a wooden coaster running the whole length of the fairground
## beside the river, twenty metres up at the top of its lift hill.
##
## The track is a stadium — two long straights with a half-circle at each end —
## and a height profile laid along it: the station, the climb, and then three
## drops that get smaller, the way a real one spends what the chain lift gave
## it. Everything else is worked out from that single line: the rails, the
## sleepers, the trestles down to the ground, and where a car is at any moment.
##
## The cars are AnimatableBody3D with a floor and high sides, so a child
## standing in one is carried by it rather than having to be told they are
## aboard. They move by arc length, and their speed comes from how far they
## have fallen — slow over the top, fast at the bottom — which is the whole
## feeling of the thing.

## The shape of the circuit. Half-length along the river, half-width across it;
## the ends are half-circles of that width.
const HALF_LENGTH := 68.0
const HALF_WIDTH := 6.5

## The height profile, as [fraction of the circuit, metres above the ground].
## The station is at the start; the chain lift takes it to the top by a third
## of the way round.
const PROFILE: Array = [
	[0.00, 1.30], [0.06, 1.30], [0.28, 20.0], [0.34, 19.4], [0.46, 3.2],
	[0.58, 12.6], [0.68, 2.8], [0.80, 7.4], [0.90, 2.2], [1.00, 1.30],
]

## Where the station is, and where the chain lift ends.
const STATION_END := 0.06
const LIFT_TOP := 0.28
## How fast the chain drags a car up, and the least speed a car ever has.
const LIFT_SPEED := 3.2
const CRAWL := 3.0
## How much of the fall becomes speed. Not gravity: a car doing twenty metres
## a second cannot be stood up in, and this is a ride for a six-year-old.
const FALL_TO_SPEED := 3.1

const CARS := 3
const CAR_GAP := 3.4

const TIMBER := Color(0.55, 0.40, 0.26)
const TIMBER_DARK := Color(0.38, 0.28, 0.19)
const RAIL := Color(0.80, 0.34, 0.28)
const CAR_COLOURS: Array[Color] = [
	Color(0.88, 0.26, 0.24), Color(0.96, 0.78, 0.26), Color(0.28, 0.52, 0.84),
]

var _cars: Array[AnimatableBody3D] = []
var _at_distance := 0.0

func _init(at: Vector3) -> void:
	name = "RollerCoaster"
	position = at

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_build_track(tool)
	_build_station(tool)

	tool.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.86
	tool.set_material(material)
	var drawn := MeshInstance3D.new()
	drawn.name = "Track"
	drawn.mesh = tool.commit()
	add_child(drawn)

	for car in CARS:
		_cars.append(_build_car(car))
	_place_cars()

## How long the circuit is, all the way round.
func circuit() -> float:
	return 4.0 * (HALF_LENGTH - HALF_WIDTH) + TAU * HALF_WIDTH

## Where the track is at a distance along it, and which way it is heading.
## The stadium is walked straight-round-straight-round, so that a car's speed
## can be worked out from distance rather than from an angle that means
## something different on every part of the shape.
func point_at(distance: float) -> Vector3:
	var straight := 2.0 * (HALF_LENGTH - HALF_WIDTH)
	var bend := PI * HALF_WIDTH
	var total := circuit()
	var along := fposmod(distance, total)
	var flat := Vector2.ZERO
	if along < straight:
		# Up the eastern side, heading north.
		flat = Vector2(HALF_WIDTH, (HALF_LENGTH - HALF_WIDTH) - along)
	elif along < straight + bend:
		var turn := (along - straight) / HALF_WIDTH
		flat = Vector2(
			cos(turn) * HALF_WIDTH,
			-(HALF_LENGTH - HALF_WIDTH) - sin(turn) * HALF_WIDTH
		)
	elif along < 2.0 * straight + bend:
		var back := along - straight - bend
		flat = Vector2(-HALF_WIDTH, -(HALF_LENGTH - HALF_WIDTH) + back)
	else:
		var turn := (along - 2.0 * straight - bend) / HALF_WIDTH
		flat = Vector2(
			-cos(turn) * HALF_WIDTH,
			(HALF_LENGTH - HALF_WIDTH) + sin(turn) * HALF_WIDTH
		)
	return Vector3(flat.x, height_at(along / total), flat.y)

## How high the track is at a fraction of the way round, read off the profile.
func height_at(fraction: float) -> float:
	var f := fposmod(fraction, 1.0)
	for key in PROFILE.size() - 1:
		var from: Array = PROFILE[key]
		var to: Array = PROFILE[key + 1]
		if f >= float(from[0]) and f <= float(to[0]):
			var along := (f - float(from[0])) / maxf(float(to[0]) - float(from[0]), 0.0001)
			# Smoothed, so the crest of a hill is a crest and not a corner.
			return lerpf(float(from[1]), float(to[1]), smoothstep(0.0, 1.0, along))
	return float(PROFILE[0][1])

## How fast a car is going at a fraction of the way round: the chain lift's own
## pace while it is on the chain, and what it has fallen since the top
## everywhere else.
func speed_at(fraction: float) -> float:
	var f := fposmod(fraction, 1.0)
	if f < LIFT_TOP:
		return LIFT_SPEED
	var fallen := height_at(LIFT_TOP) - height_at(f)
	return maxf(CRAWL, sqrt(maxf(0.0, 2.0 * FALL_TO_SPEED * fallen)))

func _build_track(tool: SurfaceTool) -> void:
	var total := circuit()
	var steps := 150
	var step := total / float(steps)
	for piece in steps:
		var here := point_at(step * float(piece))
		var next := point_at(step * float(piece + 1))
		var run := next - here
		var middle := (here + next) * 0.5
		var turn := Basis(Vector3.UP, atan2(-run.z, run.x))
		turn = turn * Basis(Vector3.BACK, atan2(run.y, Vector2(run.x, run.z).length()))
		var length := run.length()

		# Two rails, and a sleeper under them.
		for side: float in [-1.0, 1.0]:
			var rail := BoxMesh.new()
			rail.size = Vector3(length * 1.05, 0.14, 0.12)
			Park._add(
				tool, rail,
				Transform3D(turn, middle + turn * Vector3(0.0, 0.10, side * 0.62)),
				RAIL
			)
		var sleeper := BoxMesh.new()
		sleeper.size = Vector3(length * 0.5, 0.10, 1.7)
		Park._add(tool, sleeper, Transform3D(turn, middle), TIMBER)

		# The trestle under it, where there is any height to hold up. Timber
		# cross-braced, which is what makes a wooden coaster look like one.
		if piece % 4 != 0 or middle.y < 1.6:
			continue
		for side: float in [-1.0, 1.0]:
			var leg := BoxMesh.new()
			leg.size = Vector3(0.20, middle.y, 0.20)
			Park._add(
				tool, leg,
				Transform3D(turn, middle + turn * Vector3(0.0, -middle.y * 0.5, side * 0.72)),
				TIMBER_DARK
			)
		var brace := BoxMesh.new()
		brace.size = Vector3(0.12, 0.12, 1.5)
		for rung in maxi(1, int(middle.y / 3.0)):
			Park._add(
				tool, brace,
				Transform3D(turn, middle + turn * Vector3(0.0, -float(rung) * 3.0, 0.0)),
				TIMBER_DARK
			)

## The station: a platform beside the track at the start, where the cars come
## slowly past and a child can step into one.
func _build_station(tool: SurfaceTool) -> void:
	var at := point_at(circuit() * STATION_END * 0.5)
	var deck := BoxMesh.new()
	deck.size = Vector3(3.0, 0.24, 14.0)
	var where := Vector3(at.x + 3.0, at.y - 0.55, at.z)
	Park._add(tool, deck, Transform3D(Basis(), where), TIMBER)

	var body := StaticBody3D.new()
	body.name = "Platform"
	Park._solid(body, deck.size, Transform3D(Basis(), where))
	add_child(body)

	for post in 5:
		var leg := BoxMesh.new()
		leg.size = Vector3(0.22, where.y, 0.22)
		var spot := Vector3(
			where.x + 1.2, where.y * 0.5, where.z - 6.0 + 3.0 * float(post)
		)
		Park._add(tool, leg, Transform3D(Basis(), spot), TIMBER_DARK)

	# A roof over it, because a station is a shelter and because it is what
	# tells a child from across the fairground that this is where you get on.
	var roof := BoxMesh.new()
	roof.size = Vector3(4.2, 0.18, 15.0)
	Park._add(
		tool, roof, Transform3D(Basis(), where + Vector3(0.3, 3.2, 0.0)), RAIL
	)
	for post in 4:
		var mast := BoxMesh.new()
		mast.size = Vector3(0.18, 3.2, 0.18)
		Park._add(
			tool, mast,
			Transform3D(Basis(), where + Vector3(1.3, 1.6, -6.0 + 4.0 * float(post))),
			TIMBER_DARK
		)

func _build_car(index: int) -> AnimatableBody3D:
	var car := AnimatableBody3D.new()
	car.name = "Car%d" % index
	car.sync_to_physics = true
	add_child(car)

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var colour: Color = CAR_COLOURS[index % CAR_COLOURS.size()]

	var floor_slab := BoxMesh.new()
	floor_slab.size = Vector3(2.6, 0.18, 1.8)
	Park._add(tool, floor_slab, Transform3D(Basis(), Vector3.ZERO), colour.darkened(0.4))
	_solid(car, floor_slab.size, Vector3.ZERO)
	for wall: Array in [
		[Vector3(2.6, 1.05, 0.16), Vector3(0.0, 0.53, 0.9)],
		[Vector3(2.6, 1.05, 0.16), Vector3(0.0, 0.53, -0.9)],
		[Vector3(0.16, 1.05, 1.8), Vector3(1.3, 0.53, 0.0)],
		[Vector3(0.16, 1.05, 1.8), Vector3(-1.3, 0.53, 0.0)],
	]:
		var size: Vector3 = wall[0]
		var where: Vector3 = wall[1]
		var panel := BoxMesh.new()
		panel.size = size
		Park._add(tool, panel, Transform3D(Basis(), where), colour)
		_solid(car, size, where)

	tool.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.62
	tool.set_material(material)
	var drawn := MeshInstance3D.new()
	drawn.mesh = tool.commit()
	car.add_child(drawn)
	return car

func _solid(car: AnimatableBody3D, size: Vector3, where: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = where
	car.add_child(collider)

func _place_cars() -> void:
	for index in _cars.size():
		var along := _at_distance - float(index) * CAR_GAP
		var here := point_at(along)
		var ahead := point_at(along + 1.0)
		var run := ahead - here
		var turn := Basis(Vector3.UP, atan2(-run.z, run.x))
		turn = turn * Basis(Vector3.BACK, atan2(run.y, Vector2(run.x, run.z).length()))
		_cars[index].transform = Transform3D(turn, here + Vector3(0.0, 0.55, 0.0))

func _physics_process(delta: float) -> void:
	_at_distance = fposmod(
		_at_distance + speed_at(_at_distance / circuit()) * delta, circuit()
	)
	_place_cars()

## How high the ride goes, and where the leading car is. For the checks.
func highest() -> float:
	var top := 0.0
	for key: Array in PROFILE:
		top = maxf(top, float(key[1]))
	return top

func car_distance() -> float:
	return _at_distance
