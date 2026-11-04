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
## What the panel adds round the picture: eight pixels on each side.
const PANEL_MARGINS := 16.0
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
const CELLS := 144

## A bake covers this much more than the view on every side-length, so that walking
## or dragging a little only slides the picture, and a rebake is not needed for
## every few metres.
const BAKE_MARGIN := 1.4

## The round buttons beside the map: thumb-sized on the big maps (the HUD's own
## buttons are 96 base pixels), and smaller on the small one's single button.
const TOOL_BIG := 72.0
const TOOL_SMALL := 52.0
const TOOL_GAP := 8.0

## Pixels in the picture: the grid is painted at twice its resolution, see
## MapPainter. The colours are the painter's, so the map has one palette.
const PIXELS := CELLS * MapPainter.SUPERSAMPLE

const WATER := MapPainter.WATER_DEEP
const SAND := MapPainter.SAND
const GRASS := MapPainter.GRASS
const FOREST := MapPainter.FOREST_MID
const ROCK := MapPainter.ROCK
const SNOW := MapPainter.SNOW
const PITCH := MapPainter.PITCH
## The worn routes between the places, which are the answer to "which way".
const PATH := MapPainter.PATH
## What a child has raised: warm, and the brightest thing on the map, because
## the first thing anybody looks for is their own house.
const BUILT := Color(1.0, 0.86, 0.42)

## And what they have planted. The same yellow was used for both, so a grove a
## child had grown and the house they had built were one indistinguishable
## patch — "is that yellow stuff the trees we planted?" was asked of a map that
## could not answer. A green bright enough to read against the forest behind
## it, and unmistakably not the buildings.
const PLANTED := Color(0.52, 0.90, 0.40)

var _size := Size.SMALL
## Whether the map may grow past small: not while the child is building.
var _kept_small := false
var _field: HeightField
var _canvas: TextureRect
var _image: Image
var _texture: ImageTexture
var _player_dot: Control
var _compass: MapCompass
## The names of the valley's regions, as labels over the picture, and where each
## is in the world. Found once, on the worker, by the first bake.
var _region_labels: Array[Label] = []
var _regions: Array[Dictionary] = []
var _built: Array[Vector3] = []
var _planted: Array[Vector3] = []
## The structures' revision when `_planted` and `_built_copy` were taken. Starts
## at -1 so the first showing always copies.
var _copied_revision := -1
var _built_copy: Array[Vector3] = []

## Where each destination is in the world, and the glyph that stands for it.
## Each entry: "at" (Vector3, Vector3.INF while a moving mark has nothing to
## show), "glyph", and "live" for the marks that move (a friend, a horse).
var _destinations: Array[Dictionary] = []

## A child chose a place by tapping its sticker, or put it away by tapping it
## again: which kind, and whether they are now going there.
signal place_tapped(kind: int, going: bool)

## Who is where, asked of whoever knows: the other children's positions as an
## Array of Vector3, and the nearest horse to a point (Vector3.INF if none).
var friend_source := Callable()
var horse_source := Callable()

## The way to the place the child has chosen. It is the map's, so each phone's
## child has their own, and it lives as long as the map does, open or shut.
var _guide := MapGuide.new()
var _route: MapRoute
var _legend: MapLegend
## Taps arrive as touch and as emulated mouse on some devices: one tap must not
## choose a place and unchoose it again.
var _last_symbol_tap := -1000
## Whether the stickers have been laid out for the size the map is now. Until
## they have they all sit in the corner, and a tap there is a tap on the map.
var _arranged := false

## Where the map was last drawn from, so it is only redrawn when the player has
## actually gone somewhere.
var _drawn_at := Vector3(1e9, 1e9, 1e9)
var _drawn_size := Size.HIDDEN

## How many things were built when the picture was drawn. The whole-valley map
## is pinned to the valley, so its centre never moves and "have we walked far
## enough to redraw" is false for ever — a house built with that map open never
## appeared on it until the child cycled the map to another size and back.
var _drawn_built := -1

## The bake in flight, if any: which size and centre it is for, and the bytes
## it produces, handed across under the mutex.
var _bake_task := -1
var _bake_size := Size.HIDDEN
var _bake_centre := Vector3.ZERO
var _bake_bytes := PackedByteArray()
## The regions a bake found, held here until the main thread has waited for the
## task and moves them into `_regions`: the worker never writes what the main
## thread reads every frame.
var _bake_regions: Array[Dictionary] = []
var _bake_mutex := Mutex.new()
## How many metres across the bake in flight spans, and the one on screen did.
var _bake_range := 0.0
var _drawn_range := 0.0

## Where the map is looking, what the fingers are doing to it, and the parts that
## only exist for looking around (see MapView, MapGesture, MapTool).
var _view := MapView.new()
var _gesture := MapGesture.new()
## True once the child has dragged or zoomed off the point the map follows. The
## map then stays where it was put until "back to me" is pressed, the size is
## changed, or the map is closed.
var _free := false
## The range a zoom button is easing towards, 0 when nothing is easing.
var _zoom_goal := 0.0
var _player_at := Vector3.ZERO
var _picture: TextureRect
var _zoom_in_button: MapTool
var _zoom_out_button: MapTool
var _me_button: MapTool
var _close_button: MapTool
## The layer the buttons stand on, over the whole panel.
var _tools: Control
## The most pixels a picture may have, set by the screen it must fit on; 0 for no limit.
var _fit_pixels := 0.0

## Emitted by the close button, for whatever opened the map to put it away.
signal close_requested

