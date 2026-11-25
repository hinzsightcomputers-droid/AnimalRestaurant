// A liquid in a pot or bowl (CookSurface), seen from above: a round net whose
// surface rocks, dips in the middle as it's stirred, and rings out from whatever
// lands in it. Its color swirls round with the stirring; it can simmer (bubbles
// swelling and popping), have a skin of oil or foam, and be see-through (water).
shader_type spatial;
render_mode cull_disabled, depth_draw_always;

uniform vec3 soup : source_color = vec3(0.93, 0.6, 0.3);
uniform float radius = 0.12;
uniform vec2 tilt = vec2(0.0);       // Up at the rim along x and z (m).
uniform vec2 saddle = vec2(0.0);     // Up along one way and down along the other (m).
uniform float heave = 0.0;           // Up in the middle (m).
uniform float dip = 0.0;             // The hollow stirring makes (m).
uniform float turn = 0.0;            // How far it's swirled round (radians)...
uniform float twist = 0.0;           // ...and how much its streaks trail.
uniform vec4 drop_a = vec4(0.0);     // Something landing: x, z (-1..1), seconds since, how hard (m).
uniform vec4 drop_b = vec4(0.0);
uniform vec4 drop_c = vec4(0.0);
uniform vec4 drop_d = vec4(0.0);
uniform float boil = 0.0;            // 0 still, 0.4 a simmer, 1 a rolling boil.
uniform float oil = 0.0;             // Golden eyes of oil floating on it.
uniform float foam = 0.0;            // Froth gathered at the rim.
uniform float clear = 0.0;           // 1: water.
uniform float thick = 0.0;           // 1: a batter: the marks of the whisk stay in it.
uniform float glossy = 0.75;

varying vec2 at;

#include "res://assets/shaders/food_light.gdshaderinc"

float ring(vec2 p, vec4 drop) {
	if (drop.w <= 0.0 || drop.z > 1.6) {
		return 0.0;
	}
	float d = distance(p, drop.xy);
	float front = drop.z * 1.5;
	float wave = sin((d - front) * 24.0) * exp(-pow((d - front) * 5.0, 2.0));
	return drop.w * (wave * exp(-drop.z * 2.6) - 1.3 * exp(-d * d * 90.0 - drop.z * 13.0));
}

float lift(vec2 p) {
	float r2 = dot(p, p);
	float y = dot(tilt, p) * (1.5 - 0.5 * r2) + heave * (1.0 - 2.0 * r2) + saddle.x * (p.x * p.x - p.y * p.y) + saddle.y * 2.0 * p.x * p.y;
	y -= dip * (exp(-r2 * 4.0) - 0.45);
	y += ring(p, drop_a) + ring(p, drop_b) + ring(p, drop_c) + ring(p, drop_d);
	y += boil * boil * 0.0032 * (food_noise(p * 4.0 + vec2(TIME * 2.1, -TIME * 1.3)) - 0.5) * 2.0;
	return y;
}

void vertex() {
	vec2 p = VERTEX.xz;
	at = p;
	float e = 0.035;
	float dx = lift(p + vec2(e, 0.0)) - lift(p - vec2(e, 0.0));
	float dz = lift(p + vec2(0.0, e)) - lift(p - vec2(0.0, e));
	VERTEX = vec3(p.x * radius, max(lift(p), -0.1 * radius), p.y * radius);
	NORMAL = normalize(vec3(-dx, 2.0 * e * radius, -dz));
}

