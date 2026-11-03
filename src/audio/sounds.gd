class_name Sounds
extends Node

## Every sound in the game, synthesised rather than loaded.
##
## There are no audio files in this project and there will not be: a sound
## library is a licensing question, a download, and an asset pipeline, and what
## this game needs is a dozen short blips that confirm something happened. Those
## are cheaper to generate than to find.
##
## The absence of sound was the single largest hole in the game's feel. Picking
## up a stick, placing a wall, scoring a goal — all of them happened in silence,
## and silence reads as "nothing happened" no matter what the screen shows.
##
## Everything here is a short envelope over a few sine partials. Tuned to a
## pentatonic scale, so any two sounds that overlap still agree with each other
## — which matters when a child is running through long grass collecting things
## as fast as he can find them.

const RATE := 22050

## A pentatonic scale in hertz, from which every pitched sound is drawn.
## A plain typed array, not a PackedFloat32Array: a packed array constructor is
## not a constant expression in GDScript, and the error names the constant
## rather than the constructor.
## What a partial and its harmonics add up to at their peak, so adding the
## harmonics does not make anything louder than it was.
const HARMONIC_SUM := 1.42

## The lowest pitch anything here should rely on. Below it a phone's speaker
## plays little or nothing.
const SPEAKER_FLOOR := 250.0

const SCALE: Array[float] = [
	261.63, 293.66, 329.63, 392.00, 440.00,
	523.25, 587.33, 659.25, 784.00, 880.00,
]

enum Sound {
	PICKUP,     # something went into the bag
	PLACE,      # a piece was built
	REMOVE,     # a piece was taken back down
	REFUSE,     # a build was not allowed
	KICK,       # the ball was struck
	GOAL,       # it went in
	JUMP,
	LAND,
	CLEARED,    # a rock was jumped
	GROWN,      # a sapling reached its next stage
	CHIME,      # the world answering: a grove, birds
	SPLASH,     # water: filling the bottle, watering an animal
	STEP_GRASS, # a foot on meadow: a soft brush
	STEP_SAND,  # a foot on sand or the fairground's trodden ground: a dry crunch
	STEP_WOOD,  # a foot on the bridge's planks: a hollow knock
	STEP_WATER, # a foot, or a stroke, in water: a small wet slap
	CHEER,      # a goal: a small crowd, swelling and fading
	DROP,       # the drop tower let go: a soft, falling slide
	SWING,      # the pirate ship passing the bottom of its swing: a breath of air
}

## How far a sound that happens somewhere else in the valley carries, and how
## near it has to be to be heard at full strength. A dam finished by a brother
## half a valley away is news, not something that happens in the child's ear.
const HEARD_FULL := 12.0
const HEARD_NOT := 70.0

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _cache: Dictionary = {}
## The frame each sound last started on. See play().
var _started: Dictionary = {}

## A handful of players cycled round, so overlapping sounds do not cut each
## other off — a child collecting quickly triggers three in half a second.
const VOICES := 6

func _init() -> void:
	name = "Sounds"
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = Mix.EFFECTS
		add_child(player)
		_players.append(player)

func play(sound: Sound, pitch := 1.0, volume_db := 0.0) -> void:
	# The same sound twice in one frame is one sound, only louder. Taking down a
	# stack of twenty pieces, or a plan, asked for twenty identical removals in
	# the same instant, and twenty copies of one waveform in step add up to
	# twenty times the amplitude: a crack at the limiter, and a ring of six
	# players cut off one after another. Once is what was meant.
	var frame := Engine.get_process_frames()
	if frame > 0 and _started.get(sound, -1) == frame:
		return
	_started[sound] = frame
	var stream: AudioStreamWAV = _cache.get(sound)
	if stream == null:
		stream = _build(sound)
		_cache[sound] = stream
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	# A little variation, so the twentieth stick does not sound identical to the
	# first. Repetition is what makes a confirmation sound become a nuisance.
	player.pitch_scale = pitch * randf_range(0.97, 1.05)
	# Set every time: the players are shared round the ring, and a quiet footstep
	# would otherwise leave its volume behind for the next chime to be given.
	player.volume_db = volume_db
	player.play()

## How much quieter, in decibels, a sound is for happening `metres` away from
## the child. Nothing within HEARD_FULL, a straight fall in decibels beyond it,
## and -80 (nothing) from HEARD_NOT.
static func falloff_db(metres: float) -> float:
	if metres <= HEARD_FULL:
		return 0.0
	if metres >= HEARD_NOT:
		return -80.0
	return lerpf(0.0, -30.0, (metres - HEARD_FULL) / (HEARD_NOT - HEARD_FULL))

## Play a sound that happened somewhere, as loud as that somewhere is near.
func play_at(sound: Sound, metres: float, pitch := 1.0, volume_db := 0.0) -> void:
	var quieter := falloff_db(metres)
	if quieter + volume_db > -79.0:
		play(sound, pitch, quieter + volume_db)

