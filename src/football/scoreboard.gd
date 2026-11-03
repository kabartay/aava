class_name Scoreboard
extends Node3D

## The scoreboard: five metres of it, standing at the middle of the north
## touchline, facing the pitch, so that a child on the far touchline thirty
## metres away can still read who is winning.
##
## Two legs, a dark board with the title thin across the top and the two
## scores in big digits in the sides' own colours — blue on the left, which is
## the west end it defends, red on the right. The digits are unshaded, not lit
## by the sun: a board that goes black at dusk is a board nobody can read when
## the floodlights are the only reason anyone is still playing.
##
## The legs and the board are solid, like the goalposts, so a stray shot
## rattles off them rather than through.

const BOARD_COLOUR := Color(0.09, 0.10, 0.13)
const LEG_COLOUR := Color(0.30, 0.31, 0.34)
const TITLE_COLOUR := Color(0.86, 0.88, 0.92)
const COLON_COLOUR := Color(0.96, 0.96, 0.94)

## How far the writing floats in front of the board's face, so it never sits
## coplanar with it and flickers.
const WRITING_OUT := 0.03

var _blue: Label3D
var _red: Label3D
var _title: Label3D

## Which side's number is flashing, and for how much longer. -1 for neither.
var _flashing := -1
var _flash_left := 0.0
## How long a goal's flash lasts, and how fast it blinks between the side's
## colour and white.
const FLASH_RATE := 6.0

## What the title says in place of its usual word while somebody has won.
var _winner := -1

## `ground` is the height of the grass at the foot, which the legs are sunk a
## little into, so a gentle slope never shows a gap under one of them.
func _init(ground: float) -> void:
	name = "Scoreboard"
	var foot := Pitch.scoreboard_foot()
	position = Vector3(foot.x, ground, foot.z)

	var legs := StandardMaterial3D.new()
	legs.albedo_color = LEG_COLOUR
	legs.roughness = 0.7
	var board := StandardMaterial3D.new()
	board.albedo_color = BOARD_COLOUR
	board.roughness = 0.85

	var half := Pitch.BOARD_HALF_WIDTH
	var leg_x := half - 0.55
	var sunk := 0.4
	for side in PackedFloat32Array([-1.0, 1.0]):
		_slab(
			Vector3(side * leg_x, (Pitch.BOARD_HEIGHT - sunk) * 0.5, 0.0),
			Vector3(Pitch.LEG_HALF * 2.0, Pitch.BOARD_HEIGHT + sunk, Pitch.LEG_HALF * 2.0),
			legs
		)
	var middle_y := Pitch.BOARD_HEIGHT - Pitch.BOARD_FACE * 0.5
	_slab(
		Vector3(0.0, middle_y, 0.0),
		Vector3(half * 2.0, Pitch.BOARD_FACE, Pitch.BOARD_THICKNESS),
		board
	)

	var front := Pitch.BOARD_THICKNESS * 0.5 + WRITING_OUT
	var top := Pitch.BOARD_HEIGHT

	# The title, thin and small across the top.
	_title = _write(Text.of("board_title"), 0.0035, TITLE_COLOUR)
	_title.position = Vector3(0.0, top - 0.3, front)
	add_child(_title)

	# The two scores, and between them a colon.
	var digits_y := top - 1.3
	_blue = _write("0", 0.009, Goal.SIDE_COLOURS[0])
	_blue.position = Vector3(-1.55, digits_y, front)
	add_child(_blue)
	_red = _write("0", 0.009, Goal.SIDE_COLOURS[1])
	_red.position = Vector3(1.55, digits_y, front)
	add_child(_red)
	var colon := _write(":", 0.009, COLON_COLOUR)
	colon.position = Vector3(0.0, digits_y + 0.05, front)
	add_child(colon)

	# A bar of each colour under its number, so which side is which does not
	# rest on the digits alone.
	for side in 2:
		var bar := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(half - 0.7, 0.14, 0.02)
		bar.mesh = mesh
		var paint := StandardMaterial3D.new()
		paint.albedo_color = Goal.SIDE_COLOURS[side]
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bar.material_override = paint
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bar.position = Vector3((-1.0 if side == 0 else 1.0) * (half * 0.5 + 0.1), top - Pitch.BOARD_FACE + 0.28, front - WRITING_OUT * 0.5)
		add_child(bar)

## Put the two scores up.
func show_scores(blue: int, red: int) -> void:
	_number(_blue, blue)
	_number(_red, red)

