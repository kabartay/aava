class_name PartIcon
extends Control

## A tiny drawing of anything a child can build, for the palette.
##
## The palette used single characters — "|" for a wall, "n" for a door, "z" for
## stairs — which are unreadable. A child cannot be expected to decode a letter
## into a roof, and an icon he has to be taught is an icon that does not work.
## The house parts were given pictures first and the objects were left behind,
## so a sapling was a "T", a fir an "A" and a bird feeder a "Y": the same
## problem, one row further along.
##
## These are drawn with the 2D primitives rather than rendered from the 3D mesh:
## a viewport per button would cost eight extra render passes to show eight
## thumbnails, and a wall seen head-on is a rectangle either way. What matters is
## that the silhouette is the one he will see in the world.

const WALL_COLOR := Color(0.88, 0.85, 0.78)
const TIMBER := Color(0.52, 0.37, 0.22)
const ROOF_COLOR := Color(0.72, 0.35, 0.30)
const GLASS := Color(0.55, 0.78, 0.90)
const STONE := Color(0.62, 0.61, 0.60)
const DARK := Color(0.24, 0.20, 0.16)
const LEAF := Color(0.35, 0.62, 0.30)
const LEAF_DEEP := Color(0.22, 0.45, 0.24)
const EARTH := Color(0.44, 0.33, 0.22)
const FLAME := Color(0.96, 0.62, 0.20)
const EMBER := Color(0.88, 0.32, 0.18)
const SEED := Color(0.92, 0.78, 0.34)

var kind: StringName

func _init(part_kind: StringName) -> void:
	kind = part_kind
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	# Everything is drawn inside a square with a small margin, so pieces of
	# different proportions still read as a set.
	var box := Rect2(size * 0.16, size * 0.68)
	match kind:
		HouseParts.WALL:
			_wall(box)
		HouseParts.WALL_DOOR:
			_wall(box)
			_opening(box, 0.34, 0.52, 1.0, DARK)
			# A handle, so the hole is a door and not a hole.
			draw_circle(
				Vector2(box.get_center().x + box.size.x * 0.12, box.position.y + box.size.y * 0.78),
				maxf(1.5, box.size.x * 0.035), SEED
			)
		HouseParts.WALL_WINDOW:
			_wall(box)
			_opening(box, 0.30, 0.30, 0.42, GLASS)
			# Glazing bars: a pane with a cross in it is unmistakably a window.
			var pane := Rect2(
				Vector2(box.get_center().x - box.size.x * 0.15, box.position.y + box.size.y * 0.30),
				Vector2(box.size.x * 0.30, box.size.y * 0.12)
			)
			draw_line(Vector2(pane.get_center().x, pane.position.y), Vector2(pane.get_center().x, pane.end.y), WALL_COLOR, 1.5)
			draw_line(Vector2(pane.position.x, pane.get_center().y), Vector2(pane.end.x, pane.get_center().y), WALL_COLOR, 1.5)
		HouseParts.FLOOR:
			_floor(box)
		HouseParts.ROOF:
			_lean_to(box)
		HouseParts.ROOF_PEAK:
			_gable(box)
		HouseParts.STAIRS:
			_stairs(box)
		HouseParts.POST:
			_post(box)
		HouseParts.BED:
			_bed(box)
		BuildKinds.SAPLING:
			_sapling(box)
		BuildKinds.PINE:
			_fir(box)
		BuildKinds.FEEDER:
			_feeder(box)
		BuildKinds.PATH:
			_path(box)
		BuildKinds.FENCE:
			_fence(box)
		BuildKinds.CAMPFIRE:
			_campfire(box)

## Whether this is something the palette can draw. The checks walk every
## buildable kind through it, so a piece added without a picture is caught
## here rather than as a blank square on a child's screen — which is how the
## bed went a whole afternoon.
static func knows(part_kind: StringName) -> bool:
	return HouseParts.INFO.has(part_kind) or BuildKinds.INFO.has(part_kind)

## A sapling: a mound of earth, a thin stem, two leaves. Small on purpose —
## next to the fir it has to read as the little one.
func _sapling(box: Rect2) -> void:
	var foot := Vector2(box.get_center().x, box.end.y)
	draw_colored_polygon(PackedVector2Array([
		foot + Vector2(-box.size.x * 0.30, 0.0),
		foot + Vector2(box.size.x * 0.30, 0.0),
		foot + Vector2(box.size.x * 0.18, -box.size.y * 0.10),
		foot + Vector2(-box.size.x * 0.18, -box.size.y * 0.10),
	]), EARTH)
	var top := foot + Vector2(0.0, -box.size.y * 0.62)
	draw_line(foot + Vector2(0.0, -box.size.y * 0.06), top, TIMBER, maxf(2.0, box.size.x * 0.07))
	for side in PackedFloat32Array([-1.0, 1.0]):
		var leaf := PackedVector2Array([
			top + Vector2(0.0, box.size.y * 0.06),
			top + Vector2(side * box.size.x * 0.34, -box.size.y * 0.04),
			top + Vector2(side * box.size.x * 0.10, -box.size.y * 0.18),
		])
		draw_colored_polygon(leaf, LEAF)

