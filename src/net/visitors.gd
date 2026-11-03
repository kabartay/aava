class_name Visitors
extends Node3D

## The other children, drawn where they are standing.
##
## A visitor is a mesh and a name, not a physics body. They are told where to be
## twelve times a second and glide between those points; giving them a character
## controller would mean simulating someone else's movement locally and then
## disagreeing with the machine that actually knows.
##
## The name floats above them because that is the whole point of seeing someone
## in your valley — knowing which brother it is. It faces the camera, since a
## label seen edge-on is no label at all.

## How quickly a visitor catches up to the last position that arrived. Fast
## enough not to lag visibly behind, slow enough that a dropped packet reads as
## a stride rather than a jump.
const SMOOTHING := 12.0

## The shirts a child can choose from, and the fallback for anyone who has not.
##
## The plain colours by name — red is red — so that "I am the blue one" is a
## thing a six-year-old can say and be right about. Black and white are pulled
## a little off the ends of the range: a pure black shirt disappears entirely
## in a valley at night, and a pure white one blows out to a flat shape in
## sunlight, and in both cases what a child loses is the person they were
## looking for.
const SHIRTS: Array[Color] = [
	Color8(220, 50, 47),
	Color8(60, 180, 75),
	Color8(60, 110, 220),
	Color8(240, 200, 50),
	Color8(245, 150, 40),
	Color8(150, 70, 190),
	Color8(245, 160, 190),
	Color8(60, 200, 210),
	Color8(40, 40, 46),
	Color8(238, 238, 240),
	Color8(140, 140, 146),
	# Burgundy. Dark enough to be its own colour beside the red and not a
	# shade of it, light enough that it is still a colour at dusk rather than
	# a second black — which is the same line the black and white are drawn
	# just inside of, for the same reason.
	Color8(142, 32, 58),
]

## What the shirts are called, so a child picks "blue" and not a swatch.
## New colours go on the end of both lists and nowhere else: a child's choice
## is saved as a position in them, and inserting one in the middle would hand
## every brother a different shirt the next time they opened the game.
const SHIRT_NAMES: Array[StringName] = [
	&"red", &"green", &"blue", &"yellow", &"orange",
	&"purple", &"pink", &"cyan", &"black", &"white", &"grey",
	&"burgundy",
]

var _visitors: Dictionary = {}

## Asked where a visitor stands: is that a seat on a ride, and which (see
## Main._seat_at). Left unset, nobody sits on a ride. Which ride a child is on is
## known from where they are, so nothing about it is sent.
var seat_finder := Callable()

## Where somebody was said to be before they had been announced. Positions are
## unreliable and names are reliable, so the first position can overtake the
## name that introduces it; dropped, a visitor who stands still (a host reading
## out the number) is drawn at the world's origin until they next move. Kept
## to a handful so a peer that never introduces itself cannot make it grow.
const MAX_EARLY := 8
var _early: Dictionary = {}

## `chose` is the shirt that child picked for themselves, or -1 if they are
## playing on a version that never asked them. `look` is who they chose to be,
## [character, skin, hair] (see Character.clean), or empty for a version that
## never asked that either: those children are the simple figure.
func add(id: int, who: String, chose := -1, look := []) -> void:
	if _visitors.has(id):
		return
	var shirt := shirt_for(id, chose)
	var wearing := Character.clean(look)

	var body := _make_body(who, shirt, wearing)
	add_child(body)

	_visitors[id] = {
		"node": body, "wanted": Vector3.ZERO, "facing": 0.0, "seen": false,
		"shirt": shirt, "look": wearing, "motion": _motion_for(body),
		"code": 0, "code_age": 0.0, "idle": 0.0, "swim_w": 0.0, "swim_tip": 0.0,
	}
	if _early.has(id):
		var told: Array = _early[id]
		_early.erase(id)
		move(id, told[0], told[1], told[2])

## Which shirt to draw somebody in.
##
## Their own choice, when they have made one. Failing that, one keyed off the
## peer id rather than off how many are already here — the count goes down when
## somebody leaves, so the next to join took a colour already being worn, and
## arrival order differs per machine, so a brother was green on one phone and
## orange on the other.
func shirt_for(id: int, chose: int) -> Color:
	if chose >= 0 and chose < SHIRTS.size():
		return SHIRTS[chose]
	# Everyone else's shirt, and deliberately not this child's own. Counting
	# their current colour as taken meant that asking again — which is what
	# happens when they type their name, because the name and the shirt travel
	# together — was guaranteed to hand back a different one, and a brother
	# changed colour every time he renamed himself.
	var worn := {}
	for other_id: int in _visitors:
		if other_id == id:
			continue
		worn[_visitors[other_id]["shirt"]] = true
	for step in SHIRTS.size():
		var candidate := SHIRTS[(absi(id) + step) % SHIRTS.size()]
		if not worn.has(candidate):
			return candidate
	return SHIRTS[absi(id) % SHIRTS.size()]

