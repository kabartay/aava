class_name HudFly
extends Control

## Things that fly across the screen: a coin from where it was earned to the
## purse, a chip of wool from the child to the bag.
##
## For a child who cannot read, "+3" on the screen is nothing; a coin that
## leaves the animal and lands in the purse, which then bumps, says it. Cheap
## by construction. A piece is one Control and one Tween, there is no
## `_process`, so an idle layer costs nothing, and the number alive is capped:
## a burst of events merges into the pieces already in the air instead of
## spawning more. Nothing here takes a touch.

## Fired when a piece lands, with what it carried and where, so the purse can bump.
signal landed(item: StringName, at: Vector2)

## The most pieces in the air at once, and how long an earlier piece of the
## same kind stays open to merge a new event into.
const MAX_LIVE := 9
const MERGE_WINDOW := 0.18
const COIN := &"coin"

## Seconds a piece takes. Short: a toddler's eye follows it, an older child's
## is not kept waiting.
const FLIGHT := 0.7
const PIECE := 30.0

## One bounded burst of coins, by how big the reward is.
const FEW := 5
const MANY := 15

var _live: Array[Control] = []
var _last_start := {}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Sizeless: pieces are placed in their parent's coordinates.
	size = Vector2.ZERO

## How many pieces are in the air.
func live_count() -> int:
	return _live.size()

## How many coin pieces a reward of `amount` is shown as: one, two or three.
static func pieces_for(amount: int) -> int:
	return 1 if amount < FEW else (2 if amount < MANY else 3)

## Coins from `from` to `to`, or back the other way for a spend (the caller
## swaps the two). Returns how many pieces were launched, 0 when merged away.
func coins(amount: int, from: Vector2, to: Vector2) -> int:
	if amount <= 0 or _merged(COIN, from, to):
		return 0
	var made := 0
	for i in pieces_for(amount):
		if _live.size() >= MAX_LIVE:
			break
		_launch(CoinIcon.new(), COIN, from, to, float(i) * 0.09)
		made += 1
	return made

## A chip of one item from `from` to `to`.
func chip(item: StringName, from: Vector2, to: Vector2) -> int:
	if _merged(item, from, to) or _live.size() >= MAX_LIVE:
		return 0
	_launch(ItemChip.new(item), item, from, to, 0.0)
	return 1

## Take everything out of the air at once.
func clear() -> void:
	for piece: Control in _live:
		if is_instance_valid(piece):
			var tween := piece.get_meta(&"tween", null) as Tween
			if tween != null:
				tween.kill()
			piece.queue_free()
	_live.clear()

## Stop every piece where it is, for the screenshots.
func freeze() -> void:
	for piece: Control in _live:
		var tween := piece.get_meta(&"tween", null) as Tween
		if tween != null:
			tween.pause()

func _merged(item: StringName, from: Vector2, to: Vector2) -> bool:
	var now := Time.get_ticks_msec() * 0.001
	var key := "%s:%d" % [item, int(signf(to.x - from.x) + 2.0 * signf(to.y - from.y))]
	var before := float(_last_start.get(key, -10.0))
	_last_start[key] = now if now - before >= MERGE_WINDOW else before
	return now - before < MERGE_WINDOW

func _launch(piece: Control, item: StringName, from: Vector2, to: Vector2, delay: float) -> void:
	piece.size = Vector2(PIECE, PIECE)
	piece.custom_minimum_size = piece.size
	piece.pivot_offset = piece.size * 0.5
	piece.position = from - piece.size * 0.5
	piece.scale = Vector2(0.4, 0.4)
	piece.modulate.a = 0.0
	add_child(piece)
	_live.append(piece)
	var tween := piece.create_tween()
	tween.set_parallel(true)
	# Pops out, then goes: the first tenth of a second is the pop.
	tween.tween_property(piece, "modulate:a", 1.0, 0.08).set_delay(delay)
	tween.tween_property(piece, "scale", Vector2(1.25, 1.25), 0.12).set_delay(delay)
	tween.tween_property(piece, "position", to - piece.size * 0.5, FLIGHT) \
		.set_delay(delay + 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(piece, "scale", Vector2(0.7, 0.7), FLIGHT) \
		.set_delay(delay + 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(_land.bind(piece, item))
	piece.set_meta(&"tween", tween)

func _land(piece: Control, item: StringName) -> void:
	_live.erase(piece)
	var at := piece.position + piece.size * 0.5
	piece.queue_free()
	landed.emit(item, at)
