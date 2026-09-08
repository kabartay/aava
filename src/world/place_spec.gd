class_name PlaceSpec
extends RefCounted

## Where the playground, pool and café stand, and how flat the ground under
## them has to be.
##
## This is a dependency-free leaf script for the same reason `terrain_spec.gd`
## is: the height field has to level the ground under these places, and `Places`
## has to ask the height field where the ground is. Putting the positions in
## either one makes the two reference each other, and a cyclic `class_name`
## dependency does not produce an error in Godot — the import simply never
## finishes. See LESSONS.md.
##
## The camp offset is fixed rather than passed in, because the height field is a
## pure function of position and a seed and must stay that way: anything that
## can be set at runtime cannot be part of it.

## Where each place sits relative to the camp, spread rather than in a row so
## that walking between them means crossing the valley.
## Spread across the valley rather than clustered round the camp.
##
## They were all within twenty-six metres of it, which put the pitch, the
## archery butts, the pool, the café and the playground in one heap — a child
## could stand still and reach everything, and the valley beyond was scenery
## with nothing in it. Now they are 375 to 440 m from the camp and 440 to 813 m
## from each other: far enough that going somewhere is a journey, close enough
## that a horse crosses it in under a minute.
##
## Each site was checked for being dry, gentle across its own footprint, and
## clear of the river before being written down here.
const OFFSETS := {
	&"playground": Vector3(-360.0, 0.0, 250.0),
	&"cafe": Vector3(-300.0, 0.0, -260.0),
	&"pool": Vector3(60.0, 0.0, 380.0),
}

## How much flat ground each place needs, and how far out the levelling fades.
## Each radius must cover the structure that stands on it. The playground's
## frame and slide together span about seven metres, so a six-metre radius left
## the slide's foot on a slope.
const RADIUS := {
	&"playground": 20.4,
	&"cafe": 7.0,
	&"pool": 13.0,
}
## Half the width of the structure that actually stands at each place. The
## levelled radius has to comfortably exceed this, because the outer part of
## that radius is the feathered edge where the ground slopes back into the
## valley — flat ground is only guaranteed inside the footprint.
const FOOTPRINT := {
	&"playground": 14.4,
	&"cafe": 2.5,
	&"pool": 7.0,
}

const FEATHER := 7.0

## Where the archery range stands, relative to the camp. Not one of the
## levelled places — the range finds its own flat ground — but the map needs
## to know where it is.
const RANGE_OFFSET := Vector3(330.0, 0.0, -180.0)

## Everything the places touch, as a box around the camp. Still worth having
## now they are spread out — it is most of the world away from them — but it has
## to be wide enough to contain the furthest, or that place quietly stops being
## levelled and its buildings stand on a slope.
const BOUNDS_HALF := 460.0

## How much of the levelling applies at a point, from 1 at the centre to 0
## outside the feathered edge. Zero for every point far from all three, which is
## almost everywhere, so this is cheap.
static func influence(x: float, z: float, camp: Vector3) -> float:
	# Rejected before any square root. height_at calls this for every terrain
	# vertex in the world, and the places occupy a few dozen metres of it.
	if absf(x - camp.x) > BOUNDS_HALF or absf(z - camp.z) > BOUNDS_HALF:
		return 0.0

	var strongest := 0.0
	for place in OFFSETS:
		var centre: Vector3 = camp + OFFSETS[place]
		var radius: float = RADIUS[place]
		var reach := radius + FEATHER
		# Compared as squares, so the square root is only taken for points that
		# are actually near a place.
		var dx := x - centre.x
		var dz := z - centre.z
		if absf(dx) > reach or absf(dz) > reach:
			continue
		# Compared as squares, so the square root is only taken for the handful
		# of points actually near a place.
		var squared := dx * dx + dz * dz
		if squared > reach * reach:
			continue
		var distance := sqrt(squared)
		strongest = maxf(strongest, 1.0 - smoothstep(radius, radius + FEATHER, distance))
	return strongest

