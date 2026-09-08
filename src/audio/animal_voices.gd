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

## The voices are synthesised, sample by sample, in GDScript — a couple of
## hundred milliseconds of it on a phone, which used to land on the first
## frame. They are baked on a worker thread now and collected when done; a
## creature that would have spoken in the first second of a game says
## nothing, which nobody will notice.
var _bake_task := -1
var _baked: Dictionary = {}
var _bake_mutex := Mutex.new()

func _init() -> void:
	name = "AnimalVoices"
	_rng.seed = 5150
	_bake_task = WorkerThreadPool.add_task(_bake_all, false, "animal voices")

	# The players are made here, on the main thread, before anything can ask
	# to play. An edit once left this loop stranded after a `return` further
	# down the file, and every animal in the valley went silent: the first
	# call to play indexed an empty array and gave up.
	for _i in VOICES:
		var player := AudioStreamPlayer3D.new()
		player.max_distance = AUDIBLE
		player.unit_size = 6.0
		player.volume_db = -8.0
		add_child(player)
		_players.append(player)

	_wait = _rng.randf_range(4.0, 9.0)

## Every voice, built off the main thread. Writes into `_baked` under the
## mutex; `_collect_baked` moves them across once the task reports done.
func _bake_all() -> void:
	var made := {
		&"dog": _bark(),
		&"squirrel": _chatter(),
		&"beaver": _grunt(),
		&"cat": _meow(true),
		&"cat_short": _meow(false),
		&"cat_purr": _purr(),
	}
	_bake_mutex.lock()
	_baked = made
	_bake_mutex.unlock()

## Pick up the baked voices if they are ready. Cheap once they have been.
func _collect_baked() -> void:
	if _bake_task < 0:
		return
	if not WorkerThreadPool.is_task_completed(_bake_task):
		return
	WorkerThreadPool.wait_for_task_completion(_bake_task)
	_bake_task = -1
	_bake_mutex.lock()
	_sounds = _baked
	_baked = {}
	_bake_mutex.unlock()

## Wait for the voices, for a check that wants them now.
func bake_now() -> void:
	if _bake_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_bake_task)
		_bake_task = -1
		_bake_mutex.lock()
		_sounds = _baked
		_baked = {}
		_bake_mutex.unlock()

## Which voices are ready. For the checks.
func voices() -> Array:
	return _sounds.keys()

## Say something, from where the creature is. Used directly for the purr, and by
## the timer below for everything else.
func speak(kind: StringName, at: Vector3, pitch := 1.0) -> void:
	# The same recording twice in a row is the fastest way to hear that it is
	# one: a little off the given pitch each time.
	_play(kind, at, pitch * _rng.randf_range(0.94, 1.08))
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
	_collect_baked()
	if kind == &"cat" and _sounds.has(&"cat_short") and _rng.randf() < 0.4:
		# Two cries, a long and a short, so the cat is not a doorbell.
		kind = &"cat_short"
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

