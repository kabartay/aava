class_name Flag
extends Node3D

## A flag, pennant or vane that flies the valley's wind.
##
## The flags on the pirate ship and the shop roof were boxes baked into the
## static mesh, each frozen at an angle somebody chose, so on a day when every
## tree was leaning north-east they pointed wherever the modeller had. This is
## a small node that turns its pieces to Wind.direction and ripples them with
## Wind.strength. Its local +x is the free end: the flag lies along it from the
## pole, so turning the node is all it takes to point it.

## Offsets the ripple, so two flags in sight are not in step.
var _phase := 0.0

func _ready() -> void:
	_phase = fmod(absf(global_position.x) * 1.7 + absf(global_position.z) * 2.3, TAU)
	fly(Wind.clock())

## Add one rectangle of cloth, `size` long along +x from the pole (so the pole
## is at its root); `splay` turns it about z and `lift` raises it.
func add_cloth(size: Vector3, colour: Color, splay := 0.0, lift := 0.0) -> void:
	var piece := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	piece.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.8
	piece.material_override = material
	piece.transform = Transform3D(Basis(Vector3.BACK, splay), Vector3(size.x * 0.5 * cos(splay), lift, 0.0))
	add_child(piece)

func _process(_delta: float) -> void:
	if is_visible_in_tree():
		fly(Wind.clock())

## Where the flag is at time `t`: yawed to the wind's direction (in the world,
## whatever the parent is doing), drooping in a calm and streaming level in a
## blow, with a ripple that grows with the strength.
func fly(t: float) -> void:
	var s := Wind.strength(t)
	# The strength changes the size of the ripple, never its rate: a rate that
	# followed it would be multiplied by the clock, and wind-up flags would
	# whirr after the game had been open a while.
	var flutter := (0.6 * sin(t * 3.1 + _phase) + 0.4 * sin(t * 5.3 + _phase * 2.0)) * (0.05 + 0.25 * s)
	var droop := (1.0 - s) * 0.6
	var turned := Basis(Vector3.UP, -Wind.angle(t) + flutter) * Basis(Vector3.BACK, -droop)
	if is_inside_tree():
		global_basis = turned
	else:
		basis = turned

## Which way the free end points in the ground plane, for the checks.
func free_end() -> Vector2:
	var along := (global_basis if is_inside_tree() else basis) * Vector3.RIGHT
	return Vector2(along.x, along.z).normalized()
