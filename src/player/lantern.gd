class_name Lantern
extends Node3D

## The light a child carries at night.
##
## It exists because night now genuinely gets dark, and a valley you cannot
## read is a valley you leave. The lantern does not make night into day — it
## makes a circle of night into day, which is the whole appeal: what is just
## outside the circle is worth walking towards.
##
## It lights itself at dusk, and there is a switch. Lighting itself is right —
## a six-year-old in the dark should not have to work out which control turns
## the light on — but a lamp you cannot put out is not a lamp you own, and
## being able to turn it off is most of what makes carrying one feel like
## carrying something. Switched off it stays off until it is switched on again,
## whatever the hour.

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

## The metal it is built out of: the lid, the base, the uprights and the bail.
## Bronze rather than grey steel: the light in it is warm, and cold metal round
## a warm flame reads as a camping lamp from a supermarket.
const METAL := Color(0.38, 0.29, 0.17)

## The flame inside the glass, which is brighter and yellower than the glass
## itself. A lantern lit evenly all through is a bulb; a lantern with a bright
## point in a softer body is a flame in a case.
const FLAME := Color(1.0, 0.95, 0.72)

## Where it hangs: out at the child's side and below the shoulder, in a hand,
## rather than up beside the face. It is carried on the body itself, so it
## swings round as the child turns and goes down with them into the water —
## parented to the character body instead, it stayed at standing height while
## the swimmer sank, and a lit ball hanging beside a half-submerged head is the
## bug that sent us looking.
const HELD_AT := Vector3(0.32, 0.80, -0.06)

## Below this much darkness the lantern is not worth lighting.
const THRESHOLD := 0.22

var owned := false

## Whether the switch is on. It is, to begin with, so a child who buys a
## lantern and walks into the night gets a lantern.
var switched_on := true

var _light: OmniLight3D
var _lamp: Node3D
var _glass: MeshInstance3D
var _flame: MeshInstance3D
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
	add_child(_light)

	# The lamp itself. It was a glowing ball floating beside the child's ear,
	# which at night — swimming, with the body low in the water and the ball
	# staying where it was — read as a face coming off. So it is built like a
	# lantern: a glass body between a lid and a base, with a bail over the top
	# and a ring to hang it from, and it is carried in the hand.
	_lamp = Node3D.new()
	_lamp.visible = false
	add_child(_lamp)

	# The glass is half see-through and glows gently; the flame inside it does
	# the bright work. That is the whole trick of making a lamp look like a lamp
	# rather than a lit marble.
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(COLOUR.r, COLOUR.g, COLOUR.b, 0.55)
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.emission_enabled = true
	glow.emission = COLOUR
	glow.emission_energy_multiplier = 1.5
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var metal := StandardMaterial3D.new()
	metal.albedo_color = METAL
	metal.roughness = 0.42
	metal.metallic = 0.7

	# The glass: a squat barrel, the lit part and the only part that carries
	# any distance at night.
	var glass := CylinderMesh.new()
	glass.top_radius = 0.085
	glass.bottom_radius = 0.095
	glass.height = 0.20
	glass.radial_segments = 10
	glass.rings = 1
	_glass = MeshInstance3D.new()
	_glass.mesh = glass
	_glass.material_override = glow
	_lamp.add_child(_glass)

	var flame_glow := StandardMaterial3D.new()
	flame_glow.albedo_color = FLAME
	flame_glow.emission_enabled = true
	flame_glow.emission = FLAME
	flame_glow.emission_energy_multiplier = 3.4
	flame_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var wick := SphereMesh.new()
	wick.radius = 0.035
	wick.height = 0.085
	wick.radial_segments = 8
	wick.rings = 5
	_flame = MeshInstance3D.new()
	_flame.mesh = wick
	_flame.material_override = flame_glow
	_flame.position.y = -0.02
	_lamp.add_child(_flame)

	# Lid and base, in metal, so the glass reads as being held between them.
	for cap: Array in [[0.125, 0.045, 0.105, 0.075], [-0.115, 0.035, 0.105, 0.105]]:
		var plate := CylinderMesh.new()
		plate.top_radius = float(cap[2])
		plate.bottom_radius = float(cap[3])
		plate.height = float(cap[1])
		plate.radial_segments = 10
		plate.rings = 1
		var piece := MeshInstance3D.new()
		piece.mesh = plate
		piece.material_override = metal
		piece.position.y = float(cap[0])
		_lamp.add_child(piece)

	# Three uprights round the glass, which is what a storm lantern has and
	# what stops the lit part reading as a bare bulb.
	for post in 3:
		var bar := BoxMesh.new()
		bar.size = Vector3(0.018, 0.21, 0.018)
		var upright := MeshInstance3D.new()
		upright.mesh = bar
		upright.material_override = metal
		var angle := TAU * float(post) / 3.0
		upright.position = Vector3(sin(angle) * 0.092, 0.005, cos(angle) * 0.092)
		_lamp.add_child(upright)

	# The bail: the half hoop you carry it by.
	var hoop := TorusMesh.new()
	hoop.inner_radius = 0.072
	hoop.outer_radius = 0.084
	hoop.rings = 10
	hoop.ring_segments = 6
	var bail := MeshInstance3D.new()
	bail.mesh = hoop
	bail.material_override = metal
	bail.position.y = 0.175
	bail.rotation.x = PI * 0.5
	_lamp.add_child(bail)

	# A small ring at the top of the bail — what a lantern hangs from, and the
	# detail that makes the silhouette read as one at a glance.
	var eyelet := TorusMesh.new()
	eyelet.inner_radius = 0.016
	eyelet.outer_radius = 0.028
	eyelet.rings = 8
	eyelet.ring_segments = 5
	var ring := MeshInstance3D.new()
	ring.mesh = eyelet
	ring.material_override = metal
	ring.position.y = 0.255
	_lamp.add_child(ring)

	_lamp.position = HELD_AT
	# The light sits inside the glass, so what is lit and what glows are the
	# same thing rather than two things a hand apart.
	_light.position = HELD_AT

## Called every frame with how dark it is. The lantern decides for itself.
func follow(darkness: float, delta: float) -> void:
	var want := 1.0 if owned and switched_on and darkness > THRESHOLD else 0.0
	_lit = move_toward(_lit, want, delta / FADE)
	# Eased against the darkness as well as the fade, so the light comes up as
	# dusk falls rather than switching on at a threshold.
	var strength := _lit * smoothstep(THRESHOLD, 0.6, darkness)
	_light.light_energy = ENERGY * strength
	_lamp.visible = strength > 0.02
	if _lamp.visible:
		# A slight flicker, because a steady point of light reads as electric.
		var flicker := 1.0 + sin(float(Time.get_ticks_msec()) * 0.006) * 0.05
		_light.light_energy *= flicker
		# The flame moves with the flicker too. A light that wavers over a
		# perfectly still flame is two lamps in one place.
		_flame.scale = Vector3(1.0, flicker * flicker, 1.0)

func is_lit() -> bool:
	return _light.light_energy > 0.01

## Turn it on or off. Returns what it is now, so the game can say so.
func flick() -> bool:
	switched_on = not switched_on
	return switched_on
