// A round piece of food on the griddle (CookPiece): batter that's poured,
// spreads, jiggles, rises, sets from its edge in, bubbles, and browns in
// patches; or an egg white. The mesh is only a net (UV.x: from the middle of the
// bottom, round the side, to the middle of the top; UV.y: round it): its shape is
// made here from its radius and thickness.
shader_type spatial;
render_mode cull_disabled;

uniform float radius = 0.1;
uniform float thickness = 0.022;
uniform vec2 stretch = vec2(1.0);
uniform float seed = 0.0;
uniform float mirror = 1.0;            // -1 once it's been turned over.
uniform float edge = 1.0;              // How uneven its outline is.
uniform float rise = 0.6;              // How tall it stands (1: thickness).
uniform vec2 tilt = vec2(0.0);         // Jiggling: up at the rim along x and z (m)...
uniform float heave = 0.0;             // ...and up in the middle.
uniform float bend = 0.0;              // Its sides drooping (m at the rim): off a spatula.
uniform float ripple = 0.0;            // Rings from a stream landing in the middle.
uniform float mound = 0.0;             // Heaped in the middle while it's being poured (m).
uniform float flat_egg = 0.0;          // 1: an egg white, thin at its edge.

uniform vec3 raw : source_color = vec3(0.96, 0.88, 0.66);
uniform vec3 done : source_color = vec3(0.84, 0.55, 0.27);
uniform vec3 brown : source_color = vec3(0.56, 0.31, 0.13);
uniform vec3 burnt : source_color = vec3(0.16, 0.1, 0.07);
uniform float up = 0.0;                // How cooked each side is.
uniform float down = 0.0;
uniform float up_seed = 0.0;           // Each side's own pattern.
uniform float down_seed = 5.0;
uniform float up_holes = 1.0;          // 1: the side facing up is the one that bubbled.
uniform float bubbles = 1.0;           // How much it bubbles at all.
uniform float bubbled = 0.0;           // How far the bubbling got (the first side's doneness).

varying vec2 at;       // x and z across it (-1..1).
varying float height;  // 0 at the bottom, 1 at the top.
varying vec3 local_normal;

#include "res://assets/shaders/food_light.gdshaderinc"

vec3 shape(float s, float turn) {
	vec2 way = vec2(cos(turn), sin(turn));
	float around = atan(way.y * mirror, way.x);
	float uneven = 0.011 * sin(around * 3.0 + seed) + 0.009 * sin(around * 5.0 + seed * 2.3) + 0.006 * sin(around * 8.0 + seed * 4.1) + flat_egg * (0.035 * sin(around * 2.0 + seed * 1.7) + 0.018 * sin(around * 13.0 + seed));
	float r = radius * (1.0 + edge * uneven);
	float tall = thickness * rise;
	float bulge = min(tall * 0.5, r * 0.45);
	float out_at;
	float y;
	if (s < 0.4) {
		out_at = (r - bulge) * s / 0.4;
		y = 0.0;
	} else if (s < 0.62) {
		float phi = mix(-PI * 0.5, PI * 0.5, (s - 0.4) / 0.22);
		out_at = r - bulge + bulge * cos(phi);
		y = tall * (0.5 + 0.5 * sin(phi));
	} else {
		float t = (s - 0.62) / 0.38;
		out_at = (r - bulge) * (1.0 - t);
		y = tall;
	}
	float u = out_at / max(r, 0.0001);
	float h = y / max(tall, 0.0001);
	vec2 p = way * u;
	y *= mix(1.0, 0.28 + 0.9 * (1.0 - u * u), flat_egg);
	float wave = dot(tilt, p) * (1.5 - 0.5 * u * u) + heave * (1.0 - 2.0 * u * u) + ripple * sin(u * 16.0 - TIME * 24.0) * (1.0 - u) + mound * exp(-u * u * 9.0);
	y += wave * h * h;
	y -= bend * (p.x * p.x * 0.8 + p.y * p.y * 0.35);
	return vec3(way.x * out_at * stretch.x, y, way.y * out_at * stretch.y);
}

