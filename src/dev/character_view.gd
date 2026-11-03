extends SceneTree

## The five characters in a row, without building the world.
##
##   godot --path . --resolution 1280x720 --script src/dev/character_view.gd -- \
##         --out=row.png [--from=5] [--yaw=0] [--skin=0] [--hair=1] [--shirt=2] \
##         [--focus=1] [--lean=1]
##
## `--from` is the camera's distance in metres (5 is the distance a child is
## judged from); `--yaw` turns the row about the vertical (180 shows the
## backs); `--focus=N` shows only character N, close, and `--lean=1` swings
## the joints a little so that it is plain each one hangs from the right place.

var _out := "characters.png"
var _from := 5.0
var _yaw := 0.0
var _skin := 0
var _hair := 1
var _shirt := 2
var _focus := -1
var _frames := 0

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		var parts := argument.split("=", true, 1)
		if parts.size() != 2:
			continue
		match parts[0].lstrip("-"):
			"out": _out = parts[1]
			"from": _from = parts[1].to_float()
			"yaw": _yaw = parts[1].to_float()
			"skin": _skin = parts[1].to_int()
			"hair": _hair = parts[1].to_int()
			"shirt": _shirt = parts[1].to_int()
			"focus": _focus = parts[1].to_int()
	var root := get_root()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.62, 0.78, 0.92)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.68, 0.78)
	environment.ambient_light_energy = 0.8
	var world := WorldEnvironment.new()
	world.environment = environment
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	sun.light_energy = 1.1
	root.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30.0, 140.0, 0.0)
	fill.light_energy = 0.7
	root.add_child(fill)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40.0, 40.0)
	ground.mesh = plane
	var green := StandardMaterial3D.new()
	green.albedo_color = Color(0.40, 0.58, 0.28)
	ground.material_override = green
	root.add_child(ground)

	var shirt: Color = Visitors.SHIRTS[_shirt]
	var row := Node3D.new()
	row.rotation_degrees.y = _yaw
	root.add_child(row)
	var shown: Array = [0, 1, 2, 3, 4] if _focus < 0 else [_focus]
	var tool := Visitors.new()
	for i in shown.size():
		var which: int = shown[i]
		var figure: Node3D
		if Character.is_rigged(which):
			figure = Character.build(which, _skin, _hair, shirt)
		else:
			figure = MeshInstance3D.new()
			(figure as MeshInstance3D).mesh = tool._build_body(shirt, Character.SKINS[_skin])
		# Negative: the camera looks along +Z, so +X is on its left.
		figure.position.x = (float(shown.size() - 1) * 0.5 - float(i)) * 1.1
		row.add_child(figure)
		var triangles := 0
		var stack: Array[Node] = [figure]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			stack.append_array(node.get_children())
			if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
				triangles += ((node as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() / 3
		print("%s: %d triangles" % [Character.KEYS[which], triangles])
	var camera := Camera3D.new()
	camera.fov = 45.0
	root.add_child(camera)
	var aim := Vector3(0.0, 0.75, 0.0)
	if _focus >= 0:
		aim = Vector3(0.0, 0.95, 0.0)
	camera.look_at_from_position(aim + Vector3(0.0, 0.35, -_from), aim)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 8:
		return false
	var image := get_root().get_texture().get_image()
	image.save_png(_out)
	print("written ", _out)
	quit()
	return true
