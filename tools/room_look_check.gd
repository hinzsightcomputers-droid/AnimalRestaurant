extends Node

# Pictures of the room itself for the room art pass: the game camera with the
# chef in the kitchen and in the dining room, then wide shots of the kitchen
# and dining room from fixed spots. Run (not headless) with APPDATA pointing at
# a copy of a save with an account, and:
#   SHOTS=<folder>  [PREFIX=<text>]
#   godot --resolution 1280x720 res://tools/room_look_check.tscn

var main: Node

const WIDE := [
	# [file, camera position, look at]
	["wide_kitchen", Vector3(4.0, 2.6, -5.4), Vector3(4.0, 0.9, -10.5)],
	["wide_kitchen_left", Vector3(6.6, 2.3, -6.0), Vector3(1.6, 0.9, -10.6)],
	["wide_dining", Vector3(5.5, 3.2, 3.5), Vector3(-2.5, 0.6, -2.5)],
	["wide_dining_back", Vector3(-5.5, 2.6, 4.0), Vector3(2.0, 0.8, -4.5)],
	["fireplace", Vector3(-4.4, 1.9, -1.6), Vector3(-6.0, 1.0, -5.0)],
]


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(3.0).timeout
	for i in 10:
		if Player.find(get_tree(), 0) != null:
			break
		await _key(KEY_ENTER, 0.1)
		await get_tree().create_timer(0.5).timeout
	await _pick_accounts()
	var player: Player = Player.find(get_tree(), 0)
	player.global_position = Vector3(4.0, 0.0, -8.3)
	await get_tree().create_timer(1.5).timeout
	await _shot("game_kitchen.png")
	player.global_position = Vector3(-1.5, 0.0, 0.0)
	await get_tree().create_timer(1.5).timeout
	await _shot("game_dining.png")
	var rig: Node = _find(main, func(n): return n is CameraRig)[0]
	var camera: Camera3D = _find(rig, func(n): return n is Camera3D)[0]
	rig.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = Vector3(0.0, 0.0, 9.0)  # Out of the pictures.
	camera.fov = 60.0
	for wide in WIDE:
		camera.global_position = wide[1]
		camera.look_at(wide[2])
		await get_tree().create_timer(0.5).timeout
		await _shot(wide[0] + ".png")
	print("ROOM done")
	get_tree().quit()


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(OS.get_environment("SHOTS") + "/" + OS.get_environment("PREFIX") + file)


func _pick_accounts() -> void:
	for round in 30:
		var buttons := _find(get_tree().root, func(n): return n is Button and n.is_visible_in_tree() and ("played)" in n.text or n.text == "Done" or "rather not say" in n.text))
		if buttons.is_empty():
			var focus := get_viewport().gui_get_focus_owner()
			if focus is Button and focus.is_visible_in_tree():
				buttons = [focus]
			else:
				return
		buttons[0].pressed.emit()
		await get_tree().create_timer(0.5).timeout


func _key(code: Key, hold: float) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await get_tree().create_timer(hold).timeout
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)


func _find(n: Node, f: Callable, out := []) -> Array:
	if f.call(n):
		out.append(n)
	for c in n.get_children():
		_find(c, f, out)
	return out
