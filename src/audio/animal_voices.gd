class_name AnimalVoices
extends Node3D

## What the creatures sound like.
##
## These are deliberately not part of the ambient bed. A dog barking on a loop
## is wallpaper; a dog barking once, from over there, because you walked past it
## is an animal. So every one of these is a single event, played from the place
## the creature actually is, at intervals long enough that a child notices each
## one rather than tuning them all out.
##
## The intervals are the whole craft here. Too often and it is a farmyard; too
## rarely and the valley is dead. They are also jittered rather than fixed,
## because anything that happens on a metronome stops sounding like an animal
## within about a minute.

const RATE := 22050

## How far a voice carries, and how near a creature has to be before it says
## anything at all. A dog on the far side of the valley barking at nobody is
## noise; the same dog barking as a child walks up to it is the point.
const AUDIBLE := 26.0
const NOTICE := 18.0

## Seconds between one creature speaking and the next, per kind. The first
## number is the shortest gap, the second the longest; the actual wait is
## somewhere between, drawn afresh each time.
const GAPS := {
	&"dog": [11.0, 26.0],
	&"squirrel": [16.0, 38.0],
	&"beaver": [22.0, 50.0],
	# A cat says little on its own — a meow now and then, at the longest gaps
	# here — and purrs only when it is stroked. The first version had it silent
	# unless stroked, on the theory that a cat meowing at nobody is nobody's
	# cat; but a cat that never makes a sound until touched reads as a statue,
	# and the person watching asked for the occasional meow back.
	&"cat": [28.0, 65.0],
}

## How many can be speaking at once. Beyond a handful it is a chorus.
const VOICES := 4

var _players: Array[AudioStreamPlayer3D] = []
var _next := 0
var _sounds: Dictionary = {}
var _wait := 0.0
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	name = "AnimalVoices"
	_rng.seed = 5150
	# Built here rather than in _ready: the game asks for a purr on the same
	# frame it creates this. See LESSONS.md.
	_sounds[&"dog"] = _bark()
	_sounds[&"squirrel"] = _chatter()
	_sounds[&"beaver"] = _grunt()
	_sounds[&"cat"] = _meow()
	_sounds[&"cat_purr"] = _purr()

	for _i in VOICES:
		var player := AudioStreamPlayer3D.new()
		player.max_distance = AUDIBLE
		player.unit_size = 6.0
		player.volume_db = -8.0
		add_child(player)
		_players.append(player)

	_wait = _rng.randf_range(4.0, 9.0)

## Say something, from where the creature is. Used directly for the purr, and by
## the timer below for everything else.
func speak(kind: StringName, at: Vector3, pitch := 1.0) -> void:
	_play(kind, at, pitch)
	# Stroking a cat: it answers, then settles into a purr. The purr arrives a
	# moment after the meow rather than under it, which is the order a real
	# one does things in.
	if kind == &"cat" and is_inside_tree():
		_purr_later(at)

func _purr_later(at: Vector3) -> void:
	await get_tree().create_timer(0.6).timeout
	if is_inside_tree():
		_play(&"cat_purr", at, 1.0)

func _play(kind: StringName, at: Vector3, pitch: float) -> void:
	if not _sounds.has(kind):
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = _sounds[kind]
	player.pitch_scale = pitch
	player.global_position = at
	player.play()

