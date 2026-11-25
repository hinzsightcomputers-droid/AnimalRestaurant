// How food is lit up close: softly wrapped round (light gets into batter, dough
// and cheese a little), the same warm shadow side as the soft toon look, and a
// wet highlight wherever it's shiny. A shader sets `shine` in its fragment().

varying float shine;
uniform vec4 shadow_tint : source_color = vec4(0.42, 0.25, 0.2, 1.0);

void light() {
	float facing = dot(NORMAL, LIGHT);
	float soft = clamp((facing + 0.3) / 1.3, 0.0, 1.0);
	float lit = smoothstep(0.0, 1.0, soft) * ATTENUATION;
	vec3 glow = vec3(lit);
	if (LIGHT_IS_DIRECTIONAL) {
		glow = mix(shadow_tint.rgb, vec3(1.0), lit);
	}
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * glow;
	if (shine > 0.0) {
		float glint = pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), mix(18.0, 260.0, shine * shine));
		SPECULAR_LIGHT += LIGHT_COLOR / PI * glint * shine * 2.0 * ATTENUATION * step(0.0, facing);
	}
}

float food_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float food_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(food_hash(cell), food_hash(cell + vec2(1.0, 0.0)), f.x), mix(food_hash(cell + vec2(0.0, 1.0)), food_hash(cell + vec2(1.0, 1.0)), f.x), f.y);
}

float food_fbm(vec2 p) {
	return food_noise(p) * 0.55 + food_noise(p * 2.1 + 7.3) * 0.3 + food_noise(p * 4.3 + 1.9) * 0.15;
}
