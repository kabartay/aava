class_name MapRoute
extends Control

## What the map adds to the picture to show the way: a "you are here" ring round
## the child's arrow, a dotted line from them to the place they chose with a
## pulsing ring on that place, and a thin stem from any sticker that had to be
## moved aside back to the spot it stands for.
##
## It lies under the stickers and over the ground, and takes no touches.

var player_at := Vector2.ZERO
var target_at := Vector2.ZERO
var target_radius := 20.0
var has_target := false
## Pairs of true spot and where the sticker was moved to, flattened.
var stems := PackedVector2Array()
var _time := 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_state(you: Vector2, goal: Vector2, goal_radius: float, goal_shown: bool, moved: PackedVector2Array) -> void:
	player_at = you
	target_at = goal
	target_radius = goal_radius
	has_target = goal_shown
	stems = moved

## Breathes only while somebody can see it: a shut map used to run this every
## frame to return at its first line, and a node that is not processing is not
## asked at all.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_ENTER_TREE:
		set_process(is_visible_in_tree())

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	queue_redraw()

func _draw() -> void:
	var edge := Color(0.0, 0.0, 0.0, 0.5)
	var ink := Color(1.0, 1.0, 1.0, 0.95)
	for pair in range(0, stems.size() - 1, 2):
		draw_line(stems[pair], stems[pair + 1], edge, 3.0)
		draw_line(stems[pair], stems[pair + 1], ink, 1.5)
		draw_circle(stems[pair], 3.5, edge)
		draw_circle(stems[pair], 2.5, ink)

	# You are here: a soft ring, breathing, round the arrow.
	var breath := 0.5 + 0.5 * sin(_time * 3.0)
	draw_arc(player_at, 24.0 + 3.0 * breath, 0.0, TAU, 28, edge, 5.0)
	draw_arc(player_at, 24.0 + 3.0 * breath, 0.0, TAU, 28, Color(1.0, 0.95, 0.5, 0.95), 3.0)

	if not has_target:
		return
	var way := target_at - player_at
	var length := way.length()
	if length > 30.0:
		var step := 14.0
		var along := way / length
		var start := 30.0
		var end := length - target_radius - 4.0
		var phase := fposmod(_time * 14.0, step)
		var s := start + phase
		while s < end:
			draw_circle(player_at + along * s, 3.6, edge)
			draw_circle(player_at + along * s, 2.6, ink)
			s += step
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	draw_arc(target_at, target_radius + 3.0 + 4.0 * pulse, 0.0, TAU, 32, edge, 6.0)
	draw_arc(target_at, target_radius + 3.0 + 4.0 * pulse, 0.0, TAU, 32, Color(1.0, 0.92, 0.35), 3.5)
