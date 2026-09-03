extends SceneTree

## Headless numeric probe. Renders nothing: it prints the numbers a screenshot
## can only hint at, so geometry and colour bugs get diagnosed by measurement
## rather than by staring at an image.

func _initialize() -> void:
	var field := HeightField.new(20260903)

	print("--- height / steepness / tint across the valley")
	for z in PackedFloat32Array([-100.0, -40.0, 0.0, 40.0, 100.0]):
		var row := PackedStringArray()
		for x in PackedFloat32Array([-100.0, -40.0, 0.0, 40.0, 100.0]):
			var h := field.height_at(x, z)
			var steep := field.steepness_at(x, z)
			row.append("h%5.1f s%.2f" % [h, steep])
		print("z=%6.1f | %s" % [z, " | ".join(row)])

	print("--- tint at a few spots (as the mesh stores it)")
	var chunk := TerrainChunk.new(field, Vector2i(0, 0), 4, 2, StandardMaterial3D.new(), false)
	var arrays := (chunk.get_child(0) as MeshInstance3D).mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var grid := 17
	for pick in [0, grid * 4 + 4, grid * 8 + 8, grid * 12 + 12, grid * 16 + 16]:
		print("  v%-5d pos=%v  n=%v  color=%s" % [pick, vertices[pick], normals[pick], colors[pick]])

	print("--- how much of a chunk is each tint")
	var buckets := {"green": 0, "rock": 0, "sand": 0, "snow": 0, "other": 0}
	for c in colors:
		if c.g > c.r * 1.25 and c.g > c.b * 1.25:
			buckets["green"] += 1
		elif absf(c.r - c.g) < 0.06 and absf(c.g - c.b) < 0.06 and c.r < 0.7:
			buckets["rock"] += 1
		elif c.r > 0.7 and c.g > 0.7 and c.b > 0.7:
			buckets["snow"] += 1
		elif c.r > c.b * 1.3:
			buckets["sand"] += 1
		else:
			buckets["other"] += 1
	print("  ", buckets, " of ", colors.size())

	quit()
