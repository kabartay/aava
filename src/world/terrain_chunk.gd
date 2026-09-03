class_name TerrainChunk
extends Node3D

## One square of ground. Owns its mesh, its vertex colours and, near the player,
## its collision. Built once and never edited: when detail changes, the chunk is
## replaced rather than patched, which keeps generation a pure function of
## (coordinate, step) and impossible to get subtly out of sync.
##
## Neighbouring detail rings sample the height field at different steps, so their
## shared edges do not line up and a hairline crack appears between them. It is
## left alone deliberately: the nearest such seam is three chunks away, behind
## fog, and every attempt to hide it with a skirt produced a wall far more
## visible than the crack. If it ever does read on screen, the answer is edge
## stitching, not more geometry.

var ring: int

func _init(
	field: HeightField,
	coord: Vector2i,
	step: int,
	detail_ring: int,
	material: StandardMaterial3D,
	with_collision: bool
) -> void:
	ring = detail_ring

	var size := TerrainSpec.CHUNK_SIZE
	var origin_x := float(coord.x * size)
	var origin_z := float(coord.y * size)
	position = Vector3(origin_x, 0.0, origin_z)

	var grid := size / step + 1

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	vertices.resize(grid * grid)
	normals.resize(grid * grid)
	colors.resize(grid * grid)

	for gz in grid:
		for gx in grid:
			var local_x := float(gx * step)
			var local_z := float(gz * step)
			var world_x := origin_x + local_x
			var world_z := origin_z + local_z
			var height := field.height_at(world_x, world_z)

			var index := gz * grid + gx
			vertices[index] = Vector3(local_x, height, local_z)
			normals[index] = field.normal_at(world_x, world_z)
			colors[index] = _tint(field, world_x, world_z, height)

	for gz in grid - 1:
		for gx in grid - 1:
			var a := gz * grid + gx
			var b := a + 1
			var c := a + grid
			var d := c + 1
			# Winding matters: Godot culls back faces, and the mirror image of this
			# order renders the ground inside-out — the terrain simply vanishes
			# when seen from above, which looks exactly like it was never built.
			indices.append_array(PackedInt32Array([a, b, c, b, d, c]))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(visual)

	if with_collision:
		_add_collision(field, origin_x, origin_z, size)

## Collision is a separate, always-full-resolution heightmap. Detail rings exist
## to save triangles on screen; the player must never fall through a hill because
## the ground they are standing on happened to be drawn coarsely.
func _add_collision(field: HeightField, origin_x: float, origin_z: float, size: int) -> void:
	var samples := size + 1
	var data := PackedFloat32Array()
	data.resize(samples * samples)
	for z in samples:
		for x in samples:
			data[z * samples + x] = field.height_at(origin_x + float(x), origin_z + float(z))

	var shape := HeightMapShape3D.new()
	shape.map_width = samples
	shape.map_depth = samples
	shape.map_data = data

	var collider := CollisionShape3D.new()
	collider.shape = shape
	# A HeightMapShape3D is centred on its own origin, so it has to be nudged to
	# the middle of the chunk whose corner this node sits on.
	collider.position = Vector3(float(size) * 0.5, 0.0, float(size) * 0.5)

	var body := StaticBody3D.new()
	body.add_child(collider)
	add_child(body)

func _tint(field: HeightField, x: float, z: float, height: float) -> Color:
	var steep := field.steepness_at(x, z)
	var color := TerrainSpec.COLOR_GRASS

	# Meadow tint breaks up the green so the valley floor is not one flat colour.
	color = color.lerp(TerrainSpec.COLOR_MEADOW, clampf((height - 1.0) / 14.0, 0.0, 1.0))

	# A beach follows the water line wherever it goes.
	var shore := 1.0 - smoothstep(0.2, 2.6, height - HeightField.WATER_LEVEL)
	color = color.lerp(TerrainSpec.COLOR_SAND, clampf(shore, 0.0, 1.0))

	# Rock where nothing could root.
	color = color.lerp(TerrainSpec.COLOR_ROCK, smoothstep(0.35, 0.75, steep))

	# Snow on the peaks, and only where it would settle.
	var snow := smoothstep(96.0, 150.0, height) * (1.0 - smoothstep(0.6, 0.95, steep))
	color = color.lerp(TerrainSpec.COLOR_SNOW, clampf(snow, 0.0, 1.0))

	return color
