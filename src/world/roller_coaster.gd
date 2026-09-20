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
##
## Station, chain lift, and then the ride spends what the lift gave it: a first
## drop nearly to the sand, a big camelback, a second drop, a pair of small
## hills taken fast enough to lift a child off the seat, and a long swooping
## turn home into the brakes. Each crest is lower than the one before it,
## because a coaster cannot climb higher than it has fallen from and a profile
## that pretends otherwise is the one thing a ten-year-old will notice.
const PROFILE: Array = [
	[0.00, 1.30], [0.05, 1.30], [0.26, 20.0], [0.31, 19.2], [0.40, 2.6],
	[0.50, 14.4], [0.57, 3.4], [0.64, 10.2], [0.70, 3.6], [0.76, 7.6],
	[0.81, 3.2], [0.86, 5.6], [0.92, 2.0], [1.00, 1.30],
]

## Where the cars pull up, where the chain lift ends, and where the brakes
## take hold on the way back in.
const BOARDS_AT := 0.02
const LIFT_FOOT := 0.05
const LIFT_TOP := 0.26
const BRAKES_FROM := 0.94

## How long the cars stand at the platform. Long enough to walk the length of
## it and step in without hurrying a six-year-old.
const DWELL := 5.0

## The physics.
##
## A real coaster is one number — how far it has fallen since the lift — and
## everything else follows. This one integrates that properly instead of
## reading a speed off the height: gravity along the track's own slope, a
## little drag, the chain holding a steady pace up the hill, and brakes on the
## way in. What that buys over reading the speed off the profile is the feel of
## it — a car crests a hill still slowing, and picks up over the brow rather
## than at it.
##
## Gravity is scaled down. At nine metres a second squared a twenty-metre drop
## ends at eighteen metres a second, and a child cannot stand up in that.
const GRAVITY := 3.2
const DRAG := 0.035
const LIFT_SPEED := 3.4
const LIFT_PULL := 2.6
const BRAKE := 4.5
const CRAWL := 1.6
const TOP_SPEED := 13.0

## How far the piles stand either side of the track's own line.
const PILE_OFFSET := 0.78

## How high a car's floor rides above the track's own line.
const CAR_FLOOR := 0.55

const CARS := 3
const CAR_GAP := 3.4

const TIMBER := Color(0.55, 0.40, 0.26)
const TIMBER_DARK := Color(0.38, 0.28, 0.19)
const RAIL := Color(0.80, 0.34, 0.28)
const CAR_COLOURS: Array[Color] = [
	Color(0.88, 0.26, 0.24), Color(0.96, 0.78, 0.26), Color(0.28, 0.52, 0.84),
]

var _cars: Array[AnimatableBody3D] = []
var _frame: StaticBody3D
var _at_distance := 0.0
var _speed := 0.0
## How long is left of the wait at the platform.
var _waiting := 0.0

func _init(at: Vector3) -> void:
	name = "RollerCoaster"
	position = at

	# The timber is solid: a coaster you can walk through is scenery, and this
	# is the biggest thing on the fairground.
	_frame = StaticBody3D.new()
	_frame.name = "Frame"
	add_child(_frame)

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_build_track(tool)
	_build_lift(tool)
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

## How far the track is banked here, and which way.
##
## A coaster does not go round a bend flat — it lays over into it, and the
## sight of the train tipped up on the turn is half of what makes one look
## fast. The bends are the two half-circles at the ends of the stadium, so the
## bank comes on where the straight ends and eases off where the next one
## begins; which way it leans is worked out from the track itself, by asking
## which way the tangent is swinging.
const BANK := deg_to_rad(24.0)
const BANK_EASE := 5.0

func bank_at(distance: float) -> float:
	var total := circuit()
	var here := point_at(distance)
	var ahead := point_at(distance + 2.0)
	var behind := point_at(distance - 2.0)
	var into := Vector2(ahead.x - here.x, ahead.z - here.z).normalized()
	var out_of := Vector2(here.x - behind.x, here.z - behind.z).normalized()
	# How far the heading swings over four metres: nothing on a straight, and
	# a steady amount all the way round a bend.
	var swing := out_of.angle_to(into)
	var lean := clampf(swing / (4.0 / HALF_WIDTH), -1.0, 1.0)
	return -lean * BANK