## Called every frame with the creatures near the player. One of them speaks
## when the wait runs out, chosen at random from those close enough to be worth
## hearing.
func watch(near: Array[Dictionary], listener: Vector3, delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return

	var candidates: Array[Dictionary] = []
	for animal in near:
		var kind: StringName = animal["kind"]
		if not GAPS.has(kind) or float(GAPS[kind][0]) > 1e8:
			continue
		var node = animal.get("node")
		if node == null or not is_instance_valid(node):
			continue
		if (node as Node3D).global_position.distance_to(listener) > NOTICE:
			continue
		candidates.append(animal)

	if candidates.is_empty():
		# Nothing near enough. Look again shortly rather than waiting out a full
		# interval in an empty meadow.
		_wait = 2.0
		return

	var chosen: Dictionary = candidates[_rng.randi_range(0, candidates.size() - 1)]
	var kind: StringName = chosen["kind"]
	var node: Node3D = chosen["node"]
	# A little pitch either way, so two dogs are two dogs.
	_play(kind, node.global_position, _rng.randf_range(0.9, 1.12))

	var gap: Array = GAPS[kind]
	_wait = _rng.randf_range(float(gap[0]), float(gap[1]))

## A bark: a burst of noise with a hard attack and a falling pitch, twice.
func _bark() -> AudioStreamWAV:
	var samples := int(RATE * 0.42)
	var values := PackedFloat32Array()
	values.resize(samples)
	var noise := RandomNumberGenerator.new()
	noise.seed = 771

	for pair in 2:
		var start := int(RATE * (0.0 if pair == 0 else 0.19))
		var length := int(RATE * 0.13)
		var carried := 0.0
		for i in length:
			var progress := float(i) / float(length)
			# Very fast in, slower out: the shape of something shouted.
			var envelope := minf(progress * 26.0, 1.0) * pow(1.0 - progress, 1.9)
			carried = lerpf(carried, noise.randf_range(-1.0, 1.0), 0.55)
			# A voiced tone under the noise, dropping — the growl inside a bark.
			var tone := sin(TAU * (280.0 - 110.0 * progress) * float(i) / float(RATE))
			var at := start + i
			if at < samples:
				values[at] += (carried * 0.55 + tone * 0.45) * envelope * 0.85
	return _to_stream(values)

## Chatter: a run of very short high clicks, the way a squirrel scolds.
func _chatter() -> AudioStreamWAV:
	var samples := int(RATE * 0.55)
	var values := PackedFloat32Array()
	values.resize(samples)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3311

	var at := int(RATE * 0.02)
	while at < samples - int(RATE * 0.04):
		var length := int(RATE * rng.randf_range(0.018, 0.032))
		var pitch := rng.randf_range(2100.0, 3400.0)
		for i in length:
			var progress := float(i) / float(length)
			var envelope := minf(progress * 14.0, 1.0) * pow(1.0 - progress, 2.2)
			var index := at + i
			if index < samples:
				values[index] += sin(TAU * pitch * float(i) / float(RATE)) * envelope * 0.4
		at += length + int(RATE * rng.randf_range(0.03, 0.07))
	return _to_stream(values)

## A grunt: low, short, and not much of it. Beavers are not talkative.
func _grunt() -> AudioStreamWAV:
	var samples := int(RATE * 0.3)
	var values := PackedFloat32Array()
	values.resize(samples)
	var noise := RandomNumberGenerator.new()
	noise.seed = 9021
	var carried := 0.0
	for i in samples:
		var progress := float(i) / float(samples)
		var envelope := minf(progress * 12.0, 1.0) * pow(1.0 - progress, 1.6)
		carried = lerpf(carried, noise.randf_range(-1.0, 1.0), 0.28)
		var tone := sin(TAU * (150.0 - 40.0 * progress) * float(i) / float(RATE))
		values[i] = (carried * 0.4 + tone * 0.6) * envelope * 0.7
	return _to_stream(values)

## A meow: a voice, not a siren. The first version swept a fixed stack of
## four harmonics up and down, which is exactly what a siren does. A cat's cry
## is a buzz rich in harmonics — the same buzz throughout — shaped by a mouth
## that opens from "m" through "ia" and closes again to "ow". So this runs a
## sawtooth-like set of twelve harmonics through two moving resonances, and it
## is the resonances that move, as they do in a throat. A little pitch jitter
## and a breath of noise keep it from being perfectly clean, which no animal
## is.
func _meow() -> AudioStreamWAV:
	var harmonics := 12
	var block := 32
	var samples := int(RATE * 0.72)
	var values := PackedFloat32Array()
	values.resize(samples)
	var noise := RandomNumberGenerator.new()
	noise.seed = 4242
	var phase := 0.0
	var breath := 0.0
	var jitter := 0.0
	var open := 0.0
	var weights := PackedFloat32Array()
	weights.resize(harmonics)
	var peak := 0.0
	for i in samples:
		var t := float(i) / float(RATE)
		var progress := float(i) / float(samples)
		# The cry: a quick rise out of the closed "m", a hold with a little
		# wobble in it, and a longer, slower fall into the "ow".
		var pitch: float
		if progress < 0.22:
			pitch = lerpf(540.0, 860.0, smoothstep(0.0, 0.22, progress))
		elif progress < 0.5:
			pitch = 860.0 - 40.0 * smoothstep(0.22, 0.5, progress)
		else:
			pitch = lerpf(820.0, 470.0, smoothstep(0.5, 1.0, progress))
		if i % 8 == 0:
			jitter = lerpf(jitter, noise.randf_range(-1.0, 1.0), 0.25)
		var vibrato := 1.0 + 0.012 * sin(TAU * 5.5 * t) * smoothstep(0.2, 0.45, progress) + 0.006 * jitter
		phase = fmod(phase + TAU * pitch * vibrato / float(RATE), TAU)

		if i % block == 0:
			# The mouth: two resonances that open the vowel and close it. The
			# second one drops towards the end, which is what turns "a" into
			# "ow".
			open = smoothstep(0.04, 0.3, progress) * (1.0 - smoothstep(0.55, 0.95, progress))
			var first := lerpf(380.0, 780.0, open)
			var second := lerpf(1000.0, 1900.0, open) * (1.0 - 0.25 * smoothstep(0.5, 1.0, progress))
			for n in harmonics:
				var frequency := pitch * float(n + 1)
				var near_first := (frequency - first) / 140.0
				var near_second := (frequency - second) / 220.0
				weights[n] = (
					1.0 / (1.0 + near_first * near_first)
					+ 0.6 / (1.0 + near_second * near_second)
					+ 0.06
				) / float(n + 1)

		var tone := 0.0
		for n in harmonics:
			tone += sin(phase * float(n + 1)) * weights[n]
		breath = lerpf(breath, noise.randf_range(-1.0, 1.0), 0.3)
		var envelope := smoothstep(0.0, 0.09, progress) * (1.0 - smoothstep(0.6, 1.0, progress))
		# Loudness follows how open the mouth is, but never to nothing mid-cry.
		var voice := envelope * (0.55 + 0.45 * open)
		values[i] = (tone + breath * 0.03) * voice
		peak = maxf(peak, absf(values[i]))
	# The resonances make the level unpredictable; bring the loudest point to
	# a known one so the cat is neither a whisper nor a shout.
	if peak > 0.0:
		var gain := 0.72 / peak
		for i in samples:
			values[i] *= gain
	return _to_stream(values)

## A purr: a low tone pulsed about twenty-five times a second, which is roughly
## what a real one does. Long, because purring is something that goes on.
func _purr() -> AudioStreamWAV:
	var samples := int(RATE * 1.6)
	var values := PackedFloat32Array()
	values.resize(samples)
	var noise := RandomNumberGenerator.new()
	noise.seed = 6464
	var carried := 0.0
	for i in samples:
		var t := float(i) / float(RATE)
		var progress := float(i) / float(samples)
		# In and out gently at both ends, so it does not click.
		var envelope := smoothstep(0.0, 0.12, progress) * (1.0 - smoothstep(0.78, 1.0, progress))
		carried = lerpf(carried, noise.randf_range(-1.0, 1.0), 0.12)
		# The pulse is what makes it a purr rather than a hum.
		var pulse := 0.55 + 0.45 * sin(TAU * 26.0 * t)
		var tone := sin(TAU * 42.0 * t) * 0.5 + sin(TAU * 84.0 * t) * 0.2
		values[i] = (tone + carried * 0.35) * pulse * envelope * 0.8
	return _to_stream(values)

func _to_stream(values: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(values.size() * 2)
	for i in values.size():
		data.encode_s16(i * 2, int(clampf(values[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream
