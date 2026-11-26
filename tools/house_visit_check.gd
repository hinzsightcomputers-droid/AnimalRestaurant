extends Node

# The regulars' houses in their woodland spots, in the four-way split: one
# chef on each porch (Mabel, Stitches, Cheddar) and one in the kitchen, then a
# visit at each door (knock, greeting, inside if they're friends enough), then
# the cart drive to the beach. Prints draw calls and fps. Run (not headless)
# with APPDATA pointing at a copy of a save with an account and SHOTS=<folder>:
#   godot --resolution 1920x1080 res://tools/house_visit_check.tscn

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
	if OS.get_environment("DRIVE") == "1":
		await _drive()
		return
	var manager: PlayerManager = _find(main, func(n): return n is PlayerManager)[0]
	for index in range(1, 4):
		InputSetup.assign_device(index, "pad_%d" % index)
		manager._spawn(index)
	await get_tree().create_timer(1.0).timeout
	await _pick_accounts()
	var town: Town = _find(main, func(n): return n is Town)[0]
	var order := ["mabel", "stitches", "cheddar"]
	for i in order.size():
		var house := town.house_of(order[i])
		var player := Player.find(get_tree(), i)
		var door: Vector3 = house.reel_door()
		player.global_position = door + (door - house.global_position).normalized() * 2.5
		player.visual.rotation.y = atan2(house.global_position.x - door.x, house.global_position.z - door.z)
	Player.find(get_tree(), 3).global_position = Vector3(4.0, 0.0, -8.3)
	await get_tree().create_timer(3.0).timeout
	_report("split_houses")
	await _shot("visit_00_split.png")
	for i in order.size():  # Each knocks; the greeting (or inside) a few seconds later.
		town.house_of(order[i]).reel_knock(Player.find(get_tree(), i))
	await get_tree().create_timer(2.5).timeout
	await _shot("visit_01_knock.png")
	await get_tree().create_timer(3.5).timeout
	await _shot("visit_02_answer.png")
	for round in 6:  # Click through what they say.
		await _key(KEY_E, 0.1)
		await get_tree().create_timer(1.2).timeout
	await _shot("visit_03_talk.png")
	print("VISIT done")
	get_tree().quit()


# DRIVE=1: Cheddar's cart by the lane, then the drive to the beach.
func _drive() -> void:
	var trip: CarTrip = _find(main, func(n): return n is CarTrip)[0]
	trip.reel_stage(Player.find(get_tree(), 0))
	await get_tree().create_timer(2.0).timeout
	await _shot("drive_00_cart.png")
	trip.reel_drive(8.0, [])
	for i in 3:
		await get_tree().create_timer(2.5).timeout
		_report("drive_%d" % (i + 1))
		await _shot("drive_%02d.png" % (i + 1))
	await get_tree().create_timer(5.0).timeout
	await _shot("drive_04_beach.png")
	print("VISIT done")
	get_tree().quit()


func _report(label: String) -> void:
	var calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	print("VISIT %s: %d draw calls, %d fps" % [label, calls, Engine.get_frames_per_second()])


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
