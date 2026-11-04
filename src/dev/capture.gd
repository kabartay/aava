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
##   --demo=1       stock the inventory and stand a finished camp in front of
##                  the player, so a screenshot shows the whole game rather
##                  than an empty valley
##   --build=1      open build mode with the ghost preview showing
##   --atcafe=1     read --pos and --look as metres from the café's site
##   --atshop=1     the same for the shop's site (z negative is out in front)
##   --atpitch=1    stand the player on the football pitch instead of the spawn
##   --lang=en|fr|ru  which language to draw the interface in
##   --map=SIZE[,METRES[,DX,DZ]]  open the map at that size (small|large|full,
##                  or 1|2|3), looking METRES across at DX,DZ metres from the
##                  middle of the valley
##   --guide=KIND   with --map: choose that place (playground, pitch...) as the
##                  destination; --legend=1 opens the key; --mapat=X,Z stands
##                  the child there first; --friend=X,Z puts a friend there
##   --zoom=METRES  pull the camera this far further out than its default
##   --together=choice|host|type  open the play-together panel on a page
##   --shop=1  open the shop panel, with coins to spend
##   --dam=1  finish the first dam before the shot, to show the pond
##   --mounts=1  put a horse and a bicycle in front of the camera
##   --ride=KIND    seat a child on that mount (horse, bicycle...), placed
##                  at --look, with --rider=N for the character (0 simple, -1 none)
##   --ride=carousel  seat the child on the park's carousel instead, on the
##                  figure --figure=N (0..7: horse, pig, horse, swan, horse,
##                  rooster, horse, swan), and print where its saddle is
##   --character=C,SKIN,HAIR  with --player=1, dress the player as that
##                  character (0 plain, 1 boy, 2 girl, 3 cap, 4 bear)
##   --chop=N  fell the N nearest trees before the shot, to show a clearing
##   --energy=N  draw the energy bar at this fraction (0..1)
##   --water=N  draw the bottle at this fraction, and carry one
##   --animals=1  place one of every animal in front of the camera
##   --animalyaw=DEG  turn the animals this far from facing the camera
##                    (90 shows them side on)
##   --only=KIND  with --animals=1, place just that kind, straight ahead
##   --animalat=METRES  how far ahead of the camera they stand (default 9)
##   --kick=SECONDS kick the nearest ball, then watch it fly for this long
##   --aim=1        show the aim preview (the dots, green when on target) as
##                  the game draws it while the kick button is held
##   --score=B,R    set the football score (blue, red) before the shot
##   --side=0|1     the chip says which side this child plays (0 blue, 1 red)
##   --winner=0|1   that side has won the match: board title, confetti, announcement
##   --flash=0|1    that side's number is flashing on the board, as after a goal
##   --power=0..1   how hard to kick it
##   --loft=0..1    how high: 0 along the ground, 1 chipped over the top
##   --turn=DEG     how far the finger slid the shot sideways, right positive
##   --nowater=1    leave the water sheet out, to see the ground under it
##   --unshaded=1   draw the terrain as flat vertex colour, no lighting at all,
##                  which separates "the colours are wrong" from "the light is"
##   --testhouse=1  build the checks' house — two squares by two, door, window,
##                  floors, whole roof, bed — through the build mode, on the
##                  nearest buildable ground to the --look point (or to the
##                  player), and print where it went
##   --plan=room|house|cafe|shop  put up that ready-made plan with one tap, on
##                  the nearest buildable ground to the --look point
##   --material=plaster|stone|blue|red  what new walls are made of
##   --storeys=2    with --plan=house, stack a second storey and move the roof up
##   --meal=juice|icecream|pancake|soup|pizza|cake  set that dish on the café table
##                  nearest the --look point, and --mealframes=N frames on
##   --sit=1        with --player=1 and --meal, sit the player in the seat that
##                  meal was served at, posed as at a table in the game
##   --group=plans|walls|floor|roof|furniture|things  with --build=1, open the
##                  palette on that group

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
var _demo := false
var _build := false
var _at_pitch := false
var _at_cafe := false
var _at_shop := false
var _kick_after := 0.0
var _kick_strength := 1.0
var _kick_loft := 0.25
var _kick_turn := 0.0
var _aim_preview := false
var _score := Vector2i(-1, -1)
var _side := -1
var _winner := -1
var _flash := -1
var _zoom := 0.0
var _shop := false
var _together := ""
## --map=SIZE[,METRES[,DX,DZ]] opens the map (see the header); --guide=KIND picks
## that place as the destination; --legend=1 opens the legend; --mapat=X,Z stands
## the child there first.
var _map := ""
var _friend := Vector2.INF
var _guide := ""
var _legend := false
var _map_at := Vector2.INF
var _energy := 1.0
var _chop := 0
var _mounts := false
var _ride: StringName = &""
var _rider := 0
var _figure := 0
## --character=C,SKIN,HAIR: dress the player as this character.
var _look: Array = []
var _dam := false
var _lantern: Lantern = null
var _water := -1.0
var _animals := false
var _animal_yaw := 0.0
var _only_kind := ""
var _animal_at := 9.0
var _coins := 40
var _menu := false
## Open the grown-ups' settings panel (the gear's), for a picture of it.
var _settings := false
var _meal: StringName = &""
var _meal_frames := 60
var _sit := false
var _house := false
var _test_house := false
var _palette_group := ""
var _wall_material := ""
var _two_storeys := false
var _plan := ""
var _language := "en"
var _structures: Structures
var _birds: Birds
var _inventory: Inventory
var _build_mode: BuildMode
var _hud: Hud

