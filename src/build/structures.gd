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
## The records still growing, found again whenever `revision` moves.
var _growing: Array[Dictionary] = []
var _growing_revision := -1

## Counts every change to what is standing, so a reader that copies the list —
## the map — can tell that its copy is still true without asking for another.
var revision := 0
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
##
## Told what is being placed, a house part is judged against other house parts
## by the place it takes on the grid rather than by distance: one wall per edge
## per storey, one floor per square per storey. Judged by distance, a wall on
## the edge of a square and the floor in it were a metre apart with two-metre
## footprints, and the floor was refused — so a room could not have both.
## Everything else, and a house part against everything else, is still judged
## by footprint.
func is_clear(
	world_position: Vector3, radius: float,
	kind := &"", spin := 0.0, extent := Vector2i.ONE
) -> bool:
	var layer := HouseParts.layer(kind)
	var keys: Array[Vector2i] = []
	if layer != &"":
		keys = HouseParts.keys_of(kind, world_position, spin, extent)
	for record in _records:
		var other: Vector3 = record["position"]
		var other_kind: StringName = record["kind"]
		# Stairs are climbed, so what is laid over them must leave the head
		# room: a floor straight above the stairs is a ceiling a child walks
		# into a third of the way up.
		if layer == &"floor" and _under_stairs(kind, world_position, other_kind, other, keys, record):
			return false
		# Different storeys never conflict: a wall upstairs stands directly over
		# the wall below it, and that is the whole point of building upwards.
		if absf(other.y - world_position.y) > HouseParts.STOREY * 0.5:
			continue
		var other_layer := HouseParts.layer(other_kind)
		if layer != &"" and other_layer != &"":
			if other_layer != layer:
				continue
			for key in _keys_of(record):
				if keys.has(key):
					return false
			continue
		var other_footprint := (
			HouseParts.footprint(other_kind) if HouseParts.is_house_part(other_kind)
			else BuildKinds.footprint(other_kind)
		)
		var minimum := radius + other_footprint
		if Vector2(other.x - world_position.x, other.z - world_position.z).length() < minimum * 0.5:
			return false
	return true

## Whether a floor or stairs at `at` and a record of the floor layer make a
## staircase with something over it: the one is stairs, and the other is a
## storey above it in the same square.
func _under_stairs(
	kind: StringName, at: Vector3, other_kind: StringName, other: Vector3,
	keys: Array[Vector2i], record: Dictionary
) -> bool:
	if HouseParts.layer(other_kind) != &"floor":
		return false
	if kind != HouseParts.STAIRS and other_kind != HouseParts.STAIRS:
		return false
	# The stairs are the lower of the two.
	var rise := -INF
	if kind == HouseParts.STAIRS:
		rise = other.y - at.y
	if other_kind == HouseParts.STAIRS:
		rise = maxf(rise, at.y - other.y)
	if rise < HouseParts.STOREY * 0.5 or rise > HouseParts.STOREY * 1.5:
		return false
	return _keys_of(record).any(func(key: Vector2i) -> bool: return keys.has(key))

## Whether something already built stands over these stairs, or a floor a
## storey above them.
func stairs_blocked_above(kind: StringName, at: Vector3, spin: float) -> bool:
	if HouseParts.layer(kind) != &"floor":
		return false
	var keys := HouseParts.keys_of(kind, at, spin)
	for record in _records:
		if _under_stairs(kind, at, record["kind"], record["position"], keys, record):
			return true
	return false

func _keys_of(record: Dictionary) -> Array[Vector2i]:
	return HouseParts.keys_of(
		record["kind"], record["position"], float(record["spin"]),
		record.get("extent", Vector2i.ONE)
	)

## The house pieces standing within `reach` of a point, measured across the
## ground. The build ghost outlines the ones it is about to join.
func house_pieces_near(world_position: Vector3, reach: float) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for record in _records:
		if not HouseParts.is_house_part(record["kind"]):
			continue
		var at: Vector3 = record["position"]
		if Vector2(at.x - world_position.x, at.z - world_position.z).length() <= reach:
			found.append(record)
	return found

