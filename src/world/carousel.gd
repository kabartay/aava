class_name Carousel
extends Node3D

## The roundabout: a turning floor with horses on poles, under a striped
## canopy, round a mirrored drum.
##
## It is a ride like the tower and the ship: it stands still until somebody
## has paid, seats that child on the nearest horse (or pig, or chariot), spins
## up, turns for about a minute, slows, stops and lets them off. The game says
## when and who (see `board`, `rider_seat` and `step_off`); the ride knows
## where its own saddles are, which is the one thing nobody else can.
##
## What a child stands on is a still disc and what turns is what is drawn, as
## `_init` explains. The rider is not carried by physics at all: the game puts
## them on their saddle every frame, which is also how the coaster holds its
## riders.

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

## What a ride is: a spin up, fifty seconds at speed, a slowing down — about a
## minute from being seated to being let off.
const SPIN_UP_TIME := 4.0
const RIDE_TIME := 50.0
const SLOW_TIME := 6.0
## How far an animal rises and falls on its pole, and how quickly (radians a
## second of the ride's own clock), alternating from one to the next.
const BOB := 0.2
const BOB_RATE := 1.9
## Where the animals stand: the share of the radius they ride at, how high the
## middle of one is over the floor's origin, and how far above that its saddle
## is. Written once so that the drawing, the collider and the seat agree.
const RING := 0.66
const RIDE_ABOVE_FLOOR := 1.15
const SADDLE_ABOVE_RIDE := 0.35
const SADDLE_TOP := FLOOR_HEIGHT + RIDE_ABOVE_FLOOR + SADDLE_ABOVE_RIDE
## What each of the eight is. A roundabout of one animal is a rank of horses; a
## pig and a chariot give a child something to choose.
const KINDS: Array[StringName] = [
	&"horse", &"pig", &"horse", &"chariot", &"horse", &"pig", &"horse", &"chariot",
]
## The painted drum in the middle, solid and collided as drawn.
const DRUM_RADIUS := 1.12
const DRUM_HEIGHT := 2.4
## The ramps up onto the deck. A deck two thirds of a metre up with nothing to
## climb it by is a wall to a child on a thumb-stick, who cannot step up: four
## slopes, between the animals, that a body simply walks up.
const RAMP_RUN := 2.4
const RAMP_WIDTH := 2.2
const RAMP_THICKNESS := 0.12

enum Phase { STILL, SPIN_UP, RIDING, SLOWING }

const DRUM_PAINT := Color(0.30, 0.52, 0.78)
const MIRROR := Color(0.74, 0.86, 0.94)
const PIG_PINK := Color(0.95, 0.68, 0.70)
const RAMP_COLOUR := Color(0.62, 0.46, 0.32)
const GOLD := Color(0.96, 0.78, 0.22)
const FLOOR_COLOUR := Color(0.72, 0.30, 0.26)
const TRIM := Color(0.96, 0.86, 0.42)
const POLE := Color(0.86, 0.80, 0.52)
const CANOPY_A := Color(0.84, 0.26, 0.24)
const CANOPY_B := Color(0.96, 0.92, 0.84)

var _turntable: Node3D
var _horses: AnimatableBody3D
var _turned := 0.0
## Where a child sits on each animal, in the turning frame: the origin is the
## top of the saddle's centre at rest, and the basis turns a child (who faces
## -z) to face along the animal.
var _saddles: Array[Transform3D] = []
## The animals, which rise and fall on their poles, and the solid barrel under
## each with where it stands at rest: moved together, so that what is drawn is
## what is collided.
var _figures: Array[MeshInstance3D] = []
var _barrels: Array[CollisionShape3D] = []
var _barrel_rest: Array[Transform3D] = []
var _phase := Phase.STILL
var _phase_time := 0.0
## How fast it is going (nought to one), and how far it swept its floor in the
## last tick.
var _speed := 0.0
var _swept := 0.0
var _bob_clock := 0.0
## Which saddle the child is in, or -1.
var _rider := -1
var _glow_material: StandardMaterial3D
var _glow_light: OmniLight3D

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

	_build_ramps(still, footing)
	_build_sign(still, footing)

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
	_build_drum(turning, footing)

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
	# horses at all. Drawn twice over: once as paint, and once, a hair bigger
	# and in a mesh of its own, as the glow that comes up at dusk (see `glow`).
	var glowing := SurfaceTool.new()
	glowing.begin(Mesh.PRIMITIVE_TRIANGLES)
	for bulb in 16:
		var bulb_angle := TAU * float(bulb) / 16.0
		var bulb_mesh := SphereMesh.new()
		bulb_mesh.radius = 0.09
		bulb_mesh.height = 0.18
		bulb_mesh.radial_segments = 8
		bulb_mesh.rings = 5
		var bulb_at := Transform3D(
			Basis(),
			Vector3(cos(bulb_angle), 0.0, sin(bulb_angle)) * rim
				+ Vector3(0.0, roof_base.y - 0.04, 0.0)
		)
		var bulb_colour := Color(1.0, 0.92, 0.55) if bulb % 2 == 0 else Color(0.98, 0.70, 0.30)
		Park._add(turning, bulb_mesh, bulb_at, bulb_colour)
		var lit_mesh := SphereMesh.new()
		lit_mesh.radius = 0.115
		lit_mesh.height = 0.23
		lit_mesh.radial_segments = 8
		lit_mesh.rings = 5
		Park._add(glowing, lit_mesh, bulb_at, bulb_colour)

	# The animals: a body on a brass pole, facing the way round.
	for horse in HORSES:
		_build_animal(horse, turning, roof_base, rim)

	# Drawn once, on the turntable. It was committed to the horses' body as
	# well, so every vertex of the ride went to the card twice, one copy on
	# top of the other, turning in step.
	Park.commit(turning, _turntable, "Turning")
	Park.commit(still, self, "Still")
	_commit_glow(glowing, roof_base)

	# Its music: a small tune, from the middle of the ride and only heard near
	# it. A carousel that turns in silence is a ceiling fan. The tune is baked
	# on a worker thread, as the animals' voices are, and starts when it is
	# ready — a couple of hundred thousand samples is not for the first frame.
	_music = AudioStreamPlayer3D.new()
	_music.name = "Music"
	_music.bus = Mix.WORLD
	_music.max_distance = MUSIC_REACH
	_music.unit_size = 4.0
	_music.volume_db = MUSIC_STILL_DB
	_music.position = Vector3(0.0, CANOPY_HEIGHT * 0.5, 0.0)
	add_child(_music)
	_music_task = WorkerThreadPool.add_task(_bake_music, false, "carousel music")

## The four ramps, each a slab from the deck's edge down to the sand, drawn and
## collided as the same box. They stand between the animals' own angles, and
## are still: a slope a child walks up must not turn under their feet.
func _build_ramps(still: SurfaceTool, footing: StaticBody3D) -> void:
	var top := FLOOR_HEIGHT + DECK_THICKNESS * 0.5
	var slope := atan2(top, RAMP_RUN)
	for ramp in 4:
		# An eighth of a turn off the animals' own angles (they stand at every
		# eighth), so each ramp comes up into the gap between two barrels and
		# not into the side of one.
		var angle := TAU * float(ramp) / 4.0 + TAU / 16.0
		var out := Vector3(cos(angle), 0.0, sin(angle))
		# Down the slope, and up out of it; the width runs across.
		var down := out * cos(slope) - Vector3.UP * sin(slope)
		var normal := out * sin(slope) + Vector3.UP * cos(slope)
		var basis := Basis(down, normal, down.cross(normal))
		var middle := out * (RADIUS + RAMP_RUN * 0.5) + Vector3(0.0, top * 0.5, 0.0) \
			- normal * RAMP_THICKNESS * 0.5
		var size := Vector3(
			sqrt(RAMP_RUN * RAMP_RUN + top * top), RAMP_THICKNESS, RAMP_WIDTH
		)
		var slab := BoxMesh.new()
		slab.size = size
		Park._add(still, slab, Transform3D(basis, middle), RAMP_COLOUR)
		var shape := BoxShape3D.new()
		shape.size = size
		var ramp_collider := CollisionShape3D.new()
		ramp_collider.shape = shape
		ramp_collider.transform = Transform3D(basis, middle)
		footing.add_child(ramp_collider)

## The sign on the south side, where a child arrives: a plate on a post with a
## coin and the price on it, as the kiosk has.
func _build_sign(still: SurfaceTool, footing: StaticBody3D) -> void:
	var at := Vector3(0.0, 0.0, RADIUS + 1.4)
	var post := BoxMesh.new()
	post.size = Vector3(0.12, 1.6, 0.12)
	var post_at := Transform3D(Basis(), at + Vector3(0.0, 0.8, 0.0))
	Park._add(still, post, post_at, Color(0.32, 0.30, 0.34))
	Park._solid(footing, post.size, post_at)
	var board := at + Vector3(0.0, 1.95, 0.0)
	Plaque.build(still, 0.0, board, 1.5, 0.7, 0.0, 0.08)
	# The coin to the left of the figure, on both faces.
	for face: float in [1.0, -1.0]:
		var coin := CylinderMesh.new()
		coin.top_radius = 0.14
		coin.bottom_radius = 0.14
		coin.height = 0.02
		coin.radial_segments = 14
		coin.rings = 1
		Park._add(
			still, coin,
			Transform3D(
				Basis(Vector3.RIGHT, PI * 0.5), board + Vector3(-0.46, 0.0, face * 0.105)
			),
			GOLD
		)
	Plaque.write(self, 0.0, board, [["%d" % Park.RIDE_PRICE, -0.02, 0.0042]], 0.08)

## The drum round the column: painted, with mirrors let into it and a gold band
## top and bottom. It stands on the axis, so a still collider is the same as a
## turning one; the collider is as wide as the widest thing drawn on it.
func _build_drum(turning: SurfaceTool, footing: StaticBody3D) -> void:
	var base := FLOOR_HEIGHT + DECK_THICKNESS * 0.5
	var drum := CylinderMesh.new()
	drum.top_radius = DRUM_RADIUS
	drum.bottom_radius = DRUM_RADIUS
	drum.height = DRUM_HEIGHT
	drum.radial_segments = 24
	drum.rings = 1
	Park._add(
		turning, drum, Transform3D(Basis(), Vector3(0.0, base + DRUM_HEIGHT * 0.5, 0.0)),
		DRUM_PAINT
	)
	for band_y: float in [0.09, DRUM_HEIGHT - 0.09]:
		var band := CylinderMesh.new()
		band.top_radius = DRUM_RADIUS + 0.03
		band.bottom_radius = DRUM_RADIUS + 0.03
		band.height = 0.18
		band.radial_segments = 24
		band.rings = 1
		Park._add(turning, band, Transform3D(Basis(), Vector3(0.0, base + band_y, 0.0)), TRIM)
	for panel in 8:
		var angle := TAU * (float(panel) + 0.5) / 8.0
		var glass := BoxMesh.new()
		glass.size = Vector3(0.62, DRUM_HEIGHT - 0.7, 0.05)
		# Its face outward: a box's +z turned to point along the radius.
		var face := Basis(Vector3.UP, PI * 0.5 - angle)
		Park._add(
			turning, glass,
			Transform3D(
				face, Vector3(cos(angle), 0.0, sin(angle)) * (DRUM_RADIUS - 0.005)
					+ Vector3(0.0, base + DRUM_HEIGHT * 0.5, 0.0)
			),
			MIRROR
		)
	var crown := CylinderMesh.new()
	crown.top_radius = DRUM_RADIUS + 0.2
	crown.bottom_radius = DRUM_RADIUS + 0.2
	crown.height = 0.12
	crown.radial_segments = 24
	crown.rings = 1
	Park._add(
		turning, crown, Transform3D(Basis(), Vector3(0.0, base + DRUM_HEIGHT + 0.06, 0.0)), TRIM
	)
	var solid := CylinderShape3D.new()
	solid.radius = DRUM_RADIUS + 0.03
	solid.height = DRUM_HEIGHT
	var body := CollisionShape3D.new()
	body.shape = solid
	body.position = Vector3(0.0, base + DRUM_HEIGHT * 0.5, 0.0)
	footing.add_child(body)

