extends RefCounted

## The house a child builds, step by step, for the checks and the screenshots.
##
## One plan in one place, so the house the checks prove works is the house the
## screenshot shows. Every piece goes up through BuildMode exactly as a child
## puts it up: stand somewhere on the ground, face a way, let the ghost land
## where it lands, tap. Nothing is placed by coordinates, and the child never
## leaves the ground — the whole point is that a house can be finished without
## climbing onto it.
##
## The house is two squares by two — four metres by four — with a door in the
## south wall, a window in the east, a floor in every square, one whole roof,
## and a bed in the north-east corner.

const REACH := BuildMode.REACH

## Somewhere near `near` with room for the house and a stride round it: ground
## a child may build on, not too steep, and level enough that one floor level
## suits all of it. The returned point is the centre of the house's north-west
## square, at ground height, or INF if nothing nearby will do.
static func find_site(build: BuildMode, field: HeightField, near: Vector3) -> Vector3:
	for ring in 30:
		var around := maxi(ring * 6, 1)
		for step in around:
			var angle := TAU * float(step) / float(around)
			var at := near + Vector3(cos(angle), 0.0, sin(angle)) * float(ring) * 4.0
			var square := HouseParts.snap_cell(at.x, at.z)
			if _fits(build, field, square):
				return Vector3(square.x, field.height_at(square.x, square.y), square.y)
	return Vector3.INF

static func _fits(build: BuildMode, field: HeightField, square: Vector2) -> bool:
	var lowest := INF
	var highest := -INF
	# The house runs from a metre west and north of the first square's centre
	# to three metres east and south of it; the stride round it is where the
	# child stands.
	for i in 9:
		for j in 9:
			var x := square.x - 3.0 + float(i)
			var z := square.y - 3.0 + float(j)
			var at := Vector3(x, field.height_at(x, z), z)
			if not build.would_build_at(at) or build._kept_ground(x, z):
				return false
			lowest = minf(lowest, at.y)
			highest = maxf(highest, at.y)
	return highest - lowest < 0.5

## Each step: what to build, where the child stands (x, z), which way they
## face, and where the piece should end up (x, z).
static func plan(origin: Vector3) -> Array:
	var x := origin.x
	var z := origin.z
	return [
		# The north wall, from inside the room looking north. A little off the
		# exact spot and a little off straight, because nobody stands exactly.
		[HouseParts.WALL, Vector2(x + 0.3, z - 1.0 + REACH - 0.2), 0.0, Vector2(x, z - 1.0)],
		[HouseParts.WALL, Vector2(x + 1.75, z - 1.0 + REACH + 0.3), 0.1, Vector2(x + 2.0, z - 1.0)],
		# The west wall, looking west.
		[HouseParts.WALL, Vector2(x - 1.0 + REACH, z + 0.2), PI * 0.5, Vector2(x - 1.0, z)],
		[HouseParts.WALL, Vector2(x - 1.0 + REACH + 0.2, z + 1.7), PI * 0.5 - 0.15, Vector2(x - 1.0, z + 2.0)],
		# The east wall, looking east, with a window in it.
		[HouseParts.WALL_WINDOW, Vector2(x + 3.0 - REACH, z + 0.25), -PI * 0.5, Vector2(x + 3.0, z)],
		[HouseParts.WALL, Vector2(x + 3.0 - REACH - 0.2, z + 2.0), -PI * 0.5, Vector2(x + 3.0, z + 2.0)],
		# The south wall, looking south, with the door.
		[HouseParts.WALL, Vector2(x + 2.0, z + 3.0 - REACH), PI, Vector2(x + 2.0, z + 3.0)],
		[HouseParts.WALL_DOOR, Vector2(x + 0.2, z + 3.0 - REACH + 0.3), PI, Vector2(x, z + 3.0)],
		# A floor in every square, from just south of each one, looking north.
		[HouseParts.FLOOR, Vector2(x + 0.2, z + REACH), 0.0, Vector2(x, z)],
		[HouseParts.FLOOR, Vector2(x + 2.2, z + REACH), 0.0, Vector2(x + 2.0, z)],
		[HouseParts.FLOOR, Vector2(x - 0.2, z + 2.0 + REACH), 0.0, Vector2(x, z + 2.0)],
		[HouseParts.FLOOR, Vector2(x + 2.0, z + 2.0 + REACH - 0.3), 0.0, Vector2(x + 2.0, z + 2.0)],
		# The whole roof, from outside the door, on the ground, looking in.
		[HouseParts.ROOF_ROOM, Vector2(x + 0.2, z + 3.0 + 1.2), 0.0, Vector2(x + 1.0, z + 1.0)],
		# And a bed in the north-east corner, from inside the room, looking
		# across it into the corner.
		[HouseParts.BED, Vector2(x - 0.05, z + 2.4), -0.7, Vector2(x + 2.0, z)],
	]

## Build the house. Returns one record per step: the kind, where the child
## stood, where the piece was meant to go, what the ghost was aimed at, and
## whether the tap built it.
static func build(build_mode: BuildMode, field: HeightField, origin: Vector3) -> Array[Dictionary]:
	var done: Array[Dictionary] = []
	build_mode.set_active(true)
	for step: Array in plan(origin):
		var kind: StringName = step[0]
		var stand: Vector2 = step[1]
		var standing := Vector3(stand.x, field.height_at(stand.x, stand.y), stand.y)
		build_mode.select(kind)
		build_mode.aim(standing, float(step[2]))
		var aimed := build_mode.target()
		var built := build_mode.place()
		done.append({
			"kind": kind, "stand": standing, "yaw": float(step[2]),
			"meant": step[3], "aimed": aimed, "built": built,
		})
	return done
