class_name NoteIcon
extends Control

## The small picture that stands beside an announcement.
##
## A three-year-old cannot read the line, so for them an announcement used to be
## a sound and nothing else. This is the part a non-reader can see: a cross for
## "no", a coin with a cross for "not enough coins", a coin with a plus for a
## reward, the hold ring for "hold it". Built from the pieces the interface
## already draws (CoinIcon, ItemChip, ActionIcon), on a dark disc so that it
## reads over sky as well as over grass. Never tappable.

## What the picture shows. NONE draws nothing.
enum Kind { NONE, CROSS, COIN_CROSS, COIN_PLUS, ITEM_CROSS, HOLD, ACTION }

## Side of the picture, in pixels.
const SIDE := 52.0

const RED := Color(0.95, 0.32, 0.30)
const GREEN := Color(0.40, 0.88, 0.50)
const DISC := Color(0.07, 0.09, 0.12, 0.62)

var kind: Kind = Kind.NONE

## The mark laid over the picture (a cross or a plus), as its own child so that
## it draws above the coin or the item beneath it.
class Mark:
	extends Control

	var plus := false
	var big := false
	var ring := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var unit := minf(size.x, size.y)
		if ring:
			# The hold ring, part-filled, as the buttons that must be held show it.
			var middle := size * 0.5
			draw_arc(middle, unit * 0.34, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.30), 5.0, true)
			draw_arc(middle, unit * 0.34, -PI * 0.5, -PI * 0.5 + TAU * 0.7, 32, Color(0.36, 0.86, 0.46), 5.0, true)
			return
		var centre := size * 0.5 if big else Vector2(size.x * 0.76, size.y * 0.76)
		var arm := unit * (0.26 if big else 0.14)
		var width := unit * (0.12 if big else 0.09)
		var colour := GREEN if plus else RED
		if not big:
			draw_circle(centre, arm * 1.7, Color(0.07, 0.09, 0.12, 0.9))
		if plus:
			draw_line(centre - Vector2(arm, 0.0), centre + Vector2(arm, 0.0), colour, width, true)
			draw_line(centre - Vector2(0.0, arm), centre + Vector2(0.0, arm), colour, width, true)
		else:
			draw_line(centre - Vector2(arm, arm), centre + Vector2(arm, arm), colour, width, true)
			draw_line(centre - Vector2(arm, -arm), centre + Vector2(arm, -arm), colour, width, true)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(SIDE, SIDE)
	size = Vector2(SIDE, SIDE)
	visible = false

## Show a picture, or none. `item` names the thing for ITEM_CROSS and
## `action` the glyph for ACTION. Rebuilt only when it differs from what is
## already shown: an announcement said again keeps its picture.
func show_kind(which: Kind, item: StringName = &"", action: int = 0) -> void:
	var key := "%d:%s:%d" % [which, item, action]
	if which == kind and key == str(get_meta(&"key", "")):
		visible = which != Kind.NONE
		return
	set_meta(&"key", key)
	kind = which
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	visible = which != Kind.NONE
	var inner := Rect2(SIDE * 0.14, SIDE * 0.14, SIDE * 0.72, SIDE * 0.72)
	match which:
		Kind.CROSS:
			_add_mark(false, true, false)
		Kind.COIN_CROSS:
			_add(CoinIcon.new(), inner)
			_add_mark(false, false, false)
		Kind.COIN_PLUS:
			_add(CoinIcon.new(), inner)
			_add_mark(true, false, false)
		Kind.ITEM_CROSS:
			_add(ItemChip.new(item), inner)
			_add_mark(false, false, false)
		Kind.HOLD:
			_add_mark(false, false, true)
		Kind.ACTION:
			_add(ActionIcon.new(action as ActionIcon.Kind), inner)
	queue_redraw()

func _add(piece: Control, box: Rect2) -> void:
	piece.position = box.position
	piece.size = box.size
	piece.custom_minimum_size = box.size
	add_child(piece)

func _add_mark(plus: bool, big: bool, ring: bool) -> void:
	var mark := Mark.new()
	mark.plus = plus
	mark.big = big
	mark.ring = ring
	mark.size = Vector2(SIDE, SIDE)
	add_child(mark)

func _draw() -> void:
	if kind == Kind.NONE:
		return
	draw_circle(size * 0.5, SIDE * 0.5, DISC)
