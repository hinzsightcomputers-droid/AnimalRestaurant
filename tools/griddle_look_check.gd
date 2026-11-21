extends Node

# Pictures of the griddle corner for the art pass: the stove and the counters
# around it from the room's view side, then the pancake close-up at each step
# (cooked by script, like a reel). Run (not headless) with APPDATA pointing at
# a copy of a save with an account and SHOTS=<folder>:
#   godot --resolution 1920x1080 res://tools/griddle_look_check.tscn
# PREFIX=<text> starts every file name (to keep before and after apart).
# RECIPE=<name> cooks data/recipes/<name>.tres instead of the pancakes, and
# EVERY=<seconds> also takes a picture that often (a long single step).
# STATION=<station_id> cooks there instead of the stove ("oven" for the bakes).

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
	var station_id := OS.get_environment("STATION") if not OS.get_environment("STATION").is_empty() else "stove"
	var stoves := _find(main, func(n): return n is CookingStation and n.station_id == station_id)
	var stove: CookingStation = stoves[0]
	print("GRIDDLE stove ", stove.name, " at ", stove.global_position)
	player.global_position = stove.global_position + stove.global_transform.basis.z * 0.9
	await get_tree().create_timer(1.5).timeout
	await _shot("1_game_view.png")
	# The corner up close, from the room's view side.
	var rig: Node = _find(main, func(n): return n is CameraRig)[0]
	rig.process_mode = Node.PROCESS_MODE_DISABLED
	var camera: Camera3D = _find(rig, func(n): return n is Camera3D)[0]
	player.global_position = stove.global_position + Vector3(0.0, 0.0, 2.5)  # Out of the picture.
	var saved := camera.global_transform
	var saved_fov := camera.fov
	var look := stove.global_position + Vector3(0.0, 0.9, 0.0)
	camera.fov = 40.0
	camera.global_position = look + stove.global_transform.basis * Vector3(0.0, 1.3, 2.6)
	camera.look_at(look)
	await get_tree().create_timer(0.5).timeout
	await _shot("2_corner_front.png")
	camera.global_position = look + stove.global_transform.basis * Vector3(1.6, 1.1, 2.0)
	camera.look_at(look)
	await get_tree().create_timer(0.3).timeout
	await _shot("3_corner_side.png")
	camera.global_transform = saved
	camera.fov = saved_fov
	player.global_position = stove.global_position + stove.global_transform.basis.z * 0.9
	rig.process_mode = Node.PROCESS_MODE_INHERIT
	await get_tree().create_timer(0.5).timeout
	# The pancakes, a picture a moment into each step.
	var recipe_name := OS.get_environment("RECIPE")
	stove.reel_cook(player, load("res://data/recipes/%s.tres" % (recipe_name if not recipe_name.is_empty() else "pancakes")), {})
	var every := float(OS.get_environment("EVERY")) if not OS.get_environment("EVERY").is_empty() else 0.0
	var next_at := every
	var session: CookSession = stove.session
	var last := ""
	var shot := 4
	var started := Time.get_ticks_msec()
	for t in 30000:
		await get_tree().process_frame
		if not is_instance_valid(session) or session.is_finished:
			break
		if every > 0.0 and (Time.get_ticks_msec() - started) / 1000.0 >= next_at:
			next_at += every
			await _shot("%d_at_%ds.png" % [shot, roundi(next_at - every)])
			shot += 1
		if session.current != null and session.current.title != last:
			last = session.current.title
			print("GRIDDLE step ", last)
			await get_tree().create_timer(1.2).timeout
			if is_instance_valid(session) and not session.is_finished:
				await _shot("%d_step_%s.png" % [shot, last.to_snake_case()])
				shot += 1
	await get_tree().create_timer(0.8).timeout
	await _shot("%d_done.png" % shot)
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
