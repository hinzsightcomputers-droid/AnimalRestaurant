// Oak: long straight grain that swirls into cathedral arches, dark open pores
// drawn out along it, pale flecks across it, and (optionally) knife marks. Cooler
// and browner than the kitchen's honey wood, so food stands out on it. Works on
// any mesh, from its own (scaled) position: the grain runs along x.
shader_type spatial;

uniform vec3 light_wood : source_color = vec3(0.64, 0.53, 0.4);
uniform vec3 dark_wood : source_color = vec3(0.4, 0.31, 0.22);
uniform float staves = 0.0;          // Strips glued side by side, this wide (m; 0: one piece).
uniform float figure = 1.0;          // How much its rings and pores show (thin sticks: little).
uniform float knife_marks = 0.0;     // 0..1: pale scratches from chopping.

varying vec3 local_pos;
varying vec3 local_normal;

void vertex() {
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	local_pos = VERTEX * scale;
	local_normal = NORMAL;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x), mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.1 + 7.3) * 0.3 + noise(p * 4.3 + 1.9) * 0.15;
}

void fragment() {
	vec3 p = local_pos;
	p.z += p.y * 0.7;  // The grain carries on down its sides.
	float tone = 0.0;
	float seam = 0.0;
	float row = 0.0;
	if (staves > 0.0) {
		row = floor(p.z / staves);
		tone = hash(vec2(row, 3.0)) - 0.5;
		p.x += hash(vec2(row, 9.0)) * 5.0;
		float edge = abs(fract(p.z / staves) - 0.5) * 2.0;
		float soft = fwidth(p.z / staves) * 2.0;
		seam = smoothstep(0.97 - soft, 1.0, edge);
	}
	// Growth rings, sawn through: far apart and arched in places, tight in others.
	vec2 q = vec2(p.x * 1.6, p.z * 9.0);
	float bend = fbm(q + row * 13.0) * 1.1 + fbm(vec2(p.x * 5.0, p.z * 26.0)) * 0.25;
	float rings = fract((p.z * 22.0 + bend * 2.6 + p.x * 0.8));
	float late = smoothstep(0.15, 0.85, rings) * smoothstep(1.0, 0.93, rings);
	// Pores: short dark dashes along the grain, most of them at the rings.
	vec2 fine = vec2(p.x * 38.0, p.z * 620.0);
	float dash = smoothstep(0.62, 0.86, noise(fine + vec2(noise(vec2(p.z * 300.0, 1.0)) * 9.0, 0.0)));
	float pores = dash * mix(0.25, 1.0, smoothstep(0.35, 0.8, late));
	// Flecks: the pale rays quarter-sawn oak shows.
	float fleck = smoothstep(0.8, 0.95, noise(vec2(p.x * 42.0 + p.z * 60.0, p.z * 170.0))) * 0.5;
	vec3 base = mix(light_wood, dark_wood, clamp(late * 0.42 * figure + tone * 0.35 + (fbm(vec2(p.x * 3.0, p.z * 12.0)) - 0.5) * 0.35 + (1.0 - figure) * 0.3, 0.0, 1.0));
	base = mix(base, dark_wood * 0.72, pores * 0.5 * figure);
	base = mix(base, light_wood * 1.12, fleck * (1.0 - late) * 0.6);
	base = mix(base, dark_wood * 0.6, seam * 0.55);
	if (knife_marks > 0.0 && local_normal.y > 0.5) {
		float marks = 0.0;
		for (int i = 0; i < 2; i++) {
			float turn = i == 0 ? 0.18 : -0.3;
			vec2 m = mat2(vec2(cos(turn), sin(turn)), vec2(-sin(turn), cos(turn))) * local_pos.xz;
			vec2 cell = floor(m * vec2(130.0, 9.0));
			vec2 f = fract(m * vec2(130.0, 9.0));
			float there = step(0.86, hash(cell + float(i) * 17.0));
			marks = max(marks, there * smoothstep(0.35, 0.1, abs(f.x - 0.5)) * smoothstep(0.0, 0.25, f.y) * smoothstep(1.0, 0.7, f.y));
		}
		base = mix(base, light_wood * 1.18, marks * knife_marks * 0.4);
	}
	ALBEDO = base;
	ROUGHNESS = 0.72 + 0.1 * pores;
	SPECULAR = 0.28;
}
