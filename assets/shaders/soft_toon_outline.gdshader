// The thin outline of the soft toon material: the model again, pushed out
// along its normals by outline_thickness meters (in the world, so a model's
// scale doesn't change it) and drawn inside out in one flat color.
// outline_thickness 0 = no outline.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform float outline_thickness : hint_range(0.0, 0.05) = 0.006;
uniform vec4 outline_color : source_color = vec4(0.31, 0.14, 0.07, 1.0);

void vertex() {
	vec3 normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	vec4 world = MODEL_MATRIX * vec4(VERTEX, 1.0);
	world.xyz += normal * outline_thickness;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * world;
}

void fragment() {
	if (outline_thickness <= 0.0) {
		discard;
	}
	ALBEDO = outline_color.rgb;
}
