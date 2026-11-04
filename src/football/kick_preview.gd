class_name KickPreview
extends Node3D

## A dotted line from the ball to where it will land or stop, shown whenever a
## ball is at the child's feet and while the kick button is held.
##
## Which way a kick went, and how far, was the question asked most from the
## phone: the kick goes along the striker-to-ball line and the loft follows
## the camera, both of which are right and neither of which a child can see
## before the foot moves. Games answer this with a trajectory line, and this
## is that — dotted, so it reads as a hint and not as a ruler.
##
## The dots are one MultiMesh, placed by the game from `Ball.predict`, which
## is the ball's own arithmetic; the arc cannot disagree with the kick.

const MAX_DOTS := 40
## Big and bright enough to read from the run-up on a phone screen: a dot a
## child can see is worth more than a faint one that is accurate.
const DOT_RADIUS := 0.12
const COLOUR := Color(1.0, 1.0, 1.0, 0.8)
## The arc and the ring turn this green when the ball is going into a goal
## mouth, between the posts and under the bar. A little stronger than the
## white, because it is the one thing in the picture worth noticing.
## A bright lime, because the pitch it is drawn over is itself green and a
## plain green vanishes into it.
const ON_TARGET := Color(0.55, 1.0, 0.25, 0.85)

## The ring where the ball will come down: wide enough to see from the run-up,
## thin enough not to be a target painted on the grass.
const RING_INNER := 0.50
const RING_OUTER := 0.70

var _dots: MultiMeshInstance3D
var _ring: MeshInstance3D
var _ring_material: StandardMaterial3D
var _shown := 0
var _on_target := false

func _init() -> void:
	name = "KickPreview"
	var ball := SphereMesh.new()
	ball.radius = DOT_RADIUS
	ball.height = DOT_RADIUS * 2.0
	ball.radial_segments = 6
	ball.rings = 3
	var material := StandardMaterial3D.new()
	material.albedo_color = COLOUR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	ball.material = material

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	# Set before instance_count, or it is ignored — see LESSONS.md.
	multi.use_colors = true
	multi.instance_count = MAX_DOTS
	multi.mesh = ball
	_dots = MultiMeshInstance3D.new()
	_dots.multimesh = multi
	_dots.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_dots)

	var torus := TorusMesh.new()
	torus.inner_radius = RING_INNER
	torus.outer_radius = RING_OUTER
	torus.rings = 24
	torus.ring_segments = 4
	# Squashed flat by the instance, below: a ring lying on the grass, not a
	# tyre standing on it.
	_ring_material = StandardMaterial3D.new()
	_ring_material.albedo_color = COLOUR
	_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	torus.material = _ring_material
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.scale = Vector3(1.0, 0.25, 1.0)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	hide_path()

## Lay the dots along `points`, fading towards the far end so the eye reads
## a direction rather than a fence, and put the ring where the path ends: on
## the ground below the last dot, at height `ring_y` if the caller knows the
## grass there. `on_target` turns arc and ring green.
func show_path(points: PackedVector3Array, on_target := false, ring_y := NAN) -> void:
	var multi := _dots.multimesh
	var count := mini(points.size(), MAX_DOTS)
	var tint := ON_TARGET if on_target else COLOUR
	for i in MAX_DOTS:
		if i < count:
			var fade := 1.0 - 0.4 * float(i) / float(maxf(count - 1, 1))
			multi.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * (0.7 + 0.3 * fade)), points[i]))
			multi.set_instance_color(i, Color(tint.r, tint.g, tint.b, tint.a * fade))
		else:
			_park(i)
	_shown = count
	_on_target = on_target and count > 0
	_dots.visible = count > 0
	_ring_material.albedo_color = tint
	_ring.visible = count > 0
	if count > 0:
		var end := points[points.size() - 1]
		# A hair above the grass, so it is not swallowed by it.
		_ring.position = Vector3(end.x, (end.y if is_nan(ring_y) else ring_y) + 0.04, end.z)

func hide_path() -> void:
	for i in MAX_DOTS:
		_park(i)
	_shown = 0
	_on_target = false
	_dots.visible = false
	_ring.visible = false

## Whether the path on show is going into a goal mouth. For the checks.
func is_on_target() -> bool:
	return _on_target

## Where the ring is, for the checks.
func ring_position() -> Vector3:
	return _ring.position

## How many dots are on show. For the checks.
func dots_shown() -> int:
	return _shown

func _park(i: int) -> void:
	_dots.multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.001), Vector3(0.0, -10000.0, 0.0)))
	_dots.multimesh.set_instance_color(i, Color(0.0, 0.0, 0.0, 0.0))