func _init(field: HeightField) -> void:
	_field = field

	add_theme_stylebox_override("panel", MapPainter.frame_style())
	mouse_filter = Control.MOUSE_FILTER_STOP

	_canvas = TextureRect.new()
	# The picture is painted at twice the grid, with its edges already smooth,
	# so it is stretched with filtering: the nearest-neighbour stretch it used
	# to have turned every path into a row of dashes.
	_canvas.stretch_mode = TextureRect.STRETCH_SCALE
	# Without this the TextureRect draws the texture at its own size in the
	# corner and leaves the rest of the panel empty: expand_mode decides
	# whether the node may be larger than the image it holds, and the default
	# says no.
	_canvas.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)

	# One texture for the life of the map: every bake is CELLS square, so the
	# picture is updated in place rather than replaced.
	_image = Image.create_empty(PIXELS, PIXELS, false, Image.FORMAT_RGB8)
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
	_add_destination(PlaceGlyph.Kind.SHOP, PlaceSpec.centre_of(&"shop", camp))
	# The great mountain. It is the one landmark in the world that cannot be
	# walked to and is not on the map at any size — it stands a kilometre past
	# the valley, and the map's widest view is eleven hundred metres across —
	# so without this there was nothing anywhere to answer "which way is it",
	# and the first thing asked about it was exactly that. Off the map is
	# precisely what the rim pointers are for.
	_add_destination(
		PlaceGlyph.Kind.MOUNTAIN,
		Vector3(HeightField.ELBRUS_AT.x, 0.0, HeightField.ELBRUS_AT.y)
	)

	# The crossing. It is the only way over the river on anything with wheels,
	# and a child who has just bought a bicycle has no way of guessing where it
	# is — the river looks the same for a kilometre in both directions.
	_add_destination(
		PlaceGlyph.Kind.BRIDGE,
		Vector3(
			field.river_centre_x(BridgeSpec.CENTRE_Z), 0.0, BridgeSpec.CENTRE_Z
		)
	)

	# The fairground, at its gate: the biggest place in the valley, and the
	# one across the river from the camp that nothing on the map pointed to.
	_add_destination(
		PlaceGlyph.Kind.FAIRGROUND, ParkSpec.gate() + Vector3(0.0, 0.0, -30.0)
	)
	# The ponds: the big one has the boats on it, the other is just a lake.
	var ponds := Lakes.centres()
	if ponds.size() > 0:
		_add_destination(PlaceGlyph.Kind.BOAT, ponds[0])
	if ponds.size() > 1:
		_add_destination(PlaceGlyph.Kind.LAKE, ponds[1])
	# Marks that move: the nearest horse, and the children on other phones.
	_add_destination(PlaceGlyph.Kind.HORSE, Vector3.INF, true)
	for _friend in 3:
		_add_destination(PlaceGlyph.Kind.FRIEND, Vector3.INF, true)

	# An arrow rather than a dot, because it has to say which way as well as
	# where — see the note on _orient. It sits in the middle of the maps that
	# follow the child and moves about on the whole-valley one, which does not.
	_player_dot = MapArrow.new()
	_canvas.add_child(_player_dot)

	# North is a picture, not a letter: a little snow peak on a round badge.
	_compass = MapCompass.new()
	_canvas.add_child(_compass)

	# The way, under the stickers; the key, over everything.
	_route = MapRoute.new()
	_route.size = Vector2(SMALL_PIXELS, SMALL_PIXELS)
	_canvas.add_child(_route)
	_legend = MapLegend.new()
	_canvas.add_child(_legend)

	_setup_view()
	_apply_size()

func _add_destination(kind: PlaceGlyph.Kind, at: Vector3, live := false) -> void:
	var glyph := PlaceGlyph.new(kind)
	glyph.visible = not live
	_canvas.add_child(glyph)
	_destinations.append({"at": at, "glyph": glyph, "live": live})

## Fingers, mouse and trackpad: a drag pans, a pinch or the wheel zooms about the
## point under it, and a tap — a press and lift that went nowhere — cycles the
## size. Everything the gesture reader recognises is taken here, so that nothing
## under the map moves while it is being looked at.
##
## The tap is decided on release (see MapGesture), so a drag or a pinch never
## chooses a symbol: the tap goes first to the stickers and the key, in the map's
## own coordinates, and only a tap on bare map cycles the size.
func _gui_input(event: InputEvent) -> void:
	if _gesture.feed(event, _canvas.position):
		accept_event()

func _on_gesture_tapped(at: Vector2) -> void:
	if handle_symbol_tap(at):
		return
	_cycle_size()

## Tap to cycle small, large, whole valley, and back. Hiding belongs to the
## button outside it: a map that can hide itself leaves nothing to press to
## bring it back.
func _cycle_size() -> void:
	match _size:
		Size.SMALL:
			# Not while building: the bigger maps are centred, over the pieces
			# and the line saying why one cannot go there.
			if not _kept_small:
				_size = Size.LARGE
		Size.LARGE:
			_size = Size.FULL
		_:
			_size = Size.SMALL
	_apply_size()

## Whether the map is showing anything at all. The button outside needs to know,
## because a toggle that does not reflect its own state is worse than no toggle.
func is_showing() -> bool:
	return _size != Size.HIDDEN

## Whether the map is one of the big ones, which cover the middle of the screen.
func is_big() -> bool:
	return _size == Size.LARGE or _size == Size.FULL

## Open at the last used size, or small if it has never been opened.
func show_map() -> void:
	if _size == Size.HIDDEN:
		_size = Size.SMALL
		_apply_size()

