class_name KickPreview
extends Node3D

## A dotted line from the ball to where it will land or stop, shown whenever a
## ball is at the child's feet and while the kick button is held.
##
## Which way a kick went, and how far, was the question asked most from the
## phone: the kick goes the way the child faces, turned and lifted by the slide
## of the finger on the kick button, and a child cannot see that before the
## foot moves. Games answer this with a trajectory line, and this
## is that — dotted, so it reads as a hint and not as a ruler.
##
## The dots are one MultiMesh, placed by the game from `Ball.predict`, which
## is the ball's own arithmetic; the arc cannot disagree with the kick.

const MAX_DOTS := 40
## Small and a little translucent: the dots are a hint laid on the grass, not
## a thing to look at. The owner found the first, bigger ones, and the ring and
## arrow that came with them, too noticeable; the dots alone say enough.
const DOT_RADIUS := 0.07
const COLOUR := Color(1.0, 1.0, 1.0, 0.62)
## The dots turn this green when the ball is going into a goal mouth, between
## the posts and under the bar. A bright lime, because the pitch it is drawn
## over is itself green and a plain green vanishes into it.
const ON_TARGET := Color(0.55, 1.0, 0.25, 0.75)

var _dots: MultiMeshInstance3D
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

	hide_path()

## Lay the dots along `points`, fading towards the far end so the eye reads
## a direction rather than a fence. `on_target` turns them green. There is no
## ring where the path ends: the last dot is where it comes down.
func show_path(points: PackedVector3Array, on_target := false) -> void:
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

func hide_path() -> void:
	for i in MAX_DOTS:
		_park(i)
	_shown = 0
	_on_target = false
	_dots.visible = false

## Whether the path on show is going into a goal mouth. For the checks.
func is_on_target() -> bool:
	return _on_target

## How many dots are on show. For the checks.
func dots_shown() -> int:
	return _shown

func _park(i: int) -> void:
	_dots.multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.001), Vector3(0.0, -10000.0, 0.0)))
	_dots.multimesh.set_instance_color(i, Color(0.0, 0.0, 0.0, 0.0))
