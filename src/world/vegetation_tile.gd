class_name VegetationTile
extends Node3D

## One tile of planting: a MultiMesh per plant kind.
##
## Vegetation is chunked into tiles for a reason that is easy to get wrong:
## Godot has no per-instance culling inside a MultiMesh. One MultiMesh is one
## object to the renderer, so a single forest-wide MultiMesh is either entirely
## drawn or entirely skipped, and every instance always renders. Tiles are what
## buy back frustum culling and distance fade.

## Candidate positions tried per tile. Most are rejected by the density test, so
## this is a ceiling on effort, not a count of trees.
const TREE_CANDIDATES := 46
const GRASS_CANDIDATES := 620

## The least gap between two trunks' centres within a tile. A child is a third of
## a metre across and each trunk is solid to a third of a metre either side, so
## closer than this and a pair of trees is a wall the child cannot slip between.
const MIN_TREE_GAP := 1.8

## The heights the two tree meshes are built at (see Vegetation._init), kept
## here because the trunk a tree is solid to depends on them.
const CONIFER_HEIGHT := 6.4
const BROADLEAF_HEIGHT := 5.2

## How far a tree's origin is sunk below the ground it stands on (see
## generate_trees), so the ground cuts the trunk's flare a little above its middle.
const ROOT_DEPTH := 0.15

## The thinnest a trunk is ever made solid, however stunted the tree.
const MIN_TRUNK_RADIUS := 0.2

## Where the trees dissolve away, in metres from the camera; the dissolve begins
## a little under a quarter of that nearer. Tiles stream in out to TREE_RADIUS of
## them, so the middle of a tile that has only just arrived is some 240 m off:
## ending the fade at the full 256 m means it arrives almost transparent and
## thickens as the child walks towards it, instead of a whole wood appearing in
## one frame. Visibility range measures to the middle of a layer's bounds, which
## for a tile is the tile's middle, so the whole tile fades together.
const TREE_FADE_END := 256.0

## Whether this tile was planted with grass. Read by the manager to decide if a
## tile that has come closer needs replanting.
var has_grass := false

