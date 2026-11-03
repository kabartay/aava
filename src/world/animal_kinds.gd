class_name AnimalKinds
extends RefCounted

## Who lives in the valley, what they want, and what they give back.
##
## A leaf script with no dependencies, so the spawning, the interface, the
## rewards and the checks all agree about what a squirrel is without any of them
## depending on one another.
##
## Every animal wants something found where that animal lives: a squirrel in the
## forest wants a cone that fell under the conifers, a beaver at the water wants
## a stick from the treeline. This is the whole teaching mechanism — a child
## learns where things are by learning who wants them, without a word of it
## being explained.

const CAT := &"cat"
const DOG := &"dog"
const SQUIRREL := &"squirrel"
const BEAVER := &"beaver"
## Livestock, which is a different thing from the wild animals above: they are
## not shy, they do not want anything brought to them, and what they give is
## not coins. A sheep gives wool to whoever has shears; a cow gives milk to
## whoever is thirsty. Both make the meadows worth crossing on their own
## account rather than as the space between two woods.
const SHEEP := &"sheep"
const COW := &"cow"

const ALL: Array[StringName] = [CAT, DOG, SQUIRREL, BEAVER, SHEEP, COW]

## How many of each the valley holds, over the whole of it.
##
## Written down as a wanted number rather than left to fall out of a chance per
## candidate, which is how it used to work and gave five hundred squirrels —
## so many that a child tripped over coins and the shop stopped meaning
## anything. The chances are worked back from these, and a check counts the
## valley and fails if the population drifts.
const WANTED := {
	SQUIRREL: 300,
	SHEEP: 100,
	COW: 50,
	CAT: 50,
	DOG: 50,
	BEAVER: 30,
}

## What each one wants, where it lives, and what caring for it is worth.
##
## `want` of an empty name means it wants nothing but attention — a cat is
## stroked, not fed, which is true of cats and is also the one interaction a
## child with an empty bag can always perform.
## Sizes and colours are storybook, not zoological. At real proportions these
## read as four brown specks from five metres away on a tablet — the eldest
## could not tell the cat from the dog and the six-year-old could not see them
## at all. They are now half again as large, and each has a colour no other
## animal shares: ginger cat, dark dog, red squirrel, chestnut beaver (it was
## slate, and a slate beaver at the water's edge was a dark blob with no face).
const INFO := {
	CAT: {
		"want": &"", "coins": 2, "cooldown": 40.0,
		"colour": Color(0.92, 0.62, 0.24), "size": 0.46,
		"home": "meadow", "shy": 0.35,
	},
	DOG: {
		"want": &"stick", "coins": 3, "cooldown": 30.0,
		"colour": Color(0.40, 0.30, 0.24), "size": 0.62,
		"home": "meadow", "shy": 0.0,
	},
	SQUIRREL: {
		"want": &"cone", "coins": 4, "cooldown": 25.0,
		"colour": Color(0.86, 0.36, 0.14), "size": 0.30,
		"home": "forest", "shy": 0.75,
	},
	BEAVER: {
		"want": &"stick", "coins": 5, "cooldown": 35.0,
		"colour": Color(0.52, 0.34, 0.20), "size": 0.54,
		"home": "water", "shy": 0.2,
	},
	# A sheep gives wool rather than coins, and only to somebody carrying
	# shears. Big and slow and entirely unbothered by children.
	SHEEP: {
		"want": &"", "coins": 0, "cooldown": 100.0,
		"colour": Color(0.95, 0.94, 0.90), "size": 0.58,
		"home": "meadow", "shy": 0.0,
		"gives": &"wool",
	},
	# A cow gives milk, drunk on the spot. The cooldown is what stops a meadow
	# of cows being an endless larder.
	COW: {
		"want": &"", "coins": 0, "cooldown": 120.0,
		"colour": Color(0.96, 0.95, 0.93), "size": 1.0,
		"home": "meadow", "shy": 0.0,
		"gives": &"milk",
	},
}

## The dark on a sheep's face and legs, and the dark of a cow's markings. Named
## because both are used in several places apiece and a colour typed out twice
## is a colour that drifts.
const SHEEP_FACE := Color(0.24, 0.22, 0.24)
const COW_PATCH := Color(0.17, 0.15, 0.16)

## What an animal hands over when it is cared for, or nothing — in which case
## it pays coins like the rest.
static func gives(kind: StringName) -> StringName:
	return INFO[kind].get("gives", &"")

static func want(kind: StringName) -> StringName:
	return INFO[kind]["want"]

static func coins(kind: StringName) -> int:
	return INFO[kind]["coins"]

static func cooldown(kind: StringName) -> float:
	return INFO[kind]["cooldown"]

static func colour(kind: StringName) -> Color:
	return INFO[kind]["colour"]

static func size_of(kind: StringName) -> float:
	return INFO[kind]["size"]

## How readily it runs from an approaching child, 0 to 1. A squirrel bolts, a
## dog does not. Shyness is what makes an animal feel alive rather than placed,
## and it is why catching a squirrel is worth more than greeting a dog.
static func shyness(kind: StringName) -> float:
	return INFO[kind]["shy"]

static func label(kind: StringName) -> String:
	return Text.of("animal_" + String(kind))

