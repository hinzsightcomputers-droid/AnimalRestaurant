# SlotPicker: the restaurants on this computer (SaveGame.SLOTS of them), opened
# from the start screen (Tab, or (Y) on a gamepad). Each shows its name, day,
# stars and money, or "Empty: start a new restaurant". Picking a different one
# remembers it (Settings.save_slot) and restarts the game into it, so nothing of
# the one before carries over; picking the one being played just closes it.
# Chefs (accounts) are shared: the same people can work in every restaurant.
class_name SlotPicker
extends CanvasLayer

signal closed

const TEXT_COLOR := Color("#502312")

var _first: Button


static func open(parent: Node) -> SlotPicker:
	var picker := SlotPicker.new()
	parent.add_child(picker)
	return picker


func _ready() -> void:
	layer = 25
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.add_theme_stylebox_override("panel", UiStyle.panel(18))
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(_label("Your restaurants", 26))
	for slot in range(1, SaveGame.SLOTS + 1):
		var button := Button.new()
		button.custom_minimum_size = Vector2(520, 64)
		button.add_theme_font_size_override("font_size", 19)
		button.text = describe(slot)
		button.pressed.connect(_pick.bind(slot))
		column.add_child(button)
		if slot == Settings.save_slot or _first == null:
			_first = button
	var back := Button.new()
	back.text = "Back"
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(_close)
	column.add_child(back)
	_first.grab_focus.call_deferred()


# "Sunny Spoon: day 12, 2 stars, $340 (playing now)" or "Empty: start a new restaurant".
static func describe(slot: int) -> String:
	var info := SaveGame.peek(slot)
	var playing := " (playing now)" if slot == Settings.save_slot else ""
	if info.is_empty() or String(info["name"]).is_empty():
		return "%d.  Empty: start a new restaurant%s" % [slot, playing]
	var stars := "%d star%s" % [info["stars"], "" if info["stars"] == 1 else "s"]
	return "%d.  %s: day %d, %s, $%d%s" % [slot, info["name"], info["day"], stars, info["money"], playing]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _pick(slot: int) -> void:
	if slot == Settings.save_slot:
		_close()
		return
	if SaveGame.has_save() or not GameState.restaurant_name.is_empty():
		SaveGame.save_game()  # The one being left, as it is.
	Settings.set_value("save_slot", slot)
	OS.set_restart_on_exit(true)
	get_tree().quit()  # A fresh start in the other restaurant.


func _close() -> void:
	closed.emit()
	queue_free()


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	return label
