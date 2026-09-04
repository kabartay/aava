class_name VitalsGauge
extends Control

## Energy and water, drawn together under the coin count.
##
## A number from 0 to 100 would be exact and useless: the six-year-old cannot
## read it and the ten-year-old would have to stop and interpret it. A bar that
## drains and a bottle that empties are read at a glance without being taught.
##
## Both are drawn against custom_minimum_size rather than size, because inside a
## container this control has no size when _draw first runs. See LESSONS.md.

const WIDTH := 176.0
const HEIGHT := 52.0

const TRACK := Color(0.16, 0.18, 0.22, 0.78)
const FULL := Color(0.52, 0.86, 0.48)
const LOW := Color(0.94, 0.72, 0.32)
const EMPTY := Color(0.90, 0.42, 0.38)
const GLASS := Color(0.80, 0.88, 0.94, 0.85)
const WATER := Color(0.38, 0.66, 0.86)
const OUTLINE := Color(0.06, 0.08, 0.11, 0.85)

var energy := 1.0
var water := 0.0
var show_bottle := false

func _init() -> void:
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_energy(fraction: float) -> void:
	energy = clampf(fraction, 0.0, 1.0)
	queue_redraw()

func set_water(fraction: float, carried: bool) -> void:
	water = clampf(fraction, 0.0, 1.0)
	show_bottle = carried
	queue_redraw()

func _draw() -> void:
	var extent := custom_minimum_size if custom_minimum_size.x > 0.0 else size
	var bottle_room := extent.x * 0.24 if show_bottle else 0.0
	var bar := Rect2(0.0, extent.y * 0.30, extent.x - bottle_room, extent.y * 0.40)

	draw_rect(bar, TRACK)
	if energy > 0.0:
		# Green while there is plenty, amber as it runs down, red when running
		# has stopped being possible — the colour is the warning, not a message.
		var tint := FULL
		if energy < 0.16:
			tint = EMPTY
		elif energy < 0.38:
			tint = LOW
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * energy, bar.size.y)), tint)
	draw_rect(bar, OUTLINE, false, 1.5)

	if show_bottle:
		_bottle(Rect2(
			extent.x - bottle_room + 6.0, 0.0,
			bottle_room - 6.0, extent.y
		))

## The same bottle as the shop icon, so the thing bought and the thing carried
## are visibly the same object.
func _bottle(box: Rect2) -> void:
	var neck_w := box.size.x * 0.30
	draw_rect(Rect2(
		box.position.x + (box.size.x - neck_w) * 0.5, box.position.y,
		neck_w, box.size.y * 0.20
	), GLASS)

	var body := Rect2(
		box.position.x + box.size.x * 0.14, box.position.y + box.size.y * 0.20,
		box.size.x * 0.72, box.size.y * 0.80
	)
	draw_rect(body, GLASS)
	if water > 0.0:
		var depth := body.size.y * water
		draw_rect(Rect2(
			body.position.x, body.position.y + body.size.y - depth,
			body.size.x, depth
		), WATER)
	draw_rect(body, OUTLINE, false, 1.5)
