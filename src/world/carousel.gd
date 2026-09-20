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
var _turned := 0.0

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

	# The floor, and the step up onto it.
	var deck := CylinderMesh.new()
	deck.top_radius = RADIUS
	deck.bottom_radius = RADIUS
	deck.height = 0.22
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
	pad.height = 0.24
	var collider := CollisionShape3D.new()
	collider.shape = pad
	collider.position = Vector3(0.0, FLOOR_HEIGHT, 0.0)
	footing.add_child(collider)

	# The middle column, and the canopy over it: stripes, because a roundabout
	# without stripes is a platform.
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

	for wedge in 12:
		var roof := CylinderMesh.new()
		roof.top_radius = 0.0
		roof.bottom_radius = RADIUS + 0.4
		roof.height = 1.5
		roof.radial_segments = 12
		roof.rings = 1
		# One cone drawn twelve times would be twelve cones; instead each
		# wedge is a thin slice of colour laid over the last, which is how the
		# stripes are made without a texture.
		if wedge % 2 == 1:
			continue
		Park._add(
			turning, roof,
			Transform3D(
				Basis(Vector3.UP, TAU * float(wedge) / 12.0),
				Vector3(0.0, FLOOR_HEIGHT + CANOPY_HEIGHT + 0.55, 0.0)
			),
			CANOPY_A if wedge % 4 == 0 else CANOPY_B
		)

	# The horses: a body on a brass pole, facing the way round.
	for horse in HORSES:
		var angle := TAU * float(horse) / float(HORSES)
		var spot := Vector3(cos(angle), 0.0, sin(angle)) * (RADIUS * 0.66)
		var pole := CylinderMesh.new()
		pole.top_radius = 0.06
		pole.bottom_radius = 0.06
		pole.height = CANOPY_HEIGHT * 0.92
		pole.radial_segments = 8
		pole.rings = 1
		Park._add(
			turning, pole,
			Transform3D(Basis(), spot + Vector3(0.0, FLOOR_HEIGHT + CANOPY_HEIGHT * 0.46, 0.0)),
			POLE
		)
		var facing := Basis(Vector3.UP, -angle)
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
		var head := BoxMesh.new()
		head.size = Vector3(0.52, 0.30, 0.30)
		Park._add(
			turning, head,
			Transform3D(facing, ride_at + facing * Vector3(0.86, 0.66, 0.0)),
			MountKinds.HORSE_COATS[horse % MountKinds.HORSE_COATS.size()]
		)

	Park.commit(turning, _turntable, "Turning")
	Park.commit(still, self, "Still")

func _physics_process(delta: float) -> void:
	_turned = fmod(_turned + TURN_RATE * delta, TAU)
	_turntable.transform = Transform3D(Basis(Vector3.UP, _turned), Vector3.ZERO)

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

## How far round it has turned. For the checks.
func turned() -> float:
	return _turned
