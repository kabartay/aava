class_name Character
extends RefCounted

## Who a child is drawn as: five characters over one rig.
##
## The first is the plain figure the game began with — a round head on a
## rounded body — and it is still built where it always was (Player and
## Visitors), so that a child who never opens the settings sees no change at
## all. The other four are cartoon children, built here: a boy with short hair,
## a girl with pigtails, a child in a backwards cap and dungarees, and a small
## child in a hoodie with bear ears. Big heads, short arms and legs, round
## everything — nearer Toca Boca than a drawing of a real person, because a
## six-year-old reads "that is Amir" from a silhouette and a colour, and a
## faithful anatomy would only make the hands too small to see.
##
## One rig, four definitions. A definition (DEFS) is proportions plus the names
## of the hair, the top and the bottom it wears; nothing about a character is a
## code path of its own, so a fifth is a dictionary and not a function.
##
## THE RIG. Every joint is a Node3D at the joint, with the part that hangs from
## it as a mesh on a child of its own, so that a later pass can turn a joint and
## the part swings about the right place. Feet at y = 0, facing -Z, standing,
## arms hanging, every joint at rest rotation zero:
##
##   Rig                  the root; meta "chest_radius" and "chest_y"
##     Hips               at the hip height; the pelvis and any skirt
##       Torso            the waist; the chest, and the shirt on it
##         Head           the neck; head, hair, face, cap, hood, ears
##         UpperArmL/R    the shoulder; ForearmL/R at the elbow, HandL/R at the wrist
##       ThighL/R         the hip; ShinL/R at the knee, FootL/R at the ankle
##
## L is the side at -X, R at +X, as seen from behind the child. Meshes are
## smooth lofts (AnimalLoft, which made the animals) with the colour on the
## vertex: skin, hair and clothes are one material.

## The simple figure, now a clay toy: see `_clay`.
const SIMPLE := 0

## What each character is called, in the order a child's choice is saved as an
## index. New ones go on the end and nowhere else, for the reason the shirts do.
const KEYS: Array[StringName] = [&"simple", &"boy", &"girl", &"cap", &"bear"]

## The words for each, in Text, for the grown-up reading a tooltip.
const LABELS: Array[StringName] = [
	&"ui_char_simple", &"ui_char_boy", &"ui_char_girl", &"ui_char_cap", &"ui_char_bear",
]

## Five natural skin tones, the first being what the simple figure has always
## had, so that an old save is the colour it was.
const SKINS: Array[Color] = [
	Color(0.93, 0.78, 0.62),
	Color(0.99, 0.87, 0.76),
	Color(0.80, 0.60, 0.42),
	Color(0.58, 0.39, 0.26),
	Color(0.36, 0.23, 0.16),
]

## Five hair colours. The simple figure has none.
const HAIRS: Array[Color] = [
	Color(0.12, 0.09, 0.08),
	Color(0.38, 0.23, 0.12),
	Color(0.86, 0.69, 0.32),
	Color(0.70, 0.30, 0.13),
	Color(0.58, 0.42, 0.26),
]

const SKIN_NAMES: Array[StringName] = [&"fair", &"light", &"tan", &"brown", &"dark"]
const HAIR_NAMES: Array[StringName] = [&"black", &"brown", &"blond", &"ginger", &"chestnut"]

## Height of the ankle joint above the ground, which is also half the height of
## a shoe: the sole of a foot is at y = 0.
const ANKLE := 0.065

## Rings between one key and the next on a limb. Colour changes part-way down
## one (a sleeve, a hem) and a ring is where it can change sharply: with too few
## the edge is a smear across the whole length of the part.
const LIMB_STEPS := 4

## Proportions and clothes. Lengths in metres, standing: `leg` is the hip
## height, `torso` the waist to the shoulders, `head` the head's radius, `build`
## how broad the body is. One garment takes the colour the child chose for their
## clothes (the top, or for the dungarees the dungarees); the rest are fixed, so
## that "the red one" is the red thing and not a rainbow.
const DEFS := {
	&"boy": {
		"leg": 0.47, "torso": 0.42, "head": 0.25, "build": 1.0,
		"hair": &"short", "top": &"tshirt", "bottom": &"shorts",
		"bottom_colour": Color(0.24, 0.30, 0.46), "shoe": Color(0.94, 0.94, 0.96),
	},
	&"girl": {
		"leg": 0.47, "torso": 0.40, "head": 0.25, "build": 0.94,
		"hair": &"pigtails", "top": &"tshirt", "bottom": &"skort",
		"bottom_colour": Color(0.52, 0.30, 0.58), "shoe": Color(0.90, 0.36, 0.50),
	},
	&"cap": {
		"leg": 0.46, "torso": 0.42, "head": 0.25, "build": 1.04,
		"hair": &"short", "top": &"dungarees", "bottom": &"dungarees",
		"bottom_colour": Color(0.96, 0.94, 0.88), "shoe": Color(0.40, 0.28, 0.20),
	},
	&"bear": {
		"leg": 0.37, "torso": 0.36, "head": 0.26, "build": 0.9,
		"hair": &"fringe", "top": &"hoodie", "bottom": &"trousers",
		"bottom_colour": Color(0.34, 0.35, 0.42), "shoe": Color(0.30, 0.30, 0.36),
	},
}

