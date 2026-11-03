extends SceneTree

## Close-up sheet of one animal, from four sides, without building the world.
##
##   godot --path . --resolution 1280x720 --script src/dev/animal_view.gd -- \
##         --kind=cow --variant=0 --out=cow.png [--head=1]
##
## `--kind` is any animal, or `horse`, or `drake` or `hen` for the ducks.
##
## The world takes minutes to build and an animal is a metre across, so judging
## the shape of one is done here: a plain meadow, the sun, and the real
## `build_node` seen side on, from three-quarters, from the front and from
## behind (or, with --head=1, close on the head).

var _kind := "cow"
var _variant := 0
var _out := "animal.png"
var _head := false
var _camera: Camera3D
var _views: Array = []
var _shot := 0
var _frames := 0
var _sheet: Image
var _centre := Vector3.ZERO

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		var parts := argument.split("=", true, 1)
		if parts.size() != 2:
			continue
		match parts[0].lstrip("-"):
			"kind": _kind = parts[1]
			"variant": _variant = parts[1].to_int()
			"out": _out = parts[1]
			"head": _head = parts[1].to_int() != 0
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
	# A weaker light from the other side, so the side nearest the camera is
	# not always in shadow.
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
	var animal: Node3D
	var size := 1.0
	match _kind:
		"horse":
			# Not one of the valley's animals but a mount, seen the same way.
			animal = MountKinds.build_node(MountKinds.horse_id(_variant))
			size = 1.3
		"drake", "hen":
			# A duck is a mesh of its own, a third of a metre long.
			var ducks := Ducks.new()
			animal = MeshInstance3D.new()
			(animal as MeshInstance3D).mesh = ducks._build(_kind == "drake")
			size = 0.25
		_:
			animal = AnimalKinds.build_node(StringName(_kind), _variant)
			size = AnimalKinds.size_of(StringName(_kind))
	root.add_child(animal)
	var triangles := 0
	var stack: Array[Node] = [animal]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			triangles += ((node as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() / 3
	print("%s: %d triangles" % [_kind, triangles])
	_centre = Vector3(0.0, size * 1.0, 0.0)
	var far := size * 6.5
	var near := size * 5.0
	if _head:
		var pivot := MountKinds.HORSE_HEAD_PIVOT if _kind == "horse" else (
			Vector3(0.0, 0.2, -0.2) if size == 0.25 else AnimalKinds.head_pivot(StringName(_kind))
		)
		_centre = pivot + Vector3(0.0, size * 0.3, 0.0)
		far = size * 3.2
		near = size * 3.2
	# The animal faces -Z: the side is +X, the front -Z.
	_views = [
		_centre + Vector3(far, 0.0, 0.0),
		_centre + Vector3(near * 0.7, near * 0.25, -near * 0.7),
		_centre + Vector3(0.0, near * 0.1, -far),
		_centre + Vector3(-near * 0.7, near * 0.3, near * 0.7),
	]
	_camera = Camera3D.new()
	_camera.fov = 45.0
	root.add_child(_camera)
	_sheet = Image.create(1280, 720, false, Image.FORMAT_RGB8)

func _place() -> void:
	_camera.position = _views[_shot]
	_camera.look_at(_centre)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_place()
	if _frames % 6 != 0:
		return false
	var image := get_root().get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	image.resize(640, 360)
	_sheet.blit_rect(image, Rect2i(0, 0, 640, 360), Vector2i((_shot % 2) * 640, (_shot / 2) * 360))
	_shot += 1
	if _shot >= _views.size():
		_sheet.save_png(_out)
		print("written ", _out)
		quit()
		return true
	_place()
	return false
