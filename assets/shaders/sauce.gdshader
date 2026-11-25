// A sauce lying on food (SauceSheet): a net over the plate, lifted to wherever
// the sauce is (its texture: how high what's under it is, and how deep the sauce
// is there). See-through where it's thin and deep-colored where it pools, with a
// wet shine; it isn't drawn at all where there's none.
shader_type spatial;
render_mode cull_disabled, depth_draw_always;

uniform sampler2D heights : filter_linear, repeat_disable;  // r: what's under it (m), g: the sauce (m).
uniform float cells = 80.0;
uniform vec2 size = vec2(0.34);
uniform vec3 sauce : source_color = vec3(0.38, 0.17, 0.04);
uniform vec3 thin_color : source_color = vec3(0.95, 0.55, 0.12);
uniform float absorb = 520.0;      // How quickly it goes from see-through to solid with depth (per meter).
uniform float least_alpha = 0.35;
uniform float gloss = 0.95;
uniform float lumps = 0.0;         // A foam's or a thick sauce's texture.
uniform float lift = 0.0009;       // Drawn this far over what it lies on.

varying vec2 spot;

#include "res://assets/shaders/food_light.gdshaderinc"

// Smoothed over the cells round it, so no cell shows.
vec2 sample_smooth(vec2 uv) {
	vec2 p = uv * cells - 0.5;
	vec2 i = floor(p);
	vec2 f = p - i;
	vec2 w0 = (1.0 - f) * (1.0 - f) * (1.0 - f) / 6.0;
	vec2 w1 = (4.0 - 6.0 * f * f + 3.0 * f * f * f) / 6.0;
	vec2 w3 = f * f * f / 6.0;
	vec2 w2 = 1.0 - w0 - w1 - w3;
	vec2 g0 = w0 + w1;
	vec2 g1 = w2 + w3;
	vec2 a = (i - 0.5 + w1 / g0) / cells;
	vec2 b = (i + 1.5 + w3 / g1) / cells;
	vec2 low = mix(textureLod(heights, vec2(b.x, a.y), 0.0).rg, textureLod(heights, vec2(a.x, a.y), 0.0).rg, g0.x);
	vec2 high = mix(textureLod(heights, vec2(b.x, b.y), 0.0).rg, textureLod(heights, vec2(a.x, b.y), 0.0).rg, g0.x);
	return mix(high, low, g0.y);
}

void vertex() {
	spot = UV;
	vec2 here = sample_smooth(UV);
	VERTEX.y = here.r + here.g + lift;
}

void fragment() {
	vec2 here = sample_smooth(spot);
	float depth = here.g;
	float edge = smoothstep(0.00022, 0.00036, depth);
	if (edge < 0.03) {
		discard;
	}
	float step_uv = 1.3 / cells;
	vec2 left = sample_smooth(spot - vec2(step_uv, 0.0));
	vec2 right = sample_smooth(spot + vec2(step_uv, 0.0));
	vec2 back = sample_smooth(spot - vec2(0.0, step_uv));
	vec2 front = sample_smooth(spot + vec2(0.0, step_uv));
	vec2 span = 2.0 * step_uv * size;
	// The sauce's own swell counts for more than what's under it, and its rim rounds over.
	float rim = 0.0014;
	vec2 slope = vec2((right.r - left.r) / span.x, (front.r - back.r) / span.y)
		+ vec2((right.g - left.g) / span.x, (front.g - back.g) / span.y) * 1.7
		+ vec2(smoothstep(0.0, rim, right.g) - smoothstep(0.0, rim, left.g), smoothstep(0.0, rim, front.g) - smoothstep(0.0, rim, back.g)) * 0.6;
	float bumpy = food_fbm(spot * cells * 0.9);
	slope += vec2(dFdx(bumpy), dFdy(bumpy)) * lumps * 6.0;
	vec3 normal = normalize(vec3(-slope.x, 1.0, -slope.y));
	float deep = 1.0 - exp(-(depth + 0.0005) * absorb);
	vec3 color = mix(thin_color, sauce, deep);
	color *= 1.0 + lumps * (bumpy - 0.5) * 0.25;
	ALBEDO = color;
	ALPHA = edge * mix(least_alpha, 1.0, deep);
	NORMAL = normalize(mat3(VIEW_MATRIX) * (MODEL_NORMAL_MATRIX * normal));
	ROUGHNESS = mix(0.85, 0.08, gloss);
	SPECULAR = mix(0.2, 0.6, gloss);
	EMISSION = thin_color * (1.0 - deep) * 0.05 * gloss;  // Light coming through it.
	// The kitchen's light in it: a soft bright band toward the edges it's seen along.
	float along_it = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION += vec3(1.0, 0.93, 0.8) * along_it * 0.3 * gloss * edge;
	shine = gloss;
}
