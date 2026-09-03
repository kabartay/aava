class_name Structures
extends Node3D

## Everything the player has built, and what it has since become.
##
## This is where the promise of the game is actually kept: a sapling planted
## here grows on its own, and when three of them come up close together the
## world notices and answers. Without that, building is decoration.

## How close two mature trees must be to count as the same grove, and how many
## it takes before the place becomes one.
const GROVE_RADIUS := 15.0
const GROVE_MINIMUM := 3

signal placed(kind: StringName, world_position: Vector3)
signal matured(kind: StringName, world_position: Vector3)
signal groves_changed(centres: Array)

var field: HeightField

var _records: Array[Dictionary] = []
var _material: StandardMaterial3D
var _grove_centres: Array = []

func _init(height_field: HeightField) -> void:
	field = height_field
	# Built here, not in _ready: headless checks place structures without ever
	# starting the tree.
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	# Same reasoning as the terrain: the colours were picked as sRGB values.
	_material.vertex_color_is_srgb = true
	_material.roughness = 0.9

## True when nothing already stands close enough to overlap. Checked before
## placing so two saplings cannot occupy the same metre of ground.
func is_clear(world_position: Vector3, radius: float) -> bool:
	for record in _records:
		var other: Vector3 = record["position"]
		var minimum := radius + BuildKinds.footprint(record["kind"])
		if Vector2(other.x - world_position.x, other.z - world_position.z).length() < minimum * 0.5:
			return false
	return true

func place(kind: StringName, world_position: Vector3, spin: float) -> void:
	var record := {
		"kind": kind,
		"position": world_position,
		"spin": spin,
		"age": 0.0,
		"stage": 0,
		"node": null,
	}
	_records.append(record)
	_spawn_node(record)
	placed.emit(kind, world_position)
	if not BuildKinds.grows(kind):
		_recompute_groves()

func _spawn_node(record: Dictionary) -> void:
	var node := MeshInstance3D.new()
	node.mesh = BuildKinds.build_mesh(record["kind"], record["stage"])
	node.material_override = _material
	node.transform = Transform3D(Basis(Vector3.UP, record["spin"]), record["position"])
	add_child(node)
	record["node"] = node

func _process(delta: float) -> void:
	var any_matured := false
	for record in _records:
		if not BuildKinds.grows(record["kind"]):
			continue
		if record["stage"] >= BuildKinds.GROWTH_STAGES - 1:
			continue
		record["age"] = float(record["age"]) + delta
		var stage := mini(
			int(float(record["age"]) / BuildKinds.GROWTH_STAGE_SECONDS),
			BuildKinds.GROWTH_STAGES - 1
		)
		if stage == record["stage"]:
			continue
		record["stage"] = stage
		# The node is replaced rather than re-meshed so that growth is a single
		# visible event, and so a save reloaded at any stage takes the same path.
		var node: Node3D = record["node"]
		if is_instance_valid(node):
			node.queue_free()
		_spawn_node(record)
		if stage >= BuildKinds.GROWTH_STAGES - 1:
			matured.emit(record["kind"], record["position"])
			any_matured = true
	if any_matured:
		_recompute_groves()

## Where the world has been changed enough to answer: finished feeders, and the
## centre of every cluster of grown trees.
func attract_points() -> Array:
	var points: Array = []
	for record in _records:
		if record["kind"] == BuildKinds.FEEDER:
			points.append(record["position"] + Vector3.UP * 1.9)
	for centre in _grove_centres:
		points.append(centre)
	return points

func grove_count() -> int:
	return _grove_centres.size()

## Greedy clustering: walk the grown trees, and for each one not yet spoken for,
## gather everything within a grove's reach. Good enough for the handful of
## trees a child plants, and it never disagrees with itself between frames.
func _recompute_groves() -> void:
	var grown: Array[Vector3] = []
	for record in _records:
		if BuildKinds.grows(record["kind"]) and record["stage"] >= BuildKinds.GROWTH_STAGES - 1:
			grown.append(record["position"])

	var claimed := {}
	var centres: Array = []
	for i in grown.size():
		if claimed.has(i):
			continue
		var cluster: Array[int] = [i]
		for j in range(i + 1, grown.size()):
			if claimed.has(j):
				continue
			if grown[i].distance_to(grown[j]) <= GROVE_RADIUS:
				cluster.append(j)
		if cluster.size() < GROVE_MINIMUM:
			continue
		var sum := Vector3.ZERO
		for index in cluster:
			claimed[index] = true
			sum += grown[index]
		var centre: Vector3 = sum / float(cluster.size())
		centres.append(centre + Vector3.UP * 4.5)

	if centres.size() != _grove_centres.size():
		_grove_centres = centres
		groves_changed.emit(_grove_centres)
	else:
		_grove_centres = centres

func to_data() -> Array:
	var data: Array = []
	for record in _records:
		var at: Vector3 = record["position"]
		data.append({
			"kind": String(record["kind"]),
			"x": at.x, "y": at.y, "z": at.z,
			"spin": record["spin"],
			"age": record["age"],
		})
	return data

func from_data(data: Array) -> void:
	for record in _records:
		var node: Node3D = record["node"]
		if is_instance_valid(node):
			node.queue_free()
	_records.clear()

	for entry in data:
		var kind := StringName(entry.get("kind", ""))
		if not BuildKinds.INFO.has(kind):
			continue
		var record := {
			"kind": kind,
			"position": Vector3(entry.get("x", 0.0), entry.get("y", 0.0), entry.get("z", 0.0)),
			"spin": float(entry.get("spin", 0.0)),
			"age": float(entry.get("age", 0.0)),
			"stage": 0,
			"node": null,
		}
		if BuildKinds.grows(kind):
			record["stage"] = mini(
				int(float(record["age"]) / BuildKinds.GROWTH_STAGE_SECONDS),
				BuildKinds.GROWTH_STAGES - 1
			)
		_records.append(record)
		_spawn_node(record)
	_recompute_groves()
