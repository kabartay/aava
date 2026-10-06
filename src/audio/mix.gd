class_name Mix
extends RefCounted

## Where the sounds go before they reach the speaker.
##
## Everything used to go straight to the one Master bus, with nothing at the
## end of it. A goal, a chime, an engine at full revs and an animal calling
## close by can land in the same moment, and their sum went past full scale and
## clipped — a crackle, on exactly the moments meant to feel best. And the
## valley sounded the same with a child's head under the river as above it,
## which the eye had been told about and the ear had not.
##
## So there are two buses and one rule each:
##
## - **Master** ends in a limiter, so no combination of sounds can clip.
## - **World** carries everything that happens *in* the valley — the
##   ambience, the animals — and goes dull under water. The interface's own
##   sounds and the other children's voices stay on Master: a coin is still a
##   coin under water, and a brother is still a brother.
##
## Built in code, like the rest of this project, and idempotent: asking twice
## finds what the first asking made.

const WORLD := &"World"

## A decibel short of full scale, so the limiter has something to aim at that
## no speaker will distort on.
const CEILING_DB := -1.0

## The world's cutoff in the air and at its most under water. Not lower than
## this under water: muffled is the point, but a phone's speaker plays nothing
## much below a few hundred cycles, and a world muffled below that is a world
## gone silent rather than one heard through water.
const OPEN_CUTOFF := 16000.0
const UNDER_CUTOFF := 650.0
const UNDER_HUSH_DB := -4.0

static var _last_under := -1.0

static func build() -> void:
	var master := AudioServer.get_bus_index(&"Master")
	if _effect(master, "AudioEffectHardLimiter") == null:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = CEILING_DB
		AudioServer.add_bus_effect(master, limiter)

	var world := AudioServer.get_bus_index(WORLD)
	if world < 0:
		world = AudioServer.bus_count
		AudioServer.add_bus(world)
		AudioServer.set_bus_name(world, WORLD)
		AudioServer.set_bus_send(world, &"Master")
	if _effect(world, "AudioEffectLowPassFilter") == null:
		var dull := AudioEffectLowPassFilter.new()
		dull.cutoff_hz = OPEN_CUTOFF
		AudioServer.add_bus_effect(world, dull)
	_last_under = -1.0
	muffle(0.0)

## How far under water the listener is, from 0 in the air to 1 fully under.
## Cheap to call every frame: nothing is touched unless it has changed.
static func muffle(amount: float) -> void:
	var under := clampf(amount, 0.0, 1.0)
	if absf(under - _last_under) < 0.005:
		return
	_last_under = under
	var world := AudioServer.get_bus_index(WORLD)
	if world < 0:
		return
	var index := _effect_index(world, "AudioEffectLowPassFilter")
	if index < 0:
		return
	# Off entirely in the air. A filter left running at sixteen kilohertz does
	# nothing anyone can hear and still costs a little of every buffer.
	var wet := under > 0.02
	AudioServer.set_bus_effect_enabled(world, index, wet)
	if wet:
		var filter := AudioServer.get_bus_effect(world, index) as AudioEffectLowPassFilter
		# Swept in octaves rather than in cycles, which is how an ear hears a
		# filter close: a straight line from sixteen thousand to six hundred
		# spends almost all of its travel where nothing changes.
		filter.cutoff_hz = exp(lerpf(log(OPEN_CUTOFF), log(UNDER_CUTOFF), under))
	AudioServer.set_bus_volume_db(world, lerpf(0.0, UNDER_HUSH_DB, under))

## Where the world's filter has got to. For the checks.
static func world_cutoff() -> float:
	var world := AudioServer.get_bus_index(WORLD)
	var index := _effect_index(world, "AudioEffectLowPassFilter") if world >= 0 else -1
	if index < 0 or not AudioServer.is_bus_effect_enabled(world, index):
		return OPEN_CUTOFF
	return (AudioServer.get_bus_effect(world, index) as AudioEffectLowPassFilter).cutoff_hz

static func _effect(bus: int, type: String) -> AudioEffect:
	var index := _effect_index(bus, type)
	return AudioServer.get_bus_effect(bus, index) if index >= 0 else null

static func _effect_index(bus: int, type: String) -> int:
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i).get_class() == type:
			return i
	return -1