var _world: World
var _camera: Camera3D

func _ready() -> void:
	_parse_arguments()
	Text.set_language(StringName(_language))

	_world = World.new(_seed)
	add_child(_world)
	if _at_cafe:
		# --pos and --look are metres from the middle of the café's site, x
		# along its front and z towards its back wall (the building is
		# centred a little behind the origin: the bar is about z 5).
		var cafe_site := PlaceSpec.centre_of(&"cafe", _world.field.camp_centre())
		cafe_site.y = _world.field.height_at(cafe_site.x, cafe_site.z)
		_camera_position += cafe_site
		_look_at += cafe_site
	if _at_shop:
		# The same, for the shop: x along its front, z towards its back wall,
		# so the porch and the stands are at negative z.
		var shop_site := PlaceSpec.centre_of(&"shop", _world.field.camp_centre())
		shop_site.y = _world.field.height_at(shop_site.x, shop_site.z)
		_camera_position += shop_site
		_look_at += shop_site
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
	if _lantern != null:
		# A large delta so the fade completes rather than being caught halfway.
		_lantern.follow(_world.atmosphere.darkness(), 10.0)
	# The playground's lamps likewise, or a night shot of it shows them dark.
	_world.places.light_lamps(_world.atmosphere.evening(), 10.0)
	# Terrain streams a couple of chunks per frame, so a capture taken on frame
	# one would photograph an empty world. Waiting is not optional here.
	_world.follow(_camera_position)

	await _wait_for_world()

	if _test_house:
		_raise_the_test_house()
	if not _wall_material.is_empty() and _build_mode != null:
		_build_mode.set_material(StringName(_wall_material))
	if not _palette_group.is_empty() and _hud != null:
		_hud._show_group(StringName(_palette_group))
	if _map != "" and _hud != null and _hud.minimap() != null:
		await _settle_the_map()
	if _test_house or not _palette_group.is_empty():
		# A few frames for the new pieces to be drawn, and the ghost aimed
		# again at what is now chosen.
		for _i in 4:
			if _build and _player != null:
				_build_mode.aim(_player.global_position, _rig.yaw)
				_hud.set_storey(
					_build_mode.storey(),
					_build_mode.active and HouseParts.is_house_part(_build_mode.selected)
				)
			await RenderingServer.frame_post_draw

	# After streaming, not before: felling searches the forest and queues tile
	# rebuilds, and doing that against a half-built world hangs the process.
	if _animals:
		_gather_animals()
	if _chop > 0:
		_fell_nearby()
	if _mounts:
		_show_mounts()
	if _ride != &"":
		_seat_a_rider()
	if _dam:
		for _i in DamSpec.STICKS_NEEDED:
			_world.dams.deliver(DamSpec.SITES[0])
		print("dam built at z=%.0f; %d dams standing" % [DamSpec.SITES[0], _world.dams.built.size()])
		# The rebuilt chunks stream in a few per frame, and that has to finish
		# before the shutter opens.
		for _f in 90:
			await RenderingServer.frame_post_draw
			if _world.terrain.is_idle() and _world.vegetation.is_idle():
				break
	if _chop > 0 or _mounts or _animals or _ride != &"":
		# Let the queued rebuilds actually run before the shutter opens.
		for _i in 12:
			await get_tree().process_frame

	# Staged last, just before the shutter: a won match starts a new game by
	# itself after a few seconds, and the warm-up is longer than that.
	if _hud != null and _winner >= 0:
		_world.football._win(_winner)
		_hud.announce(
			Text.of("say_won_blue" if _winner == 0 else "say_won_red"), 60.0,
			Goal.SIDE_COLOURS[_winner].lightened(0.2)
		)
	elif _flash >= 0:
		_world.football._board.celebrate(_flash, 600.0)
	if _winner >= 0 or _flash >= 0:
		for _i in 25:
			await get_tree().process_frame
	if _meal != &"":
		# A dish on the table nearest the look-at point, a moment after it was
		# set down, so that a shot shows the food and a bite of it gone.
		var seated := _world.places.serve_meal(_look_at, _meal)
		if _sit and _player != null and not seated.is_empty():
			# Where the game keeps a diner (Main._carry), posed as Main._process does.
			var seat: Vector3 = seated["seat"]
			_player.global_position = seat - Vector3(0.0, Places.DINING_SINK, 0.0)
			_player.rotation.y = float(seated["facing"])
			var found := _world.places.cafe_seat_near(_player.global_position)
			_player.seat_pose = found.get("pose", &"")
			_player.seat_place = found.get("place", Transform3D())
		for _i in _meal_frames:
			if _sit and _player != null:
				_player.meal_age = _world.places.cafe_seat_near(_player.global_position).get("meal_age", -1.0)
			await get_tree().process_frame
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
	if _at_pitch:
		# Right beside the middle ball, facing the goal at negative x, so the
		# picture shows what a child sees when he walks up to kick it.
		spawn = Pitch.centre() + Vector3(1.1, 0.0, 0.0)
		spawn.y = _world.field.height_at(spawn.x, spawn.z)
	_player = Player.new()
	_player.position = spawn + Vector3.UP * 1.2
	_player.set_physics_process(false)
	add_child(_player)
	if not _look.is_empty():
		_player.set_look(_look)

	_rig = CameraRig.new(_player)
	_rig.yaw = deg_to_rad(_yaw)
	_rig.pitch = deg_to_rad(_pitch)
	if not is_zero_approx(_zoom):
		_rig.zoom(-_zoom)

	# The lantern too, or a night screenshot photographs a game without one.
	# Lit later, after set_time — reading the darkness here gave daylight,
	# because the player is built before the hour is chosen.
	_lantern = Lantern.new()
	_lantern.owned = not _shop
	_player.add_child(_lantern)

	_player.add_child(_rig)
	_camera = _rig.camera
	_camera.current = true

	_inventory = Inventory.new()
	_structures = Structures.new(_world.field)
	add_child(_structures)
	_birds = Birds.new()
	add_child(_birds)
	_build_mode = BuildMode.new(_world.field, _structures, _inventory)
	add_child(_build_mode)

	_hud = Hud.new()
	add_child(_hud)
	# The score chip, as the game shows it on or beside the pitch.
	if _score.x >= 0:
		_world.football.from_data({"blue": _score.x, "red": _score.y})
	_hud.set_score(_world.football.blue, _world.football.red)
	_hud.set_at_the_pitch(_at_pitch)
	_hud.set_side(_side)
	# The same wiring the game uses, from the same place, so this tool cannot
	# photograph a game that is connected differently from the real one.
	Wiring.connect_hud(
		_hud, _build_mode, _rig, _inventory, _world.field, _player, _structures,
		{
			&"place": func() -> void: _build_mode.place(),
			&"kick_start": func() -> void: _player.start_charging(),
			&"kick_release": func() -> void: _kick_nearest(),
			&"jump": func() -> void: _player.request_jump(),
			&"dive": func() -> void: _player.diving = not _player.diving,
			&"remove": func() -> void:
				var record := _structures.nearest(_player.global_position, 4.0)
				if not record.is_empty():
					_structures.remove(record),
			&"undo": func() -> void:
				var record := _build_mode.take_last()
				if not record.is_empty():
					_structures.remove(record),
			&"language": func(code: StringName) -> void: Text.set_language(code),
			&"reset": func() -> void: pass,
			&"care": func() -> void: pass,
			&"shop": func() -> void: pass,
			&"buy": func(_item: StringName) -> void: pass,
			&"drink": func() -> void: pass,
			&"whistle": func() -> void: pass,
			&"chop": func() -> void: pass,
			&"ride": func() -> void: pass,
			&"shoot_start": func() -> void: pass,
			&"shoot_release": func() -> void: pass,
			&"visit": func() -> void: pass,
			&"dam": func() -> void: pass,
			# The snack, lantern and ticket buttons arrived after this table
			# was written, and the screenshot tool reported them as unwired.
			&"ticket": func() -> void: pass,
			&"snack": func() -> void: pass,
			&"lantern": func() -> void: pass,
		}
	)

	_open_the_map()
	if _demo:
		_stand_up_a_camp(spawn)
	if _build:
		# Through the HUD, so the palette and the place button open exactly as
		# they do for a player pressing the button.
		_hud.set_building(true)
		if _house:
			_hud._show_house(true)
			_build_mode.select(HouseParts.WALL_DOOR)
			_stand_up_a_house(_world.field.find_spawn_point() if not _at_pitch else Pitch.centre() + Vector3(0.0, 0.0, 26.0))
		else:
			_build_mode.select(BuildKinds.FEEDER)

	_world.follow(spawn)

