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
## as everything else, and a child can only be in the valley by invitation. There
## is no lobby, no matchmaking, and no way for a stranger to be on the other end
## — not because it is filtered, but because there is no path.
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

## Voice needs far less than music. 11 kHz mono is telephone quality and plenty
## for one child shouting about a football; it is a quarter of the data of the
## mix rate, which matters on a tablet's wifi.
const RATE := 11025
const DOWNSAMPLE := 4

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
func start_talking() -> void:
	if not _available or _talking or _session == null:
		return
	if not _session.is_connected_to_anyone():
		return

	# Asked for here, on the press, rather than at startup — see the note at the
	# top of this file. The dialog is answered after this frame, so this press
	# does not carry; the next one does. That is one lost press, once, in
	# exchange for a permission request that explains itself.
	if not is_permitted():
		OS.request_permission(PERMISSION)
		return
	_talking = true
	_capture.clear_buffer()
	_microphone.play()
	talking_changed.emit(true)

## Let go. The microphone stops here, and this is the only place it can be
## running from.
func stop_talking() -> void:
	if not _talking:
		return
	_talking = false
	if _microphone != null:
		_microphone.stop()
	if _capture != null:
		_capture.clear_buffer()
	talking_changed.emit(false)

func _process(_delta: float) -> void:
	if not _talking or _capture == null or _session == null:
		return
	# The connection can drop while a child is still holding the button, and
	# talking into a valley that is no longer there should stop the microphone
	# rather than leave it running.
	if not _session.is_connected_to_anyone():
		stop_talking()
		return

	var wanted := FRAMES_PER_PACKET * DOWNSAMPLE
	while _capture.get_frames_available() >= wanted:
		var frames := _capture.get_buffer(wanted)
		_send_voice.rpc(_pack(frames))

## Stereo float frames at the mix rate become mono 16-bit at a quarter of it.
##
## Averaged rather than sampled, because taking every fourth frame aliases:
## high frequencies fold down into the voice and it sounds like a robot.
func _pack(frames: PackedVector2Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(FRAMES_PER_PACKET * 2)
	for i in FRAMES_PER_PACKET:
		var sum := 0.0
		for step in DOWNSAMPLE:
			var frame := frames[i * DOWNSAMPLE + step]
			sum += (frame.x + frame.y) * 0.5
		var value := clampf(sum / float(DOWNSAMPLE), -1.0, 1.0)
		out.encode_s16(i * 2, int(value * 32767.0))
	return out

## Voice is sent unreliably: a lost packet is a click, and a resent one arrives
## after the word it belonged to and is worse than silence.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _send_voice(packet: PackedByteArray) -> void:
	var from := multiplayer.get_remote_sender_id()
	_play(from, packet)
	someone_spoke.emit(from)

func _play(from: int, packet: PackedByteArray) -> void:
	var playback := _speaker_for(from)
	if playback == null:
		return
	var count := packet.size() / 2
	for i in count:
		if playback.get_frames_available() <= 0:
			# Behind, and the choice is to drop the newest or to grow a delay
			# that never recovers. Dropping keeps the conversation in time.
			break
		var value := float(packet.decode_s16(i * 2)) / 32767.0
		playback.push_frame(Vector2(value, value))

## One player per speaker, made on first hearing them.
func _speaker_for(id: int) -> AudioStreamGeneratorPlayback:
	if _speakers.has(id):
		var existing: AudioStreamPlayer = _speakers[id]
		if is_instance_valid(existing):
			return existing.get_stream_playback()
		_speakers.erase(id)

	var generator := AudioStreamGenerator.new()
	generator.mix_rate = RATE
	# A tenth of a second of slack. Longer would ride out worse wifi at the cost
	# of a delay children would talk over.
	generator.buffer_length = 0.1

	var player := AudioStreamPlayer.new()
	player.stream = generator
	add_child(player)
	player.play()
	_speakers[id] = player
	return player.get_stream_playback()

## Somebody left the valley, so their voice goes with them.
func forget(id: int) -> void:
	if not _speakers.has(id):
		return
	var player: AudioStreamPlayer = _speakers[id]
	if is_instance_valid(player):
		player.queue_free()
	_speakers.erase(id)

func forget_everyone() -> void:
	for id in _speakers.keys():
		forget(id)
	stop_talking()
