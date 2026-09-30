class_name Atmosphere
extends Node3D

## Sky, sun and time of day.
##
## Light is doing most of the artistic work in this game. There are no textures
## and no hand-painted art, so what separates a warm sunlit valley from a pile of
## coloured polygons is entirely here: the angle of the sun, the colour it throws,
## how far you can see before the air takes over, and how the sky changes across
## an evening. Getting this right is cheaper than any amount of modelling.

## A full day in seconds. Long enough that a session has one mood rather than a
## strobing sunrise, short enough that a child who plays twice sees two skies.
const DAY_LENGTH := 1200.0

## Where the day starts when a new world is created: late morning, high contrast,
## long enough before evening that the first session is bright.
const START_TIME := 0.36

var time_of_day := START_TIME

var _sun: DirectionalLight3D
var _environment: Environment
var _sky_material: ProceduralSkyMaterial

## The air, as the sky sets it. Named rather than written twice, because
## underwater borrows these numbers and lerps away from them, and a constant
## that lives only at its call site cannot be lerped away from.
const FOG_BEGIN := 220.0
const FOG_END := 2600.0
const FOG_CURVE := 1.35
const FOG_SKY_AFFECT := 0.18
const SATURATION := 1.12

## Under the surface.
##
## Water is not air with a tint on it: it is a different medium, and what says
## so is how little of it you can see through. The whole valley has to go, and
## what is left is a green room a few metres across with a bright ceiling —
## which is exactly what being underwater in a river looks like, and is also
## the cheapest possible thing to draw.
const UNDER_FOG := Color(0.09, 0.30, 0.34)
const UNDER_FOG_BEGIN := 0.4
## How far you can see just under the surface, and at the bottom of the
## deepest place in the valley. Water carries less light the further down you
## are, and a dive that looks the same at four metres as at half a one is a
## dive with nothing to find at the bottom of it.
const UNDER_SEES_SHALLOW := 34.0
const UNDER_SEES_DEEP := 11.0
## Over how many metres of depth the light goes, and over how many the tint
## arrives at all. The second is short: the change belongs at the surface, at
## the moment the head goes under, or a child cannot tell whether they are in
## or out.
const UNDER_GOES_DARK_OVER := 7.0
const UNDER_ARRIVES_OVER := 0.5
## How quickly the eye adjusts crossing the surface. Fast, but not a cut.
const UNDER_SETTLE := 7.0

## How far under the surface the camera is, eased, and how deep it has gone.
var _under := 0.0
var _deep := 0.0
## What the sky last asked for, before the water had its say.
var _fog_in_air := Color(0.80, 0.87, 0.93)
var _ambient_in_air := 0.55

## Colour of the sunlight across a day, sampled by sun height.
var _sun_colors := [
	Color(0.99, 0.62, 0.36),  # horizon: low, warm, raking
	Color(1.00, 0.88, 0.72),  # morning
	Color(1.00, 0.97, 0.92),  # noon: near white
]