## What a first house still wants next, for the line that tells a child who has
## never built one what to do: walls, then a floor, then a roof, then a bed.
## Empty when all four stand somewhere. It goes by what is standing, not by what
## was tapped last, so a house a child began on Monday is met on Tuesday with
## the step after the one they got to.
func house_step() -> StringName:
	var walls := false
	var boards := false
	var roof := false
	var bed := false
	for record in _records:
		var kind: StringName = record["kind"]
		walls = walls or HouseParts.layer(kind) == &"wall"
		boards = boards or kind == HouseParts.FLOOR
		roof = roof or HouseParts.is_roof(kind)
		bed = bed or kind == HouseParts.BED
	if not walls:
		return &"walls"
	if not boards:
		return &"floor"
	if not roof:
		return &"roof"
	if not bed:
		return &"bed"
	return &""

## Whether this record still stands — the undo button asks before taking back
## a piece that a tap may already have taken down.
func has(record: Dictionary) -> bool:
	return _records.has(record)

## Which storey a piece stands on, counting up from the ground under it.
func storey_of(record: Dictionary) -> int:
	var at: Vector3 = record["position"]
	return HouseParts.storey_of(at.y - field.height_at(at.x, at.z))

## The piece this child built, of this kind, in this square (x, z) on this
## storey, or an empty record if there is none — which is how a saved undo
## list finds its pieces again, since a record itself cannot be saved.
func find_own(kind: StringName, x: float, z: float, storey: int) -> Dictionary:
	for record in _records:
		if record["kind"] != kind or not bool(record.get("paid", true)):
			continue
		var at: Vector3 = record["position"]
		if absf(at.x - x) < 0.05 and absf(at.z - z) < 0.05 and storey_of(record) == storey:
			return record
	return {}

## Whether the piece of this kind at this exact spot was put up by this child.
## A tree that matures pays its reward to whoever planted it: asked of the
## growth signal, which carries only a kind and a place, so that a sapling
## adopted from the host's valley, or one the other child planted, does not pay
## a second purse as well as the first.
func is_own_at(kind: StringName, world_position: Vector3) -> bool:
	for record in _records:
		if record["kind"] == kind and bool(record.get("paid", true)) \
				and (record["position"] as Vector3).is_equal_approx(world_position):
			return true
	return false

## Everything that stands on a piece and would hang in the air without it, the
## highest first, and without the piece itself:
##
## - the wall a storey up, on the wall (and the one above that);
## - the roofs and the chimney on a wall's top, unless some other wall or post
##   still holds them up — taking out one wall for a door does not take the
##   roof off;
## - what is on a floor: the bed, the table, the chair, the rug, the lamp.
##
## Found again through what is found, so a roof on a wall on a wall comes too.
func standing_on(record: Dictionary) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if not has(record):
		return found
	var gone: Array[Dictionary] = [record]
	var next := 0
	while next < gone.size():
		var base := gone[next]
		next += 1
		for other in _records:
			if gone.has(other) or not _rests_on(other, base, gone):
				continue
			gone.append(other)
			found.append(other)
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["position"] as Vector3).y > (b["position"] as Vector3).y)
	return found

## Whether `upper` stands on `base`, given that everything in `gone` is being
## taken down with it.
func _rests_on(upper: Dictionary, base: Dictionary, gone: Array[Dictionary]) -> bool:
	var base_kind: StringName = base["kind"]
	var upper_kind: StringName = upper["kind"]
	var base_layer := HouseParts.layer(base_kind)
	var upper_layer := HouseParts.layer(upper_kind)
	if base_layer == &"" or upper_layer == &"":
		return false
	var low: Vector3 = base["position"]
	var high: Vector3 = upper["position"]
	var rise := high.y - low.y
	if base_layer == &"wall" or base_layer == &"post":
		if upper_layer == base_layer:
			return (
				absf(rise - HouseParts.STOREY) < HouseParts.STOREY * 0.25
				and HouseParts.key_of(high) == HouseParts.key_of(low)
			)
		var is_upstairs_floor := (
			upper_kind == HouseParts.FLOOR
			and high.y - field.height_at(high.x, high.z) > HouseParts.STOREY * 0.625
		)
		if HouseParts.is_roof(upper_kind) or upper_kind == HouseParts.CHIMNEY or is_upstairs_floor:
			# A floor a storey up is laid on the tops of the walls below, the
			# same as a roof is; only one on the ground (see _carries) is a
			# drawing on the grass that nothing holds up.
			var top := low.y + HouseParts.height(base_kind)
			return (
				absf(high.y - top) < 0.1 and _covers(upper, HouseParts.key_of(low))
				and not _held_up_otherwise(upper, gone)
			)
		return false
	if base_layer == &"floor":
		# On the boards: a hand's breadth above the floor, in its square.
		var furnishing := upper_layer == &"furniture" or upper_layer == &"seat" or upper_layer == &"rug"
		return (
			furnishing and rise > 0.05 and rise < HouseParts.STOREY * 0.5
			and HouseParts.key_of(high) == HouseParts.key_of(low)
		)
	return false