## Hold the map to its small size, and bring one that is open larger back down
## to it: while a child builds, the large and whole-valley maps lay over the
## palette, the tabs and the status line, and a tap on them was taken by the
## map. The small one sits in the corner, clear of them all.
func keep_small(kept: bool) -> void:
	_kept_small = kept
	if kept and (_size == Size.LARGE or _size == Size.FULL):
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
	if _fit_pixels > 0.0:
		pixels = minf(pixels, maxf(_fit_pixels, SMALL_PIXELS))
	visible = _size != Size.HIDDEN
	var strip := strip_width_for(pixels)
	# The panel is the picture, the strip of buttons beside it on the big maps, and
	# the panel's margins all round.
	custom_minimum_size = Vector2(pixels + strip + PANEL_MARGINS, pixels + PANEL_MARGINS)
	size = custom_minimum_size
	_canvas.custom_minimum_size = Vector2(pixels, pixels)
	_canvas.size = Vector2(pixels, pixels)
	_reset_view(pixels)
	_size_the_guidance(pixels)

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

## Wait for whatever is still baking before this object goes.
##
## A bake on a worker thread writes its result back into this object. Freed
## first, the worker is left writing into memory that is no longer there — a
## crash, or a script error at "lock on a null value", depending on who wins
## the race. AnimalVoices learnt this on CI; this class had the same exposure
## and nothing closing it.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		# Closed with a finger down: forget it, so that nothing is left holding a
		# drag that will never finish.
		_gesture.cancel()
		return
	if what != NOTIFICATION_PREDELETE:
		return
	if _bake_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_bake_task)
		_bake_task = -1

func _process(delta: float) -> void:
	advance(delta)
	if _follow_player == null or not is_instance_valid(_follow_player):
		return
	_pulse_suggested()
	# The guide follows the child whether or not the map is open.
	guide_step(
		_follow_player.global_position,
		_follow_camera.yaw if _follow_camera != null else 0.0
	)
	# Nothing to copy for a map that is not showing, and nothing to copy again
	# until something is built or taken down. Both lists used to be made afresh
	# every frame, one entry for every piece a child had ever placed — a house
	# is hundreds — and thrown away a sixtieth of a second later.
	var revision := _follow_structures.revision if _follow_structures != null else 0
	if _size != Size.HIDDEN and revision != _copied_revision:
		_planted = (
			_follow_structures.planted() if _follow_structures != null
			else ([] as Array[Vector3])
		)
		_built_copy = (
			_follow_structures.positions() if _follow_structures != null
			else ([] as Array[Vector3])
		)
		_copied_revision = revision
	track(
		_follow_player.global_position,
		_follow_camera.yaw if _follow_camera != null else 0.0,
		_built_copy
	)

## Called with where the player is and which way the camera looks.
func track(world_position: Vector3, yaw: float, built: Array[Vector3]) -> void:
	if _size == Size.HIDDEN:
		return
	_built = built
	_collect_bake()
	_player_at = world_position
	var range_metres := _view.range_m
	var base := centre_for(_size, world_position)
	if not _free:
		_view.centre = Vector2(base.x, base.z)
	var centre := Vector3(_view.centre.x, 0.0, _view.centre.y)
	# Redraw after real movement — a fiftieth of the map's width — or at a new
	# size, and never while a bake is already on its way. The whole-valley map
	# never moves, so once it is drawn it is done.
	var stale := (
		_size != _drawn_size
		or _built.size() != _drawn_built
		or _picture_is_poor(centre, range_metres)
	)
	if stale and _bake_task < 0:
		_start_bake(centre)
	_orient(yaw, world_position, centre, range_metres)
	_arrange_marks(centre, range_metres)
	_place_regions(centre, range_metres)
	_show_picture(centre, range_metres)
	_layout_tools()

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
	_bake_range = _view.range_m * BAKE_MARGIN
	var step := _bake_range / float(CELLS)
	_bake_task = WorkerThreadPool.add_task(_bake.bind(centre, step), false, "minimap")

## The picture, sample by sample. Runs on the pool: reads the height field,
## which is read-only once built, and writes only its own bytes.
func _bake(centre: Vector3, step: float) -> void:
	var range_metres := step * float(CELLS)
	_bake_mutex.lock()
	var need_regions := _regions.is_empty()
	_bake_mutex.unlock()
	var found: Array[Dictionary] = []
	if need_regions:
		found = MapPainter.scan_regions(_field)
	var painted := MapPainter.bake(_field, centre, range_metres, CELLS)
	_bake_mutex.lock()
	_bake_bytes = painted
	_bake_regions = found
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
	var found := _bake_regions
	_bake_regions = []
	_bake_mutex.unlock()
	if not found.is_empty():
		_regions = found
	if bytes.size() != PIXELS * PIXELS * 3:
		return
	_image.set_data(PIXELS, PIXELS, false, Image.FORMAT_RGB8, bytes)
	_mark_buildings(_bake_centre, _bake_range)
	_texture.update(_image)
	_drawn_at = _bake_centre
	_drawn_built = _built.size()
	_drawn_size = _bake_size
	_drawn_range = _bake_range
	_sync_region_labels()

