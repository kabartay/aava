class_name Wind
extends RefCounted

## The one wind of the valley: a direction and a strength that drift slowly.
##
## The trees, the grass and the sound of the wind all used to keep their own
## weather — the shader swayed every plant on its own phase along fixed axes,
## and the ambience rolled dice for a target strength — so a gust could be
## heard with nothing moving, and no two things leaned the same way. Both now
## read this, which is a pure function of time: smooth everywhere, never a step.

## Radians, measured in the ground plane from +x towards +z; the way the air
## is travelling, so a flag points along it.
static func angle(t: float) -> float:
	return 0.8 + 0.6 * sin(t * 0.013) + 0.4 * sin(t * 0.0071 + 1.3)

## 0.15 (a calm spell) to 1.0 (blustery), over minutes.
static func strength(t: float) -> float:
	var s := 0.575 + 0.35 * sin(t * 0.045) + 0.15 * sin(t * 0.0173 + 2.0)
	return clampf(s, 0.15, 1.0)

static func direction(t: float) -> Vector2:
	var a := angle(t)
	return Vector2(cos(a), sin(a))

## Now, in the seconds everything shares.
static func clock() -> float:
	return float(Time.get_ticks_msec()) * 0.001
