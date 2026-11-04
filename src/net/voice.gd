class_name Voice
extends Node

## Talking to the other children in the valley.
##
## This is the only part of the game whose failures reach outside it, and the
## children are small, so the rules are strict and they are structural rather
## than intentional:
##
## **The microphone is not running unless a child is holding the button.** Not
## "we only send while held" — the capture stream is stopped, so there is
## nothing to send even if something later went wrong. Push-to-talk is the
## whole design, not a mode of it.
##
## **Only to people already in the valley.** Voice travels over the same session
## as everything else. There is no lobby and no matchmaking, and nothing here
## goes past the local network. But this used to say there was no way at all
## for a stranger to be on the other end, and that is not so: a host is open to
## any phone on the same network that runs this game and knows the number,
## which at home is the family and on a café's wifi is not. So the parent's
## switch has to close the door both ways — see `allowed`.
##
## **Nothing is ever written down.** No recording, no buffering to disk, no
## history. Frames go from the microphone to the network to a speaker and are
## then gone. A check reads this file and fails the build if it ever learns
## about FileAccess.
##
## **The permission is asked for when a child presses talk**, not when the game
## opens. A parent who sees "Aava wants to record audio" the moment their child
## opens a game about a valley has been given no reason for it; the same dialog
## a second after the child taps a button marked *talk*, while playing with
## their brother, explains itself.
##
## The cost of stopping the stream between presses is a fraction of a second
## before the first word carries. That is a real cost and it is worth it.

signal talking_changed(speaking: bool)
signal someone_spoke(id: int)

## The child pressed talk and the phone said no: the dialog was refused, or
## Android has stopped asking after two refusals and answered for them. The
## screen has to say so, or the button simply does nothing.
signal permission_refused()

## Voice needs far less than music. 11 kHz mono is telephone quality and plenty
## for one child shouting about a football; it is a quarter of the data of the
## mix rate, which matters on a tablet's wifi.
const RATE := 11025

## How many captured frames make one sent frame, as the audio server is
## actually mixing — which is a fraction, and has to be kept as one.
##
## This was a constant 4, which is only right at 44,100. It then became the mix
## rate over RATE *rounded*, which was meant to fix the 48,000 Hz phones and did
## not: 48,000 / 11,025 is 4.35, it rounds to 4, and those phones went on
## sending 12,000 samples of speech a second into a stream that plays 11,025.
## The voice came out an eighth slow and low, and the extra overflowed the
## playback buffer and was dropped a word at a time — the very failure the note
## here described as fixed. Most Android phones mix at 48,000.
static func ratio() -> float:
	return maxf(AudioServer.get_mix_rate() / float(RATE), 1.0)

## How many captured frames the next packet needs, given where the last one
## left off. Varies by one from packet to packet, because 4.35 frames do not
## divide into whole ones.
static func frames_for(step: float, phase: float) -> int:
	return int(floor(phase + float(FRAMES_PER_PACKET) * step))

## Stereo float frames at the mix rate become one packet of mono 16-bit at
## RATE. `phase` is how far into the first frame the last packet stopped.
##
## Each sent sample is the average of the captured frames it spans rather than
## one of them picked out: taking every fourth frame aliases, and the high end
## folds down into the voice and it sounds like a robot.
static func pack(frames: PackedVector2Array, step: float, phase: float) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(FRAMES_PER_PACKET * 2)
	var last := frames.size() - 1
	for i in FRAMES_PER_PACKET:
		var from := int(floor(phase + float(i) * step))
		var to := maxi(from + 1, int(floor(phase + float(i + 1) * step)))
		var sum := 0.0
		for at in range(from, to):
			var frame := frames[mini(at, last)]
			sum += (frame.x + frame.y) * 0.5
		var value := clampf(sum / float(to - from), -1.0, 1.0)
		out.encode_s16(i * 2, int(value * 32767.0))
	return out

## Where the next packet starts inside the first frame it is given.
var _phase := 0.0

