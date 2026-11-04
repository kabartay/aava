class_name MapCompass
extends Control

## Which way is north, as a picture rather than a letter: a round badge with a
## snow-capped peak at its top. A three-year-old cannot read "N", but can find
## the mountain, and the great mountain really does stand to the north.

const SIZE := 30.0

func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var mid := Vector2(SIZE, SIZE) * 0.5
	draw_circle(mid, SIZE * 0.5, Color(0.20, 0.14, 0.09, 0.9))
	draw_circle(mid, SIZE * 0.5 - 1.5, Color(0.98, 0.93, 0.78))
	# Tick marks at east, south and west.
	var tick := Color(0.45, 0.30, 0.16)
	for dir: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		draw_circle(mid + dir * (SIZE * 0.5 - 4.5), 1.5, tick)
	# A big peak and a small one, both with snow.
	var base := mid.y + 6.0
	var rock := Color(0.42, 0.40, 0.52)
	draw_colored_polygon(PackedVector2Array([Vector2(mid.x - 9.0, base), Vector2(mid.x - 4.0, mid.y - 1.0), Vector2(mid.x + 1.0, base)]), rock.lightened(0.15))
	var peak := PackedVector2Array([Vector2(mid.x - 5.0, base), Vector2(mid.x + 1.5, mid.y - 9.5), Vector2(mid.x + 8.0, base)])
	draw_colored_polygon(peak, rock)
	draw_colored_polygon(PackedVector2Array([Vector2(mid.x + 1.5, mid.y - 9.5), Vector2(mid.x + 4.2, mid.y - 4.0), Vector2(mid.x + 1.5, mid.y - 5.6), Vector2(mid.x - 1.4, mid.y - 3.8)]), Color.WHITE)
