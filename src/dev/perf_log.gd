class_name PerfLog
extends Node

## What the game actually costs, printed from inside the running game.
##
## Everything measured before this was measured on a laptop and multiplied by a
## guess. `adb shell dumpsys SurfaceFlinger --latency` can prove the frames are
## arriving on time, which is worth knowing, but a game locked to vsync looks
## identical at four milliseconds a frame and at fifteen — and the difference
## between those two is the difference between a tablet that stays cool for an
## afternoon and one that throttles in ten minutes.
##
## So this reports the numbers only the engine knows: how long the frame
## actually took on the CPU, how many draw calls went out, how much graphics
## memory is held. On Android `print` reaches logcat, so
## `adb logcat -s godot` is the whole reading apparatus.
##
## Debug builds only, and it says so in every line, because a number without
## its conditions is how the 8.34 ms that turned out to be the monitor's
## refresh rate got believed for an afternoon.

## How often to report. Long enough not to be noise in the log, short enough
## that walking into a forest and reading the next line is one motion.
const INTERVAL := 3.0

var _elapsed := 0.0
var _worst_frame := 0.0
var _frames := 0
var _process_total := 0.0

func _init() -> void:
	name = "PerfLog"

func _process(delta: float) -> void:
	_frames += 1
	_worst_frame = maxf(_worst_frame, delta)
	_process_total += Performance.get_monitor(Performance.TIME_PROCESS)

	_elapsed += delta
	if _elapsed < INTERVAL:
		return

	# Averaged over the window rather than sampled once, because one sample
	# lands wherever it lands — often on the frame a chunk was built.
	var mean_process := (_process_total / float(_frames)) * 1000.0
	print(
		(
			"perf: %.0f fps | cpu frame %.2f ms (worst gap %.1f ms) | "
			+ "physics %.2f ms | %d draw calls | %d k primitives | vram %.0f MB"
		) % [
			Performance.get_monitor(Performance.TIME_FPS),
			mean_process,
			_worst_frame * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0),
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		]
	)

	_elapsed = 0.0
	_frames = 0
	_worst_frame = 0.0
	_process_total = 0.0
