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
}

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _cache: Dictionary = {}

## A handful of players cycled round, so overlapping sounds do not cut each
## other off — a child collecting quickly triggers three in half a second.
const VOICES := 6

func _init() -> void:
	name = "Sounds"
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)

func play(sound: Sound, pitch := 1.0) -> void:
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
	player.play()

func _build(sound: Sound) -> AudioStreamWAV:
	match sound:
		Sound.PICKUP:
			return _tone([SCALE[5], SCALE[7]], 0.10, 0.5)
		Sound.PLACE:
			return _tone([SCALE[2], SCALE[0]], 0.13, 0.6, true)
		Sound.REMOVE:
			return _tone([SCALE[2], SCALE[0]], 0.16, 0.45)
		Sound.REFUSE:
			# Low and short. Not a buzzer: being told no should not startle.
			return _tone([174.61, 164.81], 0.14, 0.35)
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
		_:
			return _tone([SCALE[7], SCALE[9], SCALE[8]], 0.60, 0.45)

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
			value += sin(TAU * frequency * t) * weight
		value = value / float(partials.size()) * envelope * volume
		_write(data, i, value)
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