## What somebody is actually wearing, as opposed to what they would be given if
## they arrived now — those differ, because the second depends on who else is
## already here.
func shirt_of(id: int) -> Color:
	if not _visitors.has(id):
		return Color.BLACK
	return _visitors[id]["shirt"]

## Somebody changed their name, or their shirt, while standing in the valley.
## Whoever they are drawn as stays as it was.
func reshirt(id: int, chose: int) -> void:
	if _visitors.has(id):
		relook(id, chose, _visitors[id]["look"])

## Somebody changed their shirt, or who they are, while standing in the valley.
## The body is made again and put where the old one stood: a rig is a tree of
## joints and the simple figure is one mesh, so changing between the two means
## a different kind of node, not a different mesh on the same one.
func relook(id: int, chose: int, look: Array) -> void:
	if not _visitors.has(id):
		return
	var record: Dictionary = _visitors[id]
	var old: Node3D = record["node"]
	if not is_instance_valid(old):
		return
	var shirt := shirt_for(id, chose)
	var wearing := Character.clean(look)
	var who := ""
	for child in old.get_children():
		if child is Label3D:
			who = (child as Label3D).text
	var fresh := _make_body(who, shirt, wearing)
	fresh.position = old.position
	fresh.rotation = old.rotation
	add_child(fresh)
	old.queue_free()
	record["node"] = fresh
	record["motion"] = _motion_for(fresh)
	record["shirt"] = shirt
	record["look"] = wearing
	# Still in the saddle if they were riding when they changed.
	var riding: StringName = record.get("mount", &"")
	if riding != &"":
		record["mount"] = &""
		_ride(record, riding)

## What moves a body's joints, or null for a body that has none.
func _motion_for(body: Node3D) -> RigMotion:
	var rig := body.get_node_or_null("Rig") as Node3D
	return RigMotion.new(rig) if rig != null else null

## How somebody is moving, as Session.motion_code packs it: arrives with every
## position, and is trusted for a second at most (see MOTION_FRESH).
func moving(id: int, code: int) -> void:
	if _visitors.has(id):
		_visitors[id]["code"] = code & 127
		_visitors[id]["code_age"] = 0.0

## How somebody is being drawn moving. For the checks.
func motion_of(id: int) -> RigMotion:
	return _visitors[id].get("motion") if _visitors.has(id) else null

## Who somebody is drawn as, as the three numbers they chose. For the checks.
func look_of(id: int) -> Array:
	if not _visitors.has(id):
		return Character.clean([])
	return _visitors[id]["look"]

## How far above their own spot somebody sits: a rider in the saddle, as the
## player's own body is drawn, and a child on foot not at all.
func _lift_of(record: Dictionary) -> float:
	var riding: StringName = record.get("mount", &"")
	return MountKinds.eye_lift(riding) if riding != &"" else 0.0

## What somebody is riding, or empty. For the checks.
func mount_of(id: int) -> StringName:
	return _visitors[id].get("mount", &"") if _visitors.has(id) else &""

## Put somebody on a mount, or take them off. The mount is the same mesh the
## valley draws it as, and the rider is lifted into its saddle, so a child on a
## horse across the valley is on a horse and not running at sixteen metres a
## second. Nothing is rebuilt when it has not changed: this is asked of every
## position that arrives. Whoever they are drawn as is lifted: the simple
## figure's mesh is made again at the saddle's height, a rig is raised whole.
func _ride(record: Dictionary, mount: StringName) -> void:
	if record.get("mount", &"") == mount:
		return
	record["mount"] = mount
	var node: Node3D = record["node"]
	if not is_instance_valid(node):
		return
	var old := node.get_node_or_null("Mount")
	if old != null:
		node.remove_child(old)
		old.queue_free()
	var lift := _lift_of(record)
	if mount != &"":
		var steed := MountKinds.build_node(mount)
		steed.name = "Mount"
		node.add_child(steed)
	var look: Array = record.get("look", Character.clean([]))
	if node is MeshInstance3D:
		(node as MeshInstance3D).mesh = _build_body(record["shirt"], Character.SKINS[look[1]], lift)
	else:
		var rig := node.get_node_or_null("Rig") as Node3D
		if rig != null:
			rig.position.y = lift
	for child in node.get_children():
		if child is Label3D:
			(child as Label3D).position.y = 2.15 + lift

