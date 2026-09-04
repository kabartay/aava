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

enum Size {HIDDEN, SMALL, LARGE}

const SMALL_PIXELS := 190.0
const LARGE_PIXELS := 340.0

## How many metres across the map shows at each size. The small one is a
## neighbourhood; the large one should reach the mountains, so that a child can
## see the shape of the whole valley and not merely his own footprints.
const SMALL_RANGE := 150.0
const LARGE_RANGE := 460.0

## Metres between samples. Coarse on purpose: this is a map, not a photograph,
## and every sample is a call into the height field.
const STEP := 2.0

const WATER := Color(0.36, 0.55, 0.70)
const SAND := Color(0.80, 0.74, 0.56)
const GRASS := Color(0.38, 0.56, 0.32)
const FOREST := Color(0.20, 0.38, 0.22)
const ROCK := Color(0.52, 0.50, 0.50)
const SNOW := Color(0.90, 0.92, 0.95)
const PITCH := Color(0.30, 0.62, 0.30)

var _size := Size.SMALL
var _field: HeightField
var _canvas: TextureRect
var _image: Image
var _texture: ImageTexture
var _player_dot: Control
var _compass: Label
var _built: Array[Vector3] = []

## Where the map was last drawn from, so it is only redrawn when the player has
## actually gone somewhere. Redrawing every frame would sample the height field
## thousands of times a frame for a picture that has not changed.
var _drawn_at := Vector3(1e9, 1e9, 1e9)
var _drawn_size := Size.HIDDEN

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
	# Scaled to fill and left crisp rather than smoothed. The map is 43 pixels
	# across, and interpolation turned a legible little chart of the valley into
	# a green smear.
	_canvas.stretch_mode = TextureRect.STRETCH_SCALE
	# Without this the TextureRect draws the texture at its own 75-pixel size in
	# the corner and leaves the rest of the panel empty: expand_mode decides
	# whether the node may be larger than the image it holds, and the default
	# says no.
	_canvas.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)

	# The player is always dead centre, so the marker is a fixed dot rather than
	# something that has to be positioned.
	# The player is always at the centre of his own map, so this is a fixed
	# marker rather than something that has to be positioned each frame.
	_player_dot = Panel.new()
	var dot := StyleBoxFlat.new()
	dot.bg_color = Color(1.0, 1.0, 1.0, 0.95)
	dot.set_corner_radius_all(6)
	dot.border_color = Color(0.1, 0.12, 0.16, 0.9)
	dot.set_border_width_all(2)
	_player_dot.add_theme_stylebox_override("panel", dot)
	_player_dot.custom_minimum_size = Vector2(12.0, 12.0)
	_player_dot.size = Vector2(12.0, 12.0)
	_player_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Added to the canvas, not to this container: a PanelContainer stretches
	# every direct child to fill it, and the dot became a white sheet over the
	# entire map.
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

## Tap to cycle hidden, small, large.
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
	_size = ((_size + 1) % Size.size()) as Size
	_apply_size()
	accept_event()

func cycle() -> void:
	_size = ((_size + 1) % Size.size()) as Size
	_apply_size()

func _apply_size() -> void:
	var pixels := SMALL_PIXELS if _size == Size.SMALL else LARGE_PIXELS
	visible = _size != Size.HIDDEN
	custom_minimum_size = Vector2(pixels, pixels)
	size = Vector2(pixels, pixels)
	_canvas.custom_minimum_size = Vector2(pixels, pixels)
	_canvas.size = Vector2(pixels, pixels)
	# Force a redraw at the new scale.
	_drawn_at = Vector3(1e9, 1e9, 1e9)

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
	# Redraw only after real movement, or at a new size.
	if _size == _drawn_size and world_position.distance_to(_drawn_at) < STEP:
		_orient(yaw)
		return
	_drawn_at = world_position
	_drawn_size = _size
	_redraw(world_position)
	_orient(yaw)

## The compass letter rides around the edge of the map, so north is a direction
## rather than a label. A child who has been told "the mountains are north" can
## then use it without being taught to read a map.
func _orient(yaw: float) -> void:
	var radius := size.x * 0.5 - 18.0
	var centre := size * 0.5
	_player_dot.position = centre - _player_dot.size * 0.5
	# The map is drawn with world north up, so north on screen is simply up,
	# rotated by however far the camera has turned.
	var angle := yaw - PI * 0.5
	_compass.position = centre + Vector2(cos(angle), sin(angle)) * radius - _compass.size * 0.5

func _redraw(centre: Vector3) -> void:
	var range_metres := SMALL_RANGE if _size == Size.SMALL else LARGE_RANGE
	var cells := int(range_metres / STEP)
	if _image == null or _image.get_width() != cells:
		_image = Image.create_empty(cells, cells, false, Image.FORMAT_RGB8)
		_texture = ImageTexture.create_from_image(_image)
		_canvas.texture = _texture

	var half := range_metres * 0.5
	for row in cells:
		var world_z := centre.z - half + float(row) * STEP
		for column in cells:
			var world_x := centre.x - half + float(column) * STEP
			_image.set_pixel(column, row, _colour_at(world_x, world_z))

	_mark_buildings(centre, range_metres, cells)
	_texture.update(_image)

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
	if _field.steepness_at(x, z) > 0.45:
		return ROCK
	if _field.forest_density_at(x, z) > 0.3:
		return FOREST
	return GRASS

## Everything the children have built shows as a bright dot. This is what makes
## the map theirs rather than a survey: the first thing a child looks for is his
## own house.
func _mark_buildings(centre: Vector3, range_metres: float, cells: int) -> void:
	var half := range_metres * 0.5
	for at in _built:
		var column := int((at.x - centre.x + half) / STEP)
		var row := int((at.z - centre.z + half) / STEP)
		if column < 1 or row < 1 or column >= cells - 1 or row >= cells - 1:
			continue
		var spread := PackedInt32Array([-1, 0, 1])
		for dx in spread:
			for dz in spread:
				_image.set_pixel(column + dx, row + dz, Color(1.0, 0.86, 0.42))