## The flat colour of one spot, the way the map was drawn before MapPainter
## shaded it: kept as the plain answer to "what is here" for the checks.
func _colour_at(x: float, z: float) -> Color:
	var height := _field.height_at(x, z)
	# A pond is blue whatever height its water stands at. This asked whether
	# the ground was below the world's waterline, and the bed of the lake up on
	# the eastern shoulder is eleven metres above it — so the one piece of open
	# water a child walks to came out green, and the map said there was nothing
	# there.
	if _field.is_pond(x, z):
		return WATER
	if height < HeightField.WATER_LEVEL:
		return WATER
	if Pitch.is_in_play(x, z):
		return PITCH
	if height < HeightField.WATER_LEVEL + 1.0:
		return SAND
	# Asked of the world rather than written down again here. The map carried a
	# hard 100 m from before the ground did, and the ground now starts its snow
	# ten metres above a treeline of 118 — so everything between 100 and 128 m
	# was spruce forest underfoot and an ice cap on the map a child was reading
	# to find their way through it.
	if height > HeightField.SNOWLINE - 10.0:
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
func _orient(yaw: float, world_position: Vector3, centre: Vector3, range_metres: float) -> void:
	var middle := Vector2(_view.px, _view.px) * 0.5
	# Where the child actually is on this map. On the maps that follow them
	# that is always the middle; on the whole-valley map it is wherever they
	# have got to, which is the entire point of that map.
	var scale := _view.px / range_metres
	var offset := Vector2(world_position.x - centre.x, world_position.z - centre.z) * scale
	var rim := middle.x - _player_dot.size.x * 0.5 - 2.0
	offset.x = clampf(offset.x, -rim, rim)
	offset.y = clampf(offset.y, -rim, rim)
	_player_dot.position = middle + offset - _player_dot.size * 0.5
	# The map is drawn with world north up, and the camera's yaw is measured the
	# other way round from screen rotation — so the arrow pointed exactly
	# backwards until this was negated.
	_player_dot.rotation = -yaw
	_player_dot.pivot_offset = _player_dot.size * 0.5
	# In the top-right corner, the one corner no place sits in the direction of,
	# so the pointers that pin themselves to the rim keep clear of it.
	_compass.position = Vector2(_view.px - _compass.size.x - 6.0, 6.0)

## One label for every region the bake found, made once.
func _sync_region_labels() -> void:
	var found := _regions
	while _region_labels.size() < found.size():
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.90))
		label.add_theme_constant_override("outline_size", 5)
		label.visible = false
		_canvas.add_child(label)
		_region_labels.append(label)

## Name the regions on the large and whole-valley maps: the lake, the river, the
## fairground, the forest, the mountains. On the small map there is no room and
## the pictures of the places do the work. A name is dropped, rather than
## squeezed in, when it would run off the map or over another name or picture.
func _place_regions(centre: Vector3, range_metres: float) -> void:
	for label in _region_labels:
		label.visible = false
	# Nor under the key, which covers the picture.
	if (_size != Size.LARGE and _size != Size.FULL) or _legend.is_open():
		return
	var half := _view.px * 0.5
	var scale := _view.px / range_metres
	var font := 15 if _size == Size.LARGE else 18
	var wanted: Array[Rect2] = []
	var order: Array[int] = []
	for i in mini(_regions.size(), _region_labels.size()):
		var region := _regions[i]
		var at: Vector3 = region["at"]
		var label := _region_labels[i]
		var kind: StringName = region["kind"]
		var name_text := Text.of(String(MapPainter.REGION_TEXT[kind]))
		label.text = name_text.substr(0, 1).to_upper() + name_text.substr(1)
		label.add_theme_font_size_override("font_size", font)
		label.add_theme_color_override("font_outline_color", MapPainter.label_outline(kind))
		var extent := label.get_minimum_size()
		var spot := Vector2(half, half) + Vector2(at.x - centre.x, at.z - centre.z) * scale
		wanted.append(Rect2(spot - extent * 0.5, extent))
		order.append(i)
	var blockers: Array[Rect2] = [Rect2(_compass.position, _compass.size)]
	if _legend.visible:
		blockers.append(_legend.button_rect())
	for destination in _destinations:
		var glyph: PlaceGlyph = destination["glyph"]
		if glyph.visible:
			blockers.append(Rect2(glyph.position, glyph.size))
	blockers.append(Rect2(_player_dot.position, _player_dot.size))
	var chosen := MapPainter.lay_out(
		wanted, Rect2(Vector2(4.0, 4.0), Vector2(_view.px, _view.px) - Vector2(8.0, 8.0)), blockers
	)
	for k in chosen.size():
		if chosen[k].size == Vector2.ZERO:
			continue
		var label := _region_labels[order[k]]
		label.size = chosen[k].size
		label.position = chosen[k].position
		label.visible = true

## What the map is drawn around.
##
## The small and large maps follow the child, which is what a map in the corner
## is for: what is near me. The whole-valley map does not — it is pinned to the
## valley itself, so it shows all of it however far from the middle a child has
## wandered. It used to follow them at every size, which meant "the whole map"
## was really a 1,100-metre window centred on wherever they happened to be
## standing: walk out towards the mountains and half of it was blank hillside
## while the far side of the valley was off the edge, with no way to shift it
## back. Fixed to the middle, the whole valley is always on it and there is
## nothing left to pan to.
static func centre_for(size: Size, world_position: Vector3) -> Vector3:
	if size == Size.FULL:
		return Vector3.ZERO
	return world_position

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
	var step := range_metres / float(PIXELS)
	var half := range_metres * 0.5
	# Planted first, built over the top: where a child has raised a house in
	# among their own trees, the house is the thing they are looking for.
	var planted_lookup := {}
	for at in _planted:
		planted_lookup[Vector2i(int(at.x), int(at.z))] = true
	for pass_over: int in [0, 1]:
		var marks := _planted if pass_over == 0 else _built
		var ink := PLANTED if pass_over == 0 else BUILT
		for at in marks:
			if pass_over == 1 and planted_lookup.has(Vector2i(int(at.x), int(at.z))):
				continue
			var column := int((at.x - centre.x + half) / step)
			var row := int((at.z - centre.z + half) / step)
			if column < 4 or row < 4 or column >= PIXELS - 4 or row >= PIXELS - 4:
				continue
			# A dark outline round the bright square, so the mark parts from the
			# meadow by brightness as well as by hue.
			for dx in range(-3, 4):
				for dz in range(-3, 4):
					if absi(dx) == 3 and absi(dz) == 3:
						continue
					var inside := absi(dx) <= 2 and absi(dz) <= 2
					if inside:
						_image.set_pixel(column + dx, row + dz, ink)
					elif pass_over == 1 or _image.get_pixel(column + dx, row + dz) != BUILT:
						_image.set_pixel(column + dx, row + dz, MapPainter.INK)

