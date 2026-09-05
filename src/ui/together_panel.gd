class_name TogetherPanel
extends PanelContainer

## Playing together, as a child can actually operate it.
##
## The hard part of this screen is not the network, it is the address. A full
## one is fifteen characters of dots and digits — unreadable at six and a typing
## task at ten. But two devices on a family network share everything except the
## last number, so this shows *one number* and asks for *one number*. The child
## hosting reads it out; the child joining taps it in on keys the size of a
## thumb.
##
## There is no text entry anywhere on this screen. A name is picked from a list
## of the children who already exist, and a number is tapped on a keypad. Both
## because a six-year-old cannot type, and because every character a child can
## enter is a character that has to be validated before it is shown to anyone.

signal host_requested()
signal join_requested(code: int)
signal leave_requested()
signal closed()

## Emitted whenever the page changes, because each page is a different size and
## whoever positions this panel has to be told.
signal resized_page()

enum Page { CHOICE, HOSTING, TYPING, VISITING }

const BUTTON_HEIGHT := 74.0
const KEY_SIZE := 92.0

var page := Page.CHOICE

var _column: VBoxContainer
var _typed := ""

func _init() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.13, 0.96)
	style.set_corner_radius_all(18)
	style.content_margin_left = 26.0
	style.content_margin_right = 26.0
	style.content_margin_top = 20.0
	style.content_margin_bottom = 20.0
	style.border_color = Color(0.58, 0.82, 0.96, 0.4)
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)
	visible = false

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 12)
	add_child(_column)

func open() -> void:
	page = Page.CHOICE
	_typed = ""
	visible = true
	_rebuild()

func show_hosting() -> void:
	page = Page.HOSTING
	visible = true
	_rebuild()

func show_visiting() -> void:
	page = Page.VISITING
	visible = true
	_rebuild()

func close() -> void:
	visible = false
	closed.emit()

## Redrawn wholesale on every change rather than updated in place. This panel is
## opened a few times an afternoon and holds at most a dozen controls, so the
## cost is nothing and the alternative — keeping four pages of widgets in step —
## is where interface bugs actually live.
func _rebuild() -> void:
	for child in _column.get_children():
		child.queue_free()

	match page:
		Page.CHOICE:
			_build_choice()
		Page.HOSTING:
			_build_hosting()
		Page.TYPING:
			_build_typing()
		Page.VISITING:
			_build_visiting()

	# The freed children of the old page are still counted in the minimum size
	# until the tree processes their removal, so the caller is told to measure
	# again on the next frame rather than this one.
	resized_page.emit()

func _build_choice() -> void:
	_heading(Text.of("ui_together"))

	var invite := _big(Text.of("ui_invite"), Color(0.62, 0.88, 0.68))
	invite.pressed.connect(func() -> void: host_requested.emit())
	_column.add_child(invite)

	var visit := _big(Text.of("ui_visit"), Color(0.58, 0.82, 0.96))
	visit.pressed.connect(_start_typing)
	_column.add_child(visit)

	_column.add_child(_back())

## The number to read out, as large as it will go. This is the whole screen: a
## child holds up the tablet and says "one six one".
func _build_hosting() -> void:
	_heading(Text.of("ui_your_number"))

	var code := Session.own_code()
	if code <= 0:
		_note(Text.of("say_no_network"))
	else:
		var number := Label.new()
		number.text = str(code)
		number.add_theme_font_size_override("font_size", 128)
		number.add_theme_color_override("font_color", Color(0.62, 0.88, 0.68))
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_column.add_child(number)
		_note(Text.of("say_read_it_out"))

	var leave := _big(Text.of("ui_play_alone"), Color(0.94, 0.72, 0.66))
	leave.pressed.connect(func() -> void: leave_requested.emit())
	_column.add_child(leave)

	_column.add_child(_back())

## A keypad, because a child cannot type an address but can tap three digits.
func _build_typing() -> void:
	_heading(Text.of("ui_their_number"))

	var entry := Label.new()
	entry.text = _typed if not _typed.is_empty() else "—"
	entry.add_theme_font_size_override("font_size", 96)
	entry.add_theme_color_override("font_color", Color(0.58, 0.82, 0.96))
	entry.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(entry)

	var keys := GridContainer.new()
	keys.columns = 3
	keys.add_theme_constant_override("h_separation", 8)
	keys.add_theme_constant_override("v_separation", 8)
	_column.add_child(keys)

	for digit in range(1, 10):
		keys.add_child(_key(str(digit)))
	# Bottom row: clear, zero, and go — in that order so the two destructive-ish
	# keys are not either side of the one that acts.
	keys.add_child(_key("←"))
	keys.add_child(_key("0"))

	var go := _key("✓")
	go.add_theme_color_override("font_color", Color(0.62, 0.88, 0.68))
	go.disabled = _typed.is_empty()
	keys.add_child(go)

	_column.add_child(_back())

func _build_visiting() -> void:
	_heading(Text.of("ui_together"))
	_note(Text.of("say_visiting"))

	var leave := _big(Text.of("ui_play_alone"), Color(0.94, 0.72, 0.66))
	leave.pressed.connect(func() -> void: leave_requested.emit())
	_column.add_child(leave)

	_column.add_child(_back())

func _start_typing() -> void:
	page = Page.TYPING
	_typed = ""
	_rebuild()

func _press(key: String) -> void:
	match key:
		"←":
			_typed = _typed.substr(0, maxi(0, _typed.length() - 1))
		"✓":
			var code := _typed.to_int()
			if code >= 1 and code <= 254:
				join_requested.emit(code)
			_typed = ""
			return
		_:
			# Three digits is the whole range; a fourth would be a typo, and
			# refusing it silently is kinder than clearing what was typed.
			if _typed.length() < 3:
				_typed += key
	_rebuild()

func _key(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(KEY_SIZE, KEY_SIZE)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 40)
	button.pressed.connect(func() -> void: _press(label))
	return button

func _big(label: String, colour: Color) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(KEY_SIZE * 3.0 + 16.0, BUTTON_HEIGHT)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 26)
	button.add_theme_color_override("font_color", colour)
	return button

func _back() -> Button:
	var button := _big(Text.of("ui_back"), Color(0.86, 0.89, 0.94))
	button.custom_minimum_size.y = BUTTON_HEIGHT * 0.8
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(close)
	return button

func _heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.72))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(label)

func _note(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = KEY_SIZE * 3.0
	_column.add_child(label)
