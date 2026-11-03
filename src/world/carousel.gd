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
	&"horse", &"pig", &"horse", &"swan", &"horse", &"rooster", &"horse", &"swan",
]
## The paint of the four horses: a coat, the colour of the mane and tail, and of
## the saddle cloth. Bright and clean, as a fairground's is, so that each reads
## as a horse from across the sand and not as a dull shape.
const HORSE_PAINT: Array[Array] = [
	[Color(0.98, 0.96, 0.92), Color(0.96, 0.74, 0.20), Color(0.86, 0.22, 0.34)],
	[Color(0.99, 0.91, 0.68), Color(0.82, 0.28, 0.52), Color(0.24, 0.50, 0.84)],
	[Color(0.66, 0.83, 0.96), Color(0.98, 0.97, 0.94), Color(0.90, 0.30, 0.34)],
	[Color(0.98, 0.72, 0.82), Color(0.30, 0.46, 0.84), Color(0.98, 0.80, 0.26)],
]
const HOOF := Color(0.42, 0.34, 0.30)
const DARK_EYE := Color(0.14, 0.12, 0.16)
const WEBBING := Color(0.96, 0.92, 0.80)
## The painted drum in the middle, solid and collided as drawn.
const DRUM_RADIUS := 1.12
const DRUM_HEIGHT := 2.4
## How far the paint and the gold trim stand out from the drum's skin, at the
## furthest: the collider goes out as far as that.
const DRUM_PAINT_REACH := 0.06
## The ramps up onto the deck. A deck two thirds of a metre up with nothing to
## climb it by is a wall to a child on a thumb-stick, who cannot step up: four
## slopes, between the animals, that a body simply walks up.
const RAMP_RUN := 2.4
const RAMP_WIDTH := 2.2
const RAMP_THICKNESS := 0.12
const RAIL_HEIGHT := 0.85
const RAIL_COLOUR := Color(0.97, 0.94, 0.86)

enum Phase { STILL, SPIN_UP, RIDING, SLOWING }

const DRUM_PAINT := Color(0.30, 0.52, 0.78)
const MIRROR := Color(0.74, 0.86, 0.94)
const PIG_PINK := Color(1.0, 0.72, 0.74)
const RAMP_COLOUR := Color(0.62, 0.46, 0.32)
const GOLD := Color(0.96, 0.78, 0.22)
const FLOOR_COLOUR := Color(0.88, 0.38, 0.34)
const TRIM := Color(0.96, 0.86, 0.42)
const POLE := Color(0.86, 0.80, 0.52)
const CANOPY_A := Color(0.84, 0.26, 0.24)
const CANOPY_B := Color(0.96, 0.92, 0.84)
## The valance's two colours, each a shade off the stripe above it, so that the
## canopy check, which counts the stripes' own colours, still counts one cone.
const VALANCE_A := Color(0.93, 0.36, 0.38)
const VALANCE_B := Color(1.0, 0.97, 0.88)
const PENNANT := Color(0.97, 0.28, 0.50)

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
	_build_deck(turning)

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
	_build_valance(turning, glowing, roof_base, rim)
	_build_roof_top(turning, roof_apex, roof_base, rim)

	# The animals: a body on a brass pole, facing the way round.
	for horse in HORSES:
		_build_animal(horse, turning, roof_base, rim)

	# Drawn once, on the turntable. It was committed to the horses' body as
	# well, so every vertex of the ride went to the card twice, one copy on
	# top of the other, turning in step.
	#
	# The turning part casts no shadow. At midday the canopy threw one hard
	# shadow over the whole deck, and what stood in it was lit by the blue of
	# the sky alone: the pale horses went lilac and the red deck maroon. (A warm
	# light under the canopy was tried, and only warmed the sides of the horses
	# that face the middle, and put a hot patch on the stripes.) The animals are
	# meshes of their own, so they still shade the deck and one another, and the
	# still part, the ramps and the sign, still shades the sand.
	var turning_drawn := Park.commit(turning, _turntable, "Turning")
	turning_drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
		# Drawn as planks laid end to end, two colours alternating, so that it
		# reads as a boarded ramp and not as one brown slab; collided as the one
		# box they make together.
		var planks := 8
		var plank_length := size.x / float(planks)
		for plank in planks:
			var piece := BoxMesh.new()
			piece.size = Vector3(plank_length - 0.02, RAMP_THICKNESS, RAMP_WIDTH)
			var along := (float(plank) + 0.5) * plank_length - size.x * 0.5
			Park._add(
				still, piece, Transform3D(basis, middle + down * along),
				RAMP_COLOUR if plank % 2 == 0 else RAMP_COLOUR.lightened(0.18)
			)
		var shape := BoxShape3D.new()
		shape.size = size
		var ramp_collider := CollisionShape3D.new()
		ramp_collider.shape = shape
		ramp_collider.transform = Transform3D(basis, middle)
		footing.add_child(ramp_collider)
		_build_handrails(still, footing, basis, middle + normal * RAMP_THICKNESS * 0.5, size)