## Work out everything about a tile that does not touch the scene tree, so a
## worker thread can do it.
##
## A tile with grass is six hundred and twenty candidates times three height
## samples, plus a path test, a lake test and a pitch test each, plus the trees
## — about two thousand height-field queries, all on the main thread, one tile
## every thirty metres walked. That is what "it stutters a little after walking
## for a while" was. Same treatment as the terrain: this runs on the pool and
## returns arrays; `_init` turns them into instances.
##
## `felled` is a snapshot, not the live record: the axe writes to the live one
## on the main thread while this reads.
static func bake(
	field: HeightField,
	coord: Vector2i,
	tile_size: int,
	world_seed: int,
	felled: Felled,
	with_grass: bool
) -> Dictionary:
	var origin_x := float(coord.x * tile_size)
	var origin_z := float(coord.y * tile_size)

	# One pass over the trees, split into standing and felled, rather than the
	# two passes this used to make — once for the trees and once more, over the
	# whole tile again, for the stumps.
	var conifers: Array[Transform3D] = []
	var broadleaves: Array[Transform3D] = []
	var stumps: Array[Transform3D] = []
	var forest := generate_trees(field, coord, tile_size, world_seed, null)
	for grown in forest:
		var at: Vector3 = grown["position"]
		if felled != null and felled.is_felled(at.x, at.z):
			# Felled but grubbed out draws nothing at all: the tree stays gone
			# — the forest would otherwise stand it back up on the next
			# rebuild — and the ground is clear.
			if felled.shows_stump(at.x, at.z):
				# As wide as the trunk that was cut, so a great tree leaves a
				# great stump and a stunted one a small one.
				var girth := clampf(float(grown["scale"]), 0.6, 1.6)
				stumps.append(Transform3D(
					Basis(Vector3.UP, float(stumps.size()) * 1.1).scaled(Vector3(girth, 1.0, girth)),
					Vector3(at.x - origin_x, at.y, at.z - origin_z)
				))
		elif grown["conifer"]:
			conifers.append(grown["transform"])
		else:
			broadleaves.append(grown["transform"])

	# Stumps of trees that were never the forest's: one a child planted and then
	# felled is recorded as felled but is not in the list above, so it left bare
	# grass where it had stood. Any record the forest's own trees account for was
	# drawn in the loop already.
	if felled != null:
		for stump in felled.shown_in(origin_x, origin_z, float(tile_size)):
			var known := false
			for grown in forest:
				var there: Vector3 = grown["position"]
				if absf(there.x - stump.x) < Felled.MATCH_RADIUS and absf(there.z - stump.y) < Felled.MATCH_RADIUS:
					known = true
					break
			if known:
				continue
			stumps.append(Transform3D(
				Basis(Vector3.UP, float(stumps.size()) * 1.1),
				Vector3(stump.x - origin_x, field.height_at(stump.x, stump.y), stump.y - origin_z)
			))

	var tufts: Array[Transform3D] = []
	if with_grass:
		# Its own generator, seeded the same way the trees' is. The two never
		# shared one: generate_trees makes its own, so grass has always drawn
		# from the seed directly — and must keep doing so, or every tuft moves.
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector3i(world_seed, coord.x, coord.y))
		var bridge_x := field.river_centre_x(BridgeSpec.CENTRE_Z)
		# Every built floor, mat, court and deck that has said it is there, read
		# once for the tile (see ClearGround).
		var cleared := ClearGround.near(
			origin_x, origin_z, origin_x + float(tile_size), origin_z + float(tile_size)
		)
		for _i in GRASS_CANDIDATES:
			var local := Vector3(rng.randf() * tile_size, 0.0, rng.randf() * tile_size)
			var world_x := origin_x + local.x
			var world_z := origin_z + local.z
			var height := field.height_at(world_x, world_z)
			# Nothing grows in a pond, whatever height its water stands at. A
			# raised pond's bed sits well above the world's waterline and read
			# to this as ordinary dry hillside — a wood in a lake.
			if field.is_pond(world_x, world_z):
				continue
			if height < HeightField.WATER_LEVEL + 0.35 or height > HeightField.TREELINE:
				continue
			# A forward difference from the height already in hand, rather than
			# steepness_at, which takes four more samples of its own.
			var rise_x := field.height_at(world_x + 1.2, world_z) - height
			var rise_z := field.height_at(world_x, world_z + 1.2) - height
			if (rise_x * rise_x + rise_z * rise_z) > 0.36:
				continue
			# Nothing grows on a mown pitch, on a trodden path, or in a lake:
			# grass placed by its own rule comes straight up through anything
			# the terrain painted or the water covers.
			# Nor on the fairground, which is sand under a child's feet.
			if ParkSpec.inside(world_x, world_z):
				continue
			if Pitch.is_levelled(world_x, world_z):
				continue
			# Nor through the deck. It rises from the bank at each end by
			# less than a tuft is tall, so grass there came up between the
			# planks. A hand's breadth beyond the deck as well, for a
			# blade's own width.
			if (
				absf(world_z - BridgeSpec.CENTRE_Z) <= BridgeSpec.HALF_WIDTH + 0.6
				and absf(world_x - bridge_x) <= BridgeSpec.HALF_SPAN + 0.6
			):
				continue
			if field.path_at(world_x, world_z, height) > 0.35:
				continue
			if Lakes.wet(world_x, world_z):
				continue
			# Nor on a floor. A building is a place with a floor in it, and
			# grass came up through the café's and the shop's — and on the
			# doormat and porch deck, which are floor outside the walls.
			if PlaceSpec.on_floor(world_x, world_z, field.camp_centre()):
				continue
			# Nor on anything else built flat on the ground that registered itself.
			if not cleared.is_empty() and ClearGround.covers(cleared, world_x, world_z):
				continue
			# Trodden ground grows a tuft here and there, not a lawn. Decided by
			# a hash of the spot rather than a draw from the generator, so the
			# generator's sequence — and every other tuft in the tile — is
			# untouched.
			var worn := PlaceSpec.trodden(world_x, world_z, field.camp_centre())
			if worn > 0.2 and (hash(Vector2i(int(world_x * 7.0), int(world_z * 7.0))) % 100) < int(worn * 80.0):
				continue
			local.y = height
			var scale := rng.randf_range(0.75, 1.45)
			tufts.append(Transform3D(
				Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(scale, scale * rng.randf_range(0.8, 1.3), scale)),
				local
			))

	return {
		"coord": coord,
		"with_grass": with_grass,
		"conifers": conifers,
		"broadleaves": broadleaves,
		"stumps": stumps,
		"grass": tufts,
	}

## Assemble a tile from data already baked, on the main thread: four
## MultiMeshes at most, and nothing that asks the height field anything.
func _init(
	baked: Dictionary,
	tile_size: int,
	conifer: Mesh,
	broadleaf: Mesh,
	grass: Mesh,
	tree_material: ShaderMaterial,
	grass_material: ShaderMaterial,
	stump: Mesh
) -> void:
	var coord: Vector2i = baked["coord"]
	position = Vector3(float(coord.x * tile_size), 0.0, float(coord.y * tile_size))
	has_grass = baked["with_grass"]

	_add_layer(conifer, tree_material, baked["conifers"], tile_size, 24.0, true, TREE_FADE_END)
	_add_layer(broadleaf, tree_material, baked["broadleaves"], tile_size, 24.0, true, TREE_FADE_END)
	if stump != null:
		_add_layer(stump, tree_material, baked["stumps"], tile_size, 24.0, true, TREE_FADE_END)
	_add_layer(grass, grass_material, baked["grass"], tile_size, 1.5, false, 74.0)

## Where every tree in a tile stands, as a pure function of the world seed.
##
## This is a static function with no side effects because two callers need the
## same answer: the tile, which draws the trees, and the axe, which has to find
## one to cut down. When the two computed it separately they drifted — the
## search consumed a different number of random draws than the tile did, and
## found trees a metre from where they were drawn. There is one sequence, here.
##
## The order of the draws is the contract. Do not reorder them, and do not skip
## one for a rejected candidate: every candidate must consume the same draws
## whether it is kept or not, or every tree after the first felled one moves.
static func generate_trees(
	field: HeightField,
	coord: Vector2i,
	tile_size: int,
	world_seed: int,
	felled: Felled
) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var origin_x := float(coord.x * tile_size)
	var origin_z := float(coord.y * tile_size)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(world_seed, coord.x, coord.y))
	# Where trees have stood in this tile, felled or not. A felled tree still
	# keeps its neighbours at a distance, or cutting one would let the tree that
	# had been crowded out spring up in its place.
	var spots: Array[Vector2] = []
	# Everything built flat on the ground that has said it is there (see
	# ClearGround), read once for the tile. A trunk standing in a mat or a floor
	# is a solid pole in the middle of it.
	var cleared := ClearGround.near(origin_x, origin_z, origin_x + float(tile_size), origin_z + float(tile_size))

	for _i in TREE_CANDIDATES:
		var local := Vector3(rng.randf() * tile_size, 0.0, rng.randf() * tile_size)
		var world_x := origin_x + local.x
		var world_z := origin_z + local.z
		var density := field.forest_density_at(world_x, world_z)
		var thinned: bool = density <= 0.0 or rng.randf() > density

		# Every remaining draw happens whether or not the tree survives, so that
		# rejecting one candidate never shifts the next.
		local.y = field.height_at(world_x, world_z) - ROOT_DEPTH
		var scale := rng.randf_range(0.78, 1.35)
		var spin := rng.randf()
		var stretch := rng.randf_range(0.9, 1.2)
		var species := rng.randf()

		if thinned:
			continue
		# Nothing grows in a pond, whatever height its water stands at. A
		# raised pond's bed sits well above the world's waterline, so to
		# everything that asks the height alone it looked like dry hillside —
		# and a wood grew in the lake.
		if field.is_pond(world_x, world_z):
			continue
		# Not in another trunk's lap. Within the tile by the list below, across
		# its edge by the margin; the draws above were already taken, so this
		# moves no other tree.
		var here := Vector2(world_x, world_z)
		var crowded := false
		# The tile cannot see its neighbour's trees, so instead nobody stands
		# within half a gap of the seam: two trees either side of it are then at
		# least a whole gap apart, and no pair is a wall across the join.
		var edge := MIN_TREE_GAP * 0.5
		if (
			local.x < edge or local.x > float(tile_size) - edge
			or local.z < edge or local.z > float(tile_size) - edge
		):
			continue
		for other in spots:
			if other.distance_squared_to(here) < MIN_TREE_GAP * MIN_TREE_GAP:
				crowded = true
				break
		if crowded:
			continue
		spots.append(here)
		# Like a felled tree, a tree kept off a built floor still holds its spot,
		# so its neighbours do not move when a floor is registered late.
		if not cleared.is_empty() and ClearGround.covers(cleared, world_x, world_z):
			continue
		if felled != null and felled.is_felled(world_x, world_z):
			continue

		# The wood changes character as it climbs rather than merely thinning:
		# mixed at the bottom, all spruce by the middle slopes, and stunted
		# where it gives out. Both numbers come from the height field, so the
		# planting and anything else that asks about the mountainside agree.
		var conifer_bias := HeightField.conifer_share(local.y)
		var vigour := HeightField.tree_vigour(local.y)
		out.append({
			"position": Vector3(world_x, local.y, world_z),
			# One mesh per species, so the crown is made broader one way than the
			# other: a tenth wider along one axis and as much narrower across it,
			# so the trunk keeps its girth. Taken from the digits of `spin` that
			# its turn does not notice, which costs no new draw and moves no tree.
			# Scaled before it is turned, so it is the tree's own axes that differ.
			"transform": Transform3D(
				Basis(Vector3.UP, spin * TAU) * Basis.from_scale(Vector3(
					scale * vigour * lerpf(0.9, 1.1, fposmod(spin * 97.0, 1.0)),
					scale * stretch * vigour,
					scale * vigour / lerpf(0.9, 1.1, fposmod(spin * 97.0, 1.0))
				)),
				local
			),
			"conifer": species < conifer_bias,
			"scale": scale * vigour,
			"radius": trunk_radius(species < conifer_bias, scale * vigour),
		})
	return out

