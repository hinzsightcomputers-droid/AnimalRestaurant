// Something pouring (PourStream): a stream from a tip down to where it lands,
// thinning as it falls, wavering a little, spreading where it lands. Its head
// falls from the tip as it starts and its tail follows when it stops.
shader_type spatial;
render_mode cull_back;

uniform vec3 liquid : source_color = vec3(0.4, 0.2, 0.05);
uniform float thick = 0.006;     // Its radius at the tip.
uniform float drop = 0.2;        // How far it falls (m).
uniform float head = 1.0;        // How far down it's got (0..1)...
uniform float tail = 0.0;        // ...and where it's broken off.
uniform float waver = 1.0;
uniform float gloss = 0.8;
uniform vec2 sway = vec2(0.0);   // How far the tip is off to one side of where it lands (a thick stream trails behind).

#include "res://assets/shaders/food_light.gdshaderinc"

void vertex() {
	float t = 0.5 - VERTEX.y;
	float down = mix(tail, head, t);
	float r = thick * mix(1.1, 0.62, sqrt(down));
	r *= 1.0 + 0.12 * sin(down * 22.0 - TIME * 26.0) * waver;
	float landed = step(0.999, head);
	r += thick * 1.1 * smoothstep(0.94, 1.0, down) * landed;
	r *= mix(smoothstep(1.0, 0.86, t) * 0.75 + 0.25, 1.0, landed);      // A rounded drop at its head...
	r *= mix(1.0, smoothstep(0.0, 0.2, t) * 0.9 + 0.1, step(0.001, tail));  // ...and pinched off at its tail.
	vec2 off = vec2(sin(TIME * 9.0 + down * 7.0), cos(TIME * 7.3 + down * 6.0)) * 0.0009 * down * waver + sway * (1.0 - down) * (1.0 - down * 0.4);
	VERTEX = vec3(VERTEX.x * r + off.x, -down * drop, VERTEX.z * r + off.y);
}

void fragment() {
	ALBEDO = liquid;
	ROUGHNESS = mix(0.8, 0.1, gloss);
	SPECULAR = 0.5;
	shine = gloss;
}
