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

var _wind: AudioStreamPlayer
var _water: AudioStreamPlayer
var _birds: AudioStreamPlayer

var _wind_level := 0.0
var _water_level := 0.0
var _bird_level := 0.0

func _init() -> void:
	name = "Ambience"
	# Built here rather than in _ready, because the game sets these going on the
	# frame it creates them. See LESSONS.md.
	_wind = _voice(_make_wind())
	_water = _voice(_make_water())
	_birds = _voice(_make_birds())

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
	at: Vector3, field: HeightField, places: Places, darkness: float, delta: float
) -> void:
	# Clamped, because `delta / FOLLOW` passes 1.0 on any frame longer than six
	# tenths of a second — a chunk loading, a dam finishing — and an unclamped
	# lerp weight above 1 overshoots the target instead of approaching it. The
	# audible result is the wind lurching the wrong way on exactly the frames
	# where the game is already struggling.
	var weight := clampf(delta / FOLLOW, 0.0, 1.0)
	# Wind: the higher and barer the ground, the more of it. Sheltered down by
	# the river, wild up on a hillside.
	var exposure := smoothstep(WIND_QUIET_HEIGHT, WIND_LOUD_HEIGHT, at.y)
	var sheltered := 1.0 - smoothstep(0.0, 60.0, field.distance_to_river(at.x, at.z)) * 0.35
	_wind_level = lerpf(_wind_level, clampf(0.25 + exposure * 0.75, 0.0, 1.0) * sheltered, weight)

	# Water: from whichever is nearer, the river or a lake.
	var to_river := field.distance_to_river(at.x, at.z)
	var to_water := to_river
	if places != null:
		for basin in Lakes.BASINS:
			var flat := Vector2(at.x - basin.x, at.z - basin.z).length() - basin.y
			to_water = minf(to_water, maxf(flat, 0.0))
	_water_level = lerpf(
		_water_level, 1.0 - smoothstep(4.0, WATER_REACH, to_water), weight
	)

	# Birds: daylight, and where there is something for them to sit in.
	var wooded := field.forest_density_at(at.x, at.z)
	_bird_level = lerpf(_bird_level, (1.0 - darkness) * clampf(wooded * 1.6, 0.0, 1.0), weight)

	_apply(_wind, _wind_level, -26.0)
	_apply(_water, _water_level, -24.0)
	_apply(_birds, _bird_level, -30.0)

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

## Wind: noise with the top taken off, breathing slowly in and out.
func _make_wind() -> AudioStreamWAV:
	var samples := int(RATE * LOOP_SECONDS)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 424242
	var carried := 0.0
	for i in samples:
		var t := float(i) / float(RATE)
		# Heavily damped, so it is air rather than static.
		carried = lerpf(carried, noise.randf_range(-1.0, 1.0), 0.06)
		# Two slow swells at different periods, so the breathing never lands on
		# the same beat twice within the loop.
		var swell := 0.55 + 0.3 * sin(t * 0.7) + 0.15 * sin(t * 1.9 + 1.1)
		var value := carried * swell * 2.4
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	return _wrap(data)

## Water: brighter noise than wind, with a faster ripple on it.
func _make_water() -> AudioStreamWAV:
	var samples := int(RATE * LOOP_SECONDS)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 909090
	var carried := 0.0
	var previous := 0.0
	for i in samples:
		var t := float(i) / float(RATE)
		carried = lerpf(carried, noise.randf_range(-1.0, 1.0), 0.30)
		# The difference between one damped sample and the last is a crude high
		# pass: it keeps the hiss of moving water and drops the rumble.
		var bright := carried - previous
		previous = carried
		var ripple := 0.75 + 0.25 * sin(t * 3.1) * sin(t * 1.3)
		data.encode_s16(i * 2, int(clampf(bright * ripple * 3.2, -1.0, 1.0) * 32767.0))
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

	# Eight calls in four seconds, each a short rising or falling pair of notes.
	for _call in 8:
		var start := rng.randi_range(0, samples - int(RATE * 0.5))
		var pitch := rng.randf_range(1400.0, 2600.0)
		var bend := rng.randf_range(-0.35, 0.5)
		var length := int(RATE * rng.randf_range(0.07, 0.16))
		for i in length:
			var progress := float(i) / float(length)
			var envelope := sin(progress * PI)
			var frequency := pitch * (1.0 + bend * progress)
			var at := start + i
			if at < samples:
				values[at] += sin(TAU * frequency * float(i) / float(RATE)) * envelope * 0.55

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