## How wide a trunk is where a child's body meets it, a metre above the ground,
## for a tree of the given horizontal scale: the mesh's own taper, scaled, and a
## hand's breadth over so that being stopped short reads as solid.
static func trunk_radius(conifer: bool, horizontal_scale: float) -> float:
	var height := CONIFER_HEIGHT if conifer else BROADLEAF_HEIGHT
	var base := 0.05 if conifer else 0.07
	var top := 0.012 if conifer else 0.035
	var long := 0.92 if conifer else 0.52
	var drawn := lerpf(base, top, clampf(1.0 / (long * height), 0.0, 1.0)) * height
	# And the flare at the foot, which is wider than the trunk a metre up and is
	# what a child's boots actually meet: measured where the ground cuts it, a
	# little above the tree's sunken origin. Taken from the trunk alone, the solid
	# trunk was narrower than the bark at the base and a child stood inside it. A
	# flare is a six-sided prism, so its flat sides sit a tenth in from the
	# corners the mesh's radius names.
	var flare_foot := 0.09 if conifer else 0.12
	var flare_span := 0.16 * height
	var along := clampf((ROOT_DEPTH + flare_span * 0.5) / flare_span, 0.0, 1.0)
	var at_ground := lerpf(flare_foot, base, along) * height
	return maxf(
		maxf(drawn * horizontal_scale + 0.06, at_ground * horizontal_scale * 0.9 + 0.04),
		MIN_TRUNK_RADIUS
	)

func _add_layer(
	mesh: Mesh,
	material: ShaderMaterial,
	transforms: Array[Transform3D],
	tile_size: int,
	height_allowance: float,
	casts_shadow: bool,
	fade_distance: float
) -> void:
	if transforms.is_empty():
		return

	var multimesh := MultiMesh.new()
	# Order matters and is unforgiving: transform_format defaults to 2D, and both
	# it and use_colors are ignored once instance_count has been set. Get this
	# wrong and the layer renders as nothing at all, with no error.
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh

	var lowest := INF
	var highest := -INF
	for transform in transforms:
		lowest = minf(lowest, transform.origin.y)
		highest = maxf(highest, transform.origin.y)
	# Given bounds up front, the engine skips rebuilding them from the instances.
	multimesh.custom_aabb = AABB(
		Vector3(0.0, lowest - 1.0, 0.0),
		Vector3(float(tile_size), highest - lowest + height_allowance, float(tile_size))
	)

	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		# A slight per-instance tint so a stand of one mesh does not read as
		# stamped copies. Multiplied onto the mesh's own vertex colours.
		#
		# Chosen from where the plant stands, not from its place in the list:
		# the index gave the first tree of every tile the same tint. A second
		# draw leans it towards yellow-green or blue-green, which is what
		# tells one tree from the next at a distance.
		var at := transforms[i].origin
		var seed_at := hash(Vector3i(int(at.x * 10.0), int(at.y * 10.0), int(at.z * 10.0)))
		var shade := 0.82 + float(seed_at % 1000) * 0.00036
		var warm := float((seed_at >> 10) % 1000) * 0.001 - 0.5
		# One plant in six is a young, yellow-green one: the lighter flush of new
		# growth, which breaks up a wood of identical dark greens for nothing
		# but a colour per instance.
		var young := 0.0
		if (seed_at >> 20) % 6 == 0:
			young = 0.14
		multimesh.set_instance_color(i, Color(
			shade * (1.0 + warm * 0.30 + young),
			shade * (1.02 + young * 0.8),
			shade * (0.94 - warm * 0.26 - young * 1.6)
		))

	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	# Grass does not cast shadows. At this instance count the cost is real, and
	# thousands of tiny shadows blur into grey blotches on the ground rather
	# than reading as grass.
	instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts_shadow
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	if fade_distance > 0.0:
		# Fade the layer out over its last stretch, so the edge of the grass is
		# a horizon rather than a line drawn on the ground.
		instance.visibility_range_end = fade_distance
		instance.visibility_range_end_margin = fade_distance * 0.22
		instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(instance)
