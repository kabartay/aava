class_name Ambience
extends Node

## The sound the valley makes when nothing is happening.
##
## Everything that made a noise before was an event: a kick, a coin, a piece
## going down. Between those the game was perfectly silent, and silence is what
## a picture of a place sounds like rather than the place itself. A child could
## stand in a meadow beside a river and hear nothing at all.
##
## Three continuous voices, mixed by where the player is standing:
##
## **Wind**, always there, rising as the ground does — loud on an open hillside,
## hushed down among the trees by the river. It breathes rather than drones,
## because a steady hiss is the fastest way to make somebody turn the sound off.
##
## **Water**, from the river and the lakes, loud enough at the bank to have to
## walk away from.
##
## **Birds**, in daylight only, and only where there are trees to hold them.
##
## All synthesised at load, like every other sound here: no files, and the whole
## valley's audio is a few kilobytes of generated waveform.

const RATE := 22050

## Long enough that the loop is not heard as a loop. Noise has no pitch to give
## the repeat away, so a few seconds is plenty.
const LOOP_SECONDS := 4.0

## How quickly a voice follows the world. Slow: sound that snaps when a child
## turns round is worse than sound that is slightly late.
const FOLLOW := 0.6

## Where wind starts to be heard, and where it is at full strength.
const WIND_QUIET_HEIGHT := 4.0
const WIND_LOUD_HEIGHT := 90.0

## How far from water it can still be heard.
const WATER_REACH := 34.0

## How loud each voice is at its loudest, in decibels.
##
## The river was the loudest thing in the valley: standing on the bank it
## drowned the wind, the birds and the game itself. A river heard from a few
## paces away is a presence, not a noise — these were all mixed by ear on a
## laptop and every one of them came out too loud on a phone held at arm's
## length, the water most of all.
const WIND_DB := -36.0
const LEAVES_DB := -34.0
const WATER_DB := -35.0
const BIRDS_DB := -40.0
const SWIMMING_DB := -28.0

var _wind: AudioStreamPlayer
var _leaves: AudioStreamPlayer
var _water: AudioStreamPlayer
var _birds: AudioStreamPlayer
## The sound of being in the water rather than beside it.
var _swimming: AudioStreamPlayer

var _wind_level := 0.0
var _leaf_level := 0.0

## Slow weather. Wind is not a constant with gusts on it — it gets up for a
## while and then drops away for a while, and a valley where it never does
## sounds like a machine left running. This drifts over minutes, so a child
## hears calm spells and blustery ones without either being an event.
var _weather := 0.5
var _weather_target := 0.5
var _weather_wait := 0.0
var _water_level := 0.0
var _bird_level := 0.0
var _swim_level := 0.0

## How much the rest of the valley is hushed while a child is in the water.
## Standing in the river the wind and the leaves were exactly as loud as they
## are in a meadow, so being in the water sounded like being beside it.
const HUSHED_IN_WATER := 0.7

func _init() -> void:
	name = "Ambience"
	# Built here rather than in _ready, because the game sets these going on the
	# frame it creates them. See LESSONS.md.
	_wind = _voice(_make_wind())
	_water = _voice(_make_water())
	_leaves = _voice(_make_leaves())
	_birds = _voice(_make_birds())
	_swimming = _voice(_make_swimming())

func _voice(stream: AudioStreamWAV) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	# Silent until the world says otherwise, so nothing blares on the first
	# frame before anyone has said where the player is standing.
	player.volume_db = -80.0
	add_child(player)
	return player

