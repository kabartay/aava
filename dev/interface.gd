extends Node2D

## Interface screenshot tool.
##
## dev/capture.tscn renders the valley; this renders the controls drawn over it.
## They are all drawn in code — no image files anywhere — so a glyph that is
## wrong is wrong in a way no check can see and no amount of reading the source
## will show. The microphone, the globe and the two children were all drawn
## against this.
##
## Usage:
##   godot --path . --resolution 1080x2376 res://dev/interface.tscn -- \
##         --out=/tmp/hud.png [--icons=1]
##
##   --icons=1  the glyph sheet on its own, large, instead of the whole screen.
##   --flags=1  the language flags, large.

const DEFAULT_OUT := "user://interface.png"

func _ready() -> void:
	var out := DEFAULT_OUT
	var icons_only := false
	var flags_only := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
		elif argument == "--icons=1":
			icons_only = true
		elif argument == "--flags=1":
			flags_only = true

	if flags_only:
		_build_flag_sheet()
	elif icons_only:
		_build_icon_sheet()
	else:
		_build_screen()

	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("wrote %s" % out)
	get_tree().quit()

## The language flags, big enough to judge. They are drawn rather than loaded,
## so this is the only way to look at one.
func _build_flag_sheet() -> void:
	var cell := Vector2(300.0, 200.0)
	for i in FlagIcon.Kind.size():
		var flag := FlagIcon.new(i as FlagIcon.Kind)
		flag.position = Vector2(24.0 + float(i) * (cell.x + 24.0), 24.0)
		flag.size = cell
		add_child(flag)

## Every glyph side by side, on the dark the buttons actually use.
func _build_icon_sheet() -> void:
	var kinds: Array[ActionIcon.Kind] = [
		ActionIcon.Kind.MAP, ActionIcon.Kind.VIEW_FIRST, ActionIcon.Kind.VIEW_THIRD,
		ActionIcon.Kind.MIC_ON, ActionIcon.Kind.MIC_OFF, ActionIcon.Kind.TOGETHER,
		ActionIcon.Kind.JUMP, ActionIcon.Kind.TALK, ActionIcon.Kind.BUILD,
	]
	var cell := 150.0
	for i in kinds.size():
		var panel := ColorRect.new()
		panel.color = Color(0.16, 0.16, 0.18)
		panel.position = Vector2(20.0 + float(i) * (cell + 16.0), 20.0)
		panel.size = Vector2(cell, cell)
		add_child(panel)
		var icon := ActionIcon.new(kinds[i])
		icon.size = Vector2(cell, cell)
		panel.add_child(icon)

## The real HUD over a flat ground, so spacing and overlap can be judged.
func _build_screen() -> void:
	var ground := ColorRect.new()
	ground.color = Color(0.32, 0.44, 0.30)
	ground.size = get_viewport().get_visible_rect().size
	add_child(ground)

	var hud := Hud.new()
	add_child(hud)
	hud.set_coins(42)
	hud.set_voice_allowed(true)
	hud.set_first_person(false)
