class_name Goal
extends Node3D

## A goal: two posts, a crossbar, two struts sloping back to the ground, and
## a net of strings hung over them.
##
## The frame is solid, so a shot can rattle off the post — which is most of the
## drama of shooting at anything. The net is drawn as strings — a grid of
## them down the sloping back and across the triangular sides, the way a
## real net hangs — but barely bounces: a ball that hits it should drop dead
## inside the goal, and simulating cloth to achieve that would be absurd, so
## behind the strings the back and sides are walls the ball loses nearly all
## its speed against. The first goal drew the net as four translucent slabs
## on a boxy frame, and read as a glass cabinet.

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

	var half := Pitch.GOAL_WIDTH * 0.5
	var depth := Pitch.GOAL_DEPTH
	var height := Pitch.GOAL_HEIGHT

	# Front frame: the bit that gets hit.
	_post(Vector3(0.0, 0.0, -half), height)
	_post(Vector3(0.0, 0.0, half), height)
	_crossbar(Vector3(0.0, height, 0.0), Pitch.GOAL_WIDTH, Vector3.FORWARD)

	# Two struts from the top of each post down to the ground behind, and a
	# bar along the ground between them, which is what the net hangs over.
	var foot_y := 0.06
	var top_back := Vector3(0.0, height, 0.0)
	var ground_back := Vector3(depth, foot_y, 0.0)
	for side in PackedFloat32Array([-1.0, 1.0]):
		_strut(top_back + Vector3(0.0, 0.0, side * half), ground_back + Vector3(0.0, 0.0, side * half))
	_crossbar(ground_back, Pitch.GOAL_WIDTH, Vector3.FORWARD)

	_string_the_net(half, depth, height, foot_y)

	# What the ball meets behind the strings: the sloping back, the two sides,
	# all dead.
	var slope := ground_back - top_back
	var slope_length := slope.length()
	_solid_turned(
		(top_back + ground_back) * 0.5,
		Vector3(0.04, slope_length, Pitch.GOAL_WIDTH),
		Basis.looking_at(slope.normalized(), Vector3.RIGHT) * Basis(Vector3.RIGHT, PI * 0.5),
		NET_BOUNCE
	)
	for side in PackedFloat32Array([-1.0, 1.0]):
		_solid(Vector3(depth * 0.5, height * 0.5, side * half), Vector3(depth, height, 0.04), NET_BOUNCE)

## A strut from `from` to `to`, drawn and solid.
func _strut(from: Vector3, to: Vector3) -> void:
	var run := to - from
	var mesh := CylinderMesh.new()
	mesh.top_radius = Pitch.POST_RADIUS * 0.7
	mesh.bottom_radius = Pitch.POST_RADIUS * 0.7
	mesh.height = run.length()
	mesh.radial_segments = 8
	mesh.rings = 1
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _frame_material
	# A cylinder stands along its own Y; laid along the run.
	visual.transform = Transform3D(
		Basis.looking_at(run.normalized(), Vector3.RIGHT) * Basis(Vector3.RIGHT, PI * 0.5),
		from + run * 0.5
	)
	add_child(visual)

## The net: strings down the slope of the back and across it, and strings
## across and up each triangular side, all in one mesh.
func _string_the_net(half: float, depth: float, height: float, foot_y: float) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spacing := 0.3
	var thickness := 0.018
	var slope := Vector3(depth, foot_y - height, 0.0)
	var slope_length := slope.length()
	var along := Basis.looking_at(slope.normalized(), Vector3.RIGHT) * Basis(Vector3.RIGHT, PI * 0.5)
	var top_back := Vector3(0.0, height, 0.0)

	# Down the back, one string per span of width.
	var across_count := int(Pitch.GOAL_WIDTH / spacing)
	for k in across_count + 1:
		var z := -half + Pitch.GOAL_WIDTH * float(k) / float(across_count)
		_string(tool, Vector3(thickness, slope_length, thickness), along, top_back + slope * 0.5 + Vector3(0.0, 0.0, z))
	# Across the back, one string per span of the slope.
	var down_count := int(slope_length / spacing)
	for k in down_count + 1:
		var t := float(k) / float(down_count)
		_string(tool, Vector3(thickness, thickness, Pitch.GOAL_WIDTH), Basis(), top_back + slope * t)
	# The sides: strings back from the post to the strut, and up from the
	# ground to the strut.
	for side in PackedFloat32Array([-1.0, 1.0]):
		var z := side * half
		var rows := int(height / spacing)
		for k in range(1, rows):
			var y := height * float(k) / float(rows)
			var reach := depth * (1.0 - (y - foot_y) / (height - foot_y))
			_string(tool, Vector3(reach, thickness, thickness), Basis(), Vector3(reach * 0.5, y, z))
		var columns := int(depth / spacing)
		for k in range(1, columns + 1):
			var x := depth * float(k) / float(columns + 1)
			var tall := (height - foot_y) * (1.0 - x / depth)
			_string(tool, Vector3(thickness, tall, thickness), Basis(), Vector3(x, foot_y + tall * 0.5, z))

	tool.generate_normals()
	tool.set_material(_net_material)
	var net := MeshInstance3D.new()
	net.mesh = tool.commit()
	net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(net)

## One string of the net: a thin box, added to the tool.
static func _string(tool: SurfaceTool, size: Vector3, basis: Basis, centre: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = size
	var arrays := box.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var transform := Transform3D(basis, centre)
	for i in indices.size():
		tool.add_vertex(transform * vertices[indices[i]])

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

## One immovable slab of collision. Separate bodies per part rather than one
## compound shape, so the post can be springy and the net dead.
func _solid(at: Vector3, size: Vector3, bounce: float) -> void:
	_solid_turned(at, size, Basis(), bounce)

func _solid_turned(at: Vector3, size: Vector3, basis: Basis, bounce: float) -> void:
	var box := BoxShape3D.new()
	box.size = size

	var collider := CollisionShape3D.new()
	collider.shape = box

	var body := StaticBody3D.new()
	body.transform = Transform3D(basis, at)
	var material := PhysicsMaterial.new()
	material.bounce = bounce
	material.friction = 0.7
	body.physics_material_override = material
	body.add_child(collider)
	add_child(body)