## --- Looking around: zoom, pan and "back to me". -------------------------------

## Built once, from _init: the picture that can be shifted and scaled under the
## glyphs, the three buttons, and the wiring of the gesture reader.
##
## The baked picture is a child rather than the canvas's own texture because it has
## to be able to sit somewhere other than exactly over the view: while the finger
## is zooming, the last bake is stretched to follow it, and the sharp one replaces
## it when it lands. Without that the map would hold still and then jump.
func _setup_view() -> void:
	_canvas.clip_contents = true
	_picture = TextureRect.new()
	_picture.texture = _texture
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.texture = null
	_canvas.add_child(_picture)
	_canvas.move_child(_picture, 0)

	# The picture keeps its own size inside the panel; the buttons live in a layer
	# of their own over the whole panel, in the picture's coordinates, so that on
	# the big maps they can stand in a strip beside the picture and cover nothing.
	_canvas.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_canvas.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_tools = Control.new()
	_tools.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tools)
	_zoom_in_button = MapTool.new(MapTool.Kind.PLUS)
	_zoom_out_button = MapTool.new(MapTool.Kind.MINUS)
	_me_button = MapTool.new(MapTool.Kind.ME)
	_close_button = MapTool.new(MapTool.Kind.CLOSE)
	for tool: MapTool in [_zoom_in_button, _zoom_out_button, _me_button, _close_button]:
		_tools.add_child(tool)
	_zoom_in_button.pressed.connect(zoom_button.bind(1))
	_zoom_out_button.pressed.connect(zoom_button.bind(-1))
	_me_button.pressed.connect(recentre)
	_close_button.pressed.connect(close_requested.emit)

	_gesture.moved.connect(_on_gesture_moved)
	_gesture.tapped.connect(_on_gesture_tapped)

## Back to the size's own view: following the child at the usual range.
func _reset_view(pixels: float) -> void:
	_view.px = pixels
	_view.range_m = range_of(_size)
	_free = false
	_zoom_goal = 0.0
	_gesture.cancel()
	if _size != Size.HIDDEN:
		var base := centre_for(_size, _player_at)
		_view.centre = Vector2(base.x, base.z)
	_layout_tools()

func _on_gesture_moved(from: Vector2, to: Vector2, factor: float) -> void:
	_zoom_goal = 0.0
	var before := _view.centre
	_view.grab(from, to, factor)
	if not _view.centre.is_equal_approx(before):
		_free = true
	_layout_tools()

## One press of a plus or minus: ease the range by MapView.STEP, about the middle.
## Repeated presses compound from where the last one is heading.
func zoom_button(direction: int) -> void:
	var goal := _zoom_goal if _zoom_goal > 0.0 else _view.range_m
	_zoom_goal = MapView.clamp_range(goal * pow(MapView.STEP, -float(direction)))

## Ease towards a button's zoom goal. Called every frame from _process; a check
## calls it with a long step to finish at once.
func advance(delta: float) -> void:
	if _zoom_goal <= 0.0:
		return
	var middle := Vector2(_view.px, _view.px) * 0.5
	var ease_to := 1.0 - exp(-14.0 * delta)
	var next := _view.range_m * pow(_zoom_goal / _view.range_m, ease_to)
	if absf(next - _zoom_goal) < _zoom_goal * 0.003:
		next = _zoom_goal
		_zoom_goal = 0.0
	_view.zoom_at(middle, _view.range_m / next)

## "Back to me": the middle of the view is the child again, at the range it has.
## On the maps that follow the child that is just letting go; the whole-valley map
## is pinned to the valley, so there it moves to the child instead.
func recentre() -> void:
	if _size == Size.FULL:
		_free = true
		_view.centre = Vector2(
			clampf(_player_at.x, -MapView.LIMIT, MapView.LIMIT),
			clampf(_player_at.z, -MapView.LIMIT, MapView.LIMIT)
		)
	else:
		_free = false
	_layout_tools()

## Look at this much of the world, centred here, and stay there until "back to
## me". For the screenshot tool and the checks.
func set_view(range_metres: float, centre: Vector2) -> void:
	_zoom_goal = 0.0
	_view.range_m = MapView.clamp_range(range_metres)
	_view.centre = centre
	_free = true
	_layout_tools()

## Zoom to this many metres across at once, about the middle, still following.
func zoom_to(range_metres: float) -> void:
	_zoom_goal = 0.0
	_view.range_m = MapView.clamp_range(range_metres)

## The metres across, and the world point in the middle, of what is on screen.
func view_range() -> float:
	return _view.range_m

func view_centre() -> Vector2:
	return _view.centre

