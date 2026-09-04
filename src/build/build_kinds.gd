class_name BuildKinds
extends RefCounted

## What can be built, what it costs, and what it becomes.
##
## A leaf script, like ItemKinds: the palette, the ghost preview, the store of
## placed things and the growth clock all read from here without depending on
## one another.
##
## Costs are deliberately small. The point of gathering is to give building a
## reason, not to make a child grind. Three sticks is a walk across a clearing.

const SAPLING := &"sapling"
const FEEDER := &"feeder"
const PATH := &"path"
const FENCE := &"fence"
const CAMPFIRE := &"campfire"

const ALL: Array[StringName] = [SAPLING, FEEDER, PATH, FENCE, CAMPFIRE]

## How long a sapling spends in each stage before the next, in seconds of play.
## Short enough that a child who plants a tree sees it change within the same
## session — the whole promise of the game is that the world answers, and an
## answer that takes a week is not one.
const GROWTH_STAGE_SECONDS := 75.0
const GROWTH_STAGES := 3

const INFO := {
	SAPLING: {
		"label": "sapling", "icon": "T",
		"cost": {&"seed": 1},
		"footprint": 1.8, "grows": true,
		"hint": "plant three close together and a grove takes root",
	},
	FEEDER: {
		"label": "feeder", "icon": "Y",
		"cost": {&"stick": 3, &"seed": 1},
		"footprint": 1.2, "grows": false,
		"hint": "birds come to it",
	},
	PATH: {
		"label": "path", "icon": "=",
		"cost": {&"stone": 1},
		"footprint": 0.9, "grows": false,
		"hint": "marks the way home",
	},
	FENCE: {
		"label": "fence", "icon": "#",
		"cost": {&"stick": 2},
		"footprint": 1.0, "grows": false,
		"hint": "encloses what is yours",
	},
	CAMPFIRE: {
		"label": "campfire", "icon": "^",
		"cost": {&"stick": 3, &"stone": 2},
		"footprint": 1.6, "grows": false,
		"hint": "a place to come back to",
	},
}

static func label(kind: StringName) -> String:
	return Text.of("build_" + String(kind))

static func icon(kind: StringName) -> String:
	return INFO[kind]["icon"]

static func cost(kind: StringName) -> Dictionary:
	return INFO[kind]["cost"]

static func footprint(kind: StringName) -> float:
	return INFO[kind]["footprint"]

static func grows(kind: StringName) -> bool:
	return INFO[kind]["grows"]

static func hint(kind: StringName) -> String:
	return INFO[kind]["hint"]

## The mesh for a piece at a given growth stage. Stage is ignored by everything
## that does not grow, so callers never have to ask which is which.
static func build_mesh(kind: StringName, stage := 0) -> Mesh:
	match kind:
		SAPLING:
			return _sapling(stage)
		FEEDER:
			return _feeder()
		PATH:
			return _path()
		FENCE:
			return _fence()
		_:
			return _campfire()

## Three visible stages: a sprout you could miss, a young tree at knee height,
## and a full tree. The middle stage matters — without it, growth reads as a
## tree appearing out of nowhere rather than as something that grew.
static func _sapling(stage: int) -> Mesh:
	match clampi(stage, 0, GROWTH_STAGES - 1):
		0:
			var sprout := SurfaceTool.new()
			sprout.begin(Mesh.PRIMITIVE_TRIANGLES)
			_add(sprout, _stem(0.02, 0.03, 0.26), Vector3(0.0, 0.13, 0.0), Color(0.42, 0.55, 0.24))
			_add(sprout, _leaf(0.16), Vector3(0.0, 0.30, 0.0), Color(0.34, 0.62, 0.24))
			sprout.generate_normals()
			return sprout.commit()
		1:
			var young := SurfaceTool.new()
			young.begin(Mesh.PRIMITIVE_TRIANGLES)
			_add(young, _stem(0.05, 0.07, 1.05), Vector3(0.0, 0.52, 0.0), Color(0.36, 0.26, 0.17))
			_add(young, _leaf(0.52), Vector3(0.0, 1.28, 0.0), Color(0.24, 0.52, 0.22))
			young.generate_normals()
			return young.commit()
		_:
			return PlantMeshes.broadleaf(5.0)

static func _feeder() -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add(tool, _stem(0.05, 0.06, 1.5), Vector3(0.0, 0.75, 0.0), Color(0.46, 0.33, 0.20))
	var tray := BoxMesh.new()
	tray.size = Vector3(0.62, 0.07, 0.62)
	_add(tool, tray, Vector3(0.0, 1.52, 0.0), Color(0.60, 0.44, 0.26))
	var roof := CylinderMesh.new()
	roof.top_radius = 0.0
	roof.bottom_radius = 0.48
	roof.height = 0.34
	roof.radial_segments = 4
	roof.rings = 1
	_add(tool, roof, Vector3(0.0, 1.86, 0.0), Color(0.72, 0.36, 0.28))
	tool.generate_normals()
	return tool.commit()

static func _path() -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var slab := CylinderMesh.new()
	slab.top_radius = 0.42
	slab.bottom_radius = 0.46
	slab.height = 0.12
	slab.radial_segments = 7
	slab.rings = 1
	_add(tool, slab, Vector3(0.0, 0.05, 0.0), Color(0.60, 0.60, 0.62))
	tool.generate_normals()
	return tool.commit()

static func _fence() -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wood := Color(0.52, 0.37, 0.22)
	_add(tool, _stem(0.05, 0.06, 1.1), Vector3(-0.45, 0.55, 0.0), wood)
	_add(tool, _stem(0.05, 0.06, 1.1), Vector3(0.45, 0.55, 0.0), wood)
	var rail := BoxMesh.new()
	rail.size = Vector3(1.05, 0.09, 0.08)
	_add(tool, rail, Vector3(0.0, 0.82, 0.0), wood)
	_add(tool, rail, Vector3(0.0, 0.50, 0.0), wood)
	tool.generate_normals()
	return tool.commit()

static func _campfire() -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 7:
		var angle := TAU * float(i) / 7.0
		var stone := SphereMesh.new()
		stone.radius = 0.17
		stone.height = 0.22
		stone.radial_segments = 6
		stone.rings = 3
		_add(tool, stone, Vector3(cos(angle) * 0.55, 0.07, sin(angle) * 0.55), Color(0.55, 0.54, 0.55))
	for i in 4:
		var angle := TAU * float(i) / 4.0 + 0.4
		var log_mesh := _stem(0.05, 0.06, 0.7)
		var offset := Vector3(cos(angle) * 0.13, 0.28, sin(angle) * 0.13)
		var lean := Basis(Vector3(sin(angle), 0.0, -cos(angle)), deg_to_rad(28.0))
		_add_transformed(tool, log_mesh, Transform3D(lean, offset), Color(0.40, 0.28, 0.18))
	tool.generate_normals()
	return tool.commit()

static func _stem(top: float, bottom: float, height: float) -> CylinderMesh:
	var stem := CylinderMesh.new()
	stem.top_radius = top
	stem.bottom_radius = bottom
	stem.height = height
	stem.radial_segments = 6
	stem.rings = 1
	return stem

static func _leaf(radius: float) -> SphereMesh:
	var leaf := SphereMesh.new()
	leaf.radius = radius
	leaf.height = radius * 1.7
	leaf.radial_segments = 7
	leaf.rings = 4
	return leaf

static func _add(tool: SurfaceTool, source: PrimitiveMesh, offset: Vector3, color: Color) -> void:
	_add_transformed(tool, source, Transform3D(Basis(), offset), color)

static func _add_transformed(tool: SurfaceTool, source: PrimitiveMesh, transform: Transform3D, color: Color) -> void:
	var arrays := source.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for i in vertices.size():
			tool.set_color(color)
			tool.add_vertex(transform * vertices[i])
		return
	for i in indices.size():
		tool.set_color(color)
		tool.add_vertex(transform * vertices[indices[i]])
