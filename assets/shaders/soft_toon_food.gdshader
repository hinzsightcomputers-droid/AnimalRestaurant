// The soft toon material for food (ToonStyle.FOOD): its base color, mottled and
// slightly bumpy, with light getting into it, a wet shine where it has one, and a
// floury bloom on dough. The texture is from the model's own position, so it stays
// with the food and needs no picture.
shader_type spatial;
render_mode cull_disabled;

uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D base_texture : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform float roughness = 0.9;
uniform float max_blur = 16.0;
uniform float grain = 60.0;
uniform float mottle = 0.16;
uniform float bumps = 0.5;
uniform float shine_amount : hint_range(0.0, 1.0) = 0.1;
uniform float dust = 0.0;
uniform float soft = 0.3;

varying vec3 local;
varying vec3 local_normal;
varying float wet;

uniform vec4 shadow_tint : source_color = vec4(0.42, 0.25, 0.2, 1.0);
uniform float felt_sheen = 0.22;

void vertex() {
	vec3 size = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	local = VERTEX * size;  // In meters, so a stretched piece's texture isn't.
	local_normal = NORMAL;
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise3(vec3 p) {
	vec3 c = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash3(c), hash3(c + vec3(1.0, 0.0, 0.0)), f.x), mix(hash3(c + vec3(0.0, 1.0, 0.0)), hash3(c + vec3(1.0, 1.0, 0.0)), f.x), f.y);
	float b = mix(mix(hash3(c + vec3(0.0, 0.0, 1.0)), hash3(c + vec3(1.0, 0.0, 1.0)), f.x), mix(hash3(c + vec3(0.0, 1.0, 1.0)), hash3(c + vec3(1.0, 1.0, 1.0)), f.x), f.y);
	return mix(a, b, f.z);
}

void fragment() {
	vec3 p = local * grain;
	float big = noise3(p * 0.45 + 3.1);
	float fine = noise3(p * 1.7);
	float patchy = (big * 0.65 + fine * 0.35) - 0.5;
	vec3 color = base_color.rgb * texture(base_texture, UV).rgb;
	color *= 1.0 + patchy * 2.0 * mottle;
	color = mix(color, color * vec3(1.06, 0.97, 0.84), clamp(big - 0.45, 0.0, 1.0) * mottle * 2.5);  // Warmer in the darker patches.
	float floury = dust * smoothstep(0.35, 0.75, noise3(p * 0.8 + 9.0)) * clamp(local_normal.y, 0.0, 1.0);
	color = mix(color, vec3(1.0, 0.97, 0.91), floury);
	ALBEDO = color;
	// Little bumps, from how the texture changes across the screen.
	float rough_at = (noise3(p * 2.2) * 0.6 + noise3(p * 5.0) * 0.4) * bumps * 0.35 / grain;
	vec3 dx = dFdx(VERTEX);
	vec3 dy = dFdy(VERTEX);
	vec3 r1 = cross(dy, NORMAL);
	vec3 r2 = cross(NORMAL, dx);
	float det = dot(dx, r1);
	vec3 grad = sign(det) * (dFdx(rough_at) * r1 + dFdy(rough_at) * r2);
	vec3 n = normalize(abs(det) * NORMAL - grad * 2.2);
	NORMAL = n;
	ROUGHNESS = mix(0.9, 0.25, shine_amount);
	SPECULAR = mix(0.25, 0.5, shine_amount);
	EMISSION = emission_color.rgb * emission_energy;
	wet = clamp(max(shine_amount, (0.6 - roughness) * 0.9) * (1.0 - floury), 0.0, 1.0);
}

void light() {
	float facing = dot(NORMAL, LIGHT);
	float lit = smoothstep(0.0, 1.0, clamp((facing + soft) / (1.0 + soft), 0.0, 1.0)) * ATTENUATION;
	vec3 glow = vec3(lit);
	if (LIGHT_IS_DIRECTIONAL) {
		glow = mix(shadow_tint.rgb, vec3(1.0), lit);
	}
	float sheen = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5) * felt_sheen * max(lit, 0.35);
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * (glow + vec3(sheen));
	if (wet > 0.0) {
		float glint = pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), mix(14.0, 110.0, wet));
		SPECULAR_LIGHT += LIGHT_COLOR / PI * glint * wet * 1.6 * ATTENUATION * step(0.0, facing);
	}
}