func _init() -> void:
	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.sky_energy_multiplier = 1.0
	_sky_material.ground_bottom_color = Color(0.24, 0.28, 0.24)
	_sky_material.ground_horizon_color = Color(0.72, 0.80, 0.84)
	_sky_material.sun_angle_max = 12.0
	_sky_material.sun_curve = 0.12

	var sky := Sky.new()
	sky.sky_material = _sky_material
	# The ambient light in this valley comes entirely from the sky (see the
	# ambient settings below), which means every change to the sky material
	# makes the engine re-render a radiance cubemap. At the default size that
	# is a real cost on a phone for a sky that is a smooth gradient with no
	# detail in it to lose.
	sky.radiance_size = Sky.RADIANCE_SIZE_64

	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	# Ambient straight from the sky keeps shadows blue rather than black, which
	# is the single biggest difference between "stylised" and "cheap".
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_environment.ambient_light_sky_contribution = 1.0
	# Sky ambient is bright by itself; at full energy it doubles up with the sun
	# and the meadow blows out to white before the tonemapper sees it.
	_environment.ambient_light_energy = 0.55

	# Distance fog tinted to the sky is what makes the mountains read as far away
	# instead of as a wall standing right behind the trees.
	_environment.fog_enabled = true
	_environment.fog_mode = Environment.FOG_MODE_DEPTH
	# The far country reaches two kilometres now, so the air has to as well:
	# fog that ended at 1,600 m turned the mountains behind it into a flat
	# wall of sky colour, which is what "you can see a band of water and then
	# nothing" looked like from a hilltop.
	_environment.fog_depth_begin = FOG_BEGIN
	_environment.fog_depth_end = FOG_END
	_environment.fog_depth_curve = FOG_CURVE
	_environment.fog_density = 1.0
	# A little fog on the sky as well, or the fogged terrain meets an unfogged
	# horizon and the join reads as a hard band across the view.
	_environment.fog_sky_affect = FOG_SKY_AFFECT

	# AGX holds highlights together in a bright outdoor scene, where ACES at this
	# exposure clipped a sunlit meadow to flat white.
	_environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	_environment.tonemap_white = 1.0
	_environment.tonemap_exposure = 1.1

	_environment.glow_enabled = true
	_environment.glow_intensity = 0.16
	_environment.glow_bloom = 0.03
	_environment.glow_hdr_threshold = 1.3

	_environment.adjustment_enabled = true
	_environment.adjustment_saturation = SATURATION
	_environment.adjustment_contrast = 1.04

	# The sun is turned by hand in _process, like everything else this project
	# animates itself, so it opts out of the engine's physics interpolation for
	# the same reason they all do: interpolation resamples it at the physics
	# tick and draws it a tick late, which is the wrong treatment for a node
	# nothing in the physics world is moving.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

	var holder := WorldEnvironment.new()
	holder.environment = _environment
	add_child(holder)

	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_sun.directional_shadow_max_distance = 260.0
	_sun.directional_shadow_split_1 = 0.06
	_sun.directional_shadow_split_2 = 0.16
	_sun.directional_shadow_split_3 = 0.42
	# Normal bias fights shadow acne on the terrain's long, shallow slopes,
	# where a plain depth bias would detach shadows from their casters instead.
	_sun.shadow_normal_bias = 1.4
	_sun.shadow_bias = 0.04
	_sun.shadow_blur = 1.1
	add_child(_sun)

	_apply_time()

## How much the day must move before the sky is redrawn.
##
## Writing to the sky material dirties the sky, and with ambient light coming
## from the sky that means re-rendering a radiance cubemap — which was happening
## every single frame, 120 times a second on the phone this is played on, for a
## day that takes twenty minutes to go round. A fiftieth of a second of daylight
## is far below anything an eye can catch, and it turns that into about ten
## redraws a second.
const SKY_STEP := 1.0 / (DAY_LENGTH * 10.0)

var _drawn_at := -1.0

func _process(delta: float) -> void:
	time_of_day = fposmod(time_of_day + delta / DAY_LENGTH, 1.0)
	# Crossing midnight takes the difference to nearly a whole day rather than
	# to nearly nothing, so the wrap redraws rather than sticking.
	if absf(time_of_day - _drawn_at) < SKY_STEP:
		return
	_drawn_at = time_of_day
	_apply_time()

func _apply_time() -> void:
	# 0.0 is midnight, 0.5 is noon.
	var sun_angle := (time_of_day - 0.25) * TAU
	var height := sin(sun_angle)

	_sun.rotation = Vector3(-asin(clampf(height, -1.0, 1.0)), deg_to_rad(-38.0) + sun_angle * 0.35, 0.0)

	var day := clampf(height, 0.0, 1.0)
	_sun.light_energy = lerpf(0.0, 1.05, smoothstep(-0.05, 0.30, height))
	_sun.light_color = _sun_color(day)

	# Dusk is the sun low but still up; night is the sun gone. They were one
	# value before, which left the valley in a permanent orange twilight that
	# never actually got dark — and a lantern nobody needs is a lantern nobody
	# buys.
	var dusk := 1.0 - smoothstep(0.0, 0.35, height)
	var night := smoothstep(0.02, -0.20, height)

	var sky_top := Color(0.20, 0.42, 0.78).lerp(Color(0.30, 0.24, 0.44), dusk)
	var sky_horizon := Color(0.79, 0.89, 0.97).lerp(Color(0.96, 0.55, 0.36), dusk)
	# Deep blue rather than black: a child should be able to make out the shape
	# of the valley at night, just not what is lying in the grass.
	_sky_material.sky_top_color = sky_top.lerp(Color(0.045, 0.062, 0.135), night)
	_sky_material.sky_horizon_color = sky_horizon.lerp(Color(0.115, 0.145, 0.235), night)
	_sky_material.sun_angle_max = lerpf(12.0, 30.0, dusk)

	_fog_in_air = _sky_material.sky_horizon_color.lerp(
		Color(0.86, 0.91, 0.96).lerp(Color(0.10, 0.13, 0.22), night), 0.35
	)
	# Night was 0.045, judged on a laptop in a lit room. On the tablet it is
	# very nearly black: a child cannot see the ground, the animals are dark
	# smudges, and the valley they are meant to be exploring is gone. Raised
	# until the shape of the land reads without the lantern, which is the point
	# — the lantern shows you what is in the grass, not where the hills are.
	_ambient_in_air = lerpf(0.55, 0.20, night) if night > 0.0 else lerpf(
		0.12, 0.55, smoothstep(-0.15, 0.25, height)
	)
	# The sky has had its say; the water gets the last word, because what is
	# between the eye and everything else wins over what is lighting it.
	_apply_water()

	# The moon stands in for the sun once it is down, so shadows do not vanish
	# entirely and the ground keeps its shape.
	if night > 0.0:
		_sun.light_energy = lerpf(_sun.light_energy, 0.26, night)
		_sun.light_color = _sun.light_color.lerp(Color(0.62, 0.72, 1.0), night)
		_sun.rotation = Vector3(
			-asin(clampf(-height, -1.0, 1.0)),
			deg_to_rad(-38.0) + sun_angle * 0.35,
			0.0
		)

