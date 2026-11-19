extends Node

# Pictures of the chopping board for the art pass: the board and the counter
# round it from the room's view side, then the carrot close-up through peeling
# and chopping (played by script, like a reel), a picture every couple of
# seconds. Run (not headless) with APPDATA pointing at a copy of a save with an
# account and SHOTS=<folder>:
#   godot --resolution 1920x1080 res://tools/board_look_check.tscn
# PREFIX=<text> starts every file name (to keep before and after apart).

var main: Node


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
	var board: ChoppingBoard = _find(main, func(n): return n is ChoppingBoard)[0]
	print("BOARD at ", board.global_position)
	player.global_position = board.global_position + board.global_transform.basis.z * 0.9
	await get_tree().create_timer(1.5).timeout
	await _shot("1_game_view.png")
	var rig: Node = _find(main, func(n): return n is CameraRig)[0]
	rig.process_mode = Node.PROCESS_MODE_DISABLED
	var camera: Camera3D = _find(rig, func(n): return n is Camera3D)[0]
	player.global_position = board.global_position + Vector3(0.0, 0.0, 2.5)  # Out of the picture.
	var saved := camera.global_transform
	var saved_fov := camera.fov
	var look := board.global_position + Vector3(0.0, 0.9, 0.0)
	camera.fov = 40.0
	camera.global_position = look + board.global_transform.basis * Vector3(0.0, 1.6, 1.4)
	camera.look_at(look)
	await get_tree().create_timer(0.5).timeout
	await _shot("2_corner_front.png")
	camera.global_position = look + board.global_transform.basis * Vector3(1.0, 1.2, 1.1)
	camera.look_at(look)
	await get_tree().create_timer(0.3).timeout
	await _shot("3_corner_side.png")
	camera.global_transform = saved
	camera.fov = saved_fov
	player.global_position = board.global_position + board.global_transform.basis.z * 0.9
	rig.process_mode = Node.PROCESS_MODE_INHERIT
	await get_tree().create_timer(0.5).timeout
	board.reel_cook(player, load("res://data/recipes/chopping.tres"), {})
	var session: CookSession = board.session
	var shot := 4
	var next_shot := 0.0
	var clock := 0.0
	while is_instance_valid(session) and not session.is_finished and clock < 120.0:
		await get_tree().process_frame
		clock += get_process_delta_time()
		if clock >= next_shot and session.current != null:
			next_shot = clock + 2.2
			await _shot("%02d_%s.png" % [shot, session.current.title.to_snake_case()])
			shot += 1
	await get_tree().create_timer(0.6).timeout
	await _shot("%02d_done.png" % shot)
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