## Whether a roof, or a chimney, is over the wall or post at this grid point:
## in the square beside it or on the square it covers.
func _covers(roof: Dictionary, wall_key: Vector2i) -> bool:
	for key in _keys_of(roof):
		var offset := key - wall_key
		if absi(offset.x) <= 1 and absi(offset.y) <= 1:
			return true
	return false

## Whether a wall or a post that is not going down holds a roof at its height.
func _held_up_otherwise(roof: Dictionary, gone: Array[Dictionary]) -> bool:
	var level := float((roof["position"] as Vector3).y)
	for record in _records:
		var layer := HouseParts.layer(record["kind"])
		if (layer != &"wall" and layer != &"post") or gone.has(record):
			continue
		var at: Vector3 = record["position"]
		if (
			absf(at.y + HouseParts.height(record["kind"]) - level) < 0.1
			and _covers(roof, HouseParts.key_of(at))
		):
			return true
	return false

## What a standing piece cost, so it can be given back exactly: a whole roof
## cost every square it covers.
static func cost_of(record: Dictionary) -> Dictionary:
	var kind: StringName = record.get("kind", &"")
	if HouseParts.is_house_part(kind):
		var extent: Vector2i = record.get("extent", Vector2i.ONE)
		return HouseParts.cost_for(kind, extent.x * extent.y)
	if BuildKinds.INFO.has(kind):
		return BuildKinds.cost(kind)
	return {}

## The lowest storey, from `from` up, with no piece of this layer on this grid
## point. Storeys are counted from the house's floor level.
##
## This is how a wall goes on top of a wall: a child taps the same edge again,
## and the next storey is the first one free there. Choosing the storey by how
## high the child was standing meant climbing onto the walls to build on them.
func free_storey(layer: StringName, key: Vector2i, floor_level: float, from: int) -> int:
	var taken := {}
	for record in _records:
		if HouseParts.layer(record["kind"]) != layer:
			continue
		if not _keys_of(record).has(key):
			continue
		var at: Vector3 = record["position"]
		var level := roundi((at.y - floor_level) / HouseParts.STOREY)
		taken[level] = true
		# Nothing stands on a waist-high wall: a wall a storey up from it would
		# hang in the air a metre and a half above its top.
		if record["kind"] == HouseParts.WALL_HALF:
			for above in range(level, HouseParts.MAX_STOREYS):
				taken[above] = true
	var storey := from
	while taken.has(storey):
		storey += 1
	return storey

## The top of the highest wall or post round a square, or -INF if nothing
## stands round it. A roof square sits there, whatever height the child is
## standing at.
func wall_top_round(cell: Vector2i) -> float:
	var top := -INF
	for record in _records:
		var layer := HouseParts.layer(record["kind"])
		if layer != &"wall" and layer != &"post":
			continue
		var offset: Vector2i = HouseParts.key_of(record["position"]) - cell
		# The four edges of the square and its four corners — and its centre,
		# where a wall saved before walls moved onto edges still stands.
		if absi(offset.x) > 1 or absi(offset.y) > 1:
			continue
		var at: Vector3 = record["position"]
		top = maxf(top, at.y + HouseParts.height(record["kind"]))
	return top

## Whether a floor already lies in this square on this storey, for a bed to
## stand on rather than in.
func floor_under(cell: Vector2i, level: float) -> bool:
	for record in _records:
		if HouseParts.layer(record["kind"]) != &"floor":
			continue
		var at: Vector3 = record["position"]
		if HouseParts.key_of(at) == cell and absf(at.y - level) < HouseParts.STOREY * 0.5:
			return true
	return false

## How near a counter a table or a shelf has to be for the two to be one
## building, and how near a child has to stand to use what the building offers.
const VENUE_REACH := 6.0
const VENUE_USE := 3.2

