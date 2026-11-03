extends SceneTree

## The settings panel's choice rows, or the first-run panel, on their own.
##
##   godot --path . --resolution 1280x720 --script src/dev/look_panel_view.gd -- \
##         --out=panel.png [--offer=1] [--look=2,1,3] [--shirt=4] [--lang=ru]

var _out := "panel.png"
var _offer := false
var _look: Array = [0, 0, 0]
var _shirt := 2
var _frames := 0
var _hud: Hud

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		var parts := argument.split("=", true, 1)
		if parts.size() != 2:
			continue
		match parts[0].lstrip("-"):
			"out": _out = parts[1]
			"offer": _offer = parts[1] == "1"
			"look": _look = Array(parts[1].split(",")).map(func(v: String) -> int: return v.to_int())
			"shirt": _shirt = parts[1].to_int()
			"lang": Text.set_language(StringName(parts[1]))
	InputActions.register()
	var back := ColorRect.new()
	back.color = Color(0.40, 0.58, 0.34)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(back)
	_hud = Hud.new()
	get_root().add_child(_hud)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 3:
		_hud.set_look(_look)
		_hud.set_shirt(_shirt)
		if _offer:
			_hud.offer_look()
		else:
			_hud._toggle_menu()
	if _frames < 10:
		return false
	get_root().get_texture().get_image().save_png(_out)
	print("written ", _out)
	quit()
	return true