## Whether the picture on screen no longer serves the view: zoomed in far enough
## that it is coarse, zoomed out or dragged until it no longer covers it. A fresh
## bake is made around the view with a margin, so the next one is not needed soon.
func _picture_is_poor(centre: Vector3, range_metres: float) -> bool:
	if _drawn_range <= 0.0:
		return false
	var ratio := range_metres / _drawn_range
	if ratio < 0.45 or ratio > 0.85:
		return true
	var off := maxf(absf(centre.x - _drawn_at.x), absf(centre.z - _drawn_at.z))
	return off > (_drawn_range - range_metres) * 0.5 * 0.7

## Put the baked picture where its world area is in the current view.
func _show_picture(centre: Vector3, range_metres: float) -> void:
	var span := _drawn_range if _drawn_range > 0.0 else range_metres
	var side := _view.px * span / range_metres
	var shift := Vector2.ZERO
	if _drawn_range > 0.0:
		shift = Vector2(_drawn_at.x - centre.x, _drawn_at.z - centre.z) / range_metres * _view.px
	_picture.size = Vector2(side, side)
	_picture.position = Vector2(_view.px, _view.px) * 0.5 + shift - _picture.size * 0.5

func strip_width_for(pixels: float) -> float:
	if not _roomy():
		return 0.0
	return TOOL_GAP + clampf((pixels - 3.0 * TOOL_GAP) / 4.0, TOOL_SMALL, TOOL_BIG)

## How big the round buttons are: a thumb's width on the big maps (the HUD's own
## buttons are 96 base pixels), and a little less on the small one, which only
## ever shows "back to me" and has no room for more.
func tool_side() -> float:
	if not _roomy():
		return TOOL_SMALL
	# Four buttons stand in a column beside the picture; they shrink only when the
	# screen leaves the picture too short for four thumbs.
	return clampf((_view.px - 3.0 * TOOL_GAP) / 4.0, TOOL_SMALL, TOOL_BIG)

func _roomy() -> bool:
	return _size == Size.LARGE or _size == Size.FULL

## The buttons stand in a column in a strip to the right of the picture on the big
## maps, so they sit on no sticker and no label: close at the top, then back to me
## last, with the zoom pair between. The small map is too small for any of that,
## and offers "back to me" once it has been moved off the child, in its corner.
func _layout_tools() -> void:
	var roomy := _roomy()
	var side := tool_side()
	for tool: MapTool in [_zoom_in_button, _zoom_out_button, _me_button, _close_button]:
		tool.set_side(side)
	_zoom_in_button.visible = roomy
	_zoom_out_button.visible = roomy
	_me_button.visible = roomy or _free
	_close_button.visible = roomy
	if roomy:
		var x := _view.px + TOOL_GAP
		var step := side + TOOL_GAP
		_close_button.position = Vector2(x, 0.0)
		_zoom_in_button.position = Vector2(x, step)
		_zoom_out_button.position = Vector2(x, step * 2.0)
		_me_button.position = Vector2(x, step * 3.0)
	else:
		_me_button.position = Vector2(_view.px - side - 6.0, _view.px - side - 6.0)

## The most picture pixels the screen has room for, from whoever lays the map out.
## The whole-valley map is taller than a phone held sideways has to spare, and
## its south edge ran off the bottom.
func fit_to(pixels: float) -> void:
	var wanted := maxf(pixels, SMALL_PIXELS)
	if is_equal_approx(wanted, _fit_pixels):
		return
	_fit_pixels = wanted
	if _size != Size.HIDDEN:
		var free := _free
		var centre := _view.centre
		var range_metres := _view.range_m
		_apply_size()
		if free:
			_view.range_m = range_metres
			_view.centre = centre
			_free = true

# --- Symbols, the way to a chosen place, and the key -------------------------
#
# Everything below is the map's guidance: what a tap on a sticker does, where
# the stickers go so that none hides another, and the guide that outlives the
# map being open. It lives apart from the picture and from the gestures, and
# asks nothing of them but a point in the map's own coordinates (the canvas's:
# 0,0 is the top-left of the picture).

## How wide a sticker is at each size of map. The corner map has no room to
## spare; the big ones are for finding things with a finger.
static func glyph_diameter(for_size: Size) -> float:
	match for_size:
		Size.SMALL:
			return 30.0
		Size.LARGE:
			return 46.0
		_:
			return 56.0

## How far from a sticker's middle a tap still counts as on it. On the big maps
## that is a finger's width (about 90 pixels across) — the nearest sticker
## wins; on the small one there is no room for that and a tap on bare map must
## still be able to open it up.
static func hit_radius(for_size: Size) -> float:
	match for_size:
		Size.SMALL:
			return glyph_diameter(for_size) * 0.5 + 4.0
		Size.LARGE:
			return 40.0
		_:
			return 45.0

func _size_the_guidance(pixels: float) -> void:
	_arranged = false
	var diameter := glyph_diameter(_size)
	for destination in _destinations:
		(destination["glyph"] as PlaceGlyph).set_diameter(diameter)
	_route.size = Vector2(pixels, pixels)
	var key_wanted := _size == Size.LARGE or _size == Size.FULL
	_legend.visible = key_wanted
	_legend.fit(Vector2(pixels, pixels))
	if not key_wanted:
		_legend.set_open(false)

## The kind of place the current task is done at (PlaceGlyph.Kind), or -1. Its
## sticker swells and shrinks gently on the map, so the "what to do next" line
## has a place to look at. Only a hint: nothing is chosen on the child's behalf.
var _suggested := -1

func suggest(kind: int) -> void:
	_suggested = kind

func suggested() -> int:
	return _suggested

## How much bigger a suggested sticker is drawn at this moment, 1 to 1.18.
static func pulse_scale(seconds: float) -> float:
	return 1.09 + 0.09 * sin(seconds * 4.0)

