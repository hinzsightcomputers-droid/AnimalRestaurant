extends Node

# The Meshy decor (design/decor/) in the real dining room: every catalogue item
# with a model placed where Decorate mode would let it go (floor items on free
# squares, wall items on the wall spots), then pictures from the game camera,
# with one chef and with four in split screen. Run (not headless) with APPDATA
# pointing at a copy of a save with an account and SHOTS=<folder>:
#   godot --resolution 1920x1080 res://tools/decor_room_check.tscn

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
	var room: DecorRoom = _find(main, func(n): return n is DecorRoom)[0]
	GameState.decor_placed.clear()
	var only := OS.get_environment("DECOR_SET")  # e.g. garden: just that set.
	var items := Decor.items().filter(func(i): return i.get("meshy", false) and (only.is_empty() or i.get("set", "") == only))
	var spot := 0
	var origin := Decor.grid_origin()
	var cells := Decor.grid_cells()
	var cell := float(Decor.settings()["grid"]["cell"])
	for item in items:
		if item["kind"] == "wall":
			while spot < Decor.settings()["wall_spots"].size() and Decor.spot_taken(spot):
				spot += 1
			if spot < Decor.settings()["wall_spots"].size():
				GameState.decor_placed.append({ "id": item["id"], "x": 0.0, "z": 0.0, "turn": 0, "spot": spot })
				print("ROOM %s on wall spot %d" % [item["id"], spot])
				spot += 1
			else:
				print("ROOM %s: no wall spot left" % item["id"])
			continue
		var placed := false
		for zi in cells.y:
			for xi in cells.x:
				var point := Decor.snap(item, origin + Vector2(xi + 0.5, zi + 0.5) * cell, 0)
				if room.can_go(item, point, 0):
					GameState.decor_placed.append({ "id": item["id"], "x": point.x, "z": point.y, "turn": 0, "spot": -1 })
					room.refresh()
					await get_tree().physics_frame
					await get_tree().physics_frame
					print("ROOM %s at %s" % [item["id"], point])
					placed = true
					break
			if placed:
				break
		if not placed:
			print("ROOM %s: no free floor" % item["id"])
	room.refresh()
	await get_tree().process_frame
	var test := OS.get_environment("DECOR_TEST")  # Compare looks: noshadow / nooutline.
	for mesh in room.find_children("*", "MeshInstance3D", true, false):
		if test == "noshadow":
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif test == "nooutline":
			for i in mesh.get_surface_override_material_count():
				var m: Material = mesh.get_surface_override_material(i)
				if m != null:
					m.next_pass = null
	var player: Player = Player.find(get_tree(), 0)
	player.global_position = Vector3(-2.0, player.global_position.y, 0.0)
	await get_tree().create_timer(2.0).timeout
	await _shot("room_1_player%s.png" % test)
	if not test.is_empty():
		get_tree().quit()
		return
	player.global_position = Vector3(-5.0, player.global_position.y, 2.0)
	await get_tree().create_timer(2.0).timeout
	await _shot("room_1_player_left.png")
	player.global_position = Vector3(4.0, player.global_position.y, -8.0)  # The kitchen.
	await get_tree().create_timer(2.5).timeout
	await _shot("room_1_player_kitchen.png")
	player.global_position = Vector3(-2.0, player.global_position.y, 0.0)
	await get_tree().create_timer(1.5).timeout
	var manager: PlayerManager = _find(main, func(n): return n is PlayerManager)[0]
	var spots := [Vector3(-5, 0, -2), Vector3(-1, 0, 2), Vector3(-5, 0, 3), Vector3(2, 0, -1)]
	for index in range(1, 4):
		var account := Accounts.find_by_name("Co-op chef %d" % (index + 1))
		if account.is_empty():
			account = Accounts.create("Co-op chef %d" % (index + 1))
		Accounts.assign(index, account["id"])
		InputSetup.assign_device(index, "pad_%d" % index)
		manager._spawn(index)
	await get_tree().create_timer(1.0).timeout
	for index in 4:
		var chef: Player = Player.find(get_tree(), index)
		chef.global_position = Vector3(spots[index].x, chef.global_position.y, spots[index].z)
	await get_tree().create_timer(3.0).timeout
	await _shot("room_4_players.png")
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
