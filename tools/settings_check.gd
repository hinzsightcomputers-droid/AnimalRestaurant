extends Node

# The settings screen: a picture of the top and of the bottom of the list, and
# each new setting stepped once and read back. Run with APPDATA pointed at a
# test folder: SHOTS=<folder> godot --path . --resolution 1280x720 res://tools/settings_check.tscn


func _ready() -> void:
	if not OS.get_environment("APPDATA").to_lower().contains("temp"):
		print("SETTINGS CHECK refusing: point APPDATA at a test folder")
		get_tree().quit(1)
		return
	await get_tree().create_timer(0.5).timeout
	var screen := SettingsScreen.open(get_tree())
	await get_tree().create_timer(0.6).timeout
	await _shot("settings_top.png")
	var choices := screen.find_children("*", "Button", true, false).filter(func(b): return b.has_meta(&"step"))
	print("SETTINGS choice rows: ", choices.size())
	for button in choices:
		var before: String = button.text
		(button.get_meta(&"step") as Callable).call(1)
		print("SETTINGS stepped '%s' -> '%s'" % [before, button.text])
	choices.back().grab_focus()
	await get_tree().create_timer(0.6).timeout
	await _shot("settings_bottom.png")
	print("SETTINGS values: text_size %s text_speed %s render_scale %s max_fps %s" % [Settings.text_size, Settings.text_speed, Settings.render_scale, Settings.max_fps])
	print("SETTINGS saved: ", FileAccess.get_file_as_string("user://settings.json").contains("\"text_size\""))
	print("SETTINGS CHECK done")
	get_tree().quit()


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOTS") + "/" + file)
