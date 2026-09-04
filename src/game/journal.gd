class_name Journal
extends RefCounted

## What the valley remembers about you between visits.
##
## This exists because the game had no memory of yesterday. A child who built a
## house on Monday was met on Tuesday by a valley that said nothing about it —
## his house was there, but nothing acknowledged that he had made it. Building
## something nobody notices is a weaker reason to come back than building
## something the world greets you about.
##
## So: a running tally, and a greeting on arrival that names what was done last
## time. The tally is deliberately about doing rather than owning. "You built
## four things" is a record of an afternoon; "you have four walls" is an
## inventory.

signal day_turned(days_away: int)

## Counted for the whole life of the world.
const BUILT := &"built"
const CARED := &"cared"
const GOALS := &"goals"
const ROCKS := &"rocks"
const PLANTED := &"planted"
const COINS := &"coins"

const ALL: Array[StringName] = [BUILT, CARED, GOALS, ROCKS, PLANTED, COINS]

## Totals since the world began, and totals for this session only. The second is
## what the greeting reports, because "today you did this" means more at six
## than a number that only ever goes up.
var lifetime: Dictionary = {}
var last_visit: Dictionary = {}
var session: Dictionary = {}

## Unix time of the previous visit, and how many calendar days ago that was.
var last_seen := 0
var days_away := 0
var visits := 0

func _init() -> void:
	for key in ALL:
		lifetime[key] = 0
		last_visit[key] = 0
		session[key] = 0

func record(key: StringName, amount := 1) -> void:
	if not lifetime.has(key):
		return
	lifetime[key] = int(lifetime[key]) + amount
	session[key] = int(session[key]) + amount

## Did anything at all happen last time? A greeting that reports an empty visit
## is worse than no greeting.
func has_last_visit() -> bool:
	for key in ALL:
		if int(last_visit[key]) > 0:
			return true
	return false

func did_anything_this_session() -> bool:
	for key in ALL:
		if int(session[key]) > 0:
			return true
	return false

## How much each kind of thing counts towards being the headline. These are not
## scores — nothing is displayed from them. They exist because the raw counts
## are not comparable: forty rocks are jumped in the time it takes to build one
## house, so picking the largest number would report the rocks every single
## time and the house never.
const WEIGHT := {
	BUILT: 12.0,
	PLANTED: 9.0,
	CARED: 6.0,
	GOALS: 4.0,
	ROCKS: 1.0,
	COINS: 0.5,
}

## The single most notable thing from last visit, as a translation key and a
## count. One line, not six: a child does not read a table.
func headline() -> Array:
	var best_key := &""
	var best_count := 0
	var best_score := 0.0
	for key in ALL:
		var count := int(last_visit[key])
		if count <= 0:
			continue
		# Diminishing returns, not a plain multiplication. The fortieth rock
		# jumped is worth far less than the first, whereas the second house is
		# nearly as much of an afternoon as the first. Without this the rocks
		# win every time on sheer count, and a child who built something is
		# told about pebbles.
		var score := sqrt(float(count)) * float(WEIGHT[key])
		if score > best_score:
			best_score = score
			best_key = key
			best_count = count
	return [best_key, best_count]

## Roll the session into history. Called when the game starts, with the time
## now, so that what "last visit" means is fixed at arrival rather than drifting
## while the child plays.
func arrive(now: int) -> void:
	visits += 1
	if last_seen > 0:
		var elapsed := now - last_seen
		days_away = int(floor(float(elapsed) / 86400.0))
	last_seen = now
	for key in ALL:
		session[key] = 0
	if days_away > 0:
		day_turned.emit(days_away)

## Called when the game closes. What was done this session becomes what is
## reported next time.
func depart() -> void:
	if not did_anything_this_session():
		return
	for key in ALL:
		last_visit[key] = int(session[key])

func to_data() -> Dictionary:
	return {
		"lifetime": lifetime.duplicate(),
		"last_visit": last_visit.duplicate(),
		"last_seen": last_seen,
		"visits": visits,
	}

func from_data(data: Dictionary) -> void:
	var stored: Dictionary = data.get("lifetime", {})
	var previous: Dictionary = data.get("last_visit", {})
	for key in ALL:
		# String keys, because JSON has no StringName and a save written by an
		# earlier version must still load.
		lifetime[key] = int(stored.get(String(key), 0))
		last_visit[key] = int(previous.get(String(key), 0))
		session[key] = 0
	last_seen = int(data.get("last_seen", 0))
	visits = int(data.get("visits", 0))
