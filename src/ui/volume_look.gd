class_name VolumeLook
extends RefCounted

## How the settings' volume sliders are drawn: the lit part of the track and a
## round knob, made in code like the rest of the interface.

## The track up to the knob, and the knob: warm white, like the panel's text.
const LIT := Color(0.96, 0.93, 0.78)

## A round knob this many pixels across, with a soft edge so it does not look
## cut out with scissors at the phone's scale.
static func knob(diameter: int) -> ImageTexture:
	var size := maxi(diameter, 4)
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var centre := Vector2(size, size) * 0.5
	var radius := float(size) * 0.5 - 1.0
	for y in size:
		for x in size:
			var distance := (Vector2(x, y) + Vector2(0.5, 0.5)).distance_to(centre)
			var cover := clampf(radius - distance + 0.5, 0.0, 1.0)
			image.set_pixel(x, y, Color(LIT, cover))
	return ImageTexture.create_from_image(image)