## One animal on its pole. The pole stands in the turning drawing and the animal
## is a mesh of its own, so that it can slide up and down the pole; its solid
## barrel is moved with it (see `_physics_process`).
func _build_animal(horse: int, turning: SurfaceTool, roof_base: Vector3, rim: float) -> void:
	var kind := KINDS[horse]
	var coat: Color = MountKinds.HORSE_COATS[horse % MountKinds.HORSE_COATS.size()]
	var figure := SurfaceTool.new()
	figure.begin(Mesh.PRIMITIVE_TRIANGLES)

	var angle := TAU * float(horse) / float(HORSES)
	var spot := Vector3(cos(angle), 0.0, sin(angle)) * (RADIUS * RING)
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
	var ride_at := spot + Vector3(0.0, FLOOR_HEIGHT + RIDE_ABOVE_FLOOR, 0.0)
	var saddle_top := ride_at.y + SADDLE_ABOVE_RIDE
	# A child's -z is the animal's +x (its head), so the seat is the animal's
	# own turn and a quarter more.
	_saddles.append(Transform3D(
		facing * Basis(Vector3.UP, -PI * 0.5),
		Vector3(ride_at.x, saddle_top, ride_at.z)
	))
	# How wide the barrel under it has to be to hold everything drawn on it.
	var width := 0.5

	match kind:
		&"chariot":
			width = 0.9
			_draw_chariot(figure, facing, ride_at, GOLD if horse % 2 == 1 else CANOPY_A)
		&"pig":
			_draw_pig(figure, facing, ride_at)
			_legs(figure, facing, ride_at, PIG_PINK.darkened(0.15))
			_saddle(figure, facing, ride_at, saddle_top)
		_:
			var body := BoxMesh.new()
			body.size = Vector3(1.5, 0.62, 0.42)
			Park._add(figure, body, Transform3D(facing, ride_at), coat)
			var neck := BoxMesh.new()
			neck.size = Vector3(0.36, 0.62, 0.34)
			Park._add(figure, neck, Transform3D(facing, ride_at + facing * Vector3(0.62, 0.42, 0.0)), coat)
			# Legs, a mane and a tail: a horse that is one slab on a stick reads
			# as a bench. They are drawn inside the barrel's own box (1.6 by
			# 0.5, down to 0.775 under ride_at), so the collider still
			# describes the horse.
			_legs(figure, facing, ride_at, coat.darkened(0.15))
			var mane := BoxMesh.new()
			mane.size = Vector3(0.1, 0.62, 0.1)
			Park._add(figure, mane, Transform3D(facing, ride_at + facing * Vector3(0.38, 0.52, 0.0)), coat.darkened(0.45))
			var tail := BoxMesh.new()
			tail.size = Vector3(0.1, 0.5, 0.12)
			Park._add(figure, tail, Transform3D(facing, ride_at + facing * Vector3(-0.78, -0.05, 0.0)), coat.darkened(0.45))
			var head := BoxMesh.new()
			head.size = Vector3(0.52, 0.30, 0.30)
			Park._add(figure, head, Transform3D(facing, ride_at + facing * Vector3(0.86, 0.66, 0.0)), coat)
			_saddle(figure, facing, ride_at, saddle_top)

	# The lap strap: across the thighs, round the brass pole, with a buckle.
	# What a child holds is the pole itself, which the pose's hands are on.
	var leather := ShopStock.colour(ShopStock.SADDLE).darkened(0.35)
	var strap_y := SADDLE_ABOVE_RIDE + 0.17
	var strap := BoxMesh.new()
	strap.size = Vector3(0.1, 0.04, width + 0.02)
	Park._add(figure, strap, Transform3D(facing, ride_at + facing * Vector3(-0.06, strap_y, 0.0)), leather)
	for side: float in [-1.0, 1.0]:
		var drop := BoxMesh.new()
		drop.size = Vector3(0.1, 0.2, 0.04)
		Park._add(
			figure, drop,
			Transform3D(facing, ride_at + facing * Vector3(-0.06, strap_y - 0.1, side * (width * 0.5 + 0.01))),
			leather
		)
	var buckle := BoxMesh.new()
	buckle.size = Vector3(0.07, 0.06, 0.08)
	Park._add(figure, buckle, Transform3D(facing, ride_at + facing * Vector3(-0.06, strap_y + 0.03, 0.0)), GOLD)
	_figures.append(Park.commit(figure, _turntable, "Animal%d" % horse))

	# What a child bumps into: the barrel of the animal, turned with it, and
	# topped exactly where the saddle sits rather than a fraction above or below
	# it — an animal a child could find themselves floating over, or sunk into,
	# is not one that reads as ridden.
	var barrel_bottom := ride_at.y - 0.775
	var barrel_height := saddle_top - barrel_bottom
	var solid := BoxShape3D.new()
	solid.size = Vector3(1.6, barrel_height, width)
	var barrel := CollisionShape3D.new()
	barrel.shape = solid
	var rest := Transform3D(
		facing, Vector3(ride_at.x, barrel_bottom + barrel_height * 0.5, ride_at.z)
	)
	barrel.transform = rest
	_horses.add_child(barrel)
	_barrels.append(barrel)
	_barrel_rest.append(rest)