## The noise gate. A packet quieter than this (a peak of about -36 dB, which is
## a room and not a voice) is not sent, and the gate stays open for a quarter
## of a second after the last loud one so the soft end of a word is not
## clipped. It is the simple half of dealing with a phone hearing the other
## phones: what comes back off a speaker across the room is much quieter than
## a child at the microphone, and silence costs the wifi nothing.
const GATE_PEAK := 0.015
const GATE_HANG := 5

## The last quiet packet, kept so that when the gate opens the beginning of the
## word goes out with it rather than starting a twentieth of a second late.
var _preroll := PackedByteArray()
var _hang := 0

## How much speech is held back before a voice starts to play, about an eighth
## of a second. Wifi delivers packets in bursts, and a speaker that starts the
## moment the first arrives runs dry between bursts and plays the gap as a
## stutter. This much in hand rides out a hitch of that size; any more is
## delay a child mid-sentence would notice.
const PREBUFFER := 0.12

## A voice that has not been heard for this long has stopped, and whatever it
## left below the prebuffer is played rather than held for ever: the end of a
## word would otherwise never be heard.
const SPEECH_MSEC := 150

## How quickly the game's own sounds give way under a voice, and return.
const DUCK_ATTACK := 0.25
const DUCK_RELEASE := 0.8

## Per speaker: the frames waiting for the prebuffer, whether they are playing
## yet, when the last packet came, and how big the generator's buffer is.
var _pending: Dictionary = {}
var _primed: Dictionary = {}
var _heard_at: Dictionary = {}
var _capacity: Dictionary = {}
var _duck := 0.0

## How much audio goes in one packet. About a twentieth of a second, so a lost
## packet is a click rather than a missing word.
const FRAMES_PER_PACKET := 550

## The bus the microphone is captured on. Silent, because a child hearing
## themselves a moment late cannot speak at all.
const BUS := &"Mic"

## The Android permission. Declaring it in the manifest is not enough — it is a
## dangerous permission and has to be asked for while the game is running.
const PERMISSION := "android.permission.RECORD_AUDIO"

var _session: Session = null
var _capture: AudioEffectCapture = null
var _microphone: AudioStreamPlayer = null
var _speakers: Dictionary = {}
var _talking := false

## The button is down but the permission dialog is still open. Without this the
## press that raised the dialog was simply lost, and a child who pressed,
## tapped "allow" and pressed again could not tell it from being refused.
var _held := false
var _available := false

func _init() -> void:
	name = "Voice"

## True when this device can talk at all: a microphone exists, the permission
## was granted, and the audio bus was built. False is not an error — a tablet
## with no permission simply has no talk button.
func is_available() -> bool:
	return _available

func is_talking() -> bool:
	return _talking

func attach(session: Session) -> void:
	_session = session

func _ready() -> void:
	_available = _build_bus()
	if not _available:
		push_warning("no microphone: the talk button will not be offered")
	if is_inside_tree():
		get_tree().on_request_permissions_result.connect(_on_permission_answered)

## The dialog was answered. If the child is still holding the button the answer
## carries straight on into talking, rather than asking them to press again; if
## they let go while it was open there is nothing to carry on.
func _on_permission_answered(permission: String, granted: bool) -> void:
	if permission != PERMISSION:
		return
	if granted:
		if _held:
			start_talking()
	else:
		# Said whether or not the button is still down: the child saw a dialog
		# and said no, or Android said it for them, and either way "nothing
		# happens" is the one answer that explains nothing.
		_held = false
		permission_refused.emit()

## Peak loudness of a run of captured frames, 0 to 1.
static func peak(frames: PackedVector2Array) -> float:
	var loudest := 0.0
	for frame in frames:
		loudest = maxf(loudest, absf(frame.x + frame.y) * 0.5)
	return loudest

## Leaving mid-word must not leave the valley turned down for good.
func _exit_tree() -> void:
	Mix.duck(0.0)

