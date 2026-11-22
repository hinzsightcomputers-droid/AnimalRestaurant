// A Meshy model with its top cut away (ModelFit.cut_top): nothing above
// cut_height is drawn, and the inside of what's left shows, a little darker,
// so a pot Meshy made with its lid on is an open pot. Otherwise the model's own
// look, as meshy_surface.gdshader (its texture, its blur capped far off).
// height_row turns the mesh's own vertex into its height in the ModelFit's
// space (bottom at 0), so the cut moves with the model.
shader_type spatial;
render_mode cull_disabled;

uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D base_texture : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform float max_blur = 1.0;
uniform vec4 height_row = vec4(0.0, 1.0, 0.0, 0.0);
uniform float cut_height = 1.0;
uniform float inside_shade : hint_range(0.0, 1.0) = 0.55;

varying float fit_height;

void vertex() {
	fit_height = dot(height_row, vec4(VERTEX, 1.0));
}

void fragment() {
	if (fit_height > cut_height) {
		discard;
	}
	vec2 texels = UV * vec2(textureSize(base_texture, 0));
	float blur = 0.5 * log2(max(dot(dFdx(texels), dFdx(texels)), dot(dFdy(texels), dFdy(texels))));
	vec3 color = base_color.rgb * textureLod(base_texture, UV, clamp(blur, 0.0, max_blur)).rgb;
	if (!FRONT_FACING) {  // The inside, seen through the cut.
		NORMAL = -NORMAL;
		color *= inside_shade;
	}
	ALBEDO = color;
	ROUGHNESS = roughness;
	SPECULAR = 0.5;
}