## Rows of the head, each as [height, half-width, front, back] in units of the
## head's radius from its middle: a round skull a little fuller across the
## cheeks than the crown, with a small chin.
const HEAD_ROWS := [
	[-0.95, 0.42, 0.40, 0.40],
	[-0.68, 0.82, 0.80, 0.76],
	[-0.20, 1.00, 0.96, 0.93],
	[0.35, 0.97, 0.94, 0.95],
	[0.76, 0.70, 0.66, 0.72],
]

var _def: Dictionary
var _skin: Color
var _hair: Color
var _cloth: Color
var _material: StandardMaterial3D
var _head_radius := 0.25
var _head_lift := 0.0
var _torso_height := 0.4
var _head: AnimalLoft

## Is this a character built here? All five are: the plain figure became a clay
## toy on the same rig, so that it walks, kicks and swims by the same code as
## the others, and there is no limbless one left for a body to be drawn as.
static func is_rigged(which: int) -> bool:
	return which >= SIMPLE and which < KEYS.size()

## A choice as it is kept, saved and sent: [character, skin, hair]. Anything out
## of range, missing or of the wrong kind becomes the plain choice for that
## part, so that a hand-edited save or a message from another version cannot
## index off the end of a list.
static func clean(look: Variant) -> Array:
	var out: Array = [SIMPLE, 0, 0]
	if not (look is Array):
		return out
	var given: Array = look
	var limits := [KEYS.size(), SKINS.size(), HAIRS.size()]
	for i in mini(given.size(), 3):
		var value: Variant = given[i]
		if (value is int or value is float) and int(value) >= 0 and int(value) < int(limits[i]):
			out[i] = int(value)
	return out

## The choice as the numbers a save file keeps.
static func to_data(look: Array) -> Dictionary:
	return {"character": look[0], "skin": look[1], "hair": look[2]}

## And back, from a save that may be older than all of this.
static func from_data(data: Dictionary) -> Array:
	return clean([data.get("character", 0), data.get("skin", 0), data.get("hair", 0)])

## The rig for a character, standing at the origin.
static func build(which: int, skin: int, hair: int, cloth: Color) -> Node3D:
	var key := KEYS[clampi(which, 0, KEYS.size() - 1)]
	var builder := Character.new()
	builder._skin = SKINS[clampi(skin, 0, SKINS.size() - 1)]
	builder._hair = HAIRS[clampi(hair, 0, HAIRS.size() - 1)]
	builder._cloth = cloth
	if key == &"simple":
		return builder._clay()
	builder._def = DEFS[key]
	return builder._rig(key)