## Called every frame with where the player is and what is around them.
func follow(
	at: Vector3, field: HeightField, places: Places, darkness: float, delta: float,
	in_water := 0.0
) -> void:
	# Clamped, because `delta / FOLLOW` passes 1.0 on any frame longer than six
	# tenths of a second — a chunk loading, a dam finishing — and an unclamped
	# lerp weight above 1 overshoots the target instead of approaching it. The
	# audible result is the wind lurching the wrong way on exactly the frames
	# where the game is already struggling.
	var weight := clampf(delta / FOLLOW, 0.0, 1.0)
	# Weather first: a target strength picked every half-minute or so and drifted
	# towards, so the wind rises and falls over minutes rather than holding one
	# level for ever.
	_weather_wait -= delta
	if _weather_wait <= 0.0:
		_weather_target = randf_range(0.15, 1.0)
		_weather_wait = randf_range(22.0, 55.0)
	_weather = lerpf(_weather, _weather_target, clampf(delta / 14.0, 0.0, 1.0))

	# Wind: the higher and barer the ground, the more of it. Sheltered down by
	# the river, wild up on a hillside.
	var exposure := smoothstep(WIND_QUIET_HEIGHT, WIND_LOUD_HEIGHT, at.y)
	var sheltered := 1.0 - smoothstep(0.0, 60.0, field.distance_to_river(at.x, at.z)) * 0.35
	# Barely there down in the valley and only really heard on an open hillside.
	# The floor was 0.25, which meant a quarter of full wind everywhere a child
	# ever stood, including in the shelter of the trees — a constant hiss that
	# is exactly what makes somebody turn the sound off.
	_wind_level = lerpf(
		_wind_level, clampf(0.05 + exposure * 0.95, 0.0, 1.0) * sheltered * _weather, weight
	)

	# Water: from whichever is nearer, the river or a lake.
	var to_river := field.distance_to_river(at.x, at.z)
	var to_water := to_river
	if places != null:
		to_water = minf(to_water, Lakes.distance_to_water(at.x, at.z))
	# Full only well inside the water; from the bank it is already easing off,
	# so walking up to a river is a sound growing rather than a wall arriving.
	_water_level = lerpf(
		_water_level, 0.9 * (1.0 - smoothstep(1.0, WATER_REACH, to_water)), weight
	)

	# In the water: the water itself, close and moving, and everything else
	# hushed behind it. `in_water` is how deep the child is, from nothing on
	# the bank to one when swimming.
	var swimming := clampf(in_water, 0.0, 1.0)
	_swim_level = lerpf(_swim_level, swimming, weight)
	var hushed := 1.0 - _swim_level * HUSHED_IN_WATER

	# Leaves: only where there are leaves. Rustling was mixed into the wind
	# itself, so it followed a child out into an empty meadow and rustled there.
	# It is its own voice now, and it falls away sharply with the trees.
	var wooded := field.forest_density_at(at.x, at.z)
	_leaf_level = lerpf(_leaf_level, clampf(wooded * 1.3, 0.0, 1.0) * _weather, weight)

	# Birds: daylight, and where there is something for them to sit in.
	_bird_level = lerpf(_bird_level, (1.0 - darkness) * clampf(wooded * 1.6, 0.0, 1.0), weight)

	# Quiet. All of these were mixed by ear on a laptop and were far too loud
	# on a tablet held at arm's length — the wind in particular drowned the
	# game.
	_apply(_wind, _wind_level * hushed, WIND_DB)
	_apply(_leaves, _leaf_level * hushed, LEAVES_DB)
	# The water heard from the bank gives way to the water you are in.
	_apply(_water, _water_level * (1.0 - _swim_level * 0.5), WATER_DB)
	_apply(_birds, _bird_level * hushed, BIRDS_DB)
	_apply(_swimming, _swim_level, SWIMMING_DB)

## How loud each voice is right now, for the checks: nothing else can hear
## the mix.
func levels() -> Dictionary:
	return {
		"wind": _wind_level, "leaves": _leaf_level, "water": _water_level,
		"birds": _bird_level, "swimming": _swim_level,
		# How much of the meadow's own voices is let through while the child
		# is in the water: one on the bank, less than half of it swimming.
		"hush": 1.0 - _swim_level * HUSHED_IN_WATER,
	}

## Whether a voice is actually sounding. Also for the checks.
func is_sounding(voice: String) -> bool:
	match voice:
		"wind":
			return _wind.playing
		"leaves":
			return _leaves.playing
		"water":
			return _water.playing
		"birds":
			return _birds.playing
		_:
			return _swimming.playing

