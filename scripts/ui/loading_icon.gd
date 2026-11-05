# LoadingIcon: the game's icon in the bottom right corner of the black screen
# between scenes, with steam rising from its chimney. The house and the steam
# are two images cut from the icon (assets/loading_house.png, loading_steam.png):
# the steam picture drifts up and sways in a shader, as two copies that take
# turns fading in, so it never stops rising. IrisTransition shows it.
class_name LoadingIcon
extends Control

const HOUSE := preload("res://assets/loading_house.png")
const STEAM := preload("res://assets/loading_steam.png")
const WIDTH_SHARE := 0.26     # The house's width, as a share of the screen's height.
const MARGIN_SHARE := 0.05    # Its gap from the corner, the same way.
const STEAM_AT := Vector2(685.0, -198.0)  # Where the steam picture sits on the house picture, in its pixels.
const FADE_SECONDS := 0.2
const SHADER_CODE := """
shader_type canvas_item;
uniform sampler2D steam : repeat_disable, filter_linear;
uniform float speed = 0.3;   // Rises per second.
uniform float rise = 0.15;   // How far each copy drifts, as a share of the picture.
uniform vec3 cream : source_color = vec3(0.98, 0.93, 0.8);

vec4 copy(vec2 uv, float phase, float time) {
	float height = 1.0 - uv.y;
	float sway = sin(uv.y * 9.0 + time * 1.8 + phase * 6.283) * 0.035 * height;
	vec4 sampled = texture(steam, vec2(uv.x + sway, uv.y + (phase - 0.5) * 2.0 * rise));
	float weight = 1.0 - abs(phase * 2.0 - 1.0);
	return vec4(sampled.rgb * sampled.a, sampled.a) * weight;
}

void fragment() {
	float phase = fract(TIME * speed);
	vec4 both = copy(UV, phase, TIME) + copy(UV, fract(phase + 0.5), TIME);
	vec3 color = both.rgb / max(both.a, 0.001);
	float fade_at_top = smoothstep(0.0, 0.3, UV.y);
	COLOR = vec4(mix(color, cream, 0.45), both.a * fade_at_top);
}
"""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var screen := get_viewport_rect().size
	var scale_by := screen.y * WIDTH_SHARE / HOUSE.get_width()
	var house_size := Vector2(HOUSE.get_size()) * scale_by
	var corner := screen - house_size - Vector2.ONE * screen.y * MARGIN_SHARE
	_add_picture(HOUSE, corner, house_size)
	var steam := _add_picture(STEAM, corner + STEAM_AT * scale_by, Vector2(STEAM.get_size()) * scale_by)
	var shader := Shader.new()
	shader.code = SHADER_CODE
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("steam", STEAM)
	steam.material = material
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_SECONDS)


func _add_picture(texture: Texture2D, at: Vector2, size_on_screen: Vector2) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.position = at
	picture.size = size_on_screen
	add_child(picture)
	return picture


func fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	await tween.finished
