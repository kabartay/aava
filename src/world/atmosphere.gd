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

## Colour of the sunlight across a day, sampled by sun height.
var _sun_colors := [
	Color(0.99, 0.62, 0.36),  # horizon: low, warm, raking
	Color(1.00, 0.88, 0.72),  # morning
	Color(1.00, 0.97, 0.92),  # noon: near white
]

func _ready() -> void:
	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.sky_energy_multiplier = 1.0
	_sky_material.ground_bottom_color = Color(0.24, 0.28, 0.24)
	_sky_material.ground_horizon_color = Color(0.72, 0.80, 0.84)
	_sky_material.sun_angle_max = 12.0
	_sky_material.sun_curve = 0.12

	var sky := Sky.new()
	sky.sky_material = _sky_material

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
	_environment.fog_depth_begin = 140.0
	_environment.fog_depth_end = 1600.0
	_environment.fog_depth_curve = 1.35
	_environment.fog_density = 1.0
	# A little fog on the sky as well, or the fogged terrain meets an unfogged
	# horizon and the join reads as a hard band across the view.
	_environment.fog_sky_affect = 0.18

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
	_environment.adjustment_saturation = 1.12
	_environment.adjustment_contrast = 1.04

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

func _process(delta: float) -> void:
	time_of_day = fposmod(time_of_day + delta / DAY_LENGTH, 1.0)
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
	_sky_material.sky_top_color = sky_top.lerp(Color(0.017, 0.024, 0.062), night)
	_sky_material.sky_horizon_color = sky_horizon.lerp(Color(0.055, 0.070, 0.130), night)
	_sky_material.sun_angle_max = lerpf(12.0, 30.0, dusk)

	_environment.fog_light_color = _sky_material.sky_horizon_color.lerp(
		Color(0.86, 0.91, 0.96).lerp(Color(0.10, 0.13, 0.22), night), 0.35
	)
	_environment.ambient_light_energy = lerpf(0.55, 0.045, night) if night > 0.0 else lerpf(
		0.12, 0.55, smoothstep(-0.15, 0.25, height)
	)

	# The moon stands in for the sun once it is down, so shadows do not vanish
	# entirely and the ground keeps its shape.
	if night > 0.0:
		_sun.light_energy = lerpf(_sun.light_energy, 0.075, night)
		_sun.light_color = _sun.light_color.lerp(Color(0.62, 0.72, 1.0), night)
		_sun.rotation = Vector3(
			-asin(clampf(-height, -1.0, 1.0)),
			deg_to_rad(-38.0) + sun_angle * 0.35,
			0.0
		)

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
	_apply_time()