## A camp as a child would leave it: a fire, a fence, a path, a feeder, and a
## grove of three grown trees with birds over it. Built here rather than
## screenshotted from a save so that the picture always matches the code.

	# After the interface exists, or these paint onto nothing.
	_hud.set_coins(_coins)
	_hud.set_vitals(_energy, maxf(_water, 0.0), _water >= 0.0)
	if _shop:
		_hud.set_owned({})
	else:
		# Everything owned, so the controls that only appear once bought can be
		# photographed.
		var owned := {}
		for item in ShopStock.ALL:
			owned[item] = true
		_hud.set_owned(owned)
	if _shop:
		_hud.set_shop_open(true, _coins, {})
	if _settings:
		_hud._toggle_menu()
	if _menu:
		_hud.set_place_offer(Places.CAFE)
		_hud.set_cafe_menu_open(true, false, _coins)
	match _together:
		"choice":
			_hud.together.open()
		"host":
			_hud.together.show_hosting()
		"type":
			_hud.together.open()
			_hud.together._start_typing()

## Open the map at the size asked for, with a destination chosen and the legend
## up if wanted, the way a child's taps would leave it.
func _open_the_map() -> void:
	if _map == "":
		return
	var parts := _map.split(",")
	if _map_at != Vector2.INF:
		_player.position = Vector3(_map_at.x, _world.field.height_at(_map_at.x, _map_at.y) + 1.2, _map_at.y)
	var map := _hud.minimap()
	map.horse_source = func(from: Vector3) -> Vector3:
		return _world.mounts.nearest_standing(MountKinds.HORSE, from)
	if _friend != Vector2.INF:
		var friend_at := Vector3(_friend.x, 0.0, _friend.y)
		map.friend_source = func() -> Array: return [friend_at]
	# The size by name or by number: 1 small, 2 large, 3 the whole valley.
	var named: String = {"1": "small", "2": "large", "3": "full"}.get(parts[0], parts[0])
	map.open_at(named)
	_hud._layout()
	if parts.size() >= 4:
		map.set_view(parts[1].to_float(), Vector2(parts[2].to_float(), parts[3].to_float()))
	elif parts.size() >= 2:
		map.zoom_to(parts[1].to_float())
	if _guide != "":
		map.choose_named(_guide)
	map.set_legend_open(_legend)

