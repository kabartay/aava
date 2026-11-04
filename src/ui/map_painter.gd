class_name MapPainter
extends RefCounted

## How the map is painted: the palette, the hill-shading, the shore, the forest
## canopy, the path and the footprints of the places. Pure and static, so it
## runs on the worker thread and the checks can call it directly.
##
## The valley is sampled on a CELLS-square grid, one height and a few scalars per
## cell, and then painted at SUPERSAMPLE times that: the scalars are blended
## between cells and thresholded per pixel, so a river's edge or a path is a
## smooth line rather than a staircase of nine-metre squares, and the cost of
## the picture is still the cost of the grid (the pixel work is plain arithmetic,
## the expensive height_at / forest_density_at / path_at run once per cell).
##
## Anything that wants the map at another resolution or centre (a zoomed view)
## calls `bake` with its own cells and range.

## Pixels painted per grid cell, on each axis.
const SUPERSAMPLE := 2

# --- Palette. Neighbouring classes differ in brightness, not only in hue, so the
# map still reads for a colour-blind child and in bright sunlight.
const WATER_DEEP := Color(0.09, 0.34, 0.62)
const WATER_SHALLOW := Color(0.20, 0.55, 0.80)
const FOAM := Color(0.93, 0.98, 0.98)
const SAND := Color(0.95, 0.87, 0.62)
const GRASS := Color(0.50, 0.70, 0.32)
const FOREST_DARK := Color(0.10, 0.25, 0.15)
const FOREST_MID := Color(0.16, 0.37, 0.20)
const FOREST_LIGHT := Color(0.30, 0.52, 0.26)
const ROCK := Color(0.50, 0.42, 0.37)
const SNOW := Color(0.97, 0.98, 1.0)
const PITCH := Color(0.16, 0.56, 0.22)
const PITCH_STRIPE := Color(0.12, 0.47, 0.18)
const LINE_WHITE := Color(1.0, 1.0, 1.0)
const PATH := Color(0.98, 0.72, 0.34)
const PATH_CASING := Color(0.50, 0.31, 0.14)
const FAIR_GROUND := Color(0.94, 0.82, 0.58)
const FENCE := Color(0.45, 0.28, 0.14)
const EARTH := Color(0.86, 0.68, 0.46)
const PLAZA := Color(0.96, 0.92, 0.82)
const POOL_TILE := Color(0.98, 0.97, 0.92)
const POOL_WATER := Color(0.20, 0.78, 0.86)
const ROOF_CAFE := Color(0.84, 0.31, 0.24)
const ROOF_SHOP := Color(0.24, 0.50, 0.74)
const INK := Color(0.16, 0.11, 0.07)
## What a built piece is drawn in on the map (Minimap.BUILT), for the contrast check.
const BUILT_INK := Color(1.0, 0.86, 0.42)

## Light from the north-west: x west, z north, and well above the horizon.
const LIGHT := Vector3(-0.55, 0.70, -0.55)
## How much taller the hills are drawn than they are, for the shading only.
const EXAGGERATION := 2.6
## Contour hints every this many metres above the valley floor.
const CONTOUR_STEP := 14.0
const CONTOUR_FROM := 6.0

## Region names painted over the large and full maps.
const REGION_LAKE := &"lake"
const REGION_RIVER := &"river"
const REGION_FAIR := &"fairground"
const REGION_FOREST := &"forest"
const REGION_MOUNTAINS := &"mountains"
const REGION_TEXT := {
	&"lake": "map_lake",
	&"river": "map_river",
	&"fairground": "map_fairground",
	&"forest": "map_forest",
	&"mountains": "map_mountains",
}

## The panel round the map: a warm wooden-brown board with a parchment edge and
## a soft shadow, in the manner of the game's other round-cornered things.
static func frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.20, 0.14, 0.09, 0.94)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(8.0)
	style.border_color = Color(0.96, 0.86, 0.60)
	style.set_border_width_all(3)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0.0, 2.0)
	return style

## The dark edge of a region's name, tinted to the thing it names.
static func label_outline(kind: StringName) -> Color:
	match kind:
		REGION_LAKE, REGION_RIVER:
			return Color(0.05, 0.22, 0.45)
		REGION_FOREST:
			return Color(0.05, 0.22, 0.10)
		REGION_FAIR:
			return Color(0.45, 0.16, 0.12)
		_:
			return Color(0.20, 0.17, 0.20)

