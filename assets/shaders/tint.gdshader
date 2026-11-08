// Skin and hair: a greyscale texture (plain white if none) times the chef's
// color, so one texture works for every skin or hair color.
shader_type spatial;

uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D shade : source_color, hint_default_white;
uniform float roughness : hint_range(0.0, 1.0) = 0.85;

void fragment() {
	ALBEDO = tint.rgb * texture(shade, UV).r;
	ROUGHNESS = roughness;
}