func _rig(key: StringName) -> Node3D:
	var build: float = _def["build"]
	var leg_length: float = _def["leg"]
	_torso_height = _def["torso"]
	_head_radius = _def["head"]
	_head_lift = _head_radius * 1.15
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.roughness = 0.82

	var root := Node3D.new()
	root.name = "Rig"
	root.set_meta("character", key)

	var hips := _joint(root, "Hips", Vector3(0.0, leg_length, 0.0))
	_part(hips, _pelvis(build))

	var waist := 0.06
	var torso := _joint(hips, "Torso", Vector3(0.0, waist, 0.0))
	_part(torso, _chest(build))
	root.set_meta("chest_radius", 0.20 * build + 0.02)
	root.set_meta("chest_y", leg_length + waist + _torso_height * 0.5)

	var neck := _joint(torso, "Head", Vector3(0.0, _torso_height + 0.01, 0.0))
	_part(neck, _head_mesh(key))

	# Arms, from the shoulder. Short: the hand ends about where the hip is.
	var shoulder_x := 0.2 * build + 0.045
	var shoulder_y := _torso_height - 0.07
	var sleeve := 0.075 if _def["top"] == &"hoodie" else 0.065
	for side: int in [-1, 1]:
		var tag := "L" if side < 0 else "R"
		var shoulder := _joint(torso, "UpperArm" + tag, Vector3(side * shoulder_x, shoulder_y, 0.0))
		_part(shoulder, _upper_arm(sleeve))
		var elbow := _joint(shoulder, "Forearm" + tag, Vector3(0.0, -0.16, 0.0))
		_part(elbow, _forearm(sleeve))
		var wrist := _joint(elbow, "Hand" + tag, Vector3(0.0, -0.15, 0.0))
		_part(wrist, _hand())

	# Legs, from the hip.
	var whole_leg := leg_length - ANKLE
	var thigh_length := whole_leg * 0.52 + 0.02
	# The hip joint is 0.02 below the hips, which comes out of the shin: with it
	# added the foot's sole was 4 cm under the ground.
	var shin_length := whole_leg - thigh_length - 0.02
	for side: int in [-1, 1]:
		var tag := "L" if side < 0 else "R"
		var hip := _joint(hips, "Thigh" + tag, Vector3(side * 0.095 * build, -0.02, 0.0))
		_part(hip, _thigh(thigh_length, build))
		var knee := _joint(hip, "Shin" + tag, Vector3(0.0, -thigh_length, 0.0))
		_part(knee, _shin(shin_length, build))
		var ankle := _joint(knee, "Foot" + tag, Vector3(0.0, -shin_length, 0.0))
		_part(ankle, _foot())
	return root

static func _joint(parent: Node3D, joint_name: String, at: Vector3) -> Node3D:
	var joint := Node3D.new()
	joint.name = joint_name
	joint.position = at
	parent.add_child(joint)
	return joint

## The mesh a joint carries, as a child of its own so that the joint can be
## moved and turned without touching what hangs on it.
func _part(joint: Node3D, tool: SurfaceTool) -> void:
	tool.generate_normals()
	tool.set_material(_material)
	var shape := MeshInstance3D.new()
	shape.name = "Mesh"
	shape.mesh = tool.commit()
	joint.add_child(shape)

static func _tool() -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool

# ---------------------------------------------------------------- the body

## Which of the garments is in the colour the child chose.
func _top_colour() -> Color:
	return Color(0.96, 0.94, 0.88) if _def["top"] == &"dungarees" else _cloth

func _bottom_colour() -> Color:
	return _cloth if _def["bottom"] == &"dungarees" else _def["bottom_colour"]

func _pelvis(build: float) -> SurfaceTool:
	var tool := _tool()
	var bottom := _bottom_colour()
	var loft := AnimalLoft.make([
		AnimalLoft.key(Vector3(0.0, -0.09, 0.0), 0.150 * build, 0.115 * build, 0.115 * build),
		AnimalLoft.key(Vector3(0.0, -0.01, 0.0), 0.195 * build, 0.130 * build, 0.130 * build),
		AnimalLoft.key(Vector3(0.0, 0.07, 0.0), 0.180 * build, 0.122 * build, 0.122 * build),
	], Vector3(0.0, 0.0, -1.0), 12, 2, 0.04, 0.0)
	loft.paint = func(_p: Vector3, _along: float, _angle: float) -> Color: return bottom
	loft.emit(tool)
	# A skort: a short flared skirt over the tops of the legs.
	if _def["bottom"] == &"skort":
		var flare := AnimalLoft.make([
			AnimalLoft.key(Vector3(0.0, 0.04, 0.0), 0.185 * build, 0.130 * build, 0.130 * build),
			AnimalLoft.key(Vector3(0.0, -0.07, 0.0), 0.225 * build, 0.165 * build, 0.165 * build),
			AnimalLoft.key(Vector3(0.0, -0.16, 0.0), 0.255 * build, 0.190 * build, 0.190 * build),
		], Vector3(0.0, 0.0, -1.0), 16, 2, 0.0, 0.0)
		flare.paint = func(_p: Vector3, _along: float, _angle: float) -> Color: return bottom
		flare.emit(tool)
	return tool