## Make the scorer's number flash in its colour for `seconds`, so that a goal is
## a moment on the board and not only a digit that changed.
func celebrate(side: int, seconds: float) -> void:
	_blue.modulate = Goal.SIDE_COLOURS[0]
	_red.modulate = Goal.SIDE_COLOURS[1]
	_flashing = side
	_flash_left = seconds

## Is a number flashing now, and whose? For the checks: -1 for nobody's.
func flashing() -> int:
	return _flashing if _flash_left > 0.0 else -1

## Say who has won, in the winner's colour, in place of the title; -1 puts the
## title back. The winner's number flashes until the next game begins.
func show_winner(side: int, seconds: float) -> void:
	_winner = side
	if side < 0:
		_flash_left = 0.0
		_blue.modulate = Goal.SIDE_COLOURS[0]
		_red.modulate = Goal.SIDE_COLOURS[1]
		_title.text = Text.of("board_title")
		_title.modulate = TITLE_COLOUR
		_title.pixel_size = 0.0035
		return
	_title.text = Text.of("board_wins_blue" if side == 0 else "board_wins_red")
	_title.modulate = Goal.SIDE_COLOURS[side]
	# As big as fits across the board, whatever the language makes of it.
	_title.pixel_size = clampf(5.2 / (float(_title.text.length()) * 115.0), 0.002, 0.0055)
	celebrate(side, seconds)
	_confetti(side)

## The title as it reads, for the checks.
func title_text() -> String:
	return _title.text

func _process(delta: float) -> void:
	if _flash_left <= 0.0:
		return
	_flash_left -= delta
	var label := _blue if _flashing == 0 else _red
	if _flash_left <= 0.0:
		label.modulate = Goal.SIDE_COLOURS[_flashing]
		return
	# Between the side's colour and white, so the number blinks rather than
	# merely changing hue, which reads at thirty metres.
	var on := int(floor(_flash_left * FLASH_RATE)) % 2 == 0
	label.modulate = Goal.SIDE_COLOURS[_flashing] if on else Color(1.0, 1.0, 1.0)

## A burst of paper in the winner's colours above the board, which falls and is
## gone: a simple one-shot, with no scene to load.
func _confetti(side: int) -> void:
	var burst := CPUParticles3D.new()
	burst.name = "Confetti"
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 90
	burst.lifetime = 2.6
	burst.explosiveness = 1.0
	burst.direction = Vector3.UP
	burst.spread = 55.0
	burst.initial_velocity_min = 5.0
	burst.initial_velocity_max = 9.0
	burst.gravity = Vector3(0.0, -6.0, 0.0)
	burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	burst.emission_box_extents = Vector3(Pitch.BOARD_HALF_WIDTH, 0.2, 0.3)
	var paper := Gradient.new()
	paper.colors = PackedColorArray([
		Goal.SIDE_COLOURS[side], Color(1.0, 1.0, 1.0), Color(0.98, 0.84, 0.25),
	])
	paper.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	burst.color_initial_ramp = paper
	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.4)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = material
	burst.mesh = quad
	burst.position = Vector3(0.0, Pitch.BOARD_HEIGHT + 0.3, 0.6)
	add_child(burst)
	# Gone with the paper, not left emitting nothing for the rest of the game.
	if is_inside_tree():
		get_tree().create_timer(burst.lifetime + 0.5).timeout.connect(burst.queue_free)

## What is written for each side, for the checks.
func digits() -> PackedStringArray:
	return PackedStringArray([_blue.text, _red.text])

func _number(label: Label3D, value: int) -> void:
	label.text = str(value)
	# Three digits do not fit the half of the board they have.
	label.pixel_size = 0.009 if label.text.length() <= 2 else 0.006

## A line of writing that is lit by itself, not by the day.
static func _write(text: String, pixel: float, colour: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 200
	label.pixel_size = pixel
	label.modulate = colour
	label.shaded = false
	label.double_sided = false
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return label

## One solid, drawn box: a visible mesh with a static body the same size.
func _slab(at: Vector3, size: Vector3, material: StandardMaterial3D) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	visual.position = at
	add_child(visual)

	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	var body := StaticBody3D.new()
	# Props, like the goalposts: the ball and the child stop for it, the camera
	# looks past.
	body.collision_layer = TerrainSpec.LAYER_PROPS
	body.position = at
	body.add_child(collider)
	add_child(body)
