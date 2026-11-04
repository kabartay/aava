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

## The interface's own sounds — the coin, the chime, the click of building —
## on a bus of their own, so they can be turned down under a voice without
## touching the voices themselves, which stay on Master.
const EFFECTS := &"Effects"

## How far the valley's ambience and the interface's sounds give way while
## somebody is speaking. Gentle: the world is still there, it is simply not
## shouting over a brother. About a third of the loudness, not silence.
const DUCK_DB := -8.0

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

## Below this nothing a phone's speaker, or a child's earphones, can play:
## the wind's body, the engine's lowest thump and the water's drone put about
## half their energy down there, where all it can do is take headroom from
## the limiter. Cut gently, far under the lowest pitch the game's own notes
## rely on (Sounds.SPEAKER_FLOOR), so no sound loses anything it could have
## been heard by.
const RUMBLE_CUTOFF := 60.0

## The grown-up's volume control: a number of bars lit out of STEPS, for the
## valley's ambience and for the interface's own sounds. Never below one bar,
## because silence is the mute's job and a mute is easy to see and to undo; a
## volume stuck at nothing is a game a parent believes is broken.
const STEPS := 5

## What each lit bar plays at, as a share of full volume. Uneven on purpose: the
## ear hears loudness in ratios, so equal steps in amplitude sound like one big
## drop at the bottom and nothing at the top.
const STEP_GAIN: Array[float] = [0.08, 0.2, 0.4, 0.68, 1.0]

static var _last_under := -1.0
static var _duck := 0.0
static var _ambience_steps := STEPS
static var _effects_steps := STEPS
static var _muted := false

static func build() -> void:
	var master := AudioServer.get_bus_index(&"Master")
	if _effect(master, "AudioEffectHighPassFilter") == null:
		var rumble := AudioEffectHighPassFilter.new()
		rumble.cutoff_hz = RUMBLE_CUTOFF
		# First in the chain, so the limiter never spends itself on it.
		AudioServer.add_bus_effect(master, rumble, 0)
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
	var effects := AudioServer.get_bus_index(EFFECTS)
	if effects < 0:
		effects = AudioServer.bus_count
		AudioServer.add_bus(effects)
		AudioServer.set_bus_name(effects, EFFECTS)
		AudioServer.set_bus_send(effects, &"Master")
	if _effect(world, "AudioEffectLowPassFilter") == null:
		var dull := AudioEffectLowPassFilter.new()
		dull.cutoff_hz = OPEN_CUTOFF
		AudioServer.add_bus_effect(world, dull)
	_last_under = -1.0
	muffle(0.0)
	# A rebuilt bus layout keeps what a grown-up asked for.
	set_muted(_muted)

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
	_levels()

## How far the game's own sounds are turned down, from 0 (not at all) to 1
## (by DUCK_DB). Cheap to call every frame, like muffle.
static func duck(amount: float) -> void:
	var ducked := clampf(amount, 0.0, 1.0)
	# Anything that is not a visible change is skipped, except arriving at
	# exactly zero, which must be reached or the valley stays a hair quiet.
	if absf(ducked - _duck) < 0.005 and not (ducked == 0.0 and _duck != 0.0):
		return
	_duck = ducked
	_levels()

## Where the ducking has got to, for the checks.
static func ducked() -> float:
	return _duck

## The volume of the two buses the ducking reaches. The world's is the sum of
## its two reasons to be quieter: under water, and under a voice.
static func _levels() -> void:
	var down := _duck * DUCK_DB
	var world := AudioServer.get_bus_index(WORLD)
	if world >= 0:
		var under := clampf(_last_under, 0.0, 1.0)
		AudioServer.set_bus_volume_db(
			world, lerpf(0.0, UNDER_HUSH_DB, under) + down + step_db(_ambience_steps)
		)
	var effects := AudioServer.get_bus_index(EFFECTS)
	if effects >= 0:
		AudioServer.set_bus_volume_db(effects, down + step_db(_effects_steps))

## The loudness of a number of lit bars, in decibels (0 at all of them).
static func step_db(steps: int) -> float:
	return linear_to_db(STEP_GAIN[clampi(steps, 1, STEPS) - 1])

## The grown-up's volume: how many bars are lit for the ambience and for the
## interface's sounds. Out-of-range numbers (an edited save) are clamped.
static func set_steps(ambience: int, effects: int) -> void:
	_ambience_steps = clampi(ambience, 1, STEPS)
	_effects_steps = clampi(effects, 1, STEPS)
	_levels()

## Silence everything, the children's voices included, or end it. The Master
## bus is muted rather than turned down, so the volume the grown-up chose is
## still there when it ends.
static func set_muted(muted: bool) -> void:
	_muted = muted
	var master := AudioServer.get_bus_index(&"Master")
	if master >= 0:
		AudioServer.set_bus_mute(master, muted)

static func ambience_steps() -> int:
	return _ambience_steps

static func effects_steps() -> int:
	return _effects_steps

static func muted() -> bool:
	return _muted

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