## The body: the simple figure is one mesh with the name on it; the others are
## a rig, with the name on a node that carries it.
func _make_body(who: String, shirt: Color, look: Array) -> Node3D:
	var body: Node3D
	if Character.is_rigged(look[0]):
		body = Node3D.new()
		var rig := Character.build(look[0], look[1], look[2], shirt)
		rig.name = "Rig"
		body.add_child(rig)
	else:
		var simple := MeshInstance3D.new()
		simple.mesh = _build_body(shirt, Character.SKINS[look[1]])
		body = simple

	var label := Label3D.new()
	label.text = who
	label.font_size = 96
	label.pixel_size = 0.0022
	label.position = Vector3(0.0, 2.15, 0.0)
	# Always facing the reader, and drawn over the world: a name hidden behind a
	# tree is worse than no name, because it tells a child nobody is there.
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 18
	label.outline_modulate = Color(0.06, 0.08, 0.11, 0.85)
	body.add_child(label)
	return body

## Somebody changed their name while standing in the valley.
func rename(id: int, who: String) -> void:
	if not _visitors.has(id):
		return
	var node: Node3D = _visitors[id]["node"]
	if not is_instance_valid(node):
		return
	for child in node.get_children():
		if child is Label3D:
			(child as Label3D).text = who
			return

## How long a name stays lit after the last scrap of somebody's voice arrived.
## A packet is a twentieth of a second, so this rides over a lost one or two
## without flickering, and goes out soon after they let go.
const SPEAKING_FOR := 0.35
const SPEAKING_COLOUR := Color(1.0, 0.85, 0.3)

## Somebody's voice has just arrived: their name lights up, so a child can see
## which of the others is talking.
func speaking(id: int) -> void:
	if _visitors.has(id):
		_visitors[id]["speaking"] = SPEAKING_FOR

func is_speaking(id: int) -> bool:
	return _visitors.has(id) and float(_visitors[id].get("speaking", 0.0)) > 0.0

func remove(id: int) -> void:
	_early.erase(id)
	if not _visitors.has(id):
		return
	var node: Node3D = _visitors[id]["node"]
	if is_instance_valid(node):
		node.queue_free()
	_visitors.erase(id)

func clear() -> void:
	_early.clear()
	for id in _visitors.keys():
		remove(id)

func count() -> int:
	return _visitors.size()

## A position arrived from another machine.
func move(id: int, at: Vector3, facing: float, mount := &"") -> void:
	if not _visitors.has(id):
		if _early.has(id) or _early.size() < MAX_EARLY:
			_early[id] = [at, facing, mount]
		return
	var record: Dictionary = _visitors[id]
	_ride(record, mount)
	record["wanted"] = at
	record["facing"] = facing
	var node: Node3D = record["node"]
	# The first position is applied outright. Easing in from the origin would
	# send a visitor sprinting across the valley the moment they appeared.
	if not record["seen"]:
		record["seen"] = true
		node.position = at
		node.rotation.y = facing

func _process(delta: float) -> void:
	var weight := 1.0 - exp(-SMOOTHING * delta)
	# Where the camera is, for how often to animate. Infinite when there is
	# none (a headless check), which animates everybody every frame.
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var eye := camera.global_position if camera != null else Vector3(INF, INF, INF)
	for id in _visitors:
		var record: Dictionary = _visitors[id]
		var node: Node3D = record["node"]
		if not is_instance_valid(node):
			continue
		var lit := float(record.get("speaking", 0.0)) > 0.0
		record["speaking"] = maxf(float(record.get("speaking", 0.0)) - delta, 0.0)
		for child in node.get_children():
			if child is Label3D:
				(child as Label3D).modulate = SPEAKING_COLOUR if lit else Color.WHITE
				(child as Label3D).scale = Vector3.ONE * (1.3 if lit else 1.0)
		node.position = node.position.lerp(record["wanted"], weight)
		node.rotation.y = lerp_angle(node.rotation.y, float(record["facing"]), weight)
		var motion: RigMotion = record["motion"]
		if motion != null:
			_animate(record, motion, node, delta, eye)

## How often somebody is animated, by how far they are from the camera: every
## frame close by, and further off only as often as a stride can be told from
## the next. A far figure is a few pixels and a pose a tenth of a second old is
## the same pixels.
const NEAR_SQ := 25.0 * 25.0
const FAR_SQ := 60.0 * 60.0
const FAR_EVERY := 0.2
const MID_EVERY := 0.07

