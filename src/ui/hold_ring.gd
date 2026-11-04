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

## How long this ring takes to fill. The same second for everything but the
## reset in the settings, which asks for longer on purpose.
var seconds := SECONDS

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
	# A finger that slides off the button is still "holding" it as far as
	# button_up is concerned, which only arrives when the finger finally lifts,
	# wherever that is. The ring watches the motion itself.
	button.gui_input.connect(ring._watch)
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

## Stop a hold in progress and say nothing: for the HUD, which is about to be
## thrown away or hidden under a finger.
func cancel() -> void:
	_cancel()

func _stop() -> void:
	var early := _held >= 0.0 and not _spent
	_cancel()
	if early:
		too_short.emit()

## The finger moved, or the system took the touch away. Either ends the hold
## as surely as lifting does, and the later button_up then finds nothing to end.
func _watch(event: InputEvent) -> void:
	if _held < 0.0:
		return
	var outside := false
	if event is InputEventMouseMotion:
		outside = not _inside((event as InputEventMouseMotion).position)
	elif event is InputEventScreenDrag:
		outside = not _inside((event as InputEventScreenDrag).position)
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).canceled:
		_cancel()
		return
	if outside:
		_stop()

func _inside(local: Vector2) -> bool:
	return Rect2(Vector2.ZERO, _button.size).has_point(local)

func _notification(what: int) -> void:
	match what:
		# The system can take the touch without a release ever arriving: the
		# phone call, the swipe down for the notification shade, the home
		# button. A hold that went on counting through that would complete for
		# whoever picked the phone up next.
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, \
		NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_cancel()
		NOTIFICATION_VISIBILITY_CHANGED:
			if _held >= 0.0 and not _button.is_visible_in_tree():
				_cancel()

## True when the button, or anything above it, is waiting to be freed. The HUD
## is queue_freed on a change of language and stays in the tree until the end
## of the frame, still processing.
func _going() -> bool:
	var node: Node = _button
	while node != null:
		if node.is_queued_for_deletion():
			return true
		node = node.get_parent()
	return false

func _cancel() -> void:
	_held = -1.0
	_spent = false
	progress = 0.0
	set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
	# Nothing is held: a stray frame must not start the count from nothing.
	if _held < 0.0:
		return
	# A button hidden or greyed under a finger sends no button_up, and the ring
	# would otherwise go on filling for something nobody is touching.
	if _button.disabled or not _button.is_visible_in_tree() or _going():
		_cancel()
		return
	if _spent:
		return
	_held += delta
	progress = clampf(_held / seconds, 0.0, 1.0)
	queue_redraw()
	if _held >= seconds:
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