## What it wants, in words, for the prompt over its head.
static func wish(kind: StringName) -> String:
	# Livestock is not stroked. A sheep said "wants a stroke" and gave wool,
	# which is two different animals in one prompt.
	var given := gives(kind)
	if given != &"":
		return Text.of("wish_shear" if given == &"wool" else "wish_milk")
	var wanted := want(kind)
	if wanted == &"":
		return Text.of("wish_stroke")
	return Text.format("wish_give", [ItemKinds.label_object(wanted)])

## A body, four legs, a head and a tail in one mesh. The cat, dog, sheep and cow
## are smooth lofts (see `AnimalNatural`); the squirrel and the beaver are still
## built from primitives, whose different proportions are enough to tell them
## apart at a glance.
static func build_mesh(kind: StringName, variant := 0) -> Mesh:
	return _build(kind, true, variant)

## The body alone, for an animal whose legs are nodes of their own.
static func body_mesh(kind: StringName, variant := 0) -> Mesh:
	return _build(kind, false, variant)

## How many coats each kind comes in. Four is enough that a flock or a meadow
## of cows is not one animal photocopied, and few enough that the meshes can be
## built once each and shared by every animal wearing them.
const VARIANTS := 4

## One individual's coat: the kind's own colour nudged a little lighter or
## darker and a little round the colour wheel. Small on purpose — a dog is
## still the dark one and a squirrel still the red one — but two of them side by
## side are no longer the same swatch.
static func tint(kind: StringName, variant: int) -> Color:
	var base := colour(kind)
	match variant % VARIANTS:
		1:
			return Color.from_hsv(fposmod(base.h + 0.012, 1.0), base.s, clampf(base.v * 0.84, 0.0, 1.0))
		2:
			return Color.from_hsv(fposmod(base.h - 0.014, 1.0), base.s * 0.9, clampf(base.v * 1.1 + 0.02, 0.0, 1.0))
		3:
			return Color.from_hsv(fposmod(base.h + 0.025, 1.0), base.s * 1.1, clampf(base.v * 0.94, 0.0, 1.0))
	return base

## Which coat an animal standing at this spot wears. Worked out from where it
## is rather than drawn from the spawning random stream, so adding variety did
## not move a single animal that was already being placed.
static func variant_at(x: float, z: float) -> int:
	return absi(hash(Vector2i(roundi(x * 4.0), roundi(z * 4.0)))) % VARIANTS

## Meshes already built, by kind, coat and whether the legs are baked in.
## Every animal of a kind and coat shares one, instead of the valley building
## hundreds of identical meshes at start-up.
static var _meshes: Dictionary = {}

## The shape of each species, in one place: how long and tall and narrow the
## body is, how the legs are set. Proportions are what tell a cat from a
## beaver — on screen, size and tint alone made all four the same lump.
static func _shape(kind: StringName) -> Dictionary:
	match kind:
		CAT:
			# Legs of a cat's own length: a long low body on short legs, as the
			# stilts it was given at 1.0 made it a greyhound with a tail.
			return {"long": 1.85, "tall": 0.64, "slim": 0.8, "leg": 0.82, "leg_slim": 0.8, "front_leg": 1.0, "hip_lift": 0.0}
		DOG:
			return {"long": 1.7, "tall": 0.8, "slim": 0.92, "leg": 1.05, "leg_slim": 1.0, "front_leg": 1.0, "hip_lift": 0.0}
		SQUIRREL:
			# Sitting up: short front legs held high on the chest, the body tall.
			return {"long": 1.1, "tall": 1.1, "slim": 0.95, "leg": 0.9, "leg_slim": 1.1, "front_leg": 0.55, "hip_lift": 0.35}
		SHEEP:
			# A barrel on short legs: a sheep is mostly fleece, and the fleece
			# is what the silhouette is.
			return {"long": 1.5, "tall": 1.05, "slim": 1.1, "leg": 0.72, "leg_slim": 0.8, "front_leg": 1.0, "hip_lift": 0.0}
		COW:
			# Long, deep and level, on legs that reach: the outline of a cow is
			# a rectangle with corners, and nothing else here is that shape.
			return {"long": 1.7, "tall": 0.95, "slim": 1.05, "leg": 1.15, "leg_slim": 1.1, "front_leg": 1.0, "hip_lift": 0.0}
		_:
			return {"long": 1.45, "tall": 0.92, "slim": 1.05, "leg": 0.85, "leg_slim": 1.2, "front_leg": 1.0, "hip_lift": 0.0}

## Where the four legs hang from, in the body's frame: front-left,
## front-right, hind-left, hind-right. Front is -Z.
## How big an animal's body actually is: across, up and along, in metres.
##
## The same numbers the barrel is built from, so what a child bumps into is
## the animal they can see. A cow is two and a half metres long and was being
## stood in for by a capsule half a metre across — which is a post where the
## cow's middle is, and open air at both ends of her.
static func body_size(kind: StringName) -> Vector3:
	var scale := size_of(kind)
	var shape := _shape(kind)
	# The width is measured off the drawn animal rather than worked out from
	# her proportions a second time.
	#
	# Two ways of answering one question drift apart, and these had: a sheep's
	# fleece, a cow's barrel and a dog's chest all stand out past the number
	# this used to compute, so every animal here was solid across about two
	# thirds of what a child could see — which is how a quad bike drove
	# through the outside of a sheep and touched nothing.
	return Vector3(
		_drawn_width(kind),
		scale * float(shape["tall"]) * 1.32,
		scale * float(shape["long"]) * 1.62 * (1.12 if kind == SHEEP else 1.0)
	)

