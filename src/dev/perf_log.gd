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

## The slowest run of each named main-thread step in this window, in
## milliseconds. Filled through `note()` from wherever the game does work it
## suspects of hitching — chunk assembly, tile assembly, the animals — and
## printed with the frame numbers, so a "worst gap 140 ms" line names its
## cause instead of leaving it to be guessed at. Static, so callers need no
## reference to this node and cost one dictionary write in a debug build and
## one boolean test in a release.
static var _slow: Dictionary = {}
static var _enabled := false

## Below this a step is not worth naming.
const WORTH_NAMING_MS := 4.0

func _init() -> void:
	name = "PerfLog"
	_enabled = true

## The moment a step starts. Pair with `note()`.
static func stamp() -> int:
	return Time.get_ticks_usec()

## Record how long a step took, keeping the worst of each name.
static func note(step: String, since: int) -> void:
	if not _enabled:
		return
	var ms := float(Time.get_ticks_usec() - since) / 1000.0
	if ms > float(_slow.get(step, 0.0)):
		_slow[step] = ms

## The slowest steps of the window, worst first, as text.
static func _slow_report() -> String:
	var names := _slow.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return float(_slow[a]) > float(_slow[b]))
	var parts: PackedStringArray = []
	for step: String in names:
		if float(_slow[step]) < WORTH_NAMING_MS or parts.size() >= 4:
			break
		parts.append("%s %.1f ms" % [step, float(_slow[step])])
	_slow.clear()
	return ", ".join(parts) if not parts.is_empty() else "nothing over %.0f ms" % WORTH_NAMING_MS

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
			+ "physics %.2f ms | %d draw calls | %d k primitives | vram %.0f MB | slow: %s"
		) % [
			Performance.get_monitor(Performance.TIME_FPS),
			mean_process,
			_worst_frame * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0),
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
			_slow_report(),
		]
	)

	_elapsed = 0.0
	_frames = 0
	_worst_frame = 0.0
	_process_total = 0.0
