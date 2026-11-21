// The surface of a soft toon material: a base color times an optional texture
// (white when there's none), plus emission for things that glow.

uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D base_texture : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy : hint_range(0.0, 16.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
// How blurry the texture may get far off (its mip level). Meshy models pack their
// pieces tightly in one picture, so blurring further bleeds one into the next
// (cream specks on a wooden chair): ToonStyle holds theirs at MESHY_MAX_BLUR.
uniform float max_blur = 16.0;

void fragment() {
	vec2 texels = UV * vec2(textureSize(base_texture, 0));
	float blur = 0.5 * log2(max(dot(dFdx(texels), dFdx(texels)), dot(dFdy(texels), dFdy(texels))));
	ALBEDO = base_color.rgb * textureLod(base_texture, UV, clamp(blur, 0.0, max_blur)).rgb;
	ROUGHNESS = roughness;
	SPECULAR = 0.5;  // For the reflected ambient light; the sun's highlight is light()'s own (gloss).
	EMISSION = emission_color.rgb * emission_energy;
}

#include "res://assets/shaders/soft_toon_light.gdshaderinc"