func _pulse_suggested() -> void:
	var seconds := float(Time.get_ticks_msec()) / 1000.0
	for destination in _destinations:
		var glyph: PlaceGlyph = destination["glyph"]
		var wanted := _suggested >= 0 and int(glyph.kind) == _suggested
		glyph.pivot_offset = glyph.size * 0.5
		glyph.scale = Vector2.ONE * (pulse_scale(seconds) if wanted else 1.0)

## The guide, for whoever draws the pointer on the play screen.
func guide() -> MapGuide:
	return _guide

## Which place the guide is leading to, as an index into the destinations, or -1.
func chosen_index() -> int:
	return _guide.index if _guide.active else -1

## Bring the moving marks up to date, and the guide with them. Called every
## frame by the map and directly by the checks.
func guide_step(player: Vector3, yaw: float) -> void:
	_refresh_live(player)
	if _guide.active:
		var mark := _destinations[_guide.index]
		if _is_present(mark):
			_guide.retarget(mark["at"])
		else:
			# The friend left, or the horse is gone.
			_guide.clear()
	_guide.update(player, yaw)

## A friend, or the nearest horse, shown where they are now or not at all.
func _refresh_live(player: Vector3) -> void:
	var friends: Array = friend_source.call() if friend_source.is_valid() else []
	var friend_number := 0
	for destination in _destinations:
		if not destination["live"]:
			continue
		var glyph: PlaceGlyph = destination["glyph"]
		var found := Vector3.INF
		if glyph.kind == PlaceGlyph.Kind.HORSE:
			if horse_source.is_valid():
				found = horse_source.call(player)
		elif friend_number < friends.size():
			found = friends[friend_number]
			friend_number += 1
		destination["at"] = found
		if not found.is_finite() and glyph.visible:
			glyph.visible = false

## Whether a destination is anywhere: a friend who has left, or a horse that is
## gone, has nowhere to be drawn. Whether its sticker is on screen is another
## matter (see _marks_to_show).
func _is_present(destination: Dictionary) -> bool:
	return (destination["at"] as Vector3).is_finite()

## How many places besides home and the chosen one the small map shows. It is 190
## pixels across: a dozen stickers there hide the ground and each other, and the
## larger maps are for everything.
const SMALL_EXTRA := 3

## Which destinations get a sticker on this map, one flag each. Everything that is
## anywhere on the large and whole-valley maps; on the small one the chosen place,
## home, and the nearest few to the middle of the view.
func _marks_to_show(centre: Vector3) -> Array[bool]:
	var shown: Array[bool] = []
	for destination in _destinations:
		shown.append(_is_present(destination))
	if _size != Size.SMALL:
		return shown
	var order: Array[int] = []
	for i in _destinations.size():
		if not shown[i]:
			continue
		var glyph: PlaceGlyph = _destinations[i]["glyph"]
		if glyph.kind != PlaceGlyph.Kind.HOME and i != chosen_index():
			order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		return _flat_distance(a, centre) < _flat_distance(b, centre)
	)
	for rank in order.size():
		if rank >= SMALL_EXTRA:
			shown[order[rank]] = false
	return shown

func _flat_distance(index: int, from: Vector3) -> float:
	var at: Vector3 = _destinations[index]["at"]
	return Vector2(at.x - from.x, at.z - from.z).length_squared()

## Put each sticker where its place is — or, when that is off the map, on the
## rim pointing at it — then move stickers apart so that none hides another,
## the child's own arrow or the key's button, and say with a thin stem where
## each moved one really is. It works from the places themselves, through the
## view's transform (so it follows every pan and zoom), and is the same every
## frame.
func _arrange_marks(centre: Vector3, range_metres: float) -> void:
	var diameter := glyph_diameter(_size)
	var canvas := Vector2(_view.px, _view.px)
	var middle := canvas * 0.5
	var to_show := _marks_to_show(Vector3(centre.x, 0.0, centre.z))
	var scale := canvas.x / range_metres
	# Stickers keep this far from the edge, and the ones pinned to it keep room
	# for their chevron as well.
	var inset := diameter * 0.82 + 3.0
	var inner := Rect2(Vector2(inset, inset), canvas - Vector2(inset, inset) * 2.0)
	var glyphs: Array[PlaceGlyph] = []
	var truths := PackedVector2Array()
	var wanted := PackedVector2Array()
	var radii := PackedFloat32Array()
	for d in _destinations.size():
		var destination := _destinations[d]
		var glyph: PlaceGlyph = destination["glyph"]
		if glyph.visible != to_show[d]:
			glyph.visible = to_show[d]
		if not to_show[d]:
			continue
		var at: Vector3 = destination["at"]
		var offset := Vector2(at.x - centre.x, at.z - centre.z) * scale
		var reach := maxf(absf(offset.x), absf(offset.y))
		var pinned := reach > inner.size.x * 0.5
		glyphs.append(glyph)
		truths.append(middle + offset)
		wanted.append(middle + (offset * (inner.size.x * 0.5 / reach) if pinned else offset))
		radii.append(diameter * 0.47)
	var you := _player_dot.position + _player_dot.size * 0.5
	var obstacles := PackedVector2Array([you])
	var obstacle_radii := PackedFloat32Array([MapArrow.SIZE * 0.5 + 8.0])
	obstacles.append(_compass.position + _compass.size * 0.5)
	obstacle_radii.append(MapCompass.SIZE * 0.5 + 6.0)
	if _me_button.visible and _me_button.get_parent() == _canvas:
		obstacles.append(_me_button.position + _me_button.size * 0.5)
		obstacle_radii.append(_me_button.size.x * 0.5 + 4.0)
	if _legend.visible and not _legend.is_open():
		obstacles.append(_legend.button_rect().get_center())
		obstacle_radii.append(MapLegend.BUTTON * 0.5 + 4.0)
	# The ones pinned to the rim slide along it, and then the rest are kept off
	# those and off each other.
	var rim_marks := PackedVector2Array()
	var rim_at: Array[int] = []
	for i in glyphs.size():
		if not inner.has_point(truths[i]):
			rim_marks.append(wanted[i])
			rim_at.append(i)
	var moved := wanted.duplicate()
	# Further apart than the stickers are wide: two on either side of a corner are
	# nearer each other than the distance along the rim between them.
	var spread := MapGuide.spread_on_rim(rim_marks, inner, diameter * 1.28)
	for k in rim_at.size():
		moved[rim_at[k]] = spread[k]
		obstacles.append(spread[k])
		obstacle_radii.append(diameter * 0.47)
	var free_marks := PackedVector2Array()
	var free_radii := PackedFloat32Array()
	var free_at: Array[int] = []
	for i in glyphs.size():
		if inner.has_point(truths[i]):
			free_marks.append(wanted[i])
			free_radii.append(radii[i])
			free_at.append(i)
	var settled := MapGuide.declutter(free_marks, free_radii, obstacles, obstacle_radii, inner)
	for k in free_at.size():
		moved[free_at[k]] = settled[k]
	var stems := PackedVector2Array()
	for i in glyphs.size():
		var glyph := glyphs[i]
		glyph.position = moved[i] - glyph.size * 0.5
		if not inner.has_point(truths[i]):
			glyph.point(true, (truths[i] - moved[i]).angle())
		else:
			glyph.point(false, 0.0)
			if truths[i].distance_to(moved[i]) > 4.0:
				stems.append(truths[i])
				stems.append(moved[i])
	var goal := Vector2.ZERO
	var goal_shown := false
	if _guide.active and _guide.index >= 0 and _guide.index < _destinations.size():
		var chosen: PlaceGlyph = _destinations[_guide.index]["glyph"]
		goal = chosen.position + chosen.size * 0.5
		goal_shown = chosen.visible and _is_present(_destinations[_guide.index])
	_route.set_state(you, goal, diameter * 0.5, goal_shown, stems)
	_arranged = true

