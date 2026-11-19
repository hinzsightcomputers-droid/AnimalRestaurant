extends Node

# Pictures of any station for the art pass: the station from the room's view
# side, then one recipe's close-up played by script (like a reel), a picture
# every few seconds. Run (not headless) with APPDATA pointing at a copy of a
# save with an account, and:
#   STATION=stove|oven|microwave|board|sink|table  RECIPE=<data/recipes name>
#   SHOTS=<folder>  [PREFIX=<text>]  [EVERY=<seconds between pictures, 2.5>]
#   godot --resolution 1280x720 res://tools/station_look_check.tscn
# (board_look_check does the chopping board's own set.)

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
	var wanted := OS.get_environment("STATION")
	var recipe_name := OS.get_environment("RECIPE")
	var every := float(OS.get_environment("EVERY")) if OS.get_environment("EVERY") != "" else 2.5
	if not recipe_name.is_empty() and not GameData.is_unlocked(recipe_name):  # Bring in its station (the microwave comes with Mochi). Only the test save.
		GameState.unlocks.append(recipe_name)
		GameState.unlocks_changed.emit()
		await get_tree().process_frame
	var stations: Array = main.find_children("*", "CookingStation", true, false).filter(func(s): return s.station_id == wanted)
	if wanted == "board":
		stations = main.find_children("*", "ChoppingBoard", true, false)
	elif wanted == "table":
		stations = main.find_children("*", "DiningTable", true, false).filter(func(t): return t.spot == "kitchen")
	elif wanted == "sink":
		stations = main.find_children("*", "Sink", true, false)
	if stations.is_empty():
		print("STATION none for ", wanted)
		get_tree().quit()
		return
	var station: Node3D = stations[0]
	print("STATION ", station.name, " at ", station.global_position)
	var rig: Node = _find(main, func(n): return n is CameraRig)[0]
	var camera: Camera3D = _find(rig, func(n): return n is Camera3D)[0]
	if OS.get_environment("CORNER") != "0":
		rig.process_mode = Node.PROCESS_MODE_DISABLED
		player.global_position = station.global_position + Vector3(0.0, 0.0, 2.5)  # Out of the picture.
		var saved := camera.global_transform
		var saved_fov := camera.fov
		var look := station.global_position + Vector3(0.0, 0.9, 0.0)
		camera.fov = 40.0
		camera.global_position = look + station.global_transform.basis * Vector3(0.0, 1.6, 1.4)
		camera.look_at(look)
		await get_tree().create_timer(0.8).timeout
		await _shot("00_corner.png")
		camera.global_transform = saved
		camera.fov = saved_fov
		rig.process_mode = Node.PROCESS_MODE_INHERIT
	player.global_position = station.global_position + station.global_transform.basis.z * 0.9
	await get_tree().create_timer(0.8).timeout
	var dishes := GameData.dishes.filter(func(dish): return dish.get("recipe", "") == recipe_name)
	station.reel_cook(player, load("res://data/recipes/%s.tres" % recipe_name), dishes.front() if not dishes.is_empty() else {})
	var session: CookSession = station.session
	var shot := 1
	var next_shot := 1.2
	var clock := 0.0
	while is_instance_valid(session) and not session.is_finished and clock < 240.0:
		await get_tree().process_frame
		clock += get_process_delta_time()
		if clock >= next_shot and session.current != null:
			next_shot = clock + every
			await _shot("%02d_%s.png" % [shot, session.current.title.to_snake_case().validate_filename().replace(" ", "")])
			shot += 1
	await get_tree().create_timer(0.6).timeout
	await _shot("%02d_done.png" % shot)
	print("STATION done, ", shot, " pictures")
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