## The handrails either side of a ramp: posts, a high rail and a low one, drawn
## in cream with a gold ball on each end post, and collided as the one thin wall
## they make, since a child's body cannot go between the rails either. `surface`
## is the middle of the ramp's walking face, and the basis runs down the slope,
## up out of it and across.
func _build_handrails(
	still: SurfaceTool, footing: StaticBody3D, basis: Basis, surface: Vector3, size: Vector3
) -> void:
	var down := basis.x
	var up := basis.y
	var across := basis.z
	var posts := 4
	for side: float in [-1.0, 1.0]:
		var edge := surface + across * side * (RAMP_WIDTH * 0.5 - 0.05)
		for post in posts:
			var along := -size.x * 0.5 + 0.06 + (size.x - 0.12) * float(post) / float(posts - 1)
			var base := edge + down * along
			# Upright, not square to the slope: a post leans nowhere.
			_strut(still, base, base + Vector3.UP * RAIL_HEIGHT, 0.035, 0.035, RAIL_COLOUR, 5)
			if post == 0 or post == posts - 1:
				var ball := SphereMesh.new()
				ball.radius = 0.07
				ball.height = 0.14
				ball.radial_segments = 8
				ball.rings = 4
				Park._add(still, ball, Transform3D(Basis(), base + Vector3.UP * (RAIL_HEIGHT + 0.05)), GOLD)
		for rail_height: float in [RAIL_HEIGHT, RAIL_HEIGHT * 0.45]:
			var from := edge + down * (-size.x * 0.5 + 0.06) + Vector3.UP * rail_height
			var to := edge + down * (size.x * 0.5 - 0.06) + Vector3.UP * rail_height
			_strut(still, from, to, 0.03, 0.03, RAIL_COLOUR, 5)
		# The wall: from the slope to the top rail, as thick as the posts.
		var wall := BoxShape3D.new()
		wall.size = Vector3(size.x, RAIL_HEIGHT + 0.05, 0.07)
		var wall_collider := CollisionShape3D.new()
		wall_collider.shape = wall
		wall_collider.transform = Transform3D(basis, edge + up * (wall.size.y * 0.5))
		footing.add_child(wall_collider)

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
	# Eight bays, alternately a mirror and a painted panel, each in a gold frame
	# and parted by a gold pilaster. Every one is a strip bent round the drum
	# rather than a flat board stood against it, so that nothing is drawn wider
	# than the paint the collider already covers.
	var bay := TAU / 8.0
	var painted: Array[Color] = [
		Color(0.96, 0.46, 0.50), Color(0.99, 0.82, 0.36), Color(0.60, 0.80, 0.52),
		Color(0.80, 0.54, 0.86),
	]
	var low := base + 0.3
	var high := base + DRUM_HEIGHT - 0.3
	for panel in 8:
		var middle := bay * (float(panel) + 0.5)
		_arc_strip(turning, DRUM_RADIUS + 0.012, middle - bay * 0.40, middle + bay * 0.40, low, high, TRIM)
		if panel % 2 == 0:
			_arc_strip(
				turning, DRUM_RADIUS + 0.024, middle - bay * 0.34, middle + bay * 0.34,
				low + 0.08, high - 0.08, MIRROR
			)
			# A glint across the glass: a paler stripe, as light catches a mirror.
			_arc_strip(
				turning, DRUM_RADIUS + 0.028, middle - bay * 0.24, middle - bay * 0.14,
				low + 0.3, high - 0.3, MIRROR.lightened(0.6)
			)
		else:
			var paint: Color = painted[(panel / 2) % painted.size()]
			_arc_strip(
				turning, DRUM_RADIUS + 0.024, middle - bay * 0.34, middle + bay * 0.34,
				low + 0.08, high - 0.08, paint
			)
			# A gold lozenge on the paint, lying in the plane that touches the
			# drum, a hair inside the widest paint.
			var out := Vector3(cos(middle), 0.0, sin(middle))
			var side := Vector3(-sin(middle), 0.0, cos(middle))
			var centre := out * (DRUM_RADIUS + 0.028) + Vector3(0.0, (low + high) * 0.5, 0.0)
			_quad(
				turning, centre + Vector3.UP * 0.34, centre + side * 0.2,
				centre - Vector3.UP * 0.34, centre - side * 0.2, out, GOLD
			)
		var edge := bay * float(panel)
		_strut(
			turning,
			Vector3(cos(edge), base, sin(edge)) * (DRUM_RADIUS - 0.01),
			Vector3(cos(edge), base + DRUM_HEIGHT, sin(edge)) * (DRUM_RADIUS - 0.01),
			0.05, 0.05, GOLD, 5
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
	# A gold dome on the crown, the column going up through it.
	var dome := SphereMesh.new()
	dome.radius = DRUM_RADIUS + 0.1
	dome.height = DRUM_RADIUS + 0.1
	dome.radial_segments = 16
	dome.rings = 8
	dome.is_hemisphere = true
	Park._add(
		turning, dome,
		Transform3D(
			Basis.from_scale(Vector3(1.0, 0.45, 1.0)),
			Vector3(0.0, base + DRUM_HEIGHT + 0.12, 0.0)
		),
		GOLD
	)
	var solid := CylinderShape3D.new()
	solid.radius = DRUM_RADIUS + DRUM_PAINT_REACH
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

	# Everything below is drawn in the animal's own frame — x along it towards
	# the head, y up, z across — about the middle of its body, and put in the
	# world by this one transform.
	var frame := Transform3D(facing, ride_at)
	var paint: Array = HORSE_PAINT[(horse / 2) % HORSE_PAINT.size()]
	match kind:
		&"swan":
			width = 0.9
			_draw_swan(figure, frame, GOLD if horse % 4 == 3 else Color(0.62, 0.80, 0.96))
		&"pig":
			_draw_pig(figure, frame, paint[2])
			_saddle(figure, frame, saddle_top - ride_at.y, paint[2])
		&"rooster":
			_draw_rooster(figure, frame)
			_saddle(figure, frame, saddle_top - ride_at.y, Color(0.30, 0.64, 0.80))
		_:
			# A prancing horse: the neck arched, the head tucked, one foreleg
			# folded up. It is drawn inside the barrel's own box (1.6 by 0.5, down
			# to 0.775 under ride_at) except for the head, which is above the
			# saddle where nothing a child does reaches.
			_draw_horse(figure, frame, paint[0], paint[1])
			_saddle(figure, frame, saddle_top - ride_at.y, paint[2])

	# The lap belt: a thin cream webbing laid across the thighs and down either
	# side of the saddle, with a gold buckle. What a child holds is the brass
	# pole, which the pose's hands are on.
	var belt_y := SADDLE_ABOVE_RIDE + 0.12
	var belt_half := width * 0.5 + 0.02
	_block(figure, frame, Vector3(-0.06, belt_y, 0.0), Vector3(0.05, 0.015, belt_half * 2.0), WEBBING)
	for side: float in [-1.0, 1.0]:
		_block(
			figure, frame, Vector3(-0.06, (0.30 + belt_y) * 0.5, side * belt_half),
			Vector3(0.05, belt_y - 0.30 + 0.01, 0.015), WEBBING
		)
	_block(figure, frame, Vector3(-0.06, belt_y + 0.01, 0.0), Vector3(0.06, 0.02, 0.07), GOLD)
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
func _draw_swan(figure: SurfaceTool, frame: Transform3D, gilt: Color) -> void:
	var white := Color(0.99, 0.99, 1.0)
	var beak := Color(1.0, 0.58, 0.16)
	# The tub: a rounded hull, blunt at the stern and drawn out to a prow that
	# sweeps up at the front, on a rounded skirt, with the gold edging following
	# the hull's own rim (see `_tub`).
	_tub(figure, frame, gilt)
	_ball(figure, frame, Vector3(0.0, -0.34, 0.0), Vector3(0.62, 0.27, 0.30), TRIM)
	_block(
		figure, frame, Vector3(-0.68, 0.62, 0.0), Vector3(0.1, 0.56, 0.8), gilt.darkened(0.15)
	)
	# The cushion is a saddle's height and colour, which is what the seat is.
	_block(
		figure, frame, Vector3(-0.05, 0.31, 0.0), Vector3(1.2, 0.08, 0.62),
		ShopStock.colour(ShopStock.SADDLE)
	)
	# The swan: a long S of a neck rising from the prow, a head bent down, and
	# an orange bill with a black knob.
	var neck: Array[Vector3] = [
		Vector3(0.62, 0.34, 0.0), Vector3(0.84, 0.58, 0.0), Vector3(0.76, 0.88, 0.0),
		Vector3(0.86, 1.10, 0.0),
	]
	var thick: Array[float] = [0.17, 0.12, 0.10, 0.09]
	for index in neck.size() - 1:
		_rod(figure, frame, neck[index], neck[index + 1], thick[index], thick[index + 1], white, 6)
		_ball(figure, frame, neck[index + 1], Vector3.ONE * thick[index + 1], white)
	_ball(figure, frame, Vector3(0.90, 1.14, 0.0), Vector3(0.16, 0.12, 0.11), white)
	_rod(figure, frame, Vector3(0.98, 1.13, 0.0), Vector3(1.16, 1.06, 0.0), 0.06, 0.035, beak, 5)
	_ball(figure, frame, Vector3(0.99, 1.17, 0.0), Vector3(0.04, 0.04, 0.05), Color(0.14, 0.12, 0.16))
	for side: float in [-1.0, 1.0]:
		_ball(figure, frame, Vector3(0.92, 1.18, side * 0.1), Vector3.ONE * 0.025, DARK_EYE)
		# A wing, lifted a little, from the rider's hip to the back.
		_ball(
			figure, frame, Vector3(-0.30, 0.50, side * 0.44), Vector3(0.52, 0.2, 0.05), white,
			Basis(Vector3.BACK, deg_to_rad(18.0))
		)
		_ball(
			figure, frame, Vector3(-0.52, 0.62, side * 0.44), Vector3(0.3, 0.14, 0.04),
			Color(0.90, 0.94, 1.0), Basis(Vector3.BACK, deg_to_rad(30.0))
		)
	# Tail feathers, fanned up behind the backrest.
	for fan in 3:
		var spread := float(fan - 1) * 0.2
		_rod(
			figure, frame, Vector3(-0.70, 0.84, 0.0), Vector3(-0.78, 1.06, spread),
			0.07, 0.025, white, 5
		)
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
				frame.basis * Basis(Vector3.RIGHT, PI * 0.5),
				frame * Vector3(0.0, -0.3, side * 0.41)
			),
			GOLD
		)

