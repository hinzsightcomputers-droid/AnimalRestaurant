extends Node

# The soup's vegetables at the chopping board, the soup, then the mac, played by
# script with pictures of every step; at the mac's draining, stray presses
# (mashing, or still holding from the grating) must not take the pasta off. Run
# (not headless) with APPDATA pointing at a copy of a save with an account and
# SHOTS=<folder> (ONLY=chop: just the vegetables; ONLY=four_cheese_mac: just the mac):
#   godot --resolution 1600x900 res://tools/soup_mac_check.tscn

var main: Node
var player: Player


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
	player = Player.find(get_tree(), 0)
	var stove: CookingStation = _find(main, func(n): return n is CookingStation and n.station_id == "stove")[0]
	var board: ChoppingBoard = _find(main, func(n): return n is ChoppingBoard)[0]
	var dishes := {}
	for dish in GameData.dishes:
		dishes[dish["id"]] = dish
	var soup: Dictionary = dishes["vegetable_soup"]
	var recipe := OS.get_environment("RECIPE")  # Just this recipe, cooked at the stove (no chopping first).
	if OS.get_environment("ONLY") != "four_cheese_mac" and recipe.is_empty():
		player.global_position = board.global_position + board.global_transform.basis.z * 0.9
		await get_tree().create_timer(0.8).timeout
		board._open_closeup(player, Ingredients.new(Order.new(null, soup)))
		board.session.input.scripted = true
		await _play("chop", board.session)
		if OS.get_environment("ONLY") == "chop":
			get_tree().quit()
			return
	player.set_held_item(null)
	player.global_position = stove.global_position + stove.global_transform.basis.z * 0.9
	var jobs := [["soup", soup], ["four_cheese_mac", {}]] if recipe.is_empty() else [[recipe, {}]]
	for job in jobs:
		if recipe.is_empty() and OS.get_environment("ONLY") not in ["", job[0]]:
			continue
		await get_tree().create_timer(2.5).timeout
		if OS.get_environment("AT") == "board":  # A chopping board recipe (filleting).
			player.global_position = board.global_position + board.global_transform.basis.z * 0.9
			board.reel_cook(player, load("res://data/recipes/%s.tres" % job[0]), job[1])
			await _play(job[0], board.session)
			continue
		stove.reel_cook(player, load("res://data/recipes/%s.tres" % job[0]), job[1])
		await _play(job[0], stove.session)
	get_tree().quit()


func _play(prefix: String, session: CookSession) -> void:
	Input.action_release("p0_interact")
	var last: CookAction = null
	var shot := 1
	var clock := 0.0
	var began := Time.get_ticks_msec()
	var next := 0.0
	while is_instance_valid(session) and not session.is_finished and clock < 120.0:
		await get_tree().process_frame
		clock += get_process_delta_time()
		if session.current == null:
			continue
		if session.current != last:
			if last != null:
				print("CHECK %s '%s' %.2f" % [prefix, last.title, last.quality])
			last = session.current
			next = clock + 0.7
			if last is DrainAction:
				await _stray(session, last)
				next = clock
		if clock >= next:
			next = clock + (1.6 if prefix != "chop" else 0.5) * (0.12 if last is LadleAction or last is WrapAction or last is ToastAction or last is SteakPrepAction or last is ChalkAction else 1.0)
			await _shot("%s_%02d_%s.png" % [prefix, shot, last.title.to_snake_case().replace("!", "").replace(":", "")])
			shot += 1
	if is_instance_valid(session):
		print("CHECK %s done in %.1f s: %s" % [prefix, (Time.get_ticks_msec() - began) / 1000.0, session.steps.map(func(s): return "%s %.2f" % [s.title, s.quality])])
		await _shot("%s_%02d_done.png" % [prefix, shot])
	await get_tree().create_timer(2.5).timeout


# Someone still mashing (and then holding) from the grating, then doing it right.
func _stray(session: CookSession, drain: DrainAction) -> void:
	var boil := session.step_of(BoilAction) as BoilAction
	session.input.scripted = false
	for i in 8:
		Input.action_press("p0_interact")
		await get_tree().create_timer(0.1).timeout
		Input.action_release("p0_interact")
		await get_tree().create_timer(0.1).timeout
	print("CHECK mashing early: off=%s (cooked %.2f)" % [drain._off, boil.doneness])
	Input.action_press("p0_interact")
	boil.doneness = 1.0
	await get_tree().create_timer(0.8).timeout
	print("CHECK still holding in the green: off=%s" % drain._off)
	Input.action_release("p0_interact")
	await get_tree().create_timer(0.5).timeout
	Input.action_press("p0_interact")
	await get_tree().create_timer(0.8).timeout
	print("CHECK pressed: off=%s, still held pouring=%s, boil %.2f" % [drain._off, drain._pouring, boil.quality])
	Input.action_release("p0_interact")
	await get_tree().create_timer(0.2).timeout
	Input.action_press("p0_interact")
	await get_tree().create_timer(0.12).timeout
	Input.action_release("p0_interact")
	await get_tree().create_timer(0.2).timeout
	print("CHECK tapped: done=%s" % drain.done)
	session.input.scripted = true


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
