extends Node

# Text check: the griddle (pancakes, big breakfast) and chopping close-ups at
# each step, shown with the words a player sees (not a reel's). Run (not
# headless) with APPDATA pointing at a copy of a save with an account and
# SHOTS=<folder>:  godot --resolution 1920x1080 res://tools/closeup_text_check.tscn

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
	var stove: CookingStation = _find(main, func(n): return n is CookingStation and n.station_id == "stove")[0]
	var board: Node = _find(main, func(n): return n is ChoppingBoard)[0]
	for job in [[stove, "pancakes", "griddle"], [stove, "big_breakfast", "breakfast"], [board, "chopping", "chop"]]:
		player.global_position = job[0].global_position + job[0].global_transform.basis.z * 0.9
		await get_tree().create_timer(0.8).timeout
		job[0].reel_cook(player, load("res://data/recipes/%s.tres" % job[1]), {})
		var session: CookSession = job[0].session
		var last := ""
		var shot := 1
		for t in 30000:
			await get_tree().process_frame
			if not is_instance_valid(session) or session.is_finished:
				break
			if session.current != null and session.current.title != last:
				last = session.current.title
				await get_tree().create_timer(1.0).timeout
				if is_instance_valid(session) and not session.is_finished:
					session.input.scripted = false  # The words a player sees: step, controls, status.
					await get_tree().process_frame
					await get_tree().process_frame
					await _shot("%s_%02d_%s.png" % [job[2], shot, last.to_snake_case()])
					var pops := _find(session, func(n): return n is Label3D and n.visible and n.modulate.a > 0.3)
					print("TEXT %s %s: %d pop-ups showing" % [job[2], last, pops.size()])
					session.input.scripted = true
					shot += 1
		await get_tree().create_timer(2.0).timeout
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
