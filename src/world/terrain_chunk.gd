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

## What this chunk was actually built with, so the streamer can compare.
var step := 1
var has_collision := false

func _init(
	field: HeightField,
	coord: Vector2i,
	step: int,
	detail_ring: int,
	material: StandardMaterial3D,
	with_collision: bool
) -> void:
	ring = detail_ring
	# Kept so the streamer can tell whether a rebuild would actually improve
	# anything, rather than rebuilding whenever the ring number changes.
	self.step = step
	has_collision = with_collision

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

	# The height field is sampled once per point and everything else is derived
	# from that grid.
	#
	# It used to ask the field nine times for every vertex: once for the height,
	# four inside normal_at, and four more inside steepness_at while choosing a
	# colour. At 3.5 µs a call that came to 35 ms of work for a single chunk, and
	# on a tablet it showed up as the game stopping for a moment every time new
	# ground streamed in — which is most of the time while a child is walking.
	#
	# One extra ring of samples is taken all the way round, so the vertices on
	# the chunk's own edge still have neighbours to take a slope from and the
	# seams between chunks stay smooth.
	var padded := grid + 2
	# One call for the whole grid, so the field can test once per chunk whether
	# the pitch, the places, the lakes or the paths reach it at all — instead of
	# asking that question again for every vertex.
	var heights := field.fill_grid(
		origin_x - float(step), origin_z - float(step), float(step), padded
	)

	var span := float(step) * 2.0
	for gz in grid:
		for gx in grid:
			var local_x := float(gx * step)
			var local_z := float(gz * step)
			var world_x := origin_x + local_x
			var world_z := origin_z + local_z

			var here := (gz + 1) * padded + (gx + 1)
			var height := heights[here]

			# The same central difference normal_at computes analytically, taken
			# from the grid instead. Cheaper, and identical at these spacings.
			var dx := heights[here + 1] - heights[here - 1]
			var dz := heights[here + padded] - heights[here - padded]
			var slope := Vector2(dx, dz).length() / span

			var index := gz * grid + gx
			vertices[index] = Vector3(local_x, height, local_z)
			normals[index] = Vector3(-dx, span, -dz).normalized()
			colors[index] = _tint(field, world_x, world_z, height, slope)

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
		_add_collision(field, origin_x, origin_z, size, step, heights, padded)

## Collision is always at full resolution. Detail rings exist to save triangles
## on screen; the player must never fall through a hill because the ground they
## are standing on happened to be drawn coarsely.
##
## Where the mesh is already at full resolution — the innermost ring, which is
## the one a child is nearly always standing in and the one rebuilt most often
## as they walk — its grid is reused rather than the field being asked for the
## same 4,225 heights a second time. That was eight of the twenty-two
## milliseconds a near chunk cost to build.
func _add_collision(
	field: HeightField, origin_x: float, origin_z: float, size: int,
	step: int, heights: PackedFloat32Array, padded: int
) -> void:
	var samples := size + 1
	var data := PackedFloat32Array()
	data.resize(samples * samples)

	if step == 1:
		# The mesh sampled these very points, with one ring of padding round the
		# outside; the collision grid is that array with the padding dropped.
		for z in samples:
			for x in samples:
				data[z * samples + x] = heights[(z + 1) * padded + (x + 1)]
	else:
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

## `slope` is passed in rather than asked of the field, because the caller has
## already worked it out from the grid it sampled — see the note there.
func _tint(field: HeightField, x: float, z: float, height: float, slope: float) -> Color:
	# The pitch is painted before anything else and returns immediately: none of
	# the natural tinting below — shore sand, rock on slopes, snow — has any
	# business on a mown surface.
	var pitch := Pitch.influence(x, z)
	if pitch > 0.5 and Pitch.is_levelled(x, z):
		return _pitch_tint(x, z)

	var steep := slope
	var color := TerrainSpec.COLOR_GRASS

	# Meadow tint breaks up the green so the valley floor is not one flat colour.
	color = color.lerp(TerrainSpec.COLOR_MEADOW, clampf((height - 1.0) / 14.0, 0.0, 1.0))

	# A beach follows the water line wherever it goes.
	var shore := 1.0 - smoothstep(0.05, 1.15, height - HeightField.WATER_LEVEL)
	color = color.lerp(TerrainSpec.COLOR_SAND, clampf(shore, 0.0, 1.0))

	# Rock where nothing could root.
	color = color.lerp(TerrainSpec.COLOR_ROCK, smoothstep(0.35, 0.75, steep))

	# A trodden path, over the natural tinting but under the snow: a route
	# through the meadow is bare earth, and a route over a peak would still be
	# under snow.
	var path := field.path_at(x, z)
	if path > 0.0:
		color = color.lerp(TerrainSpec.COLOR_PATH, path)

	# Snow on the peaks, and only where it would settle.
	# Snow begins above the treeline, not below it. It used to start at 96 m
	# while trees grew to 140, so there was a band of forest standing in snow.
	var snow := smoothstep(HeightField.TREELINE + 8.0, HeightField.TREELINE + 70.0, height) * (1.0 - smoothstep(0.6, 0.95, steep))
	color = color.lerp(TerrainSpec.COLOR_SNOW, clampf(snow, 0.0, 1.0))

	return color

## Mown stripes, touchlines, halfway line, centre circle and penalty spots.
##
## The markings are painted into the terrain's vertex colours rather than laid
## on as decals or a separate mesh. That costs nothing to draw and can never
## drift out of alignment with the ground — but it does mean a line is only as
## crisp as the vertex spacing, which is why the pitch sits where terrain is
## sampled every metre.
func _pitch_tint(x: float, z: float) -> Color:
	var centre := Pitch.centre()
	var local_x := x - centre.x
	var local_z := z - centre.z

	# Stripes run goal to goal, the way a mower drives up and down a pitch.
	var stripe := int(floor((local_x + TerrainSpec.STRIPE_WIDTH * 64.0) / TerrainSpec.STRIPE_WIDTH))
	var color := (
		TerrainSpec.COLOR_PITCH_LIGHT if stripe % 2 == 0
		else TerrainSpec.COLOR_PITCH_DARK
	)

	if not Pitch.is_in_play(x, z):
		# Outside the touchline the grass is the same, just unpainted.
		return color

	var half := TerrainSpec.LINE_WIDTH * 0.5
	var painted := false

	# Touchlines and goal lines.
	if absf(absf(local_x) - Pitch.HALF_LENGTH) < half:
		painted = true
	if absf(absf(local_z) - Pitch.HALF_WIDTH) < half:
		painted = true

	# The halfway line.
	if absf(local_x) < half:
		painted = true

	# The centre circle.
	var from_centre := Vector2(local_x, local_z).length()
	if absf(from_centre - 5.6) < half:
		painted = true

	# The centre spot and the two penalty spots.
	if from_centre < 0.28:
		painted = true
	var sides := PackedFloat32Array([-1.0, 1.0])
	for sign in sides:
		if Vector2(local_x - sign * (Pitch.HALF_LENGTH - 6.5), local_z).length() < 0.28:
			painted = true

	# Penalty areas.
	for sign in sides:
		var area_x: float = sign * (Pitch.HALF_LENGTH - 9.0)
		if absf(local_x - area_x) < half and absf(local_z) < 8.4:
			painted = true
		if absf(absf(local_z) - 8.4) < half and (local_x - area_x) * sign < 0.0 and absf(local_x) <= Pitch.HALF_LENGTH:
			painted = true

	return TerrainSpec.COLOR_PITCH_LINE if painted else color