## How long a pace is believed without another message to say it still holds.
## A position is sent at least every twelfth of a second while moving, and the
## packets are unreliable: this rides over a few lost ones, and a pace whose
## "now stop" was the packet that was lost does not run on for ever.
const MOTION_FRESH := 1.0

func _animate(record: Dictionary, motion: RigMotion, node: Node3D, delta: float, eye: Vector3) -> void:
	var age: float = record["code_age"] + delta
	record["code_age"] = age
	var waited: float = record["idle"] + delta
	var gap := 0.0
	if eye.is_finite():
		var away := node.global_position.distance_squared_to(eye)
		gap = FAR_EVERY if away > FAR_SQ else (MID_EVERY if away > NEAR_SQ else 0.0)
	if waited < gap:
		record["idle"] = waited
		return
	record["idle"] = 0.0
	var code: int = record["code"]
	motion.speed = Session.motion_speed(code) if age < MOTION_FRESH else 0.0
	motion.swimming = code & 32 != 0
	motion.diving = code & 64 != 0
	var mount: StringName = record.get("mount", &"")
	motion.riding = mount != &""
	# Sitting: on a mount as the child's own body does; on a ride's seat when the
	# place they stand is one.
	if mount != &"":
		motion.seat = MountKinds.kind_of(mount)
		motion.seat_placed = false
		motion.gait = motion.speed
	else:
		var seated: Dictionary = seat_finder.call(node.global_position) if seat_finder.is_valid() else {}
		motion.seat = seated.get("pose", &"")
		motion.seat_placed = not seated.is_empty()
		motion.seat_place = seated.get("place", motion.seat_place)
		motion.gait = 0.0
		motion.riding = motion.seat != &""
	motion.step(minf(waited, 0.25))

	# In the water they sit low and lean over, as the child's own body does
	# (Player._settle_in_water): a position is where their collider is, and a
	# swimmer's is at the surface with the body drawn dropped to the chest.
	var before: float = record["swim_w"]
	var wanted := 1.0 if (motion.swimming and not motion.riding) else 0.0
	var now := move_toward(before, wanted, Player.SWIM_SETTLE * 0.5 * waited)
	if now > 0.0 or before > 0.0:
		record["swim_w"] = now
		var tip: float = record["swim_tip"]
		tip = lerpf(tip, (Player.DIVE_LEAN if motion.diving else Player.SWIM_LEAN) * now, 1.0 - exp(-Player.SWIM_SETTLE * waited))
		record["swim_tip"] = tip
		var rig := node.get_node_or_null("Rig") as Node3D
		if rig != null:
			rig.position.y = _lift_of(record) - Player.SWIM_SINK * now
			rig.rotation.x = -tip

## The same shape as the player, in a different shirt, so that seeing someone
## across the valley reads as "another child" and not as a different kind of
## creature.
func _build_body(shirt: Color, skin := Character.SKINS[0], lift := 0.0) -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Height and vertical offset copied from Player._build_visual() rather than
	# derived independently: a torso the full collision height tall (instead of
	# the shorter visible capsule the player actually draws), centred a sixth
	# higher than the player's is, swallowed the head sphere entirely and left
	# only the shirt-coloured torso visible — "red, no head, wrong size" was one
	# bug, not three.
	var torso := CapsuleMesh.new()
	torso.radius = Player.RADIUS
	torso.height = Player.HEIGHT * 0.66
	torso.radial_segments = 10
	torso.rings = 4
	_add(tool, torso, Transform3D(Basis(), Vector3(0.0, Player.HEIGHT * 0.33 + lift, 0.0)), shirt)

	var head := SphereMesh.new()
	head.radius = 0.21
	head.height = 0.42
	head.radial_segments = 10
	head.rings = 6
	_add(
		tool, head,
		Transform3D(Basis(), Vector3(0.0, Player.HEIGHT * 0.79 + lift, 0.0)),
		skin
	)

	var nose := CylinderMesh.new()
	nose.top_radius = 0.0
	nose.bottom_radius = 0.06
	nose.height = 0.14
	nose.radial_segments = 5
	_add(
		tool, nose,
		Transform3D(
			Basis(Vector3.RIGHT, deg_to_rad(-90.0)),
			Vector3(0.0, Player.HEIGHT * 0.79 + lift, -0.20)
		),
		skin
	)

	tool.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.82
	tool.set_material(material)
	return tool.commit()

static func _add(tool: SurfaceTool, source: PrimitiveMesh, transform: Transform3D, colour: Color) -> void:
	var arrays := source.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for i in vertices.size():
			tool.set_color(colour)
			tool.add_vertex(transform * vertices[i])
		return
	for i in indices.size():
		tool.set_color(colour)
		tool.add_vertex(transform * vertices[indices[i]])
