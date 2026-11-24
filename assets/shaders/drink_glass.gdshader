// The glass round a drink (DrinkModel): nearly clear face on, brighter at its
// edges, with a soft streak of light down one side.
shader_type spatial;
render_mode cull_back, depth_draw_never, shadows_disabled;

uniform vec3 glass : source_color = vec3(0.9, 0.96, 1.0);
uniform float body = 0.1;     // How much it shows face on...
uniform float edge = 0.6;    // ...and at its edges.

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.2);
	float streak = smoothstep(0.09, 0.0, abs(NORMAL.x + 0.6)) * 0.22;
	ALBEDO = glass;
	EMISSION = glass * (rim * 0.08 + streak * 0.3);
	ROUGHNESS = 0.06;
	SPECULAR = 0.7;
	ALPHA = clamp(body + rim * edge + streak, 0.0, 0.92);
}
