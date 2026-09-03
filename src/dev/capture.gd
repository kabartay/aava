extends Node3D

## Screenshot tool.
##
## This project is written without the Godot editor, so the only way to judge how
## the world actually looks is to render it and open the image. This scene builds
## the real world — the same World class the game uses — parks a camera at a
## chosen spot and time of day, and writes a PNG.
##
## Usage:
##   godot --path . res://dev/capture.tscn -- --out=/tmp/shot.png --time=0.36 \
##         --pos=0,12,40 --look=0,2,0 --seed=20260903
##
## Debug switches, because a screenshot of a wrong scene is worse than none:
##   --player=1     spawn the real player and shoot through the game camera
##   --yaw=DEG      camera yaw in player mode
##   --pitch=DEG    camera pitch in player mode
##   --nowater=1    leave the water sheet out, to see the ground under it
##   --unshaded=1   draw the terrain as flat vertex colour, no lighting at all,
##                  which separates "the colours are wrong" from "the light is"

const DEFAULT_OUT := "user://capture.png"

var _out := DEFAULT_OUT
var _time := 0.36
var _camera_position := Vector3(0.0, 14.0, 46.0)
var _look_at := Vector3(0.0, 2.0, 0.0)
var _seed := 20260903
var _warmup_frames := 900
var _hide_water := false
var _unshaded := false
var _with_player := false
var _yaw := 0.0
var _pitch := -16.0
var _player: Player
var _rig: CameraRig

var _world: World
var _camera: Camera3D

func _ready() -> void:
	_parse_arguments()

	_world = World.new(_seed)
	add_child(_world)
	if _hide_water:
		_world.water.visible = false
	if _unshaded:
		_world.terrain.set_unshaded(true)

	if _with_player:
		_spawn_player()
	else:
		_camera = Camera3D.new()
		_camera.fov = 62.0
		_camera.far = 4000.0
		_camera.position = _camera_position
		add_child(_camera)
		_camera.look_at(_look_at, Vector3.UP)

	_world.atmosphere.set_time(_time)
	# Terrain streams a couple of chunks per frame, so a capture taken on frame
	# one would photograph an empty world. Waiting is not optional here.
	_world.follow(_camera_position)

	await _wait_for_world()
	_report_scene()
	await _capture()
	get_tree().quit()

## Wait until the terrain has actually finished streaming, with a hard cap so a
## generation bug shows up as a bad screenshot instead of a hung process.
## Player mode: the same objects the game builds, aimed by flags so a shot can
## be composed from the terminal.
func _spawn_player() -> void:
	InputActions.register()
	var spawn := _world.field.find_spawn_point()
	_player = Player.new()
	_player.position = spawn + Vector3.UP * 1.2
	_player.set_physics_process(false)
	add_child(_player)

	_rig = CameraRig.new(_player)
	_rig.yaw = deg_to_rad(_yaw)
	_rig.pitch = deg_to_rad(_pitch)
	_player.add_child(_rig)
	_camera = _rig.camera
	_camera.current = true

	var hud := Hud.new()
	hud.camera_dragged.connect(_rig.orbit)
	add_child(hud)

	_world.follow(spawn)

func _wait_for_world() -> void:
	var frames := 0
	while frames < _warmup_frames:
		# Time is pinned so the sun does not crawl across the sky while waiting.
		_world.atmosphere.set_time(_time)
		await RenderingServer.frame_post_draw
		frames += 1
		if _world.terrain.is_idle() and _world.vegetation.is_idle() and frames > 8:
			break
	if not _world.terrain.is_idle() or not _world.vegetation.is_idle():
		printerr("world still streaming after %d frames" % frames)
	# Let the player fall the last centimetres onto ground that now exists, and
	# the camera settle behind them.
	if _player != null:
		_player.set_physics_process(true)
		for _i in 40:
			await RenderingServer.frame_post_draw
	# A few extra frames so shadow splits and the sky have settled.
	for _i in 6:
		_world.atmosphere.set_time(_time)
		await RenderingServer.frame_post_draw
	print("world ready after %d frames" % frames)

## What is actually in the scene. A screenshot cannot distinguish "the camera is
## pointing the wrong way" from "the geometry was never built", and guessing
## between those two costs far more time than printing the answer.
func _report_scene() -> void:
	var chunks := 0
	var surfaces := 0
	var triangles := 0
	var bounds := AABB()
	for child in _world.terrain.get_children():
		if child is not TerrainChunk:
			continue
		chunks += 1
		for grandchild in child.get_children():
			var visual := grandchild as MeshInstance3D
			if visual == null:
				continue
			surfaces += visual.mesh.get_surface_count()
			for surface in visual.mesh.get_surface_count():
				var index_count: int = visual.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX].size()
				triangles += index_count / 3
			var box := visual.get_aabb()
			box.position += child.position
			bounds = box if chunks == 1 else bounds.merge(box)
	var plants := 0
	for tile in _world.vegetation.get_children():
		for layer in tile.get_children():
			var multi := layer as MultiMeshInstance3D
			if multi != null:
				plants += multi.multimesh.instance_count
	print("scene: chunks=%d surfaces=%d triangles=%d plants=%d" % [chunks, surfaces, triangles, plants])
	print("bounds: %v size %v" % [bounds.position, bounds.size])
	print("camera: pos=%v looking=%v fov=%.0f far=%.0f" % [
		_camera.global_position, -_camera.global_transform.basis.z, _camera.fov, _camera.far])
	if _player != null:
		print("player: pos=%v grounded=%s ground_exists=%s" % [
			_player.global_position, _player.is_on_floor(),
			_world.terrain.has_ground_at(_player.global_position)])

func _capture() -> void:
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(_out)
	if error != OK:
		printerr("capture failed: %s (%d)" % [_out, error])
	else:
		print("capture written: %s" % _out)

func _parse_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		var parts := argument.split("=", true, 1)
		if parts.size() != 2:
			continue
		var key := parts[0].lstrip("-")
		var value := parts[1]
		match key:
			"out":
				_out = value
			"time":
				_time = value.to_float()
			"seed":
				_seed = value.to_int()
			"warmup":
				_warmup_frames = value.to_int()
			"nowater":
				_hide_water = value.to_int() != 0
			"unshaded":
				_unshaded = value.to_int() != 0
			"player":
				_with_player = value.to_int() != 0
			"yaw":
				_yaw = value.to_float()
			"pitch":
				_pitch = value.to_float()
			"pos":
				_camera_position = _to_vector(value, _camera_position)
			"look":
				_look_at = _to_vector(value, _look_at)

func _to_vector(text: String, fallback: Vector3) -> Vector3:
	var parts := text.split(",")
	if parts.size() != 3:
		return fallback
	return Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())
