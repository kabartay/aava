class_name FlagIcon
extends Control

## The flag of a language, drawn.
##
## The languages were three words in a column — "English", "Français",
## "Русский" — which is a reading task standing between a child and the button
## that makes the game readable. A six-year-old who cannot yet read the word
## "Русский" can pick the white-blue-red one out of four without being taught,
## and can find it again next time.
##
## Drawn from polygons like everything else here: there are no image files in
## this project, and a flag fetched from anywhere would be the first.
##
## A flag is not a language — English is spoken in a great many places that are
## not Britain — but for a child choosing between four buttons it is the one
## picture that is unmistakable, which is the whole job.

enum Kind {ENGLISH, FRENCH, RUSSIAN, CIRCASSIAN}

const RIM := Color(0.0, 0.0, 0.0, 0.45)

## Which flag a language is offered under.
##
## Matched against the code rather than against Text's own constants, because
## Text is loaded before this and a const in one class_name script that reads
## another's enum will not resolve — and a cycle between the two would hang the
## loader outright. See LESSONS.md.
static func for_language(code: StringName) -> Kind:
	match code:
		&"fr":
			return Kind.FRENCH
		&"ru":
			return Kind.RUSSIAN
		&"ad":
			return Kind.CIRCASSIAN
		_:
			return Kind.ENGLISH

var kind: Kind = Kind.ENGLISH

func _init(which: Kind) -> void:
	kind = which
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	match kind:
		Kind.ENGLISH:
			_union_jack(box)
		Kind.FRENCH:
			_bands(box, [
				Color8(0, 85, 164), Color8(255, 255, 255), Color8(239, 65, 53)
			], true)
		Kind.RUSSIAN:
			_bands(box, [
				Color8(255, 255, 255), Color8(0, 57, 166), Color8(213, 43, 30)
			], false)
		Kind.CIRCASSIAN:
			_circassian(box)
	# A thin dark edge, so a flag with white in it still has a shape against
	# the panel behind it.
	draw_rect(box, RIM, false, 1.0)

## Three stripes, either standing up (France) or lying down (Russia).
func _bands(box: Rect2, colours: Array, upright: bool) -> void:
	for i in colours.size():
		var part := float(i) / float(colours.size())
		var next := float(i + 1) / float(colours.size())
		var at := (
			Rect2(
				Vector2(box.position.x + box.size.x * part, box.position.y),
				Vector2(box.size.x * (next - part), box.size.y)
			) if upright
			else Rect2(
				Vector2(box.position.x, box.position.y + box.size.y * part),
				Vector2(box.size.x, box.size.y * (next - part))
			)
		)
		draw_rect(at, colours[i])

## The Union Jack: the two saltires under the upright cross, in that order,
## which is the order they are actually layered in.
func _union_jack(box: Rect2) -> void:
	var white := Color8(255, 255, 255)
	var red := Color8(200, 16, 46)
	draw_rect(box, Color8(1, 33, 105))

	var w := box.size.x
	var h := box.size.y
	var corner_a := PackedVector2Array([
		box.position, box.position + Vector2(w, h)
	])
	var corner_b := PackedVector2Array([
		box.position + Vector2(w, 0.0), box.position + Vector2(0.0, h)
	])
	# The diagonals, white and then red down the middle of the white.
	for line: PackedVector2Array in [corner_a, corner_b]:
		draw_line(line[0], line[1], white, h * 0.26)
	for line: PackedVector2Array in [corner_a, corner_b]:
		draw_line(line[0], line[1], red, h * 0.11)

	# And the upright cross over the top of both.
	draw_rect(Rect2(box.position + Vector2(0.0, h * 0.34), Vector2(w, h * 0.32)), white)
	draw_rect(Rect2(box.position + Vector2(w * 0.34, 0.0), Vector2(w * 0.32, h)), white)
	draw_rect(Rect2(box.position + Vector2(0.0, h * 0.41), Vector2(w, h * 0.18)), red)
	draw_rect(Rect2(box.position + Vector2(w * 0.41, 0.0), Vector2(w * 0.18, h)), red)

## The Circassian flag: twelve gold stars over three crossed arrows, on green.
##
## Nine of the stars stand in an arc and three in a line beneath it, one for
## each of the twelve princedoms, and the three arrows stand upright beneath
## them. There is no country to take a flag from for Adyghe and Kabardian, and
## this is the flag those languages have.
func _circassian(box: Rect2) -> void:
	var gold := Color8(255, 203, 5)
	draw_rect(box, Color8(0, 128, 62))

	var w := box.size.x
	var h := box.size.y
	var star := minf(w, h) * 0.068

	# The arc of nine, swept over the upper half and flattened, because the arc
	# on the flag is a shallow bow across a wide field rather than half a
	# circle — drawn as a true semicircle on a flag half as tall as it is wide
	# the end stars fall almost to the bottom of it.
	var bow := box.position + Vector2(w * 0.5, h * 0.62)
	for i in 9:
		var angle := PI * (1.0 - float(i) / 8.0)
		_star(bow + Vector2(cos(angle) * w * 0.37, -sin(angle) * h * 0.4), star, gold)

	# The three under the bow, in a line.
	for i in 3:
		_star(
			box.position + Vector2(w * (0.365 + 0.135 * float(i)), h * 0.42),
			star, gold
		)

	# And the three arrows standing under them, heads up, fanned from one point
	# so that the shafts cross.
	var foot := box.position + Vector2(w * 0.5, h * 0.95)
	for i in 3:
		var head := box.position + Vector2(
			w * (0.5 + 0.145 * (float(i) - 1.0)), h * 0.62
		)
		var along := (head - foot).normalized()
		var across := Vector2(-along.y, along.x)
		draw_line(foot, head, gold, maxf(1.0, h * 0.028))
		draw_colored_polygon(PackedVector2Array([
			head,
			head - along * (h * 0.13) + across * (w * 0.038),
			head - along * (h * 0.13) - across * (w * 0.038),
		]), gold)

## A five-pointed star, point upwards.
func _star(at: Vector2, radius: float, colour: Color) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var reach := radius if i % 2 == 0 else radius * 0.42
		var angle := -PI * 0.5 + TAU * float(i) / 10.0
		points.append(at + Vector2(cos(angle), sin(angle)) * reach)
	draw_colored_polygon(points, colour)
