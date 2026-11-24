extends Node

# The drink machines, with pictures: a pop from the fountain (along to its tap,
# a tap too short that has to be topped up, then up to the line), a water, a hot
# chocolate from the brewer with its marshmallows, stepping away; then carrying
# them about: how far each drink rocks as the chef starts, turns and stops, and
# that it settles. Run (not headless) with APPDATA pointing at a copy of a save
# with an account and SHOTS=<folder> (ALL=1: every drink unlocked):
#   godot --resolution 1600x900 res://tools/drink_check.tscn

var main: Node
var player: Player
var failed := 0


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
	if OS.get_environment("ALL") == "1":
		for drink in GameData.drinks:
			if not GameData.is_unlocked(drink["id"]):
				GameState.unlocks.append(drink["id"])
	var fountain: DrinkStation = _find(main, func(n): return n is DrinkStation and not n.brewer)[0]
	var brewer: DrinkStation = _find(main, func(n): return n is DrinkStation and n.brewer)[0]
	player.global_position = fountain.global_position + fountain.global_basis.z * 1.6
	await get_tree().create_timer(1.5).timeout
	await _shot("room.png")
	await _make(fountain, "koala_cola", 0.35)
	await _make(fountain, "water", 0.0)
	await _carry("cold")
	player.set_held_item(null)
	player.set_held_item(null)
	player.global_position = brewer.global_position + brewer.global_basis.z * 0.9
	await _make(brewer, "hot_chocolate", 0.0)
	await _make(brewer, "coffee", 0.0)
	await _carry("hot")
	player.set_held_item(null)
	player.set_held_item(null)
	# Stepping away from an empty glass.
	fountain._start(player)
	await get_tree().create_timer(0.8).timeout
	await _tap("p0_decor_done")
	await get_tree().create_timer(0.2).timeout
	_check("back steps away", fountain._pourer == null and not player.movement_locked and player.held_item == null)
	# Far too much: it spills.
	fountain._start(player)
	await get_tree().create_timer(0.8).timeout
	Input.action_press("p0_interact")
	await get_tree().create_timer(2.6).timeout
	await _shot("spilled.png")
	Input.action_release("p0_interact")
	await get_tree().create_timer(1.0).timeout
	_check("spilling scores little", player.held_item is Drink and player.held_item.quality <= 0.21)
	print("CHECK %d failed" % failed)
	get_tree().quit()


func _make(station: DrinkStation, id: String, short: float) -> void:
	station._start(player)
	await get_tree().create_timer(0.9).timeout
	_check("%s: starts at the middle tap" % id, station._tap == station._drinks.size() / 2)
	var goal := -1
	for i in station._drinks.size():
		if station._drinks[i]["id"] == id:
			goal = i
	await _shot("%s_1_choose.png" % id)
	for i in 30:
		if station._tap == goal:
			break
		await _tap("p0_move_right" if goal > station._tap else "p0_move_left")
		await get_tree().create_timer(0.12).timeout
	_check("%s: slid to its tap" % id, station._tap == goal)
	await get_tree().create_timer(0.6).timeout
	if short > 0.0:
		Input.action_press("p0_interact")
		await get_tree().create_timer(short).timeout
		await _shot("%s_2_pouring.png" % id)
		Input.action_release("p0_interact")
		await get_tree().create_timer(0.4).timeout
		_check("%s: let go early, it can be topped up" % id, station._pour == DrinkStation.Pour.CHOOSE and station._fill > 0.05)
		var before := station._tap
		await _tap("p0_move_left")
		await get_tree().create_timer(0.1).timeout
		_check("%s: no moving it half full" % id, station._tap == before)
	Input.action_press("p0_interact")
	var shot := false
	while station._fill < DrinkStation.LINE - 0.01 and station._pour != DrinkStation.Pour.NONE:
		await get_tree().process_frame
		if not shot and station._fill > 0.5:
			shot = true
			await _shot("%s_3_pouring.png" % id)
	Input.action_release("p0_interact")
	await get_tree().create_timer(0.3).timeout
	await _shot("%s_4_full.png" % id)
	await get_tree().create_timer(0.7).timeout
	if station._pour == DrinkStation.Pour.TOPPING:
		await _shot("%s_5_topping.png" % id)
		await _tap("p0_interact")
		for i in 4:
			await get_tree().create_timer(0.3).timeout
			await _shot("%s_6_marshmallows_%d.png" % [id, i])
	await get_tree().create_timer(1.6).timeout
	var made: Array = player.carried().filter(func(d): return d is Drink and d.id() == id)
	_check("%s: in hand, quality %.2f" % [id, made[0].quality if not made.is_empty() else -1.0], not made.is_empty() and made[0].quality > 0.9 and not player.movement_locked)


func _carry(prefix: String) -> void:
	var drinks: Array = _find(player, func(n): return n is DrinkModel and not n.is_queued_for_deletion())
	_check("%s: %d carried" % [prefix, drinks.size()], drinks.size() >= 1)
	if drinks.is_empty():
		return
	var model: DrinkModel = drinks[0]
	player.global_position = Vector3(-1.0, player.global_position.y, 2.2)
	await get_tree().create_timer(1.5).timeout
	var most := 0.0
	for leg in ["p0_move_left", "p0_move_right", "p0_move_up", "p0_move_down"]:
		Input.action_press(leg)
		for frame in 25:
			await get_tree().physics_frame
			most = maxf(most, model._rock.length())
			if frame == 8 or frame == 24:
				await _shot("%s_carry_%s_%d.png" % [prefix, leg, frame])
		Input.action_release(leg)
	_check("%s: rocks as it's carried (%.1f mm at the rim)" % [prefix, most * 1000.0], most > 0.003)
	await get_tree().create_timer(5.0).timeout
	_check("%s: settles (%.2f mm)" % [prefix, model._rock.length() * 1000.0], model._rock.length() < 0.0006)
	var zoom := CameraZoomSettings.new()
	zoom.distance = 0.9
	zoom.pitch_degrees = 35.0
	zoom.yaw_degrees = 120.0
	player.request_camera_focus(model.global_position + Vector3.UP * 0.1, zoom)
	await get_tree().create_timer(0.8).timeout
	await _shot("%s_close_still.png" % prefix)
	model.jolt(0.35)
	for i in 3:
		await get_tree().create_timer(0.09).timeout
		await _shot("%s_close_rocking_%d.png" % [prefix, i])
	player.release_camera_focus()
	await get_tree().create_timer(0.6).timeout


func _tap(action: String) -> void:
	for down in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = down
		Input.parse_input_event(event)
		await get_tree().create_timer(0.08).timeout


func _check(what: String, ok: bool) -> void:
	if not ok:
		failed += 1
	print("CHECK %s %s" % ["ok  " if ok else "FAIL", what])


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
