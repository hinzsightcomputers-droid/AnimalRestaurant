# SettingsScreen: the settings, opened with Escape or Start from anywhere
# (see Settings). Sliders for the master, music and sound effects volumes and
# for how fast the close-up cursor moves on a gamepad and on the keys; a switch
# for the hybrid camera (two players' views join when they're close); and the
# hemisphere, which flips the seasons (kept in the save, not the settings).
# Any player's up/down (keys, stick, d-pad) picks a row, left/right changes
# it, interact flips a switch; the mouse works too. Escape, Start or B closes
# it. Pauses the game while open; changes apply and are kept straight away.
class_name SettingsScreen
extends CanvasLayer

const GROUP := "settings_screen"
const BROWN := Color(0.45, 0.28, 0.16)
const TEXT := Color(0.3, 0.22, 0.15)
const PANEL_MAX := Vector2(760, 600)
const SCREEN_MARGIN := 24.0

signal closed

var _was_paused := false
var _panel: PanelContainer
var _first: Control
var _close_button: Button


static func open(tree: SceneTree) -> SettingsScreen:
	var screen := tree.get_first_node_in_group(GROUP) as SettingsScreen
	if screen == null:
		screen = SettingsScreen.new()
		tree.root.add_child(screen)
	return screen


func _ready() -> void:
	add_to_group(GROUP)
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60  # Over the event banner (50), under the iris (100).
	_was_paused = get_tree().paused
	get_tree().paused = true
	_build()
	get_viewport().size_changed.connect(_fit_to_screen)
	_first.grab_focus()


func close() -> void:
	get_tree().paused = _was_paused
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(Settings.OPEN_ACTION) or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
		return
	for player_index in InputSetup.MAX_PLAYERS:
		if event.is_action_pressed(InputSetup.action_name(player_index, "interact")):
			get_viewport().set_input_as_handled()
			var button := get_viewport().gui_get_focus_owner() as BaseButton
			if button != null:
				if button.toggle_mode:
					button.button_pressed = not button.button_pressed
				else:
					button.pressed.emit()
			return
		for side in [["move_up", SIDE_TOP], ["move_down", SIDE_BOTTOM], ["move_left", SIDE_LEFT], ["move_right", SIDE_RIGHT]]:
			if event.is_action_pressed(InputSetup.action_name(player_index, side[0]), true):
				get_viewport().set_input_as_handled()
				_move(side[1])
				return


