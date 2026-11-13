extends Node

# The line at the host stand: where each waiting customer stands and which way
# is up for them and their model. Run (not headless) with APPDATA pointing at a
# copy of a save with an account; SHOTS=<folder> for the pictures.

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
	var p: Node3D = Player.find(get_tree(), 0)
	for shot in 4:
		await get_tree().create_timer(8.0).timeout
		if p != null:
			p.global_position = Vector3(-1.0, 0.0, -0.5)
		await get_tree().create_timer(1.0).timeout
		for c in _find(main, func(n): return n is Customer):
			var up: Vector3 = c.global_basis.y
			var lowest_up := Vector3.UP
			for m in _find(c, func(n): return n is Node3D and n != c):
				if m.global_basis.y.normalized().dot(Vector3.UP) < lowest_up.dot(Vector3.UP):
					lowest_up = m.global_basis.y.normalized()
			print("%s state %s at %s rot %s up %s tilted child up %s" % [c.display_name, Customer.State.keys()[c.state], c.global_position, c.rotation_degrees, up, lowest_up])
		await RenderingServer.frame_post_draw
		get_tree().root.get_texture().get_image().save_png(OS.get_environment("SHOTS") + "/q%d.png" % shot)
	get_tree().quit()


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
