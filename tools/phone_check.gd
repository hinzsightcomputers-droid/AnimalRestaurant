extends Node

# The phone and the Moober Treats app:
#   - a ring holds (quieter) through a conversation, then rings out with no
#     voicemail (whoever rang just calls back another time);
#   - a Moober order waits in the app, holds the bell, shows on the MyFone when
#     viewed, and accepting it writes a ticket and sends a courier, which keeps
#     holding the bell until it's delivered.
#   APPDATA=<copy of a save> godot res://tools/phone_check.tscn
# With SHOTS=<folder> (not headless) it saves the MyFone on screen.

var main: Node


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.0).timeout
	for i in 10:
		if Player.find(get_tree(), 0) != null:
			break
		await _key(KEY_ENTER, 0.1)
		await get_tree().create_timer(0.5).timeout
	await _pick_accounts()
	get_tree().paused = false
	var phone: Phone = _find(main, func(n): return n is Phone)[0]
	var day_manager: DayManager = _find(main, func(n): return n is DayManager)[0]
	GameState.phone_unlocked = true
	GameState.app_orders.clear()
	var ok := true

	# The ring, through a pretend conversation.
	var call := { "kind": "townsfolk", "id": GameData.callers[0]["id"] }  # (Rung by hand, to test the ring.)
	if call.is_empty():
		print("PHONE FAIL no call to ring")
		get_tree().quit(1)
		return
	phone._ring(call)
	var chat := Node.new()
	var fake := GDScript.new()
	fake.source_code = "extends Node\nvar player_index := 7\nvar speaker_id := \"\"\n"
	fake.reload()
	chat.set_script(fake)
	chat.add_to_group(ConversationBox.GROUP)
	add_child(chat)
	var ring: float = GameData.phone_settings.get("ring_seconds", 15.0)
	await get_tree().create_timer(ring + 3.0).timeout
	ok = _check("still ringing through the chat", phone.is_ringing()) and ok
	ok = _check("quieter during the chat", phone._ring_sound.volume_db < 0.0) and ok
	chat.queue_free()
	await get_tree().create_timer(maxf(ring, float(GameData.phone_settings.get("ring_after_chat_seconds", 8.0))) + 1.0).timeout
	ok = _check("rang out after the chat", not phone.is_ringing()) and ok
	ok = _check("no app order from a missed call", GameState.app_orders.is_empty()) and ok

	# A Moober order.
	var callers := GameData.callers.filter(func(c): return Townsfolk.is_in_town(c["id"]))
	phone.moober.add_order({ "kind": "townsfolk", "id": callers[0]["id"] if not callers.is_empty() else GameData.callers[0]["id"] })
	ok = _check("order waiting in the app", GameState.app_orders.size() == 1) and ok
	ok = _check("orders hold the bell", day_manager.orders_outstanding() and not day_manager.bell_ready()) and ok
	var player := Player.find(get_tree(), 0)
	var deliveries_before := phone.delivery_manager._couriers.size()
	await _key(KEY_TAB, 0.1)  # The phone button opens it.
	await get_tree().create_timer(0.8).timeout
	ok = _check("chef on the phone (interact is for it)", player.on_phone and player.in_conversation()) and ok
	var shots := OS.get_environment("SHOTS")
	if not shots.is_empty():
		DirAccess.make_dir_recursive_absolute(shots)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shots.path_join("myfone.png"))
	await _key(KEY_E, 0.1)  # Accept.
	await get_tree().create_timer(1.0).timeout
	await _key(KEY_E, 0.1)  # Hurry the ticket along.
	await get_tree().create_timer(2.5).timeout
	ok = _check("accepted: app empty", GameState.app_orders.is_empty() and not phone.moober.has_orders()) and ok
	ok = _check("accepted: a courier's coming", phone.delivery_manager._couriers.size() == deliveries_before + 1) and ok
	ok = _check("the delivery still holds the bell", day_manager.orders_outstanding()) and ok
	ok = _check("chef free again", not player.on_phone and not player.movement_locked) and ok
	print("PHONE ", "ALL OK" if ok else "FAILED")
	get_tree().quit(0 if ok else 1)


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


func _check(what: String, passed: bool) -> bool:
	print("PHONE %s %s" % ["ok  " if passed else "FAIL", what])
	return passed


func _find(n: Node, f: Callable, out := []) -> Array:
	if f.call(n):
		out.append(n)
	for c in n.get_children():
		_find(c, f, out)
	return out
