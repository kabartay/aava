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
signal removed(kind: StringName, world_position: Vector3)
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
		var kind: StringName = record["kind"]
		var other_footprint := (
			HouseParts.footprint(kind) if HouseParts.is_house_part(kind)
			else BuildKinds.footprint(kind)
		)
		# Different storeys never conflict: a wall upstairs stands directly over
		# the wall below it, and that is the whole point of building upwards.
		if absf(other.y - world_position.y) > HouseParts.STOREY * 0.5:
			continue
		var minimum := radius + other_footprint
		if Vector2(other.x - world_position.x, other.z - world_position.z).length() < minimum * 0.5:
			return false
	return true

## The ground level the nearest house parts were built on, or INF if there are
## none close enough.
##
## This is what makes a building level. The first piece takes its height from
## the ground; every piece placed beside it takes its height from that first
## one, so a house stays flat even where the meadow does not.
func nearby_datum(world_position: Vector3, reach: float) -> float:
	var best := INF
	var best_distance := reach
	for record in _records:
		if not HouseParts.is_house_part(record["kind"]):
			continue
		var at: Vector3 = record["position"]
		var distance := Vector2(at.x - world_position.x, at.z - world_position.z).length()
		if distance > best_distance:
			continue
		best_distance = distance
		# The storey the piece sits on is subtracted back out, so the answer is
		# always the level of the ground floor however high the piece was.
		best = at.y - HouseParts.snap_height(at.y - _ground_under(at))
	return best

func _ground_under(at: Vector3) -> float:
	return field.height_at(at.x, at.z)

## Where everything stands, for the map.
func positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for record in _records:
		out.append(record["position"])
	return out

## The piece nearest to a point, within reach, or an empty dictionary.
##
## Returned as a record rather than an index because indices shift the moment
## anything is removed, and a stale index that quietly points at the wrong
## building is the sort of bug that eats an afternoon of someone's work.
func nearest(world_position: Vector3, reach: float) -> Dictionary:
	var best := {}
	var best_distance := reach
	for record in _records:
		var at: Vector3 = record["position"]
		var offset := at - world_position
		# Vertical distance counts for less, so standing under a first-floor
		# wall still lets you take it down.
		offset.y *= 0.6
		var distance := offset.length()
		if distance <= best_distance:
			best_distance = distance
			best = record
	return best

## Take a piece back down. Returns what it was, so the caller can refund it.
##
## Everything a child builds must be removable. Without that, a misplaced wall
## is permanent, and a child who has made one permanent mistake stops
## experimenting — which is the entire activity.
func remove(record: Dictionary) -> StringName:
	var index := _records.find(record)
	if index < 0:
		return &""
	var kind: StringName = record["kind"]
	var at: Vector3 = record["position"]
	var node: Node3D = record["node"]
	if is_instance_valid(node):
		node.queue_free()
	_records.remove_at(index)
	removed.emit(kind, at)
	_recompute_groves()
	return kind

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
	# Only the generated pieces grow. Asking BuildKinds about a house part is
	# asking a dictionary for a key it has never heard of, and the error is
	# raised once per piece placed — loud, but easy to lose in a busy log.
	if not BuildKinds.INFO.has(kind) or not BuildKinds.grows(kind):
		_recompute_groves()

func _spawn_node(record: Dictionary) -> void:
	var node := MeshInstance3D.new()
	var kind: StringName = record["kind"]
	node.mesh = (
		HouseParts.build_mesh(kind) if HouseParts.is_house_part(kind)
		else BuildKinds.build_mesh(kind, record["stage"])
	)
	node.material_override = _material
	node.transform = Transform3D(Basis(Vector3.UP, record["spin"]), record["position"])
	add_child(node)
	record["node"] = node

func _process(delta: float) -> void:
	var any_matured := false
	for record in _records:
		if not BuildKinds.INFO.has(record["kind"]) or not BuildKinds.grows(record["kind"]):
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
		if BuildKinds.INFO.has(record["kind"]) and BuildKinds.grows(record["kind"]) and record["stage"] >= BuildKinds.GROWTH_STAGES - 1:
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
		if not BuildKinds.INFO.has(kind) and not HouseParts.is_house_part(kind):
			continue
		var record := {
			"kind": kind,
			"position": Vector3(entry.get("x", 0.0), entry.get("y", 0.0), entry.get("z", 0.0)),
			"spin": float(entry.get("spin", 0.0)),
			"age": float(entry.get("age", 0.0)),
			"stage": 0,
			"node": null,
		}
		if BuildKinds.INFO.has(kind) and BuildKinds.grows(kind):
			record["stage"] = mini(
				int(float(record["age"]) / BuildKinds.GROWTH_STAGE_SECONDS),
				BuildKinds.GROWTH_STAGES - 1
			)
		_records.append(record)
		_spawn_node(record)
	_recompute_groves()