## The sound of being in the water: a low, close wash with slow slaps in it,
## the way water sounds around your ears rather than across a meadow. Darker
## than the river's voice, which is bright because it is heard at a distance
## and over stones.
func _make_swimming() -> AudioStreamWAV:
	var samples := int(RATE * LOOP_SECONDS)
	var values := PackedFloat32Array()
	values.resize(samples)
	var noise := RandomNumberGenerator.new()
	noise.seed = 313131

	# The wash: noise run through two passes of smoothing, which takes the
	# hiss off it and leaves the low rolling part.
	var slow := 0.0
	var slower := 0.0
	for i in samples:
		slow = lerpf(slow, noise.randf_range(-1.0, 1.0), 0.06)
		slower = lerpf(slower, slow, 0.08)
		# Breathing in and out over a few seconds, as water does around you.
		var swell := 0.65 + 0.35 * sin(TAU * float(i) / float(samples) * 2.0)
		values[i] = slower * 2.4 * swell

	# Slaps: short soft knocks of water, a handful of times through the loop,
	# each a burst of low noise that dies away.
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var at := int(RATE * 0.3)
	while at < samples - int(RATE * 0.4):
		var length := int(RATE * rng.randf_range(0.10, 0.22))
		var pitch := rng.randf_range(110.0, 230.0)
		var carried := 0.0
		for i in length:
			var index := at + i
			if index >= samples:
				break
			var fade := 1.0 - float(i) / float(length)
			carried = lerpf(carried, rng.randf_range(-1.0, 1.0), 0.25)
			var body := sin(TAU * pitch * float(i) / float(RATE)) * 0.6 + carried * 0.4
			values[index] += body * fade * fade * 0.5
		at += length + int(RATE * rng.randf_range(0.25, 0.8))

	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		data.encode_s16(i * 2, int(clampf(values[i], -1.0, 1.0) * 32767.0))
	return _wrap(data)

## Below a whisper, a voice is stopped outright rather than left playing at a
## volume nobody can hear but the mixer still has to work on.
func _apply(player: AudioStreamPlayer, level: float, loudest_db: float) -> void:
	if level < 0.02:
		if player.playing:
			player.stop()
		return
	if not player.playing:
		player.play()
	player.volume_db = loudest_db + linear_to_db(clampf(level, 0.001, 1.0))

## Wind: two bands of noise, gusting.
##
## One band of filtered noise is a hiss, however quiet it is made — the ear
## hears a single unchanging colour and reads it as static. Air has a deep part
## you feel and a light part that moves in the leaves, and the two do not gust
## together. Layering them at different cutoffs, with gusts that swell one more
## than the other, is what turns noise into weather.
func _make_wind() -> AudioStreamWAV:
	var samples := int(RATE * LOOP_SECONDS)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 424242

	var deep := 0.0
	var light := 0.0
	for i in samples:
		var t := float(i) / float(RATE)
		var source := noise.randf_range(-1.0, 1.0)
		# Very heavily damped: the body of the wind, more felt than heard.
		deep = lerpf(deep, source, 0.020)
		# Barely damped: the rustle, which is what carries the movement.
		light = lerpf(light, source, 0.180)

		# Gusts on three periods that do not divide into one another, so the
		# loop never settles into a rhythm a child could count.
		var gust := 0.45 + 0.32 * sin(t * 0.41) + 0.14 * sin(t * 1.07 + 2.2)
		gust += 0.09 * sin(t * 2.63 + 0.6)
		# The rustle rises with the gust much more than the body does, the way
		# leaves answer a breeze the ground does not notice.
		# Mostly the body of the air. The rustle used to be carried here too,
		# which is why it followed a child into an empty meadow; it is its own
		# voice now and this keeps only enough of it to give the gusts an edge.
		var value := deep * 1.6 * (0.6 + gust * 0.4) + light * 0.18 * gust
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	return _wrap(data)