## A gilded chariot: a tub with a high back and a scrolled front, on a skirt
## and two wheels, its seat at the height of a saddle.
func _draw_chariot(figure: SurfaceTool, facing: Basis, ride_at: Vector3, gilt: Color) -> void:
	var tub := BoxMesh.new()
	tub.size = Vector3(1.5, 0.42, 0.8)
	Park._add(figure, tub, Transform3D(facing, ride_at + facing * Vector3(0.0, 0.10, 0.0)), gilt)
	var cushion := BoxMesh.new()
	cushion.size = Vector3(1.2, 0.08, 0.62)
	Park._add(
		figure, cushion, Transform3D(facing, ride_at + facing * Vector3(-0.05, 0.31, 0.0)),
		ShopStock.colour(ShopStock.SADDLE)
	)
	var front := BoxMesh.new()
	front.size = Vector3(0.12, 0.62, 0.8)
	Park._add(figure, front, Transform3D(facing, ride_at + facing * Vector3(0.72, 0.34, 0.0)), gilt.darkened(0.15))
	var back := BoxMesh.new()
	back.size = Vector3(0.1, 0.56, 0.8)
	Park._add(figure, back, Transform3D(facing, ride_at + facing * Vector3(-0.68, 0.62, 0.0)), gilt.darkened(0.15))
	var undercarriage := BoxMesh.new()
	undercarriage.size = Vector3(1.2, 0.5, 0.6)
	Park._add(figure, undercarriage, Transform3D(facing, ride_at + facing * Vector3(0.0, -0.36, 0.0)), TRIM)
	for side: float in [-1.0, 1.0]:
		var wheel := CylinderMesh.new()
		wheel.top_radius = 0.3
		wheel.bottom_radius = 0.3
		wheel.height = 0.06
		wheel.radial_segments = 12
		wheel.rings = 1
		Park._add(
			figure, wheel,
			Transform3D(
				facing * Basis(Vector3.RIGHT, PI * 0.5),
				ride_at + facing * Vector3(0.0, -0.3, side * 0.41)
			),
			GOLD
		)