## Let the map draw: a few frames for the layout, then a bake waited for and
## collected, then frames for the new picture to reach the screen.
func _settle_the_map() -> void:
	var map := _hud.minimap()
	map._follow_player = _player
	for _i in 3:
		await get_tree().process_frame
	var stand := _player.global_position if _player != null else Vector3.ZERO
	for _round in 4:
		map.track(stand, 0.0, [] as Array[Vector3])
		map.wait_for_bake()
		map.track(stand, 0.0, [] as Array[Vector3])
		if map.is_drawn():
			break
	for _i in 3:
		await RenderingServer.frame_post_draw

func _stand_up_a_camp(spawn: Vector3) -> void:
	for kind in ItemKinds.ALL:
		_inventory.add(kind, 12)

	var forward := Vector3(-sin(deg_to_rad(_yaw)), 0.0, -cos(deg_to_rad(_yaw)))
	var right := Vector3(forward.z, 0.0, -forward.x)
	var placements: Array = [
		[BuildKinds.CAMPFIRE, forward * 5.0],
		[BuildKinds.FENCE, forward * 6.5 + right * 3.0],
		[BuildKinds.FENCE, forward * 7.6 + right * 3.6],
		[BuildKinds.PATH, forward * 2.6],
		[BuildKinds.PATH, forward * 3.8 - right * 0.6],
		[BuildKinds.FEEDER, forward * 6.0 - right * 4.0],
		[BuildKinds.SAPLING, forward * 12.0 - right * 2.0],
		[BuildKinds.SAPLING, forward * 15.5 + right * 2.5],
		[BuildKinds.SAPLING, forward * 18.0 - right * 3.0],
	]
	for entry in placements:
		var kind: StringName = entry[0]
		var offset: Vector3 = entry[1]
		var at := spawn + offset
		at.y = _world.field.height_at(at.x, at.z)
		if not _inventory.spend(BuildKinds.cost(kind)):
			continue
		_structures.place(kind, at, deg_to_rad(_yaw))

	# Push every sapling straight to full growth: the point of the picture is
	# what a grove looks like, not how long it takes.
	var grown := BuildKinds.GROWTH_STAGE_SECONDS * float(BuildKinds.GROWTH_STAGES) + 1.0
	var elapsed := 0.0
	while elapsed < grown:
		_structures._process(2.0)
		elapsed += 2.0
	_birds.set_points(_structures.attract_points())