## Which sticker a point on the map is on, if any, as an index into the
## destinations: the nearest whose middle is within the hit radius, or -1. Takes
## a point in the map's own coordinates, so it does not care how the map came
## to be touched.
func glyph_index_at(local: Vector2) -> int:
	var best := -1
	if not _arranged:
		return best
	var best_distance := hit_radius(_size)
	for i in _destinations.size():
		var glyph: PlaceGlyph = _destinations[i]["glyph"]
		if not glyph.visible:
			continue
		var distance := (glyph.position + glyph.size * 0.5).distance_to(local)
		if distance <= best_distance:
			best_distance = distance
			best = i
	return best

## A tap on the map at this point. Opens or closes the key, or chooses (or
## puts away) the place under the finger. True if it was for any of those, so
## that the map does not also cycle its size.
func handle_symbol_tap(local: Vector2) -> bool:
	var now := Time.get_ticks_msec()
	if now - _last_symbol_tap < 120:
		# The second half of one tap: swallowed, whatever the first one did.
		return true
	if _legend.visible:
		if _legend.is_open():
			_legend.set_open(false)
			_last_symbol_tap = now
			return true
		if _legend.button_rect().grow(10.0).has_point(local):
			_legend.set_open(true)
			_last_symbol_tap = now
			return true
	var index := glyph_index_at(local)
	if index < 0:
		return false
	_last_symbol_tap = now
	choose_index(index)
	return true

## Choose (or, if it is the one already chosen, put away) a place by index.
## The great mountain cannot be walked to: tapping it names it and nothing more.
func choose_index(index: int) -> bool:
	if index < 0 or index >= _destinations.size():
		return false
	var mark := _destinations[index]
	var glyph: PlaceGlyph = mark["glyph"]
	if not _is_present(mark) or not glyph.is_destination():
		place_tapped.emit(glyph.kind, false)
		return false
	_guide.toggle(index, glyph.kind, mark["at"])
	place_tapped.emit(glyph.kind, _guide.active)
	if _guide.active and _follow_player != null and is_instance_valid(_follow_player):
		guide_step(
			_follow_player.global_position,
			_follow_camera.yaw if _follow_camera != null else 0.0
		)
	return true

## Choose the first place of a kind. For the checks and the screenshot tool.
func choose_kind(kind: PlaceGlyph.Kind) -> bool:
	for i in _destinations.size():
		if (_destinations[i]["glyph"] as PlaceGlyph).kind == kind:
			if _guide.active and _guide.index == i:
				return true
			return choose_index(i)
	return false

## The same, by the lower-case name of the kind ("playground"), for the tool.
func choose_named(named: String) -> void:
	var kind: int = PlaceGlyph.Kind.keys().find(named.to_upper())
	if kind >= 0:
		choose_kind(kind as PlaceGlyph.Kind)

## Open at a size by name ("small", "large", "full").
func open_at(which: String) -> void:
	match which:
		"large":
			_size = Size.LARGE
		"full":
			_size = Size.FULL
		_:
			_size = Size.SMALL
	_apply_size()

func set_legend_open(open: bool) -> void:
	_legend.set_open(open and _legend.visible)

func legend() -> MapLegend:
	return _legend

## The sticker of a destination, for the checks.
func glyph_at_index(index: int) -> PlaceGlyph:
	return _destinations[index]["glyph"]