## A pig: round pink body, a snout, ears and a curl of tail. Its legs and saddle
## are the horse's.
func _draw_pig(figure: SurfaceTool, facing: Basis, ride_at: Vector3) -> void:
	var body := BoxMesh.new()
	body.size = Vector3(1.3, 0.62, 0.42)
	Park._add(figure, body, Transform3D(facing, ride_at), PIG_PINK)
	var head := BoxMesh.new()
	head.size = Vector3(0.46, 0.42, 0.4)
	Park._add(figure, head, Transform3D(facing, ride_at + facing * Vector3(0.82, 0.16, 0.0)), PIG_PINK)
	var snout := BoxMesh.new()
	snout.size = Vector3(0.14, 0.2, 0.26)
	Park._add(figure, snout, Transform3D(facing, ride_at + facing * Vector3(1.09, 0.1, 0.0)), PIG_PINK.darkened(0.2))
	for side: float in [-1.0, 1.0]:
		var ear := BoxMesh.new()
		ear.size = Vector3(0.1, 0.16, 0.08)
		Park._add(figure, ear, Transform3D(facing, ride_at + facing * Vector3(0.74, 0.44, side * 0.14)), PIG_PINK.darkened(0.1))
	var curl := BoxMesh.new()
	curl.size = Vector3(0.08, 0.24, 0.08)
	Park._add(figure, curl, Transform3D(facing, ride_at + facing * Vector3(-0.68, 0.22, 0.0)), PIG_PINK.darkened(0.2))

## Four legs, as on a horse and on a pig alike.
func _legs(figure: SurfaceTool, facing: Basis, ride_at: Vector3, colour: Color) -> void:
	for along: float in [-0.55, 0.55]:
		for side: float in [-0.12, 0.12]:
			var leg := BoxMesh.new()
			leg.size = Vector3(0.14, 0.46, 0.14)
			Park._add(
				figure, leg,
				Transform3D(facing, ride_at + facing * Vector3(along, -0.31 - 0.23 + 0.02, side)),
				colour
			)

## The saddle: a proper seat on the animal's own back, leather-coloured like
## every other saddle in the game, and something for a child's foot to look for.
## Long enough to sit behind the brass pole, which stands in the middle of it
## and goes up through the roof: the child's hips are 0.18 behind it, so the
## saddle runs 0.39 back from the pole and the cantle after.
func _saddle(figure: SurfaceTool, facing: Basis, ride_at: Vector3, saddle_top: float) -> void:
	var saddle := BoxMesh.new()
	saddle.size = Vector3(0.64, 0.1, 0.4)
	var saddle_at := Vector3(ride_at.x, saddle_top - 0.05, ride_at.z)
	Park._add(figure, saddle, Transform3D(facing, saddle_at + facing * Vector3(-0.07, 0.0, 0.0)), ShopStock.colour(ShopStock.SADDLE))
	var cantle := BoxMesh.new()
	cantle.size = Vector3(0.08, 0.18, 0.4)
	Park._add(
		figure, cantle,
		Transform3D(facing, saddle_at + facing * Vector3(-0.35, 0.08, 0.0)),
		ShopStock.colour(ShopStock.SADDLE).darkened(0.2)
	)

