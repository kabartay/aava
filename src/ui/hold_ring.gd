class_name HoldRing
extends Control

## A button that has to be held, with a ring that fills while it is.
##
## A three-year-old taps a phone at random while the older ones play, and a tap
## is all it takes to take a house down, spend the coins somebody saved for a
## bicycle, or leave a game being played together. Everyday things — jump,
## kick, put a piece up — stay instant; the ones that lose something hard to
## get back go through here. A child who wants one finds out how by seeing the
## ring fill, and a toddler lifts a finger long before it has.
##
## One node on the button rather than a rule in the HUD, so that the HUD and the
## play-together panel hold their buttons the same way.

## Fires once, when the ring is full — not again until the finger has been
## lifted, so a long press does not repeat the action.
signal completed()

## The finger came up early. The caller says how to hold it.
signal too_short()

## About a second: longer than any tap or accidental rest of a palm, shorter
## than a parent's patience.
const SECONDS := 1.0

## How far round the ring is, 0 to 1. Public for the screenshots and the checks.
var progress := 0.0

var _held := -1.0
var _spent := false
var _button: Button

## Off, the button is an ordinary one: a press starts nothing and a lifted
## finger says nothing. For the one button that is a swing in one place and a
## meal in another.
var needed := true

## Make `button` need a hold, and call `action` when it has been held. The
## button's own `pressed` is left alone and must not be connected to the action.
static func attach(button: Button, action: Callable) -> HoldRing:
	var ring := HoldRing.new()
	ring._button = button
	ring.completed.connect(action)
	button.add_child(ring)
	button.button_down.connect(ring._start)
	button.button_up.connect(ring._stop)
	return ring

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Never takes a touch: the button under it is the one being held.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

func is_holding() -> bool:
	return _held >= 0.0

func _start() -> void:
	if not needed:
		return
	_held = 0.0
	_spent = false
	progress = 0.0
	set_process(true)
	queue_redraw()

func _stop() -> void:
	var early := _held >= 0.0 and not _spent
	_cancel()
	if early:
		too_short.emit()

func _cancel() -> void:
	_held = -1.0
	_spent = false
	progress = 0.0
	set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
	# A button hidden or greyed under a finger sends no button_up, and the ring
	# would otherwise go on filling for something nobody is touching.
	if _button.disabled or not _button.is_visible_in_tree():
		_cancel()
		return
	if _spent:
		return
	_held += delta
	progress = clampf(_held / SECONDS, 0.0, 1.0)
	queue_redraw()
	if _held >= SECONDS:
		_spent = true
		completed.emit()

func _draw() -> void:
	if progress <= 0.0:
		return
	var middle := size * 0.5
	var radius := maxf(minf(size.x, size.y) * 0.5 - 5.0, 6.0)
	draw_arc(middle, radius, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, 0.25), 6.0, true)
	draw_arc(
		middle, radius, -PI * 0.5, -PI * 0.5 + TAU * progress, 40,
		Color(0.36, 0.86, 0.46), 6.0, true
	)