## Where the swan's hull is, at `along` (-1 at the stern to 1 at the prow): how
## far forward of the animal's middle, how wide either side of it, how high the
## rim stands and how deep the keel hangs below the rim. In the animal's own
## frame. The stern is blunt and the prow comes to a point and lifts, as a boat's.
static func _hull_at(along: float) -> Dictionary:
	var half_beam := 0.40 - 0.04 * along * along if along < 0.0 else 0.40 * pow(1.0 - along * along, 0.6)
	return {
		"x": -0.64 + (along + 1.0) * 0.72,
		"beam": half_beam,
		"rim": 0.31 + 0.2 * pow(maxf(along, 0.0), 3.0),
		"keel": 0.42 * (1.0 - 0.55 * along * along),
	}

## The chariot's tub as one lofted skin: stations from the stern to the prow,
## each a half ellipse across, with a deck closing the top (the cushion lies on
## it) and a transom closing the stern. The gold rail runs along the rim.
func _tub(figure: SurfaceTool, frame: Transform3D, gilt: Color) -> void:
	var stations := 8
	var round_ways := 6
	var deck := gilt.darkened(0.12)
	var previous: Array[Vector3] = []
	var last_rim: Array[Vector3] = []
	for index in stations + 1:
		var hull := _hull_at(-1.0 + 2.0 * float(index) / float(stations))
		var ring: Array[Vector3] = []
		for way in round_ways + 1:
			var angle := PI * float(way) / float(round_ways)
			ring.append(frame * Vector3(
				float(hull["x"]),
				float(hull["rim"]) - float(hull["keel"]) * sin(angle),
				float(hull["beam"]) * cos(angle)
			))
		var rim: Array[Vector3] = [ring[0], ring[round_ways]]
		if index == 0:
			# The transom: a flat face, fanned from the middle of the stern.
			var middle := frame * Vector3(float(hull["x"]), float(hull["rim"]) - float(hull["keel"]) * 0.5, 0.0)
			var backwards := frame.basis * Vector3.LEFT
			for way in round_ways:
				_quad(figure, middle, ring[way], ring[way + 1], middle, backwards, gilt)
		else:
			for way in round_ways:
				var centre := (ring[way] + ring[way + 1] + previous[way] + previous[way + 1]) * 0.25
				var axis := frame * Vector3(float(hull["x"]), float(hull["rim"]), 0.0)
				_quad(figure, previous[way], previous[way + 1], ring[way + 1], ring[way], centre - axis, gilt)
			_quad(figure, last_rim[0], ring[0], ring[round_ways], last_rim[1], frame.basis * Vector3.UP, deck)
			for side in 2:
				_strut(figure, last_rim[side], rim[side], 0.03, 0.03, GOLD, 5)
		previous = ring
		last_rim = rim

