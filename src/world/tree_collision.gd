class_name TreeCollision
extends Node3D

## Trunks you cannot walk through.
##
## The forest was drawn entirely as `MultiMeshInstance3D` — thousands of trees
## in a handful of draw calls, which is the only way a tablet can show a wood at
## all — and a MultiMesh has no collision. So the forest was scenery: a child
## walked through every trunk in it, which was reported from the phone as soon
## as anyone actually walked into a tree.
##
## Giving each of several thousand trees a `StaticBody3D` is not an option; it
## would cost more than the rest of the frame. But a child can only ever bump
## into what is within arm's reach, so this keeps a small pool of trunk-shaped
## colliders and moves them to whichever trees are nearest. Twenty bodies stand
## in for a forest, and from inside it the difference cannot be told.

## How far out trunks are made solid. Comfortably past where a child can get in
## one frame at a run, so a tree never becomes solid in their face.
const REACH := 14.0

## How many trunks can be solid at once. Even in thick forest, twenty is more
## than fits inside REACH.
const BODIES := 20

## How far the player must move before the pool is reshuffled. Every frame is
## wasteful and jumpy; this is a couple of paces.
const REFRESH_STEP := 1.5

## A trunk is drawn about a quarter of a metre across and this is a little
## wider, because being stopped slightly short of a tree reads as the tree
## being solid, while clipping into the bark before stopping reads as a bug.
const TRUNK_RADIUS := 0.34

## How tall the collider is. Only has to cover a child, and a shorter cylinder
## is a cheaper one.
const TRUNK_HEIGHT := 4.0

## Where the pool parks bodies it is not using. Far under the world, where
## nothing can reach them — cheaper than adding and removing them from the tree
## every time the player takes two steps.
const PARKED := Vector3(0.0, -10000.0, 0.0)

var vegetation: Vegetation

var _bodies: Array[StaticBody3D] = []
var _last_refresh := Vector3(1e9, 1e9, 1e9)

func _init(forest: Vegetation) -> void:
	name = "TreeCollision"
	vegetation = forest

	# Built here rather than in _ready for the usual reason: a headless check
	# uses this without ever starting the scene tree.
	var shape := CylinderShape3D.new()
	shape.radius = TRUNK_RADIUS
	shape.height = TRUNK_HEIGHT

	for _i in BODIES:
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		# One shape resource shared by every body: they are all the same
		# cylinder, and a copy each would be twenty times the memory for no
		# difference anyone can walk into.
		collider.shape = shape
		collider.position = Vector3(0.0, TRUNK_HEIGHT * 0.5, 0.0)
		body.add_child(collider)
		body.position = PARKED
		body.collision_layer = TerrainSpec.LAYER_PROPS
		add_child(body)
		_bodies.append(body)

## Put the solid trunks where the player is. Called with the player's position,
## like everything else that streams.
func follow(world_position: Vector3) -> void:
	if world_position.distance_to(_last_refresh) < REFRESH_STEP:
		return
	_last_refresh = world_position
	set_trunks(vegetation.trees_near(world_position, REACH))

## The trunks to stand in for, nearest first. Separated from `follow` so a
## check can hand it a list without building a forest.
func set_trunks(trunks: Array[Vector3]) -> void:
	for i in _bodies.size():
		if i < trunks.size():
			_bodies[i].position = trunks[i]
		else:
			_bodies[i].position = PARKED

## How many trunks are solid right now. Read by the checks.
func solid_count() -> int:
	var count := 0
	for body in _bodies:
		if body.position.y > PARKED.y * 0.5:
			count += 1
	return count
