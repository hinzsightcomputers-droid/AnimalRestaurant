// The surface of a soft toon material: a base color times an optional texture
// (white when there's none), plus emission for things that glow.

uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D base_texture : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy : hint_range(0.0, 16.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;

void fragment() {
	ALBEDO = base_color.rgb * texture(base_texture, UV).rgb;
	ROUGHNESS = roughness;
	SPECULAR = 0.5;  // For the reflected ambient light; the sun's highlight is light()'s own (gloss).
	EMISSION = emission_color.rgb * emission_energy;
}

#include "res://assets/shaders/soft_toon_light.gdshaderinc"
