class_name RespawnSpot
extends RefCounted

## Where a child is saved, and where they are allowed to reappear.
##
## The phone may be put away at any moment, which writes a save, and the child
## must open the game again standing on the ground. Two things stood in the way:
## the position saved was wherever the body happened to be — at the top of the
## wheel, in a boat in the middle of the pond — and the position loaded was
## believed whatever it said, whether or not a wall had been built on that spot
## by the other child since. Both questions are answered here, as plain static
## functions, so that the checks can ask them without a game running.

## How far from the middle of the camp a position may be and still be believed.
## The valley is a pure function of the seed and has no wall, so this is not an
## edge anyone can reach: it is wide enough for the foot of the great mountain,
## which stands a kilometre out, and narrow enough that a position hand-edited
## or damaged into the millions is refused rather than streamed towards.
const WORLD_HALF := 2500.0

## Roughly the height of a child's head above their feet, and how far above the
## ground a spot may be before it needs something under it.
const BODY_HEIGHT := 1.6
const STANDING_REACH := 0.6

## How far round a refused spot to look for the nearest place that is allowed,
## before giving up and starting the child at the camp.
const SEARCH_RINGS: Array[float] = [1.5, 3.0, 4.5, 6.0]

## A position that could be a place in the world at all: three real numbers,
## none of them the infinity or not-a-number a damaged save can produce, and
## inside the world's limit.
static func in_the_world(at: Vector3) -> bool:
	if not (is_finite(at.x) and is_finite(at.y) and is_finite(at.z)):
		return false
	return absf(at.x) <= WORLD_HALF and absf(at.z) <= WORLD_HALF and absf(at.y) <= WORLD_HALF

## What to write into the save. A child on a ride, in a boat or in the water is
## not saved where they are but where they last stood on dry ground, which for a
## ride is the platform they boarded from and for a boat is the bank.
static func spot_to_save(here: Vector3, last_on_ground: Vector3, off_ground: bool) -> Vector3:
	return last_on_ground if off_ground else here

## Whether this point is under water: below the surface of the river or a pond,
## or in the pool. The bridge's deck is over the river and is dry.
static func is_wet(field: HeightField, places: Object, at: Vector3) -> bool:
	if field.is_on_the_bridge(at):
		return false
	var ground := field.height_at(at.x, at.z)
	if field.is_pond(at.x, at.z) and ground < field.water_level_at(at.x, at.z) + 0.3:
		return true
	if ground < field.water_level_at(at.x, at.z) + 0.15:
		return true
	return places != null and float(places.call("water_depth_at", at.x, at.z)) > 0.0

## Whether something built stands where a child would be, so that setting them
## there puts them inside it. Walls, posts, chimneys, counters and the like are
## solid; floors, rugs, beds, chairs, signs and the stairs are walked over or
## sat on, and a roof is overhead. Everything else a child plants or builds is
## solid across its footprint, judged as Structures.is_clear judges it.
static func built_over(structures: Structures, at: Vector3) -> bool:
	for record: Dictionary in structures.records_near(at, 4.0):
		var kind: StringName = record["kind"]
		var base: Vector3 = record["position"]
		var offset := Vector2(at.x - base.x, at.z - base.z)
		if HouseParts.is_house_part(kind):
			var height := HouseParts.height(kind)
			# Not at the child's height at all: a storey above, or one below.
			if base.y >= at.y + BODY_HEIGHT or base.y + height <= at.y + 0.2:
				continue
			match HouseParts.layer(kind):
				&"wall":
					if _inside_a_wall(base, offset):
						return true
				&"post", &"chimney":
					if offset.length() < HouseParts.footprint(kind) * 0.5 + Player.RADIUS:
						return true
				&"furniture":
					# A bed is slept on and its square walked into; the rest
					# stand up and are walked round.
					if kind != HouseParts.BED and maxf(absf(offset.x), absf(offset.y)) < 0.6 + Player.RADIUS:
						return true
		else:
			var minimum := (0.5 + BuildKinds.footprint(kind)) * 0.5
			if offset.length() < minimum:
				return true
	return false