## A meow. A cat's cry is a buzz rich in harmonics — the same buzz throughout
## — shaped by a short vocal tract, so its resonances sit far higher than a
## person's: the first near a kilohertz, the second between two and three.
## The first two versions used a person's resonances, and were a person going
## "meow". This one runs a sawtooth-like set of harmonics through a cat's,
## opening from the closed "m" through "ia" and closing to "ow"; the pitch is
## jittered from one glottal cycle to the next, which is the roughness every
## real animal voice has and no clean oscillator does; and a breath of noise
## grows towards the end, where a cat's cry goes hoarse.
func _meow(long_cry: bool) -> AudioStreamWAV:
	var harmonics := 14
	var block := 32
	var seconds := 0.78 if long_cry else 0.46
	var samples := int(RATE * seconds)
	var values := PackedFloat32Array()
	values.resize(samples)
	var noise := RandomNumberGenerator.new()
	noise.seed = 4242 if long_cry else 4343
	var phase := 0.0
	var breath := 0.0
	var cycle_jitter := 0.0
	var cycle_gain := 1.0
	var open := 0.0
	var weights := PackedFloat32Array()
	weights.resize(harmonics)
	var peak := 0.0
	for i in samples:
		var progress := float(i) / float(samples)
		# The cry: up quickly out of the "m", a hold that sags a little, and
		# a longer fall into the "ow". The short cry is the same shape,
		# quicker, and does not fall as far.
		var pitch: float
		if long_cry:
			if progress < 0.18:
				pitch = lerpf(520.0, 820.0, smoothstep(0.0, 0.18, progress))
			elif progress < 0.55:
				pitch = lerpf(820.0, 760.0, smoothstep(0.18, 0.55, progress))
			else:
				pitch = lerpf(760.0, 430.0, smoothstep(0.55, 1.0, progress))
		else:
			if progress < 0.25:
				pitch = lerpf(600.0, 900.0, smoothstep(0.0, 0.25, progress))
			else:
				pitch = lerpf(900.0, 540.0, smoothstep(0.25, 1.0, progress))
		var before := phase
		phase = fmod(phase + TAU * pitch * (1.0 + cycle_jitter) / float(RATE), TAU)
		if phase < before:
			# A new glottal cycle: a new small error in its length and loudness.
			cycle_jitter = noise.randf_range(-0.025, 0.025)
			cycle_gain = 1.0 + noise.randf_range(-0.08, 0.08)

		if i % block == 0:
			# The mouth. Three resonances, the lower two moving with the vowel;
			# the second drops at the end, which is what turns "a" into "ow".
			open = smoothstep(0.03, 0.26, progress) * (1.0 - smoothstep(0.5, 0.94, progress))
			var first := lerpf(900.0, 1150.0, open)
			var second := lerpf(1600.0, 2900.0, open) * (1.0 - 0.28 * smoothstep(0.5, 1.0, progress))
			var third := 4200.0
			for n in harmonics:
				var frequency := pitch * float(n + 1)
				var near_first := (frequency - first) / 180.0
				var near_second := (frequency - second) / 300.0
				var near_third := (frequency - third) / 500.0
				weights[n] = (
					1.0 / (1.0 + near_first * near_first)
					+ 0.7 / (1.0 + near_second * near_second)
					+ 0.25 / (1.0 + near_third * near_third)
					+ 0.03
				) / pow(float(n + 1), 0.8)

		var tone := 0.0
		for n in harmonics:
			tone += sin(phase * float(n + 1)) * weights[n]
		breath = lerpf(breath, noise.randf_range(-1.0, 1.0), 0.35)
		var hoarse := 0.02 + 0.06 * smoothstep(0.6, 1.0, progress)
		var envelope := smoothstep(0.0, 0.06, progress) * (1.0 - smoothstep(0.62, 1.0, progress))
		# Loudness follows how open the mouth is, but never to nothing mid-cry.
		var voice := envelope * (0.5 + 0.5 * open) * cycle_gain
		values[i] = (tone + breath * hoarse) * voice
		peak = maxf(peak, absf(values[i]))
	if peak > 0.0:
		var gain := 0.7 / peak
		for i in samples:
			values[i] *= gain
	return _to_stream(values)

## A purr. Not a hum: a train of little pulses, twenty-six a second, each a
## short burst that dies away before the next — which is what a purr is, and
## why it sounds like something happening in a throat rather than a note. The
## first purr was a 42 Hz tone, which a phone's speaker cannot produce at
## all, so what came through was its noise, pulsing: a strange sound after
## the meow, as reported. The bursts here sit around three hundred hertz,
## which a phone can play, and alternate a little every three quarters of a
## second, the way breathing in and out changes a real purr.
func _purr() -> AudioStreamWAV:
	var samples := int(RATE * 1.7)
	var values := PackedFloat32Array()
	values.resize(samples)
	var noise := RandomNumberGenerator.new()
	noise.seed = 6464
	var pulse_rate := 26.0
	var carried := 0.0
	for i in samples:
		var t := float(i) / float(RATE)
		var progress := float(i) / float(samples)
		var envelope := smoothstep(0.0, 0.15, progress) * (1.0 - smoothstep(0.72, 1.0, progress))
		# Where in the current pulse we are, in seconds.
		var into := fmod(t, 1.0 / pulse_rate)
		# In-breath and out-breath: a slightly higher, quieter pulse half the time.
		var breathing_in := fmod(t, 1.5) < 0.75
		var burst_pitch := 320.0 if breathing_in else 260.0
		var burst := sin(TAU * burst_pitch * into) * exp(-into / 0.0055)
		carried = lerpf(carried, noise.randf_range(-1.0, 1.0), 0.45)
		var rasp := carried * exp(-into / 0.004) * 0.5
		var level := 0.75 if breathing_in else 1.0
		values[i] = (burst + rasp) * level * envelope * 0.55
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
