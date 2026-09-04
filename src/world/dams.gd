class_name Dams
extends Node3D

## The dams beavers build when a child brings them sticks.
##
## This is the only thing in the game that changes the world rather than the
## score. Eight sticks delivered to a dam site and the beavers finish the wall
## overnight — the river backs up into a pond that is still there tomorrow, deep
## enough to swim in, and visible from the top of the map.
##
## The ground behind the wall is raised rather than the water: the water surface
## is one flat plane across the whole world, so it cannot be lifted locally.
## Filling the trench produces exactly what a child sees, and every other system
## already agrees about where the ground is.

signal stick_delivered(site: float, carried: int, needed: int)
signal dam_finished(site: float)

## The terrain and its collision were generated against a river that a finished
## dam has just changed. Nothing else in this game edits the height field after
## generation, so this is the one signal that asks for the world to be rebuilt.
signal rebuild_needed()

## How close a child must be to a site to hand over a stick.
const REACH := 6.0

var field: HeightField

## Sticks delivered so far, keyed by site. A site reaching STICKS_NEEDED moves
## into `built`.
var progress: Dictionary = {}
var built: Array = []

var _walls: Dictionary = {}

func _init(height_field: HeightField) -> void:
	field = height_field

## The dam site within reach, or NAN.
func site_near(at: Vector3) -> float:
	return DamSpec.nearest_site(at.z, REACH)

func is_built(site: float) -> bool:
	for done in built:
		if is_equal_approx(float(done), site):
			return true
	return false

func sticks_at(site: float) -> int:
	return int(progress.get(site, 0))

## Hand a stick to the beavers. Returns true if it was taken.
func deliver(site: float) -> bool:
	if is_nan(site) or is_built(site):
		return false
	var carried := sticks_at(site) + 1
	progress[site] = carried
	stick_delivered.emit(site, carried, DamSpec.STICKS_NEEDED)

	if carried >= DamSpec.STICKS_NEEDED:
		built.append(site)
		progress.erase(site)
		_raise(site)
		dam_finished.emit(site)
	return true

## Build the wall and tell the world the ground has changed.
func _raise(site: float) -> void:
	_build_wall(site)
	rebuild_needed.emit()

## A tangle of sticks and mud across the narrow point. Deliberately untidy: a
## neat wall reads as a building, and this should read as something animals
## made out of what was lying about.
func _build_wall(site: float) -> void:
	var river_x := field.river_centre_x(site)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var timber := Color(0.44, 0.32, 0.20)
	var mud := Color(0.34, 0.28, 0.20)

	# A packed mud core, so the wall reads as solid rather than as a pile of
	# loose sticks that water would pour straight through.
	# Tall enough to reach from the bed to above the waterline, since the bed
	# here is some 3.7 m down and the whole point is a wall you can see.
	var height := absf(field.height_at(river_x, site) - HeightField.WATER_LEVEL) + 1.6
	var span := DamSpec.POND_HALF_WIDTH * 1.5

	# The mud core is deliberately narrower than the sticks that cover it. The
	# first version was a full-width box with the sticks buried inside, and it
	# read as a brown crate dropped in the river rather than as something
	# animals piled up.
	var core := BoxMesh.new()
	core.size = Vector3(span * 0.94, height, DamSpec.WALL_THICKNESS * 0.42)
	_add(tool, core, Transform3D(Basis(), Vector3(0.0, height * 0.5, 0.0)), mud)

	# Sticks laid across both faces at every angle, standing proud of the core
	# so the silhouette is a tangle. Seeded from the site, so the same dam is
	# always the same tangle.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(int(site), 71))
	for _i in 70:
		var stick := CylinderMesh.new()
		stick.top_radius = rng.randf_range(0.07, 0.13)
		stick.bottom_radius = stick.top_radius
		stick.height = rng.randf_range(2.2, 4.6)
		stick.radial_segments = 5
		stick.rings = 1
		# Pushed out to one face or the other, past the core's own thickness.
		var face := 1.0 if rng.randf() < 0.5 else -1.0
		var spot := Vector3(
			rng.randf_range(-1.0, 1.0) * span * 0.46,
			rng.randf_range(0.3, height * 1.02),
			face * rng.randf_range(0.22, DamSpec.WALL_THICKNESS * 0.5)
		)
		# Mostly leaning along the wall rather than across it, the way stacked
		# branches settle.
		var lean := Basis(Vector3.FORWARD, deg_to_rad(rng.randf_range(52.0, 128.0)))
		lean = lean.rotated(Vector3.UP, rng.randf_range(-0.5, 0.5))
		_add(tool, stick, Transform3D(lean, spot), timber.lightened(rng.randf() * 0.28))

	tool.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.92
	tool.set_material(material)

	var wall := MeshInstance3D.new()
	wall.mesh = tool.commit()
	# Founded on the riverbed and standing clear of the water. The first version
	# sat at bed level and was entirely submerged — a dark smudge under the
	# surface rather than something visibly holding the river back.
	var bed := field.height_at(river_x, site)
	var base := Vector3(river_x, bed - 0.6, site)
	wall.transform = Transform3D(Basis(), base)
	add_child(wall)
	_walls[site] = wall

## Rebuild every wall after a load, since the sticks are saved but the meshes
## are not.
func restore() -> void:
	for site in built:
		if not _walls.has(site):
			_build_wall(float(site))

func to_data() -> Dictionary:
	return {"built": built.duplicate(), "progress": progress.duplicate()}

func from_data(data: Dictionary) -> void:
	built.clear()
	progress.clear()
	for site in data.get("built", []):
		built.append(float(site))
	var saved: Dictionary = data.get("progress", {})
	for key in saved:
		progress[float(key)] = int(saved[key])

static func _add(tool: SurfaceTool, source: PrimitiveMesh, transform: Transform3D, colour: Color) -> void:
	var arrays := source.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for i in vertices.size():
			tool.set_color(colour)
			tool.add_vertex(transform * vertices[i])
		return
	for i in indices.size():
		tool.set_color(colour)
		tool.add_vertex(transform * vertices[indices[i]])