func _chest(build: float) -> SurfaceTool:
	var tool := _tool()
	var height := _torso_height
	var kind: StringName = _def["top"]
	var top := _top_colour()
	var bottom := _bottom_colour()
	var skin := _skin
	var pocket := _cloth.darkened(0.14)
	var loft := AnimalLoft.make([
		AnimalLoft.key(Vector3(0.0, 0.0, 0.0), 0.190 * build, 0.130 * build, 0.125 * build),
		AnimalLoft.key(Vector3(0.0, height * 0.35, 0.0), 0.195 * build, 0.140 * build, 0.130 * build),
		AnimalLoft.key(Vector3(0.0, height * 0.72, 0.0), 0.200 * build, 0.140 * build, 0.130 * build),
		AnimalLoft.key(Vector3(0.0, height * 0.96, 0.0), 0.140 * build, 0.105 * build, 0.100 * build),
	], Vector3(0.0, 0.0, -1.0), 20, 5, 0.0, 0.05)
	loft.paint = func(p: Vector3, _along: float, _angle: float) -> Color:
		if p.y > height:
			return skin
		if kind == &"hoodie":
			if p.z < -0.05 and p.y < height * 0.42 and absf(p.x) < 0.11 * build:
				return pocket
		elif kind == &"dungarees":
			# The dungarees take the chest up to the shoulders all round, and
			# the T-shirt shows at the neck and in the sleeves. Straps and a
			# bib painted on the vertices smeared into white blotches at the
			# size of the rings; one clean edge reads as dungarees at 5 m.
			if p.y < height * 0.80:
				return bottom
		return top
	loft.emit(tool)
	# The hood of a hoodie, bunched at the back of the neck.
	if kind == &"hoodie":
		AnimalLoft.ball(tool, Vector3(0.0, height * 0.97, 0.085 * build), Vector3(0.13, 0.065, 0.075) * build, _cloth, 8)
	return tool

func _upper_arm(radius: float) -> SurfaceTool:
	var tool := _tool()
	var long_sleeve: bool = _def["top"] == &"hoodie"
	var sleeve := _top_colour()
	var skin := _skin
	var loft := AnimalLoft.make([
		AnimalLoft.key(Vector3(0.0, 0.03, 0.0), radius * 1.0, radius * 1.0, radius * 1.0),
		AnimalLoft.key(Vector3(0.0, -0.07, 0.0), radius * 1.02, radius * 1.02, radius * 1.02),
		AnimalLoft.key(Vector3(0.0, -0.16, 0.0), radius * 0.95, radius * 0.95, radius * 0.95),
	], Vector3(0.0, 0.0, -1.0), 10, LIMB_STEPS, 0.5 * radius, 0.0)
	loft.paint = func(p: Vector3, _along: float, _angle: float) -> Color:
		return sleeve if (long_sleeve or p.y > -0.085) else skin
	loft.emit(tool)
	return tool

func _forearm(radius: float) -> SurfaceTool:
	var tool := _tool()
	var long_sleeve: bool = _def["top"] == &"hoodie"
	var sleeve := _top_colour()
	var skin := _skin
	var loft := AnimalLoft.make([
		AnimalLoft.key(Vector3(0.0, 0.01, 0.0), radius * 0.95, radius * 0.95, radius * 0.95),
		AnimalLoft.key(Vector3(0.0, -0.08, 0.0), radius * 0.88, radius * 0.88, radius * 0.88),
		AnimalLoft.key(Vector3(0.0, -0.15, 0.0), radius * 0.82, radius * 0.82, radius * 0.82),
	], Vector3(0.0, 0.0, -1.0), 10, LIMB_STEPS, 0.0, 0.0)
	loft.paint = func(p: Vector3, _along: float, _angle: float) -> Color:
		return sleeve if (long_sleeve and p.y > -0.145) else skin
	loft.emit(tool)
	return tool

func _hand() -> SurfaceTool:
	var tool := _tool()
	AnimalLoft.ball(tool, Vector3(0.0, -0.03, 0.0), Vector3(0.062, 0.068, 0.058), _skin, 8)
	return tool

func _thigh(length: float, build: float) -> SurfaceTool:
	var tool := _tool()
	var kind: StringName = _def["bottom"]
	var bottom := _bottom_colour()
	var skin := _skin
	# How far down the leg the cloth goes.
	var covered: float = {&"shorts": 0.17, &"skort": 0.07, &"dungarees": 9.0, &"trousers": 9.0}[kind]
	var wide := 0.088 * build
	var loft := AnimalLoft.make([
		AnimalLoft.key(Vector3(0.0, 0.02, 0.0), wide, wide, wide),
		AnimalLoft.key(Vector3(0.0, -length * 0.5, 0.0), wide * 0.97, wide * 0.97, wide * 0.97),
		AnimalLoft.key(Vector3(0.0, -length, 0.0), wide * 0.84, wide * 0.84, wide * 0.84),
	], Vector3(0.0, 0.0, -1.0), 10, LIMB_STEPS, 0.4 * wide, 0.0)
	loft.paint = func(p: Vector3, _along: float, _angle: float) -> Color:
		return bottom if -p.y < covered else skin
	loft.emit(tool)
	return tool

