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

## Called whenever anything is collected.
func on_collected(inventory: Inventory) -> void:
	if step != Step.GATHER:
		return
	if _sticks_at_start < 0:
		_sticks_at_start = 0
	if inventory.count(ItemKinds.STICK) - _sticks_at_start >= STICKS_WANTED:
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
	return {"step": int(step), "sticks_at_start": _sticks_at_start}

func from_data(data: Dictionary) -> void:
	step = int(data.get("step", 0)) as Step
	_sticks_at_start = int(data.get("sticks_at_start", -1))
