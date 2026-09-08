class_name Minimap
extends PanelContainer

## A map in the corner, with north on it.
##
## Drawn from the height field directly rather than from a rendered viewport: a
## second 3D camera costs a whole extra pass over the world every frame, and
## what a child needs from a map — where is the river, where is the pitch, which
## way am I facing — is exactly what the height field already knows.
##
## It has three sizes rather than two, because "hidden" and "visible" is not
## enough: a small map is for glancing at while walking, and a large one is for
## working out where to go. Tapping cycles through them.
##
## The picture is baked on a worker thread. It was drawn on the main thread,
## one height-field sample per two metres — five thousand samples for the small
## map, three hundred thousand for the whole valley, and again every two metres
## walked — and opening the map froze the game for as long as that took, which
## on the phone was seconds. Now a fixed grid of samples is filled in on the
## pool and collected when done; the map keeps showing the last picture until
## the next one lands, and the frame never waits for it.
##
## The places worth walking to are on every size of the map, as pictures,
## and a place off the edge of the map sits on the edge pointing at itself.
## They were coloured squares on the whole-valley view only, and a child
## standing at the playground wanting the football pitch had no way to know
## which way to set off.

## FULL shows the whole valley at once. It exists because the places a child is
## looking for are now four hundred metres apart: without a view of everything,
## a new world is a green field with no way to tell which direction anything is
## in. Reached by tapping twice, so it is out of the way until it is wanted.
enum Size {HIDDEN, SMALL, LARGE, FULL}

const SMALL_PIXELS := 190.0
const LARGE_PIXELS := 340.0
## Big enough to pick a direction from, and still not the whole screen — a child
## should be able to see where they are going while the map is open.
const FULL_PIXELS := 560.0

## How many metres across the map shows at each size. The small one is a
## neighbourhood; the large one should reach the mountains, so that a child can
## see the shape of the whole valley and not merely his own footprints.
const SMALL_RANGE := 150.0
const LARGE_RANGE := 460.0
## The whole playable valley, which is about a kilometre across.
const FULL_RANGE := 1100.0

## Samples across the picture, at every size. The picture is what the eye
## reads, not the metres, so the small map is fine-grained and the whole
## valley coarse — and every bake costs the same twelve thousand samples.
const CELLS := 112

const WATER := Color(0.36, 0.55, 0.70)
const SAND := Color(0.80, 0.74, 0.56)
const GRASS := Color(0.38, 0.56, 0.32)
const FOREST := Color(0.20, 0.38, 0.22)
const ROCK := Color(0.52, 0.50, 0.50)
const SNOW := Color(0.90, 0.92, 0.95)
const PITCH := Color(0.30, 0.62, 0.30)
## The worn routes between the places, which are the answer to "which way".
const PATH := Color(0.74, 0.64, 0.44)
const BUILT := Color(1.0, 0.86, 0.42)

var _size := Size.SMALL
var _field: HeightField
var _canvas: TextureRect
var _image: Image
var _texture: ImageTexture
var _player_dot: Control
var _compass: Label
var _built: Array[Vector3] = []

## Where each destination is in the world, and the glyph that stands for it.
var _destinations: Array[Dictionary] = []

## Where the map was last drawn from, so it is only redrawn when the player has
## actually gone somewhere.
var _drawn_at := Vector3(1e9, 1e9, 1e9)
var _drawn_size := Size.HIDDEN

## The bake in flight, if any: which size and centre it is for, and the bytes
## it produces, handed across under the mutex.
var _bake_task := -1
var _bake_size := Size.HIDDEN
var _bake_centre := Vector3.ZERO
var _bake_bytes := PackedByteArray()
var _bake_mutex := Mutex.new()

func _init(field: HeightField) -> void:
	_field = field

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.12, 0.72)
	style.set_corner_radius_all(14)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	style.border_color = Color(1.0, 1.0, 1.0, 0.14)
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_canvas = TextureRect.new()
	# Scaled to fill and left crisp rather than smoothed: interpolation turned
	# a legible little chart of the valley into a green smear.
	_canvas.stretch_mode = TextureRect.STRETCH_SCALE
	# Without this the TextureRect draws the texture at its own size in the
	# corner and leaves the rest of the panel empty: expand_mode decides
	# whether the node may be larger than the image it holds, and the default
	# says no.
	_canvas.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)

	# One texture for the life of the map: every bake is CELLS square, so the
	# picture is updated in place rather than replaced.
	_image = Image.create_empty(CELLS, CELLS, false, Image.FORMAT_RGB8)
	_image.fill(Color(0.12, 0.16, 0.14))
	_texture = ImageTexture.create_from_image(_image)
	_canvas.texture = _texture

	# The destinations, each with its picture. Added to the canvas, not to
	# this container: a PanelContainer stretches every direct child to fill
	# it, and a dot once became a white sheet over the whole map.
	var camp := field.camp_centre()
	_add_destination(PlaceGlyph.Kind.HOME, camp)
	_add_destination(PlaceGlyph.Kind.PLAYGROUND, PlaceSpec.centre_of(&"playground", camp))
	_add_destination(PlaceGlyph.Kind.CAFE, PlaceSpec.centre_of(&"cafe", camp))
	_add_destination(PlaceGlyph.Kind.POOL, PlaceSpec.centre_of(&"pool", camp))
	_add_destination(PlaceGlyph.Kind.PITCH, Pitch.centre())
	_add_destination(PlaceGlyph.Kind.RANGE, camp + PlaceSpec.RANGE_OFFSET)

	# The player is always at the centre of his own map, so this is a fixed
	# marker rather than something that has to be positioned each frame. An
	# arrow rather than a dot, because it has to say which way as well as
	# where — see the note on _orient.
	_player_dot = MapArrow.new()
	_canvas.add_child(_player_dot)

	_compass = Label.new()
	_compass.text = "N"
	_compass.add_theme_font_size_override("font_size", 18)
	_compass.add_theme_color_override("font_color", Color(1.0, 0.94, 0.80))
	_compass.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_compass.add_theme_constant_override("outline_size", 5)
	_compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_compass)

	_apply_size()

