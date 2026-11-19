// A soup's (or sauce's) surface in a pot: glossy, with a slow swirl of lighter
// and darker bands, a darker edge where it meets the pot, and a few soft
// bubbles that rise and pop (the style guide: food is the brightest, most
// appetizing thing; warm and soft, no harsh detail). On a flat disc; the
// swirl and bubbles are from the disc's own position, so any size works.
shader_type spatial;

uniform vec3 soup : source_color = vec3(0.93, 0.6, 0.3);
uniform float radius = 0.12;        // The disc's radius (m).
uniform float swirl_speed = 0.35;
uniform float bubbles = 1.0;        // 0: none (cold), 1: a gentle simmer.

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = local_pos.xz / max(radius, 0.001);   // -1..1 across.
	float r = length(p);
	float angle = atan(p.y, p.x);
	// A slow swirl: bands that wind round the middle.
	float band = sin(angle * 2.0 + r * 9.0 - TIME * swirl_speed * 3.0) * 0.5 + 0.5;
	vec3 color = mix(soup * 0.9, soup * 1.12, smoothstep(0.35, 0.9, band) * 0.6);
	// A darker edge, where it's deeper against the pot.
	color = mix(color, soup * 0.72, smoothstep(0.72, 1.0, r));
	// Bubbles: a few cells each with a bubble that grows and pops in turn.
	float bubble = 0.0;
	if (bubbles > 0.0) {
		vec2 cell_pos = p * 3.2;
		vec2 cell = floor(cell_pos);
		vec2 in_cell = fract(cell_pos) - 0.5;
		float seed = hash(cell);
		vec2 offset = vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5;
		float life = fract(TIME * (0.35 + seed * 0.4) + seed * 10.0);
		float size = life * 0.22 * step(0.45, seed);
		float d = length(in_cell - offset * 0.4);
		float ring = smoothstep(size, size - 0.05, d) - smoothstep(size - 0.05, size - 0.11, d);
		bubble = ring * (1.0 - life) * bubbles * step(r, 0.85);
	}
	color = mix(color, soup * 1.35, clamp(bubble, 0.0, 1.0) * 0.8);
	ALBEDO = color;
	ROUGHNESS = 0.18;
	SPECULAR = 0.6;
}
