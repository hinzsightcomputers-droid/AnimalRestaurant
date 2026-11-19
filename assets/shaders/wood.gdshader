// Warm wood for the chopping corner (the style guide: honey and warm woods,
// soft, no harsh grain): long gentle grain lines that wobble a little, with
// planks of slightly different tone across the depth when `planks` is set
// (a butcher-block counter) or one piece when it's 0 (a cutting board), and a
// few faint knife marks. Works on any mesh, from its own (scaled) position, so
// the grain runs along the object's length whichever way the station faces.
shader_type spatial;

uniform vec3 light_wood : source_color = vec3(0.86, 0.64, 0.42);
uniform vec3 dark_wood : source_color = vec3(0.72, 0.5, 0.31);
uniform float planks = 0.0;          // Planks per meter across the depth (0: one piece).
uniform float grain = 70.0;          // Grain lines per meter.
uniform float knife_marks = 0.0;     // 0..1: faint scratches from chopping.
uniform float roughness = 0.75;

varying vec3 local_pos;

void vertex() {
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	local_pos = VERTEX * scale;
}

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

void fragment() {
	vec3 p = local_pos;
	float plank_tone = 0.0;
	float seam = 0.0;
	if (planks > 0.0) {
		float row = floor(p.z * planks);
		plank_tone = hash(row) * 0.55;
		p.x += hash(row + 7.0) * 3.0;  // Each plank's grain starts somewhere else.
		float edge = abs(fract(p.z * planks) - 0.5) * 2.0;
		seam = smoothstep(0.93, 1.0, edge);
	}
	float wobble = sin(p.x * 6.0 + p.z * 3.0) * 0.012 + sin(p.x * 17.0) * 0.004;
	float lines = sin((p.z + wobble) * grain * 6.2832) * 0.5 + 0.5;
	float soft_grain = smoothstep(0.55, 1.0, lines) * 0.35;
	vec3 base = mix(light_wood, dark_wood, clamp(plank_tone + soft_grain, 0.0, 1.0));
	base = mix(base, dark_wood * 0.8, seam * 0.6);
	if (knife_marks > 0.0) {
		float scratch = smoothstep(0.985, 1.0, sin(p.x * 230.0 + sin(p.z * 40.0) * 2.0) * 0.5 + 0.5)
			* step(0.6, hash(floor(p.z * 30.0)));
		base = mix(base, light_wood * 1.08, scratch * knife_marks * 0.5);
	}
	ALBEDO = base;
	ROUGHNESS = roughness;
	SPECULAR = 0.3;
}
