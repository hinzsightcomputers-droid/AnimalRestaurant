# PhotoMode (autoload): screenshots, and a photo mode for nice ones (store
# screenshots, or just a moment worth keeping).
#   F12 - saves what's on screen as a PNG in the user folder's "screenshots"
#         (the toast says where).
#   F10 - photo mode: the game freezes, every bit of UI hides (the HUD, tickets,
#         prompts, the icons over heads), and the first chef's camera is free:
#         WASD / arrows move it across the room, Q / E turn round, R / F tilt,
#         the mouse wheel or Z / X zoom, right-drag to orbit, Shift for faster.
#         H hides the help line. F12 takes the picture; F10 or Escape goes back
#         to the game just as it was.
extends Node

const PHOTO_KEY := KEY_F10
const SHOT_KEY := KEY_F12
const FOLDER := "user://screenshots"
const HELP := "PHOTO MODE   WASD move   Q/E turn   R/F tilt   wheel or Z/X zoom   right-drag orbit   Shift faster   H hide this   F12 take picture   F10 back"
const MOVE_SPEED := 4.0     # Meters a second across the floor (times the zoom).
const TURN_SPEED := 1.6     # Radians a second.
const ZOOM_STEP := 0.9      # Each wheel notch brings it this much closer.
const DISTANCE_RANGE := Vector2(0.8, 30.0)
const SIDE_WALL_X := 7.15   # The right-hand walls (RestaurantGrounds.INDOORS).
const PITCH_RANGE := Vector2(deg_to_rad(2.0), deg_to_rad(85.0))

var active := false
var _layer: CanvasLayer
var _help: Label
var _toast: Label
var _toast_tween: Tween
var _was_paused := false
var _hidden: Array[CanvasItem] = []   # UI layers and pieces hidden for photo mode...
var _hidden_3d: Array[Node3D] = []    # ...and the icons and prompts over heads.
var _hidden_layers: Array[CanvasLayer] = []
var _camera: Camera3D
var _camera_start: Transform3D
var _mask_was := 0
var _pivot := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.0
var _distance := 6.0
var _dragging := false
var _taking := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 120  # Over everything.
	add_child(_layer)
	_help = _label(16, Control.PRESET_BOTTOM_WIDE, Vector2(0.0, -64.0))
	_help.text = HELP
	_help.visible = false
	_toast = _label(22, Control.PRESET_TOP_WIDE, Vector2(0.0, 24.0))
	_toast.visible = false


func _label(font_size: int, preset: Control.LayoutPreset, offset: Vector2) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.9))
	label.add_theme_color_override("font_outline_color", Color(0.18, 0.12, 0.08))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_layer.add_child(label)
	label.set_anchors_and_offsets_preset(preset)
	label.offset_left = 24.0
	label.offset_right = -24.0
	label.position += offset
	return label


# _input, so the keys work whatever has focus, and the game never sees them in photo mode.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.keycode == SHOT_KEY:
			get_viewport().set_input_as_handled()
			take_screenshot()
			return
		if key.keycode == PHOTO_KEY or (active and key.keycode == KEY_ESCAPE):
			get_viewport().set_input_as_handled()
			set_active(not active)
			return
		if active and key.keycode == KEY_H:
			_help.visible = not _help.visible
	if not active:
		return
	var button := event as InputEventMouseButton
	if button != null:
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_distance *= ZOOM_STEP
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_distance /= ZOOM_STEP
		elif button.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = button.pressed
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging:
		_yaw -= motion.relative.x * 0.006
		_pitch += motion.relative.y * 0.006
	# Nothing reaches the game while it's frozen for a photo (but Escape is ours too).
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not active or _camera == null or not is_instance_valid(_camera):
		return
	var fast := 3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	var turn := _axis(KEY_E, KEY_Q)
	_yaw += turn * TURN_SPEED * fast * delta
	_pitch += _axis(KEY_R, KEY_F) * TURN_SPEED * 0.6 * fast * delta
	_distance *= pow(1.6, _axis(KEY_X, KEY_Z) * fast * delta)
	var move := Vector2(_axis(KEY_D, KEY_A) + _axis(KEY_RIGHT, KEY_LEFT), _axis(KEY_S, KEY_W) + _axis(KEY_DOWN, KEY_UP))
	if move != Vector2.ZERO:
		var step := move.normalized().rotated(-_yaw) * MOVE_SPEED * fast * delta * clampf(_distance / 6.0, 0.4, 3.0)
		_pivot += Vector3(step.x, 0.0, step.y)
	_place()


func _axis(plus: Key, minus: Key) -> float:
	return (1.0 if Input.is_key_pressed(plus) else 0.0) - (1.0 if Input.is_key_pressed(minus) else 0.0)


func _place() -> void:
	_pitch = clampf(_pitch, PITCH_RANGE.x, PITCH_RANGE.y)
	_distance = clampf(_distance, DISTANCE_RANGE.x, DISTANCE_RANGE.y)
	var offset := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _distance
	_camera.global_position = _pivot + offset
	_camera.look_at(_pivot, Vector3.UP)
	_pick_walls()


