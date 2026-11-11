// ChefFace: the chef's face, layered Mii-style over the skin on a 0..1 face
// canvas (u across, v down). Each part is a small texture placed at its own
// center and size, then moved and scaled by the chef's choices. Eyes and brows
// are drawn twice, mirrored for the chef's left. Layout and texture rules:
// docs/character_asset_spec.md.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// Eyes: R = ink, G = iris (tinted by eye_color), B = highlight, white elsewhere.
uniform sampler2D eyes_texture : source_color, filter_linear_mipmap, repeat_disable, hint_default_transparent;
uniform vec2 eyes_center = vec2(0.5, 0.52);
uniform float eyes_size = 0.2;
uniform float eyes_spacing = 0.15;
uniform vec2 eyes_offset = vec2(0.0);  // x: further apart, y: lower.
uniform float eyes_scale = 1.0;
uniform vec4 eye_color : source_color = vec4(0.23, 0.16, 0.12, 1.0);

// Brows: white shapes, tinted by brow_color (the hair color).
uniform sampler2D brows_texture : source_color, filter_linear_mipmap, repeat_disable, hint_default_transparent;
uniform vec2 brows_center = vec2(0.5, 0.39);
uniform float brows_size = 0.18;
uniform float brows_spacing = 0.16;
uniform vec2 brows_offset = vec2(0.0);
uniform float brows_scale = 1.0;
uniform vec4 brow_color : source_color = vec4(0.35, 0.23, 0.13, 1.0);

// Nose, mouth and face paint: drawn as they are.
uniform sampler2D nose_texture : source_color, filter_linear_mipmap, repeat_disable, hint_default_transparent;
uniform vec2 nose_center = vec2(0.5, 0.62);
uniform float nose_size = 0.13;
uniform vec2 nose_offset = vec2(0.0);
uniform float nose_scale = 1.0;

uniform sampler2D mouth_texture : source_color, filter_linear_mipmap, repeat_disable, hint_default_transparent;
uniform vec2 mouth_center = vec2(0.5, 0.73);
uniform float mouth_size = 0.22;
uniform vec2 mouth_offset = vec2(0.0);
uniform float mouth_scale = 1.0;

uniform sampler2D paint_1 : source_color, filter_linear_mipmap, repeat_disable, hint_default_transparent;
uniform sampler2D paint_2 : source_color, filter_linear_mipmap, repeat_disable, hint_default_transparent;
uniform sampler2D paint_3 : source_color, filter_linear_mipmap, repeat_disable, hint_default_transparent;

uniform vec4 ink_color : source_color = vec4(0.12, 0.09, 0.08, 1.0);

// `tex` placed `size` across at `center` (flipped left-right if `mirror`).
vec4 part(sampler2D tex, vec2 uv, vec2 center, float size, bool mirror) {
	vec2 local = (uv - center) / size + 0.5;
	if (mirror) {
		local.x = 1.0 - local.x;
	}
	if (local.x < 0.0 || local.y < 0.0 || local.x > 1.0 || local.y > 1.0) {
		return vec4(0.0);
	}
	return texture(tex, local);
}

vec4 over(vec4 under, vec4 top) {
	float a = top.a + under.a * (1.0 - top.a);
	vec3 rgb = (top.rgb * top.a + under.rgb * under.a * (1.0 - top.a)) / max(a, 0.0001);
	return vec4(rgb, a);
}

vec4 eye_ink(vec4 e) {
	vec3 rgb = mix(vec3(1.0), eye_color.rgb, e.g);
	rgb = mix(rgb, ink_color.rgb, e.r);
	rgb = mix(rgb, vec3(1.0), e.b);
	return vec4(rgb, e.a);
}

void fragment() {
	vec2 uv = UV;
	vec4 face = vec4(0.0);
	face = over(face, texture(paint_1, uv));
	face = over(face, texture(paint_2, uv));
	face = over(face, texture(paint_3, uv));
	face = over(face, part(nose_texture, uv, nose_center + nose_offset, nose_size * nose_scale, false));
	face = over(face, part(mouth_texture, uv, mouth_center + mouth_offset, mouth_size * mouth_scale, false));
	// The chef's right brow and eye are on our left; their left ones mirrored.
	float brow_x = brows_spacing + brows_offset.x;
	vec2 brow_at = brows_center + vec2(0.0, brows_offset.y);
	for (int side = 0; side < 2; side++) {
		float s = side == 0 ? -1.0 : 1.0;
		vec4 brow = part(brows_texture, uv, brow_at + vec2(s * brow_x, 0.0), brows_size * brows_scale, side == 1);
		face = over(face, vec4(brow_color.rgb, brow.a));
	}
	float eye_x = eyes_spacing + eyes_offset.x;
	vec2 eye_at = eyes_center + vec2(0.0, eyes_offset.y);
	for (int side = 0; side < 2; side++) {
		float s = side == 0 ? -1.0 : 1.0;
		face = over(face, eye_ink(part(eyes_texture, uv, eye_at + vec2(s * eye_x, 0.0), eyes_size * eyes_scale, side == 1)));
	}
	ALBEDO = face.rgb;
	ALPHA = face.a;
	ROUGHNESS = 0.9;
}

// Lit like the skin under it (the art style's soft toon lighting).
#include "res://assets/shaders/soft_toon_light.gdshaderinc"
