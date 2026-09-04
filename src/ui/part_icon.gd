class_name PartIcon
extends Control

## A tiny drawing of a building piece, for the palette.
##
## The palette used single characters — "|" for a wall, "n" for a door, "z" for
## stairs — which are unreadable. A child cannot be expected to decode a letter
## into a roof, and an icon he has to be taught is an icon that does not work.
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
		HouseParts.WALL_WINDOW:
			_wall(box)
			_opening(box, 0.30, 0.30, 0.42, GLASS)
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

func _wall(box: Rect2) -> void:
	draw_rect(box, WALL_COLOR)
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
	draw_line(left, right, DARK, 2.0)

func _lean_to(box: Rect2) -> void:
	var points := PackedVector2Array([
		Vector2(box.position.x, box.end.y),
		Vector2(box.end.x, box.position.y + box.size.y * 0.25),
		Vector2(box.end.x, box.position.y + box.size.y * 0.55),
		Vector2(box.position.x, box.end.y),
	])
	draw_colored_polygon(points, ROOF_COLOR)

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
