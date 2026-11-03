extends SceneTree

## The five characters in a row, without building the world.
##
##   godot --path . --resolution 1280x720 --script src/dev/character_view.gd -- \
##         --out=row.png [--from=5] [--yaw=0] [--skin=0] [--hair=1] [--shirt=2] \
##         [--focus=1] [--lean=1] [--pose=walk|run|kick|swim|dive|jump|cheer]
##
## `--pose` drives each figure through RigMotion and stops it mid-motion (the
## kick is shown just after the ball leaves, at the peak of the swing);
## `--extra=N` runs N more frames first, to catch another moment of a stride.
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
var _pose := ""
## `--mount=horse|bicycle|motorcycle|quad|boat` sits the figure on that machine,
## and `--ride=carousel|wheel|coaster|drop_tower|pirate_ship|swing` on that ride,
## each as the game draws it; `--gait=` is how fast it is going (metres a
## second), `--aim=` the height looked at, `--seatno=` which seat of a ride.
var _mount := ""
var _ride := ""
var _gait := 0.0
var _aim := -1.0
var _seat_no := 0
## `--lift=` raises the camera above what it looks at, to see over a wall.
var _lift := 0.35
var _extra := 0
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
			"pose": _pose = parts[1]
			"mount": _mount = parts[1]
			"ride": _ride = parts[1]
			"gait": _gait = parts[1].to_float()
			"aim": _aim = parts[1].to_float()
			"seatno": _seat_no = parts[1].to_int()
			"lift": _lift = parts[1].to_float()
			"extra": _extra = parts[1].to_int()

## Built on the first frame and not in `_initialize`, where the root is not yet
## in the tree and a ride has no global transform to give a seat.
func _build() -> void:
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
	# A ride is looked at from its seat, which is at the origin: the ground goes
	# well below it rather than through the child.
	if _ride != "":
		ground.position.y = -12.0

	var shirt: Color = Visitors.SHIRTS[_shirt]
	var row := Node3D.new()
	row.rotation_degrees.y = _yaw
	root.add_child(row)
	var shown: Array = [0, 1, 2, 3, 4] if _focus < 0 else [_focus]
	# A ride is built as the game builds it, and the world is moved so that the
	# seat being looked at is at the origin, under the camera's gaze.
	var rides := Node3D.new()
	row.add_child(rides)
	if _ride != "":
		var found := _build_ride(rides)
		rides.position = -(row.global_transform.affine_inverse() * found.origin)
		_ride_place = (
			Transform3D(row.global_transform.basis * found.basis, Vector3.ZERO)
			if _ride == "swing" else _seat_of_ride(_ride_node)
		)
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
		if _mount != "":
			var steed := MountKinds.build_node(StringName(_mount))
			steed.position.x = figure.position.x
			row.add_child(steed)
			figure.position.y = MountKinds.eye_lift(StringName(_mount))
		if _ride != "":
			figure.position.x = 0.0
			rides.add_child(figure)
		else:
			row.add_child(figure)
		if _pose != "" or _mount != "" or _ride != "":
			_strike(figure)
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
	if _aim >= 0.0:
		aim = Vector3(0.0, _aim, 0.0)
	camera.look_at_from_position(aim + Vector3(0.0, _lift, -_from), aim)

var _ride_node: Node3D
var _ride_place := Transform3D()

## Build the ride asked for under `parent`, and say where the seat is (before
## the world is moved to put it at the origin).
func _build_ride(parent: Node3D) -> Transform3D:
	match _ride:
		"carousel": _ride_node = Carousel.new(Vector3.ZERO)
		"wheel": _ride_node = FerrisWheel.new(Vector3.ZERO)
		"coaster": _ride_node = RollerCoaster.new(Vector3.ZERO)
		"drop_tower": _ride_node = DropTower.new(Vector3.ZERO)
		"pirate_ship": _ride_node = PirateShip.new(Vector3.ZERO)
		_: _ride_node = Node3D.new()
	parent.add_child(_ride_node)
	return _seat_of_ride(_ride_node)

func _seat_of_ride(ride: Node3D) -> Transform3D:
	match _ride:
		"carousel": return (ride as Carousel).saddles()[_seat_no]
		"wheel": return (ride as FerrisWheel).seat_of(_seat_no)
		"coaster": return (ride as RollerCoaster).seat_of(_seat_no)
		"drop_tower": return (ride as DropTower).seats()[_seat_no]
		"pirate_ship": return (ride as PirateShip).seats()[_seat_no]
	# The swing: a seat on its chains, with the bar 2.75 above.
	var bar := Node3D.new()
	ride.add_child(bar)
	var rope := Node3D.new()
	rope.position = Vector3(0.0, 3.72, 0.0)
	bar.add_child(rope)
	for side: float in [-0.34, 0.34]:
		var chain := MeshInstance3D.new()
		var tube := CylinderMesh.new()
		tube.top_radius = 0.02
		tube.bottom_radius = 0.02
		tube.height = 2.75
		chain.mesh = tube
		chain.position = Vector3(side, -1.375, 0.0)
		rope.add_child(chain)
	var slab := MeshInstance3D.new()
	var board := BoxMesh.new()
	board.size = Vector3(0.88, 0.06, 0.30)
	slab.mesh = board
	slab.position = Vector3(0.0, 3.72 - 2.75 + 0.02, 0.0)
	bar.add_child(slab)
	return Transform3D(Basis(), Vector3(0.0, 3.72 - 2.75 + 0.05, 0.0))

## Put a figure in the middle of a motion: it is driven for a second of
## frames, as the game would, and stopped where the pose is interesting.
func _strike(figure: Node3D) -> void:
	var motion := RigMotion.new(figure)
	var frame := 1.0 / 60.0
	if _mount != "":
		motion.seat = MountKinds.kind_of(StringName(_mount))
		motion.riding = true
		motion.gait = _gait
	if _ride != "":
		motion.seat = StringName(_ride)
		motion.riding = true
		motion.seat_placed = true
		motion.seat_place = _ride_place
	match _pose:
		"walk": motion.speed = 3.4
		"run": motion.speed = 6.6
		"swim":
			motion.swimming = true
			motion.speed = 2.0
		"dive":
			motion.swimming = true
			motion.diving = true
		"jump": motion.airborne = true
		"cheer": motion.cheer()
		"kick":
			motion.winding = true
			motion.charge = 1.0
	for _step in 70 + _extra:
		motion.step(frame)
	if _pose == "kick":
		# The release, and then a few frames on: the foot at the peak, and just past.
		motion.winding = false
		motion.kick()
		for _step in 4:
			motion.step(frame)
	if _ride != "":
		print("rig ", figure.global_position, " hips ", (figure.find_child("Hips", true, false) as Node3D).global_position, " head ", (figure.find_child("Head", true, false) as Node3D).global_position, " ride ", _ride_node.global_position, " rides ", figure.get_parent().global_position)
	if _pose == "swim" or _pose == "dive":
		figure.rotation.x = -(Player.DIVE_LEAN if _pose == "dive" else Player.SWIM_LEAN)
		figure.position.y = 0.5

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_build()
	if _frames < 10:
		return false
	var image := get_root().get_texture().get_image()
	image.save_png(_out)
	print("written ", _out)
	quit()
	return true
