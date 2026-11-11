// Soft toon lighting, shared by every material in the art style (see the Art
// Style Guide tab of the GDD): light falls off in a few soft steps instead of a
// smooth gradient, the sun's shadow side gets a warm tint instead of going
// grey, a faint sheen at the edges gives the matte felt look, and glossy
// things (syrup, sauces) get one soft white highlight.
// toon_amount 0 lights it plainly instead (for comparing before and after).

uniform int shade_steps : hint_range(1, 4) = 3;
uniform float step_softness : hint_range(0.0, 0.5) = 0.12;
uniform vec4 shadow_tint : source_color = vec4(0.42, 0.25, 0.2, 1.0);
uniform float felt_sheen : hint_range(0.0, 1.0) = 0.22;
uniform float gloss : hint_range(0.0, 1.0) = 0.0;
uniform float toon_amount : hint_range(0.0, 1.0) = 1.0;

float soft_steps(float lit) {
	float steps = float(max(shade_steps, 1));
	float x = lit * steps;
	float band = floor(x);
	float edge = smoothstep(0.5 - step_softness, 0.5 + step_softness, x - band);
	return min((band + edge) / steps, 1.0);
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float plain = ndl * ATTENUATION;
	float lit = soft_steps(ndl) * ATTENUATION;  // Bands across the form only: distance and shadow fade smoothly, so dim light isn't rounded away.
	vec3 band_light = vec3(lit);
	if (LIGHT_IS_DIRECTIONAL) {
		band_light = mix(shadow_tint.rgb, vec3(1.0), lit);  // A warm shadow side, not a grey one.
	}
	float sheen = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5) * felt_sheen * max(lit, 0.35);
	vec3 toon = band_light + vec3(sheen);
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * mix(vec3(plain), toon, toon_amount);
	if (gloss > 0.0) {
		float highlight = smoothstep(0.93, 0.97, dot(reflect(-LIGHT, NORMAL), VIEW)) * ATTENUATION;
		SPECULAR_LIGHT += LIGHT_COLOR / PI * highlight * gloss * toon_amount;
	}
}