## The levelling for one named place alone, from 1 at its centre to 0 outside
## its feathered edge. The height field asks per place now, because each place
## is levelled to its own ground: one shared level, read at the camp, put the
## playground and the café — four hundred metres out, on hills thirty metres
## higher — at the bottom of thirty-metre pits.
static func influence_of(place: StringName, x: float, z: float, camp: Vector3) -> float:
	var centre: Vector3 = camp + OFFSETS[place]
	var radius: float = RADIUS[place]
	var reach := radius + FEATHER
	var dx := x - centre.x
	var dz := z - centre.z
	if absf(dx) > reach or absf(dz) > reach:
		return 0.0
	var squared := dx * dx + dz * dz
	if squared > reach * reach:
		return 0.0
	return 1.0 - smoothstep(radius, radius + FEATHER, sqrt(squared))

## Whether any place reaches into this box at all — asked once per terrain
## chunk, so the tint can skip every vertex of the chunks that hold no place.
static func touches_box(x0: float, z0: float, x1: float, z1: float, camp: Vector3) -> bool:
	for place in OFFSETS:
		var centre: Vector3 = camp + OFFSETS[place]
		var reach: float = RADIUS[place] + FEATHER
		if x1 < centre.x - reach or x0 > centre.x + reach:
			continue
		if z1 < centre.z - reach or z0 > centre.z + reach:
			continue
		return true
	return false

## How trodden the ground is here: the playground and the café are gathering
## places, worn to earth by feet, in a way the pool's tiled surround is not.
static func trodden(x: float, z: float, camp: Vector3) -> float:
	return maxf(
		influence_of(&"playground", x, z, camp), influence_of(&"cafe", x, z, camp)
	)

static func centre_of(place: StringName, camp: Vector3) -> Vector3:
	return camp + OFFSETS[place]

## Is this ground kept for a place — the playground, the pool, the café —
## where nothing may be built? A sapling planted beside the trampoline grew
## into a tree standing in it, which is how this came to exist. The whole
## levelled disc is kept, hedge and all.
static func reserved(x: float, z: float, camp: Vector3) -> bool:
	return reserved_by(x, z, camp) != &""

## Which place keeps this ground, or nothing.
static func reserved_by(x: float, z: float, camp: Vector3) -> StringName:
	for place in OFFSETS:
		var centre: Vector3 = camp + OFFSETS[place]
		var radius: float = RADIUS[place]
		if absf(x - centre.x) > radius or absf(z - centre.z) > radius:
			continue
		if Vector2(x - centre.x, z - centre.z).length() < radius:
			return place
	return &""

## The nearest ground outside whatever place keeps this point: straight out
## from the place's centre, a couple of metres past its edge. For things that
## were built there before the ground was kept.
static func nearest_free(x: float, z: float, camp: Vector3) -> Vector3:
	var place := reserved_by(x, z, camp)
	if place == &"":
		return Vector3(x, 0.0, z)
	var centre: Vector3 = camp + OFFSETS[place]
	var out := Vector2(x - centre.x, z - centre.z)
	if out.length() < 0.001:
		out = Vector2(1.0, 0.0)
	out = out.normalized() * (float(RADIUS[place]) + 2.0)
	return Vector3(centre.x + out.x, 0.0, centre.z + out.y)

## How deep the pool is, and how far its walls reach. Declared here rather than
## in Places because the height field has to dig the hole: a pool drawn as a
## rim on flat ground is a white square painted on the grass, which is exactly
## what the first version looked like.
const POOL_DEPTH := 1.9
const POOL_HALF := 6.0

## How much the ground is cut away at a point, in metres. Zero everywhere but
## inside the pool.
##
## Excavated in the height field so the terrain mesh, the collision heightmap,
## the grass and the pickups all agree there is a hole here — the same reason
## the football pitch is levelled here rather than by a node that draws a pitch.
static func excavation(x: float, z: float, camp: Vector3) -> float:
	if absf(x - camp.x) > BOUNDS_HALF or absf(z - camp.z) > BOUNDS_HALF:
		return 0.0
	var centre: Vector3 = camp + OFFSETS[&"pool"]
	var inside := maxf(absf(x - centre.x), absf(z - centre.z))
	if inside > POOL_HALF:
		return 0.0
	# Shelving at the edge, so a child steps in rather than falling in. Matches
	# the depth Places reports for swimming.
	return POOL_DEPTH * (1.0 - smoothstep(POOL_HALF - 1.6, POOL_HALF, inside))
