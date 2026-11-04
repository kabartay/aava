class_name Tasks
extends Node

## The opening thread: a handful of small tasks that lead a child by the hand.
##
## This is the largest gap the game had. A child started, saw a valley, and was
## told nothing: not that sticks can be picked up, not that there is a pitch,
## not that anything can be built. Everything was discoverable and nothing was
## discovered.
##
## The answer in games is never a wall of text. It is one instruction at a time,
## phrased as somewhere to go and something to do, that completes by itself when
## the child does the thing — so the game teaches by watching rather than by
## explaining. Each step also has a line that fires on completion, which is
## where the *next* idea is planted: finish gathering and you are told about the
## bag; finish building and you are told you can undo.
##
## The thread ends. It is an opening, not a quest log: after four steps the
## valley is handed over and never asks for anything again.

signal changed(instruction: String)
signal completed(reward: String)

enum Step {GATHER, BUILD, PITCH, PLANT, FREE}

## How many sticks the first task asks for. Small enough to finish in the first
## clearing a child walks into.
const STICKS_WANTED := 3

var step: Step = Step.GATHER

## Sticks actually found since the opening began. Counted rather than read off
## the bag: sticks refunded by taking a build down, or spent on one, moved the
## bag's count without a stick being found.
var _found := 0
var _sticks_at_start := -1

func instruction() -> String:
	match step:
		Step.GATHER:
			return Text.of("task_gather")
		Step.BUILD:
			return Text.of("task_build")
		Step.PITCH:
			return Text.of("task_pitch")
		Step.PLANT:
			return Text.of("task_plant")
		_:
			return ""

func is_finished() -> bool:
	return step == Step.FREE

## The kind of place on the map this step leads to, as a PlaceGlyph.Kind, or -1
## where the step is not somewhere to go. The map pulses that sticker, so a
## child told to "go to the pitch" can see where it is.
func place_kind() -> int:
	if step == Step.PITCH:
		return PlaceGlyph.Kind.PITCH
	return -1

## Called whenever anything is collected.
func on_collected(_inventory: Inventory, kind: StringName = ItemKinds.STICK) -> void:
	if step != Step.GATHER:
		return
	# Only a stick counts. A stone picked up while three sticks from a refund
	# were already in the bag finished "gather sticks" without one being found.
	if kind != ItemKinds.STICK:
		return
	_found += 1
	if _found >= STICKS_WANTED:
		_advance(Step.BUILD, Text.of("task_gather_done"))

func on_built(_kind: StringName) -> void:
	if step == Step.BUILD:
		_advance(Step.PITCH, Text.of("task_build_done"))

## Reaching the pitch counts, whether or not a ball is kicked: walking somewhere
## is the achievement for a six-year-old, and demanding a goal first would stall
## the thread on the hardest part of the game.
func on_moved(world_position: Vector3) -> void:
	if step != Step.PITCH:
		return
	if Pitch.is_levelled(world_position.x, world_position.z):
		_advance(Step.PLANT, Text.of("task_pitch_done"))

func on_grove() -> void:
	if step == Step.PLANT:
		_advance(Step.FREE, Text.of("task_plant_done"))

func _advance(next: Step, reward: String) -> void:
	step = next
	completed.emit(reward)
	changed.emit(instruction())

func to_data() -> Dictionary:
	return {"step": int(step), "sticks_at_start": _sticks_at_start, "sticks_found": _found}

func from_data(data: Dictionary) -> void:
	# Clamped, because a step past FREE is neither a task nor finished: no
	# instruction is shown and the thread never ends.
	step = clampi(SaveGame.as_int(data.get("step", 0)), Step.GATHER, Step.FREE) as Step
	_sticks_at_start = SaveGame.as_int(data.get("sticks_at_start", -1), -1)
	_found = maxi(0, SaveGame.as_int(data.get("sticks_found", 0)))
