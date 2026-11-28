extends Node

# Pictures of the room under each lighting in data/day.json (the meals,
# closing, the night shift and the after-hours blocks), as the game camera
# sees it with the chef in the dining room and in the kitchen. Run (not
# headless) with APPDATA pointing at a copy of a save with an account, and:
#   SHOTS=<folder>  [PREFIX=<text>]  [ONLY=night,dinner]
#   godot --resolution 1280x720 res://tools/lighting_check.tscn

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
	var day: DayManager = _find(main, func(n): return n is DayManager)[0]
	var settings := GameData.day_settings
	var lightings := {}
	for phase in settings.get("phases", []):
		lightings[phase["id"]] = phase.get("lighting", {})
	lightings["closing"] = settings.get("closing", {}).get("lighting", {})
	lightings["night"] = settings.get("night", {}).get("lighting", {})
	var after: Dictionary = settings.get("after_hours", {}).get("lighting", {})
	for block in after:
		if block != "_about":
			lightings["after_" + block] = after[block]
	var only := OS.get_environment("ONLY").split(",", false)
	var player: Player = Player.find(get_tree(), 0)
	for id in lightings:
		if not only.is_empty() and not only.has(id):
			continue
		day._light(lightings[id], 0.0)
		player.global_position = Vector3(-1.5, 0.0, 0.0)
		await get_tree().create_timer(1.2).timeout
		await _shot("%s_dining.png" % id)
		player.global_position = Vector3(4.0, 0.0, -8.3)
		await get_tree().create_timer(1.2).timeout
		await _shot("%s_kitchen.png" % id)
	print("LIGHTING done")
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
