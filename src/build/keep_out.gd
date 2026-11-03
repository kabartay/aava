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
	# The scoreboard behind it, whose legs stand just outside the apron.
	if Pitch.under_scoreboard(x, z, KEEP_BACK):
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
	# Each rule pushes straight out of its own ground, and the ground just
	# outside one can be another's, so go round again until nothing keeps it.
	# A few rounds are plenty: the grounds are far apart, and the last answer
	# stands if they somehow never settle.
	for _round in 4:
		at = _pushed_out(at, camp, river_x)
		if not kept(at.x, at.y, camp, river_x):
			break
	return at

## One push out of each rule in turn.
static func _pushed_out(at: Vector2, camp: Vector3, river_x: float) -> Vector2:
	if PlaceSpec.reserved(at.x, at.y, camp):
		var free := PlaceSpec.nearest_free(at.x, at.y, camp)
		at = Vector2(free.x, free.z)
	# The pitch and its apron, which were kept from building but never moved
	# out of: a tree saved on the pitch stayed in the middle of the game.
	if Pitch.is_levelled(at.x, at.y):
		at = out_of_the_pitch(at)
	if inside_the_park(at.x, at.y):
		at = out_of_the_park(at)
	# The scoreboard: out by whichever of its ends or its back is nearest. Its
	# front is the apron, which nothing stands on to begin with.
	if Pitch.under_scoreboard(at.x, at.y, KEEP_BACK):
		var foot := Pitch.scoreboard_foot()
		var margin := KEEP_BACK + 0.5
		var end := signf(at.x - foot.x)
		if end == 0.0:
			end = 1.0
		var to_end := Pitch.BOARD_HALF_WIDTH + margin - absf(at.x - foot.x)
		var to_back := at.y - (foot.z - Pitch.BOARD_THICKNESS * 0.5 - margin)
		if to_end < absf(to_back):
			at.x = foot.x + end * (Pitch.BOARD_HALF_WIDTH + margin)
		else:
			at.y = foot.z - Pitch.BOARD_THICKNESS * 0.5 - margin
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

## Straight out of the levelled pitch by the nearest side of its apron.
static func out_of_the_pitch(at: Vector2) -> Vector2:
	var margin := 0.5
	var reach_x := Pitch.HALF_LENGTH + Pitch.APRON
	var reach_z := Pitch.HALF_WIDTH + Pitch.APRON
	var dx := at.x - Pitch.CENTRE.x
	var dz := at.y - Pitch.CENTRE.z
	if reach_x - absf(dx) < reach_z - absf(dz):
		var end := 1.0 if dx >= 0.0 else -1.0
		return Vector2(Pitch.CENTRE.x + end * (reach_x + margin), at.y)
	var side := 1.0 if dz >= 0.0 else -1.0
	return Vector2(at.x, Pitch.CENTRE.z + side * (reach_z + margin))

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