## How wide the drawn animal actually is across her middle, tail and ears
## left out of it. Measured from the mesh once per kind and remembered — the
## mesh is built from constants, so the answer cannot change while the game
## runs.
static var _widths: Dictionary = {}

static func _drawn_width(kind: StringName) -> float:
	if _widths.has(kind):
		return float(_widths[kind])
	var shape := _shape(kind)
	var middle := size_of(kind) * float(shape["long"]) * 1.62 * 0.3
	# Across every coat: the markings on a cow are laid out differently on each,
	# and the collision has to cover whichever one is standing there.
	var widest := 0.0
	for variant in VARIANTS:
		var arrays := (body_mesh(kind, variant) as ArrayMesh).surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for point in points:
			if absf(point.z) <= middle:
				widest = maxf(widest, absf(point.x))
	_widths[kind] = widest * 2.0
	return widest * 2.0

## How far a paw hangs below the end of its leg, in units of the animal's size
## and the kind's own leg thickness: the sphere on the foot of `leg_mesh` reaches
## a quarter of its thickness (0.13 of the size) past the end of the cylinder.
const PAW_DEPTH := 0.0325

static func hips(kind: StringName) -> Array[Vector3]:
	var scale := size_of(kind)
	var shape := _shape(kind)
	var out: Array[Vector3] = []
	for front in PackedFloat32Array([-1.0, 1.0]):
		for side in PackedFloat32Array([-1.0, 1.0]):
			var lift := float(shape["hip_lift"]) if front < 0.0 else 0.0
			# The hip is as high as the leg is long, so the paw rests on the
			# ground. It was a flat `scale`, which left a sheep's legs (0.72 of
			# it) ending inside her own fleece, fourteen centimetres off the
			# grass, and a cow's (1.15) buried to the hocks. A raised front leg
			# keeps the height it was given: the squirrel holds those to its chest.
			var height := scale * (1.0 + lift)
			if lift == 0.0:
				var reach := float(shape["leg"]) * (float(shape["front_leg"]) if front < 0.0 else 1.0)
				height = scale * (reach + PAW_DEPTH * float(shape["leg_slim"]))
			# A squirrel's arms hang from its chest, which is the tall body
			# leaning up and forward, not out at the end of a long one.
			var along := 0.05 if kind == SQUIRREL and front < 0.0 else 0.6
			out.append(Vector3(
				side * scale * 0.44 * float(shape["slim"]),
				height,
				front * scale * float(shape["long"]) * along
			))
	return out

## One leg, pivoted at the hip so that turning it about X swings it: the leg
## itself, a paler paw. Front legs can be shorter than hind — the squirrel's.
static func leg_mesh(kind: StringName, front: bool, variant := 0, side := 1.0) -> Mesh:
	var key := "%s/%d/leg%s/%s" % [kind, variant % VARIANTS, front, side > 0.0]
	if _meshes.has(key):
		return _meshes[key]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var scale := size_of(kind)
	var shape := _shape(kind)
	var coat := tint(kind, variant)
	if AnimalNatural.is_natural(kind):
		# Hanging from its hip, and as long as the hip is high.
		AnimalNatural.leg(kind, front, variant, coat, scale, hips(kind)[0 if front else 2].y, tool, Vector3.ZERO, side)
		tool.generate_normals()
		tool.set_material(fur_material())
		_meshes[key] = tool.commit()
		return _meshes[key]
	var dark := coat.darkened(0.25)
	var reach := scale * float(shape["leg"]) * (float(shape["front_leg"]) if front else 1.0)
	var thickness := scale * 0.13 * float(shape["leg_slim"])
	var leg := CylinderMesh.new()
	leg.top_radius = thickness
	leg.bottom_radius = thickness * 0.8
	leg.height = reach
	leg.radial_segments = 6
	leg.rings = 1
	_add(tool, leg, Transform3D(Basis(), Vector3(0.0, -reach * 0.5, 0.0)), dark)
	var paw := SphereMesh.new()
	paw.radius = thickness * 1.15
	paw.height = thickness * 1.5
	paw.radial_segments = 6
	paw.rings = 3
	_add(tool, paw, Transform3D(Basis(), Vector3(0.0, -reach + thickness * 0.5, -thickness * 0.4)), dark if kind != DOG else coat.lightened(0.25))
	tool.generate_normals()
	tool.set_material(fur_material())
	_meshes[key] = tool.commit()
	return _meshes[key]

## An animal as a node: the body, and four legs hung from the hips that
## Animals swings as it walks. The baked mesh alone stood stiff-legged.
static func build_node(kind: StringName, variant := 0) -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = body_mesh(kind, variant)
	root.add_child(body)
	var points := hips(kind)
	for i in points.size():
		var leg := MeshInstance3D.new()
		leg.name = "Leg%d" % i
		# The left legs are the mirror of the right: each leans in at the top.
		leg.mesh = leg_mesh(kind, i < 2, variant, -1.0 if i % 2 == 0 else 1.0)
		leg.position = points[i]
		body.add_child(leg)
	# The head and, for those that wag one, the tail hang from the root rather
	# than the body, so the body keeps exactly four children — the legs — and
	# Animals can find each by name. Each is drawn about its own joint.
	var head := MeshInstance3D.new()
	head.name = "Head"
	head.mesh = head_mesh(kind, variant)
	head.position = head_pivot(kind)
	root.add_child(head)
	var tail := tail_mesh(kind, variant)
	if tail != null:
		var wag := MeshInstance3D.new()
		wag.name = "Tail"
		wag.mesh = tail
		wag.position = tail_pivot(kind)
		root.add_child(wag)
	return root

