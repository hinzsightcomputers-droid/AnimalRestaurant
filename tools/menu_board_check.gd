extends "res://tools/soup_mac_check.gd"

# The menu chalkboard: breakfast waits for its menu, a scripted chef writes it
# (pictures of the close-up), then pictures of the board in the room. Run like
# soup_mac_check, with SHOTS=<folder>:
#   godot --resolution 1600x900 res://tools/menu_board_check.tscn


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
	var days: DayManager = _find(main, func(n): return n is DayManager)[0]
	var board := MenuBoard.find(get_tree())
	print("CHECK board found: %s" % (board != null))
	DayCycle.force(DayCycle.Phase.MEAL, int(OS.get_environment("MEAL")) if not OS.get_environment("MEAL").is_empty() else 0)
	GameState.menu_written_meal = -1
	days._start_phase(DayCycle.meal, 0.0)
	print("CHECK waiting: %s, bell ready: %s, menu: %s" % [board.is_waiting(), days.bell_ready(), GameData.meal_menu().map(func(d): return d["id"])])
	player.global_position = board.global_position + board.global_transform.basis.z * 1.0
	await get_tree().create_timer(1.0).timeout
	await _shot("menu_00_waiting.png")
	board.open_closeup(player, true)
	await _play("menu", board.session)
	await get_tree().create_timer(1.5).timeout
	print("CHECK written: waiting=%s, menu_written_meal=%d" % [board.is_waiting(), GameState.menu_written_meal])
	player.global_position = board.global_position + board.global_transform.basis.z * 1.6
	await get_tree().create_timer(1.5).timeout
	await _shot("menu_99_board.png")
	get_tree().quit()
