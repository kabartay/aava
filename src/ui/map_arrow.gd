class_name MapArrow
extends Control

## Where you are on the map, and which way you are facing.
##
## A round dot can say where but not which way, so the map had to turn — or, as
## it actually was, the compass mark had to turn while the map stood still,
## which read as neither. An arrow says both at once and lets everything else
## stay put.

const SIZE := 20.0

func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var half := SIZE * 0.5
	# Pointing up at rest, because the map is drawn north-up and a rotation of
	# zero should mean facing north.
	var nose := Vector2(half, 1.0)
	var left := Vector2(2.0, SIZE - 2.0)
	var right := Vector2(SIZE - 2.0, SIZE - 2.0)
	var waist := Vector2(half, SIZE * 0.68)

	var shape := PackedVector2Array([nose, right, waist, left])
	draw_colored_polygon(shape, Color(1.0, 1.0, 1.0))
	# A dark edge, so it reads against both the green of the meadow and the
	# blue of the river.
	draw_polyline(shape + PackedVector2Array([nose]), Color(0.10, 0.12, 0.16), 2.0)