## A body built from primitives: a body, a neck, a head with a face, a tail,
## and — when baked in — four legs.
static func _build(kind: StringName, with_legs: bool, variant := 0) -> Mesh:
	var key := "%s/%d/%s" % [kind, variant % VARIANTS, with_legs]
	if _meshes.has(key):
		return _meshes[key]
	if AnimalNatural.is_natural(kind):
		return _build_natural(kind, with_legs, variant, key)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var scale := size_of(kind)
	var colour := tint(kind, variant)
	# A cow's markings are black on some and brown on others.
	var dark := colour.darkened(0.25)
	var shape := _shape(kind)
	var long := float(shape["long"])
	var tall := float(shape["tall"])
	var slim := float(shape["slim"])

	# Where the parts go. Baked into one mesh, everything goes to `tool`. Built
	# for a node, the head and the tail kinds that wag go to meshes of their
	# own, which Animals can turn: a head fixed to the body can neither graze
	# nor look round, and a tail that is part of the body cannot wag. `tool` is
	# pointed at whichever mesh is being added to as the code below goes round
	# the animal, and back at the body between the parts.
	var body_tool := tool
	var head_tool := tool
	var tail_tool := tool
	if not with_legs:
		head_tool = SurfaceTool.new()
		head_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		if TAILS.has(kind):
			tail_tool = SurfaceTool.new()
			tail_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var body := SphereMesh.new()
	body.radius = scale
	body.height = scale * 1.7
	body.radial_segments = 12
	body.rings = 7
	# Bodies are built out of an ellipsoid with a barrel of flat panels laid
	# over it rather than out of the ellipsoid alone.
	#
	# A scaled sphere is a bubble, and a valley of bubbles with ears on is what
	# this was: the eye reads an animal by its corners — the point of a
	# shoulder, the square of a rump, the flat of a flank — and a sphere has
	# none of them anywhere. The sphere stays underneath as the soft filling;
	# the panels are what give it a shape to recognise.
	_add(tool, body, Transform3D(
		Basis().scaled(Vector3(slim * 0.92, tall * 0.94, long * 0.98)),
		Vector3(0.0, scale * 1.05, 0.0)
	), colour)
	_barrel(tool, kind, scale, long, tall, slim, colour)

	# The neck lifts the head clear of the shoulders. Without it the head was
	# swallowed by the body and every animal was a single blob.
	var head_forward := -scale * (long * 0.92)
	var head_lift := scale * 1.45
	match kind:
		SQUIRREL:
			head_lift = scale * 2.05
			head_forward = -scale * long * 0.62
		CAT:
			head_lift = scale * 1.52
		DOG:
			head_lift = scale * 1.55
		COW:
			# Carried lower than a dog's: a cow's head hangs from the shoulder
			# rather than being held up on a stalk.
			head_lift = scale * 1.3
		BEAVER:
			# Hunched: a beaver's head sits low and close on its shoulders,
			# which is what stopped it reading as a second, smaller lump.
			head_lift = scale * 1.3
			head_forward = -scale * long * 0.8

	# From the neck to the ears, what is added goes to the head's own mesh —
	# see the note on `head_tool` — and `tool` is put back for the body after.
	tool = head_tool
	var neck := CylinderMesh.new()
	neck.top_radius = scale * (0.24 if kind == CAT else 0.3)
	neck.bottom_radius = scale * (0.3 if kind == CAT else 0.38)
	neck.height = scale * (0.62 if kind == CAT else 0.5)
	neck.radial_segments = 7
	neck.rings = 1
	_add(tool, neck, Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(-32.0 if kind != SQUIRREL else -10.0)),
		Vector3(0.0, head_lift - scale * 0.32, head_forward * 0.55)
	), colour)
	# The foot of the neck, where the head turns: its middle, less half its
	# length along the way it leans.
	var neck_pivot := Vector3(0.0, head_lift - scale * 0.32, head_forward * 0.55) - (
		Basis(Vector3.RIGHT, deg_to_rad(-32.0 if kind != SQUIRREL else -10.0)) * Vector3.UP
	) * neck.height * 0.5

	# A sheep's face is dark, not fleece: the head used to be drawn in the
	# coat's white and the dark mask sat inside it, so from the front a sheep
	# was a white ball with two beads in it.
	var face := SHEEP_FACE if kind == SHEEP else colour
	var head := SphereMesh.new()
	head.radius = scale * (0.55 if kind == CAT else (0.58 if kind == DOG else 0.62))
	head.height = head.radius * 1.8
	head.radial_segments = 10
	head.rings = 6
	_add(tool, head, Transform3D(
		Basis().scaled(Vector3(0.84, 0.96, 1.18)) if kind == SHEEP else Basis(),
		Vector3(0.0, head_lift, head_forward)
	), face)
	# A brow over it: deeper than it is wide and set back a little, so the head
	# has a forehead and cheeks rather than being a ball with eyes on. An
	# ellipsoid again — the box that was here made every animal look like a
	# crate with ears.
	var skull := SphereMesh.new()
	skull.radius = head.radius * 0.86
	skull.height = head.radius * 1.5
	skull.radial_segments = 9
	skull.rings = 5
	_add(
		tool, skull,
		Transform3D(
			Basis().scaled(Vector3(1.0, 0.92, 1.15)),
			Vector3(0.0, head_lift + scale * 0.05, head_forward + scale * 0.06)
		),
		face
	)

	# A muzzle, so there is a front. Long and boxy on the dog, blunt on the
	# beaver, small on the cat.
	var snout := SphereMesh.new()
	snout.radius = scale * 0.26
	snout.height = scale * 0.52
	snout.radial_segments = 8
	snout.rings = 4
	var snout_long := 1.0
	match kind:
		DOG:
			snout_long = 1.8
		CAT:
			snout_long = 0.8
		COW:
			snout_long = 2.2
	var snout_colour := colour.lightened(0.28) if kind == DOG else colour.darkened(0.12)
	if kind == BEAVER:
		# A paler muzzle on the dark face, as a real beaver has.
		snout_colour = colour.lightened(0.3)
	elif kind == SHEEP:
		snout_colour = SHEEP_FACE.lightened(0.08)
	_add(tool, snout, Transform3D(
		Basis().scaled(Vector3(0.85, 0.75, snout_long)),
		Vector3(0.0, head_lift - scale * 0.14, head_forward - scale * 0.5)
	), snout_colour)
	if kind == BEAVER:
		# Two front teeth, which is the whole of a beaver's face.
		for side in PackedFloat32Array([-1.0, 1.0]):
			var tooth := BoxMesh.new()
			tooth.size = Vector3(scale * 0.06, scale * 0.12, scale * 0.03)
			_add(tool, tooth, Transform3D(Basis(), Vector3(side * scale * 0.04, head_lift - scale * 0.3, head_forward - scale * 0.76)), Color(0.96, 0.92, 0.80))

	# Ears, which is most of what separates a cat from a beaver at ten metres.
	# A cat and a squirrel get tall pointed ears standing straight up; a dog
	# gets long ones hanging down; a beaver gets almost none.
	var pricked := kind == CAT or kind == SQUIRREL
	for side in PackedFloat32Array([-1.0, 1.0]):
		if kind == DOG:
			var flop := BoxMesh.new()
			# Shorter and swung further out than they were: at 0.9 tall they
			# hung to the dog's chin and read as a pair of long black flaps.
			flop.size = Vector3(scale * 0.14, scale * 0.62, scale * 0.34)
			_add(tool, flop, Transform3D(
				Basis(Vector3.FORWARD, deg_to_rad(side * 28.0)),
				Vector3(side * scale * 0.54, head_lift - scale * 0.02, head_forward + scale * 0.08)
			), dark)
			continue
		var ear := CylinderMesh.new()
		ear.top_radius = 0.0
		# A cat's ears are broad at the base and not much taller than they are
		# wide; at a full scale of height they were a rabbit's.
		ear.bottom_radius = scale * (0.24 if pricked else 0.16)
		ear.height = scale * ((0.78 if kind == CAT else 1.05) if pricked else 0.32)
		ear.radial_segments = 5
		ear.rings = 1
		_add(tool, ear, Transform3D(
			Basis(Vector3.FORWARD, deg_to_rad(side * 10.0)) if kind == CAT else Basis(),
			Vector3(
				side * scale * 0.36,
				head_lift + scale * ((0.74 if kind == CAT else 0.86) if pricked else 0.3),
				head_forward + scale * 0.12
			)
		), dark)
		if pricked:
			# The pink inside the ear.
			var inner := CylinderMesh.new()
			inner.top_radius = 0.0
			inner.bottom_radius = scale * 0.12
			inner.height = scale * (0.46 if kind == CAT else 0.6)
			inner.radial_segments = 4
			inner.rings = 1
			_add(tool, inner, Transform3D(Basis(), Vector3(side * scale * 0.36, head_lift + scale * (0.66 if kind == CAT else 0.78), head_forward + scale * 0.02)), Color(0.86, 0.60, 0.62))

	tool = body_tool

	# A squirrel's ears have tufts on them, and in a wood at twenty metres the
	# tufts and the tail are the whole animal.
	if kind == SQUIRREL:
		# A cream chest and throat: the red squirrel's one pale thing, and what
		# makes the sitting-up pose read as a chest being held out.
		var chest := SphereMesh.new()
		chest.radius = scale * 0.5
		chest.height = scale * 1.2
		chest.radial_segments = 8
		chest.rings = 4
		_add(tool, chest, Transform3D(
			Basis().scaled(Vector3(0.78, 1.0, 0.5)),
			Vector3(0.0, scale * 1.4, -scale * long * 0.7)
		), Color(0.95, 0.88, 0.74))
		for side in PackedFloat32Array([-1.0, 1.0]):
			var tuft := CylinderMesh.new()
			tuft.top_radius = 0.0
			tuft.bottom_radius = scale * 0.1
			tuft.height = scale * 0.5
			tuft.radial_segments = 4
			tuft.rings = 1
			_add(head_tool, tuft, Transform3D(
				Basis(Vector3.FORWARD, deg_to_rad(side * 14.0)),
				Vector3(side * scale * 0.36, head_lift + scale * 1.38, head_forward + scale * 0.12)
			), colour.darkened(0.2))
		# And the paws it holds against its chest, which is the pose it is
		# built in: the body is upright and the front legs are short, so
		# without hands there is nothing at the top of that chest at all.
		for side in PackedFloat32Array([-1.0, 1.0]):
			var paw := SphereMesh.new()
			paw.radius = scale * 0.16
			paw.height = scale * 0.22
			paw.radial_segments = 6
			paw.rings = 3
			_add(tool, paw, Transform3D(Basis(), Vector3(
				side * scale * 0.2, scale * 1.35, -scale * long * 0.58
			)), colour.lightened(0.2))

	if with_legs:
		var points := hips(kind)
		for i in points.size():
			var reach := scale * float(shape["leg"]) * (float(shape["front_leg"]) if i < 2 else 1.0)
			var leg := CylinderMesh.new()
			leg.top_radius = scale * 0.13 * float(shape["leg_slim"])
			leg.bottom_radius = leg.top_radius * 0.8
			leg.height = reach
			leg.radial_segments = 6
			leg.rings = 1
			_add(tool, leg, Transform3D(Basis(), points[i] + Vector3(0.0, -reach * 0.5, 0.0)), dark)
		_add_paws(tool, scale, long, slim, dark)

	_add_belly(tool, scale, long, tall, slim, colour)
	_add_face(head_tool, kind, scale, head_lift, head_forward, snout_long, colour)
	_add_tail(tail_tool, kind, scale, colour, long)
	if not with_legs:
		_keep_part(key + "/head", head_tool, neck_pivot)
		if TAILS.has(kind):
			var root: Vector2 = TAILS[kind]
			_keep_part(key + "/tail", tail_tool, Vector3(0.0, scale * root.x, scale * long * root.y))
	tool.generate_normals()
	# The material travels with the mesh. These meshes are built from vertex
	# colours alone, so a caller that attaches the mesh without also knowing to
	# set vertex_color_use_as_albedo gets four identical white animals — which
	# is exactly what happened the first time the screenshot tool used them.
	tool.set_material(fur_material())
	_meshes[key] = tool.commit()
	return _meshes[key]