## The bus, its capture effect, and the (stopped) microphone player.
func _build_bus() -> bool:
	if not ProjectSettings.get_setting("audio/driver/enable_input", false):
		return false

	var index := AudioServer.get_bus_index(BUS)
	if index < 0:
		index = AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, BUS)
	# Silent, so nobody hears their own voice a moment late — which is the
	# single most effective way to stop a person speaking.
	AudioServer.set_bus_mute(index, true)

	_capture = null
	for effect in AudioServer.get_bus_effect_count(index):
		if AudioServer.get_bus_effect(index, effect) is AudioEffectCapture:
			_capture = AudioServer.get_bus_effect(index, effect)
			break
	if _capture == null:
		_capture = AudioEffectCapture.new()
		AudioServer.add_bus_effect(index, _capture)

	_microphone = AudioStreamPlayer.new()
	_microphone.stream = AudioStreamMicrophone.new()
	_microphone.bus = BUS
	add_child(_microphone)
	return true

## Has the child (or their parent) allowed the microphone?
##
## True everywhere but Android, where nothing is granted until it is asked for.
func is_permitted() -> bool:
	if OS.get_name() != "Android":
		return true
	return OS.get_granted_permissions().has(PERMISSION)

## Hold to talk. The microphone starts here and nowhere else.
## Whether talking is allowed at all. A parent's switch, and the one this file
## actually has to obey: hiding the button would be a promise about the
## interface, and this is a promise about the microphone — and about the
## speaker.
##
## It used to stop only the microphone. A parent who switched voice off had
## stopped their child being heard, and every other voice in the valley went on
## playing to them, which is not what anybody switching voice off means.
var allowed := true:
	set(value):
		allowed = value
		if not allowed:
			# Everyone already speaking goes quiet now, mid-word, rather than
			# finishing what was in the buffer.
			forget_everyone()

func start_talking() -> void:
	if not allowed:
		return
	if not _available or _talking or _session == null:
		return
	# Somebody has to be in the valley, not merely a door held open: a host
	# waiting alone has nobody to hear, and the microphone is not opened for
	# nobody. (The button is not offered then either; see main.gd.)
	if not _session.has_company():
		return

	# Asked for here, on the press, rather than at startup — see the note at the
	# top of this file. The dialog is answered after this frame, and if the
	# button is still down then, `_on_permission_answered` carries on.
	_held = true
	if not is_permitted():
		OS.request_permission(PERMISSION)
		return
	_talking = true
	_capture.clear_buffer()
	# A new press is a new stream: nothing is left over from the last one.
	_phase = 0.0
	_hang = 0
	_preroll = PackedByteArray()
	_microphone.play()
	_hush_the_others(true)
	talking_changed.emit(true)

## Let go. The microphone stops here, and this is the only place it can be
## running from.
func stop_talking() -> void:
	_held = false
	if not _talking:
		return
	_talking = false
	if _microphone != null:
		_microphone.stop()
	if _capture != null:
		_capture.clear_buffer()
	_hush_the_others(false)
	talking_changed.emit(false)

## The microphone does not stay live behind the child's back.
##
## Holding the talk button is the only thing that keeps it open, and the button
## is released by a touch event. Pressing Home, a phone call, or the app
## switcher takes the app away mid-press and the release is never delivered, so
## the microphone stayed open and sending to the others' phones until the
## child came back and pressed again.
func _notification(what: int) -> void:
	if (
		what == NOTIFICATION_APPLICATION_PAUSED
		or what == NOTIFICATION_APPLICATION_FOCUS_OUT
		or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT
	):
		stop_talking()

