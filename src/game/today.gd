class_name Today
extends RefCounted

## The one thing that is only worth doing today.
##
## The journal made the valley remember yesterday. This gives a reason to come
## back tomorrow, which is the other half: something offered on Monday that is
## gone by Tuesday, replaced by something else.
##
## It is deliberately small. A daily quest with a chain of steps is a job, and a
## child who misses three days should not come back to a backlog. One thing, one
## sentence, one reward, and no penalty at all for ignoring it — the valley is
## still worth being in without it.
##
## What is offered is a pure function of the calendar day, so every child on the
## same map is offered the same thing and can help each other with it. Nothing
## is stored but which day was last completed.

signal completed(kind: StringName, reward: int)

const VISIT := &"visit"
const CARE := &"care"
const BUILD := &"build"
const SCORE := &"score"
const SHOOT := &"shoot"
const PLANT := &"plant"

## Every kind of thing a day can ask for. Ordered, because the day number
## indexes into this and the order must not change between versions or a save
## would find yesterday's task under today's number.
const KINDS: Array[StringName] = [VISIT, CARE, BUILD, SCORE, SHOOT, PLANT]

## What each is worth. More than a single animal, less than an afternoon's work:
## enough to notice, not enough that skipping it costs anything real.
const REWARD := 8

## How many of the thing today asks for.
const AMOUNT := {
	VISIT: 1,
	CARE: 3,
	BUILD: 4,
	SCORE: 2,
	SHOOT: 3,
	PLANT: 2,
}

## Which calendar day was last finished. Days are counted from the unix epoch,
## so this survives clock changes better than storing a date.
var last_finished := -1

var _day := 0
var _progress := 0

## Start the day. `now` is unix time; the day is what changes at midnight local.
func begin(now: int) -> void:
	_day = _day_number(now)
	_progress = 0

func day_number() -> int:
	return _day

## What today asks for.
func kind() -> StringName:
	return KINDS[_day % KINDS.size()]

func needed() -> int:
	return int(AMOUNT[kind()])

func done() -> int:
	return _progress

func is_finished() -> bool:
	return last_finished == _day

## A line describing today's task, already counted.
func describe() -> String:
	if is_finished():
		return Text.of("today_done")
	return Text.format("today_%s" % kind(), [needed() - _progress])

## Tell today that something happened. Only the thing it asked for counts.
func record(what: StringName, amount := 1) -> void:
	if is_finished() or what != kind():
		return
	_progress += amount
	if _progress >= needed():
		last_finished = _day
		completed.emit(kind(), REWARD)

## Arriving counts towards a day that only asks you to turn up.
func arrive() -> void:
	record(VISIT)

## Days since the epoch. Local midnight, not UTC, because a child's day turns
## over when it gets dark where they are.
static func _day_number(unix_time: int) -> int:
	# Typed explicitly: Dictionary.get returns a Variant, and an inferred
	# variable from one breaks every expression downstream. See LESSONS.md.
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	return int(floor(float(unix_time + bias * 60) / 86400.0))

func to_data() -> Dictionary:
	return {"last_finished": last_finished}

func from_data(data: Dictionary) -> void:
	last_finished = int(data.get("last_finished", -1))