## What a foot lands on here, as the sound it makes.
##
## Asked of the world rather than remembered, so there is no table of places to
## fall out of step with the ground: the bridge's own deck, the fairground's
## trodden sand and the beach — which the terrain paints by this same height
## above the waterline — and everything else is meadow. Water wins over all of
## them, because a foot in the river makes the river's noise whatever the bank
## is made of.
static func step_sound(field: HeightField, at: Vector3, wading: bool) -> Sound:
	if wading:
		return Sound.STEP_WATER
	if field.is_on_the_bridge(at):
		return Sound.STEP_WOOD
	if ParkSpec.sand(at.x, at.z) > 0.5:
		return Sound.STEP_SAND
	if at.y - field.water_level_at(at.x, at.z) < 0.6:
		return Sound.STEP_SAND
	return Sound.STEP_GRASS

func _build(sound: Sound) -> AudioStreamWAV:
	match sound:
		Sound.PICKUP:
			return _tone([SCALE[5], SCALE[7]], 0.10, 0.5)
		Sound.PLACE:
			return _tone([SCALE[2], SCALE[0]], 0.13, 0.6, true)
		Sound.REMOVE:
			return _tone([SCALE[2], SCALE[0]], 0.16, 0.45)
		Sound.REFUSE:
			# Low and short, and falling. Not a buzzer: being told no should
			# not startle.
			#
			# Low for this game's scale, not low in fact. It was 175 and 165
			# cycles, pure, and played lower still at a call or two — down to
			# 120 — which a phone's speaker does not reproduce: the most used
			# answer in the game was, on the device it is played on, silence.
			return _tone([SCALE[1], SCALE[0]], 0.16, 0.4, true)
		Sound.KICK:
			return _thump(0.09)
		Sound.GOAL:
			return _tone([SCALE[0], SCALE[2], SCALE[4], SCALE[7]], 0.55, 0.7)
		Sound.JUMP:
			return _tone([SCALE[3], SCALE[5]], 0.09, 0.35)
		Sound.LAND:
			return _thump(0.07)
		Sound.CLEARED:
			return _tone([SCALE[5], SCALE[7], SCALE[9]], 0.30, 0.55)
		Sound.GROWN:
			return _tone([SCALE[1], SCALE[3], SCALE[6]], 0.42, 0.5)
		Sound.SPLASH:
			return _splash(0.22)
		Sound.STEP_GRASS:
			return _scuff(0.07, 0.10, 0.30)
		Sound.STEP_SAND:
			return _scuff(0.08, 0.30, 0.38)
		Sound.STEP_WOOD:
			return _tone([SCALE[0], SCALE[2]], 0.08, 0.30)
		Sound.STEP_WATER:
			return _splash(0.12)
		Sound.CHEER:
			return _cheer(0.9)
		Sound.DROP:
			return _slide(SCALE[8], SCALE[3], 1.1, 0.35)
		Sound.SWING:
			return _breath(0.7, 0.3)
		_:
			return _tone([SCALE[7], SCALE[9], SCALE[8]], 0.60, 0.45)

## A soft glide from one pitch to another, for something falling: the phase is
## accumulated, so the bend is the one asked for and not twice it. Gentle all
## the way — a quick swell in and a long fade — because the ride it belongs to
## is the one a small child is most unsure of.
func _slide(from_hz: float, to_hz: float, seconds: float, volume: float) -> AudioStreamWAV:
	var samples := int(RATE * seconds)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var phase := 0.0
	for i in samples:
		var progress := float(i) / float(samples)
		phase += TAU * lerpf(from_hz, to_hz, progress) / float(RATE)
		var envelope := minf(progress * 8.0, 1.0) * pow(1.0 - progress, 1.5)
		var value := (sin(phase) + 0.30 * sin(phase * 2.0)) / HARMONIC_SUM
		_write(data, i, value * envelope * volume)
	return _wav(data)

## Air moving past: damped noise that swells and dies away, so it is a breath
## and never a hiss. Longer than a splash and a good deal quieter.
func _breath(seconds: float, volume: float) -> AudioStreamWAV:
	var samples := int(RATE * seconds)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 20261104
	var last := 0.0
	for i in samples:
		var progress := float(i) / float(samples)
		var envelope := pow(sin(PI * progress), 2.0)
		last = lerpf(last, noise.randf_range(-1.0, 1.0), 0.12)
		_write(data, i, last * envelope * volume)
	return _wav(data)