# The game leaves out the right-hand walls it looks in over: the free camera
# can be anywhere, so they show unless it's past them. The cottage outside (its
# roof, the front's full height) only when looking at something outdoors, as
# in the game.
func _pick_walls() -> void:
	_camera.set_cull_mask_value(RestaurantGrounds.SIDE_WALL_LAYER, _camera.global_position.x < SIDE_WALL_X)
	var tall_front := RestaurantGrounds.outdoors(_pivot)
	_camera.set_cull_mask_value(RestaurantGrounds.TALL_FRONT_LAYER, tall_front)
	_camera.set_cull_mask_value(RestaurantGrounds.LOW_FRONT_LAYER, not tall_front)


# For tools: `keep_view_ui` leaves what's in the chefs' own views showing (a
# close-up's own screen), `help` false leaves out the help line.
func set_active(on: bool, keep_view_ui := false, help := true) -> void:
	if on == active:
		return
	active = on
	_help.visible = on and help
	_dragging = false
	if on:
		_was_paused = get_tree().paused
		get_tree().paused = true
		_hide_ui(keep_view_ui)
		_take_camera()
	else:
		_show_ui()
		_give_camera_back()
		get_tree().paused = _was_paused


# Every CanvasLayer but the players' views, everything in a view but its
# picture, and the icons and prompts floating over heads.
func _hide_ui(keep_view_ui := false) -> void:
	for node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var layer := node as CanvasLayer
		if layer == _layer or layer is ViewManager or not layer.visible:
			continue
		layer.visible = false
		_hidden_layers.append(layer)
	for view in get_tree().root.find_children("*", "PlayerView", true, false):
		if keep_view_ui:
			break
		for child in view.get_children():
			if child is CanvasItem and not child is SubViewport and child.visible:
				child.visible = false
				_hidden.append(child)
	for node in get_tree().root.find_children("*", "Node3D", true, false):
		if _is_overlay(node) and node.visible:
			node.visible = false
			_hidden_3d.append(node)


func _is_overlay(node: Node) -> bool:
	if node is WaitIcon:
		return true
	if node is Label3D:
		if _script_is(node, "interact_prompt.gd"):
			return true
		if node.get_parent() != null and _script_is(node.get_parent(), "held_item_display.gd"):
			return true
	return false


func _script_is(node: Node, file: String) -> bool:
	var script: Script = node.get_script()
	return script != null and script.resource_path.ends_with(file)


func _show_ui() -> void:
	for layer in _hidden_layers:
		if is_instance_valid(layer):
			layer.visible = true
	for item in _hidden:
		if is_instance_valid(item):
			item.visible = true
	for node in _hidden_3d:
		if is_instance_valid(node):
			node.visible = true
	_hidden_layers.clear()
	_hidden.clear()
	_hidden_3d.clear()


# The first chef's camera (or the first view showing), to move freely; it
# starts right where it was, looking at the same spot.
func _take_camera() -> void:
	_camera = null
	var views := get_tree().root.find_children("*", "PlayerView", true, false)
	views = views.filter(func(v): return v.visible)
	views.sort_custom(func(a, b): return a.player_index < b.player_index)
	if views.is_empty():
		_camera = get_viewport().get_camera_3d()  # A scene of its own (the start screen...).
		if _camera == null:
			return
		_pivot = _camera.global_position - _camera.global_basis.z * 6.0
	else:
		var rig: CameraRig = views[0].rig
		_camera = rig.camera
		_pivot = rig.global_position
	_camera_start = _camera.global_transform
	_mask_was = _camera.cull_mask
	_camera.set_cull_mask_value(CustomerDisplay.TEXT_LAYER, false)  # Table badges.
	var offset := _camera.global_position - _pivot
	_distance = maxf(offset.length(), 1.0)
	_pitch = asin(clampf(offset.y / _distance, -1.0, 1.0))
	_yaw = atan2(offset.x, offset.z)


# For tools (the week bot's store photos): the free camera to `from`, looking at `at`.
func frame(from: Vector3, at: Vector3) -> void:
	if not active or _camera == null:
		return
	_pivot = at
	var offset := from - at
	_distance = maxf(offset.length(), DISTANCE_RANGE.x)
	_pitch = asin(clampf(offset.y / _distance, -1.0, 1.0))
	_yaw = atan2(offset.x, offset.z)
	_place()


func _give_camera_back() -> void:
	if _camera != null and is_instance_valid(_camera):
		_camera.global_transform = _camera_start
		_camera.cull_mask = _mask_was
	_camera = null


# Saves the screen as it is now (without photo mode's help line or a toast).
func take_screenshot() -> void:
	if _taking:
		return
	_taking = true
	var help_was := _help.visible
	_help.visible = false
	_toast.visible = false
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	_help.visible = help_was and active
	_taking = false
	if image == null:
		return
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path := "%s/%s.png" % [FOLDER, stamp]
	var n := 2
	while FileAccess.file_exists(path):
		path = "%s/%s_%d.png" % [FOLDER, stamp, n]
		n += 1
	var error := image.save_png(path)
	if error == OK:
		_show_toast("Screenshot saved: %s\nin %s" % [path.get_file(), ProjectSettings.globalize_path(FOLDER)])
	else:
		_show_toast("Couldn't save the screenshot.")


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)
	_toast_tween.tween_callback(func(): _toast.visible = false)