## A pig: round and pink, a saddle cloth on its back, a snout with two nostrils,
## floppy ears, a curl of tail and four short legs on little dark trotters.
func _draw_pig(figure: SurfaceTool, frame: Transform3D, cloth: Color) -> void:
	var dark := PIG_PINK.darkened(0.16)
	# One fat ellipsoid for the body, deep so that the legs under it are short.
	# All of it inside the barrel's own length, which is 0.8 either side.
	_ball(figure, frame, Vector3(-0.10, -0.06, 0.0), Vector3(0.64, 0.30, 0.245), PIG_PINK)
	# The head, big and round at the front, with a flat snout.
	_ball(figure, frame, Vector3(0.54, 0.06, 0.0), Vector3(0.24, 0.23, 0.22), PIG_PINK)
	_rod(figure, frame, Vector3(0.68, 0.03, 0.0), Vector3(0.79, 0.03, 0.0), 0.125, 0.13, dark, 8)
	for side: float in [-1.0, 1.0]:
		_ball(figure, frame, Vector3(0.795, 0.03, side * 0.05), Vector3(0.02, 0.035, 0.022), DARK_EYE)
		_ball(figure, frame, Vector3(0.69, 0.17, side * 0.13), Vector3.ONE * 0.04, DARK_EYE)
		# An ear, a flat flap that folds forward and hangs down over the side of
		# the head, as a pig's do: a rod pricked up from the crown read as a horn.
		_ball(
			figure, frame, Vector3(0.58, 0.19, side * 0.20), Vector3(0.115, 0.03, 0.085), dark,
			Basis(Vector3.BACK, deg_to_rad(-25.0)) * Basis(Vector3.RIGHT, side * deg_to_rad(52.0))
		)
	# A curl of tail: three short sticks that turn on themselves.
	_rod(figure, frame, Vector3(-0.70, 0.06, 0.0), Vector3(-0.77, 0.15, 0.0), 0.04, 0.035, dark, 4)
	_rod(figure, frame, Vector3(-0.77, 0.15, 0.0), Vector3(-0.74, 0.26, 0.0), 0.035, 0.03, dark, 4)
	_rod(figure, frame, Vector3(-0.74, 0.26, 0.0), Vector3(-0.66, 0.23, 0.0), 0.03, 0.025, dark, 4)
	for along: float in [-0.46, 0.44]:
		for side: float in [-0.14, 0.14]:
			_rod(figure, frame, Vector3(along, -0.2, side), Vector3(along, -0.64, side), 0.115, 0.095, PIG_PINK, 6)
			_rod(figure, frame, Vector3(along, -0.62, side), Vector3(along, -0.74, side), 0.1, 0.105, HOOF, 6)

