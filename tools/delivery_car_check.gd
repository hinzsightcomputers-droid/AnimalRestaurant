extends "res://tools/soup_mac_check.gd"

# The delivery cart in the whole game: night, a phoned-in order bagged and
# handed to player 1, who puts it in the cart (its courier goes home) and
# drives it (on autopilot). Checks the order's paid and off the board, the
# cart's empty and the night isn't held up. Run with SHOTS=<folder>:
#   godot --resolution 1600x900 res://tools/delivery_car_check.tscn

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
	await get_tree().create_timer(1.0).timeout
	DeliveryDrive.test_autopilot = true
	GameState.phone_unlocked = true
	DayCycle.to_night()
	var manager: DeliveryManager = _find(main, func(n): return n is DeliveryManager)[0]
	var caller := { "kind": "townsfolk", "id": "amy", "name": "Amy", "species": "songbird", "regular_id": "" }
	var order := manager.add_delivery(GameData.random_dish(), caller)
	await get_tree().create_timer(2.0).timeout
	var player := Player.find(get_tree(), 0)
	player.set_held_item(TakeoutBag.of_dish(CookedDish.new(order, 0.95)))
	var car := manager.car
	player.global_position = car.global_transform * Vector3(-1.6, 0.0, 0.0)
	await get_tree().create_timer(1.5).timeout
	await _shot("car_01_by_cart.png")
	print("CHECK prompt with bag: '%s'" % car._prompt_for(0))
	var money := GameState.money
	car._on_interacted(0)
	print("CHECK loaded %d, courier %s, holding %s" % [car.loaded.size(), "gone home" if manager.courier_for(order) == null else "still here", player.held_item])
	await get_tree().create_timer(0.5).timeout
	await _shot("car_02_loaded.png")
	print("CHECK prompt empty-handed: '%s'" % car._prompt_for(0))
	car._on_interacted(0)
	await get_tree().create_timer(6.0).timeout
	await _shot("car_03_driving.png")
	var waited := 0.0
	while car.driver >= 0 and waited < 120.0:
		await get_tree().create_timer(1.0).timeout
		waited += 1.0
	await get_tree().create_timer(1.0).timeout
	await _shot("car_04_back.png")
	print("CHECK back after %.0f s: money +%d, on board %s, cart busy %s, player locked %s visible %s" % [waited, GameState.money - money, order in manager.order_board.orders if "orders" in manager.order_board else "?", car.busy(), player.movement_locked, player.visible])
	get_tree().quit()