## The cat, dog, sheep and cow: a smooth body, head and legs from `AnimalNatural`
## rather than the primitives above. The parts go where `_build` sends them —
## one mesh when the legs are baked in, and a head and a tail of their own when
## they are not — and the head and tail are drawn about their joints the same
## way.
static func _build_natural(kind: StringName, with_legs: bool, variant: int, key: String) -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var scale := size_of(kind)
	var coat := tint(kind, variant)
	var head_tool := tool
	var tail_tool := tool
	if not with_legs:
		head_tool = SurfaceTool.new()
		head_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		if TAILS.has(kind):
			tail_tool = SurfaceTool.new()
			tail_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	AnimalNatural.body(kind, variant, coat, scale, tool)
	if with_legs:
		var points := hips(kind)
		for i in points.size():
			AnimalNatural.leg(kind, i < 2, variant, coat, scale, points[i].y, tool, points[i], -1.0 if i % 2 == 0 else 1.0)
	var neck_pivot := AnimalNatural.head(kind, variant, coat, scale, head_tool)
	if TAILS.has(kind):
		AnimalNatural.tail(kind, coat, scale, tail_tool)
	tool.generate_normals()
	tool.set_material(fur_material())
	if not with_legs:
		_keep_part(key + "/head", head_tool, neck_pivot)
		if TAILS.has(kind):
			var root: Vector2 = TAILS[kind]
			_keep_part(key + "/tail", tail_tool, Vector3(0.0, scale * root.x, scale * float(_shape(kind)["long"]) * root.y))
	_meshes[key] = tool.commit()
	return _meshes[key]