## A rooster: an upright body, a proud chest, a fan of tail feathers in four
## colours, a red comb and wattle, and yellow legs.
func _draw_rooster(figure: SurfaceTool, frame: Transform3D) -> void:
	var body := Color(0.94, 0.46, 0.20)
	var red := Color(0.88, 0.16, 0.20)
	var yellow := Color(1.0, 0.82, 0.24)
	_rod(figure, frame, Vector3(-0.36, 0.04, 0.0), Vector3(0.28, 0.14, 0.0), 0.24, 0.245, body, 8)
	_ball(figure, frame, Vector3(-0.36, 0.04, 0.0), Vector3.ONE * 0.24, body)
	_ball(figure, frame, Vector3(0.30, 0.17, 0.0), Vector3(0.26, 0.28, 0.24), Color(0.98, 0.58, 0.26))
	_rod(figure, frame, Vector3(0.36, 0.30, 0.0), Vector3(0.52, 0.64, 0.0), 0.13, 0.095, body, 6)
	_ball(figure, frame, Vector3(0.55, 0.72, 0.0), Vector3(0.13, 0.12, 0.11), body)
	_rod(figure, frame, Vector3(0.64, 0.72, 0.0), Vector3(0.80, 0.68, 0.0), 0.05, 0.012, yellow, 4)
	_ball(figure, frame, Vector3(0.66, 0.62, 0.0), Vector3(0.03, 0.07, 0.03), red)
	for tuft in 3:
		_ball(
			figure, frame, Vector3(0.50 + float(tuft) * 0.045, 0.86 - absf(float(tuft) - 1.0) * 0.03, 0.0),
			Vector3(0.035, 0.07, 0.03), red
		)
	for side: float in [-1.0, 1.0]:
		_ball(figure, frame, Vector3(0.62, 0.76, side * 0.09), Vector3.ONE * 0.025, DARK_EYE)
		_ball(figure, frame, Vector3(-0.10, 0.10, side * 0.235), Vector3(0.3, 0.17, 0.035), body.darkened(0.18), Basis(Vector3.BACK, deg_to_rad(-14.0)))
		_rod(figure, frame, Vector3(0.1 * side, -0.14, side * 0.12), Vector3(0.1 * side, -0.70, side * 0.12), 0.04, 0.03, yellow, 5)
	# The tail: a fan of long feathers sweeping up and back.
	var feathers: Array[Color] = [
		Color(0.16, 0.62, 0.66), red, Color(0.98, 0.70, 0.18), Color(0.30, 0.66, 0.38),
		Color(0.16, 0.62, 0.66),
	]
	for feather in feathers.size():
		var lean := float(feather - 2) * 0.17
		_rod(
			figure, frame, Vector3(-0.50, 0.12, 0.0), Vector3(-0.78, 0.70 - absf(lean) * 0.4, lean),
			0.06, 0.02, feathers[feather], 4
		)
	for side: float in [-1.0, 1.0]:
		_rod(figure, frame, Vector3(0.1 * side, -0.68, side * 0.12), Vector3(0.1 * side + 0.16, -0.72, side * 0.12), 0.03, 0.025, yellow, 4)