## A small house, put up the way a child would: walls in a rectangle, a door at
## the front, windows either side, a floor and a roof over the top.
func _stand_up_a_house(near: Vector3) -> void:
	for kind in ItemKinds.ALL:
		_inventory.add(kind, 300)

	var module := HouseParts.MODULE
	var storey := HouseParts.STOREY
	var base := near + Vector3(-module * 1.5, 0.0, -module * 4.0)
	base.y = _world.field.height_at(base.x, base.z)

	var plan: Array = [
		# Front wall with a door in the middle and a window each side.
		[HouseParts.WALL_WINDOW, Vector2(0, 0), 0.0],
		[HouseParts.WALL_DOOR, Vector2(1, 0), 0.0],
		[HouseParts.WALL_WINDOW, Vector2(2, 0), 0.0],
		# Back wall.
		[HouseParts.WALL, Vector2(0, 2), 0.0],
		[HouseParts.WALL_WINDOW, Vector2(1, 2), 0.0],
		[HouseParts.WALL, Vector2(2, 2), 0.0],
		# Sides, turned a quarter.
		[HouseParts.WALL, Vector2(-0.5, 1), PI * 0.5],
		[HouseParts.WALL, Vector2(2.5, 1), PI * 0.5],
		# Floor inside.
		[HouseParts.FLOOR, Vector2(1, 1), 0.0],
	]
	# One floor level for the whole building, taken from the first square, the
	# way the build mode now does it for a player.
	var level := base.y
	for entry in plan:
		var kind: StringName = entry[0]
		var cell: Vector2 = entry[1]
		var spin: float = entry[2]
		var at := base + Vector3(cell.x * module, 0.0, cell.y * module)
		at.y = level
		if _inventory.spend(HouseParts.cost(kind)):
			_structures.place(kind, at, spin)

	# A roof one storey up, over the whole footprint.
	for column in 3:
		var at := base + Vector3(float(column) * module, 0.0, module)
		at.y = level + storey
		if _inventory.spend(HouseParts.cost(HouseParts.ROOF_PEAK)):
			_structures.place(HouseParts.ROOF_PEAK, at, 0.0)

## The checks' house, built through the build mode by the same steps the checks
## take — so the picture is of the house the checks prove stands up.
func _raise_the_test_house() -> void:
	const TestHouse := preload("res://src/dev/test_house.gd")
	if _structures == null:
		# A free camera has no game round it; the house needs somewhere to go.
		_inventory = Inventory.new()
		_structures = Structures.new(_world.field)
		add_child(_structures)
		_build_mode = BuildMode.new(_world.field, _structures, _inventory)
		add_child(_build_mode)
	for kind in ItemKinds.ALL:
		_inventory.add(kind, 300)
	# The forest, as the game tells it to the builder: a house is not put on a
	# tree, and the site is looked for among clear ground.
	_build_mode.set_tree_finder(func(at: Vector3, reach: float) -> Array[Vector3]:
		return _world.vegetation.trees_near(at, reach))
	# Ahead of the player rather than on top of them, so the player is not
	# walled in.
	if _plan != "":
		_raise_a_plan()
		return
	var near := _look_at
	if _player != null:
		var yaw := deg_to_rad(_yaw)
		near = _player.global_position + Vector3(-sin(yaw), 0.0, -cos(yaw)) * 9.0
	var origin: Vector3 = TestHouse.find_site(_build_mode, _world.field, near)
	if not origin.is_finite():
		printerr("test house: no buildable ground near %s" % near)
		return
	var was_active := _build_mode.active
	var built := 0
	for step: Dictionary in TestHouse.build(_build_mode, _world.field, origin):
		if bool(step["built"]):
			built += 1
	_build_mode.set_active(was_active)
	print("test house: %d pieces; north-west square at (%.1f, %.1f, %.1f), middle at (%.1f, %.1f)" % [
		built, origin.x, origin.y, origin.z, origin.x + 1.0, origin.z + 1.0
	])
	if _build and _hud != null:
		_hud._show_house(true)
		_build_mode.select(HouseParts.WALL)

## A ready-made plan in one tap, on the nearest buildable ground to where the
## camera looks.
func _raise_a_plan() -> void:
	const TestHouse := preload("res://src/dev/test_house.gd")
	var near := _look_at
	var origin: Vector3 = TestHouse.find_site(_build_mode, _world.field, near)
	if not origin.is_finite():
		printerr("plan: no buildable ground near %s" % near)
		return
	var was_active := _build_mode.active
	var built: bool = TestHouse.build_plan(_build_mode, _world.field, origin, StringName("plan_" + _plan))
	_build_mode.set_active(was_active)
	print("plan %s: built %s; first square at (%.1f, %.1f, %.1f)" % [_plan, built, origin.x, origin.y, origin.z])
	if _two_storeys and built:
		# A second storey on the plan, as a child would stack it: every wall
		# and floor again a storey up, and a whole roof over the lot.
		var storey := Vector3(0.0, HouseParts.STOREY, 0.0)
		for record in _build_mode.just_placed().duplicate():
			var kind: StringName = record["kind"]
			if HouseParts.is_wall(kind) or kind == HouseParts.FLOOR:
				_structures.place(
					kind, (record["position"] as Vector3) + storey, float(record["spin"]),
					true, Vector2i.ONE, record["material"]
				)
			elif kind == HouseParts.ROOF_ROOM:
				_structures.place(
					kind, (record["position"] as Vector3) + storey, float(record["spin"]),
					true, record["extent"]
				)
				_structures.remove(record)

