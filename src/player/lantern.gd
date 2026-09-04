class_name Lantern
extends Node3D

## The light a child carries at night.
##
## It exists because night now genuinely gets dark, and a valley you cannot
## read is a valley you leave. The lantern does not make night into day — it
## makes a circle of night into day, which is the whole appeal: what is just
## outside the circle is worth walking towards.
##
## Lit automatically rather than by a button. A six-year-old in the dark should
## not have to work out which control turns the light on, and there is no
## interesting decision in "would you like to see?".

## How far the light reaches, and how bright at the centre. Generous enough to
## walk by, small enough that the valley still feels large in the dark.
const RANGE := 15.0
const ENERGY := 3.4

## Warm, like something burning. A white light reads as a torch from a hardware
## shop rather than as a lantern.
const COLOUR := Color(1.0, 0.86, 0.56)

## Seconds to fade in and out. Snapping a light on is a flicker of the whole
## screen; easing it reads as a flame catching.
const FADE := 1.6

## Below this much darkness the lantern is not worth lighting.
const THRESHOLD := 0.22

var owned := false

var _light: OmniLight3D
var _glass: MeshInstance3D
var _lit := 0.0

func _init() -> void:
	# Built here rather than in _ready: the game sets `owned` and asks about the
	# light on the same frame it creates this. See LESSONS.md.
	_light = OmniLight3D.new()
	_light.omni_range = RANGE
	_light.light_color = COLOUR
	_light.light_energy = 0.0
	# No shadows. A single moving point light casting shadows through five
	# thousand grass instances costs more than the rest of the frame put
	# together, and buys nothing a child would notice.
	_light.shadow_enabled = false
	_light.position = Vector3(0.0, 1.1, 0.0)
	add_child(_light)

	# The lamp itself, so the light has a visible source rather than emanating
	# from the child's chest.
	var body := SphereMesh.new()
	body.radius = 0.11
	body.height = 0.26
	body.radial_segments = 8
	body.rings = 5
	var glow := StandardMaterial3D.new()
	glow.albedo_color = COLOUR
	glow.emission_enabled = true
	glow.emission = COLOUR
	glow.emission_energy_multiplier = 2.2
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_glass = MeshInstance3D.new()
	_glass.mesh = body
	_glass.material_override = glow
	_glass.position = Vector3(0.26, 0.95, 0.0)
	_glass.visible = false
	add_child(_glass)

## Called every frame with how dark it is. The lantern decides for itself.
func follow(darkness: float, delta: float) -> void:
	var want := 1.0 if owned and darkness > THRESHOLD else 0.0
	_lit = move_toward(_lit, want, delta / FADE)
	# Eased against the darkness as well as the fade, so the light comes up as
	# dusk falls rather than switching on at a threshold.
	var strength := _lit * smoothstep(THRESHOLD, 0.6, darkness)
	_light.light_energy = ENERGY * strength
	_glass.visible = strength > 0.02
	if _glass.visible:
		# A slight flicker, because a steady point of light reads as electric.
		var flicker := 1.0 + sin(float(Time.get_ticks_msec()) * 0.006) * 0.05
		_light.light_energy *= flicker

func is_lit() -> bool:
	return _light.light_energy > 0.01
