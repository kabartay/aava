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
## The count moved, so the line that shows it is out of date.
signal progressed()

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

## How many days ahead of the clock a finished day can be before it is taken
## for a clock that was wrong. Two covers every time zone change there is.
const MAX_SKEW_DAYS := 2

## Which calendar day was last finished. Days are counted from the unix epoch,
## so this survives clock changes better than storing a date.
var last_finished := -1

var _day := 0
var _progress := 0
## Which day the saved count belongs to.
var _saved_day := -1

## Start the day. `now` is unix time; the day is what changes at midnight local.
##
## The count so far is kept if it is still the same day. It was always set back
## to nothing, and it was never saved, so two of three sheep herded and the
## game closed — or put away by the phone to save its battery, which a child
## does not even see — was nought of three on opening it again.
func begin(now: int) -> void:
	var day := _day_number(now)
	# A clock that was once far ahead (a wrong date, a trip across the date
	# line) must not hold today's task shut for months: a finish further ahead
	# than any time zone explains is forgotten.
	if last_finished > day + MAX_SKEW_DAYS:
		last_finished = day - 1
	if day != _saved_day:
		_progress = 0
	_day = day
	# A count saved against a bigger ask than today's, or edited, would print
	# "-3 left"; one short of the ask is the most that can be true unfinished.
	if not is_finished():
		_progress = mini(_progress, needed() - 1)
	# Remembered, so that beginning again on the same day (the phone woken from
	# its pocket) keeps the count, and beginning on a later one starts it afresh.
	_saved_day = day

func day_number() -> int:
	return _day

## What today asks for.
func kind() -> StringName:
	return KINDS[_day % KINDS.size()]

func needed() -> int:
	return int(AMOUNT[kind()])

func done() -> int:
	return _progress

## Finished today, or on a later day than the clock now says. Only equality
## used to count, so winding the clock back a day (or flying west) offered the
## same day's task again and paid it again, and winding it forward made it
## pay a third time: eight coins for every turn of the date.
func is_finished() -> bool:
	return last_finished >= _day

## The kind of place on the map today's task is done at (a PlaceGlyph.Kind), or
## -1 when it is not done in one place or is already done.
func place_kind() -> int:
	if is_finished():
		return -1
	match kind():
		SCORE:
			return PlaceGlyph.Kind.PITCH
		SHOOT:
			return PlaceGlyph.Kind.RANGE
		_:
			return -1

## A line describing today's task, already counted.
func describe() -> String:
	if is_finished():
		return Text.of("today_done")
	# Visiting is not a count — you either have or you have not — so its line
	# carries no number, unlike every other kind here.
	if kind() == VISIT:
		return Text.of("today_visit")
	return Text.format("today_%s" % kind(), [needed() - _progress])

## Tell today that something happened. Only the thing it asked for counts.
func record(what: StringName, amount := 1) -> void:
	if is_finished() or what != kind():
		return
	_progress += amount
	progressed.emit()
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
	return {"last_finished": last_finished, "day": _day, "progress": _progress}

func from_data(data: Dictionary) -> void:
	last_finished = SaveGame.as_int(data.get("last_finished", -1), -1)
	_saved_day = SaveGame.as_int(data.get("day", -1), -1)
	_progress = maxi(0, SaveGame.as_int(data.get("progress", 0)))
