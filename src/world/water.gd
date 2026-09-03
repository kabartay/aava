class_name Water
extends MeshInstance3D

## The water surface.
##
## Nothing about the river is modelled. The height field carves a trench below
## zero and this plane fills it, so one flat surface becomes river, pond and
## shoreline depending only on the ground beneath it.
##
## The shoreline fade is computed from the river's own centre line rather than
## from the depth buffer: the Mobile renderer cannot be relied on for screen and
## depth texture reads, and a water shader that only works on desktop is no use
## in a game whose target device is a tablet. The shader therefore repeats the
## same meander formula the height field uses — the one place in this project
## where a formula is deliberately duplicated, because the alternative is a
## per-chunk water mesh for a slice that does not need one yet.

## Side of the water sheet. Sized to the fog distance: past that, air hides it.
const EXTENT := 1400.0

## Metres per quad. The vertex wave has a period of tens of metres, so this has
## to stay well below that or the motion turns into a flag flapping.
const QUAD_SIZE := 6.0

## The sheet is snapped to this grid as it follows the player, so the waves stay
## put in world space instead of sliding along with the camera.
const SNAP := 64.0

const SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec3 shallow_color : source_color = vec3(0.42, 0.74, 0.70);
uniform vec3 deep_color : source_color = vec3(0.06, 0.26, 0.40);
uniform float wave_height = 0.10;
uniform float wave_speed = 0.5;
uniform float bank_fade = 26.0;
uniform float river_half_width = 16.0;

varying vec3 world_vertex;
varying float bank_blend;

// Mirrors HeightField.river_centre_x. Keep the two in step: this is what makes
// the water fade out exactly where the bank rises.
float river_centre_x(float z) {
	return 46.0 * sin(z * 0.0038) + 22.0 * sin(z * 0.0111 + 1.3);
}

void vertex() {
	world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	float to_river = abs(world_vertex.x - river_centre_x(world_vertex.z));
	bank_blend = 1.0 - smoothstep(river_half_width, river_half_width + bank_fade, to_river);

	// Two crossed waves at different periods read as a current rather than a
	// pulse, and cost two sines.
	float t = TIME * wave_speed;
	float wave = sin(world_vertex.x * 0.10 + t) * cos(world_vertex.z * 0.075 - t * 0.8);
	VERTEX.y += wave * wave_height * bank_blend;
}

void fragment() {
	// Fresnel: water seen edge-on is a mirror, water seen from above is a window.
	// This single term is most of what makes a flat plane look wet.
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);

	ALBEDO = mix(shallow_color, deep_color, clamp(bank_blend, 0.0, 1.0));
	ALPHA = mix(0.0, mix(0.62, 0.92, fresnel), clamp(bank_blend * 1.15, 0.0, 1.0));

	ROUGHNESS = 0.08;
	SPECULAR = 0.75;
}
"""

func _init() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(EXTENT, EXTENT)
	var subdivisions := int(EXTENT / QUAD_SIZE)
	plane.subdivide_width = subdivisions
	plane.subdivide_depth = subdivisions
	mesh = plane

	var shader := Shader.new()
	shader.code = SHADER

	var material := ShaderMaterial.new()
	material.shader = shader
	material_override = material

	position.y = HeightField.WATER_LEVEL
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## The sheet is finite, so it has to travel with the player — snapped, so the
## waves do not appear to be dragged along.
func follow(world_position: Vector3) -> void:
	position.x = snappedf(world_position.x, SNAP)
	position.z = snappedf(world_position.z, SNAP)
	position.y = HeightField.WATER_LEVEL