# Up and down pick a row; left and right change a slider.
func _move(side: Side) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null:
		_first.grab_focus()
		return
	if focused is Range and (side == SIDE_LEFT or side == SIDE_RIGHT):
		var slider := focused as Range
		slider.value += slider.step * (1.0 if side == SIDE_RIGHT else -1.0)
		return
	var next := focused.find_valid_focus_neighbor(side)
	if next != null:
		next.grab_focus()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.07, 0.05, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.99, 0.95, 0.86)
	style.set_border_width_all(6)
	style.border_color = Color(0.55, 0.38, 0.25)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(28)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.theme = _theme()
	add_child(_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	_panel.add_child(content)
	var title := _label(content, "Settings", 32, BROWN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 12)
	content.add_child(grid)
	_heading(grid, "Sound")
	_first = _volume_row(grid, "Master volume", "master_volume")
	_volume_row(grid, "Music", "music_volume")
	_volume_row(grid, "Sound effects", "sfx_volume")
	_heading(grid, "Controls")
	_speed_row(grid, "Cursor speed (gamepad)", "pad_cursor_speed")
	_speed_row(grid, "Cursor speed (keys)", "key_cursor_speed")
	_heading(grid, "Screen and world")
	var hybrid := CheckButton.new()
	hybrid.text = "Hybrid camera with two players"
	hybrid.tooltip_text = "On: your views join into one when you're close together. Off: always side by side."
	hybrid.button_pressed = Settings.hybrid_camera
	hybrid.add_theme_font_size_override("font_size", 20)
	hybrid.toggled.connect(func(on: bool): Settings.set_value("hybrid_camera", on))
	_mark(hybrid, _row_label(grid, "Split screen"))
	grid.add_child(hybrid)
	_label(grid, "", 18, TEXT)
	var hemisphere := Button.new()
	hemisphere.add_theme_font_size_override("font_size", 20)
	hemisphere.text = _hemisphere_text()
	hemisphere.pressed.connect(func():
		GameState.hemisphere = "south" if GameState.hemisphere == "north" else "north"
		SaveGame.save_game()
		hemisphere.text = _hemisphere_text())
	_mark(hemisphere, _row_label(grid, "Seasons"))
	grid.add_child(hemisphere)
	_label(grid, "", 18, TEXT)

	var hint := _label(content, "Up/down to pick, left/right to change. Escape, Start or B to close.", 16, Color(TEXT, 0.7))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(bottom)
	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.custom_minimum_size = Vector2(180, 46)
	_close_button.add_theme_font_size_override("font_size", 20)
	_close_button.pressed.connect(close)
	_close_button.focus_entered.connect(func(): _close_button.text = "> Close <")
	_close_button.focus_exited.connect(func(): _close_button.text = "Close")
	bottom.add_child(_close_button)
	_fit_to_screen()


# A brown ring round whatever is picked, and dark text on the switch.
func _theme() -> Theme:
	var theme := Theme.new()
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.set_border_width_all(3)
	ring.border_color = BROWN
	ring.set_corner_radius_all(8)
	ring.set_expand_margin_all(5)
	for type in ["HSlider", "Button", "CheckButton"]:
		theme.set_stylebox("focus", type, ring)
	for color in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(color, "CheckButton", TEXT)
	return theme


func _hemisphere_text() -> String:
	return "Northern hemisphere" if GameState.hemisphere == "north" else "Southern hemisphere"


# A 0-100% slider for a volume.
func _volume_row(grid: GridContainer, text: String, key: String) -> HSlider:
	return _slider_row(grid, text, key, 0.0, 1.0, 0.05, func(value: float) -> String: return "%d%%" % roundi(value * 100.0))


# A slider for a cursor speed, e.g. 1.2x.
func _speed_row(grid: GridContainer, text: String, key: String) -> HSlider:
	var limits := Settings.cursor_speed_range
	return _slider_row(grid, text, key, limits.x, limits.y, 0.1, func(value: float) -> String: return "%.1fx" % value)


func _slider_row(grid: GridContainer, text: String, key: String, low: float, high: float, step: float, shown: Callable) -> HSlider:
	var row := _row_label(grid, text)
	var slider := HSlider.new()
	_mark(slider, row)
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = float(Settings.get(key))
	slider.custom_minimum_size = Vector2(260, 28)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(slider)
	var value_label := _label(grid, shown.call(slider.value), 20, TEXT)
	value_label.custom_minimum_size = Vector2(64, 0)
	slider.value_changed.connect(func(value: float):
		value_label.text = shown.call(value)
		Settings.set_value(key, value))
	return slider


func _heading(grid: GridContainer, text: String) -> void:
	_label(grid, text, 22, BROWN)
	_label(grid, "", 18, TEXT)
	_label(grid, "", 18, TEXT)


func _row_label(grid: GridContainer, text: String) -> Label:
	return _label(grid, text, 20, TEXT)


# The picked row shows on its label: an arrow, in brown.
func _mark(control: Control, label: Label) -> void:
	var text := label.text
	control.focus_entered.connect(func():
		label.text = "> " + text
		label.add_theme_color_override("font_color", BROWN))
	control.focus_exited.connect(func():
		label.text = text
		label.add_theme_color_override("font_color", TEXT))


func _label(parent: Control, text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _fit_to_screen() -> void:
	var screen := get_viewport().get_visible_rect().size
	var needed := _panel.get_combined_minimum_size()
	var size := needed.max(Vector2(PANEL_MAX.x, needed.y)).min(screen - Vector2.ONE * SCREEN_MARGIN * 2.0)
	_panel.size = size
	_panel.position = (screen - size) / 2.0