## The way a car sits at a point on the track: pointed along it, pitched with
## its slope, and laid over into its bend. Asked by the rails, the sleepers and
## the cars alike, so none of them can disagree about which way is up.
func frame_at(distance: float) -> Basis:
	var here := point_at(distance)
	var ahead := point_at(distance + 1.0)
	var run := ahead - here
	var turn := Basis(Vector3.UP, atan2(-run.z, run.x))
	turn = turn * Basis(Vector3.BACK, atan2(run.y, Vector2(run.x, run.z).length()))
	return turn * Basis(Vector3.RIGHT, bank_at(distance))

## How steeply the track falls or rises here: metres of height per metre along
## the rail, which is what gravity actually pulls on.
func gradient_at(fraction: float) -> float:
	var step := 1.0 / 600.0
	return (height_at(fraction + step) - height_at(fraction - step)) / (2.0 * step * circuit())

## How fast a car would be going at a fraction of the way round if it had come
## straight from the top of the lift. Kept for the checks and for anything that
## wants the shape of the ride without running it.
func speed_at(fraction: float) -> float:
	var f := fposmod(fraction, 1.0)
	if f < LIFT_TOP:
		return LIFT_SPEED
	var fallen := height_at(LIFT_TOP) - height_at(f)
	return clampf(sqrt(maxf(0.0, 2.0 * GRAVITY * fallen)), CRAWL, TOP_SPEED)

## How fast the train is actually going, this moment.
func speed() -> float:
	return _speed

## Is it standing at the platform?
func boarding() -> bool:
	return _waiting > 0.0

func _build_track(tool: SurfaceTool) -> void:
	var total := circuit()
	var steps := 150
	var step := total / float(steps)
	for piece in steps:
		var here := point_at(step * float(piece))
		var next := point_at(step * float(piece + 1))
		var run := next - here
		var middle := (here + next) * 0.5
		var turn := frame_at(step * (float(piece) + 0.5))
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
		# The track is solid too, not only the piles under it: where it runs
		# low — through the station, and over the last hill — a child walked
		# straight through the rails.
		Park._solid(
			_frame, Vector3(length * 1.02, 0.36, 1.7), Transform3D(turn, middle)
		)

		# The trestle under it, where there is any height to hold up.
		#
		# Upright, and measured from the ground. They used to be turned with
		# the track and offset in the track's own frame, so on every slope the
		# legs leaned with the rails and their feet stopped short of the sand:
		# a coaster standing on piles that touch nothing. A post holds a track
		# up; it does not lie along it.
		# Every fifth piece rather than every fourth: at three metres apart the
		# bents closed into a thicket and the shape of the ride was lost inside
		# its own scaffolding. Eleven metres is what a wooden coaster actually
		# stands on, and it is still close enough that no span is unsupported.
		if piece % 5 != 0 or middle.y < 1.6:
			continue
		var across := Vector3(-run.z, 0.0, run.x).normalized() * PILE_OFFSET
		var foot_height := middle.y
		for side: float in [-1.0, 1.0]:
			var leg := BoxMesh.new()
			leg.size = Vector3(0.18, foot_height, 0.18)
			Park._add(
				tool, leg,
				Transform3D(
					Basis(),
					Vector3(middle.x, foot_height * 0.5, middle.z) + across * side
				),
				TIMBER_DARK
			)
			Park._solid(
				_frame, Vector3(0.45, foot_height, 0.45),
				Transform3D(
					Basis(),
					Vector3(middle.x, foot_height * 0.5, middle.z) + across * side
				)
			)
		# Rungs across the bent, and a diagonal in every bay: the lattice is
		# most of what a wooden coaster looks like from the ground.
		var bays := maxi(1, int(foot_height / 4.5))
		for rung in bays + 1:
			var at := foot_height * float(rung) / float(bays + 1)
			var rail_across := BoxMesh.new()
			rail_across.size = Vector3(0.10, 0.10, across.length() * 2.0 + 0.2)
			Park._add(
				tool, rail_across,
				Transform3D(
					Basis(Vector3.UP, atan2(across.x, across.z)),
					Vector3(middle.x, at, middle.z)
				),
				TIMBER_DARK
			)
		for bay in bays:
			var low := foot_height * float(bay) / float(bays + 1)
			var high := foot_height * float(bay + 1) / float(bays + 1)
			var rise := high - low
			var diagonal := BoxMesh.new()
			diagonal.size = Vector3(0.09, sqrt(rise * rise + across.length() * across.length() * 4.0), 0.09)
			Park._add(
				tool, diagonal,
				Transform3D(
					Basis(Vector3.UP, atan2(across.x, across.z))
					* Basis(Vector3.RIGHT, atan2(across.length() * 2.0, rise)),
					Vector3(middle.x, (low + high) * 0.5, middle.z)
				),
				TIMBER
			)

## The chain lift: the ratchet strip a car is dragged up on, laid between the
## rails from the station to the top. It is the one part of a coaster a child
## hears before they see, and the part that says which way the ride goes.
func _build_lift(tool: SurfaceTool) -> void:
	var total := circuit()
	var from := total * LIFT_FOOT
	var to := total * LIFT_TOP
	var teeth := int((to - from) / 1.1)
	for tooth in teeth:
		var along := lerpf(from, to, float(tooth) / float(teeth))
		var here := point_at(along)
		var next := point_at(along + 0.6)
		var run := next - here
		var turn := Basis(Vector3.UP, atan2(-run.z, run.x))
		turn = turn * Basis(Vector3.BACK, atan2(run.y, Vector2(run.x, run.z).length()))
		var rung := BoxMesh.new()
		rung.size = Vector3(0.14, 0.16, 0.5)
		Park._add(
			tool, rung,
			Transform3D(turn, here + turn * Vector3(0.0, 0.16, 0.0)),
			TIMBER_DARK
		)

## The station: a platform beside the track at the start, where the cars come
## slowly past and a child can step into one.
func _build_station(tool: SurfaceTool) -> void:
	var at := point_at(circuit() * BOARDS_AT)
	# Beside where the cars stand, and level with their floors: a platform a
	# metre below the car is one you cannot step across from.
	var deck := BoxMesh.new()
	deck.size = Vector3(3.2, 0.24, 16.0)
	var where := Vector3(at.x + 2.6, at.y + CAR_FLOOR - 0.12, at.z)
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
	# Not a moving platform as far as physics is concerned: the ride moves its
	# passengers itself, and letting Godot move them as well carried them half
	# again as far as the car they were standing in.
	car.sync_to_physics = false
	add_child(car)

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var colour: Color = CAR_COLOURS[index % CAR_COLOURS.size()]

	var floor_slab := BoxMesh.new()
	floor_slab.size = Vector3(2.6, 0.18, 1.8)
	Park._add(tool, floor_slab, Transform3D(Basis(), Vector3.ZERO), colour.darkened(0.4))
	_solid(car, floor_slab.size, Vector3.ZERO)
	# Walls at the ends only, and the sides open all the way down to the floor.
	# A character body climbs slopes and steps over nothing at all, so even a
	# low sill across the way in is a wall to a child trying to get aboard —
	# which is why there was no way into these at all.
	for wall: Array in [
		[Vector3(0.16, 1.05, 1.8), Vector3(1.3, 0.53, 0.0)],
		[Vector3(0.16, 1.05, 1.8), Vector3(-1.3, 0.53, 0.0)],
	]:
		var size: Vector3 = wall[0]
		var where: Vector3 = wall[1]
		var panel := BoxMesh.new()
		panel.size = size
		Park._add(tool, panel, Transform3D(Basis(), where), colour)
		_solid(car, size, where)

	# A lap bar down each side: high enough to hold on to, high enough to walk
	# under, and it says "sit down" without being a fence.
	for side: float in [-1.0, 1.0]:
		var bar := BoxMesh.new()
		bar.size = Vector3(2.6, 0.12, 0.12)
		Park._add(
			tool, bar,
			Transform3D(Basis(), Vector3(0.0, 0.94, side * 0.86)),
			colour.darkened(0.25)
		)
		for post in 2:
			var stanchion := BoxMesh.new()
			stanchion.size = Vector3(0.12, 0.94, 0.12)
			Park._add(
				tool, stanchion,
				Transform3D(Basis(), Vector3((float(post) - 0.5) * 2.2, 0.47, side * 0.86)),
				colour.darkened(0.25)
			)

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
		var turn := frame_at(along)
		# Lifted along the car's own up, so a car on a banked bend sits on its
		# track rather than hovering beside it.
		_cars[index].transform = Transform3D(
			turn, here + turn * Vector3(0.0, CAR_FLOOR, 0.0)
		)

func _physics_process(delta: float) -> void:
	var before: Array[Vector3] = []
	for car in _cars:
		before.append(car.position)

	_roll(delta)
	_place_cars()
	_moved.clear()
	for index in _cars.size():
		_moved.append(_cars[index].position - before[index])

## How far each car moved on the last frame, for whoever is riding in it.
var _moved: Array[Vector3] = []

## How far the ride moves whoever is aboard, this frame.
##
## Godot leaves a character standing in a body that is moved by hand: the car
## goes out from under them and they drop back onto its floor, over and over.
## So the ride says how far it has taken them and the game moves them by that.
func carry(at: Vector3, _delta: float) -> Vector3:
	for index in _cars.size():
		if index >= _moved.size():
			break
		var local := _cars[index].global_transform.affine_inverse() * at
		if absf(local.x) < 1.3 and absf(local.z) < 0.95 and local.y > -0.4 and local.y < 2.0:
			return _moved[index]
	return Vector3.ZERO

## Move the train along by one frame of physics.
##
## Four regimes, and the whole ride is in them: standing at the platform, being
## dragged up the chain at a steady pace, running free under gravity and drag,
## and being brought to a stand by the brakes on the way in.
func _roll(delta: float) -> void:
	var total := circuit()
	if _waiting > 0.0:
		_waiting -= delta
		_speed = 0.0
		return

	var fraction := _at_distance / total
	if fraction < LIFT_TOP:
		# Out of the station and up the chain: a steady pull, whatever the
		# hill does. This has to cover the station itself as well as the lift,
		# or the brakes that stopped the train there hold it there for ever —
		# which is exactly what they did.
		_speed = move_toward(_speed, LIFT_SPEED, LIFT_PULL * delta)
	elif fraction >= BRAKES_FROM:
		# In the brakes on the run home. Down to a crawl rather than to a
		# stand: it has to reach the platform to stop at it.
		_speed = move_toward(_speed, CRAWL, BRAKE * delta)
	else:
		# Free running: gravity along the slope, and a little drag. A crest
		# taken slowly is a car still slowing as it goes over, which is the
		# part of a coaster that makes a child hold their breath.
		var grade := gradient_at(fraction)
		_speed += (-GRAVITY * grade - DRAG * _speed) * delta
		_speed = clampf(_speed, CRAWL * 0.4, TOP_SPEED)

	var was := _at_distance
	_at_distance = fposmod(_at_distance + _speed * delta, total)

	# Pull up at the platform once a lap, on the way past it.
	var stop_at := total * BOARDS_AT
	var passed := was < stop_at and _at_distance >= stop_at
	if was > _at_distance:
		# Round the end of the lap.
		passed = passed or stop_at >= was or stop_at <= _at_distance
	if passed:
		_at_distance = stop_at
		_speed = 0.0
		_waiting = DWELL

## How high the ride goes, and where the leading car is. For the checks.
func highest() -> float:
	var top := 0.0
	for key: Array in PROFILE:
		top = maxf(top, float(key[1]))
	return top

func car_distance() -> float:
	return _at_distance
