# IrisTransition: an old-cartoon circle wipe between scenes. The screen closes
# in to a dot in the middle, the new scene loads in the background on a black
# screen with the LoadingIcon in the corner, then the circle opens back up on
# it. It lives on the tree root (not in a scene), so it survives the scene
# change. Use IrisTransition.change_scene(get_tree(), "res://...").
class_name IrisTransition
extends CanvasLayer

const COLOR := Color(0.0, 0.0, 0.0)
const LOADING_SECONDS := 1.6  # The least the black screen shows, so the steam gets seen.
const SHUT := -0.01  # Past zero, so no dot is left in the middle.
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

static var _running := false  # One at a time: a second press can't start another.

var _material := ShaderMaterial.new()


# A wipe is running: change_scene() would be ignored, so check this first.
static func is_busy() -> bool:
	return _running


static func change_scene(tree: SceneTree, scene_path: String, close_seconds := 0.9, open_seconds := 1.0) -> void:
	if _running:
		return
	_running = true
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
	await _animate_radius(full, SHUT, close_seconds, Tween.EASE_IN)
	var icon := LoadingIcon.new()
	add_child(icon)
	var scene := await _load_in_background(scene_path)
	get_tree().paused = false
	get_tree().change_scene_to_packed(scene)
	await get_tree().process_frame
	await get_tree().process_frame  # Let the new scene place its cameras first.
	await icon.fade_out()
	await _animate_radius(SHUT, _full_radius(), open_seconds, Tween.EASE_OUT)
	_running = false
	queue_free()


# Loads on another thread so the steam keeps moving, for LOADING_SECONDS at least.
func _load_in_background(scene_path: String) -> PackedScene:
	ResourceLoader.load_threaded_request(scene_path)
	var waited := 0.0
	while waited < LOADING_SECONDS or ResourceLoader.load_threaded_get_status(scene_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		waited += get_process_delta_time()
	return ResourceLoader.load_threaded_get(scene_path) as PackedScene


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
