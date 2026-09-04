class_name Vitals
extends RefCounted

## Energy, and the water carried to restore it.
##
## The design rule here is that energy paces the day; it never strands a child.
## Running costs energy and walking does not, so energy is a reason to walk
## sometimes rather than a punishment for having run. At zero the player still
## walks at full speed — only running is withheld — because a game that makes a
## six-year-old crawl home is a game he stops playing.
##
## Water is the other half: the bottle bought in the shop fills at the river and
## empties into either the player or a thirsty animal. That gives the river a
## use beyond scenery and the bottle a use beyond being the cheapest thing in
## the shop.

signal energy_changed(fraction: float)
signal water_changed(fraction: float)
signal exhausted()
signal revived()

## Full energy in seconds of continuous running. Roughly a minute and a half,
## which is far enough to cross the valley and back at a run.
const MAX_ENERGY := 90.0

## What running costs, and what standing still returns. Recovery is deliberately
## slower than the drain, so running is a choice, but it is never so slow that
## waiting feels like a punishment.
const RUN_DRAIN := 1.0
const REST_RECOVERY := 0.42
const WALK_RECOVERY := 0.16

## A full bottle. Four drinks, so it is worth carrying and worth refilling.
const MAX_WATER := 4.0
const DRINK := 1.0

## What one drink restores, as a fraction of full energy.
const DRINK_RESTORE := 0.34

## Below this the player cannot run. Not zero, so there is a moment of warning
## rather than a sudden stop.
const TIRED := 0.02

var energy := MAX_ENERGY
var water := 0.0
var has_bottle := false

var _was_tired := false

func fraction() -> float:
	return energy / MAX_ENERGY

func water_fraction() -> float:
	return water / MAX_WATER if has_bottle else 0.0

func can_run() -> bool:
	return fraction() > TIRED

## Called every frame with what the player is actually doing.
func advance(delta: float, running: bool, moving: bool) -> void:
	var before := energy
	if running and moving:
		energy -= RUN_DRAIN * delta
	elif moving:
		energy += WALK_RECOVERY * delta
	else:
		energy += REST_RECOVERY * delta
	energy = clampf(energy, 0.0, MAX_ENERGY)

	# Announce crossing the tired line in both directions, so the interface can
	# say why running stopped working and, more importantly, when it works
	# again. A control that goes quiet without explanation reads as broken.
	var tired_now := not can_run()
	if tired_now and not _was_tired:
		exhausted.emit()
	elif not tired_now and _was_tired:
		revived.emit()
	_was_tired = tired_now

	if not is_equal_approx(before, energy):
		energy_changed.emit(fraction())

## Fill at the river. Returns true if anything was actually taken on board.
func fill() -> bool:
	if not has_bottle or is_equal_approx(water, MAX_WATER):
		return false
	water = MAX_WATER
	water_changed.emit(water_fraction())
	return true

## Drink. Returns true if there was water to drink.
func drink() -> bool:
	if not has_bottle or water < DRINK:
		return false
	water -= DRINK
	energy = minf(MAX_ENERGY, energy + MAX_ENERGY * DRINK_RESTORE)
	water_changed.emit(water_fraction())
	energy_changed.emit(fraction())
	return true

## Pour a drink out for an animal. Same cost, no energy back.
func pour() -> bool:
	if not has_bottle or water < DRINK:
		return false
	water -= DRINK
	water_changed.emit(water_fraction())
	return true

func grant_bottle() -> void:
	has_bottle = true
	water_changed.emit(water_fraction())

func to_data() -> Dictionary:
	return {"energy": energy, "water": water, "bottle": has_bottle}

func from_data(data: Dictionary) -> void:
	energy = clampf(float(data.get("energy", MAX_ENERGY)), 0.0, MAX_ENERGY)
	water = clampf(float(data.get("water", 0.0)), 0.0, MAX_WATER)
	has_bottle = bool(data.get("bottle", false))
	_was_tired = not can_run()
	energy_changed.emit(fraction())
	water_changed.emit(water_fraction())