func _shin(length: float, build: float) -> SurfaceTool:
	var tool := _tool()
	var kind: StringName = _def["bottom"]
	var bottom := _bottom_colour()
	var skin := _skin
	var wide := 0.088 * build * 0.84
	var long_legs := kind == &"dungarees" or kind == &"trousers"
	var loft := AnimalLoft.make([
		AnimalLoft.key(Vector3(0.0, 0.01, 0.0), wide, wide, wide),
		AnimalLoft.key(Vector3(0.0, -length * 0.5, 0.0), wide * 0.88, wide * 0.88, wide * 0.88),
		AnimalLoft.key(Vector3(0.0, -length, 0.0), wide * 0.80, wide * 0.80, wide * 0.80),
	], Vector3(0.0, 0.0, -1.0), 10, LIMB_STEPS, 0.0, 0.0)
	# Dungarees are rolled up, which is where the ankle shows; trousers come
	# down to the shoe.
	var hem := length * 0.8 if kind == &"dungarees" else length + 1.0
	loft.paint = func(p: Vector3, _along: float, _angle: float) -> Color:
		return bottom if (long_legs and -p.y < hem) else skin
	loft.emit(tool)
	return tool

func _foot() -> SurfaceTool:
	var tool := _tool()
	var shoe: Color = _def["shoe"]
	var sole := Color(0.97, 0.96, 0.93)
	var loft := AnimalLoft.make([
		AnimalLoft.key(Vector3(0.0, 0.0, 0.045), 0.056, 0.060, ANKLE),
		AnimalLoft.key(Vector3(0.0, 0.0, -0.050), 0.066, 0.056, ANKLE),
		AnimalLoft.key(Vector3(0.0, 0.0, -0.140), 0.060, 0.044, ANKLE),
	], Vector3.UP, 10, 2, 0.02, 0.05)
	loft.paint = func(p: Vector3, _along: float, _angle: float) -> Color:
		return sole if p.y < -ANKLE * 0.72 else shoe
	loft.emit(tool)
	return tool

# ---------------------------------------------------------------- the head

## Keys for a shell or the head itself from rows of HEAD_ROWS' shape. The ring's
## "up" is its front and its "down" its back, so the two are set apart: the
## centre stays on the middle of the head and the front and the back each reach
## as far as their own number says.
func _rows(rows: Array) -> Array:
	var keys: Array = []
	var r := _head_radius
	for row: Array in rows:
		keys.append(AnimalLoft.key(
			Vector3(0.0, _head_lift + float(row[0]) * r, 0.0),
			float(row[1]) * r, float(row[2]) * r, float(row[3]) * r
		))
	return keys

func _head_mesh(key: StringName) -> SurfaceTool:
	var tool := _tool()
	var r := _head_radius
	var lift := _head_lift
	var skin := _skin
	var hair := _hair
	var cloth := _cloth
	var style: StringName = _def["hair"]
	var hooded: bool = _def["top"] == &"hoodie"

	_head = AnimalLoft.make(_rows(HEAD_ROWS), Vector3(0.0, 0.0, -1.0), 18, 3, 0.15 * r, 0.30 * r)
	_head.paint = func(p: Vector3, _along: float, _angle: float) -> Color:
		var y := (p.y - lift) / r
		var z := p.z / r
		var x := p.x / r
		if hooded:
			# A face window in the hood: skin inside an oval, the hood outside,
			# and a little fringe peeping in at the top.
			var oval := pow(x / 0.80, 2.0) + pow((y + 0.12) / 0.92, 2.0)
			if z < -0.15 and oval < 1.0:
				return hair if y > 0.46 else skin
			return cloth
		# The hairline: high on the forehead, low at the back.
		var blend := smoothstep(-0.55, 0.45, z)
		var line := lerpf(0.50, -0.50, blend)
		if style == &"pigtails":
			line = lerpf(0.42, -0.30, blend)
		return hair if y > line else skin
	_head.emit(tool)

	if not hooded:
		_hair_shell(tool)
	if style == &"pigtails":
		_pigtails(tool)
	if key == &"cap":
		_cap(tool)
	if hooded:
		_hood(tool)
	_face(tool)
	return tool

## Hair with some body to it: a shell a little off the skull on the sides, the
## top and the back, and sunk inside it at the front so the painted hairline on
## the head shows there instead.
func _hair_shell(tool: SurfaceTool) -> void:
	var hair := _hair
	var rows := [
		[-0.45, 0.95, 0.70, 0.98], [0.0, 1.06, 0.80, 1.08], [0.45, 1.05, 0.90, 1.08], [0.80, 0.80, 0.76, 0.84],
	]
	var shell := AnimalLoft.make(_rows(rows), Vector3(0.0, 0.0, -1.0), 18, 3, 0.0, 0.30 * _head_radius)
	shell.paint = func(_p: Vector3, _along: float, _angle: float) -> Color: return hair
	shell.emit(tool)

