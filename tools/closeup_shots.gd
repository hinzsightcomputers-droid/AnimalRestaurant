extends Node

# Pictures of close-ups cooking themselves (a reel's chef), to see how they look:
# one every EVERY seconds (0.7) all the way through. Run (not headless) with
# APPDATA pointing at a copy of a save with an account and SHOTS=<folder>;
# DISHES=<dish ids or recipe names, comma-separated>; STEPS=<titles, comma-separated>
# takes pictures only of those; FPS=1 prints how long frames took in each step:
#   godot --resolution 1600x900 res://tools/closeup_shots.tscn

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
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):  # Just the food.
		if layer.scene_file_path.ends_with("hud.tscn"):
			layer.visible = false
	var dishes := {}
	for dish in GameData.dishes:
		dishes[dish["id"]] = dish
	for id in OS.get_environment("DISHES").split(","):
		var dish: Dictionary = dishes.get(id, {})
		var recipe: CookRecipe = CookRecipe.for_dish(dish) if not dish.is_empty() else load("res://data/recipes/%s.tres" % id)
		if recipe == null:
			print("CHECK no close-up for ", id)
			continue
		var at: String = dish.get("station", "stove")
		var stations := _find(main, func(n): return n is CookingStation and n.station_id == at)
		if dish.is_empty():  # Not a dish: what it's for.
			var kind := { "chopping": "ChoppingBoard", "soup_vegetables": "ChoppingBoard", "filleting": "ChoppingBoard", "wash_dishes": "Sink", "clear_table": "DiningTable", "wipe_table": "DiningTable", "fishing": "FishingSpot" }
			stations = _find(main, func(n): return n.get_script() != null and n.get_script().get_global_name() == kind.get(id, "-"))
		if stations.is_empty():
			stations = _find(main, func(n): return n is CookingStation and n.station_id == "stove")
		var station: Node3D = stations[0]
		player.global_position = station.global_position + station.global_transform.basis.z * 0.9
		await get_tree().create_timer(0.6).timeout
		if station is FishingSpot:
			station.reel_start(player)
		else:
			station.reel_cook(player, recipe, dish)
		await _play(id, station.session)
	get_tree().quit()


func _play(id: String, session: CookSession) -> void:
	var every := float(OS.get_environment("EVERY")) if not OS.get_environment("EVERY").is_empty() else 0.7
	var only := OS.get_environment("STEPS").split(",", false)
	var left := every
	var taken := 0
	var last: CookAction = null
	var slowest := 0.0
	var frames := 0
	var time := 0.0
	var clock := 0.0
	while is_instance_valid(session) and not session.is_finished and clock < 150.0:
		await get_tree().process_frame
		var delta := get_process_delta_time()
		clock += delta
		if not is_instance_valid(session) or session.current == null:
			continue
		if session.current != last:
			if last != null and OS.get_environment("FPS") == "1":
				print("CHECK %s '%s': %.1f ms a frame, %.1f the slowest" % [id, last.title, time / maxi(frames, 1) * 1000.0, slowest * 1000.0])
			last = session.current
			slowest = 0.0
			frames = 0
			time = 0.0
		frames += 1
		time += delta
		if frames > 5:
			slowest = maxf(slowest, delta)
		left -= delta
		if left <= 0.0 and (only.is_empty() or last.title in only):
			left = every
			taken += 1
			await _shot("%s_%03d_%s.png" % [id, taken, last.title.to_snake_case().validate_filename()])
	await get_tree().create_timer(0.5).timeout
	await _shot("%s_%03d_done.png" % [id, taken + 1])
	print("CHECK %s done%s" % [id, " %.2f" % session.quality if is_instance_valid(session) else ""])
	await get_tree().create_timer(2.5).timeout


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