## A music box: a slow, gentle tune that loops without a seam, for the
## carousel. Bell-like partials in the pentatonic scale, so whatever else is
## sounding agrees with it, at a low rate because nothing in it is above two
## kilohertz. The tails of the last notes are wrapped round to the start, which
## is what keeps the join silent.
static func music_box() -> AudioStreamWAV:
	var rate := 11025
	var step := 0.45
	var tune: Array[int] = [5, 7, 8, 7, 5, 4, 5, 3, 5, 7, 9, 8, 7, 5, 7, 5]
	var samples := int(rate * step * tune.size())
	var values := PackedFloat32Array()
	values.resize(samples)
	var ring := int(rate * 1.2)
	for n in tune.size():
		var hertz: float = SCALE[tune[n]]
		var start := int(rate * step * n)
		for i in ring:
			var t := float(i) / float(rate)
			var envelope := minf(t * 200.0, 1.0) * exp(-t * 3.5)
			var value := sin(TAU * hertz * t) + 0.25 * sin(TAU * hertz * 2.0 * t)
			values[(start + i) % samples] += value * envelope * 0.3
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		data.encode_s16(i * 2, int(clampf(values[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = samples
	return stream

## A short cheer: a crowd is noise, brighter than water, that swells up to a
## peak a third of the way through and dies away, with a wavering high note
## riding on it so that it reads as voices and not as wind.
func _cheer(seconds: float) -> AudioStreamWAV:
	var samples := int(RATE * seconds)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 20261103
	var last := 0.0
	for i in samples:
		var progress := float(i) / float(samples)
		var t := float(i) / float(RATE)
		var envelope := pow(sin(PI * pow(progress, 0.55)), 1.3)
		last = lerpf(last, noise.randf_range(-1.0, 1.0), 0.55)
		# Wavering between roughly 520 and 700 cycles: well above what a
		# phone's speaker drops.
		var voice := sin(TAU * (600.0 + 90.0 * sin(TAU * 6.0 * t)) * t)
		_write(data, i, (last * 0.5 + voice * 0.18) * envelope)
	return _wav(data)

## Filtered noise under a soft envelope: water has no pitch, so a tone is
## exactly wrong for it. The slow attack is what separates a splash from a
## thump — water gives way before it resists.
func _splash(seconds: float) -> AudioStreamWAV:
	var samples := int(RATE * seconds)
	var data := PackedByteArray()
	data.resize(samples * 2)

	var noise := RandomNumberGenerator.new()
	noise.seed = 20260904
	# Carries the previous sample forward so the noise is damped rather than
	# hissing; a plain random series sounds like radio static.
	var carried := 0.0

	for i in samples:
		var progress := float(i) / float(samples)
		var envelope := minf(progress * 12.0, 1.0) * pow(1.0 - progress, 1.6)
		carried = lerpf(carried, noise.randf_range(-1.0, 1.0), 0.34)
		var value := carried * envelope * 0.5
		var sample := int(clampf(value, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream

## A short run of partials under one envelope. `rising` plays them upward in
## time rather than together, which is what turns a chord into a little tune.
func _tone(partials: Array, seconds: float, volume: float, rising := false) -> AudioStreamWAV:
	var samples := int(RATE * seconds)
	var data := PackedByteArray()
	data.resize(samples * 2)

	for i in samples:
		var t := float(i) / float(RATE)
		var progress := float(i) / float(samples)
		# Fast attack, exponential decay: the shape of something struck.
		var envelope := minf(progress * 40.0, 1.0) * pow(1.0 - progress, 2.2)
		var value := 0.0
		for p in partials.size():
			var frequency: float = partials[p]
			var weight := 1.0 / float(p + 1)
			if rising:
				# Each partial enters a little later than the last.
				var entry := float(p) / float(partials.size()) * 0.6
				weight *= clampf((progress - entry) * 6.0, 0.0, 1.0)
			# Each partial with its second and third harmonic. On a phone's
			# speaker the fundamental of a low note is mostly gone, and the ear
			# rebuilds it from the harmonics above — so a note with none is a
			# note that vanishes when it is played at three-quarters pitch,
			# which several of these are.
			var phase := TAU * frequency * t
			value += (sin(phase) + 0.30 * sin(phase * 2.0) + 0.12 * sin(phase * 3.0)) * weight / HARMONIC_SUM
		value = value / float(partials.size()) * envelope * volume
		_write(data, i, value)
	return _wav(data)

## A footfall on something loose: noise with a soft attack and a quick fall, so
## it is a brush rather than a knock. `brightness` is how much of the noise is
## let through undamped — low is grass, higher is the grit of sand.
func _scuff(seconds: float, brightness: float, volume: float) -> AudioStreamWAV:
	var samples := int(RATE * seconds)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 31
	var last := 0.0
	for i in samples:
		var progress := float(i) / float(samples)
		var envelope := minf(progress * 14.0, 1.0) * pow(1.0 - progress, 2.4)
		last = lerpf(last, noise.randf_range(-1.0, 1.0), brightness)
		_write(data, i, last * envelope * volume)
	return _wav(data)

## A soft percussive knock: noise through a falling envelope, no pitch.
func _thump(seconds: float) -> AudioStreamWAV:
	var samples := int(RATE * seconds)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 7
	var last := 0.0
	for i in samples:
		var progress := float(i) / float(samples)
		var envelope := pow(1.0 - progress, 3.0)
		# Low-passed noise, so it is a thud rather than a hiss.
		last = lerpf(last, noise.randf_range(-1.0, 1.0), 0.18)
		_write(data, i, last * envelope * 0.6)
	return _wav(data)

func _write(data: PackedByteArray, index: int, value: float) -> void:
	var sample := int(clampf(value, -1.0, 1.0) * 32767.0)
	data.encode_s16(index * 2, sample)

func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream
