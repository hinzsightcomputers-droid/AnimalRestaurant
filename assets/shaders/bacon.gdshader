// A strip of bacon (CookPiece): lean and fat running along it, pink and limp,
// shrinking, curling into waves, and crisping as it cooks, glossy with its own
// grease. A unit box with plenty of segments, shaped here.
shader_type spatial;
render_mode cull_disabled;

uniform vec2 strip = vec2(0.2, 0.04);  // Length and width (m).
uniform float thickness = 0.008;
uniform float seed = 0.0;
uniform vec3 raw : source_color = vec3(0.93, 0.52, 0.52);
uniform vec3 done : source_color = vec3(0.7, 0.3, 0.18);
uniform vec3 fat_raw : source_color = vec3(0.98, 0.9, 0.86);
uniform vec3 fat_done : source_color = vec3(0.93, 0.7, 0.42);
uniform vec3 burnt : source_color = vec3(0.16, 0.1, 0.07);
uniform float up = 0.0;
uniform float down = 0.0;
uniform float cooked = 0.0;            // Both sides together.

varying vec3 at;
varying float top_side;

#include "res://assets/shaders/food_light.gdshaderinc"

float curl(vec2 p) {
	float crisp = clamp(cooked * 0.55, 0.0, 1.0);
	float wave = sin(p.x * 13.0 + seed + p.y * 1.5) * 0.6 + sin(p.x * 23.0 + seed * 2.0 - p.y * 3.0) * 0.25;
	float ends = smoothstep(0.32, 0.5, abs(p.x)) * 0.9;
	float sizzle = sin(TIME * 34.0 + p.x * 30.0) * 0.03 * smoothstep(0.1, 0.6, max(up, down)) * (1.0 - smoothstep(1.2, 1.6, max(up, down)));
	float lip = abs(p.y) * 2.0 * (0.5 + 0.5 * sin(p.x * 17.0 + seed * 1.3));
	return (0.5 + 0.5 * wave) * mix(0.25, 1.0, crisp) + (ends + lip * 0.5) * crisp + sizzle;
}

void vertex() {
	vec3 p = VERTEX;
	at = p;
	top_side = p.y;
	float shrink = mix(1.0, 0.86, clamp(cooked * 0.5, 0.0, 1.0));
	float uneven = 1.0 + 0.07 * sin(p.x * 11.0 + seed) + 0.05 * sin(p.x * 27.0 + seed * 3.0);
	float bow = 0.06 * sin(p.x * 5.0 + seed * 0.7) * clamp(cooked * 0.6, 0.0, 1.0);
	float lift = curl(p.xz) * 0.0085;
	float e = 0.02;
	vec2 slope = vec2(curl(p.xz + vec2(e, 0.0)) - curl(p.xz - vec2(e, 0.0)), curl(p.xz + vec2(0.0, e)) - curl(p.xz - vec2(0.0, e))) * 0.0085 / (2.0 * e) / strip;
	VERTEX = vec3(p.x * strip.x * shrink, (p.y + 0.5) * thickness * 0.75 + lift, (p.z * uneven + bow) * strip.y * mix(1.0, 0.92, clamp(cooked * 0.5, 0.0, 1.0)));
	if (abs(NORMAL.y) > 0.5) {
		NORMAL = normalize(vec3(-slope.x, 1.0, -slope.y)) * sign(NORMAL.y);
	}
}

void fragment() {
	float amount = top_side > 0.49 ? up : (top_side < -0.49 ? down : mix(down, up, top_side + 0.5));
	float along = at.x * strip.x / strip.y;
	// Fat runs along it in a couple of wandering streaks.
	float wander = food_fbm(vec2(along * 0.9 + seed, seed)) * 0.5;
	float streak = sin((at.z + wander * 0.5) * 11.0 + sin(along * 1.1 + seed) * 0.7);
	float fat = smoothstep(0.15, 0.55, streak + (food_fbm(vec2(along * 2.5, at.z * 9.0) + seed) - 0.5) * 0.7);
	fat = max(fat, smoothstep(0.4, 0.47, at.z + 0.04 * sin(along * 3.0 + seed)));
	float patchy = (food_fbm(vec2(along * 2.2, at.z * 4.0) + seed * 2.0) - 0.5) * 0.6 * smoothstep(0.1, 0.7, amount);
	float a = max(amount + patchy, 0.0);
	vec3 lean = mix(raw * (0.92 + 0.16 * food_fbm(vec2(along * 9.0, at.z * 5.0))), done, smoothstep(0.0, 1.0, a));
	vec3 white = mix(fat_raw, fat_done, smoothstep(0.15, 1.0, a));
	vec3 color = mix(lean, white, fat);
	color = mix(color, color * 0.62, smoothstep(0.42, 0.5, abs(at.z)) * smoothstep(0.5, 1.1, a) * 0.7);  // Crisp, darker edges.
	color = mix(color, burnt, smoothstep(1.35, 1.8, a) * 0.85);
	ALBEDO = color;
	float wet = mix(0.35, 0.9, smoothstep(0.15, 0.6, amount)) * (1.0 - smoothstep(1.1, 1.6, amount) * 0.6);
	ROUGHNESS = mix(0.7, 0.2, wet);
	SPECULAR = 0.5;
	shine = wet * 0.75;
}
