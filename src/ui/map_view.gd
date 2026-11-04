class_name MapView
extends RefCounted

## Where the map is looking: the world point in the middle of the picture and how
## many metres the picture spans. Pure arithmetic, so that zooming and panning can
## be checked without a screen.
##
## Everything the fingers do reduces to one move, `grab`: the world point that was
## under `from` ends up under `to`, with the picture scaled by `factor` about it.
## A one-finger drag is a grab with factor 1; a pinch is a grab from the old
## midpoint to the new one with the ratio of the fingers' distances; a wheel turn
## is a grab with from == to. That is why the point under the fingers stays put.

## A few dozen metres across: a house and its garden.
const MIN_RANGE := 40.0
## A little more than the whole valley, so the whole-valley view is not the limit.
const MAX_RANGE := 1400.0
## The view's middle may not leave the valley by more than this, so a drag cannot
## lose the map in empty space.
const LIMIT := 650.0
## How much one press of a zoom button changes the range.
const STEP := 1.6

## Side of the square picture, in pixels.
var px := 190.0
## Metres across the picture.
var range_m := 150.0
## World x and z of the picture's middle.
var centre := Vector2.ZERO

static func clamp_range(metres: float) -> float:
	return clampf(metres, MIN_RANGE, MAX_RANGE)

func world_at(pixel: Vector2) -> Vector2:
	return centre + (pixel - Vector2(px, px) * 0.5) / px * range_m

func pixel_of(world: Vector2) -> Vector2:
	return (world - centre) / range_m * px + Vector2(px, px) * 0.5

## The world point under `from` is put under `to`, and the scale grows by `factor`
## (above 1 is zoomed in) about that point. Limits are applied, and when the range
## is already at a limit the point is still held under the fingers.
func grab(from: Vector2, to: Vector2, factor: float) -> void:
	var anchor := world_at(from)
	if factor > 0.0:
		range_m = clamp_range(range_m / factor)
	centre = anchor - (to - Vector2(px, px) * 0.5) / px * range_m
	centre.x = clampf(centre.x, -LIMIT, LIMIT)
	centre.y = clampf(centre.y, -LIMIT, LIMIT)

## Zoom about one pixel, which stays under the finger.
func zoom_at(pixel: Vector2, factor: float) -> void:
	grab(pixel, pixel, factor)