void vertex() {
	float s = UV.x;
	float turn = UV.y * TAU;
	vec3 here = shape(s, turn);
	vec3 along = shape(min(s + 0.012, 1.0), turn) - shape(max(s - 0.012, 0.0), turn);
	vec3 round_it = shape(s, turn + 0.03) - shape(s, turn - 0.03);
	vec3 n = cross(round_it, along);
	// Outward: up on top, down underneath, out at the side.
	vec3 out_way = s < 0.4 ? vec3(0.0, -1.0, 0.0) : (s > 0.62 ? vec3(0.0, 1.0, 0.0) : vec3(cos(turn) * cos((s - 0.51) / 0.11 * 1.5708), sin((s - 0.51) / 0.11 * 1.5708), sin(turn) * cos((s - 0.51) / 0.11 * 1.5708)));
	if (length(n) < 1e-10) {
		n = out_way;
	}
	n = normalize(n);
	if (dot(n, out_way) < 0.0) {
		n = -n;
	}
	at = vec2(here.x / stretch.x, here.z / stretch.y * mirror) / max(radius, 0.0001);
	height = s < 0.4 ? 0.0 : (s > 0.62 ? 1.0 : (s - 0.4) / 0.22);
	local_normal = n;
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

// A griddled face: patchy, a deeper ring where it touched best, a paler rim.
vec3 face(float amount, float own) {
	float r = length(at);
	float patchy = food_fbm(at * 5.0 + own * 3.7) - 0.5;
	float lace = food_fbm(at * 15.0 + own) - 0.5;
	float start = smoothstep(0.15, 0.8, amount);
	float a = amount + (patchy * 0.5 + lace * 0.22) * start;
	a += 0.12 * smoothstep(0.55, 0.82, r) * (1.0 - smoothstep(0.84, 0.93, r)) * start;
	a -= 0.4 * smoothstep(0.88, 1.0, r) * start;
	return cooked(max(a, 0.0));
}

void fragment() {
	float r = length(at);
	vec3 top = face(up, up_seed);
	vec3 bottom = face(down, down_seed);
	vec3 normal = normalize(local_normal);
	vec3 side_color = mix(raw, mix(raw, done, 0.22) * 1.02, clamp(down + up, 0.0, 1.0));
	vec3 color;
	float shiny = 0.12;
	if (flat_egg > 0.5) {
		// An egg white: grey and see-through, setting white from the outside in, with a brown lacy edge.
		float front = mix(1.25, -0.3, clamp(down * 1.25, 0.0, 1.0));
		float set_here = smoothstep(front - 0.2, front + 0.25, r);
		vec3 wet = mix(raw, vec3(0.46, 0.43, 0.38), 0.45 * smoothstep(0.3, 1.0, r));
		color = mix(wet, done * (0.88 + 0.09 * food_fbm(at * 3.5 + seed)), set_here);
		float lacy = smoothstep(0.83, 1.02, r + (food_fbm(at * 13.0 + seed) - 0.5) * 0.22) * smoothstep(0.55, 1.1, down);
		color = mix(color, mix(vec3(0.82, 0.55, 0.24), brown, clamp(down - 0.9, 0.0, 1.0)), lacy * 0.9);
		color = mix(color, brown, smoothstep(1.35, 1.8, down) * 0.6);
		float lumps = food_fbm(at * 9.0 + seed);
		normal = normalize(normal + vec3(dFdx(lumps), 0.0, dFdy(lumps)) * 0.5 * set_here);
		shiny = mix(0.85, 0.4, set_here);
	} else if (normal.y > 0.2 || height > 0.8) {
		// Facing up. While its other side cooks it sets from the edge in: wet and glossy, then dull.
		float front = mix(1.15, -0.25, clamp((bubbled - 0.2) / 0.95, 0.0, 1.0));
		float is_set = up_holes > 0.5 ? smoothstep(front - 0.12, front + 0.16, r + (food_fbm(at * 6.0 + up_seed) - 0.5) * 0.2) : 1.0;
		color = top;
		if (up_holes > 0.5) {
			color = mix(top, mix(top, raw * vec3(0.93, 0.87, 0.74), 0.55), is_set);  // Dull, a touch darker, once it's set.
			shiny = mix(0.85, 0.06, is_set);
			color *= mix(1.0, 0.9, smoothstep(0.7, 1.0, r));  // Thinner, and it's dark underneath, toward its edge.
			vec2 grid = at * 4.6;
			vec2 cell = floor(grid);
			for (int i = -1; i <= 1; i++) {
				for (int j = -1; j <= 1; j++) {
					vec2 c = cell + vec2(float(i), float(j));
					float chance = food_hash(c + up_seed);
					if (chance > 0.78 * bubbles) {
						continue;
					}
					vec2 spot = c + 0.5 + (vec2(food_hash(c + 3.1 + up_seed), food_hash(c + 7.7 + up_seed)) - 0.5) * 0.7;
					if (length(spot / 4.6) > 0.9) {
						continue;
					}
					float birth = 0.34 + 0.5 * food_hash(c + 11.3 + up_seed) + 0.12 * (1.0 - length(spot / 4.6));
					float life = (bubbled - birth) / 0.16;
					if (life < 0.0) {
						continue;
					}
					float size = (0.13 + 0.19 * food_hash(c + 5.9)) * min(life * 1.4, 1.0);
					vec2 off = grid - spot;
					float d = length(off);
					vec2 dir = off / max(d, 0.0001);
					if (life < 1.0) {  // A bubble swelling: a shiny dome.
						float dome = smoothstep(size, size * 0.6, d);
						normal = normalize(mix(normal, vec3(dir.x * 0.9 * (d / size), 0.75, dir.y * 0.9 * (d / size) * mirror), dome * 0.9));
						color = mix(color, raw * 1.04, dome * 0.5);
						color *= 1.0 - 0.45 * smoothstep(size * 1.3, size, d) * smoothstep(size * 0.75, size, d);
						shiny = max(shiny, dome * 0.9);
					} else {  // Popped: a little hole, staying open once the batter round it has set.
						float hole = size * 0.75;
						float inside = smoothstep(hole, hole * 0.55, d);
						color *= 1.0 - 0.55 * inside * mix(0.6, 1.0, is_set);
						float lip = smoothstep(hole * 1.5, hole, d) * smoothstep(hole * 0.5, hole, d);
						normal = normalize(normal - vec3(dir.x, 0.0, dir.y * mirror) * lip * 0.9);
						color = mix(color, raw * 1.03, lip * 0.2);
					}
				}
			}
		} else {
			float crumb = food_fbm(at * 34.0 + up_seed);
			normal = normalize(normal + vec3(dFdx(crumb), 0.0, dFdy(crumb)) * 0.8);
			shiny = 0.1 + 0.18 * smoothstep(0.7, 1.1, up);  // A buttery sheen on the golden side.
		}
	} else if (normal.y < -0.2) {
		color = bottom;
		shiny = 0.2;
	} else {
		float around = food_fbm(vec2(atan(at.y, at.x) * 6.0, height * 3.0) + seed);
		color = side_color * (0.92 + 0.16 * around);
		color = mix(color, bottom, smoothstep(0.36, 0.08, height) * 0.95);
		color = mix(color, top, smoothstep(0.72, 0.98, height) * 0.9);
		shiny = mix(0.5, 0.06, clamp((down + up) * 1.4, 0.0, 1.0));
	}
	ALBEDO = color * mix(0.82, 1.0, smoothstep(0.0, 0.5, height)) * mix(0.88, 1.0, clamp(up, 0.0, 1.0));
	NORMAL = normalize(mat3(VIEW_MATRIX) * (MODEL_NORMAL_MATRIX * normal));
	ROUGHNESS = mix(0.9, 0.2, shiny);
	SPECULAR = mix(0.2, 0.5, shiny);
	shine = shiny;
}
