// The griddle's cooking top: seasoned dark steel, warm rather than black, with
// soft lighter streaks where it's been scraped and a faint orange glow from the
// heat underneath, strongest in the middle (the style guide: warm light first,
// food the brightest thing on it). Made for CookSurface's "griddle" look.
shader_type spatial;

uniform vec3 steel : source_color = vec3(0.2, 0.19, 0.19);
uniform vec3 seasoned : source_color = vec3(0.26, 0.24, 0.23);
uniform vec3 heat_color : source_color = vec3(1.0, 0.45, 0.12);
uniform float heat : hint_range(0.0, 1.0) = 0.6;
uniform vec2 size = vec2(1.14, 0.6);  // The top's width and depth (m), so the glow and streaks don't stretch.

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = local_pos.xz / size;  // -0.5..0.5 across the top.
	// Scrape streaks: soft bands along the width, a little uneven.
	float band = sin(local_pos.x * 140.0 + sin(local_pos.z * 11.0) * 0.8) * 0.5 + 0.5;  // Fine brushed lines along the depth, not wood grain.
	float patch = hash(floor(local_pos.xz * 6.0)) * 0.2;
	float streak = smoothstep(0.7, 1.0, band) * 0.25 + patch;
	vec3 base = mix(steel, seasoned, clamp(streak, 0.0, 1.0));
	// Heat: an oval glow in the middle, fading to the edges.
	float middle = 1.0 - smoothstep(0.08, 0.62, length(uv * vec2(1.0, 1.35)));
	ALBEDO = base;
	ROUGHNESS = 0.42 - streak * 0.12;
	METALLIC = 0.35;
	SPECULAR = 0.55;
	EMISSION = heat_color * middle * heat * 0.06;
}
