// A cube of steak (SearAction): marbled and wet when it's raw, each side browning
// on its own to a dark, bumpy, glistening crust, the color running a little way
// round the rounded edges.
shader_type spatial;

uniform vec4 sides[6];       // Each side's color, and how done it is: +x, -x, +y, -y, +z, -z.
uniform float sear_size = 0.08;

varying vec3 local;
varying vec3 local_normal;

#include "res://assets/shaders/food_light.gdshaderinc"

void vertex() {
	local = VERTEX / sear_size;
	local_normal = NORMAL;
}

float noise3(vec3 p) {
	return (food_noise(p.xy + p.z * 1.7) + food_noise(p.yz + p.x * 2.3) + food_noise(p.zx + p.y * 1.1)) / 3.0;
}

void fragment() {
	vec3 n = normalize(local_normal);
	vec3 away = pow(abs(local) * 2.0, vec3(9.0)) + 0.0001;
	away /= away.x + away.y + away.z;
	vec4 x = n.x > 0.0 || local.x > 0.0 ? sides[0] : sides[1];
	vec4 y = local.y > 0.0 ? sides[2] : sides[3];
	vec4 z = local.z > 0.0 ? sides[4] : sides[5];
	if (local.x <= 0.0) {
		x = sides[1];
	}
	vec4 side = x * away.x + y * away.y + z * away.z;
	float done = side.a;
	vec3 color = side.rgb;
	// Fat running through it, melting away as it sears.
	float veins = noise3(local * 5.0 + noise3(local * 3.0) * 2.5);
	float fat = smoothstep(0.035, 0.0, abs(veins - 0.5)) + smoothstep(0.02, 0.0, abs(noise3(local * 8.0 + 4.0) - 0.47)) * 0.6;
	color = mix(color, vec3(0.97, 0.82, 0.76), clamp(fat, 0.0, 1.0) * 0.75 * (1.0 - smoothstep(0.1, 0.75, done)));
	float grain = food_noise(vec2(local.x * 9.0 + local.y * 4.0, local.z * 46.0 + local.y * 30.0));
	color *= 0.9 + 0.18 * grain;
	// The crust: darker where it touched, lacy and bumpy.
	float crust = smoothstep(0.3, 1.0, done);
	float lace = noise3(local * 13.0) * 0.6 + noise3(local * 27.0) * 0.4;
	color = mix(color, color * (0.62 + 0.75 * lace), crust);
	vec3 bump = vec3(dFdx(lace), dFdy(lace), 0.0);
	NORMAL = normalize(NORMAL + bump * 1.1 * crust);
	ALBEDO = color;
	float wet = mix(0.55, 0.75, crust) * (0.55 + 0.6 * lace);
	ROUGHNESS = mix(0.8, 0.25, wet);
	SPECULAR = 0.4;
	shine = clamp(wet, 0.0, 1.0);
}