## What this child's own buildings offer where a point is: &"cafe" beside a
## table of a building that has a counter, &"shop" beside the counter of one
## that has a shelf, or nothing. A cafe is a counter with a table, a shop is a
## counter with a shelf, and either needs a wall near the counter, so a table
## and a counter left in a field are furniture and not a business.
func venue_at(at: Vector3) -> StringName:
	_find_venues()
	for table: Vector3 in _cafe_tables:
		if Vector2(table.x - at.x, table.z - at.z).length() < VENUE_USE:
			return &"cafe"
	for counter: Vector3 in _shop_counters:
		if Vector2(counter.x - at.x, counter.z - at.z).length() < VENUE_USE:
			return &"shop"
	return &""

## Which of the two this child has built anywhere, for saying so once.
func has_venue(kind: StringName) -> bool:
	_find_venues()
	return not (_cafe_tables if kind == &"cafe" else _shop_counters).is_empty()

## The chair nearest a point that belongs to a cafe, as where to sit and which
## way to face, or an empty record when there is none: a child can eat
## standing at a table.
func seat_near(at: Vector3) -> Dictionary:
	var best := {}
	var best_distance := VENUE_USE
	for record in _records:
		if record["kind"] != HouseParts.CHAIR:
			continue
		var chair: Vector3 = record["position"]
		var distance := Vector2(chair.x - at.x, chair.z - at.z).length()
		if distance >= best_distance:
			continue
		var spin := float(record["spin"])
		best_distance = distance
		best = {
			"seat": chair + Basis(Vector3.UP, spin) * Vector3(0.0, 0.5, 0.68),
			"facing": spin,
		}
	return best

## Whether somebody is sitting in one of the chairs the child has built, from
## where they are alone (they are kept `sink` below the top of it while they
## eat, see Main._carry): the pose, and the seat in the world turned to face its
## table, or an empty record. A chair is drawn 0.48 up and the seat above is
## where the rest of the game puts it, 0.5; the body is sat on the drawing.
func seat_under(at: Vector3, sink: float, across: float, about: float) -> Dictionary:
	_find_venues()
	for chair: Dictionary in _chairs:
		var seat: Vector3 = chair["seat"]
		if Vector2(seat.x - at.x, seat.z - at.z).length() > across:
			continue
		if absf(at.y - (seat.y - sink)) > about:
			continue
		return {
			"pose": &"chair",
			"place": Transform3D(Basis(Vector3.UP, float(chair["facing"])), seat - Vector3(0.0, 0.02, 0.0)),
		}
	return {}

## The foot of the table nearest a point that belongs to a cafe, for a plate to
## be set on, or NAN if there is none within reach.
func table_near(at: Vector3) -> Vector3:
	_find_venues()
	var best := Vector3(NAN, NAN, NAN)
	var best_distance := VENUE_USE
	for table: Vector3 in _cafe_tables:
		var distance := Vector2(table.x - at.x, table.z - at.z).length()
		if distance < best_distance:
			best_distance = distance
			best = table
	return best

var _venues_revision := -1
var _cafe_tables: Array[Vector3] = []
var _shop_counters: Array[Vector3] = []
## Every chair there is, as the seat and which way it faces, for `seat_under`.
var _chairs: Array[Dictionary] = []

func _find_venues() -> void:
	if _venues_revision == revision:
		return
	_venues_revision = revision
	_cafe_tables.clear()
	_shop_counters.clear()
	_chairs.clear()
	var counters: Array[Vector3] = []
	var tables: Array[Vector3] = []
	var shelves: Array[Vector3] = []
	var walls: Array[Vector3] = []
	for record in _records:
		var at: Vector3 = record["position"]
		match record["kind"]:
			HouseParts.COUNTER:
				counters.append(at)
			HouseParts.TABLE:
				tables.append(at)
			HouseParts.CHAIR:
				var spin := float(record["spin"])
				_chairs.append({"seat": at + Basis(Vector3.UP, spin) * Vector3(0.0, 0.5, 0.68), "facing": spin})
			HouseParts.SHELF:
				shelves.append(at)
			_:
				if HouseParts.layer(record["kind"]) == &"wall":
					walls.append(at)
	for counter in counters:
		if not _near_any(counter, walls):
			continue
		for table in tables:
			if _flat_distance(counter, table) <= VENUE_REACH and not _cafe_tables.has(table):
				_cafe_tables.append(table)
		if _near_any(counter, shelves):
			_shop_counters.append(counter)

func _near_any(at: Vector3, others: Array[Vector3]) -> bool:
	for other in others:
		if _flat_distance(at, other) <= VENUE_REACH:
			return true
	return false

