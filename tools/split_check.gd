extends Node

# Four chefs at once, each in a close-up (stove, chopping board, sink, table),
# to check the close-ups and the HUD in the four-way split. Run (not headless)
# with APPDATA pointing at a copy of a save with an account and SHOTS=<folder>:
#   godot --resolution 1920x1080 res://tools/split_check.tscn
# PREFIX=<text> starts every file name; RECIPE=<name> is what the stove cooks;
# PLAYERS=<n> how many chefs (4). ORDERS=1 takes pictures of the HUD's tickets instead,
# BREAK=1 of the break between meals (staff meal, sweeping up, dashing, bumping).

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
	var manager: PlayerManager = _find(main, func(n): return n is PlayerManager)[0]
	var count := int(OS.get_environment("PLAYERS")) if not OS.get_environment("PLAYERS").is_empty() else 4
	for index in range(1, count):
		InputSetup.assign_device(index, "pad_%d" % index)
		manager._spawn(index)
	await get_tree().create_timer(1.0).timeout
	await _pick_accounts()
	if not OS.get_environment("ORDERS").is_empty():
		await _orders()
		get_tree().quit()
		return
	if not OS.get_environment("BREAK").is_empty():
		await _break()
		get_tree().quit()
		return
	var stove: CookingStation = _find(main, func(n): return n is CookingStation and n.station_id == "stove")[0]
	var board: Node = _find(main, func(n): return n is ChoppingBoard)[0]
	var sink: Node = _find(main, func(n): return n is Sink)[0]
	var table: Node = _find(main, func(n): return n is DiningTable)[0]
	var recipe := OS.get_environment("RECIPE") if not OS.get_environment("RECIPE").is_empty() else "soup"
	var jobs := [[stove, recipe], [board, "chopping"], [sink, "wash_dishes"], [table, "clear_table"]]
	for index in count:
		var player: Player = Player.find(get_tree(), index)
		var station: Node3D = jobs[index][0]
		player.global_position = station.global_position + station.global_transform.basis.z * 0.9
	await get_tree().create_timer(0.8).timeout
	for index in count:
		jobs[index][0].reel_cook(Player.find(get_tree(), index), load("res://data/recipes/%s.tres" % jobs[index][1]), {})
	for i in 6:
		await get_tree().create_timer(1.6).timeout
		for job in jobs:
			if is_instance_valid(job[0].session):
				job[0].session.input.scripted = false
		await get_tree().process_frame
		await get_tree().process_frame
		await _shot("split_%d.png" % i)
		for job in jobs:
			if is_instance_valid(job[0].session):
				job[0].session.input.scripted = true
	get_tree().quit()


# The HUD with orders of every kind on it.
func _orders() -> void:
	var boards := _find(main, func(n): return n is OrderBoard)
	await get_tree().create_timer(12.0).timeout
	var board: OrderBoard = boards[0]
	var seats := _find(main, func(n): return n is Seat and n.table != null)
	var customers := get_tree().get_nodes_in_group(Customer.GROUP)
	var i := 0
	for customer in customers:
		customer.seat = seats[i * 2 % seats.size()]
		customer.global_position = customer.seat.seat_point.global_position
		customer.state = Customer.State.WAITING_FOR_FOOD
		customer.state_changed.emit(customer)
		var order := board.add_order(customer)
		order.on_wheel = i != 0
		i += 1
	board.add_delivery(GameData.dishes[2], { "kind": "townsfolk", "name": "Pip" })
	board.add_delivery(GameData.dishes[4], { "kind": "takeout", "name": "To go" })
	if board.orders.size() > 1:
		board.set_state(board.orders[0], Order.State.READY)
		Player.find(get_tree(), 0).set_held_item(CookedDish.new(board.orders[0], 0.9))
		board.set_state(board.orders[1], Order.State.COOKING)
	var first: Player = Player.find(get_tree(), 0)
	first.global_position = Vector3(2.2, 0.0, 0.7)
	await get_tree().create_timer(3.0).timeout
	await _shot("orders.png")


# The break: a staff meal on the table, crumbs and spills about, mopping one up,
# eating, then a dash into a friend.
func _break() -> void:
	var day: DayManager = _find(main, func(n): return n is DayManager)[0]
	var a: Player = Player.find(get_tree(), 0)
	var b: Player = Player.find(get_tree(), 1)
	for station in _find(main, func(n): return n is CookingStation or n is ChoppingBoard):
		day.floor_care.add_mess("spill" if station is CookingStation else "peelings", station.get_node("Interactable").global_position)
	day.floor_care.end_of_meal()
	day.meal_break.begin()
	await get_tree().create_timer(1.5).timeout
	for mess in get_tree().get_nodes_in_group(FloorMess.GROUP):
		print("CHECK mess ", mess.kind, " ", mess.global_position.snapped(Vector3.ONE * 0.1))
	var mess: FloorMess = get_tree().get_nodes_in_group(FloorMess.GROUP)[0]
	a.global_position = mess.global_position + Vector3(0.0, 0.0, 0.7)
	b.global_position = day.meal_break.global_position + Vector3(0.0, 0.0, 1.2)
	await get_tree().create_timer(1.0).timeout
	await _shot("break_0.png")
	print("CHECK a sees ", a.interactor.focused.prompt_for(0) if a.interactor.focused != null else "nothing", ", b sees ", b.interactor.focused.prompt_for(1) if b.interactor.focused != null else "nothing")
	var before := day.floor_care.count()
	a.interactor.try_interact(0)
	Input.action_press("p0_interact")
	b.interactor.try_interact(1)
	await get_tree().create_timer(0.8).timeout
	await _shot("break_1.png")
	await get_tree().create_timer(2.0).timeout
	Input.action_release("p0_interact")
	print("CHECK messes ", before, " -> ", day.floor_care.count(), ", free to move ", not a.movement_locked, " ", not b.movement_locked)
	day.meal_break.finish()
	print("CHECK well fed ", a.well_fed, " ", b.well_fed)
	a.global_position = Vector3(2.2, 0.0, 2.4)
	b.global_position = Vector3(2.2, 0.0, 1.0)
	await get_tree().create_timer(0.5).timeout
	var direction := CameraRig.screen_to_world(Vector3.RIGHT)
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		var way := CameraRig.screen_to_world({ "move_left": Vector3.LEFT, "move_right": Vector3.RIGHT, "move_up": Vector3.FORWARD, "move_down": Vector3.BACK }[action])
		if way.dot(Vector3.FORWARD) > 0.9:
			Input.action_press("p0_" + action)
			direction = way
	var start_a := a.global_position
	var start_b := b.global_position
	Input.action_press("p0_dash")
	await get_tree().create_timer(0.12).timeout
	await _shot("break_2.png")
	await get_tree().create_timer(0.35).timeout
	print("CHECK dash: a moved ", start_a.distance_to(a.global_position), ", b bumped ", start_b.distance_to(b.global_position))
	for action in ["move_left", "move_right", "move_up", "move_down", "dash"]:
		Input.action_release("p0_" + action)
	await _shot("break_3.png")


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
