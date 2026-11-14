extends Node

# The restaurant at a stage (STAGE=2 by default): the room from above and
# from the play camera, plus checks on the new tables and walls. Run (not
# headless) with APPDATA pointing at a copy of a save with an account:
#   APPDATA=<copy> SHOTS=<folder> STAGE=2 godot --resolution 1920x1080 res://tools/stage_check.tscn

var main: Node


func _ready() -> void:
	var stage := int(OS.get_environment("STAGE")) if not OS.get_environment("STAGE").is_empty() else 2
	GameState.stage = stage
	GameState.stars = maxi(GameState.stars, stage)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(3.0).timeout
	for i in 10:
		if Player.find(get_tree(), 0) != null:
			break
		await _key(KEY_ENTER, 0.1)
		await get_tree().create_timer(0.5).timeout
	await _pick_accounts()
	var ok := true
	var seats := get_tree().get_nodes_in_group(CustomerManager.SEAT_GROUP)
	var new_seats := seats.filter(func(s): return s.table != null and s.table.spot in ["nook", "bay"])
	ok = _check("%d seats, %d at the new tables" % [seats.size(), new_seats.size()], new_seats.size() == (4 if stage >= 2 else 0)) and ok
	ok = _check("the new strip is indoors", not RestaurantGrounds.outdoors(Vector3(-8.5, 0, 0)) == (stage >= 2)) and ok
	var lamps := get_tree().get_nodes_in_group("pendant_lamps").size()
	ok = _check("%d pendant lamps" % lamps, lamps == (6 if stage >= 2 else 4)) and ok
	ok = _check("the old left wall's spot moved", Decor.spot_position(3).x < -9.0 == (stage >= 2)) and ok
	var player: Node3D = Player.find(get_tree(), 0)
	if player != null:
		player.global_position = Vector3(-6.0, 0.0, 0.5)
	await get_tree().create_timer(2.0).timeout
	await _shot("stage_play.png")
	# Walk the chef into the new strip and against its wall: it should stop at the wall.
	if player != null:
		player.global_position = Vector3(-8.5, 0.0, 0.5)
		await get_tree().create_timer(0.2).timeout
		var start := player.global_position
		for i in 60:
			player.velocity = Vector3(-4.0, 0.0, 0.0)
			player.move_and_slide()
			await get_tree().physics_frame
		ok = _check("the chef stops at the new left wall (x %.2f)" % player.global_position.x, player.global_position.x > -10.2 and player.global_position.x < start.x) and ok
	var rig: Node = _find(main, func(n): return n is CameraRig)[0]
	rig.process_mode = Node.PROCESS_MODE_DISABLED
	var camera: Camera3D = _find(rig, func(n): return n is Camera3D)[0]
	camera.global_position = Vector3(-2.0, 22.0, 0.5)
	camera.look_at(Vector3(-2.0, 0.0, 0.0), Vector3(0, 0, -1))
	await get_tree().create_timer(0.5).timeout
	await _shot("stage_top.png")
	print("STAGE ", "ALL OK" if ok else "FAILED")
	get_tree().quit(0 if ok else 1)


func _check(what: String, passed: bool) -> bool:
	print("STAGE %s %s" % ["ok  " if passed else "FAIL", what])
	return passed


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(OS.get_environment("SHOTS") + "/" + file)


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