## Where each tail turns: how high, in units of the animal's size, and how far
## back along it, as a fraction of its length. Inside the rump, so that a tail
## swung about the point stays joined to her. Kinds not listed keep their tail
## baked into the body.
## The cow's, named because the dock and the tuft are drawn from it too. It is
## inside the barrel: at 1.5 high and 0.98 of her length back it was in the air
## behind the rump, because the body narrows towards its top, and the tail
## hung a third of a metre clear of her.
const COW_TAIL_ROOT := Vector2(1.5, 0.735)

const TAILS := {
	CAT: Vector2(1.15, 0.73),
	DOG: Vector2(1.45, 0.68),
	SQUIRREL: Vector2(0.72, 0.62),
	COW: COW_TAIL_ROOT,
}

## Pivots of the head and tail pieces, by the same key as the meshes.
static var _pivots: Dictionary = {}

## Commit a head or a tail as a mesh of its own, drawn about the point it turns
## on rather than about the animal's middle, so that turning the node turns
## the piece about its joint.
static func _keep_part(key: String, tool: SurfaceTool, pivot: Vector3) -> void:
	tool.generate_normals()
	var raw := tool.commit()
	var moved := SurfaceTool.new()
	moved.begin(Mesh.PRIMITIVE_TRIANGLES)
	moved.append_from(raw, 0, Transform3D(Basis(), -pivot))
	moved.set_material(fur_material())
	_meshes[key] = moved.commit()
	_pivots[key] = pivot

## The head of an animal that is built as a node: the neck, the face, the ears.
## Hung from the shoulders by `head_pivot`, so that it can graze and look round.
static func head_mesh(kind: StringName, variant := 0) -> Mesh:
	body_mesh(kind, variant)
	return _meshes["%s/%d/false/head" % [kind, variant % VARIANTS]]

static func head_pivot(kind: StringName) -> Vector3:
	body_mesh(kind)
	return _pivots["%s/0/false/head" % kind]