static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

## The lamps give light at night, a few at a time: an omni light costs a phone
## its share of every frame, so only the nearest few of the lamps a child has
## set down are lit, and only when it is dark.
const LAMP_RANGE := 7.0
const LAMP_ENERGY := 1.3
const LAMPS_LIT := 4
const LAMP_SHOWN_WITHIN := 45.0

## The records that carry a lamp's light, found again whenever `revision` moves.
var _lamps: Array[Dictionary] = []
var _lamps_revision := -1

func _add_lamp_light(record: Dictionary, node: Node3D) -> void:
	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 1.56, 0.0)
	light.omni_range = LAMP_RANGE
	light.light_energy = LAMP_ENERGY
	light.light_color = Color(1.0, 0.82, 0.55)
	light.shadow_enabled = false
	light.visible = false
	node.add_child(light)
	record["light"] = light

## How many lamps are giving light right now.
func lamps_lit() -> int:
	var lit := 0
	for record in _records:
		var light: OmniLight3D = record.get("light")
		if light != null and is_instance_valid(light) and light.visible:
			lit += 1
	return lit

## Called every frame with how dark it is and where the child is.
func light_lamps(darkness: float, near: Vector3) -> void:
	# Only the lamps are walked. A house is hundreds of pieces and nearly none
	# of them is a lamp, yet every one was asked for its light sixty times a
	# second; the lamps are found again only when something is built or taken
	# down.
	if _lamps_revision != revision:
		_lamps.clear()
		for record in _records:
			if record.get("light") != null:
				_lamps.append(record)
		_lamps_revision = revision
	var candidates: Array[Dictionary] = []
	for record in _lamps:
		var light: OmniLight3D = record.get("light")
		if light == null or not is_instance_valid(light):
			continue
		light.visible = false
		var at: Vector3 = record["position"]
		var distance := Vector2(at.x - near.x, at.z - near.z).length()
		if darkness > 0.15 and distance < LAMP_SHOWN_WITHIN:
			record["lamp_distance"] = distance
			candidates.append(record)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["lamp_distance"]) < float(b["lamp_distance"]))
	for i in mini(candidates.size(), LAMPS_LIT):
		var light: OmniLight3D = candidates[i]["light"]
		light.light_energy = LAMP_ENERGY * smoothstep(0.15, 0.45, darkness)
		light.visible = true

## The room a square is in: every square reachable from it without crossing a
## wall, a door or a window, or an empty answer if the walls do not close it in
## within ROOM_LONGEST squares either way.
##
## Answered as the squares, their bounds in grid keys, whether they make a
## rectangle, and the top of the highest wall round them — which is where the
## whole roof goes.
func enclosed_room(start: Vector2i) -> Dictionary:
	var walls := {}
	for record in _records:
		if HouseParts.layer(record["kind"]) != &"wall":
			continue
		var at: Vector3 = record["position"]
		var key := HouseParts.key_of(at)
		walls[key] = maxf(float(walls.get(key, -INF)), at.y + HouseParts.height(record["kind"]))
	if walls.is_empty():
		return {}

	var steps: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var low := start
	var high := start
	var top := -INF
	var lowest := INF
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for step in steps:
			var edge := cell + step
			if walls.has(edge):
				top = maxf(top, float(walls[edge]))
				lowest = minf(lowest, float(walls[edge]))
				continue
			var next := cell + step * 2
			if seen.has(next):
				continue
			seen[next] = true
			low = Vector2i(mini(low.x, next.x), mini(low.y, next.y))
			high = Vector2i(maxi(high.x, next.x), maxi(high.y, next.y))
			# Out into the valley: no room here.
			if (high.x - low.x) / 2 >= HouseParts.ROOM_LONGEST or (high.y - low.y) / 2 >= HouseParts.ROOM_LONGEST:
				return {}
			queue.append(next)
	var span := Vector2i((high.x - low.x) / 2 + 1, (high.y - low.y) / 2 + 1)
	return {
		"cells": seen.keys(),
		"low": low,
		"high": high,
		"span": span,
		"rectangle": seen.size() == span.x * span.y,
		"top": top,
		# A roof laid on the highest wall leaves a gap of sky over the lower
		# ones, so a room whose walls are not all one height says so.
		"level": top - lowest < 0.05,
	}

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
	# The game asks this every frame for the bed, and a house is hundreds of
	# pieces: a scan of them all sixty times a second to be told, again, that
	# nothing has moved. The last answer stands while the child stands still and
	# nothing is built or taken down. Exactly still, not nearly: this also picks
	# the piece a tap takes down, and a piece chosen from where the child was
	# half a metre ago is the wrong wall.
	if (
		_nearest_revision == revision
		and reach == _nearest_reach
		and world_position == _nearest_at
	):
		return _nearest_record
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
	_nearest_revision = revision
	_nearest_reach = reach
	_nearest_at = world_position
	_nearest_record = best
	return best