## A horse in the middle of a prance: the body round and level, the neck arched
## up from the chest and the head tucked in, one foreleg folded up and the other
## reaching down, the hind legs under it. A gold bridle, a mane and tail in a
## second colour, and gold hooves.
func _draw_horse(figure: SurfaceTool, frame: Transform3D, coat: Color, mane: Color) -> void:
	var gold := GOLD
	var muzzle := coat.lerp(Color(1.0, 0.76, 0.78), 0.45)
	_rod(figure, frame, Vector3(-0.52, 0.02, 0.0), Vector3(0.46, 0.04, 0.0), 0.24, 0.24, coat, 8)
	_ball(figure, frame, Vector3(-0.52, 0.02, 0.0), Vector3.ONE * 0.245, coat)
	_ball(figure, frame, Vector3(0.46, 0.04, 0.0), Vector3.ONE * 0.245, coat)
	# The neck, in two pieces so that it arches, and the head tilted down from it.
	_rod(figure, frame, Vector3(0.48, 0.14, 0.0), Vector3(0.72, 0.50, 0.0), 0.19, 0.14, coat, 6)
	_rod(figure, frame, Vector3(0.72, 0.50, 0.0), Vector3(0.82, 0.76, 0.0), 0.14, 0.115, coat, 6)
	_ball(figure, frame, Vector3(0.82, 0.78, 0.0), Vector3.ONE * 0.12, coat)
	_rod(figure, frame, Vector3(0.84, 0.80, 0.0), Vector3(1.08, 0.62, 0.0), 0.115, 0.075, coat, 6)
	_ball(figure, frame, Vector3(1.09, 0.62, 0.0), Vector3(0.085, 0.08, 0.075), muzzle)
	for side: float in [-1.0, 1.0]:
		_ball(figure, frame, Vector3(0.93, 0.80, side * 0.1), Vector3.ONE * 0.03, DARK_EYE)
		_rod(figure, frame, Vector3(0.80, 0.88, side * 0.06), Vector3(0.77, 1.03, side * 0.07), 0.045, 0.012, coat, 4)
		# The bridle: a cheek strap either side, and a jewel where they meet.
		_rod(figure, frame, Vector3(0.87, 0.86, side * 0.105), Vector3(1.03, 0.65, side * 0.09), 0.015, 0.015, gold, 4)
	_ball(figure, frame, Vector3(0.95, 0.77, 0.115), Vector3.ONE * 0.04, gold)
	_ball(figure, frame, Vector3(0.95, 0.77, -0.115), Vector3.ONE * 0.04, gold)
	_rod(figure, frame, Vector3(0.99, 0.69, 0.0), Vector3(1.03, 0.665, 0.0), 0.098, 0.088, gold, 8)
	# A jewelled plate on the chest.
	_ball(figure, frame, Vector3(0.66, 0.16, 0.0), Vector3.ONE * 0.07, gold)
	# The mane, a row of tufts down the back of the neck, and a forelock.
	# Each tuft is rooted on the neck's own back, found from the neck's two pieces
	# above rather than guessed, so that it grows from the neck and not beside it.
	for tuft in 6:
		var along := float(tuft) / 5.0
		var centre := Vector3(0.48, 0.14, 0.0).lerp(Vector3(0.72, 0.5, 0.0), 0.08 + along * 0.9) \
			if along < 0.65 else Vector3(0.72, 0.5, 0.0).lerp(Vector3(0.82, 0.76, 0.0), (along - 0.65) / 0.35)
		var thickness := lerpf(0.18, 0.12, along)
		var spot := centre + Vector3(-thickness * 0.85, thickness * 0.45, 0.0)
		_rod(figure, frame, spot, spot + Vector3(-0.06, -0.12, 0.0), 0.085, 0.03, mane, 4)
	_rod(figure, frame, Vector3(0.88, 0.90, 0.0), Vector3(0.99, 0.78, 0.0), 0.05, 0.02, mane, 4)
	# The tail, in two pieces, streaming back and down.
	_rod(figure, frame, Vector3(-0.68, 0.12, 0.0), Vector3(-0.80, -0.06, 0.0), 0.07, 0.065, mane, 5)
	_rod(figure, frame, Vector3(-0.80, -0.06, 0.0), Vector3(-0.83, -0.50, 0.0), 0.065, 0.025, mane, 5)
	# The hind legs: thigh, hock, cannon and a gold hoof, standing.
	for side: float in [-0.14, 0.14]:
		_rod(figure, frame, Vector3(-0.44, -0.06, side), Vector3(-0.62, -0.38, side), 0.12, 0.075, coat, 6)
		_rod(figure, frame, Vector3(-0.62, -0.38, side), Vector3(-0.54, -0.64, side), 0.06, 0.045, coat, 5)
		_rod(figure, frame, Vector3(-0.54, -0.64, side), Vector3(-0.51, -0.74, side), 0.06, 0.07, gold, 5)
	# The forelegs: the near one folded up in the prance, the far one reaching
	# for the ground.
	_rod(figure, frame, Vector3(0.42, -0.06, -0.14), Vector3(0.66, -0.16, -0.14), 0.10, 0.07, coat, 6)
	_rod(figure, frame, Vector3(0.66, -0.16, -0.14), Vector3(0.52, -0.34, -0.14), 0.065, 0.045, coat, 5)
	_rod(figure, frame, Vector3(0.52, -0.34, -0.14), Vector3(0.48, -0.42, -0.14), 0.06, 0.07, gold, 5)
	_rod(figure, frame, Vector3(0.42, -0.06, 0.14), Vector3(0.58, -0.36, 0.14), 0.10, 0.07, coat, 6)
	_rod(figure, frame, Vector3(0.58, -0.36, 0.14), Vector3(0.64, -0.62, 0.14), 0.06, 0.045, coat, 5)
	_rod(figure, frame, Vector3(0.64, -0.62, 0.14), Vector3(0.66, -0.72, 0.14), 0.06, 0.07, gold, 5)

## The saddle: a leather seat, like every other saddle in the game, on a cloth
## of the animal's own colour with a gold hem, and a gilded cantle behind. Long
## enough to sit behind the brass pole, which stands in the middle of it and goes
## up through the roof: the child's hips are 0.18 behind it, so the saddle runs
## 0.39 back from the pole and the cantle after. `top` is the top of the seat
## above the middle of the body.
func _saddle(figure: SurfaceTool, frame: Transform3D, top: float, cloth: Color) -> void:
	# The cloth first: on the back under the seat, and draped down each side.
	_block(figure, frame, Vector3(-0.07, top - 0.115, 0.0), Vector3(0.7, 0.03, 0.46), cloth)
	for side: float in [-1.0, 1.0]:
		_block(figure, frame, Vector3(-0.07, top - 0.23, side * 0.235), Vector3(0.6, 0.2, 0.025), cloth)
		_block(figure, frame, Vector3(-0.07, top - 0.34, side * 0.235), Vector3(0.6, 0.03, 0.03), GOLD)
	_block(
		figure, frame, Vector3(-0.07, top - 0.05, 0.0), Vector3(0.64, 0.1, 0.4),
		ShopStock.colour(ShopStock.SADDLE)
	)
	_block(figure, frame, Vector3(-0.35, top + 0.03, 0.0), Vector3(0.08, 0.18, 0.4), GOLD)

## A box in an animal's own frame, `tilt` turning it about its own middle.
static func _block(
	tool: SurfaceTool, frame: Transform3D, at: Vector3, size: Vector3, colour: Color,
	tilt := Basis()
) -> void:
	var box := BoxMesh.new()
	box.size = size
	Park._add(tool, box, Transform3D(frame.basis * tilt, frame * at), colour)

## An ellipsoid in an animal's own frame, `scale` its three radii.
static func _ball(
	tool: SurfaceTool, frame: Transform3D, at: Vector3, scale: Vector3, colour: Color,
	tilt := Basis()
) -> void:
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 8
	ball.rings = 4
	Park._add(tool, ball, Transform3D(frame.basis * tilt * Basis.from_scale(scale), frame * at), colour)

