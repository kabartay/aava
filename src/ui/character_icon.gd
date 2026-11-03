class_name CharacterIcon
extends Control

## A child's face and shoulders, drawn: the picture on a character's button.
##
## Choosing who to be is a row of faces and not a row of words, because the
## children choosing cannot yet read the words. Drawn from circles and polygons
## like every other icon here (there are no image files in this project), in
## the colours the child has chosen so far, so that the row is also a preview:
## change the hair and every face in the row changes with it.
##
## It is a picture of the character, not a render of the rig: at the size of a
## button a face is eyes, a smile and what is on the head, and those are the
## things that tell the five apart.

var which := Character.SIMPLE
var skin := Character.SKINS[0]
var hair := Character.HAIRS[0]
var cloth := Color(0.30, 0.47, 0.72)

const INK := Color(0.12, 0.09, 0.10)

func _init(character := Character.SIMPLE) -> void:
	which = character
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## The colours to draw it in.
func dress(skin_colour: Color, hair_colour: Color, cloth_colour: Color) -> void:
	skin = skin_colour
	hair = hair_colour
	cloth = cloth_colour
	queue_redraw()

func _draw() -> void:
	var extent := size if size.x > 0.0 else custom_minimum_size
	var unit := minf(extent.x, extent.y)
	var middle := Vector2(extent.x * 0.5, extent.y * 0.5)
	var head_at := middle + Vector2(0.0, -unit * 0.07)
	var head := unit * 0.30

	# Shoulders, cut off by the bottom of the button.
	var body := PackedVector2Array()
	for step in 13:
		var angle := PI + PI * float(step) / 12.0
		body.append(middle + Vector2(cos(angle) * unit * 0.40, unit * 0.46 + sin(angle) * unit * 0.26))
	if which == 3:
		# Dungarees: straps over the shoulders and a bib, in the colour chosen,
		# on a white T-shirt.
		draw_colored_polygon(body, Color(0.96, 0.94, 0.88))
		for side: float in [-1.0, 1.0]:
			draw_line(
				middle + Vector2(side * unit * 0.13, unit * 0.22),
				middle + Vector2(side * unit * 0.19, unit * 0.40),
				cloth, unit * 0.075
			)
		draw_rect(Rect2(middle + Vector2(-unit * 0.15, unit * 0.34), Vector2(unit * 0.30, unit * 0.2)), cloth)
	else:
		draw_colored_polygon(body, cloth)

	if which == 2:
		# Pigtails behind the head, with a bobble each.
		for side: float in [-1.0, 1.0]:
			var at := head_at + Vector2(side * head * 1.12, head * 0.35)
			draw_circle(at, head * 0.36, hair)
			draw_circle(at + Vector2(0.0, head * 0.30), head * 0.26, hair)
			draw_circle(head_at + Vector2(side * head * 0.98, -head * 0.12), head * 0.15, Color(0.96, 0.42, 0.56))
	if which == 4:
		# A hood round the face, with an ear each side.
		for side: float in [-1.0, 1.0]:
			var ear := head_at + Vector2(side * head * 0.82, -head * 0.80)
			draw_circle(ear, head * 0.38, cloth)
			draw_circle(ear, head * 0.20, Color(0.98, 0.86, 0.82))
		draw_circle(head_at, head * 1.18, cloth)
	draw_circle(head_at, head, skin)

	match which:
		1, 2:
			_hair_cap(head_at, head, 0.50 if which == 1 else 0.40)
		3:
			# The cap, dome in the clothes colour, on backwards: from the front
			# its band and a button on top.
			var dome := PackedVector2Array()
			for step in 13:
				var angle := PI + PI * float(step) / 12.0
				dome.append(head_at + Vector2(cos(angle) * head * 1.04, -head * 0.12 + sin(angle) * head * 0.98))
			draw_colored_polygon(dome, cloth)
			draw_line(
				head_at + Vector2(-head * 1.04, -head * 0.12),
				head_at + Vector2(head * 1.04, -head * 0.12),
				cloth.darkened(0.25), head * 0.16
			)
			draw_circle(head_at + Vector2(0.0, -head * 1.08), head * 0.10, cloth.darkened(0.25))
		4:
			draw_arc(head_at + Vector2(0.0, -head * 0.15), head * 0.74, PI * 1.15, PI * 1.85, 10, hair, head * 0.20)

	# The face, the same on all of them.
	for side: float in [-1.0, 1.0]:
		draw_circle(head_at + Vector2(side * head * 0.38, head * 0.08), head * 0.11, INK)
		draw_circle(head_at + Vector2(side * head * 0.38 + head * 0.03, head * 0.04), head * 0.035, Color.WHITE)
		draw_circle(head_at + Vector2(side * head * 0.62, head * 0.40), head * 0.12, skin.lerp(Color(1.0, 0.45, 0.45), 0.4))
	draw_arc(head_at + Vector2(0.0, head * 0.22), head * 0.34, PI * 0.18, PI * 0.82, 8, Color(0.62, 0.16, 0.16), maxf(1.5, head * 0.07))

## Hair across the top of the head, down to a hairline.
func _hair_cap(at: Vector2, head: float, fringe: float) -> void:
	var top := PackedVector2Array()
	# Over the top of the head down to where the hairline meets each side...
	var reach := asin(fringe / 1.06)
	for step in 13:
		var angle := PI + reach + (PI - 2.0 * reach) * float(step) / 12.0
		top.append(at + Vector2(cos(angle) * head * 1.06, sin(angle) * head * 1.06))
	# ...and back along it, lower on the forehead in the middle.
	var edge := cos(reach) * 1.06
	for step in 1 + 6:
		var across := 1.0 - float(step) / 3.0
		top.append(at + Vector2(across * head * edge, -head * fringe * (0.55 + 0.45 * absf(across))))
	draw_colored_polygon(top, hair)