func _pigtails(tool: SurfaceTool) -> void:
	var hair := _hair
	var lift := _head_lift
	for side: int in [-1, 1]:
		var s := float(side)
		var keys := [
			AnimalLoft.key(Vector3(s * 0.255, lift + 0.01, 0.035), 0.040, 0.040, 0.040),
			AnimalLoft.key(Vector3(s * 0.272, lift - 0.12, 0.05), 0.050, 0.050, 0.050),
			AnimalLoft.key(Vector3(s * 0.278, lift - 0.27, 0.06), 0.048, 0.048, 0.048),
			AnimalLoft.key(Vector3(s * 0.272, lift - 0.37, 0.06), 0.022, 0.022, 0.022),
		]
		var plait := AnimalLoft.make(keys, Vector3(0.0, 0.0, -1.0), 10, 2, 0.0, 0.03)
		plait.paint = func(_p: Vector3, _along: float, _angle: float) -> Color: return hair
		plait.emit(tool)
		AnimalLoft.ball(tool, Vector3(s * 0.262, lift + 0.02, 0.035), Vector3(0.04, 0.04, 0.04), Color(0.96, 0.42, 0.56), 8)

## A cap worn backwards: a dome, a band round the brow, and the peak behind.
func _cap(tool: SurfaceTool) -> void:
	var r := _head_radius
	var colour := _cloth
	var rim := _cloth.darkened(0.22)
	var lift := _head_lift
	var rows := [[0.46, 1.04, 1.01, 1.07], [0.62, 1.03, 1.02, 1.08], [0.84, 0.80, 0.78, 0.84]]
	var dome := AnimalLoft.make(_rows(rows), Vector3(0.0, 0.0, -1.0), 18, 3, 0.0, 0.33 * r)
	dome.paint = func(p: Vector3, _along: float, _angle: float) -> Color:
		return rim if (p.y - lift) / r < 0.22 else colour
	dome.emit(tool)
	var peak := AnimalLoft.make([
		AnimalLoft.key(Vector3(0.0, lift + 0.12 * r, 0.82 * r), 0.55 * r, 0.025, 0.025),
		AnimalLoft.key(Vector3(0.0, lift + 0.02 * r, 1.14 * r), 0.62 * r, 0.022, 0.022),
		AnimalLoft.key(Vector3(0.0, lift - 0.12 * r, 1.24 * r), 0.50 * r, 0.020, 0.020),
	], Vector3(0.0, 1.0, 0.0), 12, 2, 0.0, 0.0)
	peak.paint = func(_p: Vector3, _along: float, _angle: float) -> Color: return rim
	peak.emit(tool)
	# The button on top, which is what a cap seen from the front has to tell it
	# from a beanie.
	AnimalLoft.ball(tool, Vector3(0.0, lift + 0.92 * r, 0.04 * r), Vector3(0.11, 0.07, 0.11) * r, rim, 6)

## A hood up round the face, with the ears of a bear on it.
func _hood(tool: SurfaceTool) -> void:
	var r := _head_radius
	var cloth := _cloth
	var rows := [
		[-0.85, 0.80, 0.55, 0.96], [-0.30, 1.14, 0.86, 1.12], [0.35, 1.14, 0.90, 1.12], [0.78, 0.84, 0.78, 0.86],
	]
	var shell := AnimalLoft.make(_rows(rows), Vector3(0.0, 0.0, -1.0), 18, 3, 0.0, 0.30 * r)
	shell.paint = func(_p: Vector3, _along: float, _angle: float) -> Color: return cloth
	shell.emit(tool)
	for side: int in [-1, 1]:
		var s := float(side)
		var at := Vector3(s * 0.74 * r, _head_lift + 0.92 * r, 0.12 * r)
		AnimalLoft.ball(tool, at, Vector3(0.36, 0.36, 0.22) * r, cloth, 10)
		AnimalLoft.ball(tool, at + Vector3(0.0, 0.0, -0.10 * r), Vector3(0.20, 0.20, 0.16) * r, Color(0.98, 0.86, 0.82), 8)

