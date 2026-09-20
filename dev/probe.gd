extends SceneTree
func _initialize() -> void:
	var f := HeightField.new(20260903)
	for box: Array in [
		[50.0, 92.0, 18.0, -150.0],
		[48.0, 88.0, 16.0, -140.0],
		[52.0, 90.0, 18.0, -160.0],
	]:
		var lo := INF
		var hi := -INF
		var steepest := 0.0
		var wet := 0
		var x: float = box[0]
		while x <= box[1]:
			var z: float = box[3]
			while z <= box[2]:
				var h := f.height_at(x, z)
				lo = minf(lo, h)
				hi = maxf(hi, h)
				steepest = maxf(steepest, f.steepness_at(x, z))
				if h < HeightField.WATER_LEVEL + 0.5:
					wet += 1
				z += 4.0
			x += 4.0
		print("box x[%.0f..%.0f] z[%.0f..%.0f]: low %.1f high %.1f steepest %.2f wet %d" % [
			box[0], box[1], box[3], box[2], lo, hi, steepest, wet])
	print("river centre at z=18: ", f.river_centre_x(18.0), " z=-150: ", f.river_centre_x(-150.0))
	quit(0)
