extends Node

# Trays, the three-spot pass and the stack of bills: puts plates on the pass
# and picks them up with and without the Food Tray, fills the drink tray, and
# prints bills, checking counts; pictures of the pass and a chef with a tray.
# Run (not headless) with APPDATA pointing at a copy of a save with an account
# and SHOTS=<folder>:
#   godot --resolution 1280x720 res://tools/tray_check.tscn

var main: Node
var failures := 0


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
	var pass_counter: PassCounter = _find(main, func(n): return n is PassCounter)[0]
	GameState.upgrades.erase("food_tray")
	GameState.upgrades.erase("big_drink_tray")
	var dishes := GameData.menu()
	# Three plates down from the kitchen side.
	for i in 3:
		player.set_held_item(CookedDish.new(Order.new(null, dishes[i % dishes.size()]), 0.9))
		pass_counter._on_interacted(0)
	_check("three plates on the pass", pass_counter.items().size() == 3 and player.held_item == null)
	player.set_held_item(CookedDish.new(Order.new(null, dishes[0]), 0.9))
	_check("no fourth spot", pass_counter._prompt_for(0, false) != "Put down")
	player.set_held_item(null)
	player.global_position = pass_counter.global_position + Vector3(0.0, 0.0, 1.6)
	await get_tree().create_timer(0.6).timeout
	await _look_at(pass_counter.global_position + Vector3(0.0, 1.2, 0.0), Vector3(0.0, 1.4, 2.2))
	await _shot("tray_pass_three.png")
	# Without the Food Tray: one at a time.
	pass_counter._use(0, true)
	_check("one plate without the food tray", player.carrying() == 1 and pass_counter.items().size() == 2)
	player.set_held_item(null)
	GameState.upgrades.append("food_tray")
	_check("food tray holds 3", Player.tray_capacity("food") == 3)
	pass_counter._use(0, true)
	_check("both plates with the food tray", player.carrying() == 2 and pass_counter.items().is_empty())
	await get_tree().create_timer(0.3).timeout
	await _look_at(player.global_position + Vector3(0.0, 0.8, 0.0), Vector3(0.0, 1.2, 2.6))
	await _shot("tray_food.png")
	# Serving pops the next plate into the hand.
	player.set_held_item(null)
	_check("next plate to hand", player.carrying() == 1 and player.held_item is CookedDish)
	player.set_held_item(null)
	# Drinks: two from the start, four with the Big Drink Tray.
	var drinks := GameData.drink_menu()
	player.take(Drink.new(drinks[0]))
	_check("second drink fits", player.can_take(Drink.new(drinks[0])))
	player.take(Drink.new(drinks[min(1, drinks.size() - 1)]))
	_check("third drink doesn't", not player.can_take(Drink.new(drinks[0])))
	_check("no plate on a drink tray", not player.can_take(CookedDish.new(Order.new(null, dishes[0]), 1.0)))
	GameState.upgrades.append("big_drink_tray")
	_check("big drink tray holds 4", player.can_take(Drink.new(drinks[0])) and Player.tray_capacity("drinks") == 4)
	player.take(Drink.new(drinks[0]))
	await get_tree().create_timer(0.3).timeout
	await _shot("tray_drinks.png")
	var wanted_id: String = drinks[min(1, drinks.size() - 1)]["id"]
	_check("bring the right drink to hand", player.bring_to_hand(func(item): return item is Drink and item.id() == wanted_id) and player.held_item.id() == wanted_id and player.carrying() == 3)
	player.tray.clear()
	player.set_held_item(null)
	# Bills.
	var receipt := Receipt.new(3)
	_check("3 bills", receipt.display_name() == "3 bills")
	GameState.upgrades.erase("food_tray")
	GameState.upgrades.erase("big_drink_tray")
	print("TRAY %s (%d failed)" % ["ok" if failures == 0 else "FAIL", failures])
	get_tree().quit(0 if failures == 0 else 1)


func _check(what: String, ok: bool) -> void:
	print("TRAY   %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1


func _look_at(point: Vector3, offset: Vector3) -> void:
	var rig: Node = _find(main, func(n): return n is CameraRig)[0]
	rig.process_mode = Node.PROCESS_MODE_DISABLED
	var camera: Camera3D = _find(rig, func(n): return n is Camera3D)[0]
	camera.global_position = point + CameraRig.screen_to_world(offset)
	camera.look_at(point)
	camera.current = true
	await get_tree().create_timer(0.2).timeout


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