func _add_destination(kind: PlaceGlyph.Kind, at: Vector3) -> void:
	var glyph := PlaceGlyph.new(kind)
	_canvas.add_child(glyph)
	_destinations.append({"at": at, "glyph": glyph})

## Tap to cycle small, large, whole valley.
func _gui_input(event: InputEvent) -> void:
	# Typed explicitly: `event.pressed` on a base InputEvent is a Variant, and
	# an inferred bool from one is a parse error — the same inference trap in
	# yet another disguise.
	var tapped := false
	if event is InputEventScreenTouch:
		tapped = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		tapped = click.pressed and click.button_index == MOUSE_BUTTON_LEFT
	if not tapped:
		return
	# Tap cycles small, large, whole valley, and back. Hiding belongs to the
	# button outside it: a map that can hide itself leaves nothing to press to
	# bring it back.
	match _size:
		Size.SMALL:
			_size = Size.LARGE
		Size.LARGE:
			_size = Size.FULL
		_:
			_size = Size.SMALL
	_apply_size()
	accept_event()

## Whether the map is showing anything at all. The button outside needs to know,
## because a toggle that does not reflect its own state is worse than no toggle.
func is_showing() -> bool:
	return _size != Size.HIDDEN

## Open at the last used size, or small if it has never been opened.
func show_map() -> void:
	if _size == Size.HIDDEN:
		_size = Size.SMALL
		_apply_size()

func hide_map() -> void:
	_size = Size.HIDDEN
	_apply_size()

func _apply_size() -> void:
	var pixels := SMALL_PIXELS
	if _size == Size.LARGE:
		pixels = LARGE_PIXELS
	elif _size == Size.FULL:
		pixels = FULL_PIXELS
	visible = _size != Size.HIDDEN
	custom_minimum_size = Vector2(pixels, pixels)
	size = Vector2(pixels, pixels)
	_canvas.custom_minimum_size = Vector2(pixels, pixels)
	_canvas.size = Vector2(pixels, pixels)

## Who to follow. Given the player and camera once, the map keeps itself up to
## date in _process rather than waiting to be told each frame.
##
## It was driven from the game's main loop, and the screenshot tool — which
## builds the same interface but runs no game loop — therefore showed an empty
## panel. A widget that only works when something remembers to poke it will
## eventually meet something that forgets.
var _follow_player: Node3D
var _follow_camera: CameraRig
var _follow_structures: Structures

func follow(player: Node3D, camera: CameraRig, structures: Structures) -> void:
	_follow_player = player
	_follow_camera = camera
	_follow_structures = structures

func _process(_delta: float) -> void:
	if _follow_player == null or not is_instance_valid(_follow_player):
		return
	track(
		_follow_player.global_position,
		_follow_camera.yaw if _follow_camera != null else 0.0,
		_follow_structures.positions() if _follow_structures != null else ([] as Array[Vector3])
	)

## Called with where the player is and which way the camera looks.
func track(world_position: Vector3, yaw: float, built: Array[Vector3]) -> void:
	if _size == Size.HIDDEN:
		return
	_built = built
	_collect_bake()
	var range_metres := range_of(_size)
	# Redraw after real movement — a fiftieth of the map's width — or at a new
	# size, and never while a bake is already on its way.
	var stale := _size != _drawn_size or world_position.distance_to(_drawn_at) > range_metres / 50.0
	if stale and _bake_task < 0:
		_start_bake(world_position)
	_place_destinations(world_position, range_metres)
	_orient(yaw)

## Wait for the picture, for a screenshot or a check that wants it now.
func wait_for_bake() -> void:
	if _bake_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_bake_task)
		_finish_bake()

## Whether a picture has been drawn for the current size. For the checks.
func is_drawn() -> bool:
	return _drawn_size == _size

func _start_bake(centre: Vector3) -> void:
	_bake_size = _size
	_bake_centre = centre
	var step := range_of(_size) / float(CELLS)
	_bake_task = WorkerThreadPool.add_task(_bake.bind(centre, step), false, "minimap")