var _nearest_revision := -1
var _nearest_reach := 0.0
var _nearest_at := Vector3.ZERO
var _nearest_record := {}

## The nearest piece that also stands in the other child's valley, or an empty
## record. The only kind of piece a removal from the other phone may touch.
##
## Told what was taken down, only a piece of that kind is a match, and one on
## the same level: a chair and its table, or a bed and its floor, share a spot.
## An empty kind is a removal from a phone that does not say, matched by place.
func nearest_shared(world_position: Vector3, reach: float, kind := &"") -> Dictionary:
	var best := {}
	var best_distance := reach
	for record in _records:
		if not bool(record.get("shared", false)):
			continue
		if kind != &"" and record["kind"] != kind:
			continue
		var offset: Vector3 = record["position"] - world_position
		offset.y *= 0.6
		var distance := offset.length()
		if distance <= best_distance:
			best_distance = distance
			best = record
	return best

## Everything standing is the host's valley, handed to a guest on arrival: not
## built from this child's bag, so taking it down refunds nothing, and standing
## in both valleys, so a removal either child makes crosses the wire.
func adopt_as_shared() -> void:
	for record in _records:
		record["paid"] = false
		record["shared"] = true

## Somebody has come into this valley. Everything already standing is sent to
## them on arrival (see Session.report_valley), so it is in both valleys from
## this moment, and not only what is built afterwards: left as it was, a wall
## the host built last week could be taken down by the guest on their phone
## while the host's stayed standing, because a removal only ever matches a
## shared piece. Still the host's own, so still paid for.
##
## Three passes found this at once and named it three ways; share_standing and
## begin_sharing are kept as the same call so their checks still read.
func share_standing() -> void:
	start_sharing()

func begin_sharing() -> void:
	start_sharing()

func start_sharing() -> void:
	sharing = true
	for record in _records:
		record["shared"] = true

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
	revision += 1
	removed.emit(kind, at)
	_recompute_groves()
	return kind

## `paid` is false for a piece that arrived from the other phone: it was built
## out of the other child's bag, and taking it down must not hand this child
## materials they never spent.
##
## `extent` is how many squares a whole roof covers, across and along its ridge;
## every other piece is one square. Returns the record, so the undo button can
## take back exactly the piece that was put up.
func place(
	kind: StringName, world_position: Vector3, spin: float, paid := true,
	extent := Vector2i.ONE, material := HouseParts.DEFAULT_MATERIAL
) -> Dictionary:
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
		"extent": extent,
		"material": material,
	}
	_records.append(record)
	revision += 1
	_spawn_node(record)
	placed.emit(kind, world_position)
	# Only the generated pieces grow. Asking BuildKinds about a house part is
	# asking a dictionary for a key it has never heard of, and the error is
	# raised once per piece placed — loud, but easy to lose in a busy log.
	if not BuildKinds.INFO.has(kind) or not BuildKinds.grows(kind):
		_recompute_groves()
	return record

## Whether a child can stand on this piece rather than walk through it: any
## stairs, and a floor laid a storey or more above the ground. A floor on the
## ground stays a drawing on the grass — a lip to catch a foot on at every
## doorway, and nothing is under it to hold up — and a floor upstairs is where
## the stairs lead. The ground under a floor is the terrain's, so on a hillside
## a floor uphill of the first is still judged by its own height above it.
func _carries(record: Dictionary) -> bool:
	var kind: StringName = record["kind"]
	if kind == HouseParts.STAIRS:
		return true
	if kind != HouseParts.FLOOR:
		return false
	var at: Vector3 = record["position"]
	return at.y - field.height_at(at.x, at.z) > HouseParts.STOREY * 0.625

