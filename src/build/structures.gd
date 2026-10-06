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

## Whether what is built now also exists in somebody else's valley — true while
## a game together is open. Set by the game.
##
## Two marks ride on every piece because two valleys are not one valley. The
## other phone's world was never sent here, so a removal that arrives from it
## names a *place*, and the only pieces it may take down are ones both phones
## have: built by either child while they were playing together. Matched by
## position alone, a brother taking down one of his own old walls took down
## whatever wall stood in the same spot on this phone — a house part snaps to
## a grid, so the same spot is likely — and the next autosave made it
## permanent.
var sharing := false

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

## Where everything a child has planted stands, as opposed to everything they
## have built. The map draws the two in different colours: a grove of your own
## trees and a house you raised are both yours, but they are not the same
## answer to "what is that yellow patch".
func planted() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for record in _records:
		if BuildKinds.is_plant(record["kind"]):
			out.append(record["position"])
	return out

## Where every piece of one kind stands. Used by the fires, which need to know
## which of the things a child has built are campfires.
func positions_of(kind: StringName) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for record in _records:
		if record["kind"] == kind:
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

## The nearest piece that also stands in the other child's valley, or an empty
## record. The only kind of piece a removal from the other phone may touch.
func nearest_shared(world_position: Vector3, reach: float) -> Dictionary:
	var best := {}
	var best_distance := reach
	for record in _records:
		if not bool(record.get("shared", false)):
			continue
		var offset: Vector3 = record["position"] - world_position
		offset.y *= 0.6
		var distance := offset.length()
		if distance <= best_distance:
			best_distance = distance
			best = record
	return best

## The game together is over: from now on nothing here is in anyone else's
## valley, including what was built while it lasted. Kept per session rather
## than saved, because the next game may be with a different brother whose
## valley has none of it.
func stop_sharing() -> void:
	sharing = false
	for record in _records:
		record["shared"] = false

## The nearest tree a child planted that has finished growing, or an empty
## record. A sapling is not one: a young tree is taken back with the hands in
## build mode and the seed comes back, and an axe taken to something the height
## of a boot is not felling.
func nearest_grown_tree(world_position: Vector3, reach: float) -> Dictionary:
	var best := {}
	var best_distance := reach
	for record in _records:
		var kind: StringName = record["kind"]
		if not BuildKinds.INFO.has(kind) or not BuildKinds.grows(kind):
			continue
		if int(record["stage"]) < BuildKinds.GROWTH_STAGES - 1:
			continue
		var offset: Vector3 = record["position"] - world_position
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

## `paid` is false for a piece that arrived from the other phone: it was built
## out of the other child's bag, and taking it down must not hand this child
## materials they never spent.
func place(kind: StringName, world_position: Vector3, spin: float, paid := true) -> void:
	var record := {
		"kind": kind,
		"position": world_position,
		"spin": spin,
		"age": 0.0,
		"stage": 0,
		"node": null,
		# Something from the other phone is shared by definition; something
		# built here is shared if there is anyone to share it with.
		"shared": sharing or not paid,
		"paid": paid,
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
	if HouseParts.is_house_part(kind) and HouseParts.is_solid(kind):
		HouseParts.add_collision(node, kind)
	add_child(node)
	record["node"] = node

## Age everything by the time that passed while the game was closed, so a child
## who plants a sapling on Monday finds a tree on Tuesday. Capped, because a
## fortnight away should not mean the growth was missed entirely — the point is
## to be greeted by a change, not to have skipped it.
const MAX_OFFLINE_GROWTH := 900.0

func advance_offline(seconds: float) -> int:
	var granted := minf(maxf(seconds, 0.0), MAX_OFFLINE_GROWTH)
	if granted <= 0.0:
		return 0
	var advanced := 0
	for record in _records:
		if not BuildKinds.INFO.has(record["kind"]) or not BuildKinds.grows(record["kind"]):
			continue
		if record["stage"] >= BuildKinds.GROWTH_STAGES - 1:
			continue
		record["age"] = float(record["age"]) + granted
		advanced += 1
	# _process does the actual re-spawning on the next frame, so the visible
	# change happens through exactly one code path rather than two.
	return advanced

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
			"paid": bool(record.get("paid", true)),
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
			"shared": false,
			# Everything saved before this mark existed was built by this child.
			"paid": bool(entry.get("paid", true)),
		}
		if BuildKinds.INFO.has(kind) and BuildKinds.grows(kind):
			record["stage"] = mini(
				int(float(record["age"]) / BuildKinds.GROWTH_STAGE_SECONDS),
				BuildKinds.GROWTH_STAGES - 1
			)
		_records.append(record)
	_move_out_of_places()
	for record in _records:
		_spawn_node(record)
	_recompute_groves()

## Anything standing on ground that now belongs to something else — a place,
## the football pitch, the fairground, the crossing, the signs — is moved to
## the nearest ground outside it and set down there. Moved, not removed: the
## tree a child planted is still their tree, only no longer in the trampoline
## or in front of the big wheel.
##
## This runs on every load, so a rule made today reaches valleys built before
## it. That is the whole point: the planting rule and this one are the same
## rule, and a tree planted on the fairground the week before the rule existed
## was still standing there afterwards.
## Returns how many were moved.
func _move_out_of_places() -> int:
	var camp := field.camp_centre()
	var river_x := field.river_centre_x(BridgeSpec.CENTRE_Z)
	var moved := 0
	for record in _records:
		var at: Vector3 = record["position"]
		if not KeepOut.kept(at.x, at.z, camp, river_x):
			continue
		var free := KeepOut.nearest_free(at.x, at.z, camp, river_x)
		record["position"] = Vector3(
			free.x, field.height_at(free.x, free.y), free.y
		)
		moved += 1
	return moved
