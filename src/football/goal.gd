class_name Goal
extends Node3D

## A goal: two posts, a crossbar, and netting.
##
## The frame is solid, so a shot can rattle off the post — which is most of the
## drama of shooting at anything. The netting is drawn but barely bounces: a
## ball that hits the net should drop dead inside the goal, and simulating cloth
## to achieve that would be absurd, so the back and sides are walls the ball
## loses nearly all its speed against.

const FRAME_COLOR := Color(0.97, 0.97, 0.98)
const NET_COLOR := Color(0.90, 0.93, 0.96)

## How much of the ball's speed survives the netting. Almost none.
const NET_BOUNCE := 0.04

var index: int

var _frame_material: StandardMaterial3D
var _net_material: StandardMaterial3D

func _init(goal_index: int, at: Vector3) -> void:
	index = goal_index
	position = at
	# Local -x always points out onto the pitch, whichever end this is.
	rotation.y = 0.0 if goal_index == 1 else PI

	_frame_material = StandardMaterial3D.new()
	_frame_material.albedo_color = FRAME_COLOR
	_frame_material.roughness = 0.45

	_net_material = StandardMaterial3D.new()
	_net_material.albedo_color = NET_COLOR
	_net_material.roughness = 0.9
	# The net reads as mesh rather than as a solid sheet, seen from either side.
	_net_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_net_material.albedo_color.a = 0.34
	_net_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var half := Pitch.GOAL_WIDTH * 0.5
	var depth := Pitch.GOAL_DEPTH

	# Front frame: the bit that gets hit.
	_post(Vector3(0.0, 0.0, -half), Pitch.GOAL_HEIGHT)
	_post(Vector3(0.0, 0.0, half), Pitch.GOAL_HEIGHT)
	_crossbar(Vector3(0.0, Pitch.GOAL_HEIGHT, 0.0), Pitch.GOAL_WIDTH, Vector3.FORWARD)

	# Back frame, lower, which the net hangs from.
	var back_height := Pitch.GOAL_HEIGHT * 0.62
	_post(Vector3(depth, 0.0, -half), back_height)
	_post(Vector3(depth, 0.0, half), back_height)
	_crossbar(Vector3(depth, back_height, 0.0), Pitch.GOAL_WIDTH, Vector3.FORWARD)

	# Netting, and the walls behind it.
	_net_panel(Vector3(depth * 0.5, back_height * 0.5, -half), Vector3(depth, back_height, 0.04))
	_net_panel(Vector3(depth * 0.5, back_height * 0.5, half), Vector3(depth, back_height, 0.04))
	_net_panel(Vector3(depth, back_height * 0.5, 0.0), Vector3(0.04, back_height, Pitch.GOAL_WIDTH))
	_net_panel(
		Vector3(depth * 0.5, (Pitch.GOAL_HEIGHT + back_height) * 0.5, 0.0),
		Vector3(depth, 0.04, Pitch.GOAL_WIDTH)
	)

func _post(at: Vector3, height: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = Pitch.POST_RADIUS
	mesh.bottom_radius = Pitch.POST_RADIUS
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1

	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _frame_material
	visual.position = at + Vector3.UP * height * 0.5
	add_child(visual)

	_solid(
		at + Vector3.UP * height * 0.5,
		Vector3(Pitch.POST_RADIUS * 2.0, height, Pitch.POST_RADIUS * 2.0),
		0.55
	)

func _crossbar(at: Vector3, width: float, _axis: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = Pitch.POST_RADIUS
	mesh.bottom_radius = Pitch.POST_RADIUS
	mesh.height = width
	mesh.radial_segments = 8
	mesh.rings = 1

	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _frame_material
	# A cylinder stands along its own y, so it has to be laid on its side.
	visual.rotation.x = deg_to_rad(90.0)
	visual.position = at
	add_child(visual)

	_solid(at, Vector3(Pitch.POST_RADIUS * 2.0, Pitch.POST_RADIUS * 2.0, width), 0.55)

func _net_panel(at: Vector3, size: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _net_material
	visual.position = at
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)

	_solid(at, size, NET_BOUNCE)

## One immovable slab of collision. Separate bodies per part rather than one
## compound shape, so the post can be springy and the net dead.
func _solid(at: Vector3, size: Vector3, bounce: float) -> void:
	var box := BoxShape3D.new()
	box.size = size

	var collider := CollisionShape3D.new()
	collider.shape = box

	var body := StaticBody3D.new()
	body.position = at
	var material := PhysicsMaterial.new()
	material.bounce = bounce
	material.friction = 0.7
	body.physics_material_override = material
	body.add_child(collider)
	add_child(body)
