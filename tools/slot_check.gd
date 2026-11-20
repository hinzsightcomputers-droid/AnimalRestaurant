extends Node

# Save slots: opens the restaurant picker on the start screen (a picture), then
# saves into slot 2 and checks slot 1 wasn't touched. Run with APPDATA pointed
# at a test folder holding a copy of a save (never the real one):
#   SHOTS=<folder>  godot --path . res://tools/slot_check.tscn


var driver := false


func _ready() -> void:
	if not driver:  # Outlive the scene change: run from a copy on the root.
		var copy: Node = get_script().new()
		copy.driver = true
		get_tree().root.add_child.call_deferred(copy)
		return
	if not OS.get_environment("APPDATA").to_lower().contains("temp"):
		print("SLOT CHECK refusing: point APPDATA at a test folder")
		get_tree().quit(1)
		return
	var slot1_before := FileAccess.get_md5(SaveGame.path(1))
	print("SLOT 1: ", SlotPicker.describe(1))
	print("SLOT 2: ", SlotPicker.describe(2))
	get_tree().change_scene_to_file.call_deferred("res://scenes/intro/street_intro.tscn")
	await get_tree().create_timer(3.0).timeout
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	Input.parse_input_event(tab)
	await get_tree().create_timer(1.0).timeout
	var picker := get_tree().root.find_children("*", "SlotPicker", true, false)
	print("SLOT picker open: ", not picker.is_empty())
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOTS") + "/slot_picker.png")
	# Save into slot 2 as if it had been picked.
	Settings.save_slot = 2
	var name_before := GameState.restaurant_name
	GameState.restaurant_name = "Slot Two Diner"
	SaveGame.save_game()
	GameState.restaurant_name = name_before
	Settings.save_slot = 1
	print("SLOT 2 after: ", SlotPicker.describe(2))
	print("SLOT 1 untouched: ", FileAccess.get_md5(SaveGame.path(1)) == slot1_before)
	print("SLOT CHECK done")
	get_tree().quit()