## Leaves: light, fast, dry noise. The part of wind that only happens where
## there is something for it to happen in.
func _make_leaves() -> AudioStreamWAV:
	var samples := int(RATE * LOOP_SECONDS)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 313131
	var carried := 0.0
	var previous := 0.0
	for i in samples:
		var t := float(i) / float(RATE)
		carried = lerpf(carried, noise.randf_range(-1.0, 1.0), 0.24)
		# Differenced, to take the body out and leave the dry papery part.
		var dry := carried - previous
		previous = carried
		# Leaves answer a gust and then settle, faster than the air does.
		var gust := 0.35 + 0.4 * sin(t * 0.83 + 0.4) + 0.25 * sin(t * 2.11)
		data.encode_s16(i * 2, int(clampf(dry * maxf(gust, 0.0) * 2.6, -1.0, 1.0) * 32767.0))
	return _wrap(data)

## Water: a broad hiss with burbles moving through it.
##
## A high-passed hiss on its own is a tap running. What makes a stream is that
## the sound is not even: little runs of it well up and fall away as water goes
## over one stone and then another. Those are the burbles here — short bands of
## noise that come and go at their own irregular rate over the steady sheet.
func _make_water() -> AudioStreamWAV:
	var samples := int(RATE * LOOP_SECONDS)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 909090

	var values := PackedFloat32Array()
	values.resize(samples)

	# The sheet: bright, even, quiet.
	var carried := 0.0
	var previous := 0.0
	for i in samples:
		carried = lerpf(carried, noise.randf_range(-1.0, 1.0), 0.34)
		var bright := carried - previous
		previous = carried
		values[i] = bright * 1.9

	# The burbles: twenty-odd short swells at random places, each a narrow band
	# of noise rising and falling inside a fifth of a second.
	for _burble in 26:
		var start := noise.randi_range(0, samples - int(RATE * 0.3))
		var length := int(RATE * noise.randf_range(0.06, 0.22))
		var damping := noise.randf_range(0.10, 0.45)
		var loudness := noise.randf_range(0.35, 0.9)
		var voice := 0.0
		var last := 0.0
		for i in length:
			var progress := float(i) / float(length)
			var envelope := sin(progress * PI)
			voice = lerpf(voice, noise.randf_range(-1.0, 1.0), damping)
			var band := voice - last
			last = voice
			var at := start + i
			if at < samples:
				values[at] += band * envelope * loudness * 2.2

	for i in samples:
		data.encode_s16(i * 2, int(clampf(values[i], -1.0, 1.0) * 32767.0))
	return _wrap(data)

## Birds: a few short whistles scattered through the loop, on the same scale the
## rest of the game's sounds use so they belong to it.
func _make_birds() -> AudioStreamWAV:
	var samples := int(RATE * LOOP_SECONDS)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 171717

	var values := PackedFloat32Array()
	values.resize(samples)

	# Three calls in four seconds rather than eight. Birdsong is punctuation in
	# a quiet place, and at eight a second it was a dawn chorus that never let
	# up.
	for _call in 3:
		var start := rng.randi_range(0, samples - int(RATE * 0.5))
		var pitch := rng.randf_range(1700.0, 3000.0)
		var bend := rng.randf_range(-0.30, 0.42)
		var length := int(RATE * rng.randf_range(0.06, 0.13))
		var wobble := rng.randf_range(18.0, 34.0)
		for i in length:
			var progress := float(i) / float(length)
			var t := float(i) / float(RATE)
			# A chirp, not a note: quick to speak and slower to fall away. A
			# symmetrical envelope sounds like a synthesiser being played.
			var envelope := minf(progress * 9.0, 1.0) * pow(1.0 - progress, 1.4)
			# Vibrato, and a quiet second harmonic. A pure sine is the one sound
			# nothing in a wood makes.
			var frequency := pitch * (1.0 + bend * progress) * (1.0 + 0.02 * sin(TAU * wobble * t))
			var tone := sin(TAU * frequency * t) + 0.28 * sin(TAU * frequency * 2.0 * t)
			var at := start + i
			if at < samples:
				values[at] += tone * envelope * 0.34

	for i in samples:
		data.encode_s16(i * 2, int(clampf(values[i], -1.0, 1.0) * 32767.0))
	return _wrap(data)

## A looping stream. Without the loop points these play once and the valley goes
## quiet again four seconds later.
func _wrap(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = data.size() / 2
	return stream
