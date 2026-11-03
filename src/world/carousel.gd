class_name Carousel
extends Node3D

## The roundabout: a turning floor with horses on poles, under a striped
## canopy.
##
## The floor is an AnimatableBody3D, which is the whole trick — Godot carries a
## character body standing on one of those, so a child who steps on goes round
## with it and steps off wherever they like. Nothing has to know they are
## aboard.

const RADIUS := 6.0
const FLOOR_HEIGHT := 0.55
## How thick the drawn deck is, and its collider with it: a child's feet stand
## on exactly what is drawn rather than a centimetre above it.
const DECK_THICKNESS := 0.22
const CANOPY_HEIGHT := 4.6
## A turn every fifty seconds or so: slow enough to step onto, fast enough that
## a six-year-old can see it is going round.
const TURN_RATE := deg_to_rad(7.2)
const HORSES := 8

const FLOOR_COLOUR := Color(0.72, 0.30, 0.26)
const TRIM := Color(0.96, 0.86, 0.42)
const POLE := Color(0.86, 0.80, 0.52)
const CANOPY_A := Color(0.84, 0.26, 0.24)
const CANOPY_B := Color(0.96, 0.92, 0.84)

var _turntable: Node3D
var _horses: AnimatableBody3D
var _turned := 0.0
## Where a child sits on each horse, in the turning horses' own frame: the
## origin is the top of the saddle's centre, and the basis turns a child (who
## faces -z) to face along the horse.
var _saddles: Array[Transform3D] = []

