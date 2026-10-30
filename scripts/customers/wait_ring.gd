# WaitRing: a ring over a customer waiting for their food that empties as the
# wait goes on, so you can see at a glance who to serve first. Full when they
# order; empty at the streak's max wait (ServiceStreak), when a serve can no
# longer keep the run going. Green while the quick-service bonus is still on,
# amber after, and red, pulsing, in the last few seconds ("just in time").
# Hidden otherwise. Display only.
class_name WaitRing
extends MeshInstance3D

const SIZE := 0.5
const GREEN := Color(0.45, 0.85, 0.35)
const AMBER := Color(1.0, 0.75, 0.2)
const RED := Color(0.95, 0.3, 0.2)
const PULSE_SPEED := 9.0

const SHADER := """
shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled;

uniform float fill = 1.0;
uniform vec4 color : source_color = vec4(0.45, 0.85, 0.35, 1.0);
uniform vec4 empty : source_color = vec4(0.2, 0.15, 0.1, 0.55);
uniform vec4 edge : source_color = vec4(0.25, 0.18, 0.12, 1.0);

void vertex() {
	// Always facing the camera, keeping its size.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz), INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0 || r < 0.42) {
		discard;
	}
	float around = fract(atan(p.x, -p.y) / TAU);  // 0 at the top, clockwise.
	vec4 c = around < fill ? color : empty;
	if (r > 0.86 || r < 0.54) {
		c = edge;
	}
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
"""

var customer: Customer
var _material := ShaderMaterial.new()
var _time := 0.0


func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(SIZE, SIZE)
	mesh = quad
	var shader := Shader.new()
	shader.code = SHADER
	_material.shader = shader
	_material.render_priority = 1
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


func _process(delta: float) -> void:
	visible = customer != null and customer.state == Customer.State.WAITING_FOR_FOOD and ServiceStreak.seconds_left(customer) > 0.0
	if not visible:
		return
	var limit := ServiceStreak.max_wait()
	var left := ServiceStreak.seconds_left(customer)
	_material.set_shader_parameter("fill", left / limit)
	var color := GREEN if customer.wait_seconds <= Satisfaction.fast_seconds() else AMBER
	var pulse := 1.0
	if ServiceStreak.in_the_nick_of_time(customer.wait_seconds):
		color = RED
		_time += delta
		pulse = 1.0 + 0.15 * absf(sin(_time * PULSE_SPEED))
	_material.set_shader_parameter("color", color)
	scale = Vector3.ONE * pulse