## A fir: three tiers on a short trunk, the shape of the tree it becomes.
func _fir(box: Rect2) -> void:
	var centre := box.get_center().x
	draw_rect(Rect2(
		Vector2(centre - box.size.x * 0.06, box.end.y - box.size.y * 0.18),
		Vector2(box.size.x * 0.12, box.size.y * 0.18)
	), TIMBER)
	for i in 3:
		var t := float(i) / 3.0
		var half := box.size.x * (0.42 - 0.09 * float(i))
		var top := box.position.y + box.size.y * (0.02 + 0.26 * float(i))
		var base := top + box.size.y * 0.34
		draw_colored_polygon(PackedVector2Array([
			Vector2(centre, top),
			Vector2(centre + half, base),
			Vector2(centre - half, base),
		]), LEAF_DEEP.lerp(LEAF, t))

## A bird feeder: a little house on a post with a perch and seed in it.
func _feeder(box: Rect2) -> void:
	var centre := box.get_center().x
	draw_rect(Rect2(
		Vector2(centre - box.size.x * 0.05, box.get_center().y),
		Vector2(box.size.x * 0.10, box.size.y * 0.5)
	), TIMBER)
	var tray := Rect2(
		Vector2(box.position.x + box.size.x * 0.12, box.get_center().y - box.size.y * 0.06),
		Vector2(box.size.x * 0.76, box.size.y * 0.12)
	)
	draw_rect(tray, TIMBER)
	# Seed on the tray, which is what says "food" rather than "birdhouse".
	for i in 3:
		draw_circle(
			Vector2(tray.position.x + tray.size.x * (0.25 + 0.25 * float(i)), tray.position.y - box.size.y * 0.03),
			maxf(1.5, box.size.x * 0.045), SEED
		)
	# The roof over it.
	draw_colored_polygon(PackedVector2Array([
		Vector2(centre, box.position.y),
		Vector2(box.end.x - box.size.x * 0.06, box.position.y + box.size.y * 0.26),
		Vector2(box.position.x + box.size.x * 0.06, box.position.y + box.size.y * 0.26),
	]), ROOF_COLOR)

## A path: flat stones going away from you, smaller as they go.
func _path(box: Rect2) -> void:
	for i in 4:
		var t := float(i) / 3.0
		var width := box.size.x * lerpf(0.72, 0.26, t)
		var height := box.size.y * lerpf(0.17, 0.08, t)
		var y := box.end.y - box.size.y * lerpf(0.06, 0.72, t)
		draw_rect(Rect2(
			Vector2(box.get_center().x - width * 0.5, y - height * 0.5),
			Vector2(width, height)
		), STONE.lerp(EARTH, t * 0.5))

## A fence: two posts and two rails between them.
func _fence(box: Rect2) -> void:
	var thickness := maxf(2.0, box.size.x * 0.09)
	for side in PackedFloat32Array([0.18, 0.82]):
		draw_rect(Rect2(
			Vector2(box.position.x + box.size.x * side - thickness * 0.5, box.position.y + box.size.y * 0.12),
			Vector2(thickness, box.size.y * 0.82)
		), TIMBER)
	for rail in 2:
		var y := box.position.y + box.size.y * (0.34 + 0.26 * float(rail))
		draw_rect(Rect2(
			Vector2(box.position.x + box.size.x * 0.08, y),
			Vector2(box.size.x * 0.84, thickness * 0.8)
		), TIMBER.lightened(0.12))

## A campfire: two logs crossed, a flame over them.
func _campfire(box: Rect2) -> void:
	var centre := Vector2(box.get_center().x, box.end.y - box.size.y * 0.16)
	var reach := box.size.x * 0.40
	var thickness := maxf(2.5, box.size.x * 0.10)
	draw_line(centre + Vector2(-reach, reach * 0.30), centre + Vector2(reach, -reach * 0.30), TIMBER, thickness)
	draw_line(centre + Vector2(-reach, -reach * 0.30), centre + Vector2(reach, reach * 0.30), TIMBER, thickness)
	# The flame: a leaf-shaped tongue with a brighter heart.
	var tip := Vector2(box.get_center().x, box.position.y + box.size.y * 0.06)
	draw_colored_polygon(PackedVector2Array([
		tip,
		centre + Vector2(box.size.x * 0.26, -box.size.y * 0.06),
		centre + Vector2(0.0, -box.size.y * 0.02),
		centre + Vector2(-box.size.x * 0.26, -box.size.y * 0.06),
	]), EMBER)
	draw_colored_polygon(PackedVector2Array([
		tip + Vector2(0.0, box.size.y * 0.16),
		centre + Vector2(box.size.x * 0.13, -box.size.y * 0.06),
		centre + Vector2(-box.size.x * 0.13, -box.size.y * 0.06),
	]), FLAME)

