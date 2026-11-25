// A churro (CookPiece.make_churro): dough piped through a star tip, ridged along
// its length, rounded off at its ends, browning on the side that's down. The mesh
// is only a net (UV.x along it, UV.y round it), shaped here.
shader_type spatial;

uniform float half_length = 0.1;
uniform float thick = 0.012;           // From its middle to the tops of its ridges.
uniform float seed = 0.0;
uniform vec3 raw : source_color = vec3(0.85, 0.62, 0.36);
uniform vec3 done : source_color = vec3(0.84, 0.55, 0.27);
uniform vec3 brown : source_color = vec3(0.56, 0.31, 0.13);
uniform vec3 burnt : source_color = vec3(0.16, 0.1, 0.07);
uniform float up = 0.0;
uniform float down = 0.0;

varying vec3 at;
varying float ridge;

#include "res://assets/shaders/food_light.gdshaderinc"

const float RIDGES = 8.0;

vec3 shape(float u, float turn) {
	float x = (u * 2.0 - 1.0) * half_length;
	float end = clamp((half_length - abs(x)) / (thick * 1.1), 0.0, 1.0);
	float out_at = thick * sqrt(1.0 - (1.0 - end) * (1.0 - end));
	float twist = x * 5.0 + seed;
	out_at *= 1.0 - 0.15 * (0.5 - 0.5 * cos(turn * RIDGES + twist)) - 0.04 * sin(x * 90.0 + seed * 3.0);
	float wave = sin(x * 21.0 + seed) * 0.0022 + sin(x * 47.0 + seed * 2.0) * 0.0008;
	return vec3(x, thick * 0.96 + sin(turn) * out_at * 0.97, cos(turn) * out_at + wave);
}

void vertex() {
	float turn = UV.y * TAU;
	vec3 here = shape(UV.x, turn);
	vec3 along = shape(min(UV.x + 0.006, 1.0), turn) - shape(max(UV.x - 0.006, 0.0), turn);
	vec3 round_it = shape(UV.x, turn + 0.04) - shape(UV.x, turn - 0.04);
	vec3 n = cross(along, round_it);
	vec3 out_way = vec3(sign(UV.x - 0.5) * smoothstep(0.47, 0.5, abs(UV.x - 0.5)), sin(turn), cos(turn));
	n = length(n) < 1e-12 ? out_way : normalize(n);
	if (dot(n, out_way) < 0.0) {
		n = -n;
	}
	ridge = 0.5 + 0.5 * cos(turn * RIDGES + here.x * 5.0 + seed);
	at = here;
	VERTEX = here;
	NORMAL = n;
}

vec3 cooked(float amount) {
	if (amount < 1.0) {
		return mix(raw, done, pow(clamp(amount, 0.0, 1.0), 1.6));
	}
	if (amount < 1.4) {
		return mix(done, brown, (amount - 1.0) / 0.4);
	}
	return mix(brown, burnt, clamp((amount - 1.4) / 0.4, 0.0, 1.0));
}

void fragment() {
	float high = at.y / (thick * 2.0);
	float patchy = food_fbm(vec2(at.x * 70.0, at.z * 120.0 + at.y * 90.0) + seed) - 0.5;
	float amount = mix(down, up, smoothstep(0.25, 0.75, high + patchy * 0.25));
	amount = max(amount, min(up + down, 1.0) * 0.45);  // Its sides brown a little too.
	amount += (patchy * 0.35 + (ridge - 0.6) * 0.3) * smoothstep(0.15, 0.8, amount);
	vec3 color = cooked(max(amount, 0.0));
	color *= mix(0.8, 1.05, ridge);
	float crumb = food_noise(vec2(at.x * 420.0, at.z * 420.0 + at.y * 300.0));
	float crisp = smoothstep(0.4, 1.0, amount);
	NORMAL = normalize(NORMAL + vec3(dFdx(crumb), dFdy(crumb), 0.0) * 0.35 * crisp);
	ALBEDO = color * (0.96 + 0.08 * crumb);
	ROUGHNESS = 0.7;
	SPECULAR = 0.3;
	shine = mix(0.25, 0.4 * ridge, crisp);
}