## The picture, sample by sample. Runs on the pool: reads the height field,
## which is read-only once built, and writes only its own bytes.
func _bake(centre: Vector3, step: float) -> void:
	var bytes := PackedByteArray()
	bytes.resize(CELLS * CELLS * 3)
	var half := step * float(CELLS) * 0.5
	var index := 0
	for row in CELLS:
		var world_z := centre.z - half + (float(row) + 0.5) * step
		for column in CELLS:
			var world_x := centre.x - half + (float(column) + 0.5) * step
			var colour := _colour_at(world_x, world_z)
			bytes[index] = int(colour.r * 255.0)
			bytes[index + 1] = int(colour.g * 255.0)
			bytes[index + 2] = int(colour.b * 255.0)
			index += 3
	_bake_mutex.lock()
	_bake_bytes = bytes
	_bake_mutex.unlock()

## Pick up a finished bake, if there is one, and show it.
func _collect_bake() -> void:
	if _bake_task < 0 or not WorkerThreadPool.is_task_completed(_bake_task):
		return
	WorkerThreadPool.wait_for_task_completion(_bake_task)
	_finish_bake()

## Take the bytes of a bake that has been waited for. The task's id is dead
## once it has been waited on — asking the pool about it again is an error —
## so this is separate from the asking.
func _finish_bake() -> void:
	_bake_task = -1
	_bake_mutex.lock()
	var bytes := _bake_bytes
	_bake_bytes = PackedByteArray()
	_bake_mutex.unlock()
	if bytes.size() != CELLS * CELLS * 3:
		return
	_image.set_data(CELLS, CELLS, false, Image.FORMAT_RGB8, bytes)
	_mark_buildings(_bake_centre, range_of(_bake_size))
	_texture.update(_image)
	_drawn_at = _bake_centre
	_drawn_size = _bake_size

func _colour_at(x: float, z: float) -> Color:
	var height := _field.height_at(x, z)
	if height < HeightField.WATER_LEVEL:
		return WATER
	if Pitch.is_in_play(x, z):
		return PITCH
	if height < HeightField.WATER_LEVEL + 1.0:
		return SAND
	if height > 100.0:
		return SNOW
	if _field.path_at(x, z, height) > 0.35:
		return PATH
	if _field.steepness_at(x, z) > 0.45:
		return ROCK
	if _field.forest_density_at(x, z) > 0.3:
		return FOREST
	return GRASS

## North stays at the top and the arrow turns.
##
## It was the other way round: the map was drawn north-up and never moved, while
## the letter N rode around the edge to show which way north lay. That is a
## contradiction — a map that does not turn with a compass mark that does — and
## it read as the map spinning when it was not. Now the map is fixed, north is
## fixed above it, and the only thing that turns is the little arrow that is
## you, which is the one thing that really is turning.
func _orient(yaw: float) -> void:
	var centre := size * 0.5
	_player_dot.position = centre - _player_dot.size * 0.5
	# The map is drawn with world north up, and the camera's yaw is measured the
	# other way round from screen rotation — so the arrow pointed exactly
	# backwards until this was negated.
	_player_dot.rotation = -yaw
	_player_dot.pivot_offset = _player_dot.size * 0.5
	_compass.position = Vector2(centre.x - _compass.size.x * 0.5, 4.0)

## Put each destination's picture where the place is on the map — or, if the
## place is off the map, on the edge of it in that direction, pointing.
func _place_destinations(centre: Vector3, range_metres: float) -> void:
	var half := size.x * 0.5
	var scale := size.x / range_metres
	# Inside this much of the edge a place is drawn where it is; beyond it,
	# it is pinned to the rim.
	var rim := half - PlaceGlyph.SIZE * 0.5 - 4.0
	for destination in _destinations:
		var at: Vector3 = destination["at"]
		var glyph: PlaceGlyph = destination["glyph"]
		var offset := Vector2(at.x - centre.x, at.z - centre.z) * scale
		var reach := maxf(absf(offset.x), absf(offset.y))
		var off_map := reach > rim
		if off_map:
			offset *= rim / reach
		glyph.point(off_map, offset.angle())
		glyph.position = Vector2(half, half) + offset - glyph.size * 0.5

## How many metres across the map shows at a given size.
static func range_of(size: Size) -> float:
	match size:
		Size.SMALL:
			return SMALL_RANGE
		Size.FULL:
			return FULL_RANGE
		_:
			return LARGE_RANGE

## Everything the children have built shows as a bright dot. This is what makes
## the map theirs rather than a survey: the first thing a child looks for is his
## own house.
func _mark_buildings(centre: Vector3, range_metres: float) -> void:
	var step := range_metres / float(CELLS)
	var half := range_metres * 0.5
	for at in _built:
		var column := int((at.x - centre.x + half) / step)
		var row := int((at.z - centre.z + half) / step)
		if column < 1 or row < 1 or column >= CELLS - 1 or row >= CELLS - 1:
			continue
		var spread := PackedInt32Array([-1, 0, 1])
		for dx in spread:
			for dz in spread:
				_image.set_pixel(column + dx, row + dz, BUILT)