## The tail, for the kinds that wag one; null for the rest, whose tails stay
## in the body.
static func tail_mesh(kind: StringName, variant := 0) -> Mesh:
	if not TAILS.has(kind):
		return null
	body_mesh(kind, variant)
	return _meshes["%s/%d/false/tail" % [kind, variant % VARIANTS]]

static func tail_pivot(kind: StringName) -> Vector3:
	body_mesh(kind)
	return _pivots["%s/0/false/tail" % kind]

## The flat panels that give a body corners: shoulders, flanks, a back and a
## rump, laid over the soft shape underneath.
##
## Six slabs rather than a hundred triangles. Each is a box, so each has edges,
## and edges are what catch the light — which is the whole difference between
## an animal and a balloon in a world lit by one sun.
static func _barrel(
	tool: SurfaceTool, kind: StringName, scale: float, long: float, tall: float,
	slim: float, colour: Color
) -> void:
	var length := scale * long * 1.62
	var height := scale * tall * 1.32
	var width := scale * slim * 1.42
	var middle := Vector3(0.0, scale * 1.05, 0.0)

	# Masses, not boxes.
	#
	# The first attempt at this laid flat slabs over the body to give it
	# corners, and it worked in the sense that the animals stopped being
	# bubbles and failed in the sense that a cow became a crate. An animal is
	# neither: it is a few round masses of different sizes pushed together —
	# a deep chest, a barrel of ribs, a rounded rump — and what reads as a
	# shoulder is the *join* between two of them, not an edge.
	#
	# So these are ellipsoids, squashed differently from one another and from
	# the body they sit on. There is not a flat face anywhere in it.
	var shoulder := SphereMesh.new()
	shoulder.radius = scale * 0.66
	shoulder.height = scale * 1.2
	shoulder.radial_segments = 10
	shoulder.rings = 6
	_add(
		tool, shoulder,
		Transform3D(
			Basis().scaled(Vector3(slim * 0.96, tall * 0.92, long * 0.5)),
			middle + Vector3(0.0, scale * 0.04, -length * 0.26)
		),
		colour
	)

	var rump := SphereMesh.new()
	rump.radius = scale * 0.7
	rump.height = scale * 1.25
	rump.radial_segments = 10
	rump.rings = 6
	_add(
		tool, rump,
		Transform3D(
			Basis().scaled(Vector3(slim * 1.0, tall * 0.96, long * 0.52)),
			middle + Vector3(0.0, scale * 0.02, length * 0.27)
		),
		colour
	)

	# And the line of the back: a long, very flat ellipsoid along the top,
	# which is what gives a grazing animal its level topline without giving it
	# a lid.
	var topline := SphereMesh.new()
	topline.radius = scale * 0.5
	topline.height = scale * 0.7
	topline.radial_segments = 10
	topline.rings = 5
	_add(
		tool, topline,
		Transform3D(
			Basis().scaled(Vector3(slim * 0.78, tall * 0.3, long * 1.02)),
			middle + Vector3(0.0, height * 0.3, 0.0)
		),
		colour if kind != COW else colour.lightened(0.03)
	)

## Shared by every animal: one material, vertex-coloured, slightly rough.
static func fur_material() -> StandardMaterial3D:
	if _fur == null:
		_fur = StandardMaterial3D.new()
		_fur.vertex_color_use_as_albedo = true
		_fur.vertex_color_is_srgb = true
		_fur.roughness = 0.85
	return _fur

static var _fur: StandardMaterial3D = null

## Feet, so the legs end in something rather than stopping in the grass.
static func _add_paws(tool: SurfaceTool, scale: float, long: float, slim: float, dark: Color) -> void:
	for side in PackedFloat32Array([-1.0, 1.0]):
		for front in PackedFloat32Array([-1.0, 1.0]):
			var paw := SphereMesh.new()
			paw.radius = scale * 0.15 * (0.5 + 0.5 * slim)
			paw.height = scale * 0.2
			paw.radial_segments = 6
			paw.rings = 3
			_add(tool, paw, Transform3D(
				Basis(), Vector3(side * scale * 0.44 * slim, scale * 0.09, front * scale * long * 0.6 - scale * 0.05)
			), dark)

## A paler underside. Every animal has one, and it is most of what makes a
## body read as a body rather than a coloured egg.
static func _add_belly(tool: SurfaceTool, scale: float, long: float, tall: float, slim: float, colour: Color) -> void:
	var belly := SphereMesh.new()
	belly.radius = scale * 0.62
	belly.height = scale * 0.9
	belly.radial_segments = 8
	belly.rings = 4
	# Just proud of the body's underside, whatever the body's height.
	var underside := scale * (1.05 - 0.85 * tall)
	_add(tool, belly, Transform3D(
		Basis().scaled(Vector3(0.8 * slim, 0.55, long * 0.62)),
		Vector3(0.0, underside + scale * 0.16, -scale * long * 0.08)
	), colour.lightened(0.3))