func _spawn_node(record: Dictionary) -> void:
	var node := MeshInstance3D.new()
	var kind: StringName = record["kind"]
	node.mesh = (
		HouseParts.mesh_for(
			kind, record.get("extent", Vector2i.ONE),
			record.get("material", HouseParts.DEFAULT_MATERIAL)
		) if HouseParts.is_house_part(kind)
		else BuildKinds.build_mesh(kind, record["stage"])
	)
	node.material_override = _material
	node.transform = Transform3D(Basis(Vector3.UP, record["spin"]), record["position"])
	if HouseParts.is_house_part(kind) and (HouseParts.is_solid(kind) or _carries(record)):
		HouseParts.add_collision(node, kind)
	if kind == HouseParts.LAMP:
		_add_lamp_light(record, node)
	elif not HouseParts.is_house_part(kind):
		BuildKinds.add_collision(node, kind, int(record["stage"]))
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
	# Only what is still growing is walked. Every piece a child has placed was
	# asked, sixty times a second, whether it grows and whether it has finished
	# — and a house is hundreds of pieces that do neither.
	if _growing_revision != revision:
		_growing.clear()
		for record in _records:
			if BuildKinds.INFO.has(record["kind"]) and BuildKinds.grows(record["kind"]):
				_growing.append(record)
		_growing_revision = revision
	for i in range(_growing.size() - 1, -1, -1):
		var record := _growing[i]
		if record["stage"] >= BuildKinds.GROWTH_STAGES - 1:
			_growing.remove_at(i)
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
		var entry := {
			"kind": String(record["kind"]),
			"x": at.x, "y": at.y, "z": at.z,
			"spin": record["spin"],
			"age": record["age"],
			"paid": bool(record.get("paid", true)),
		}
		# Only a whole roof covers more than one square, so only a whole roof
		# carries its size. Every other record is saved exactly as before, and
		# a save without these reads as one square.
		var extent: Vector2i = record.get("extent", Vector2i.ONE)
		if extent != Vector2i.ONE:
			entry["across"] = extent.x
			entry["along"] = extent.y
		# Likewise only a wall that is not the old plaster look says what it is
		# made of; everything saved before there was a choice reads as plaster.
		var material: StringName = record.get("material", HouseParts.DEFAULT_MATERIAL)
		if material != HouseParts.DEFAULT_MATERIAL and HouseParts.is_wall(record["kind"]):
			entry["material"] = String(material)
		data.append(entry)
	return data

## A count of squares out of a saved field, which has been through JSON and
## may have been through worse: anything that is not a number is one square.
static func _squares(value: Variant) -> int:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return 1
	return clampi(int(value), 1, HouseParts.ROOM_LONGEST)

func from_data(data: Array) -> void:
	for record in _records:
		var node: Node3D = record["node"]
		if is_instance_valid(node):
			node.queue_free()
	_records.clear()

	for entry in data:
		# A hand-edited or damaged save may hold something that is not a record;
		# it is skipped, and the pieces around it are still built.
		if entry is not Dictionary:
			continue
		var kind := StringName(entry.get("kind", ""))
		if not BuildKinds.INFO.has(kind) and not HouseParts.is_house_part(kind):
			continue
		var record := {
			"kind": kind,
			"position": Vector3(float(entry.get("x", 0.0)), float(entry.get("y", 0.0)), float(entry.get("z", 0.0))),
			"spin": float(entry.get("spin", 0.0)),
			"age": maxf(0.0, float(entry.get("age", 0.0))),
			"stage": 0,
			"node": null,
			"shared": false,
			# Everything saved before this mark existed was built by this child.
			"paid": bool(entry.get("paid", true)),
			"extent": Vector2i(_squares(entry.get("across", 1)), _squares(entry.get("along", 1))),
			"material": HouseParts.material_from(entry.get("material", HouseParts.DEFAULT_MATERIAL)),
		}
		if BuildKinds.INFO.has(kind) and BuildKinds.grows(kind):
			record["stage"] = mini(
				int(float(record["age"]) / BuildKinds.GROWTH_STAGE_SECONDS),
				BuildKinds.GROWTH_STAGES - 1
			)
		_records.append(record)
	_move_out_of_places()
	revision += 1
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
		# Set down at the same height above the ground it stood at, not on the
		# ground: a wall a storey up or a roof on a house was put on the grass
		# beside it, at the foot of the walls it was meant to cover.
		var standing := at.y - field.height_at(at.x, at.z)
		record["position"] = Vector3(
			free.x, field.height_at(free.x, free.y) + standing, free.y
		)
		moved += 1
	return moved