## A rod from one point to another, thicker at one end than the other: the
## stuff of necks, legs, rails and ribs. Few sides, so that it stays a low-poly
## limb and not a pipe.
static func _strut(
	tool: SurfaceTool, from: Vector3, to: Vector3, r_from: float, r_to: float, colour: Color,
	sides := 6
) -> void:
	var along := to - from
	var length := along.length()
	if length < 0.001:
		return
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = r_from
	mesh.top_radius = r_to
	mesh.height = length
	mesh.radial_segments = sides
	mesh.rings = 1
	# A basis whose y runs along the rod; which way its x goes does not matter.
	var up := along / length
	var across := up.cross(Vector3.FORWARD)
	if across.length() < 0.1:
		across = up.cross(Vector3.RIGHT)
	across = across.normalized()
	Park._add(tool, mesh, Transform3D(Basis(across, up, across.cross(up)), (from + to) * 0.5), colour)

## The same, between two points of an animal's own frame.
static func _rod(
	tool: SurfaceTool, frame: Transform3D, from: Vector3, to: Vector3, r_from: float,
	r_to: float, colour: Color, sides := 6
) -> void:
	_strut(tool, frame * from, frame * to, r_from, r_to, colour, sides)

## A flat four-cornered piece, wound so that its front is the side `outward`
## points to. Only the one side is drawn; call it twice for a piece that is seen
## from both.
static func _quad(
	tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3,
	colour: Color
) -> void:
	# Godot's front faces wind clockwise, so the right-handed normal of one
	# points away from whoever sees it.
	var corners: Array[Vector3] = [a, b, c, a, c, d]
	if (b - a).cross(c - a).dot(outward) > 0.0:
		corners = [a, d, c, a, c, b]
	for corner in corners:
		tool.set_color(colour)
		tool.add_vertex(corner)

## A strip of the skin of a cylinder about the vertical axis, between two angles
## and two heights, in `steps` flat facets.
static func _arc_strip(
	tool: SurfaceTool, radius: float, from_angle: float, to_angle: float, low: float,
	high: float, colour: Color, steps := 4
) -> void:
	for step in steps:
		var a := lerpf(from_angle, to_angle, float(step) / float(steps))
		var b := lerpf(from_angle, to_angle, float(step + 1) / float(steps))
		var middle := (a + b) * 0.5
		_quad(
			tool,
			Vector3(cos(a) * radius, low, sin(a) * radius), Vector3(cos(b) * radius, low, sin(b) * radius),
			Vector3(cos(b) * radius, high, sin(b) * radius), Vector3(cos(a) * radius, high, sin(a) * radius),
			Vector3(cos(middle), 0.0, sin(middle)), colour
		)

## A shape turned about the vertical axis: `profile` is (radius, height) points
## walked from the bottom outwards and up, over the edge and inwards across the
## top, so that the outside is on the walker's right; `colours` has one for each
## stretch between two points.
static func _lathe(tool: SurfaceTool, profile: Array[Vector2], colours: Array[Color], facets: int) -> void:
	for index in profile.size() - 1:
		var from := profile[index]
		var to := profile[index + 1]
		for facet in facets:
			var a := TAU * float(facet) / float(facets)
			var b := TAU * float(facet + 1) / float(facets)
			var middle := (a + b) * 0.5
			_quad(
				tool,
				Vector3(cos(a) * from.x, from.y, sin(a) * from.x), Vector3(cos(b) * from.x, from.y, sin(b) * from.x),
				Vector3(cos(b) * to.x, to.y, sin(b) * to.x), Vector3(cos(a) * to.x, to.y, sin(a) * to.x),
				Vector3(cos(middle) * (to.y - from.y), from.x - to.x, sin(middle) * (to.y - from.y)),
				colours[index]
			)

## The deck, drawn as one turned shape so that it can be round: a plinth that
## swells into a rounded skirt, the deck's own edge, and a painted top in rings of
## red and gold. It is all one skin, so nothing in it can fight over a pixel with
## anything else. The collider is the disc of the deck, whose top is the top
## drawn here.
func _build_deck(turning: SurfaceTool) -> void:
	var under := FLOOR_HEIGHT - DECK_THICKNESS * 0.5
	var top := FLOOR_HEIGHT + DECK_THICKNESS * 0.5
	var red := Color(0.78, 0.24, 0.26)
	var cream := Color(0.98, 0.93, 0.80)
	var profile: Array[Vector2] = [
		Vector2(RADIUS * 0.92, 0.0), Vector2(RADIUS * 0.96, 0.09), Vector2(RADIUS * 0.985, 0.2),
		Vector2(RADIUS, 0.31), Vector2(RADIUS * 0.99, 0.39), Vector2(RADIUS * 0.975, under),
		Vector2(RADIUS, under), Vector2(RADIUS, top),
	]
	var colours: Array[Color] = [red, red, TRIM, TRIM, TRIM.darkened(0.2), TRIM.darkened(0.2), cream]
	# The painted top, from the rim inwards.
	var rings: Array[Array] = [
		[RADIUS - 0.35, TRIM], [RADIUS - 0.45, cream], [4.65, FLOOR_COLOUR], [4.55, TRIM],
		[3.35, FLOOR_COLOUR], [3.25, TRIM], [1.45, FLOOR_COLOUR], [1.3, TRIM],
		[0.9, FLOOR_COLOUR],
	]
	for ring in rings:
		profile.append(Vector2(ring[0], top))
		colours.append(ring[1])
	_lathe(turning, profile, colours, 32)

