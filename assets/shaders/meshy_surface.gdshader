// A Meshy model's own look (its texture, lit like any standard material), with
// one change: far off, its texture may only blur so much (max_blur, a mip
// level). Meshy packs a model's pieces tightly into one picture, so the usual
// blurrier copies far away bleed one piece into the next: cream specks and
// streaks on a wooden chair. ToonStyle puts this on Meshy models outside the
// toon-styled things (soft_toon_surface caps its texture the same way).
shader_type spatial;

uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D base_texture : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float max_blur = 1.0;

void fragment() {
	vec2 texels = UV * vec2(textureSize(base_texture, 0));
	float blur = 0.5 * log2(max(dot(dFdx(texels), dFdx(texels)), dot(dFdy(texels), dFdy(texels))));
	ALBEDO = base_color.rgb * textureLod(base_texture, UV, clamp(blur, 0.0, max_blur)).rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = 0.5;
}