## Where the front of the head is, at a sideways and an upward distance (in
## head radii) from its middle: the head loft's own ring at that height.
func _on_face(x: float, y: float, sink: float) -> Vector3:
	var wanted := _head_lift + y * _head_radius
	var low := 0.0
	var high := float(_head.keys.size() - 1)
	for _step in 14:
		var mid := (low + high) * 0.5
		if (_head.at(mid)["c"] as Vector3).y < wanted:
			low = mid
		else:
			high = mid
	var ring := _head.at((low + high) * 0.5)
	var across := float(ring["rx"])
	var inside := sqrt(maxf(0.0, 1.0 - pow(x * _head_radius / across, 2.0)))
	var centre: Vector3 = ring["c"]
	return Vector3(x * _head_radius, wanted, centre.z - float(ring["ru"]) * inside + sink)

## Eyes, brows, nose, mouth and cheeks, in the same place on every child: a
## cartoon face is the same face, and what tells children apart is the hair.
func _face(tool: SurfaceTool) -> void:
	var dark := Color(0.10, 0.08, 0.09)
	var brow := Color(0.30, 0.20, 0.14)
	if _def["top"] != &"hoodie":
		brow = _hair.darkened(0.1)
	for side: int in [-1, 1]:
		var s := float(side)
		var eye := _on_face(s * 0.40, -0.06, 0.004)
		AnimalLoft.ball(tool, eye, Vector3(0.038, 0.052, 0.034), dark, 8)
		AnimalLoft.ball(tool, eye + Vector3(s * 0.008, 0.02, -0.022), Vector3(0.013, 0.015, 0.012), Color(1.0, 1.0, 1.0), 6)
		var brow_at := _on_face(s * 0.40, 0.30, 0.0)
		_tilted_ball(tool, brow_at, Vector3(0.050, 0.012, 0.014), brow, s * 0.18)
		var cheek := _on_face(s * 0.62, -0.42, 0.002)
		AnimalLoft.ball(tool, cheek, Vector3(0.036, 0.024, 0.012), _skin.lerp(Color(1.0, 0.45, 0.45), 0.45), 8)
	AnimalLoft.ball(tool, _on_face(0.0, -0.32, 0.006), Vector3(0.030, 0.026, 0.028), _skin.darkened(0.10), 8)
	# A smile: a short tube bent up at the ends, lying on the face.
	var keys: Array = []
	for i in 5:
		var u := float(i) / 4.0 * 2.0 - 1.0
		var at := _on_face(u * 0.30, -0.62 + u * u * 0.16, -0.002)
		keys.append(AnimalLoft.key(at, 0.015, 0.015, 0.015))
	var smile := AnimalLoft.make(keys, Vector3(0.0, 0.0, -1.0), 6, 1, 0.012, 0.012)
	smile.paint = func(_p: Vector3, _along: float, _angle: float) -> Color: return Color(0.62, 0.16, 0.16)
	smile.emit(tool)

## A small ellipsoid turned about the way it faces, for a brow.
static func _tilted_ball(tool: SurfaceTool, centre: Vector3, radii: Vector3, colour: Color, roll: float) -> void:
	var piece := _tool()
	AnimalLoft.ball(piece, Vector3.ZERO, radii, colour, 6)
	piece.generate_normals()
	tool.append_from(piece.commit(), 0, Transform3D(Basis(Vector3(0.0, 0.0, 1.0), roll), centre))

# ---------------------------------------------------------------- the clay toy