func _kick_nearest() -> void:
	var ball := _world.football.ball_near(_player.global_position)
	if ball == null:
		return
	# As the game turns a child standing at a ball to face the view.
	_player.face(_kick_look(), 100.0)
	ball.kick(
		_player.global_position, _player.facing(), false,
		_kick_strength, _kick_loft, Vector3.ZERO, deg_to_rad(_kick_turn)
	)

func _kick_look() -> Vector3:
	return Vector3(-sin(_rig.yaw), 0.0, -cos(_rig.yaw))

## The aim preview the game shows while the kick button is held, drawn the way
## the game draws it: the kick's own arithmetic and the green mark.
func _show_the_aim() -> void:
	# With no player (the free camera, which is what a shot is usually taken
	# with), a striker stands beside the middle ball and looks along --yaw.
	var striker := Pitch.centre() + Vector3(1.1, 0.0, 0.0)
	striker.y = _world.field.height_at(striker.x, striker.z)
	var look := Vector3(-sin(deg_to_rad(_yaw)), 0.0, -cos(deg_to_rad(_yaw)))
	if _player != null:
		striker = _player.global_position
		look = _kick_look()
		# As the game turns a child standing at a ball to face the view.
		_player.face(look, 100.0)
		look = _player.facing()
	var ball := _world.football.ball_near(striker)
	if ball == null:
		return
	var ground := func(x: float, z: float) -> float:
		return _world.field.height_at(x, z)
	var velocity := Ball.launch_velocity(
		ball.position, striker, look, false, _kick_strength, _kick_loft, Vector3.ZERO, deg_to_rad(_kick_turn)
	)
	var path := Ball.aim_path(
		ball.position, velocity, ball.effective_linear_damp(), ball.gravity_strength(), ground
	)
	var flight := PackedVector3Array([ball.position])
	flight.append_array(path)
	var preview := KickPreview.new()
	add_child(preview)
	var end := path[path.size() - 1]
	print("aim preview: %d dots from %v to %v, on target: %s" % [path.size(), ball.position, end, Pitch.goal_ahead(flight, Ball.RADIUS, ground) >= 0])
	preview.show_path(path, Pitch.goal_ahead(flight, Ball.RADIUS, ground) >= 0)

