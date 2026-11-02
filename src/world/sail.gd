class_name Sail
extends Node3D

## A square sail that belly-fills with the valley's wind.
##
## The ship's sails were boxes baked into the hull, as stiff in a gale as in a
## calm. This is two panels hinged at the yard's ends, so that they meet in the
## middle a little proud of the line between them; how far, and on which side,
## follows Wind.strength and which way the air is crossing the sail. The sail
## lies across the node's z, with its face along x.

var _hinges: Array[Node3D] = []

## Build the sail `width` across and `height` tall, with a band of `stripe`.
func build(width: float, height: float, colour: Color, stripe: Color) -> void:
	for side: float in [1.0, -1.0]:
		var hinge := Node3D.new()
		hinge.name = "Panel%d" % int(side)
		hinge.position = Vector3(0.0, 0.0, side * width * 0.5)
		add_child(hinge)
		_hinges.append(hinge)
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var centre := Transform3D(Basis(), Vector3(0.0, 0.0, -side * width * 0.25))
		var cloth := BoxMesh.new()
		cloth.size = Vector3(0.05, height, width * 0.5)
		Park._add(tool, cloth, centre, colour)
		var band := BoxMesh.new()
		band.size = Vector3(0.06, 0.4, width * 0.5)
		Park._add(tool, band, centre, stripe)
		Park.commit(tool, hinge, "Cloth")
	fill(Wind.clock())

func _process(_delta: float) -> void:
	if is_visible_in_tree():
		fill(Wind.clock())

## How far each panel is turned at time `t`, in radians: the centre of the
## sail stands out from the line between its ends, downwind, and the sign
## eases through zero as the air comes round edge-on instead of flipping.
func belly(t: float) -> float:
	var face := (global_basis if is_inside_tree() else basis) * Vector3.RIGHT
	var across := Wind.direction(t).dot(Vector2(face.x, face.z).normalized())
	return clampf(across * 3.0, -1.0, 1.0) * (0.03 + 0.14 * Wind.strength(t))

func fill(t: float) -> void:
	if _hinges.size() < 2:
		return
	var turn := belly(t)
	# The hinge at +z carries a panel reaching towards -z, and the other the
	# reverse, so the same turn pushes them out opposite ways about y.
	_hinges[0].rotation.y = -turn
	_hinges[1].rotation.y = turn
