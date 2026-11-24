// A drink in its glass (DrinkModel): a unit cylinder (radius 1, height 1)
// shaped here to the glass, its top surface tilting, rocking and rippling. The
// numbers that move it come from DrinkModel's springs, so every vertex of the
// surface, and the sides under it, follows. Bubbles rise through a fizzy one,
// and it can have a head of foam.
shader_type spatial;
render_mode depth_draw_always, cull_back;

uniform vec3 drink : source_color = vec3(0.4, 0.2, 0.1);
uniform float alpha = 1.0;
uniform float level = 0.12;            // How high it's filled (m).
uniform float glass_height = 0.16;
uniform vec2 radii = vec2(0.042, 0.05); // The drink's radius at the bottom and at glass_height.
uniform vec2 tilt = vec2(0.0);         // How far the surface is up at the rim, along x and z.
uniform vec2 saddle = vec2(0.0);       // Up along one way and down along the other.
uniform float heave = 0.0;             // Up in the middle, down at the rim.
uniform float ripple = 0.0;            // Rings running out from the middle (a stream landing in it).
uniform float fizz = 0.0;
uniform float foam = 0.0;              // How deep its head is (m).
uniform vec3 foam_color : source_color = vec3(1.0, 0.95, 0.85);

varying vec3 at;       // x and z across the glass (-1..1), y in meters.
varying float surface; // How high the surface is here.
varying float is_top;

float wave(vec2 p) {
	float r2 = dot(p, p);
	float rock = dot(tilt, p) * (1.5 - 0.5 * r2);
	float sides = saddle.x * (p.x * p.x - p.y * p.y) + saddle.y * 2.0 * p.x * p.y;
	float rings = ripple * sin(sqrt(r2) * 17.0 - TIME * 26.0) * (1.0 - 0.7 * r2);
	return rock + sides + heave * (1.0 - 2.0 * r2) + rings;
}

void vertex() {
	vec2 p = VERTEX.xz;
	is_top = UV.x;
	surface = clamp(level + wave(p), 0.003, glass_height * 0.99);
	float y = VERTEX.y * surface;
	float radius = mix(radii.x, radii.y, clamp(y / glass_height, 0.0, 1.0));
	at = vec3(p.x, y, p.y);
	VERTEX = vec3(p.x * radius, y, p.y * radius);
	if (is_top > 0.5) {
		float e = 0.06;
		float dx = wave(p + vec2(e, 0.0)) - wave(p - vec2(e, 0.0));
		float dz = wave(p + vec2(0.0, e)) - wave(p - vec2(0.0, e));
		NORMAL = normalize(vec3(-dx, 2.0 * e * radius, -dz));
	} else if (is_top > -0.5) {
		NORMAL = normalize(vec3(p.x, 0.0, p.y));
	}
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 color = drink;
	float below = surface - at.y;
	if (is_top > 0.5) {
		float r = length(at.xz);
		color = mix(drink * 1.16, drink * 0.82, smoothstep(0.7, 1.0, r));  // Deeper against the glass.
		float crest = clamp((at.y - level) / 0.012, -1.0, 1.0);
		color *= 1.0 + 0.16 * crest;                                       // The high side catches the light.
		if (fizz > 0.0) {
			vec2 cell = floor(at.xz * 7.0);
			vec2 inside = fract(at.xz * 7.0) - 0.5;
			float seed = hash(cell);
			float life = fract(TIME * (0.9 + seed) + seed * 9.0);
			float d = length(inside - (vec2(hash(cell + 2.3), hash(cell + 5.9)) - 0.5) * 0.5);
			color = mix(color, vec3(1.0), smoothstep(life * 0.3, life * 0.3 - 0.1, d) * (1.0 - life) * 0.55 * fizz);
		}
		if (foam > 0.0) {
			float lumps = hash(floor((at.xz + 2.0) * 13.0)) * 0.1;
			color = foam_color * (0.9 + lumps);
		}
	} else {
		color = drink * mix(0.72, 1.06, smoothstep(0.0, max(surface, 0.02), at.y));
		float line = smoothstep(0.0035, 0.0012, below);                    // The bright edge where the surface meets the glass.
		color = mix(color, drink * 1.3 + 0.08, line);
		if (fizz > 0.0) {
			float around = atan(at.z, at.x) * 5.0;
			vec2 grid = vec2(around, at.y * 130.0 - TIME * 7.0);
			vec2 cell = floor(grid);
			float seed = hash(cell);
			float d = length(fract(grid) - vec2(0.3 + 0.4 * hash(cell + 1.7), 0.5));
			color = mix(color, drink * 1.5 + 0.2, smoothstep(0.26, 0.14, d) * step(0.72, seed) * fizz * 0.8);
		}
		if (foam > 0.0) {
			float edge = foam * (0.9 + 0.2 * sin(atan(at.z, at.x) * 9.0));
			color = mix(color, foam_color * 0.96, smoothstep(edge + 0.001, edge - 0.001, below));
		}
	}
	ALBEDO = color;
	ROUGHNESS = is_top > 0.5 && foam <= 0.0 ? 0.12 : 0.8;
	SPECULAR = is_top > 0.5 ? 0.6 : 0.1;  // (The glass has the shine, down the sides.)
	ALPHA = alpha;
}
