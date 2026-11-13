extends Node

# Frame rate with the toon style, 1 to 4 players in split screen, at the window
# size Godot is started with. Run it (not headless) with APPDATA pointing at a
# copy of a save that has an account, e.g.:
#   APPDATA=<copy> SHOTS=<folder> godot --resolution 1920x1080 res://tools/perf_check.tscn
# Extra players join on made-up gamepads and make new chefs in that copy.
# Vsync off so it shows the headroom, not the monitor's cap.

var main: Node


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(3.0).timeout
	for i in 10:
		if Player.find(get_tree(), 0) != null:
			break
		await _key(KEY_ENTER, 0.1)
		await get_tree().create_timer(0.5).timeout
	await _pick_accounts()
	await get_tree().create_timer(2.0).timeout
	print("window ", DisplayServer.window_get_size(), " gpu ", RenderingServer.get_video_adapter_name(), " / ", RenderingServer.get_rendering_device().get_device_name() if RenderingServer.get_rendering_device() != null else "?")
	var pm: PlayerManager = _find(main, func(n): return n is PlayerManager)[0]
	for count in [1, 2, 3, 4]:
		while InputSetup.active_players().size() < count:
			var index := pm._first_free_index()
			InputSetup.assign_device(index, "pad_%d" % (index + 4))
			pm._spawn(index)
			await get_tree().create_timer(0.5).timeout
			await _pick_accounts()
		await get_tree().create_timer(3.0).timeout
		# Spread the chefs round the room, as in play.
		var spots := [Vector3(-3.0, 0, 1.0), Vector3(3.0, 0, -8.0), Vector3(-4.0, 0, -3.0), Vector3(4.5, 0, 3.5)]
		for p in get_tree().get_nodes_in_group(Player.GROUP):
			p.global_position = spots[p.player_index % spots.size()]
		await get_tree().create_timer(2.0).timeout
		await RenderingServer.frame_post_draw
		get_tree().root.get_texture().get_image().save_png(OS.get_environment("SHOTS") + "/p%d.png" % count)
		print("views: ", _find(main, func(n): return n is SubViewport and n.size.x > 0).map(func(v): return v.size))
		await _measure("%d player%s" % [count, "" if count == 1 else "s"], 12.0)
	get_tree().quit()


func _measure(label: String, seconds: float) -> void:
	var times := []
	var draws := []
	var prims := []
	var start := Time.get_ticks_usec()
	var last := start
	while Time.get_ticks_usec() - start < seconds * 1000000.0:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		prims.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	times.sort()
	var avg := 0.0
	for t in times:
		avg += t
	avg /= times.size()
	var worst := times.slice(int(times.size() * 0.99))
	var low := 0.0
	for t in worst:
		low += t
	low /= maxf(worst.size(), 1)
	print("PERF %-10s avg %.1f fps (%.2f ms)  1%% low %.1f fps  worst %.1f ms  draw calls %d  triangles %dk  customers %d" % [
		label, 1000.0 / avg, avg, 1000.0 / low, times.back(), _avg(draws), _avg(prims) / 1000,
		get_tree().get_nodes_in_group("customers").size() if get_tree().has_group("customers") else _find(main, func(n): return n is Customer).size()])


func _pick_accounts() -> void:
	for round in 30:
		var buttons := _find(get_tree().root, func(n): return n is Button and n.is_visible_in_tree() and ("played)" in n.text or "Start as a new chef" in n.text or n.text == "Done" or "rather not say" in n.text))
		if buttons.is_empty():
			var focus := get_viewport().gui_get_focus_owner()
			if focus is Button and focus.is_visible_in_tree():
				buttons = [focus]
			else:
				return
		if "Start as a new chef" in buttons[0].text:
			for edit in _find(get_tree().root, func(n): return n is LineEdit and n.is_visible_in_tree()):
				edit.text = "Cook%d" % (randi() % 1000)
				edit.text_changed.emit(edit.text)
		print("account buttons: ", buttons.map(func(b): return b.text))
		buttons[0].pressed.emit()
		await get_tree().create_timer(0.5).timeout


func _avg(a: Array) -> float:
	var s := 0.0
	for x in a:
		s += x
	return s / maxf(a.size(), 1)


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
