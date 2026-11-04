class_name VolumeBars
extends HBoxContainer

## A volume as a row of bars that grow taller, a picture of loudness: tap the
## fourth and four are lit. Nothing in it is a word or a number, and it has no
## slider to drag, which a thumb on a moving world's panel would miss.
##
## It only draws and reports. The buttons are public so the settings can make
## them need a hold, like everything else in the grown-ups' panel that changes
## how the game behaves.

## The most a bar can be lit up to; the same as the mixer's steps.
const STEPS := Mix.STEPS

const LIT := Color(0.96, 0.93, 0.78)
const DIM := Color(1.0, 1.0, 1.0, 0.16)

## The side-to-side size of a bar and its height: wide enough for a thumb, and
## a grown-up's 7 mm and more on the phones this is made for.
const BAR_WIDTH := 72.0
const BAR_HEIGHT := 96.0

var buttons: Array[Button] = []
var steps := STEPS
var _fills: Array[ColorRect] = []

func _init() -> void:
	add_theme_constant_override("separation", 6)
	for i in STEPS:
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
		button.tooltip_text = str(i + 1)
		var fill := ColorRect.new()
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.anchor_left = 0.22
		fill.anchor_right = 0.78
		fill.anchor_bottom = 0.88
		# Each bar a little taller than the one before: 28% to 80% of the button.
		fill.anchor_top = 0.88 - (0.28 + 0.52 * float(i) / float(STEPS - 1))
		button.add_child(fill)
		buttons.append(button)
		_fills.append(fill)
		add_child(button)
	set_steps(STEPS)

## Light this many bars, 1 to STEPS.
func set_steps(lit: int) -> void:
	steps = clampi(lit, 1, STEPS)
	for i in STEPS:
		_fills[i].color = LIT if i < steps else DIM
