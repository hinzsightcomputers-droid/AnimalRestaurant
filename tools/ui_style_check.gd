extends Node

# Checks data/ui_style.json (every color name it uses is in the palette) and
# takes pictures of the shared look: a sample menu panel with its buttons
# (normal, picked, disabled), HUD text over the game, and the Settings screen.
# Run (not headless) with SHOTS=<folder>:
#   godot --path . --resolution 1280x720 res://tools/ui_style_check.tscn

const GROUPS := ["panel", "text", "button", "focus", "hud"]


func _ready() -> void:
	var bad := _unknown_names()
	print("UI_STYLE unknown color names: ", bad if not bad.is_empty() else "none")
	var back := ColorRect.new()  # Stands in for the warm room behind the menus.
	back.color = Color("#90523C")
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	add_child(_sample_hud())
	add_child(_sample_panel())
	await get_tree().create_timer(0.5).timeout
	_shot("ui_sample.png")
	SettingsScreen.open(get_tree())
	await get_tree().create_timer(0.5).timeout
	_shot("ui_settings.png")
	get_tree().quit()


# Names in the groups that aren't palette colors or "#rrggbb" codes.
func _unknown_names() -> Array:
	var palette: Dictionary = UiStyle.data().get("palette", {})
	var bad := []
	for group in GROUPS:
		var spec: Dictionary = UiStyle.data().get(group, {})
		for key in spec:
			var value: Variant = spec[key]
			if value is String and not value.begins_with("#") and not palette.has(value):
				bad.append("%s.%s=%s" % [group, key, value])
	return bad


func _sample_panel() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel(28))
	panel.position = Vector2(380, 180)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Sample menu"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", UiStyle.role("text", "title"))
	column.add_child(title)
	var body := Label.new()
	body.text = "Body text on the cream panel."
	body.add_theme_font_size_override("font_size", 20)
	body.add_theme_color_override("font_color", UiStyle.role("text", "body"))
	column.add_child(body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	column.add_child(row)
	for text in ["Normal", "Picked", "Disabled"]:
		var button := Button.new()
		button.text = text
		button.add_theme_font_size_override("font_size", 22)
		button.disabled = text == "Disabled"
		row.add_child(button)
	(row.get_child(1) as Button).call_deferred("grab_focus")
	return panel


func _sample_hud() -> Control:
	var column := VBoxContainer.new()
	column.position = Vector2(24, 16)
	for pair in [["12:30", "text", 46], ["Spring 3", "money", 24], ["$1,250", "money", 26], ["3 in a row!", "streak", 22]]:
		var label := Label.new()
		label.text = pair[0]
		label.add_theme_font_size_override("font_size", pair[2])
		label.add_theme_constant_override("outline_size", 10)
		UiStyle.hud_label(label, pair[1])
		column.add_child(label)
	return column


func _shot(file: String) -> void:
	var folder := OS.get_environment("SHOTS")
	if folder != "":
		get_tree().root.get_texture().get_image().save_png(folder + "/" + file)
