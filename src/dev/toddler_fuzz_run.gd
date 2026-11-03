extends SceneTree

## The toddler fuzz on its own, for as long as you like. See toddler_fuzz.gd.
##
##   godot --headless --script src/dev/toddler_fuzz_run.gd -- --frames=4000
##
## The suite runs a short version of the same thing; this is for after changing
## a button, a hold or anything that spends. Exits 1 and prints every loss if the
## child lost anything.

func _initialize() -> void:
	InputActions.register()
	var frames := 4000
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--frames="):
			frames = argument.substr(9).to_int()
	var only: Array = []
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			for name in argument.substr(7).split(","):
				only.append(StringName(name))
	var fuzz := preload("res://src/dev/toddler_fuzz.gd").new()
	await fuzz.run(self, frames, true, only)
	print("toddler fuzz: %d taps, %d holds completed, coins %s" % [
		fuzz.report.get("taps", 0), fuzz.report.get("holds_completed", 0),
		str(fuzz.report.get("coins", []))
	])
	for line in fuzz.report.get("meant", []):
		print("  meant: %s" % line)
	for line in fuzz.failures:
		printerr("  LOST: %s" % line)
	quit(1 if not fuzz.failures.is_empty() else 0)