## A low frame with a pillow at one end, seen from the side. Drawn last among
## the icons because it was the last part added, and the palette went a whole
## afternoon showing a blank square for it before anyone noticed.
func _bed(box: Rect2) -> void:
	var frame := Rect2(
		Vector2(box.position.x, box.get_center().y),
		Vector2(box.size.x, box.size.y * 0.30)
	)
	draw_rect(frame, WALL_COLOR)
	draw_rect(frame, DARK, false, 1.5)

	# A pillow at the left end, standing a little proud of the blanket — the one
	# detail that says which end a head goes at.
	var pillow := Rect2(
		Vector2(frame.position.x + frame.size.x * 0.04, frame.position.y - frame.size.y * 0.28),
		Vector2(frame.size.x * 0.26, frame.size.y * 0.5)
	)
	draw_rect(pillow, Color(0.94, 0.93, 0.90))

	# Short legs, so it reads as furniture standing on a floor rather than a
	# plank floating in the square.
	for side: float in [0.08, 0.92]:
		var leg := Rect2(
			Vector2(frame.position.x + frame.size.x * side - 2.0, frame.end.y),
			Vector2(4.0, box.size.y * 0.14)
		)
		draw_rect(leg, DARK)

func _wall(box: Rect2) -> void:
	draw_rect(box, WALL_COLOR)
	# Planking, so the face is boards rather than a blank panel.
	for i in 3:
		var y := box.position.y + box.size.y * (0.25 + 0.25 * float(i))
		draw_line(Vector2(box.position.x, y), Vector2(box.end.x, y), WALL_COLOR.darkened(0.12), 1.5)
	# Corner timbers, which is what makes a plain rectangle read as a wall.
	var post := box.size.x * 0.16
	draw_rect(Rect2(box.position, Vector2(post, box.size.y)), TIMBER)
	draw_rect(Rect2(Vector2(box.end.x - post, box.position.y), Vector2(post, box.size.y)), TIMBER)
	draw_rect(Rect2(Vector2(box.position.x, box.get_center().y - post * 0.3),
		Vector2(box.size.x, post * 0.6)), TIMBER)

## A hole in a wall: door if it reaches the floor, window if it does not.
func _opening(box: Rect2, width: float, top: float, bottom: float, colour: Color) -> void:
	var w := box.size.x * width
	var y := box.position.y + box.size.y * top
	var h := box.size.y * (bottom - top)
	draw_rect(Rect2(Vector2(box.get_center().x - w * 0.5, y), Vector2(w, h)), colour)

func _floor(box: Rect2) -> void:
	var slab := Rect2(
		Vector2(box.position.x, box.get_center().y - box.size.y * 0.12),
		Vector2(box.size.x, box.size.y * 0.24)
	)
	draw_rect(slab, TIMBER)
	# Board lines, so it is a floor rather than a beam.
	for i in 3:
		var x := slab.position.x + slab.size.x * (0.25 + 0.25 * float(i))
		draw_line(Vector2(x, slab.position.y), Vector2(x, slab.end.y), DARK, 1.5)

func _gable(box: Rect2) -> void:
	var apex := Vector2(box.get_center().x, box.position.y)
	var left := Vector2(box.position.x, box.end.y)
	var right := Vector2(box.end.x, box.end.y)
	draw_colored_polygon(PackedVector2Array([apex, right, left]), ROOF_COLOR)
	# Courses of tile down each slope, which is what tells a gable from a
	# plain triangle.
	for i in 3:
		var t := 0.3 + 0.24 * float(i)
		draw_line(apex.lerp(left, t), apex.lerp(right, t), ROOF_COLOR.darkened(0.18), 1.5)
	draw_line(left, right, DARK, 2.0)

func _lean_to(box: Rect2) -> void:
	var points := PackedVector2Array([
		Vector2(box.position.x, box.end.y),
		Vector2(box.end.x, box.position.y + box.size.y * 0.25),
		Vector2(box.end.x, box.position.y + box.size.y * 0.55),
		Vector2(box.position.x, box.end.y),
	])
	draw_colored_polygon(points, ROOF_COLOR)
	# Two courses along the slope, for the same reason the gable has them.
	var high := Vector2(box.end.x, box.position.y + box.size.y * 0.32)
	var low := Vector2(box.position.x, box.end.y)
	for i in 2:
		var t := 0.34 + 0.3 * float(i)
		draw_line(low.lerp(high, t) + Vector2(0.0, box.size.y * 0.02), low.lerp(high, t) + Vector2(0.0, box.size.y * 0.10), ROOF_COLOR.darkened(0.18), 1.5)

func _stairs(box: Rect2) -> void:
	var steps := 4
	for i in steps:
		var t := float(i) / float(steps)
		var w := box.size.x / float(steps)
		var h := box.size.y * (t + 1.0 / float(steps))
		draw_rect(Rect2(
			Vector2(box.position.x + w * float(i), box.end.y - h),
			Vector2(w, h)
		), STONE)

func _post(box: Rect2) -> void:
	var w := box.size.x * 0.26
	draw_rect(Rect2(Vector2(box.get_center().x - w * 0.5, box.position.y), Vector2(w, box.size.y)), TIMBER)