func _wait_for_world() -> void:
	var frames := 0
	while frames < _warmup_frames:
		# Time is pinned so the sun does not crawl across the sky while waiting.
		_world.atmosphere.set_time(_time)
		await RenderingServer.frame_post_draw
		frames += 1
		if _world.terrain.is_idle() and _world.vegetation.is_idle() and _world.pickups.is_idle() and _world.boulders.is_idle() and frames > 8:
			break
	if not _world.terrain.is_idle() or not _world.vegetation.is_idle():
		printerr("world still streaming after %d frames" % frames)

	# The far country, which every screenshot this tool has ever taken was
	# missing. DistantLand collects its finished ring inside follow(), and the
	# game calls follow() on every step a child takes — but this tool calls it
	# once and then waits, so the ring was baked and never collected and the
	# horizon came out as bare haze in shot after shot. wait_for_it() exists
	# for exactly this and nothing had ever called it.
	_world.distant_land.wait_for_it()
	await RenderingServer.frame_post_draw
	# Let the player fall the last centimetres onto ground that now exists, and
	# the camera settle behind them.
	if _player != null:
		_player.set_physics_process(true)
		for _i in 40:
			await RenderingServer.frame_post_draw

	# Strike a ball and watch it go, so the picture proves the kick rather than
	# merely showing a ball sitting on the grass.
	if _aim_preview:
		_show_the_aim()
	if _kick_after > 0.0:
		_kick_nearest()
		var flying := 0.0
		while flying < _kick_after:
			flying += 1.0 / 60.0
			await RenderingServer.frame_post_draw
	# A few extra frames so shadow splits and the sky have settled, and so the
	# build ghost has been aimed at least once.
	for _i in 6:
		_world.atmosphere.set_time(_time)
		# What the game does every frame: a camera put under the river has to
		# show the river, not the valley through clear air.
		if _camera != null:
			_world.see_from(_camera.global_position, 1.0)
		if _build and _player != null:
			_build_mode.aim(_player.global_position, _rig.yaw)
			# And the storey row, as the game shows it every frame.
			_hud.set_storey(
				_build_mode.storey(),
				_build_mode.active and HouseParts.is_house_part(_build_mode.selected)
			)
			# And the line for a first house, from what stands.
			_hud.set_house_hint(_structures.house_step())
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
	print("scene: chunks=%d surfaces=%d triangles=%d plants=%d pickups=%d rocks=%d" % [chunks, surfaces, triangles, plants, _world.pickups.count_active(), _world.boulders.count_active()])
	print("bounds: %v size %v" % [bounds.position, bounds.size])
	print("camera: pos=%v looking=%v fov=%.0f far=%.0f" % [
		_camera.global_position, -_camera.global_transform.basis.z, _camera.fov, _camera.far])
	# What is actually near the camera, and what it is. A screenshot cannot tell
	# a football from a rock, and guessing between them has already cost a round.
	if _player != null and _world != null:
		var near: Array[String] = []
		for node in _world.football.get_children():
			var at: Vector3 = node.global_position if node is Node3D else Vector3.ZERO
			if at.distance_to(_player.global_position) < 14.0:
				near.append("%s@%v" % [node.get_class() if node.get_script() == null else str(node.get_script().resource_path).get_file(), at])
		print("football nodes near player: %s" % ", ".join(near))
		var strays: Array[String] = []
		for node in _world.pickups.get_children():
			for item in node.get_children():
				var at: Vector3 = (item as Node3D).global_position
				if at.distance_to(_player.global_position) < 8.0:
					strays.append("%v" % at)
		print("pickups within 8 m: %d" % strays.size())

	if _structures != null:
		print("built: %d structures, %d grove(s), %d bird point(s)" % [
			_structures.to_data().size(), _structures.grove_count(),
			_structures.attract_points().size()])
	if _player != null and _camera != null:
		var back := _camera.global_position.distance_to(_player.global_position)
		print("camera stands %.2f m from the player (arm is %.2f)" % [back, CameraRig.ARM_LENGTH])
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
			"demo":
				_demo = value.to_int() != 0
			"build":
				_build = value.to_int() != 0
			"atcafe":
				_at_cafe = value.to_int() != 0
			"atshop":
				_at_shop = value.to_int() != 0
			"atpitch":
				_at_pitch = value.to_int() != 0
			"kick":
				# Seconds of flight to watch after striking the ball.
				_kick_after = value.to_float()
			"aim":
				_aim_preview = value.to_int() != 0
			"score":
				var both := value.split(",")
				if both.size() == 2:
					_score = Vector2i(both[0].to_int(), both[1].to_int())
			"side":
				_side = value.to_int()
			"winner":
				_winner = value.to_int()
			"flash":
				_flash = value.to_int()
			"power":
				_kick_strength = value.to_float()
			"loft":
				_kick_loft = value.to_float()
			"turn":
				_kick_turn = value.to_float()
			"house":
				_house = value.to_int() != 0
			"testhouse":
				_test_house = value.to_int() != 0
			"group":
				_palette_group = value
			"material":
				_wall_material = value
			"storeys":
				_two_storeys = value.to_int() > 1
			"plan":
				# room, house, cafe or shop: built in one tap, like testhouse.
				_plan = value
				_test_house = true
			"lang":
				_language = value
			"zoom":
				# Metres to pull the camera out from its default.
				_zoom = value.to_float()
			"shop":
				_shop = value.to_int() != 0
			"together":
				_together = value
			"map":
				_map = value
			"guide":
				_guide = value
			"legend":
				_legend = value.to_int() != 0
			"friend":
				var fz := value.split(",")
				_friend = Vector2(fz[0].to_float(), fz[1].to_float())
			"mapat":
				var xz := value.split(",")
				_map_at = Vector2(xz[0].to_float(), xz[1].to_float())
			"energy":
				_energy = value.to_float()
			"chop":
				_chop = value.to_int()
			"mounts":
				_mounts = value.to_int() != 0
			"ride":
				_ride = StringName(value)
			"rider":
				_rider = value.to_int()
			"figure":
				_figure = value.to_int()
			"character":
				_look = Array(value.split(",")).map(func(part: String) -> int: return part.to_int())
			"dam":
				_dam = value.to_int() != 0
			"water":
				_water = value.to_float()
			"animals":
				_animals = value.to_int() != 0
			"animalyaw":
				_animal_yaw = value.to_float()
			"only":
				_only_kind = value
			"animalat":
				_animal_at = value.to_float()
			"coins":
				_coins = value.to_int()
			"menu":
				_menu = value.to_int() != 0
			"settings":
				_settings = value.to_int() != 0
			"meal":
				_meal = StringName(value)
			"sit":
				_sit = value.to_int() != 0
			"mealframes":
				_meal_frames = value.to_int()
			"pos":
				_camera_position = _to_vector(value, _camera_position)
			"look":
				_look_at = _to_vector(value, _look_at)

func _to_vector(text: String, fallback: Vector3) -> Vector3:
	var parts := text.split(",")
	if parts.size() != 3:
		return fallback
	return Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())