## Brightness as the WCAG defines it, for telling whether two colours part.
static func luminance(c: Color) -> float:
	var channels := [c.r, c.g, c.b]
	var out := 0.0
	var weights := [0.2126, 0.7152, 0.0722]
	for i: int in 3:
		var v: float = channels[i]
		var lin := v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
		out += lin * float(weights[i])
	return out

## Contrast ratio between two colours: 1 for identical, 21 for black on white.
static func contrast(a: Color, b: Color) -> float:
	var la := luminance(a)
	var lb := luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

## How much light a slope receives relative to flat ground (1.0): above 1 when
## it faces the north-west, below 1 when it faces away. `gx` and `gz` are the
## rise per metre going east and going south.
static func lighting(gx: float, gz: float) -> float:
	var n := Vector3(-gx * EXAGGERATION, 1.0, -gz * EXAGGERATION).normalized()
	var l := LIGHT.normalized()
	var flat := l.y
	return clampf(1.0 + 1.1 * (n.dot(l) - flat), 0.55, 1.35)

## A stable pseudo-random number in 0..1 for a lattice point.
static func hash2(ix: int, iz: int) -> float:
	var n: int = (ix * 374761393 + iz * 668265263) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float((n ^ (n >> 16)) & 0xffff) / 65535.0

## The colour of the ground at a point with the lighting and the picture's
## scale applied: used by the checks; the bake does the same inline.
static func shaded(base: Color, lit: float) -> Color:
	var shade := Color(base.r * lit, base.g * lit, base.b * lit)
	if lit < 1.0:
		# Shadows go cool, as in a painted map.
		var cool := (1.0 - lit) * 0.5
		shade = shade.lerp(Color(0.25, 0.30, 0.52) * lit, cool)
	return Color(minf(shade.r, 1.0), minf(shade.g, 1.0), minf(shade.b, 1.0))

## How far a point is from the nearest worn route, in metres, or a large number
## when none is within `reach`. Plain geometry on the route table, so the
## routes can be drawn as clean lines at any scale without sampling the field.
static func path_distance(x: float, z: float, reach: float) -> float:
	var best := 1e9
	var i := 0
	var segments := Paths.SEGMENTS
	while i < segments.size():
		var ax := segments[i]
		var az := segments[i + 1]
		var bx := segments[i + 2]
		var bz := segments[i + 3]
		i += 4
		if x < minf(ax, bx) - reach or x > maxf(ax, bx) + reach:
			continue
		if z < minf(az, bz) - reach or z > maxf(az, bz) + reach:
			continue
		var abx := bx - ax
		var abz := bz - az
		var t := clampf(((x - ax) * abx + (z - az) * abz) / (abx * abx + abz * abz), 0.0, 1.0)
		var dx := x - (ax + abx * t)
		var dz := z - (az + abz * t)
		best = minf(best, sqrt(dx * dx + dz * dz))
	return best