func _process(delta: float) -> void:
	_listen(delta)
	if not _talking or _capture == null or _session == null:
		return
	# The connection can drop while a child is still holding the button, and
	# talking into a valley that is no longer there should stop the microphone
	# rather than leave it running.
	if not _session.is_connected_to_anyone():
		stop_talking()
		return
	# Nor into a valley whose last visitor has gone while the line stays up: a
	# host is still connected then, but the talk button is taken away (see
	# main.gd) and a hidden button never delivers its release, so the
	# microphone and the hush on the valley's sounds stayed on for good.
	if not _session.has_company():
		stop_talking()
		return

	var step := ratio()
	var wanted := frames_for(step, _phase)
	# can_get_buffer rather than get_frames_available: before the capture bus has
	# run once its buffer does not exist, and asking the latter prints an engine
	# error each frame on a phone whose audio thread starts a moment late; the
	# former answers false quietly and the loop simply waits for the next frame.
	while _capture.can_get_buffer(wanted):
		var frames := _capture.get_buffer(wanted)
		_send_gated(frames, step)
		# The fraction of a frame this packet did not use is where the next
		# one starts. Dropped, it is a ninth of a sample lost per packet, which
		# adds up to the drift this replaced.
		_phase = _phase + float(FRAMES_PER_PACKET) * step - float(wanted)
		wanted = frames_for(step, _phase)

## Send a packet, unless it is only the room. See GATE_PEAK.
func _send_gated(frames: PackedVector2Array, step: float) -> void:
	var packet := pack(frames, step, _phase)
	if peak(frames) >= GATE_PEAK:
		if _hang == 0 and not _preroll.is_empty():
			_send_voice.rpc(_preroll)
		_hang = GATE_HANG
	elif _hang > 0:
		_hang -= 1
	else:
		_preroll = packet
		return
	_preroll = PackedByteArray()
	_send_voice.rpc(packet)

## Voice is sent unreliably: a lost packet is a click, and a resent one arrives
## after the word it belonged to and is worse than silence.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _send_voice(packet: PackedByteArray) -> void:
	if not allowed:
		return
	# One packet's worth and no more. Every phone running this game sends
	# exactly this many bytes; anything else did not come from one, and a
	# packet of any size it pleased was decoded sample by sample on the main
	# thread.
	if packet.size() != FRAMES_PER_PACKET * 2:
		return
	var from := multiplayer.get_remote_sender_id()
	# Only somebody who is in the valley. A packet can still be in flight when
	# its sender leaves, and forget() has already closed their player: hearing
	# it opened a new one for a child who had gone, which then sat there for
	# the rest of the game.
	if _session == null or not _session.guests.has(from):
		return
	_play(from, packet)
	someone_spoke.emit(from)

func _play(from: int, packet: PackedByteArray) -> void:
	# This child is talking, so the room is not being listened to: see
	# _hush_the_others. The packet is dropped rather than queued, or the last
	# of what a brother said while they held the button would come out of the
	# speaker after they let go.
	if _talking:
		return
	var playback := _speaker_for(from)
	if playback == null:
		return
	_heard_at[from] = Time.get_ticks_msec()

	var frames := PackedVector2Array()
	for i in packet.size() / 2:
		var value := float(packet.decode_s16(i * 2)) / 32767.0
		frames.append(Vector2(value, value))

	# Playing already, unless it has run dry: then it was a stutter, and the
	# next stretch is held back to build up again rather than played in
	# fragments as it trickles in.
	if _primed.get(from, false) and _queued(from, playback) <= 0:
		_primed[from] = false
	var waiting: PackedVector2Array = _pending.get(from, PackedVector2Array())
	waiting.append_array(frames)
	_pending[from] = waiting
	if _primed.get(from, false) or float(waiting.size()) >= PREBUFFER * float(RATE):
		_prime(from)

## Start a speaker's held-back frames playing.
func _prime(from: int) -> void:
	var waiting: PackedVector2Array = _pending.get(from, PackedVector2Array())
	_pending[from] = PackedVector2Array()
	_primed[from] = true
	var playback := _speaker_for(from)
	if playback == null:
		return
	for frame in waiting:
		if playback.get_frames_available() <= 0:
			# Behind, and the choice is to drop the newest or to grow a delay
			# that never recovers. Dropping keeps the conversation in time.
			break
		playback.push_frame(frame)

