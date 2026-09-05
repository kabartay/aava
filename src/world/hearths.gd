class_name Hearths
extends Node3D

## Fires, and the wood that keeps them going.
##
## This is what the axe is for. Felling a tree gave wood and wood did nothing:
## it was a number in a bag. Now wood burns, a fire that is burning is warm, and
## being warm is worth something on a cold night — so the axe, the tree, the
## coins it cost and the fire it feeds are one loop instead of four unrelated
## things.
##
## It is also the first reason to build rather than to wander. A house with a
## fire in it is somewhere to come back to; a house without one is scenery a
## child assembled.

signal lit(at: Vector3)
signal went_out(at: Vector3)
signal fed(at: Vector3, minutes_left: float)

## How long one log burns. Long enough that feeding a fire is not a chore, short
## enough that a fire left alone goes out while a child is still nearby to
## notice it.
const SECONDS_PER_LOG := 150.0

## The most a fire can hold. A child who tips a whole bag of wood in should not
## get an hour of fire out of it and never think about it again.
const MAX_LOGS := 6

## How near you have to be to feed one, and how far its warmth carries.
const REACH := 3.2
const WARMTH_REACH := 7.5

## How much faster energy comes back beside a burning fire. Rest is the point of
## a fire, so this is generous.
const REST_BONUS := 2.4

var field: HeightField

## Burning fires, keyed by a rounded position so a fire found by walking up to
## it is the same fire that was lit an hour ago.
var _burning: Dictionary = {}
var _flames: Dictionary = {}
## Where each burning fire is, so warmth can be measured without going through
## the flame node — which may be freed a frame before this is asked.
var _where: Dictionary = {}

func _init(height_field: HeightField) -> void:
	field = height_field

## Every campfire that has been built, told to us by the structures.
var _built: Array[Vector3] = []

func set_fires(positions: Array[Vector3]) -> void:
	_built = positions
	# A fire whose campfire has been taken down cannot go on burning.
	for key in _burning.keys():
		var still_there := false
		for at in _built:
			if _key_for(at) == key:
				still_there = true
				break
		if not still_there:
			_extinguish(key)

## The campfire within reach, or an empty vector.
func nearest(at: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var found := false
	var best_distance := REACH
	for fire in _built:
		var distance := fire.distance_to(at)
		if distance < best_distance:
			best_distance = distance
			best = fire
			found = true
	return best if found else Vector3.ZERO

## Is there a campfire close enough to put a log on?
func has_fire_near(at: Vector3) -> bool:
	for fire in _built:
		if fire.distance_to(at) < REACH:
			return true
	return false

## Put a log on. Returns the seconds the fire has left, or zero if there was no
## fire to feed.
func feed(at: Vector3) -> float:
	if not has_fire_near(at):
		return 0.0
	var fire := nearest(at)

	var key := _key_for(fire)
	var burning := float(_burning.get(key, 0.0))
	if burning >= SECONDS_PER_LOG * float(MAX_LOGS):
		return burning

	var was_out := burning <= 0.0
	burning = minf(burning + SECONDS_PER_LOG, SECONDS_PER_LOG * float(MAX_LOGS))
	_burning[key] = burning
	if was_out:
		_light(fire, key)
		lit.emit(fire)
	fed.emit(fire, burning / 60.0)
	return burning

## How warm it is where the player is standing, from 0 to 1.
##
## Warmth is a place, not a state a child carries: step away from the fire and
## it is gone. That is what makes a fire somewhere to be rather than a button.
func warmth_at(at: Vector3) -> float:
	var warmest := 0.0
	for key in _burning:
		if float(_burning[key]) <= 0.0:
			continue
		var fire: Vector3 = _where.get(key, Vector3.ZERO)
		var distance := fire.distance_to(at)
		if distance > WARMTH_REACH:
			continue
		warmest = maxf(warmest, 1.0 - smoothstep(WARMTH_REACH * 0.35, WARMTH_REACH, distance))
	return warmest

func is_burning(at: Vector3) -> bool:
	return float(_burning.get(_key_for(at), 0.0)) > 0.0

func minutes_left(at: Vector3) -> float:
	return float(_burning.get(_key_for(at), 0.0)) / 60.0

func _process(delta: float) -> void:
	for key in _burning.keys():
		var left := float(_burning[key]) - delta
		if left <= 0.0:
			_extinguish(key)
			continue
		_burning[key] = left
		if _flames.has(key):
			var flame: Node3D = _flames[key]
			if is_instance_valid(flame):
				# Guttering, and lower as the fuel runs down, so a fire that is
				# nearly out looks nearly out.
				var fuel := clampf(left / SECONDS_PER_LOG, 0.25, 1.0)
				var flicker := 0.85 + 0.15 * sin(float(Time.get_ticks_msec()) * 0.011)
				flame.scale = Vector3.ONE * fuel * flicker
				var light: OmniLight3D = flame.get_child(0)
				if light != null:
					light.light_energy = 2.6 * fuel * flicker

func _light(at: Vector3, key: Vector3i) -> void:
	if _flames.has(key):
		return
	var flame := Node3D.new()
	add_child(flame)
	flame.global_position = at + Vector3(0.0, 0.35, 0.0)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.36)
	light.omni_range = WARMTH_REACH * 1.6
	light.light_energy = 2.6
	light.shadow_enabled = false
	flame.add_child(light)

	var body := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.26
	cone.height = 0.62
	cone.radial_segments = 7
	body.mesh = cone
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.66, 0.26)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.58, 0.20)
	glow.emission_energy_multiplier = 3.0
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	body.material_override = glow
	body.position.y = 0.31
	flame.add_child(body)

	_flames[key] = flame
	_where[key] = at

func _extinguish(key: Vector3i) -> void:
	var where: Vector3 = _where.get(key, Vector3.ZERO)
	_burning.erase(key)
	_where.erase(key)
	if _flames.has(key):
		var flame: Node3D = _flames[key]
		if is_instance_valid(flame):
			flame.queue_free()
		_flames.erase(key)
	went_out.emit(where)

## Rounded to a decimetre, so a fire is found again at the position it was built
## at rather than at a float that drifted.
static func _key_for(at: Vector3) -> Vector3i:
	return Vector3i(roundi(at.x * 10.0), roundi(at.y * 10.0), roundi(at.z * 10.0))

func to_data() -> Array:
	var out: Array = []
	for key in _burning:
		out.append([key.x, key.y, key.z, _burning[key]])
	return out

func from_data(data: Array) -> void:
	for entry in data:
		if entry is Array and entry.size() >= 4:
			var key := Vector3i(int(entry[0]), int(entry[1]), int(entry[2]))
			_burning[key] = float(entry[3])
			_light(
				Vector3(float(key.x) * 0.1, float(key.y) * 0.1, float(key.z) * 0.1), key
			)
