class_name DistantLand
extends Node3D

## The valley beyond where the ground is streamed: one coarse mesh out to the
## far mountains, in a single draw call.
##
## The streamed terrain reaches nine chunks — a little under six hundred
## metres — and beyond that there was nothing at all. From a hilltop that is
## what a child sees: a band of ground, a band of water, and then sky where a
## valley ought to be. A person on a hill sees the far side of a valley; the
## game showed the edge of its own memory.
##
## Filling that in with more streamed chunks is the obvious answer and the
## wrong one: reaching a kilometre would be a couple of thousand chunks, and
## on a phone draw calls cost far more than triangles. This is one mesh
## instead — a ring from where the streamed ground ends out to the far
## mountains, sampled coarsely, rebuilt on a worker thread when the child has
## walked far enough to notice, and drawn in one call.
##
## It has no collision and no detail. Nothing out there is walked on: by the
## time a child gets there, the streamed ground has caught up and this ring
## has moved out ahead of them again.

## Where the ring starts and ends, in metres. The inner edge sits inside the
## streamed ground's own reach so no seam of sky shows between them.
const INNER := 430.0
const OUTER := 2100.0

## How far apart the samples are. A mountain three quarters of a kilometre
## away is a silhouette; forty metres between samples is plenty for one, and
## keeps the whole ring to a few thousand triangles.
const STEP := 40.0

## How far the child walks before the ring is built again. A quarter of the
## step is imperceptible at this distance and keeps the rebuilds rare.
const REBUILD_AFTER := 120.0

var field: HeightField

var _mesh: MeshInstance3D
var _material: StandardMaterial3D
var _built_at := Vector3(1e9, 1e9, 1e9)
var _wanted_at := Vector3.ZERO
var _task := -1
var _baked: Dictionary = {}
var _mutex := Mutex.new()

func _init(height_field: HeightField) -> void:
	name = "DistantLand"
	field = height_field
	# Built here rather than in _ready, for the usual reason: a headless check
	# uses this without ever starting the scene tree. See LESSONS.md.
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.roughness = 0.95
	# No shadows either way: this is scenery, and a mesh two kilometres across
	# in the shadow pass costs more than everything it is standing behind.
	_mesh = MeshInstance3D.new()
	_mesh.material_override = _material
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)

## Where the child is. The ring is rebuilt around them when they have walked
## far enough for the old one to be visibly off-centre.
func follow(world_position: Vector3) -> void:
	_wanted_at = world_position
	_collect()
	if _task >= 0:
		return
	if world_position.distance_to(_built_at) < REBUILD_AFTER:
		return
	_start(world_position)

func _start(centre: Vector3) -> void:
	# Snapped to the sample grid, so the ring's vertices land on the same
	# points from one rebuild to the next and the horizon does not crawl.
	var snapped := Vector3(
		snappedf(centre.x, STEP), 0.0, snappedf(centre.z, STEP)
	)
	_built_at = snapped
	_task = WorkerThreadPool.add_task(_bake.bind(snapped), false, "distant land")

## The ring, sampled on a worker thread: the height field is read-only once
## built, so this touches nothing the game is using.
func _bake(centre: Vector3) -> void:
	var across := int(OUTER * 2.0 / STEP) + 1
	var vertices := PackedVector3Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	# One row of heights at a time, so a point is sampled once rather than
	# four times over as the neighbouring quads ask for it.
	var index_of: Dictionary = {}
	for gz in across:
		var z := centre.z - OUTER + float(gz) * STEP
		for gx in across:
			var x := centre.x - OUTER + float(gx) * STEP
			var out := maxf(absf(x - centre.x), absf(z - centre.z))
			if out < INNER or out > OUTER:
				continue
			var height := field.height_at(x, z)
			index_of[Vector2i(gx, gz)] = vertices.size()
			vertices.append(Vector3(x - centre.x, height, z - centre.z))
			colours.append(_colour(height, x, z))

	for gz in across - 1:
		for gx in across - 1:
			var a = index_of.get(Vector2i(gx, gz))
			var b = index_of.get(Vector2i(gx + 1, gz))
			var c = index_of.get(Vector2i(gx, gz + 1))
			var d = index_of.get(Vector2i(gx + 1, gz + 1))
			if a == null or b == null or c == null or d == null:
				continue
			# The winding the terrain uses; the mirror of it is invisible from
			# above, which is a whole afternoon written down in LESSONS.md.
			indices.append_array(PackedInt32Array([a, b, c, b, d, c]))

	_mutex.lock()
	_baked = {"vertices": vertices, "colours": colours, "indices": indices, "centre": centre}
	_mutex.unlock()