void fragment() {
	float r = length(at);
	// Turned with the stirring, the middle ahead of the rim.
	float a = -turn - twist * (1.0 - r);
	vec2 q = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * at;
	float swirl = food_fbm(vec2(dot(q, vec2(1.0, 0.0)) * 3.0 + q.y * q.y * 2.0, q.y * 6.0) + r * 1.5) - 0.5;
	vec3 color = soup * (1.0 + swirl * mix(0.3, 0.16, thick) * (1.0 - clear * 0.6));
	color = mix(color, soup * 0.7, smoothstep(0.78, 1.0, r) * mix(0.8, 0.35, thick));  // Deeper against the pot.
	vec3 normal = NORMAL;
	float wet = glossy;
	if (thick > 0.0) {  // The ridges the whisk leaves, trailing round.
		float lines = sin((r * 26.0 + atan(q.y, q.x) * 2.0 + swirl * 3.0));
		normal = normalize(normal + vec3(dFdx(lines), dFdy(lines), 0.0) * 0.5 * thick * clamp(abs(twist) * 0.6, 0.15, 1.0) * smoothstep(1.0, 0.8, r));
	}
	if (oil > 0.0) {
		vec2 grid = q * 5.0;
		vec2 cell = floor(grid);
		float seed = food_hash(cell);
		vec2 spot = vec2(food_hash(cell + 3.3), food_hash(cell + 8.1)) * 0.5 + 0.25;
		float size = 0.07 + 0.15 * food_hash(cell + 1.2);
		float d = length(fract(grid) - spot);
		float eye = smoothstep(size, size - 0.03, d) * step(0.5, seed) * step(length(cell + 0.5), 4.5);
		float rim = smoothstep(size, size - 0.035, d) * smoothstep(size - 0.08, size - 0.03, d) * step(0.5, seed) * step(length(cell + 0.5), 4.5);
		color = mix(color, vec3(1.0, 0.8, 0.32), eye * 0.35 * oil);
		color += vec3(1.0, 0.85, 0.5) * rim * 0.28 * oil;
	}
	float alpha = mix(1.0, 0.52, clear);
	if (boil > 0.0) {
		// Bubbles: each cell's swells, stands as a shiny dome, and pops to a ring.
		for (int layer = 0; layer < 2; layer++) {
			float many = layer == 0 ? 3.6 : 6.5;
			vec2 grid = at * many + float(layer) * 5.7;
			vec2 base = floor(grid);
			for (int i = -1; i <= 1; i++) {
				for (int j = -1; j <= 1; j++) {
					vec2 c = base + vec2(float(i), float(j));
					float seed = food_hash(c + float(layer));
					float rate = (0.35 + 0.5 * seed) * mix(0.8, 2.6, boil);
					float t = TIME * rate + seed * 17.0;
					float life = fract(t);
					float round_no = floor(t);
					if (food_hash(c + round_no * 1.7) > 0.12 + boil * 0.75) {
						continue;
					}
					vec2 spot = c + 0.5 + (vec2(food_hash(c + round_no + 2.2), food_hash(c - round_no + 6.4)) - 0.5) * 0.7;
					if (length((spot - float(layer) * 5.7) / many) > 0.88) {
						continue;
					}
					float size = (0.2 + 0.24 * food_hash(c + round_no * 3.1)) * smoothstep(0.0, 0.7, life);
					vec2 off = grid - spot;
					float d = length(off);
					vec2 dir = off / max(d, 0.001);
					if (life < 0.75) {
						float dome = smoothstep(size, size * 0.85, d);
						vec3 up = normalize(vec3(dir.x * d / max(size, 0.01) * 1.1, 0.8, dir.y * d / max(size, 0.01) * 1.1));
						normal = normalize(mix(normal, mat3(VIEW_MATRIX) * (MODEL_NORMAL_MATRIX * up), dome * 0.85));
						float skin = smoothstep(size, size * 0.9, d) * smoothstep(size * 0.6, size * 0.95, d);
						color = mix(color, mix(soup * 1.25, vec3(1.0), clear * 0.7), dome * 0.22 + skin * 0.35);
						alpha = mix(alpha, 0.8, skin * 0.6);
						wet = max(wet, dome);
					} else {
						float pop = (life - 0.75) / 0.25;
						float out_at = size * (1.0 + pop * 0.8);
						float edge = smoothstep(0.09, 0.0, abs(d - out_at)) * (1.0 - pop);
						color = mix(color, mix(soup * 1.3, vec3(1.0), clear * 0.7), edge * 0.45);
					}
				}
			}
		}
	}
	if (foam > 0.0) {
		float froth = smoothstep(1.0 - 0.3 * foam, 1.0, r + (food_fbm(q * 9.0) - 0.5) * 0.3);
		float beads = food_noise(q * 34.0);
		color = mix(color, mix(soup * 1.2, vec3(1.0, 0.97, 0.9), 0.65) * (0.88 + 0.2 * beads), froth * 0.8);
		alpha = mix(alpha, 0.95, froth * 0.8);
		wet = mix(wet, 0.2, froth);
	}
	ALBEDO = color;
	NORMAL = normal;
	ROUGHNESS = mix(0.8, 0.12, wet);
	SPECULAR = mix(0.2, 0.55, wet);
	// The kitchen's light in it, where it's seen along.
	EMISSION = vec3(1.0, 0.95, 0.85) * pow(1.0 - clamp(dot(normal, VIEW), 0.0, 1.0), 3.5) * 0.22 * wet;
	ALPHA = alpha;
	shine = wet;
}