## How many frames a speaker has queued and not yet played.
func _queued(from: int, playback: AudioStreamGeneratorPlayback) -> int:
	return int(_capacity.get(from, 0)) - playback.get_frames_available()

## How many frames of this speaker are being held back for the prebuffer. For
## the checks.
func held_frames(id: int) -> int:
	var waiting: PackedVector2Array = _pending.get(id, PackedVector2Array())
	return waiting.size()

## Whether this speaker's voice is playing (as opposed to filling up).
func is_playing_voice(id: int) -> bool:
	return _primed.get(id, false)

## Each frame: let a voice that has stopped finish, and turn the game's own
## sounds down under anyone speaking.
##
## Also while this child is the one talking. The phone's speaker is what the
## microphone hears of the game, as much as of a brother's voice, and a valley
## full of birdsong going into every word is the other half of the echo.
func _listen(delta: float) -> void:
	var now := Time.get_ticks_msec()
	var heard := false
	for id in _speakers.keys():
		var at: int = _heard_at.get(id, -SPEECH_MSEC * 2)
		if now - at > SPEECH_MSEC:
			if held_frames(id) > 0:
				_prime(id)
		else:
			heard = true
	var target := 1.0 if heard or _talking else 0.0
	if target == _duck:
		return
	var seconds := DUCK_ATTACK if target > _duck else DUCK_RELEASE
	_duck = move_toward(_duck, target, delta / seconds)
	Mix.duck(_duck)

## Silence the other children while this child is holding the button.
##
## The phones are in one room. Everyone hears the talker through the air at
## once and again out of their own phone a third of a second later, and with
## three devices that is two late copies — which is the "weird echo" a child
## described. There is no acoustic echo cancellation to be had here, but
## push-to-talk gives the next best thing for nothing: while you are talking,
## you are not listening, so the room stops answering itself. Let go and
## everyone comes back.
func _hush_the_others(quiet: bool) -> void:
	for id in _speakers:
		var player: AudioStreamPlayer = _speakers[id]
		if is_instance_valid(player):
			player.volume_db = -80.0 if quiet else 0.0

## One player per speaker, made on first hearing them.
func _speaker_for(id: int) -> AudioStreamGeneratorPlayback:
	if _speakers.has(id):
		var existing: AudioStreamPlayer = _speakers[id]
		if is_instance_valid(existing):
			return existing.get_stream_playback()
		_speakers.erase(id)
		_forget_state(id)

	var generator := AudioStreamGenerator.new()
	generator.mix_rate = RATE
	# A tenth of a second of slack held speech to two packets' worth of buffer,
	# so any single stutter on the sending phone — a frame the OS was slow to
	# hand back, a scene load — arrived as a burst that filled the buffer and
	# had the rest dropped, one lost word at a time: reported as "can hear them,
	# just not properly." A fifth of a second rides out that kind of hitch at
	# the cost of a little more delay, which a child mid-sentence won't notice.
	generator.buffer_length = 0.2

	var player := AudioStreamPlayer.new()
	player.stream = generator
	# Somebody who starts speaking while this child is mid-sentence is held
	# quiet like everyone else, rather than arriving at full volume into the
	# one moment the room is meant to be listening to one voice.
	player.volume_db = -80.0 if _talking else 0.0
	add_child(player)
	player.play()
	_speakers[id] = player
	_capacity[id] = player.get_stream_playback().get_frames_available()
	_primed[id] = false
	_pending[id] = PackedVector2Array()
	return player.get_stream_playback()

## Somebody left the valley, so their voice goes with them.
func forget(id: int) -> void:
	if not _speakers.has(id):
		return
	var player: AudioStreamPlayer = _speakers[id]
	if is_instance_valid(player):
		player.queue_free()
	_speakers.erase(id)
	_forget_state(id)

func _forget_state(id: int) -> void:
	_pending.erase(id)
	_primed.erase(id)
	_heard_at.erase(id)
	_capacity.erase(id)

func forget_everyone() -> void:
	for id in _speakers.keys():
		forget(id)
	stop_talking()