## The colour of far ground: the same story the terrain tells — water, sand,
## grass, rock, snow — without the paths, pitches and places, none of which
## can be told apart at this distance.
func _colour(height: float, x: float, z: float) -> Color:
	if height < HeightField.WATER_LEVEL:
		return TerrainSpec.COLOR_SILT
	var steep := field.steepness_at(x, z)
	var colour := TerrainSpec.COLOR_GRASS.lerp(
		TerrainSpec.COLOR_MEADOW, clampf((height - 1.0) / 14.0, 0.0, 1.0)
	)
	colour = colour.lerp(TerrainSpec.COLOR_SAND, clampf(1.0 - smoothstep(0.05, 1.15, height), 0.0, 1.0))
	# Far forest reads as a darkening of the hillside rather than as trees.
	colour = colour.lerp(
		TerrainSpec.COLOR_FOREST_FAR, clampf(field.forest_density_at(x, z), 0.0, 1.0) * 0.8
	)
	colour = colour.lerp(
		TerrainSpec.COLOR_PASTURE,
		smoothstep(HeightField.CONIFER_TOP, HeightField.TREELINE + 6.0, height)
	)
	var bare := maxf(
		smoothstep(0.35, 0.75, steep),
		smoothstep(HeightField.PASTURE_TOP - 26.0, HeightField.PASTURE_TOP, height)
	)
	colour = colour.lerp(TerrainSpec.COLOR_ROCK, clampf(bare, 0.0, 1.0))
	var snow := (
		smoothstep(HeightField.SNOWLINE - 22.0, HeightField.SNOWLINE + 14.0, height)
		* (1.0 - smoothstep(0.42, 0.78, steep))
	)
	colour = colour.lerp(TerrainSpec.COLOR_SNOW, clampf(snow, 0.0, 1.0))
	var ice := (
		smoothstep(HeightField.SNOWLINE + 10.0, HeightField.SNOWLINE + 46.0, height)
		* (1.0 - smoothstep(0.16, 0.38, steep))
	)
	return colour.lerp(TerrainSpec.COLOR_ICE, clampf(ice, 0.0, 1.0))

## Take a finished ring, if there is one.
func _collect() -> void:
	if _task < 0 or not WorkerThreadPool.is_task_completed(_task):
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_mutex.lock()
	var baked := _baked
	_baked = {}
	_mutex.unlock()
	if baked.is_empty():
		return
	_show(baked)

## Wait for the ring, for a check or a screenshot that wants it now.
func wait_for_it() -> void:
	if _task < 0:
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_mutex.lock()
	var baked := _baked
	_baked = {}
	_mutex.unlock()
	if not baked.is_empty():
		_show(baked)

func _show(baked: Dictionary) -> void:
	var vertices: PackedVector3Array = baked["vertices"]
	var indices: PackedInt32Array = baked["indices"]
	if vertices.is_empty() or indices.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = baked["colours"]
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# Flat shading: the normals of a forty-metre quad are meaningless, and
	# facets are what a distant hillside looks like anyway.
	var tool := SurfaceTool.new()
	tool.create_from(mesh, 0)
	tool.generate_normals()
	_mesh.mesh = tool.commit()
	_mesh.position = baked["centre"]

## How many triangles the far country costs. For the checks.
func triangle_count() -> int:
	if _mesh.mesh == null:
		return 0
	return _mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3

## Whether anything is drawn yet.
func is_drawn() -> bool:
	return _mesh.mesh != null
