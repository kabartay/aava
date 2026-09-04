class_name Mounts
extends Node3D

## The horse that waits in the valley, and the bicycle once it is bought.
##
## Both are one node holding a mesh and a position. Riding is not a physics
## problem here: the player keeps its own body and the mount follows it, which
## avoids the whole class of bugs where a character controller is parented to a
## moving object and inherits its rotation.
##
## The horse stands where the world puts it and stays there until ridden. The
## bicycle appears at the camp once bought, because a bicycle that spawns
## wherever you happened to be standing feels like a cheat rather than a thing
## you own.

signal mounted(kind: StringName)
signal dismounted(kind: StringName)

## How close you must be to get on.
const REACH := 3.2

var field: HeightField
var riding := &""

var _nodes: Dictionary = {}
var _positions: Dictionary = {}

func _init(height_field: HeightField) -> void:
	field = height_field

## Put a mount into the world. Called for the horse at the start, and for the
## bicycle when it is bought.
func place(kind: StringName, at: Vector3) -> void:
	if _nodes.has(kind):
		var existing: Node3D = _nodes[kind]
		if is_instance_valid(existing):
			existing.queue_free()

	var node := MeshInstance3D.new()
	node.mesh = MountKinds.build_mesh(kind)
	add_child(node)
	var grounded := at
	grounded.y = field.height_at(at.x, at.z)
	node.global_position = grounded
	_nodes[kind] = node
	_positions[kind] = grounded

func exists(kind: StringName) -> bool:
	return _nodes.has(kind) and is_instance_valid(_nodes[kind])

func position_of(kind: StringName) -> Vector3:
	return _positions.get(kind, Vector3.ZERO)

## The mount within reach, or an empty name. Never returns one already ridden.
func nearest(player_position: Vector3) -> StringName:
	if riding != &"":
		return &""
	var best := &""
	var best_distance := REACH
	for kind in _nodes:
		if not is_instance_valid(_nodes[kind]):
			continue
		var flat: Vector3 = _positions[kind] - player_position
		flat.y = 0.0
		var distance := flat.length()
		if distance < best_distance:
			best_distance = distance
			best = kind
	return best

func mount(kind: StringName) -> bool:
	if riding != &"" or not exists(kind):
		return false
	riding = kind
	# Hidden rather than removed: the same node is put back down on dismount, so
	# there is no chance of the world gaining a second horse.
	var node: Node3D = _nodes[kind]
	node.visible = false
	mounted.emit(kind)
	return true

## Get off. The mount is left standing where the player left it, which is how a
## child expects to find it again.
func dismount(at: Vector3) -> StringName:
	if riding == &"":
		return &""
	var kind := riding
	riding = &""
	var node: Node3D = _nodes[kind]
	if is_instance_valid(node):
		var spot := at
		spot.y = field.height_at(spot.x, spot.z)
		node.global_position = spot
		node.visible = true
		_positions[kind] = spot
	dismounted.emit(kind)
	return kind

## Whether the ground here can be ridden over on the current mount. A bicycle
## refuses a steep hill and deep water; a horse takes both.
func can_ride_over(kind: StringName, at: Vector3) -> bool:
	if MountKinds.fords_water(kind):
		return field.steepness_at(at.x, at.z) <= MountKinds.max_slope(kind)
	if at.y < HeightField.WATER_LEVEL + 0.4:
		return false
	return field.steepness_at(at.x, at.z) <= MountKinds.max_slope(kind)

func to_data() -> Dictionary:
	var out: Dictionary = {}
	for kind in _positions:
		var at: Vector3 = _positions[kind]
		out[String(kind)] = [at.x, at.y, at.z]
	return out

func from_data(data: Dictionary) -> void:
	for key in data:
		var entry = data[key]
		if entry is Array and entry.size() >= 3:
			place(
				StringName(key),
				Vector3(float(entry[0]), float(entry[1]), float(entry[2]))
			)
