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
const REACH := 18.0
const BODIES := 6

## How much of an animal's own size the body is: a little under, so a child
## stops against the animal rather than a stride short of it.
const GIRTH := 0.85

## Where bodies wait when there is nothing near to be. Far under the world.
const PARKED := Vector3(0.0, -10000.0, 0.0)

var animals: Animals

var _bodies: Array[StaticBody3D] = []
var _shapes: Array[BoxShape3D] = []
var _following := Vector3(1e9, 1e9, 1e9)
var _solid := 0

func _init(living: Animals) -> void:
	name = "AnimalCollision"
	animals = living
	# Built here rather than in _ready, for the usual reason: a headless check
	# uses this without ever starting the scene tree. See LESSONS.md.
	for _i in BODIES:
		# A box, laid along the animal, rather than an upright capsule.
		#
		# A capsule stands on its own axis, which is the one direction an
		# animal's body is not: a cow two and a half metres long was stood in
		# for by a post half a metre across through her middle, so a child
		# walked through her head and her rump and met something in between.
		# It was written off at the time as "at this size a child feels a lump
		# rather than a shape", which is true of a cat and not of a cow.
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.6, 0.6, 1.2)
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
		var size := AnimalKinds.body_size(animal["kind"]) * GIRTH
		_shapes[i].size = size
		var at := _where(animal)
		# Laid along the animal, so a cow is solid from her nose to her tail
		# and not only where her middle is.
		_bodies[i].position = at + Vector3(0.0, size.y * 0.5 + _stands(animal), 0.0)
		_bodies[i].rotation = Vector3(0.0, _facing(animal), 0.0)
		_solid += 1

## How high an animal's body sits off the ground: the length of its legs.
static func _stands(animal: Dictionary) -> float:
	var kind: StringName = animal["kind"]
	return AnimalKinds.size_of(kind) * 0.45

## Which way an animal is pointed, so the body laid along it points that way
## too.
static func _facing(animal: Dictionary) -> float:
	var node = animal.get("node")
	if node == null or not is_instance_valid(node):
		return 0.0
	return (node as Node3D).rotation.y

## How many animals are solid right now. Read by the checks.
func solid_count() -> int:
	return _solid

static func _where(animal: Dictionary) -> Vector3:
	var node = animal.get("node")
	if node == null or not is_instance_valid(node):
		return PARKED
	return (node as Node3D).global_position