## Bring one of every animal into view, so a screenshot can show whether they
## read as a cat, a dog, a squirrel and a beaver rather than as four blobs.
func _gather_animals() -> void:
	# In front of whoever is looking. With a player it is the player; without
	# one it is the camera, looking where the camera looks — it used to be the
	# *look-at point*, which moves the animals every time the camera is aimed
	# at them, so framing a row of them was a chase.
	var origin := _player.global_position if _player != null else _camera_position
	var forward: Vector3
	if _player != null:
		# _yaw is stored in degrees, as the flag is written; the rig converts
		# it on use. Reading it as radians put three of the four animals behind
		# us. Godot faces -Z, so forward is negated.
		var heading := deg_to_rad(_yaw)
		forward = -Vector3(sin(heading), 0.0, cos(heading))
	else:
		forward = (_look_at - _camera_position)
		forward.y = 0.0
		forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
	var across := Vector3(forward.z, 0.0, -forward.x)
	for i in AnimalKinds.ALL.size():
		var kind: StringName = AnimalKinds.ALL[i]
		# Centred on however many kinds there are. It was written for four and
		# there are six now, which put the row off to one side of the shot.
		var middle := (float(AnimalKinds.ALL.size()) - 1.0) * 0.5
		# Far enough out to get the whole row in one frame: they are placed in
		# front of the camera now, and three and a half metres from the lens
		# put the ends of the row outside the picture.
		var spot := origin + forward * _animal_at + across * (float(i) - middle) * 1.9
		if _only_kind != "":
			if String(kind) != _only_kind:
				continue
			spot = origin + forward * _animal_at
		spot.y = _world.field.height_at(spot.x, spot.z)
		# The node the game itself hangs, legs and all: the baked mesh has paws
		# of its own and hid how the legs of the real animal meet the ground.
		var body := AnimalKinds.build_node(kind, AnimalKinds.variant_at(spot.x, spot.z))
		# Facing the camera, so a screenshot shows heads rather than tails. The
		# meshes face -Z, as Godot does, so turning them by the heading alone
		# pointed them the way the camera looks — tails first.
		body.rotation.y = atan2(-forward.x, -forward.z) + PI + deg_to_rad(_animal_yaw)
		add_child(body)
		# Local, not global. This node is at the origin, so the two are the
		# same number — except when this runs before the capture scene itself
		# is in the tree, and then `global_position` quietly does nothing and
		# every animal stands at the origin while the log says otherwise.
		body.position = spot
		print("  %s at (%.1f, %.1f, %.1f) size %.2f" % [kind, spot.x, spot.y, spot.z, AnimalKinds.size_of(kind)])

## Fell the nearest trees, so a screenshot can show that the forest really
## changed rather than that a record was written.
func _fell_nearby() -> void:
	var at := _player.global_position if _player != null else _look_at
	var cut := 0
	for _i in _chop:
		var answer := _world.vegetation.nearest_tree_found(at, 30.0)
		if not bool(answer[1]):
			break
		var tree: Vector3 = answer[0]
		_world.felled.fell(tree)
		_world.vegetation.rebuild_around(tree)
		cut += 1
	print("felled %d trees; %d stumps recorded" % [cut, _world.felled.count()])

## One mount with a child seated on it, placed at the --look point, for a close
## look at the seat pose. The rig sits where the game puts it: the mount's own
## origin lifted by MountKinds.eye_lift, and is posed by the same RigMotion.
func _seat_a_rider() -> void:
	if _ride == &"carousel":
		_seat_a_rider_on_the_carousel()
		return
	var spot := _look_at
	spot.y = _world.field.height_at(spot.x, spot.z)
	_world.mounts.place(_ride, spot)
	if _rider < 0:
		return
	var rig := Character.build(_rider, 1, 1, Visitors.SHIRTS[2])
	rig.position = Vector3.UP * MountKinds.eye_lift(_ride)
	_world.mounts.node_of(_ride).add_child(rig)
	var motion := RigMotion.new(rig)
	motion.seat = MountKinds.kind_of(_ride)
	for _i in 90:
		motion.step(1.0 / 60.0)

## A child on one of the carousel's figures, put where the ride puts them: at
## the saddle's own transform, posed by the same RigMotion with the carousel's
## pose. The ride is still, so the saddle is at its resting height.
func _seat_a_rider_on_the_carousel() -> void:
	var saddle := _world.park.carousel.saddles()[_figure % Carousel.HORSES]
	print("carousel figure %d (%s): saddle at (%.2f, %.2f, %.2f)" % [
		_figure, Carousel.KINDS[_figure % Carousel.HORSES],
		saddle.origin.x, saddle.origin.y, saddle.origin.z])
	if _rider < 0:
		return
	var rig := Character.build(_rider, 1, 1, Visitors.SHIRTS[2])
	_world.add_child(rig)
	rig.global_transform = saddle
	var motion := RigMotion.new(rig)
	motion.seat = &"carousel"
	for _i in 90:
		motion.step(1.0 / 60.0)

## A horse and a bicycle side by side, so a screenshot shows whether each reads
## as what it is.
func _show_mounts() -> void:
	var origin := _player.global_position if _player != null else _look_at
	var heading := deg_to_rad(_yaw)
	var forward := -Vector3(sin(heading), 0.0, cos(heading))
	var across := Vector3(forward.z, 0.0, -forward.x)
	for i in MountKinds.ALL.size():
		var kind: StringName = MountKinds.ALL[i]
		var spot := origin + forward * 5.0 + across * (float(i) - 0.5) * 3.4
		_world.mounts.place(kind, spot)
		print("  %s at (%.1f, %.1f)" % [kind, spot.x, spot.z])
