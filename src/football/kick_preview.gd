class_name KickPreview
extends Node3D

## A faint dotted arc in the air from the ball to where it will land, shown
## while the kick button is held.
##
## Which way a kick went, and how far, was the question asked most from the
## phone: the kick goes along the striker-to-ball line and the loft follows
## the camera, both of which are right and neither of which a child can see
## before the foot moves. Games answer this with a trajectory line, and this
## is that — kept faint and dotted so it reads as a hint and not as a ruler.
##
## The dots are one MultiMesh, placed by the game from `Ball.predict`, which
## is the ball's own arithmetic; the arc cannot disagree with the kick.

const MAX_DOTS := 40
const DOT_RADIUS := 0.065
const COLOUR := Color(1.0, 1.0, 1.0, 0.5)

var _dots: MultiMeshInstance3D
var _shown := 0

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
## a direction rather than a fence.
func show_path(points: PackedVector3Array) -> void:
	var multi := _dots.multimesh
	var count := mini(points.size(), MAX_DOTS)
	for i in MAX_DOTS:
		if i < count:
			var fade := 1.0 - 0.6 * float(i) / float(maxf(count - 1, 1))
			multi.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * (0.7 + 0.3 * fade)), points[i]))
			multi.set_instance_color(i, Color(COLOUR.r, COLOUR.g, COLOUR.b, COLOUR.a * fade))
		else:
			_park(i)
	_shown = count
	_dots.visible = count > 0

func hide_path() -> void:
	for i in MAX_DOTS:
		_park(i)
	_shown = 0
	_dots.visible = false

## How many dots are on show. For the checks.
func dots_shown() -> int:
	return _shown

func _park(i: int) -> void:
	_dots.multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.001), Vector3(0.0, -10000.0, 0.0)))
	_dots.multimesh.set_instance_color(i, Color(0.0, 0.0, 0.0, 0.0))