## The plain figure the game began with, as a toy modelled in clay in the manner
## of Fall Guys: the same round head with its cone of a nose, the same rounded
## body in the colour of the shirt, and now stubby arms and peg legs hung on the
## joints every other character has, so that it walks, kicks and swims by the
## same code and tumbles as comically. It wears no hair (the choice is kept, and
## simply not worn): a toy has a skin and a shirt.
##
## Measured against the old figure, a capsule 1.02 m tall under a head of radius
## 0.21 centred at 1.22 m: the head is where it was, the body is a little
## narrower so that the arms fit inside the collision capsule, and the legs are
## what the body's lower third used to be.
func _clay() -> Node3D:
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.roughness = 0.82
	var trousers := Color(0.29, 0.31, 0.40)

	var root := Node3D.new()
	root.name = "Rig"
	root.set_meta("character", &"simple")
	root.set_meta("chest_radius", 0.27)
	root.set_meta("chest_y", 0.78)

	var hips := _joint(root, "Hips", Vector3(0.0, 0.40, 0.0))
	var pelvis := _tool()
	_solid(pelvis, SphereMesh.new(), Vector3(0.0, 0.03, 0.0), Vector3(0.21, 0.15, 0.20), trousers)
	_part(hips, pelvis)

	var torso := _joint(hips, "Torso", Vector3(0.0, 0.06, 0.0))
	var body := _tool()
	var capsule := CapsuleMesh.new()
	capsule.radius = 1.0
	capsule.height = 2.37
	capsule.radial_segments = 24
	capsule.rings = 6
	_solid(body, capsule, Vector3(0.0, 0.30, 0.0), Vector3(0.27, 0.27, 0.27), _cloth)
	_part(torso, body)

	var neck := _joint(torso, "Head", Vector3(0.0, 0.60, 0.0))
	var head := _tool()
	_solid(head, SphereMesh.new(), Vector3(0.0, 0.17, 0.0), Vector3(0.21, 0.21, 0.21), _skin)
	# The nose, which says which way the child is facing from any distance.
	var nose := CylinderMesh.new()
	nose.top_radius = 0.0
	nose.bottom_radius = 1.0
	nose.height = 2.0
	_solid(head, nose, Vector3(0.0, 0.17, -0.20), Vector3(0.06, 0.07, 0.06), _skin, Basis(Vector3.RIGHT, deg_to_rad(-90.0)))
	for side: float in [-1.0, 1.0]:
		_solid(head, SphereMesh.new(), Vector3(side * 0.08, 0.22, -0.185), Vector3(0.032, 0.040, 0.025), Color(0.10, 0.08, 0.09))
	_part(neck, head)

	# Stubby arms: the hand ends level with the belly.
	for side: int in [-1, 1]:
		var tag := "L" if side < 0 else "R"
		var shoulder := _joint(torso, "UpperArm" + tag, Vector3(side * 0.25, 0.46, 0.0))
		var upper := _tool()
		_peg(upper, 0.14, 0.062, _cloth)
		_part(shoulder, upper)
		var elbow := _joint(shoulder, "Forearm" + tag, Vector3(0.0, -0.13, 0.0))
		var lower := _tool()
		_peg(lower, 0.10, 0.056, _skin)
		_part(elbow, lower)
		var wrist := _joint(elbow, "Hand" + tag, Vector3(0.0, -0.10, 0.0))
		var hand := _tool()
		_solid(hand, SphereMesh.new(), Vector3(0.0, -0.025, 0.0), Vector3(0.068, 0.068, 0.068), _skin)
		_part(wrist, hand)

	# Peg legs: a thigh, a shin and a round foot, thick and short. The hip is at
	# 0.38 m, the knee 0.17 below it and the ankle 0.14 below that.
	for side: int in [-1, 1]:
		var tag := "L" if side < 0 else "R"
		var hip := _joint(hips, "Thigh" + tag, Vector3(side * 0.12, -0.02, 0.0))
		var thigh := _tool()
		_peg(thigh, 0.17, 0.085, trousers)
		_part(hip, thigh)
		var knee := _joint(hip, "Shin" + tag, Vector3(0.0, -0.17, 0.0))
		var shin := _tool()
		_peg(shin, 0.14, 0.078, trousers)
		_part(knee, shin)
		var ankle := _joint(knee, "Foot" + tag, Vector3(0.0, -0.14, 0.0))
		var foot := _tool()
		_solid(foot, SphereMesh.new(), Vector3(0.0, 0.0, -0.035), Vector3(0.095, 0.07, 0.125), _skin.darkened(0.25))
		_part(ankle, foot)
	return root

## A short rounded peg hanging from its joint, `length` down and `radius` across:
## a capsule with a little straight in it, squashed to fit.
static func _peg(tool: SurfaceTool, length: float, radius: float, colour: Color) -> void:
	var peg := CapsuleMesh.new()
	peg.radius = 1.0
	peg.height = 2.6
	peg.radial_segments = 12
	peg.rings = 3
	_solid(tool, peg, Vector3(0.0, -length * 0.5, 0.0), Vector3(radius, length / 2.6, radius), colour)

## A primitive baked into a tool: scaled by `radii`, turned, moved to `centre`,
## in one colour. The vertices are in the default smoothing group, which is what
## makes it clay and not a die.
static func _solid(tool: SurfaceTool, source: PrimitiveMesh, centre: Vector3, radii: Vector3, colour: Color, turn := Basis()) -> void:
	if source is SphereMesh:
		(source as SphereMesh).radius = 1.0
		(source as SphereMesh).height = 2.0
		(source as SphereMesh).radial_segments = 16
		(source as SphereMesh).rings = 8
	elif source is CylinderMesh:
		(source as CylinderMesh).radial_segments = 8
	var arrays := source.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var placed := Transform3D(turn * Basis.from_scale(radii), centre)
	for i in indices.size():
		tool.set_color(colour)
		tool.add_vertex(placed * vertices[indices[i]])
