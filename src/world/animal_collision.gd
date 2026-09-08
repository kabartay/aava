class_name AnimalCollision
extends Node3D

## Animals you cannot walk through.
##
## The animals are drawn nodes and nothing else: a child walked straight
## through the dog, which from the phone read as the dog not being there. The
## same answer as the forest's — see `tree_collision.gd` — for the same
## reason: a body each for every animal in the valley would cost more than it
## is worth, and a child can only bump into what is within a few paces. A
## handful of bodies follow whichever animals are nearest.
##
## They follow every frame rather than every few metres, because unlike a
## tree an animal walks away on its own.

## How far out an animal is made solid, and how many can be at once.
const REACH := 12.0
const BODIES := 6

## How much of an animal's own size the body is: a little under, so a child
## stops against the animal rather than a stride short of it.
const GIRTH := 0.85

## Where bodies wait when there is nothing near to be. Far under the world.
const PARKED := Vector3(0.0, -10000.0, 0.0)

var animals: Animals

var _bodies: Array[StaticBody3D] = []
var _shapes: Array[CapsuleShape3D] = []
var _following := Vector3(1e9, 1e9, 1e9)
var _solid := 0

func _init(living: Animals) -> void:
	name = "AnimalCollision"
	animals = living
	# Built here rather than in _ready, for the usual reason: a headless check
	# uses this without ever starting the scene tree. See LESSONS.md.
	for _i in BODIES:
		var shape := CapsuleShape3D.new()
		shape.radius = 0.4
		shape.height = 1.0
		var collider := CollisionShape3D.new()
		collider.shape = shape
		var body := StaticBody3D.new()
		body.add_child(collider)
		body.position = PARKED
		body.collision_layer = TerrainSpec.LAYER_PROPS
		add_child(body)
		_bodies.append(body)
		_shapes.append(shape)

## Where the child is. Stored rather than acted on, so the bodies can keep up
## with animals that move while the child stands still.
func follow(world_position: Vector3) -> void:
	_following = world_position

func _process(_delta: float) -> void:
	if animals == null or not is_instance_valid(animals):
		return
	if _following.y < -1000.0:
		return
	set_animals(animals.living_near(_following, REACH))

## Lend the bodies to these animals, nearest first. Separated from `_process`
## so a check can hand it a list without a world.
func set_animals(near: Array[Dictionary]) -> void:
	var listener := _following
	near.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _where(a).distance_squared_to(listener) < _where(b).distance_squared_to(listener))
	_solid = 0
	for i in _bodies.size():
		if i >= near.size():
			_bodies[i].position = PARKED
			continue
		var animal: Dictionary = near[i]
		var scale := AnimalKinds.size_of(animal["kind"])
		# A capsule stands along its own Y, which is what an animal's body is
		# not — but at this size a child feels a lump, not a shape, and a
		# capsule never catches on its own ends the way a box does.
		_shapes[i].radius = scale * 0.62 * GIRTH
		_shapes[i].height = maxf(scale * 1.9 * GIRTH, _shapes[i].radius * 2.0 + 0.05)
		var at := _where(animal)
		_bodies[i].position = at + Vector3(0.0, _shapes[i].height * 0.5, 0.0)
		_solid += 1

## How many animals are solid right now. Read by the checks.
func solid_count() -> int:
	return _solid

static func _where(animal: Dictionary) -> Vector3:
	var node = animal.get("node")
	if node == null or not is_instance_valid(node):
		return PARKED
	return (node as Node3D).global_position