func _init(at: Vector3) -> void:
	name = "Carousel"
	position = at

	var still := SurfaceTool.new()
	still.begin(Mesh.PRIMITIVE_TRIANGLES)
	var turning := SurfaceTool.new()
	turning.begin(Mesh.PRIMITIVE_TRIANGLES)

	# What turns is what is drawn. What a child stands on is a plain static
	# disc that never moves — and cannot be told apart from a turning one,
	# because a disc turned about its own middle is the same disc.
	#
	# This matters: an AnimatableBody3D floor is a moving platform, and Godot
	# gives a character standing on one some of the platform's motion. With the
	# ride also moving its passengers by hand, a child went round half again as
	# fast as the floor they were standing on.
	_turntable = Node3D.new()
	_turntable.name = "Turntable"
	add_child(_turntable)

	var footing := StaticBody3D.new()
	footing.name = "Floor"
	add_child(footing)

	# The horses are solid, and they go round: a child walked straight through
	# them, which is the one thing on a roundabout you are supposed to be able
	# to lean on. Not a moving platform as far as physics is concerned — the
	# ride moves its passengers itself, and letting the engine do it as well
	# carried them half again as far as the floor.
	_horses = AnimatableBody3D.new()
	_horses.name = "Horses"
	_horses.sync_to_physics = false
	add_child(_horses)

	# The floor, and the step up onto it.
	var deck := CylinderMesh.new()
	deck.top_radius = RADIUS
	deck.bottom_radius = RADIUS
	deck.height = DECK_THICKNESS
	deck.radial_segments = 28
	deck.rings = 1
	Park._add(turning, deck, Transform3D(Basis(), Vector3(0.0, FLOOR_HEIGHT, 0.0)), FLOOR_COLOUR)
	var skirt := CylinderMesh.new()
	skirt.top_radius = RADIUS
	skirt.bottom_radius = RADIUS * 0.94
	skirt.height = FLOOR_HEIGHT
	skirt.radial_segments = 28
	skirt.rings = 1
	Park._add(turning, skirt, Transform3D(Basis(), Vector3(0.0, FLOOR_HEIGHT * 0.5, 0.0)), TRIM)

	var pad := CylinderShape3D.new()
	pad.radius = RADIUS
	pad.height = DECK_THICKNESS
	var collider := CollisionShape3D.new()
	collider.shape = pad
	collider.position = Vector3(0.0, FLOOR_HEIGHT, 0.0)
	footing.add_child(collider)

	# The middle column, and the canopy over it: stripes, because a roundabout
	# without stripes is a platform.
	# The column is solid — it stands on the axis, so a still collider and a
	# turning one are the same thing. The horses are not: they are what a
	# child walks up to and climbs onto.
	var core := CylinderShape3D.new()
	core.radius = 0.42
	core.height = CANOPY_HEIGHT
	var core_shape := CollisionShape3D.new()
	core_shape.shape = core
	core_shape.position = Vector3(0.0, FLOOR_HEIGHT + CANOPY_HEIGHT * 0.5, 0.0)
	footing.add_child(core_shape)

	var column := CylinderMesh.new()
	column.top_radius = 0.34
	column.bottom_radius = 0.40
	column.height = CANOPY_HEIGHT
	column.radial_segments = 12
	column.rings = 1
	Park._add(
		turning, column,
		Transform3D(Basis(), Vector3(0.0, FLOOR_HEIGHT + CANOPY_HEIGHT * 0.5, 0.0)), POLE
	)

	# The stripes are twelve slices of one cone, each its own colour. They were
	# once whole cones turned about their own axis, which is the same cone in
	# the same place several times over: the colours fought over every pixel
	# and the canopy had no stripes.
	var roof_centre := Vector3(0.0, FLOOR_HEIGHT + CANOPY_HEIGHT + 0.55, 0.0)
	var roof_apex := roof_centre + Vector3(0.0, 0.75, 0.0)
	var roof_base := roof_centre + Vector3(0.0, -0.75, 0.0)
	var rim := RADIUS + 0.4
	for wedge in 12:
		var from_angle := TAU * float(wedge) / 12.0
		var to_angle := TAU * float(wedge + 1) / 12.0
		var near := roof_base + Vector3(cos(from_angle), 0.0, sin(from_angle)) * rim
		var far := roof_base + Vector3(cos(to_angle), 0.0, sin(to_angle)) * rim
		var stripe := CANOPY_A if wedge % 2 == 0 else CANOPY_B
		# The top, then the underside, which a child standing beneath sees.
		for corner: Vector3 in [roof_apex, near, far, roof_base, far, near]:
			turning.set_color(stripe)
			turning.add_vertex(corner)

	# A string of bulbs round the eave — the one thing that says "carousel"
	# from across the fairground before anyone is close enough to see the
	# horses at all.
	for bulb in 16:
		var bulb_angle := TAU * float(bulb) / 16.0
		var bulb_mesh := SphereMesh.new()
		bulb_mesh.radius = 0.09
		bulb_mesh.height = 0.18
		bulb_mesh.radial_segments = 8
		bulb_mesh.rings = 5
		Park._add(
			turning, bulb_mesh,
			Transform3D(
				Basis(),
				Vector3(cos(bulb_angle), 0.0, sin(bulb_angle)) * rim
					+ Vector3(0.0, roof_base.y - 0.04, 0.0)
			),
			Color(1.0, 0.92, 0.55) if bulb % 2 == 0 else Color(0.98, 0.70, 0.30)
		)

	# The horses: a body on a brass pole, facing the way round.
	for horse in HORSES:
		var angle := TAU * float(horse) / float(HORSES)
		var spot := Vector3(cos(angle), 0.0, sin(angle)) * (RADIUS * 0.66)
		var pole := CylinderMesh.new()
		pole.top_radius = 0.06
		pole.bottom_radius = 0.06
		# Up into the underside of the canopy, which slopes: the cone is
		# 1.5 m deep over its whole radius, so at the poles' ring it is
		# roof_base + 1.5 * (1 - r / rim). The poles used to stop at a fixed
		# 0.92 of the column and hung three-quarters of a metre short of it.
		var roof_under := roof_base.y + 1.5 * (1.0 - spot.length() / rim)
		var pole_top := roof_under + 0.05
		pole.height = pole_top - FLOOR_HEIGHT
		pole.radial_segments = 8
		pole.rings = 1
		Park._add(
			turning, pole,
			Transform3D(Basis(), spot + Vector3(0.0, FLOOR_HEIGHT + pole.height * 0.5, 0.0)),
			POLE
		)
		# Facing the way it is going, not out at the trees.
		#
		# A carousel horse stands along the circle, nose to tail with the one
		# in front: that is the whole picture of a roundabout. These were
		# turned to face straight out from the middle, which is a row of
		# horses looking over a fence. The floor turns the way a point's angle
		# *decreases*, so the tangent a horse faces is (sin a, 0, -cos a),
		# which is this.
		var facing := Basis(Vector3.UP, PI * 0.5 - angle)
		var body := BoxMesh.new()
		body.size = Vector3(1.5, 0.62, 0.42)
		var ride_at := spot + Vector3(0.0, FLOOR_HEIGHT + 1.15, 0.0)
		Park._add(turning, body, Transform3D(facing, ride_at), MountKinds.HORSE_COATS[horse % MountKinds.HORSE_COATS.size()])
		var neck := BoxMesh.new()
		neck.size = Vector3(0.36, 0.62, 0.34)
		Park._add(
			turning, neck,
			Transform3D(facing, ride_at + facing * Vector3(0.62, 0.42, 0.0)),
			MountKinds.HORSE_COATS[horse % MountKinds.HORSE_COATS.size()]
		)

		# The saddle: a proper seat on the horse's own back, the thing missing
		# before that made climbing onto one read as standing near a horse
		# rather than riding it. Leather-coloured, like every other saddle in
		# the game, and a child's own foot has somewhere to look for.
		var saddle_top := ride_at.y + 0.35
		# A child's -z is the horse's +x (its head), so the seat is the
		# horse's own turn and a quarter more.
		_saddles.append(Transform3D(
			facing * Basis(Vector3.UP, -PI * 0.5),
			Vector3(ride_at.x, saddle_top, ride_at.z)
		))
		var saddle := BoxMesh.new()
		saddle.size = Vector3(0.5, 0.1, 0.4)
		var saddle_at := Vector3(ride_at.x, saddle_top - 0.05, ride_at.z)
		Park._add(turning, saddle, Transform3D(facing, saddle_at), ShopStock.colour(ShopStock.SADDLE))
		var cantle := BoxMesh.new()
		cantle.size = Vector3(0.08, 0.18, 0.4)
		Park._add(
			turning, cantle,
			Transform3D(facing, saddle_at + facing * Vector3(-0.2, 0.08, 0.0)),
			ShopStock.colour(ShopStock.SADDLE).darkened(0.2)
		)

		# What a child bumps into, and stands on: the barrel of the horse,
		# turned with it, and topped exactly where the saddle sits rather than
		# a fraction above or below it — a horse a child climbs onto and finds
		# themselves floating over the saddle, or sunk into it, is not one
		# that reads as ridden.
		var barrel_bottom := ride_at.y - 0.775
		var barrel_height := saddle_top - barrel_bottom
		var solid := BoxShape3D.new()
		solid.size = Vector3(1.6, barrel_height, 0.5)
		var barrel := CollisionShape3D.new()
		barrel.shape = solid
		barrel.transform = Transform3D(
			facing, Vector3(ride_at.x, barrel_bottom + barrel_height * 0.5, ride_at.z)
		)
		_horses.add_child(barrel)

		# Legs, a mane and a tail: a horse that is one slab on a stick reads as
		# a bench. They are drawn inside the barrel's own box (1.6 by 0.5, down
		# to 0.775 under ride_at), so the collider still describes the horse.
		var coat: Color = MountKinds.HORSE_COATS[horse % MountKinds.HORSE_COATS.size()]
		for along: float in [-0.55, 0.55]:
			for side: float in [-0.12, 0.12]:
				var leg := BoxMesh.new()
				leg.size = Vector3(0.14, 0.46, 0.14)
				Park._add(
					turning, leg,
					Transform3D(facing, ride_at + facing * Vector3(along, -0.31 - 0.23 + 0.02, side)),
					coat.darkened(0.15)
				)
		var mane := BoxMesh.new()
		mane.size = Vector3(0.1, 0.62, 0.1)
		Park._add(
			turning, mane,
			Transform3D(facing, ride_at + facing * Vector3(0.38, 0.52, 0.0)),
			coat.darkened(0.45)
		)
		var tail := BoxMesh.new()
		tail.size = Vector3(0.1, 0.5, 0.12)
		Park._add(
			turning, tail,
			Transform3D(facing, ride_at + facing * Vector3(-0.78, -0.05, 0.0)),
			coat.darkened(0.45)
		)

		var head := BoxMesh.new()
		head.size = Vector3(0.52, 0.30, 0.30)
		Park._add(
			turning, head,
			Transform3D(facing, ride_at + facing * Vector3(0.86, 0.66, 0.0)),
			MountKinds.HORSE_COATS[horse % MountKinds.HORSE_COATS.size()]
		)

	# Drawn once, on the turntable. It was committed to the horses' body as
	# well, so every vertex of the ride went to the card twice, one copy on
	# top of the other, turning in step.
	Park.commit(turning, _turntable, "Turning")
	Park.commit(still, self, "Still")

	# Its music: a small tune, from the middle of the ride and only heard near
	# it. A carousel that turns in silence is a ceiling fan. The tune is baked
	# on a worker thread, as the animals' voices are, and starts when it is
	# ready — a couple of hundred thousand samples is not for the first frame.
	_music = AudioStreamPlayer3D.new()
	_music.name = "Music"
	_music.bus = Mix.WORLD
	_music.max_distance = MUSIC_REACH
	_music.unit_size = 5.0
	_music.volume_db = MUSIC_DB
	_music.position = Vector3(0.0, CANOPY_HEIGHT * 0.5, 0.0)
	add_child(_music)
	_music_task = WorkerThreadPool.add_task(_bake_music, false, "carousel music")

