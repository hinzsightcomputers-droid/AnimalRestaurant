# BirthdayPicker: asks a chef their birthday while they're picked (AccountPicker),
# before the day starts: a grid of months (plus "I'd rather not say"), then a
# grid of that month's days, then a thank-you. Works with mouse, keys or a
# gamepad (focus moves between the buttons). Saves it in GameState.birthdays
# ("" if they'd rather not say, so they aren't asked again) and emits
# `finished`. The lines are in design/calendar/calendar.json
# (birthday_question). BirthdayAsker still asks in game anyone who somehow
# reached the restaurant without one (e.g. after the debug panel's
# "Forget birthdays").
class_name BirthdayPicker
extends CanvasLayer

signal finished

const TEXT_COLOR := Color(0.25, 0.18, 0.12)
const BUTTON_SIZE := Vector2(132, 46)
const DAY_BUTTON_SIZE := Vector2(64, 46)

var account_id := ""
var chef_name := ""

var _lines: Dictionary = {}
var _title := Label.new()
var _prompt := Label.new()
var _grid := GridContainer.new()
var _was_paused := false


static func open(parent: Node, for_account: String, name_to_use: String) -> BirthdayPicker:
	var picker := BirthdayPicker.new()
	picker.account_id = for_account
	picker.chef_name = name_to_use
	parent.add_child(picker)
	return picker


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = get_tree().paused
	get_tree().paused = true
	_lines = EventCalendar.data().get("birthday_question", {})

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.97, 0.9, 0.97)
	style.border_color = Color(0.55, 0.4, 0.28)
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	for label: Label in [_title, _prompt]:
		label.add_theme_color_override("font_color", TEXT_COLOR)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 560
		column.add_child(label)
	_title.add_theme_font_size_override("font_size", 28)
	_prompt.add_theme_font_size_override("font_size", 22)
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	var center := CenterContainer.new()
	center.add_child(_grid)
	column.add_child(center)

	_title.text = _lines.get("title", "Before we open")
	_show_months()


func _show_months() -> void:
	_prompt.text = String(_lines.get("ask_month", "When's your birthday?")).format({ "player": chef_name })
	_clear(4)
	for index in EventCalendar.MONTHS.size():
		_button(EventCalendar.MONTHS[index], BUTTON_SIZE, _show_days.bind(index + 1))
	# 12 months fill 3 rows of 4, so this starts a row of its own.
	_button(_lines.get("rather_not_say", "I'd rather not say"), BUTTON_SIZE, _save.bind(""))
	_focus_first()


func _show_days(month: int) -> void:
	var month_name: String = EventCalendar.MONTHS[month - 1]
	_prompt.text = "%s. %s" % [month_name, _lines.get("ask_day", "And the day?")]
	_clear(7)
	for day in range(1, EventCalendar.days_in_month(month) + 1):
		_button(str(day), DAY_BUTTON_SIZE, _save.bind("%02d-%02d" % [month, day]))
	_focus_first()


func _save(month_day: String) -> void:
	GameState.birthdays[account_id] = month_day
	SaveGame.save_game()
	if month_day.is_empty():
		_prompt.text = _lines.get("no_thanks", "No problem!")
	else:
		_prompt.text = String(_lines.get("thanks", "Got it: {date}.")).format({ "date": EventCalendar.describe(month_day) })
	_clear(1)
	_button("OK", BUTTON_SIZE, _close.bind(month_day))
	_focus_first()


func _close(month_day: String) -> void:
	get_tree().paused = _was_paused
	if not month_day.is_empty() and month_day == GameClock.calendar_date().substr(5):
		EventBanner.show_today(get_tree().current_scene)
	finished.emit()
	queue_free()


func _clear(columns: int) -> void:
	_grid.columns = columns
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()


func _button(text: String, size: Vector2, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = size
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(on_press)
	_grid.add_child(button)
	return button


func _focus_first() -> void:
	for child in _grid.get_children():
		if child is Button:
			(child as Button).grab_focus()
			return
