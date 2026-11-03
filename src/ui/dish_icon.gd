class_name DishIcon
extends Control

## A tiny drawing of a dish on the café's menu, for the tiles a child taps.
##
## The same six things the board on the café's wall shows, drawn the same way
## round — side on, in the same colours — so that the picture on the wall and
## the picture on the screen are plainly the same dish to somebody who cannot
## read either. Drawn with 2D primitives, as ShopIcon is.

const CHINA := Color(0.96, 0.96, 0.94)
const ORANGE := Color(0.98, 0.64, 0.16)
const GOLDEN := Color(0.88, 0.62, 0.28)
const PINK := Color(0.94, 0.50, 0.58)
const CREAM := Color(0.98, 0.92, 0.74)
const CHERRY := Color(0.80, 0.12, 0.14)
const BLUE := Color(0.30, 0.50, 0.82)
const CHEESE := Color(0.98, 0.80, 0.30)

var dish: StringName

func _init(which: StringName) -> void:
	dish = which
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	# custom_minimum_size, not size, for the reason ShopIcon gives.
	var extent := custom_minimum_size if custom_minimum_size.x > 0.0 else size
	var unit := minf(extent.x, extent.y) * 0.5
	var c := extent * 0.5
	match dish:
		Dishes.JUICE:
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-0.42, -0.30) * unit, c + Vector2(0.42, -0.30) * unit,
				c + Vector2(0.32, 0.72) * unit, c + Vector2(-0.32, 0.72) * unit,
			]), ORANGE)
			draw_line(c + Vector2(0.1, -0.2) * unit, c + Vector2(0.38, -0.85) * unit, Color(0.88, 0.26, 0.28), unit * 0.1)
			draw_circle(c + Vector2(0.42, -0.30) * unit, unit * 0.2, Color(0.98, 0.86, 0.46))
		Dishes.ICE_CREAM:
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-0.38, 0.0) * unit, c + Vector2(0.38, 0.0) * unit, c + Vector2(0.0, 0.88) * unit,
			]), Color(0.86, 0.66, 0.38))
			draw_circle(c + Vector2(0.0, -0.08) * unit, unit * 0.42, CREAM)
			draw_circle(c + Vector2(0.0, -0.5) * unit, unit * 0.34, PINK)
			draw_circle(c + Vector2(0.06, -0.86) * unit, unit * 0.12, CHERRY)
		Dishes.PANCAKE:
			for layer in 3:
				var y := 0.28 - float(layer) * 0.26
				draw_rect(Rect2(c + Vector2(-0.72, y) * unit, Vector2(1.44, 0.26) * unit), GOLDEN if layer % 2 == 0 else Color(0.98, 0.76, 0.40))
			draw_rect(Rect2(c + Vector2(-0.52, -0.58) * unit, Vector2(1.04, 0.1) * unit), Color(0.62, 0.30, 0.10))
			draw_rect(Rect2(c + Vector2(-0.18, -0.8) * unit, Vector2(0.36, 0.22) * unit), Color(0.98, 0.90, 0.46))
		Dishes.SOUP:
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-0.8, -0.1) * unit, c + Vector2(0.8, -0.1) * unit,
				c + Vector2(0.4, 0.62) * unit, c + Vector2(-0.4, 0.62) * unit,
			]), CHINA)
			draw_rect(Rect2(c + Vector2(-0.72, 0.1) * unit, Vector2(1.44, 0.14) * unit), BLUE)
			draw_rect(Rect2(c + Vector2(-0.8, -0.22) * unit, Vector2(1.6, 0.14) * unit), Color(0.90, 0.50, 0.20))
			for puff in 3:
				draw_circle(c + Vector2(-0.3 + float(puff) * 0.3, -0.55 - float(puff % 2) * 0.2) * unit, unit * 0.13, Color(1.0, 1.0, 1.0, 0.8))
		Dishes.PIZZA:
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-0.62, -0.62) * unit, c + Vector2(0.62, -0.62) * unit, c + Vector2(0.0, 0.8) * unit,
			]), CHEESE)
			draw_rect(Rect2(c + Vector2(-0.68, -0.78) * unit, Vector2(1.36, 0.22) * unit), Color(0.80, 0.56, 0.28))
			for spot: Vector2 in [Vector2(-0.22, -0.3), Vector2(0.24, -0.26), Vector2(0.0, 0.18)]:
				draw_circle(c + spot * unit, unit * 0.15, Color(0.72, 0.16, 0.14))
		Dishes.CAKE:
			draw_rect(Rect2(c + Vector2(-0.7, -0.05) * unit, Vector2(1.4, 0.7) * unit), CREAM)
			draw_rect(Rect2(c + Vector2(-0.76, -0.3) * unit, Vector2(1.52, 0.28) * unit), Color(0.90, 0.40, 0.48))
			draw_rect(Rect2(c + Vector2(-0.06, -0.78) * unit, Vector2(0.12, 0.5) * unit), BLUE)
			draw_circle(c + Vector2(0.0, -0.9) * unit, unit * 0.12, Color(1.0, 0.84, 0.30))
			draw_circle(c + Vector2(-0.45, -0.32) * unit, unit * 0.12, CHERRY)
			draw_circle(c + Vector2(0.45, -0.32) * unit, unit * 0.12, CHERRY)