## How far the carousel's tune carries, how loud it is while the ride is going
## (and louder still the closer a child stands: the player is a 3D one) and how
## quiet when it stands.
const MUSIC_REACH := 45.0
const MUSIC_DB := -12.0
const MUSIC_STILL_DB := -26.0

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
	_phase_time += delta
	match _phase:
		Phase.STILL:
			_speed = 0.0
		Phase.SPIN_UP:
			_speed = smoothstep(0.0, 1.0, _phase_time / SPIN_UP_TIME)
			if _phase_time >= SPIN_UP_TIME:
				_phase = Phase.RIDING
				_phase_time = 0.0
		Phase.RIDING:
			_speed = 1.0
			if _phase_time >= RIDE_TIME:
				_phase = Phase.SLOWING
				_phase_time = 0.0
		Phase.SLOWING:
			_speed = 1.0 - smoothstep(0.0, 1.0, _phase_time / SLOW_TIME)
			if _phase_time >= SLOW_TIME:
				_phase = Phase.STILL
				_phase_time = 0.0
				_speed = 0.0
	_swept = TURN_RATE * _speed * delta
	_turned = fmod(_turned + _swept, TAU)
	_bob_clock += _speed * delta
	var spin := Transform3D(Basis(Vector3.UP, _turned), Vector3.ZERO)
	_turntable.transform = spin
	_horses.transform = spin
	# Each animal up or down its pole, and its barrel with it: what is drawn is
	# what a child bumps into.
	for horse in HORSES:
		var up := Vector3(0.0, _bob_of(horse), 0.0)
		_figures[horse].position = up
		_barrels[horse].transform = Transform3D(
			_barrel_rest[horse].basis, _barrel_rest[horse].origin + up
		)
	_music.volume_db = lerpf(MUSIC_STILL_DB, MUSIC_DB, _speed)

## How far an animal is up its pole. Nought while the ride is still, so a child
## let off steps down from a saddle at its resting height, and the same for all
## of them whenever it is stopped.
func _bob_of(horse: int) -> float:
	return BOB * _speed * sin(_bob_clock * BOB_RATE + float(horse) * PI)

## How far the floor moves whoever is standing on it, this frame.
##
## Godot will not do this for us. A character body standing on a body that is
## being *rotated* is not taken round with it — the engine carries a passenger
## along a platform that slides, and leaves them where they are on one that
## turns. So the ride says how far it has swept its floor and the game moves
## the child by that much, which is the same answer and one we can test.
func carry(at: Vector3, _delta: float) -> Vector3:
	if _swept == 0.0:
		return Vector3.ZERO
	var out := Vector2(at.x - global_position.x, at.z - global_position.z)
	if out.length() > RADIUS:
		return Vector3.ZERO
	var floor_at := global_position.y + FLOOR_HEIGHT
	if at.y < floor_at - 0.2 or at.y > floor_at + 2.4:
		return Vector3.ZERO
	# As far as the floor went in its own last tick, which is the same floor
	# whatever the frame rate, and not the speed it is nominally turning at: it
	# is spinning up or slowing for most of a short ride.
	var swept := out.rotated(-_swept) - out
	return Vector3(swept.x, 0.0, swept.y)

## Every saddle, in the world as the ride stands now: the origin the top of its
## centre, the basis the way a child on it faces. For the checks and the viewer.
func saddles() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for horse in HORSES:
		var saddle := _saddles[horse]
		saddle.origin.y += _bob_of(horse)
		out.append(_horses.global_transform * saddle)
	return out

## The saddle a child is in, or a transform of NANs if they are not on one.
## It is read off where they are rather than off which animal is where, so that
## the other child's phone — whose ride is at some other turn of its own —
## still sees them seated: the ring the saddles go round at, at the height of a
## saddle, is only ever somewhere a child sits. The floor of the ride is not a
## seat, and nor is the air above it. The facing is along the way round.
func seat_near(at: Vector3) -> Transform3D:
	var out := Vector2(at.x - global_position.x, at.z - global_position.z)
	var saddle_y := global_position.y + SADDLE_TOP
	if absf(out.length() - RADIUS * RING) > 0.6 \
			or at.y < saddle_y - BOB - 0.3 or at.y > saddle_y + BOB + 0.4:
		return Transform3D(Basis(), Vector3(NAN, NAN, NAN))
	var angle := out.angle()
	var along := Vector3(sin(angle), 0.0, -cos(angle))
	return Transform3D(Basis.looking_at(along, Vector3.UP), at)