## The scalloped valance that hangs from the canopy's eave, alternately red and
## cream, edged in gold, with a bulb at the bottom of each scallop: the thing that
## says "carousel" from across the fairground before anyone is close enough to see
## the horses at all. Each bulb is drawn twice: once as paint, and once, a hair
## bigger and in a mesh of its own, as the glow that comes up at dusk (see `glow`).
func _build_valance(
	turning: SurfaceTool, glowing: SurfaceTool, roof_base: Vector3, rim: float
) -> void:
	var scallops := 24
	var steps := 6
	var edge := rim - 0.03
	var drop := 0.34
	for scallop in scallops:
		var from_angle := TAU * float(scallop) / float(scallops)
		var to_angle := TAU * float(scallop + 1) / float(scallops)
		var colour := VALANCE_A if scallop % 2 == 0 else VALANCE_B
		var last_top := Vector3.ZERO
		var last_low := Vector3.ZERO
		for step in steps + 1:
			var t := float(step) / float(steps)
			var angle := lerpf(from_angle, to_angle, t)
			var out := Vector3(cos(angle), 0.0, sin(angle))
			var hang := out * edge + Vector3(0.0, roof_base.y, 0.0)
			var low := hang - Vector3(0.0, 0.05 + drop * sin(PI * t), 0.0)
			if step > 0:
				var middle := lerpf(from_angle, to_angle, (float(step) - 0.5) / float(steps))
				var facing := Vector3(cos(middle), 0.0, sin(middle))
				var piping := Vector3(0.0, -0.045, 0.0)
				for side: float in [1.0, -1.0]:
					_quad(turning, last_top, hang, low, last_low, facing * side, colour)
					_quad(turning, last_low, low, low + piping, last_low + piping, facing * side, GOLD)
			last_top = hang
			last_low = low
		var middle_angle := (from_angle + to_angle) * 0.5
		var bulb_mesh := SphereMesh.new()
		bulb_mesh.radius = 0.09
		bulb_mesh.height = 0.18
		bulb_mesh.radial_segments = 8
		bulb_mesh.rings = 5
		var bulb_at := Transform3D(
			Basis(),
			Vector3(cos(middle_angle), 0.0, sin(middle_angle)) * edge
				+ Vector3(0.0, roof_base.y - 0.05 - drop - 0.05, 0.0)
		)
		var bulb_colour := Color(1.0, 0.92, 0.55) if scallop % 2 == 0 else Color(0.98, 0.70, 0.30)
		Park._add(turning, bulb_mesh, bulb_at, bulb_colour)
		var lit_mesh := SphereMesh.new()
		lit_mesh.radius = 0.115
		lit_mesh.height = 0.23
		lit_mesh.radial_segments = 8
		lit_mesh.rings = 5
		Park._add(glowing, lit_mesh, bulb_at, bulb_colour)

## The top of the roof: a gold rib down each seam of the stripes and a gold
## ring round the rim, then a little blue cupola with a gold cap, a ball for a
## finial, a spire and a pink pennant on it.
func _build_roof_top(turning: SurfaceTool, apex: Vector3, base: Vector3, rim: float) -> void:
	var lift := Vector3(0.0, 0.03, 0.0)
	var last := Vector3.ZERO
	for seam in 13:
		var angle := TAU * float(seam) / 12.0
		var at := base + Vector3(cos(angle), 0.0, sin(angle)) * rim + lift
		if seam < 12:
			_strut(turning, apex + lift, at, 0.035, 0.035, GOLD, 4)
		if seam > 0:
			_strut(turning, last, at, 0.04, 0.04, GOLD, 4)
		last = at
	var cupola := CylinderMesh.new()
	cupola.top_radius = 0.5
	cupola.bottom_radius = 0.58
	cupola.height = 0.5
	cupola.radial_segments = 12
	cupola.rings = 1
	Park._add(turning, cupola, Transform3D(Basis(), apex + Vector3(0.0, 0.0, 0.0)), Color(0.52, 0.74, 0.92))
	var cap := CylinderMesh.new()
	cap.top_radius = 0.0
	cap.bottom_radius = 0.7
	cap.height = 0.5
	cap.radial_segments = 12
	cap.rings = 1
	Park._add(turning, cap, Transform3D(Basis(), apex + Vector3(0.0, 0.5, 0.0)), GOLD)
	var finial := SphereMesh.new()
	finial.radius = 0.14
	finial.height = 0.28
	finial.radial_segments = 8
	finial.rings = 5
	Park._add(turning, finial, Transform3D(Basis(), apex + Vector3(0.0, 0.8, 0.0)), GOLD)
	_strut(turning, apex + Vector3(0.0, 0.85, 0.0), apex + Vector3(0.0, 1.75, 0.0), 0.03, 0.012, GOLD, 5)
	var tip := apex + Vector3(0.0, 1.75, 0.0)
	for side: float in [1.0, -1.0]:
		_quad(
			turning, tip, tip + Vector3(0.0, -0.5, 0.0), tip + Vector3(1.2, -0.25, 0.0),
			tip + Vector3(1.2, -0.25, 0.0), Vector3(0.0, 0.0, side), PENNANT
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
