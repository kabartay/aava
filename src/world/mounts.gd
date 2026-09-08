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

## Put a mount into the world. Called for the horse and the boats at the
## start, and for the bicycle when it is bought. `kind` is a mount id — see
## MountKinds.kind_of. `facing` turns it, for a boat pointed out at the water.
func place(kind: StringName, at: Vector3, facing := 0.0) -> void:
	if _nodes.has(kind):
		var existing: Node3D = _nodes[kind]
		if is_instance_valid(existing):
			existing.queue_free()

	var node := MeshInstance3D.new()
	node.mesh = MountKinds.build_mesh(kind)
	add_child(node)
	var grounded := at
	grounded.y = _rest_height(kind, at)
	node.global_position = grounded
	node.rotation.y = facing
	_nodes[kind] = node
	_positions[kind] = grounded

## Where a mount rests: on the ground, or, for a boat, on the water wherever
## the ground is under it. A boat left in the shallows sat on the bed with
## its hull half under, until this.
func _rest_height(kind: StringName, at: Vector3) -> float:
	var ground := field.height_at(at.x, at.z)
	if MountKinds.floats(kind):
		return maxf(ground, HeightField.WATER_LEVEL)
	return ground

## Launch `count` boats round the shore of a pond, each where the water is
## about `depth` deep — wading depth, so a child walks out to one — and each
## pointed out across the water. The shore is found by walking out from the
## middle of the pond along each bearing until the bed comes up to the depth.
func launch_boats(pond: int, count: int, depth := 0.7) -> void:
	var offset := pond * Lakes.POND_STRIDE
	var centre := Vector3(Lakes.PONDS[offset], 0.0, Lakes.PONDS[offset + 1])
	var reach := Lakes.PONDS[offset + 2] * (1.0 + Lakes.WOBBLE) + 4.0
	for i in count:
		var bearing := TAU * float(i) / float(count) + 0.4
		var direction := Vector3(cos(bearing), 0.0, sin(bearing))
		var spot := centre
		var walked := 0.5
		while walked < reach:
			var probe := centre + direction * walked
			if field.height_at(probe.x, probe.z) > HeightField.WATER_LEVEL - depth:
				break
			spot = probe
			walked += 0.5
		# Facing the middle of the pond: rotation about Y that sends -Z to
		# -direction.
		place(MountKinds.boat_id(i), spot, atan2(direction.x, direction.z))

## How many boats there are. For the checks.
func boat_count() -> int:
	var count := 0
	for kind in _nodes:
		if MountKinds.boat_index(kind) >= 0 and is_instance_valid(_nodes[kind]):
			count += 1
	return count

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
	# The mount stays visible and is carried along under the child. Hiding it
	# was the first version, on the reasoning that the player "becomes" the
	# horse — but the child's own body is still drawn, so what a rider actually
	# saw was the horse vanishing and themselves running very fast.
	mounted.emit(kind)
	return true

## Carry the mount along under the rider. Called every frame while riding.
##
## The mount follows rather than the player being parented to it, for the same
## reason as everywhere else here: a body parented to a moving node inherits its
## rotation and fights its own gravity.
func carry(at: Vector3, facing: float) -> void:
	if riding == &"" or not exists(riding):
		return
	var node: Node3D = _nodes[riding]
	var spot := at
	spot.y = _rest_height(riding, at)
	node.global_position = spot
	node.rotation.y = facing
	_positions[riding] = spot

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
		spot.y = _rest_height(kind, at)
		node.global_position = spot
		_positions[kind] = spot
	dismounted.emit(kind)
	return kind

## Whether the ground here can be ridden over on the current mount. A bicycle
## refuses a steep hill and deep water; a horse takes both; a boat wants
## water under its keel and nothing else — which is how it puts a child down
## on the far shore.
func can_ride_over(kind: StringName, at: Vector3) -> bool:
	if MountKinds.floats(kind):
		return field.height_at(at.x, at.z) < HeightField.WATER_LEVEL - MountKinds.BOAT_DRAFT
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
