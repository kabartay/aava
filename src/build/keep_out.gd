class_name KeepOut
extends RefCounted

## Ground that belongs to something else, in one place.
##
## The planting rule and the rule that tidies a loaded valley have to be the
## same rule. They were not: the builder refused to plant a tree on the
## fairground, and a tree planted there before the rule existed stayed exactly
## where it was — standing in front of the big wheel, which is where this was
## found out.
##
## Dependency-free, like PlaceSpec and BridgeSpec, so both the builder and the
## structures can read it without a class_name cycle hanging the loader. What
## it needs from the world — where the camp is, where the river crosses — it
## is told.

## How far from the things that are not places — the crossing and the signs —
## nothing may be built. Three metres, which is a stride and a half clear.
const KEEP_BACK := 3.0

## Is this ground somebody else's?
static func kept(x: float, z: float, camp: Vector3, river_x: float) -> bool:
	if PlaceSpec.reserved(x, z, camp):
		return true
	# The football pitch, which is levelled rather than reserved.
	if Pitch.is_levelled(x, z):
		return true
	# The fairground, and a stride of sand outside its fence.
	if inside_the_park(x, z):
		return true
	# The crossing: its deck and the ground either end of it, so nothing grows
	# up through the planks or in front of them.
	if (
		absf(z - BridgeSpec.CENTRE_Z) < BridgeSpec.HALF_WIDTH + KEEP_BACK
		and absf(x - river_x) < BridgeSpec.HALF_SPAN + KEEP_BACK
	):
		return true
	# The signs, and room to stand and read them.
	var post := camp + Signpost.OFFSET
	return Vector2(x - post.x, z - post.z).length() < Signpost.KEEP_CLEAR + KEEP_BACK

static func inside_the_park(x: float, z: float) -> bool:
	return (
		x > ParkSpec.WEST - KEEP_BACK and x < ParkSpec.EAST + KEEP_BACK
		and z < ParkSpec.SOUTH + KEEP_BACK and z > ParkSpec.NORTH - KEEP_BACK
	)

## The nearest ground that is not somebody else's, for something that is
## already standing on ground that is.
##
## Moved, not removed: a tree a child planted is still their tree, only no
## longer in front of the big wheel. It goes straight out of whichever side of
## the place it is nearest to, which for a fairground is the fence it is
## closest to and for a levelled place is the bearing it stands on.
static func nearest_free(x: float, z: float, camp: Vector3, river_x: float) -> Vector2:
	var at := Vector2(x, z)
	if PlaceSpec.reserved(x, z, camp):
		var free := PlaceSpec.nearest_free(x, z, camp)
		at = Vector2(free.x, free.z)
	if inside_the_park(at.x, at.y):
		at = out_of_the_park(at)
	# The crossing and the signs both push straight away from themselves.
	if (
		absf(at.y - BridgeSpec.CENTRE_Z) < BridgeSpec.HALF_WIDTH + KEEP_BACK
		and absf(at.x - river_x) < BridgeSpec.HALF_SPAN + KEEP_BACK
	):
		var side := signf(at.y - BridgeSpec.CENTRE_Z)
		if side == 0.0:
			side = 1.0
		at.y = BridgeSpec.CENTRE_Z + side * (BridgeSpec.HALF_WIDTH + KEEP_BACK + 0.5)
	var post := Vector2(camp.x + Signpost.OFFSET.x, camp.z + Signpost.OFFSET.z)
	var clear := Signpost.KEEP_CLEAR + KEEP_BACK + 0.5
	if at.distance_to(post) < clear:
		var away := at - post
		if away.length() < 0.01:
			away = Vector2(1.0, 0.0)
		at = post + away.normalized() * clear
	return at

## Straight out of the fairground by the nearest side of it.
static func out_of_the_park(at: Vector2) -> Vector2:
	var margin := KEEP_BACK + 0.5
	var ways: Array = [
		[absf(at.x - (ParkSpec.WEST - KEEP_BACK)), Vector2(ParkSpec.WEST - margin, at.y)],
		[absf(at.x - (ParkSpec.EAST + KEEP_BACK)), Vector2(ParkSpec.EAST + margin, at.y)],
		[absf(at.y - (ParkSpec.SOUTH + KEEP_BACK)), Vector2(at.x, ParkSpec.SOUTH + margin)],
		[absf(at.y - (ParkSpec.NORTH - KEEP_BACK)), Vector2(at.x, ParkSpec.NORTH - margin)],
	]
	var best: Vector2 = ways[0][1]
	var shortest: float = ways[0][0]
	for way: Array in ways:
		if float(way[0]) < shortest:
			shortest = float(way[0])
			best = way[1]
	return best
