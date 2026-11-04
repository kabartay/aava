class_name MapTool
extends Button

## A round button on the map that says what it does with a picture, since the
## children it is for cannot all read: a plus, a minus, and a target for "back to
## me".

enum Kind {PLUS, MINUS, ME, CLOSE}

## A thumb-sized target by default; the map sets the real side for its size.
const SIZE := 72.0

var kind: Kind
var _face: StyleBoxFlat
var _held: StyleBoxFlat

func _init(which: Kind) -> void:
	kind = which
	focus_mode = Control.FOCUS_NONE
	var face := StyleBoxFlat.new()
	_face = face
	face.bg_color = Color(0.07, 0.09, 0.12, 0.82)
	face.border_color = Color(1.0, 1.0, 1.0, 0.45)
	face.set_border_width_all(2)
	var held := face.duplicate() as StyleBoxFlat
	_held = held
	held.bg_color = Color(0.25, 0.30, 0.38, 0.92)
	add_theme_stylebox_override("normal", face)
	add_theme_stylebox_override("hover", face)
	add_theme_stylebox_override("pressed", held)
	add_theme_stylebox_override("focus", face)
	set_side(SIZE)

## Make the button this many pixels across, round.
func set_side(side: float) -> void:
	if is_equal_approx(side, size.x):
		return
	custom_minimum_size = Vector2(side, side)
	size = Vector2(side, side)
	_face.set_corner_radius_all(int(side * 0.5))
	_held.set_corner_radius_all(int(side * 0.5))
	queue_redraw()

func _draw() -> void:
	var middle := size * 0.5
	var ink := Color(1.0, 0.96, 0.85)
	var arm := size.x * 0.24
	match kind:
		Kind.PLUS:
			draw_line(middle - Vector2(arm, 0.0), middle + Vector2(arm, 0.0), ink, 4.0)
			draw_line(middle - Vector2(0.0, arm), middle + Vector2(0.0, arm), ink, 4.0)
		Kind.MINUS:
			draw_line(middle - Vector2(arm, 0.0), middle + Vector2(arm, 0.0), ink, 4.0)
		Kind.CLOSE:
			var reach := arm * 0.8
			draw_line(middle - Vector2(reach, reach), middle + Vector2(reach, reach), ink, 4.0)
			draw_line(middle - Vector2(reach, -reach), middle + Vector2(reach, -reach), ink, 4.0)
		_:
			draw_arc(middle, arm * 0.9, 0.0, TAU, 24, ink, 3.0)
			draw_circle(middle, arm * 0.35, ink)
			for turn: int in [0, 1, 2, 3]:
				var way := Vector2.from_angle(float(turn) * PI * 0.5)
				draw_line(middle + way * arm * 1.1, middle + way * arm * 1.55, ink, 3.0)