## How far the carousel's tune carries, and how loud it is at the ride.
const MUSIC_REACH := 45.0
const MUSIC_DB := -16.0

var _music: AudioStreamPlayer3D
var _music_task := -1
var _music_stream: AudioStreamWAV

func _bake_music() -> void:
	_music_stream = Sounds.music_box()

## Never freed while the bake is still running: it writes into this object.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _music_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1

## Is the tune playing? For the checks.
func music_playing() -> bool:
	return _music != null and _music.playing

func _physics_process(delta: float) -> void:
	if _music_task >= 0 and WorkerThreadPool.is_task_completed(_music_task):
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1
		_music.stream = _music_stream
		_music.play()
	_turned = fmod(_turned + TURN_RATE * delta, TAU)
	var spin := Transform3D(Basis(Vector3.UP, _turned), Vector3.ZERO)
	_turntable.transform = spin
	_horses.transform = spin

## How far the floor moves whoever is standing on it, this frame.
##
## Godot will not do this for us. A character body standing on a body that is
## being *rotated* is not taken round with it — the engine carries a passenger
## along a platform that slides, and leaves them where they are on one that
## turns. So the ride says how far it has swept its floor and the game moves
## the child by that much, which is the same answer and one we can test.
func carry(at: Vector3, delta: float) -> Vector3:
	var out := Vector2(at.x - global_position.x, at.z - global_position.z)
	if out.length() > RADIUS:
		return Vector3.ZERO
	var floor_at := global_position.y + FLOOR_HEIGHT
	if at.y < floor_at - 0.2 or at.y > floor_at + 2.4:
		return Vector3.ZERO
	var swept := out.rotated(-TURN_RATE * delta) - out
	return Vector3(swept.x, 0.0, swept.y)

## Every saddle, in the world as the ride stands now: the origin the top of its
## centre, the basis the way a child on it faces. For the checks and the viewer.
func saddles() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for saddle in _saddles:
		out.append(_horses.global_transform * saddle)
	return out

## The saddle a child is standing on the back of, or a transform of NANs if
## they are not on a horse. The barrel they climb onto is 1.6 long and 0.5
## wide and topped at the saddle, so anywhere on it is the saddle, to sit in
## the middle of: the floor of the ride is not a seat, and nor is the air.
func seat_near(at: Vector3) -> Transform3D:
	for saddle in _saddles:
		var here := _horses.global_transform * saddle
		var local := here.affine_inverse() * at
		if absf(local.z) < 0.85 and absf(local.x) < 0.35 and local.y > -0.25 and local.y < 0.4:
			return here
	return Transform3D(Basis(), Vector3(NAN, NAN, NAN))

## How far round it has turned. For the checks.
func turned() -> float:
	return _turned