## Eyes and a nose. Without eyes an animal is a toy; with them it is looking
## at you, which is the whole of what a child wants from it. The cat has big
## green eyes and whiskers; the others, dark eyes with a catchlight.
static func _add_face(
	tool: SurfaceTool, kind: StringName, scale: float, head_lift: float, head_forward: float,
	snout_long: float, colour: Color
) -> void:
	var iris := Color(0.62, 0.78, 0.30) if kind == CAT else Color(0.08, 0.06, 0.05)
	if kind == SHEEP:
		# Black eyes in a black face are no eyes at all.
		iris = Color(0.78, 0.62, 0.22)
	var pupil := Color(0.05, 0.05, 0.05)
	var shine := Color(0.95, 0.95, 0.95)
	for side in PackedFloat32Array([-1.0, 1.0]):
		var eye_at := Vector3(side * scale * 0.27, head_lift + scale * 0.1, head_forward - scale * 0.5)
		var eye := SphereMesh.new()
		eye.radius = scale * (0.12 if kind == CAT else 0.1)
		eye.height = eye.radius * 2.0
		eye.radial_segments = 6
		eye.rings = 3
		_add(tool, eye, Transform3D(Basis(), eye_at), iris)
		if kind == CAT:
			var slit := SphereMesh.new()
			slit.radius = scale * 0.05
			slit.height = scale * 0.16
			slit.radial_segments = 4
			slit.rings = 3
			_add(tool, slit, Transform3D(Basis(), eye_at + Vector3(0.0, 0.0, -scale * 0.08)), pupil)
		var glint := SphereMesh.new()
		glint.radius = scale * 0.03
		glint.height = scale * 0.06
		glint.radial_segments = 4
		glint.rings = 2
		_add(tool, glint, Transform3D(Basis(), eye_at + Vector3(side * scale * 0.03, scale * 0.04, -scale * 0.09)), shine)

	var nose := SphereMesh.new()
	nose.radius = scale * 0.08
	nose.height = scale * 0.13
	nose.radial_segments = 5
	nose.rings = 3
	var nose_at := Vector3(0.0, head_lift - scale * 0.1, head_forward - scale * 0.5 - scale * 0.26 * snout_long)
	_add(tool, nose, Transform3D(Basis(), nose_at), Color(0.75, 0.45, 0.45) if kind == CAT else pupil)

	if kind == CAT:
		# Whiskers: two each side, drooping a little.
		for side in PackedFloat32Array([-1.0, 1.0]):
			for row in 2:
				var whisker := CylinderMesh.new()
				whisker.top_radius = scale * 0.012
				whisker.bottom_radius = scale * 0.012
				whisker.height = scale * 0.7
				whisker.radial_segments = 3
				whisker.rings = 1
				# Rotating +Y about FORWARD by 105° lays it along +X and a
				# little downwards; the other side is the mirror.
				_add(tool, whisker, Transform3D(
					Basis(Vector3.FORWARD, deg_to_rad(side * 105.0)),
					nose_at + Vector3(side * scale * 0.42, scale * 0.02 - float(row) * scale * 0.07, scale * 0.18 + float(row) * scale * 0.06)
				), colour.lightened(0.5))

## The tail carries the identity: a squirrel's plume, a beaver's paddle, a
## dog's curl, a cat's raised question mark. It is the cheapest possible
## characterisation and the most legible.
static func _add_tail(tool: SurfaceTool, kind: StringName, scale: float, colour: Color, long: float) -> void:
	match kind:
		SQUIRREL:
			# Two plumes in an S: up from the rump, then curling forward over
			# the back, which is how a squirrel actually carries it.
			# Three, thin at the root and fat at the top, and paler towards the
			# tip: a squirrel's tail is a plume, and two sausages of one
			# thickness were a pair of tails.
			var lower := SphereMesh.new()
			lower.radius = scale * 0.3
			lower.height = scale * 1.3
			lower.radial_segments = 7
			lower.rings = 4
			_add(tool, lower, Transform3D(
				Basis(Vector3.RIGHT, deg_to_rad(15.0)),
				Vector3(0.0, scale * 1.45, scale * long * 0.95)
			), colour)
			var middle := SphereMesh.new()
			middle.radius = scale * 0.44
			middle.height = scale * 1.4
			middle.radial_segments = 7
			middle.rings = 4
			_add(tool, middle, Transform3D(
				Basis(Vector3.RIGHT, deg_to_rad(-8.0)),
				Vector3(0.0, scale * 2.2, scale * long * 0.9)
			), colour.lightened(0.12))
			var upper := SphereMesh.new()
			upper.radius = scale * 0.5
			upper.height = scale * 1.4
			upper.radial_segments = 7
			upper.rings = 4
			_add(tool, upper, Transform3D(
				Basis(Vector3.RIGHT, deg_to_rad(-40.0)),
				Vector3(0.0, scale * 2.85, scale * long * 0.7)
			), colour.lightened(0.3))
		BEAVER:
			# A rounded paddle, flat on the ground and a little broader at the
			# far end, rather than the plank it was; dark, like the real thing's
			# bare scaly skin, against a warm brown coat.
			var paddle := SphereMesh.new()
			paddle.radius = scale * 0.5
			paddle.height = scale * 1.0
			paddle.radial_segments = 10
			paddle.rings = 5
			_add(tool, paddle, Transform3D(
				Basis(Vector3.RIGHT, deg_to_rad(10.0)) * Basis.from_scale(Vector3(0.95, 0.16, 1.3)),
				# Its near edge is inside the rump: at 1.2 of her length back it
				# was a flat line lying in the grass behind her.
				Vector3(0.0, scale * 0.5, scale * long * 1.05)
			), colour.darkened(0.45))
		CAT, DOG:
			# Smooth lofts, in `AnimalNatural`: a cat's long banded question
			# mark and a dog's sabre. Named, not a `_:`: the sheep and the cow
			# fell through to a dog's curl once and each wore it beside her own.
			AnimalNatural.tail(kind, colour, scale, tool)

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
