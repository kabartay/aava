class_name ItemKinds
extends RefCounted

## What can be picked up, and what it looks like.
##
## A leaf script with no dependencies, so that scattering, the inventory, the
## build costs and the interface can all agree about what a stick is without any
## of them depending on each other.

const STICK := &"stick"
const STONE := &"stone"
const REED := &"reed"
const SEED := &"seed"
const CONE := &"cone"

const ALL: Array[StringName] = [STICK, STONE, REED, SEED, CONE]

## Icons are single characters rather than images. A six-year-old reads a shape
## faster than a word, and this way the interface needs no art at all.
const INFO := {
	STICK: {"label": "stick", "icon": "|", "color": Color(0.52, 0.36, 0.20)},
	STONE: {"label": "stone", "icon": "o", "color": Color(0.58, 0.58, 0.60)},
	REED: {"label": "reed", "icon": "/", "color": Color(0.72, 0.68, 0.32)},
	SEED: {"label": "seed", "icon": "*", "color": Color(0.86, 0.74, 0.36)},
	CONE: {"label": "cone", "icon": "A", "color": Color(0.52, 0.34, 0.20)},
}

static func label(kind: StringName) -> String:
	return INFO[kind]["label"]

static func icon(kind: StringName) -> String:
	return INFO[kind]["icon"]

static func color(kind: StringName) -> Color:
	return INFO[kind]["color"]

## The little mesh that lies on the ground waiting to be collected. Built from
## primitives so that a pickup is recognisable by silhouette alone.
static func build_mesh(kind: StringName) -> Mesh:
	match kind:
		STICK:
			var stick := CylinderMesh.new()
			stick.top_radius = 0.035
			stick.bottom_radius = 0.045
			stick.height = 0.62
			stick.radial_segments = 5
			stick.rings = 1
			return stick
		STONE:
			var stone := SphereMesh.new()
			stone.radius = 0.17
			stone.height = 0.24
			stone.radial_segments = 6
			stone.rings = 3
			return stone
		REED:
			var reed := CylinderMesh.new()
			reed.top_radius = 0.0
			reed.bottom_radius = 0.05
			reed.height = 0.85
			reed.radial_segments = 5
			reed.rings = 1
			return reed
		CONE:
			# A cone is a cone, which is a rare piece of luck in this project.
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.11
			cone.height = 0.26
			cone.radial_segments = 7
			cone.rings = 2
			return cone
		_:
			var seed_mesh := SphereMesh.new()
			seed_mesh.radius = 0.11
			seed_mesh.height = 0.18
			seed_mesh.radial_segments = 6
			seed_mesh.rings = 3
			return seed_mesh

## How a pickup lies on the ground: sticks fall over, reeds stand up.
static func resting_rotation(kind: StringName, spin: float) -> Basis:
	match kind:
		STICK:
			return Basis(Vector3.UP, spin) * Basis(Vector3.RIGHT, deg_to_rad(84.0))
		REED:
			return Basis(Vector3.UP, spin)
		_:
			return Basis(Vector3.UP, spin)

static func resting_height(kind: StringName) -> float:
	match kind:
		STICK:
			return 0.05
		REED:
			return 0.42
		STONE:
			return 0.10
		CONE:
			return 0.13
		_:
			return 0.09
