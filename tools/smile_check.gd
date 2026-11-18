extends Node

# The big breakfast's ketchup smile, cooked twice in a row at each stove
# (scripted, like a reel): a picture of the guide as the smile step starts,
# and which guide dots are hidden under food. Run (not headless) with APPDATA
# pointing at a copy of a save with an account and SHOTS=<folder>:
#   godot --resolution 1280x720 res://tools/smile_check.tscn

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
	var recipe: CookRecipe = load("res://data/recipes/big_breakfast.tres")
	var stoves := _find(main, func(n): return n is CookingStation and n.station_id == "stove")
	print("SMILE stoves: ", stoves.size())
	var shot := 0
	for stove in stoves.slice(0, 2):
		for round in 2:
			player.global_position = stove.global_position + stove.global_transform.basis.z * 0.9
			stove.reel_cook(player, recipe, {})
			var session: CookSession = stove.session
			print("SMILE cooking at ", stove.name, " round ", round + 1, ": ", session)
			var seen := false
			var last_title := ""
			for t in 20000:
				await get_tree().process_frame
				if not is_instance_valid(session) or session.is_finished:
					break
				if session.current != null and session.current.title != last_title:
					last_title = session.current.title
					print("SMILE   step ", last_title)
				if session.current is SqueezeAction and not seen:
					seen = true
					session.input.scripted = false  # Hold still: look at the guide.
					await get_tree().create_timer(1.0).timeout
					var action: SqueezeAction = session.current
					var shown := action._dot_nodes.filter(func(d): return is_instance_valid(d) and d.visible).size()
					print("SMILE stove %s round %d: guide %d points, %d dots shown, ticked %d" % [stove.name, round + 1, action._guide.size(), shown, action._ticked.count(true)])
					for piece in session.pieces:
						if is_instance_valid(piece):
							print("   piece ", piece.name, " at ", piece.position)
					shot += 1
					await _shot("smile_%d_%s_round%d.png" % [shot, stove.name, round + 1])
					session.input.scripted = true
			for t in 3000:
				await get_tree().process_frame
				if stove.session == null:
					break
			player.set_held_item(null)
			await get_tree().create_timer(1.0).timeout
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


func _find(root: Node, test: Callable) -> Array:
	var found := []
	for child in root.get_children():
		if test.call(child):
			found.append(child)
		found.append_array(_find(child, test))
	return found