## The camera is `depth` metres under the surface — zero when it is in the air.
## Called every frame by the game, and eased here rather than at the call site
## because what is being smoothed is the eye adjusting, which is this node's
## business and nobody else's.
func go_under(depth: float, delta: float) -> void:
	var wanted := clampf(depth / UNDER_ARRIVES_OVER, 0.0, 1.0)
	var wanted_deep := clampf(depth / UNDER_GOES_DARK_OVER, 0.0, 1.0)
	var settled := absf(_under - wanted) < 0.001 and absf(_deep - wanted_deep) < 0.001
	if settled and _under <= 0.0:
		# Out of the water and already drawn that way: nothing to write, and
		# this runs every frame of every game that never goes near the river.
		return
	var weight := 1.0 - exp(-UNDER_SETTLE * delta)
	_under = lerpf(_under, wanted, weight)
	_deep = lerpf(_deep, wanted_deep, weight)
	if _under < 0.001 and wanted <= 0.0:
		_under = 0.0
		_deep = 0.0
	_apply_water()

## How far under the surface the view is being drawn, from 0 to 1. Read by the
## water sheet, which has to know which of its two faces to draw.
func under_water() -> float:
	return _under

## The air as the sky left it, bent towards the water by however much of the
## water is in the way.
func _apply_water() -> void:
	_environment.fog_light_color = _fog_in_air.lerp(UNDER_FOG, _under)
	_environment.fog_depth_begin = lerpf(FOG_BEGIN, UNDER_FOG_BEGIN, _under)
	_environment.fog_depth_end = lerpf(
		FOG_END, lerpf(UNDER_SEES_SHALLOW, UNDER_SEES_DEEP, _deep), _under
	)
	_environment.fog_depth_curve = lerpf(FOG_CURVE, 1.0, _under)
	# All the way, underwater: the sky is not a thing you can see from down
	# here, and leaving it unfogged puts a window of open blue overhead.
	_environment.fog_sky_affect = lerpf(FOG_SKY_AFFECT, 1.0, _under)
	_environment.ambient_light_energy = _ambient_in_air * lerpf(
		1.0, lerpf(0.8, 0.4, _deep), _under
	)
	_environment.adjustment_saturation = lerpf(SATURATION, 0.88, _under)

## How far into the evening it is, from 0 in daylight to 1 once the sun is
## well down. Earlier than `darkness`: street lamps come on at sunset, while
## the sky is still light, and a child watching the lamps as it got dark
## saw them stay off until it was properly night. Read by the lamps.
func evening() -> float:
	var height := sin((time_of_day - 0.25) * TAU)
	return smoothstep(0.14, -0.06, height)

## How dark it is right now, from 0 in daylight to 1 at midnight. Read by the
## lantern, which is the only thing that needs to know.
func darkness() -> float:
	var height := sin((time_of_day - 0.25) * TAU)
	return smoothstep(0.02, -0.20, height)

func _sun_color(day: float) -> Color:
	if day < 0.5:
		return _sun_colors[0].lerp(_sun_colors[1], day * 2.0)
	return _sun_colors[1].lerp(_sun_colors[2], (day - 0.5) * 2.0)

## Jump straight to a moment in the day. Used by the screenshot tool so a look
## can be judged at a chosen hour instead of whenever the capture happened to run.
func set_time(fraction: float) -> void:
	time_of_day = fposmod(fraction, 1.0)
	_drawn_at = time_of_day
	_apply_time()
