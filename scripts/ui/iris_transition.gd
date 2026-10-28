# IrisTransition: an old-cartoon circle wipe between scenes. The screen closes
# in to a dot in the middle, the new scene loads, then the circle opens back up
# on it. It lives on the tree root (not in a scene), so it survives the scene
# change. Use IrisTransition.change_scene(get_tree(), "res://...").
class_name IrisTransition
extends CanvasLayer

const COLOR := Color(0.07, 0.05, 0.04)
const SHADER_CODE := """
shader_type canvas_item;
uniform vec4 color : source_color;
uniform float radius = 2.0;   // In screen heights from the middle.
uniform float aspect = 1.778; // Screen width / height, so the circle stays round.
void fragment() {
	float distance_from_middle = length((UV - vec2(0.5)) * vec2(aspect, 1.0));
	COLOR = vec4(color.rgb, smoothstep(radius - 0.004, radius + 0.004, distance_from_middle));
}
"""

var _material := ShaderMaterial.new()


static func change_scene(tree: SceneTree, scene_path: String, close_seconds := 0.9, open_seconds := 1.0) -> void:
	var iris := IrisTransition.new()
	tree.root.add_child(iris)
	iris._run(scene_path, close_seconds, open_seconds)


func _init() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS  # Keeps going if the new scene pauses (e.g. the account picker).
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_material.shader = shader
	_material.set_shader_parameter("color", COLOR)
	var cover := ColorRect.new()
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.material = _material
	add_child(cover)


func _run(scene_path: String, close_seconds: float, open_seconds: float) -> void:
	var full := _full_radius()
	_material.set_shader_parameter("radius", full)
	await _animate_radius(full, 0.0, close_seconds, Tween.EASE_IN)
	await get_tree().create_timer(0.2).timeout  # A beat of black.
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame  # Let the new scene place its cameras first.
	await _animate_radius(0.0, _full_radius(), open_seconds, Tween.EASE_OUT)
	queue_free()


# Just past the corners, so a full circle covers nothing.
func _full_radius() -> float:
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	_material.set_shader_parameter("aspect", aspect)
	return 0.5 * sqrt(aspect * aspect + 1.0) + 0.02


func _animate_radius(from: float, to: float, seconds: float, ease_type: Tween.EaseType) -> void:
	var tween := create_tween()
	tween.tween_method(func(value: float): _material.set_shader_parameter("radius", value), from, to, seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(ease_type)
	await tween.finished
