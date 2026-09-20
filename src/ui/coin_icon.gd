class_name CoinIcon
extends Control

## A coin, drawn rather than written.
##
## The purse used to say "766 ●", with a bullet character standing in for the
## money. A bullet is a dot: at a glance it reads as punctuation, and the one
## part of the interface that tells a child what they can afford should not
## need reading at all.

const FACE := Color(1.0, 0.86, 0.36)
const EDGE := Color(0.78, 0.60, 0.16)
const MARK := Color(0.62, 0.46, 0.10)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var extent := custom_minimum_size if custom_minimum_size.x > 0.0 else size
	var unit := minf(extent.x, extent.y)
	var centre := extent * 0.5
	# The coin on edge: a disc with a rim, and a second disc offset a little so
	# it has thickness rather than being a circle.
	draw_circle(centre + Vector2(0.0, unit * 0.04), unit * 0.42, EDGE)
	draw_circle(centre, unit * 0.42, FACE)
	draw_arc(centre, unit * 0.34, 0.0, TAU, 20, EDGE, maxf(1.5, unit * 0.06))
	# A mark in the middle, so it is a coin rather than a bead.
	draw_arc(centre, unit * 0.16, PI * 0.2, PI * 1.6, 12, MARK, maxf(1.5, unit * 0.08))
