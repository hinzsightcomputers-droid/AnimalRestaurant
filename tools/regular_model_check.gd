extends Node

# Close-ups of regulars' own models through a visit, from the game's view side:
# walking in, standing in line, talking, sitting down, seated, seated talking and
# standing up, with the first chef close by (their head should follow). Run (not
# headless) with APPDATA pointing at a copy of a save with an account, SHOTS=<folder>
# and WHO=<regular ids, comma separated>:
#   WHO=zakk,evaroo godot --resolution 1280x720 res://tools/regular_model_check.tscn

var main: Node
var camera: Camera3D


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
	get_tree().paused = false
	var rig: Node = _find(main, func(n): return n is CameraRig)[0]
	rig.process_mode = Node.PROCESS_MODE_DISABLED
	camera = _find(rig, func(n): return n is Camera3D)[0]
	camera.fov = 40.0
	camera.current = true
	var manager: Node = _find(main, func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("customer_manager.gd"))[0]
	var player: Node3D = Player.find(get_tree(), 0)
	for who in OS.get_environment("WHO").split(",", false):
		GameState.forced_visitors.append(who)
		var customer: Customer = null
		for i in 200:
			await get_tree().create_timer(0.1).timeout
			var found := _find(main, func(n): return n is Customer and n.regular_id == who and n.state != Customer.State.GONE)
			if not found.is_empty():
				customer = found[0]
				break
		if customer == null:
			print("MODEL %s never came" % who)
			continue
		var display: Node = customer.get_node("Display") if customer.has_node("Display") else null
		await get_tree().create_timer(1.5).timeout
		await _shot_of(customer, who + "_1_walk.png")
		while customer.state != Customer.State.WAITING_TO_BE_SEATED:
			await get_tree().create_timer(0.2).timeout
		await get_tree().create_timer(1.5).timeout
		await _shot_of(customer, who + "_2_idle.png")
		if player != null:  # Off to one side: the head should turn to them.
			player.global_position = customer.global_position + CameraRig.screen_to_world(Vector3(1.0, 0.0, 0.6))
		await get_tree().create_timer(1.5).timeout
		await _shot_of(customer, who + "_3_head_turn.png")
		customer.talking = true
		await get_tree().create_timer(1.5).timeout
		await _shot_of(customer, who + "_4_talk.png")
		customer.talking = false
		if player != null:
			player.global_position = Vector3(3.0, 0.0, 3.0)
		manager.get("_queue").erase(customer)  # Out of the line, as being led off it does.
		manager.call("_seat_self", customer, 1.0)
		while not customer.sitting_down:
			await get_tree().create_timer(0.05).timeout
		await get_tree().create_timer(customer.sit_seconds * 0.5).timeout
		await _shot_of(customer, who + "_5_sitting_down.png")
		while customer.sitting_down:
			await get_tree().create_timer(0.1).timeout
		await get_tree().create_timer(2.5).timeout
		await _shot_of(customer, who + "_6_sit.png")
		customer.talking = true
		await get_tree().create_timer(1.5).timeout
		await _shot_of(customer, who + "_7_sit_talk.png")
		customer.talking = false
		await get_tree().create_timer(1.0).timeout
		customer.leave([customer.global_position + Vector3(0, 0, 1.5), Vector3(0, 0, 8)], "", 0)
		while not customer.standing_up:
			await get_tree().create_timer(0.05).timeout
		await get_tree().create_timer(customer.stand_seconds * 0.5).timeout
		await _shot_of(customer, who + "_8_standing_up.png")
		while customer.standing_up:
			await get_tree().create_timer(0.05).timeout
		await get_tree().create_timer(0.3).timeout
		await _shot_of(customer, who + "_9_stood.png")
		print("MODEL %s done: sit %.2fs stand %.2fs" % [who, customer.sit_seconds, customer.stand_seconds])
	get_tree().quit()


func _shot_of(customer: Node3D, file: String) -> void:
	var at := customer.global_position + Vector3(0.0, 0.6, 0.0)
	camera.global_position = at + CameraRig.screen_to_world(Vector3(0.0, 0.8, 3.2))
	camera.look_at(at)
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