## Nobody is aboard and it is not going: a child who has paid may be put on.
func free_to_board() -> bool:
	return _phase == Phase.STILL and _rider < 0

## Seat a child who has paid on the animal nearest them, and start the ride.
## False if it is not free to. Where they stand is all that is asked: nobody
## has to climb onto anything, which a thumb-stick cannot do onto a horse that
## is a metre and a half up.
func board(at: Vector3) -> bool:
	if not free_to_board():
		return false
	var best := 0
	var nearest := INF
	var here := saddles()
	for horse in HORSES:
		var apart := Vector2(here[horse].origin.x - at.x, here[horse].origin.z - at.z).length()
		if apart < nearest:
			nearest = apart
			best = horse
	_rider = best
	_phase = Phase.SPIN_UP
	_phase_time = 0.0
	return true

## Is somebody in a saddle, going round or waiting to be let off?
func has_rider() -> bool:
	return _rider >= 0

## The ride has run its minute and stopped, and the rider is still in the saddle.
func ride_is_over() -> bool:
	return _rider >= 0 and _phase == Phase.STILL

## Which animal the rider is on, or -1. For the checks.
func rider_horse() -> int:
	return _rider

func phase() -> Phase:
	return _phase

func speed() -> float:
	return _speed

## Where the rider sits, in the world as the ride stands now, or a transform of
## NANs if nobody is aboard.
func rider_seat() -> Transform3D:
	if _rider < 0:
		return Transform3D(Basis(), Vector3(NAN, NAN, NAN))
	return saddles()[_rider]

## Let the rider off: where they are to be put, on the deck beside their own
## animal, out from the middle and clear of its barrel and its neighbours'.
## Frees the ride for the next ticket.
func step_off() -> Vector3:
	var here := rider_seat()
	_rider = -1
	var out := Vector2(here.origin.x - global_position.x, here.origin.z - global_position.z)
	var spot := out.normalized() * (RADIUS * RING + 1.4)
	return Vector3(
		global_position.x + spot.x,
		global_position.y + FLOOR_HEIGHT + DECK_THICKNESS * 0.5 + 0.03,
		global_position.z + spot.y
	)

## The bulbs' glow: a mesh of its own on the turntable, whose material `glow`
## turns up at dusk, and a warm light under the canopy.
func _commit_glow(glowing: SurfaceTool, roof_base: Vector3) -> void:
	_glow_material = StandardMaterial3D.new()
	_glow_material.vertex_color_use_as_albedo = true
	_glow_material.vertex_color_is_srgb = true
	_glow_material.emission_enabled = true
	_glow_material.emission = Color(1.0, 0.86, 0.5)
	_glow_material.emission_energy_multiplier = 0.3
	glowing.generate_normals()
	glowing.set_material(_glow_material)
	var lit := MeshInstance3D.new()
	lit.name = "Glow"
	lit.mesh = glowing.commit()
	lit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_turntable.add_child(lit)
	_glow_light = OmniLight3D.new()
	_glow_light.name = "GlowLight"
	_glow_light.light_color = Color(1.0, 0.82, 0.5)
	_glow_light.omni_range = 11.0
	_glow_light.light_energy = 0.0
	_glow_light.shadow_enabled = false
	_glow_light.visible = false
	_glow_light.position = Vector3(0.0, roof_base.y - 0.4, 0.0)
	add_child(_glow_light)

## Turn the lights up with the dark: told by the game, which knows the hour. By
## day the bulbs are only paint; at dusk they shine, and the ride lights the
## fairground round it.
func glow(darkness: float) -> void:
	var lit := smoothstep(0.25, 0.7, darkness)
	_glow_material.emission_energy_multiplier = 0.3 + 3.0 * lit
	_glow_light.light_energy = 1.4 * lit
	_glow_light.visible = lit > 0.01

## How far round it has turned. For the checks.
func turned() -> float:
	return _turned