## A wall stands on the line between two squares, so one of its coordinates is
## an odd number of metres and it runs along the other: two metres long, and
## thin across. A wall saved from before walls moved onto the edges stands on a
## square's centre, and blocks the whole square.
static func _inside_a_wall(base: Vector3, offset: Vector2) -> bool:
	var key := HouseParts.key_of(base)
	var along_x := posmod(key.y, 2) == 1
	var along_z := posmod(key.x, 2) == 1
	if along_x == along_z:
		return maxf(absf(offset.x), absf(offset.y)) < HouseParts.MODULE * 0.5 + Player.RADIUS
	var length := HouseParts.MODULE * 0.5 + Player.RADIUS
	var thickness := 0.15 + Player.RADIUS
	if along_z:
		return absf(offset.x) < thickness and absf(offset.y) < length
	return absf(offset.y) < thickness and absf(offset.x) < length

## The height a child at this spot stands at. The ground as it is now, or the
## bridge's deck, or the top of a floor or stairs that is still there under
## them: a height saved against a floor that was taken down in the meantime
## would otherwise load into the air.
static func standing_y(field: HeightField, structures: Structures, at: Vector3) -> float:
	var ground := field.standing_height_at(at.x, at.z, at.y)
	if at.y <= ground + STANDING_REACH:
		return maxf(at.y, ground)
	for record: Dictionary in structures.records_near(at, 1.6):
		var kind: StringName = record["kind"]
		if HouseParts.layer(kind) != &"floor":
			continue
		var base: Vector3 = record["position"]
		if maxf(absf(at.x - base.x), absf(at.z - base.z)) > HouseParts.MODULE * 0.5:
			continue
		var top := base.y + HouseParts.height(kind)
		# Stairs are stood on all the way up; a floor only at its surface.
		if kind == HouseParts.STAIRS:
			if at.y >= base.y and at.y <= top + 0.4:
				return at.y
		elif absf(at.y - top) <= STANDING_REACH + 0.4:
			return maxf(at.y, top)
	return ground

## Whether a child may be put at this spot: in the world, on dry ground, clear
## of everything built, outside any ride, and clear of the signpost.
static func is_allowed(
	field: HeightField, structures: Structures, places: Object, park: Object, at: Vector3
) -> bool:
	if not in_the_world(at) or is_wet(field, places, at):
		return false
	if structures != null and built_over(structures, at):
		return false
	if park != null and park.call("ride_under", at) != &"":
		return false
	return true

## Where to put a child who asked for `saved`, or `spawn` if nowhere near it
## will do. A refused spot is not given up on at once: a house built over the
## place a child was standing leaves open ground a few strides away, and the
## child reappears beside the house rather than being sent back to the camp.
static func choose(
	field: HeightField, structures: Structures, places: Object, park: Object,
	signpost: Signpost, saved: Vector3, spawn: Vector3
) -> Vector3:
	if not in_the_world(saved):
		return spawn
	var spot := _settled(field, structures, signpost, saved)
	if is_allowed(field, structures, places, park, spot):
		return spot
	for ring in SEARCH_RINGS:
		for step in 8:
			var angle := TAU * float(step) / 8.0 + 0.6
			var near := _settled(field, structures, signpost, Vector3(
				saved.x + cos(angle) * ring, field.height_at(saved.x + cos(angle) * ring, saved.z + sin(angle) * ring),
				saved.z + sin(angle) * ring
			))
			if field.steepness_at(near.x, near.z) > 0.5:
				continue
			if is_allowed(field, structures, places, park, near):
				return near
	return spawn

static func _settled(field: HeightField, structures: Structures, signpost: Signpost, at: Vector3) -> Vector3:
	var spot := at
	if structures != null:
		spot.y = standing_y(field, structures, at)
	else:
		spot.y = maxf(at.y, field.standing_height_at(at.x, at.z, at.y))
	if signpost != null:
		spot = signpost.push_clear(spot)
	return spot
