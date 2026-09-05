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

## Whether this tile was planted with grass. Read by the manager to decide if a
## tile that has come closer needs replanting.
var has_grass := false

func _init(
	field: HeightField,
	coord: Vector2i,
	tile_size: int,
	world_seed: int,
	conifer: Mesh,
	broadleaf: Mesh,
	grass: Mesh,
	tree_material: ShaderMaterial,
	grass_material: ShaderMaterial,
	with_grass: bool,
	felled: Felled,
	stump: Mesh
) -> void:
	var origin_x := float(coord.x * tile_size)
	var origin_z := float(coord.y * tile_size)
	position = Vector3(origin_x, 0.0, origin_z)

	# Placement is a pure function of the world seed and the tile coordinate, so
	# a tile that streams out and back in comes back identical. Anything else
	# means the forest rearranges itself behind the player's back.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(world_seed, coord.x, coord.y))

	var conifers: Array[Transform3D] = []
	var broadleaves: Array[Transform3D] = []
	for placed in generate_trees(field, coord, tile_size, world_seed, felled):
		var transform: Transform3D = placed["transform"]
		if placed["conifer"]:
			conifers.append(transform)
		else:
			broadleaves.append(transform)

	_add_layer(conifer, tree_material, conifers, tile_size, 24.0, true, 0.0)
	_add_layer(broadleaf, tree_material, broadleaves, tile_size, 24.0, true, 0.0)

	# A stump wherever this tile would have drawn a tree that has been felled.
	if felled != null and felled.count() > 0 and stump != null:
		var stumps: Array[Transform3D] = []
		for gone in generate_trees(field, coord, tile_size, world_seed, null):
			var at: Vector3 = gone["position"]
			if not felled.is_felled(at.x, at.z):
				continue
			stumps.append(Transform3D(
				Basis(Vector3.UP, float(stumps.size()) * 1.1),
				Vector3(at.x - origin_x, at.y, at.z - origin_z)
			))
		if not stumps.is_empty():
			_add_layer(stump, tree_material, stumps, tile_size, 24.0, true, 0.0)

	if not with_grass:
		return

	var tufts: Array[Transform3D] = []
	for _i in GRASS_CANDIDATES:
		var local := Vector3(rng.randf() * tile_size, 0.0, rng.randf() * tile_size)
		var world_x := origin_x + local.x
		var world_z := origin_z + local.z
		var height := field.height_at(world_x, world_z)
		if height < HeightField.WATER_LEVEL + 0.35 or height > HeightField.TREELINE:
			continue
		if field.steepness_at(world_x, world_z) > 0.5:
			continue
		# Nothing grows on a mown pitch. Grass tufts are placed by their own
		# rule rather than by forest density, so suppressing trees there was
		# not enough — long grass came straight up through the markings.
		if Pitch.is_levelled(world_x, world_z):
			continue
		# And none on a trodden path, for the same reason: grass placed by its
		# own rule comes straight up through anything the terrain painted.
		if field.path_at(world_x, world_z) > 0.35:
			continue
		# Nor in a lake: grass placed by its own rule comes straight up through
		# the water otherwise.
		if Lakes.wet(world_x, world_z):
			continue
		local.y = height
		var scale := rng.randf_range(0.75, 1.45)
		tufts.append(Transform3D(
			Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(scale, scale * rng.randf_range(0.8, 1.3), scale)),
			local
		))
	_add_layer(grass, grass_material, tufts, tile_size, 1.5, false, 74.0)

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

	for _i in TREE_CANDIDATES:
		var local := Vector3(rng.randf() * tile_size, 0.0, rng.randf() * tile_size)
		var world_x := origin_x + local.x
		var world_z := origin_z + local.z
		var density := field.forest_density_at(world_x, world_z)
		var thinned: bool = density <= 0.0 or rng.randf() > density

		# Every remaining draw happens whether or not the tree survives, so that
		# rejecting one candidate never shifts the next.
		local.y = field.height_at(world_x, world_z) - 0.15
		var scale := rng.randf_range(0.78, 1.35)
		var spin := rng.randf()
		var stretch := rng.randf_range(0.9, 1.2)
		var species := rng.randf()

		if thinned:
			continue
		if felled != null and felled.is_felled(world_x, world_z):
			continue

		# Conifers dominate high and cool, broadleaves low and warm, so the
		# treeline changes character rather than just thinning out.
		var conifer_bias := smoothstep(24.0, 68.0, local.y)
		out.append({
			"position": Vector3(world_x, local.y, world_z),
			"transform": Transform3D(
				Basis(Vector3.UP, spin * TAU).scaled(Vector3(scale, scale * stretch, scale)),
				local
			),
			"conifer": species < conifer_bias,
		})
	return out

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
		var shade := 0.86 + fmod(float(hash(i * 2654435761)) * 0.000000001, 0.28)
		multimesh.set_instance_color(i, Color(shade, shade * 1.02, shade * 0.94))

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