## The routes that come within `reach` of a rectangle of the world, as a flat
## list of segment ends, so the per-pixel search has only a few to look at.
static func routes_near(box: Rect2, reach: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var wide := box.grow(reach)
	var i := 0
	var segments := Paths.SEGMENTS
	while i < segments.size():
		var a := Vector2(segments[i], segments[i + 1])
		var b := Vector2(segments[i + 2], segments[i + 3])
		i += 4
		var hull := Rect2(a, Vector2.ZERO).expand(b)
		if hull.intersects(wide):
			out.append_array(PackedFloat32Array([a.x, a.y, b.x, b.y]))
	return out

## The distance to the nearest of a short list of routes (see routes_near).
static func route_gap(routes: PackedFloat32Array, x: float, z: float) -> float:
	var best := 1e18
	var i := 0
	var count := routes.size()
	while i < count:
		var ax := routes[i]
		var az := routes[i + 1]
		var abx := routes[i + 2] - ax
		var abz := routes[i + 3] - az
		i += 4
		var t := ((x - ax) * abx + (z - az) * abz) / (abx * abx + abz * abz)
		t = 0.0 if t < 0.0 else (1.0 if t > 1.0 else t)
		var dx := x - (ax + abx * t)
		var dz := z - (az + abz * t)
		var squared := dx * dx + dz * dz
		if squared < best:
			best = squared
	return sqrt(best)

## What the football pitch looks like at a point inside it (the mown surface):
## stripes along its length, white lines round it, across the middle, a centre
## circle and the two boxes. `line` is the line width in metres.
static func pitch_colour(x: float, z: float, line: float) -> Color:
	var dx := x - Pitch.CENTRE.x
	var dz := z - Pitch.CENTRE.z
	var ax := absf(dx)
	var az := absf(dz)
	var hl := Pitch.HALF_LENGTH
	var hw := Pitch.HALF_WIDTH
	var w := line * 0.5
	if absf(ax - hl) < w or absf(az - hw) < w:
		return LINE_WHITE
	if ax < w:
		return LINE_WHITE
	if absf(Vector2(dx, dz).length() - Pitch.CENTRE_CIRCLE_RADIUS * 1.6) < w:
		return LINE_WHITE
	# The penalty boxes.
	if ax > hl - Pitch.PENALTY_DEPTH * 1.4 and az < Pitch.PENALTY_HALF_WIDTH:
		if absf(ax - (hl - Pitch.PENALTY_DEPTH * 1.4)) < w or absf(az - Pitch.PENALTY_HALF_WIDTH) < w:
			return LINE_WHITE
	return PITCH if int(floorf((dx + hl) / 5.0)) % 2 == 0 else PITCH_STRIPE

## Where footprint_at can paint anything, as boxes: the fairground, each place.
## The pixel pass looks inside a box before asking, so almost every pixel of
## almost every map skips the question.
static func footprint_boxes(camp: Vector3, line: float) -> Array[Rect2]:
	var out: Array[Rect2] = []
	out.append(Rect2(ParkSpec.WEST - line, ParkSpec.NORTH - line, ParkSpec.width() + 2.0 * line, ParkSpec.length() + 2.0 * line))
	for place: StringName in [&"pool", &"playground", &"cafe", &"shop", &"range"]:
		var c := PlaceSpec.centre_of(place, camp)
		var reach := 27.0 if place == &"range" else 20.0
		out.append(Rect2(c.x - reach, c.z - reach, reach * 2.0, reach * 2.0))
	return out

## The footprint of a place or the fairground at a point, or alpha 0 where there
## is none. `line` is the line width in metres, `pm` the metres a pixel covers.
static func footprint_at(x: float, z: float, camp: Vector3, line: float, pm: float) -> Color:
	# The fairground: trodden sand inside a fence with a gap at the gate, and
	# confetti where the rides are.
	if x > ParkSpec.WEST - line and x < ParkSpec.EAST + line and z < ParkSpec.SOUTH + line and z > ParkSpec.NORTH - line:
		var out := maxf(maxf(ParkSpec.WEST - x, x - ParkSpec.EAST), maxf(z - ParkSpec.SOUTH, ParkSpec.NORTH - z))
		var at_gate := absf(x - (ParkSpec.WEST + ParkSpec.EAST) * 0.5) < ParkSpec.GATE_WIDTH * 0.5
		if absf(out) < line * 0.9 and not (at_gate and z > ParkSpec.SOUTH - line * 2.0):
			return FENCE
		if out < 0.0:
			var cell := maxf(7.0, pm * 4.0)
			var ix := int(floorf(x / cell))
			var iz := int(floorf(z / cell))
			var jx := (hash2(ix, iz) - 0.5) * cell * 0.5
			var jz := (hash2(iz, ix + 7) - 0.5) * cell * 0.5
			var cx := (float(ix) + 0.5) * cell + jx
			var cz := (float(iz) + 0.5) * cell + jz
			if Vector2(x - cx, z - cz).length() < maxf(1.5, pm * 1.0) and hash2(ix + 3, iz + 5) > 0.45:
				var pick := int(hash2(ix, iz + 11) * 4.0)
				var confetti := [Color(0.92, 0.28, 0.32), Color(0.98, 0.78, 0.18), Color(0.30, 0.55, 0.92), Color(0.62, 0.34, 0.80)]
				return confetti[pick % 4]
			return FAIR_GROUND
	# The places, each a picture of what stands there.
	var pool := PlaceSpec.centre_of(&"pool", camp)
	var px := absf(x - pool.x)
	var pz := absf(z - pool.z)
	if px < PlaceSpec.POOL_HALF_X + 4.0 + line and pz < PlaceSpec.POOL_HALF_Z + 4.0 + line:
		if px < PlaceSpec.POOL_HALF_X and pz < PlaceSpec.POOL_HALF_Z:
			var lane := absf(fmod(absf(z - pool.z) + 100.0, 3.0))
			return POOL_WATER.lightened(0.18) if lane < line * 0.5 and px < PlaceSpec.POOL_HALF_X - 1.5 else POOL_WATER
		return POOL_TILE
	var play := PlaceSpec.centre_of(&"playground", camp)
	var pdx := x - play.x
	var pdz := z - play.z
	var pd := sqrt(pdx * pdx + pdz * pdz)
	if pd < PlaceSpec.FOOTPRINT[&"playground"] + line * 0.5:
		if pd > PlaceSpec.FOOTPRINT[&"playground"] - line * 0.8:
			return INK.lightened(0.35)
		# Four bright pieces of equipment round the middle.
		var kit := [Color(0.92, 0.30, 0.30), Color(0.98, 0.78, 0.20), Color(0.28, 0.58, 0.92), Color(0.34, 0.76, 0.40)]
		for k: int in 4:
			var angle := float(k) * TAU * 0.25 + 0.6
			var at := Vector2(cos(angle), sin(angle)) * 7.5
			if Vector2(pdx - at.x, pdz - at.y).length() < maxf(2.6, pm * 1.2):
				return kit[k]
		return EARTH
	for spec: Array in [[&"cafe", ROOF_CAFE, 9.0], [&"shop", ROOF_SHOP, 12.0]]:
		var place: StringName = spec[0]
		var centre := PlaceSpec.centre_of(place, camp)
		var half: float = spec[2]
		var bx := x - centre.x
		var bz := z - centre.z
		var roof_half := half * 0.78
		if absf(bx) < roof_half and absf(bz) < roof_half:
			var roof: Color = spec[1]
			if absf(bz) < line * 0.4:
				return roof.lightened(0.3)
			return roof if bz > 0.0 else roof.lightened(0.14)
		if absf(bx) < half + line and absf(bz) < half + line:
			if absf(bx) > roof_half and absf(bz) > roof_half or maxf(absf(bx), absf(bz)) > half - 0.2:
				return INK.lightened(0.3) if maxf(absf(bx), absf(bz)) > half - line * 0.4 else PLAZA
			return PLAZA
	var range_at := PlaceSpec.centre_of(&"range", camp)
	var rd := Vector2(x - range_at.x, z - range_at.z).length()
	if rd < 15.0 + line * 0.5:
		# A target: rings of red and white on pale ground.
		var ring := int(floorf(rd / maxf(3.0, pm * 1.5)))
		if rd > 15.0 - line * 0.8:
			return INK.lightened(0.35)
		if rd < 9.0:
			return Color(0.88, 0.22, 0.22) if ring % 2 == 0 else Color(1.0, 0.97, 0.9)
		return PLAZA
	return Color(0.0, 0.0, 0.0, 0.0)

## The sampled grid for one bake: everything the pixel pass blends between.
## Heights carry a one-cell margin all round (for the slopes); the rest cover the
## picture only.
class Grid extends RefCounted:
	var cells := 0
	var step := 1.0
	var origin := Vector2.ZERO
	var height := PackedFloat32Array()
	var wet := PackedFloat32Array()
	var forest := PackedFloat32Array()
	var lit := PackedFloat32Array()
	var slope := PackedFloat32Array()
	## The heights again, without the margin, for blending in the pixel pass.
	var inner := PackedFloat32Array()

## Sample the field. This is the whole cost of a bake apart from the pixel pass.
static func sample(field: HeightField, centre: Vector3, range_metres: float, cells: int) -> Grid:
	var g := Grid.new()
	g.cells = cells
	g.step = range_metres / float(cells)
	g.origin = Vector2(centre.x - range_metres * 0.5, centre.z - range_metres * 0.5)
	var side := cells + 2
	g.height.resize(side * side)
	g.wet.resize(cells * cells)
	g.forest.resize(cells * cells)
	g.lit.resize(cells * cells)
	g.slope.resize(cells * cells)
	g.inner.resize(cells * cells)
	for gz in range(-1, cells + 1):
		var z := g.origin.y + (float(gz) + 0.5) * g.step
		for gx in range(-1, cells + 1):
			var x := g.origin.x + (float(gx) + 0.5) * g.step
			g.height[(gz + 1) * side + gx + 1] = field.height_at(x, z)
	for gz in cells:
		var z := g.origin.y + (float(gz) + 0.5) * g.step
		for gx in cells:
			var x := g.origin.x + (float(gx) + 0.5) * g.step
			var at := (gz + 1) * side + gx + 1
			var h := g.height[at]
			var i := gz * cells + gx
			g.inner[i] = h
			var rise_x := (g.height[at + 1] - g.height[at - 1]) / (2.0 * g.step)
			var rise_z := (g.height[at + side] - g.height[at - side]) / (2.0 * g.step)
			g.lit[i] = lighting(rise_x, rise_z)
			g.slope[i] = HeightField.steepness_of_gradient(Vector2(rise_x, rise_z).length())
			if field.is_pond(x, z):
				g.wet[i] = 2.0
			else:
				g.wet[i] = clampf(HeightField.WATER_LEVEL - h, -1.0, 3.0)
			g.forest[i] = field.forest_density_at(x, z) if g.wet[i] < 0.0 else 0.0
	return g

## The whole picture as RGB bytes, cells * SUPERSAMPLE pixels square.
static func bake(field: HeightField, centre: Vector3, range_metres: float, cells: int) -> PackedByteArray:
	return paint(sample(field, centre, range_metres, cells), field.camp_centre())

## Paint a sampled grid. Pure arithmetic: no field access.
static func paint(g: Grid, camp: Vector3) -> PackedByteArray:
	var cells := g.cells
	var width := cells * SUPERSAMPLE
	var bytes := PackedByteArray()
	bytes.resize(width * width * 3)
	var pm := g.step / float(SUPERSAMPLE)
	var line := maxf(1.1, pm * 0.9)
	# A path is drawn at least as wide as a few pixels, so it is a line and not
	# a row of dashes, however far out the map is zoomed.
	var path_core := maxf(1.9, pm * 1.15)
	var path_edge := maxf(0.9, pm * 0.75)
	var view := Rect2(g.origin, Vector2(g.step * float(cells), g.step * float(cells)))
	var routes := routes_near(view, path_core + path_edge)
	var has_routes := routes.size() > 0
	var boxes := footprint_boxes(camp, line).filter(func(box: Rect2) -> bool: return box.intersects(view))
	var index := 0
	var last := cells - 1
	for py in width:
		var fz := (float(py) + 0.5) / float(SUPERSAMPLE) - 0.5
		var z := g.origin.y + (float(py) + 0.5) * pm
		var z0 := clampi(int(floorf(fz)), 0, last)
		var z1 := mini(z0 + 1, last)
		var tz := clampf(fz - float(z0), 0.0, 1.0)
		for px in width:
			var fx := (float(px) + 0.5) / float(SUPERSAMPLE) - 0.5
			var x := g.origin.x + (float(px) + 0.5) * pm
			var x0 := clampi(int(floorf(fx)), 0, last)
			var x1 := mini(x0 + 1, last)
			var tx := clampf(fx - float(x0), 0.0, 1.0)
			var a := z0 * cells + x0
			var b := z0 * cells + x1
			var c := z1 * cells + x0
			var d := z1 * cells + x1
			var wet := _blend(g.wet, a, b, c, d, tx, tz)
			var colour: Color
			if wet > 0.0:
				var depth := clampf(wet / 3.0, 0.0, 1.0)
				colour = WATER_SHALLOW.lerp(WATER_DEEP, depth)
				# A gentle drift of lighter water across the surface.
				var ripple := sin((x + z * 0.6) * 0.35) * sin((z - x * 0.4) * 0.27)
				if ripple > 0.82:
					colour = colour.lightened(0.10)
				# The shoreline: a bright rim just inside the water, whose width
				# stays about a pixel and a half at every scale.
				if wet < 0.6:
					colour = colour.lerp(FOAM, clampf(1.0 - wet / 0.6, 0.0, 1.0) * 0.95)
			else:
				var h := _blend(g.inner, a, b, c, d, tx, tz)
				var lit := _blend(g.lit, a, b, c, d, tx, tz)
				var forest := _blend(g.forest, a, b, c, d, tx, tz)
				var slope := _blend(g.slope, a, b, c, d, tx, tz)
				var path_gap := route_gap(routes, x, z) if has_routes else 1e9
				var textured := false
				if Pitch.is_in_play(x, z):
					colour = pitch_colour(x, z, line)
				elif h < HeightField.WATER_LEVEL + 1.0:
					colour = SAND
				elif h > HeightField.SNOWLINE - 10.0:
					colour = SNOW
				elif slope > 0.45:
					colour = ROCK.lerp(SNOW, clampf((h - 60.0) / 140.0, 0.0, 0.5))
				elif forest > 0.3:
					colour = _canopy(x, z, pm, lit)
					textured = true
				else:
					colour = GRASS
				if not textured:
					colour = shaded(colour, lit)
				# The bank: a thin dark-blue line on the land side of the water.
				if wet > -0.4:
					colour = colour.lerp(WATER_DEEP.darkened(0.3), 0.6)
				# Terrace hints on the high ground: thin, soft, never on the floor
				# of the valley, so the flat parts stay clean.
				if h > CONTOUR_FROM and colour != LINE_WHITE:
					var rise := (h - CONTOUR_FROM) / CONTOUR_STEP
					var fract_part := rise - floorf(rise)
					var per_pixel := maxf(slope, 0.02) * 1.8 * pm / CONTOUR_STEP * 2.0
					if fract_part < per_pixel and per_pixel < 0.5:
						colour = colour.darkened(0.16)
				# Paths: a bright warm line with a dark casing either side.
				if path_gap < path_core + path_edge and h >= HeightField.WATER_LEVEL + 0.6:
					if path_gap < path_core:
						colour = PATH.lerp(shaded(PATH, lit), 0.4)
					else:
						colour = colour.lerp(PATH_CASING, 0.9)
			for box: Rect2 in boxes:
				if box.has_point(Vector2(x, z)):
					var mark := footprint_at(x, z, camp, line, pm)
					if mark.a > 0.0:
						colour = Color(mark.r, mark.g, mark.b)
					break
			# A frame inside the picture: a dark line and a soft vignette.
			var edge := mini(mini(px, py), mini(width - 1 - px, width - 1 - py))
			if edge < 2:
				colour = colour.lerp(INK, 0.85)
			elif edge < 12:
				colour = colour.darkened(float(12 - edge) / 12.0 * 0.22)
			bytes[index] = int(clampf(colour.r, 0.0, 1.0) * 255.0)
			bytes[index + 1] = int(clampf(colour.g, 0.0, 1.0) * 255.0)
			bytes[index + 2] = int(clampf(colour.b, 0.0, 1.0) * 255.0)
			index += 3
	return bytes

static func _blend(values: PackedFloat32Array, a: int, b: int, c: int, d: int, tx: float, tz: float) -> float:
	return lerpf(lerpf(values[a], values[b], tx), lerpf(values[c], values[d], tx), tz)

## Forest as the tops of trees: round crowns, lit on the north-west side, in the
## shade between them. The crowns sit on a jittered lattice in world metres, so
## they do not move when the map is redrawn from another centre.
static func _canopy(x: float, z: float, pm: float, lit: float) -> Color:
	var period := maxf(7.0, pm * 3.4)
	var u := x / period
	var v := z / period
	var i0 := int(floorf(u))
	var j0 := int(floorf(v))
	var best := 9.0
	var best_vec := Vector2.ZERO
	var best_size := 0.6
	# Crowns sit within their own cell's middle three fifths, so only this cell
	# and the three nearest it can hold the closest crown.
	var step_i := 1 if u - float(i0) > 0.5 else -1
	var step_j := 1 if v - float(j0) > 0.5 else -1
	for dj: int in [0, step_j]:
		for di: int in [0, step_i]:
			var ci := i0 + di
			var cj := j0 + dj
			var cx := float(ci) + 0.2 + hash2(ci, cj) * 0.6
			var cz := float(cj) + 0.2 + hash2(cj + 17, ci) * 0.6
			var vec := Vector2(u - cx, v - cz)
			var dist := vec.length()
			if dist < best:
				best = dist
				best_vec = vec
				best_size = 0.5 + hash2(ci + 5, cj + 9) * 0.25
	var base := FOREST_DARK
	if best < best_size:
		var facing := clampf(0.5 - best_vec.normalized().dot(Vector2(-0.7, -0.7)) * 0.5 * (best / best_size), 0.0, 1.0)
		base = FOREST_MID.lerp(FOREST_LIGHT, facing)
		if best > best_size * 0.8:
			base = base.darkened(0.25)
	return shaded(base, lerpf(1.0, lit, 0.5))

## Where the named regions of the valley are, found from the field itself: the
## ponds and the river and the fairground from their specs, the forest and the
## mountains from a coarse scan. Returns dictionaries with `kind` (one of the
## REGION_ names) and `at` (a world position).
static func scan_regions(field: HeightField) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in Lakes.count():
		if Lakes.at(i, Lakes.POND_LONG) >= 40.0:
			out.append({"kind": REGION_LAKE, "at": Vector3(Lakes.at(i, Lakes.POND_X), 0.0, Lakes.at(i, Lakes.POND_Z))})
	var river_z := -130.0
	out.append({"kind": REGION_RIVER, "at": Vector3(field.river_centre_x(river_z), 0.0, river_z)})
	var fair := ParkSpec.centre()
	out.append({"kind": REGION_FAIR, "at": Vector3(fair.x, 0.0, fair.z)})
	# A scan on a 50 m lattice, over the playable valley.
	var n := 21
	var spacing := 50.0
	var density := PackedFloat32Array()
	var high := PackedFloat32Array()
	density.resize(n * n)
	high.resize(n * n)
	for j in n:
		for i in n:
			var x := (float(i) - 10.0) * spacing
			var z := (float(j) - 10.0) * spacing
			density[j * n + i] = field.forest_density_at(x, z)
			high[j * n + i] = field.height_at(x, z)
	var best_forest := -1.0
	var best_hills := -1.0
	var forest_at := Vector3.ZERO
	var hills_at := Vector3.ZERO
	for j in range(1, n - 1):
		for i in range(1, n - 1):
			var f := 0.0
			var hsum := 0.0
			for dj in range(-1, 2):
				for di in range(-1, 2):
					f += density[(j + dj) * n + i + di]
					hsum += high[(j + dj) * n + i + di]
			f += 4.0 * density[j * n + i]
			if f > best_forest:
				best_forest = f
				forest_at = Vector3((float(i) - 10.0) * spacing, 0.0, (float(j) - 10.0) * spacing)
			if hsum > best_hills:
				best_hills = hsum
				hills_at = Vector3((float(i) - 10.0) * spacing, 0.0, (float(j) - 10.0) * spacing)
	if best_forest > 3.0:
		out.append({"kind": REGION_FOREST, "at": forest_at})
	out.append({"kind": REGION_MOUNTAINS, "at": hills_at})
	return out

## Decide which labels there is room for. `wanted` holds Rect2s in priority
## order (most important first), already centred where each would like to be.
## Each is tried where it is and then just above and below; it is kept when the
## result lies inside `bounds` and clear of everything kept so far and of the
## `blockers`. Returns, for each, the chosen Rect2 or an empty Rect2 (size zero)
## when dropped.
static func lay_out(wanted: Array[Rect2], bounds: Rect2, blockers: Array[Rect2]) -> Array[Rect2]:
	var chosen: Array[Rect2] = []
	for want in wanted:
		var placed := Rect2()
		for lift: float in [0.0, -1.0, 1.0, -2.0, 2.0]:
			var rect := Rect2(want.position + Vector2(0.0, lift * want.size.y), want.size)
			if not bounds.encloses(rect):
				continue
			var clear := true
			for other in blockers:
				if rect.intersects(other):
					clear = false
					break
			if clear:
				for other in chosen:
					if other.size != Vector2.ZERO and rect.grow(2.0).intersects(other):
						clear = false
						break
			if clear:
				placed = rect
				break
		chosen.append(placed)
	return chosen
