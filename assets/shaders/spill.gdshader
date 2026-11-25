// A spill on a table (WipeAction): a glossy puddle with an uneven, rounded edge
// that breaks up and goes as it's rubbed (left: 1 all of it, 0 gone); or, with
// film, the thin wet streak a cloth leaves, drying from its edges.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 spill : source_color = vec3(0.5, 0.28, 0.12);
uniform float left = 1.0;
uniform float seed = 0.0;
uniform float film = 0.0;

varying vec2 at;

#include "res://assets/shaders/food_light.gdshaderinc"

float deep(vec2 p) {
	float around = atan(p.y, p.x);
	float out_at = 0.72 + 0.1 * sin(around * 3.0 + seed) + 0.07 * sin(around * 5.0 + seed * 2.1) + 0.04 * sin(around * 9.0 + seed * 3.7);
	float body = out_at - length(p);
	float broken = (food_fbm(p * 4.5 + seed) - 0.5) * 1.5 + 0.25;
	return min(body, 0.35) - (1.0 - left) * (0.55 + broken);
}

void vertex() {
	at = UV * 2.0 - 1.0;
}

void fragment() {
	float d = deep(at);
	float e = 0.02;
	vec2 slope = vec2(deep(at + vec2(e, 0.0)) - deep(at - vec2(e, 0.0)), deep(at + vec2(0.0, e)) - deep(at - vec2(0.0, e))) / (2.0 * e);
	float rim = smoothstep(0.16, 0.0, d);
	vec3 normal = normalize(vec3(-slope.x * rim * 0.9, 1.0, -slope.y * rim * 0.9));
	float alpha = smoothstep(0.0, 0.03, d);
	if (film > 0.5) {
		float gap = 1.0 - max(abs(at.x), abs(at.y));
		alpha = smoothstep(0.0, 0.5, gap - (1.0 - left) * (0.6 + 0.6 * food_fbm(at * 4.0 + seed))) * 0.3;
		normal = normalize(vec3((food_noise(at * 9.0 + seed) - 0.5) * 0.3, 1.0, (food_noise(at * 9.0 - seed) - 0.5) * 0.3));
	}
	ALBEDO = spill * mix(1.0, 0.8, rim);
	ALPHA = alpha * mix(0.92, 1.0, film);
	NORMAL = normalize(mat3(VIEW_MATRIX) * (MODEL_NORMAL_MATRIX * normal));
	ROUGHNESS = 0.12;
	SPECULAR = 0.5;
	shine = 0.9;
}
