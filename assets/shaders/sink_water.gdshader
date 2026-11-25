// Soapy dishwater in the sink (WashAction): cloudy blue, rolling gently, rings
// running out from whatever moves in it, a soap film swirling on top and froth
// gathered along its edges. On a flat net.
shader_type spatial;
render_mode cull_disabled, depth_draw_always, blend_mix;

uniform vec3 water : source_color = vec3(0.6, 0.8, 0.93);
uniform vec2 size = vec2(0.4, 0.3);
uniform vec4 ring_a = vec4(0.0);      // x, z (m from the middle), seconds since, how hard (m).
uniform vec4 ring_b = vec4(0.0);
uniform vec4 ring_c = vec4(0.0);
uniform vec4 ring_d = vec4(0.0);
uniform float stirred = 0.0;

varying vec2 at;

#include "res://assets/shaders/food_light.gdshaderinc"

float ring(vec2 p, vec4 r) {
	if (r.w <= 0.0 || r.z > 1.6) {
		return 0.0;
	}
	float d = distance(p, r.xy);
	float front = r.z * 0.28;
	return r.w * sin((d - front) * 130.0) * exp(-pow((d - front) * 26.0, 2.0)) * exp(-r.z * 2.2);
}

float lift(vec2 p) {
	float y = 0.0012 * (1.0 + 3.0 * stirred) * (food_noise(p * 14.0 + vec2(TIME * 0.6, -TIME * 0.4)) + food_noise(p * 31.0 - vec2(TIME * 0.9, TIME * 0.5)) * 0.5 - 0.75);
	return clamp(y + ring(p, ring_a) + ring(p, ring_b) + ring(p, ring_c) + ring(p, ring_d), -0.01, 0.012);
}

void vertex() {
	at = VERTEX.xz;
	float e = 0.005;
	float dx = lift(at + vec2(e, 0.0)) - lift(at - vec2(e, 0.0));
	float dz = lift(at + vec2(0.0, e)) - lift(at - vec2(0.0, e));
	VERTEX.y += lift(at);
	NORMAL = normalize(vec3(-dx, 2.0 * e, -dz));
}

void fragment() {
	vec2 q = at * 12.0 + vec2(food_fbm(at * 8.0 + TIME * 0.05), food_fbm(at * 8.0 - TIME * 0.06)) * 2.0;
	float film = food_fbm(q);
	vec3 color = water * (0.9 + 0.22 * film);
	// A touch of rainbow in the soap.
	color += 0.05 * vec3(sin(film * 14.0), sin(film * 14.0 + 2.1), sin(film * 14.0 + 4.2));
	vec2 half_size = size * 0.5;
	vec2 in_from = half_size - abs(at);
	float edge = min(in_from.x, in_from.y);
	float lumpy = food_noise(at * 60.0) * 0.6 + food_noise(at * 130.0) * 0.4;
	float froth = smoothstep(0.05, 0.004, edge + (food_fbm(at * 22.0 + TIME * 0.03) - 0.5) * 0.06);
	froth = max(froth, smoothstep(0.62, 0.72, food_fbm(at * 16.0 + vec2(TIME * 0.04, TIME * 0.02))));
	color = mix(color, vec3(0.97, 0.985, 1.0) * (0.84 + 0.2 * lumpy), froth * 0.92);
	float crest = dot(NORMAL, vec3(0.0, 1.0, 0.0));
	ALBEDO = color;
	EMISSION = color * 0.16;
	ROUGHNESS = mix(0.12, 0.7, froth);
	SPECULAR = 0.5;
	ALPHA = mix(0.86, 0.98, froth);
	shine = mix(0.85, 0.15, froth) * clamp(crest + 0.4, 0.3, 1.0);
}
