class_name RideSounds
extends Node3D

## The sound of the fairground's machines: the wheel's motor, the coaster's
## chain, the tower's hoist and the ship's swing, each a quiet loop from the
## ride's own middle that is heard only near it, and only while it moves.
##
## The carousel has its own music (Carousel.MUSIC_REACH, -12 dB at speed); the
## machines are kept below it and share its reach, so walking round the
## fairground is a handful of sounds fading in and out, never a wall of noise.
## This only watches the rides: it reads how fast each one is going and never
## touches their clocks or phases.

## The same reach as the carousel's tune, and the same gentle ceiling.
const REACH := Carousel.MUSIC_REACH
const MAX_DB := -8.0
## How loud a machine is at full tilt, and where it goes when it stops.
const RUNNING_DB := -19.0
const SILENT_DB := -60.0
## How quickly the level follows the ride, in decibels a second.
const FADE_DB_PER_SECOND := 30.0

class Machine extends RefCounted:
	var player: AudioStreamPlayer3D
	var base_pitch := 1.0
	var pitch_swing := 0.0
	var last_turn := NAN

var _park: Park
var _machines: Array[Machine] = []
var _wheel: Machine
var _coaster: Machine
var _tower: Machine
var _ship: Machine

func _init(park: Park) -> void:
	name = "RideSounds"
	_park = park

func _ready() -> void:
	var hum := Sounds.ride_hum()
	var chain := Sounds.chain_clatter()
	_wheel = _machine(_park.wheel.position + Vector3(0.0, FerrisWheel.RADIUS * 0.5, 0.0), hum, 0.85, 0.0, 6.0)
	_coaster = _machine(_park.coaster.position + Vector3(0.0, 3.0, 0.0), chain, 0.8, 0.8, 8.0)
	_tower = _machine(_park.drop_tower.position + Vector3(0.0, 8.0, 0.0), hum, 1.2, 0.0, 4.0)
	_ship = _machine(_park.pirate_ship.position + Vector3(0.0, 5.0, 0.0), hum, 0.62, 0.0, 5.0)

func _machine(at: Vector3, stream: AudioStream, pitch: float, swing: float, unit: float) -> Machine:
	var machine := Machine.new()
	var player := AudioStreamPlayer3D.new()
	player.bus = Mix.WORLD
	player.stream = stream
	player.max_distance = REACH
	player.unit_size = unit
	player.max_db = MAX_DB
	player.volume_db = SILENT_DB
	player.pitch_scale = pitch
	player.position = at
	add_child(player)
	machine.player = player
	machine.base_pitch = pitch
	machine.pitch_swing = swing
	_machines.append(machine)
	return machine

## How hard each ride is working, nought to one, from what each already says
## about itself.
func _activity(machine: Machine, delta: float) -> float:
	if machine == _wheel:
		var turn := _park.wheel.turned()
		var rate := 0.0
		if not is_nan(machine.last_turn) and delta > 0.0:
			rate = absf(angle_difference(machine.last_turn, turn)) / delta
		machine.last_turn = turn
		return clampf(rate / FerrisWheel.TURN_RATE, 0.0, 1.0)
	if machine == _coaster:
		return clampf(_park.coaster.speed() / 12.0, 0.0, 1.0)
	if machine == _tower:
		return _park.drop_tower.activity()
	return _park.pirate_ship.activity()

func _physics_process(delta: float) -> void:
	for machine in _machines:
		var busy := _activity(machine, delta)
		var target := lerpf(SILENT_DB, RUNNING_DB, sqrt(busy)) if busy > 0.01 else SILENT_DB
		var player := machine.player
		player.volume_db = move_toward(player.volume_db, target, FADE_DB_PER_SECOND * delta)
		player.pitch_scale = machine.base_pitch + machine.pitch_swing * busy * 0.5
		var audible := player.volume_db > SILENT_DB + 0.5
		if audible and not player.playing:
			player.play()
		elif not audible and player.playing:
			player.stop()

## Is this machine sounding? For the checks.
func sounding(index: int) -> bool:
	return index < _machines.size() and _machines[index].player.playing
