extends Node

# Close-ups of customers with the toon style on and off, from the game's view
# side (CameraRig.VIEW_YAW). Run (not headless) with APPDATA pointing at a copy
# of a save with an account and SHOTS=<folder>:
#   godot --resolution 1920x1080 res://tools/customer_look_check.tscn

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
	var player: Node3D = Player.find(get_tree(), 0)
	if player != null:
		player.global_position = Vector3(-1.0, 0.0, -0.5)
	await get_tree().create_timer(14.0).timeout  # A line forms.
	var customers := _find(main, func(n): return n is Customer and n.state == Customer.State.WAITING_TO_BE_SEATED)
	print("LOOK waiting: ", customers.map(func(c): return c.display_name))
	var look_at := Vector3(-2.5, 0.8, -1.2)
	if not customers.is_empty():
		look_at = customers[0].global_position + Vector3(0.0, 0.8, 0.0)
	# Take over the first player's camera: its rig stops following.
	var rig: Node = _find(main, func(n): return n is CameraRig)[0]
	rig.process_mode = Node.PROCESS_MODE_DISABLED
	var camera: Camera3D = _find(rig, func(n): return n is Camera3D)[0]
	camera.fov = 40.0
	camera.global_position = look_at + CameraRig.screen_to_world(Vector3(0.0, 1.2, 2.6))
	camera.look_at(look_at)
	camera.current = true
	var toon: ToonStyle = _find(main, func(n): return n is ToonStyle)[0]
	await get_tree().create_timer(0.5).timeout
	await _shot("look_toon.png")
	toon.enabled = false
	await get_tree().create_timer(0.5).timeout
	await _shot("look_plain.png")
	toon.enabled = true
	# From the room camera's height too.
	camera.global_position = look_at + CameraRig.screen_to_world(Vector3(0.0, 4.0, 4.0))
	camera.look_at(look_at)
	await get_tree().create_timer(0.5).timeout
	await _shot("look_high.png")
	get_tree().quit()


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
