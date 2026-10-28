# RestaurantSetup: naming the restaurant and picking the color its name is
# written in. Shown on the start screen the first time (and after the debug
# panel's "Rename restaurant"). Type on a keyboard or use the on-screen letters
# (for gamepads), pick a color swatch, then open. Emits `changed` as the players
# type and pick, so the sign on the building can update live, and `done` when
# they're finished (GameState already holds the name and color then).
class_name RestaurantSetup
extends CanvasLayer

signal changed(restaurant_name: String, color: Color)
signal done

const DEFAULT_NAME := "Animal Restaurant"
const MAX_LENGTH := 22
const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const SPACE_KEY := "Space"
const DELETE_KEY := "Del"
# Mid-tone colors that read both on the sign and in the cream dialogue box.
# (No sky blue: that's the chef's own name in the dialogue box.)
const COLORS := ["#d1453b", "#e0780f", "#c99a06", "#3f8a3a", "#1f8f8a", "#3a5bc7", "#8a4fc4", "#d14f8f"]
const TEXT_COLOR := Color(0.25, 0.18, 0.12)

var _name_edit := LineEdit.new()
var _letters := GridContainer.new()
var _swatches := HBoxContainer.new()
var _open_button := Button.new()
var _color := Color(COLORS[0])


func _ready() -> void:
	layer = 20
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -16
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.97, 0.9, 0.96)
	style.border_color = Color(0.55, 0.4, 0.28)
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(_label("Name your restaurant", 24))

	_name_edit.max_length = MAX_LENGTH
	_name_edit.placeholder_text = DEFAULT_NAME
	_name_edit.custom_minimum_size = Vector2(520, 0)
	_name_edit.add_theme_font_size_override("font_size", 24)
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.text = GameState.restaurant_name
	_name_edit.text_changed.connect(func(_text): _emit_changed())
	_name_edit.text_submitted.connect(func(_text): _finish())
	column.add_child(_name_edit)

	_letters.columns = 14  # Two rows, so the sign above stays in view.
	_letters.add_theme_constant_override("h_separation", 4)
	_letters.add_theme_constant_override("v_separation", 4)
	var keys: Array[String] = []
	for letter in LETTERS:
		keys.append(letter)
	keys.append_array([SPACE_KEY, DELETE_KEY])
	for key in keys:
		var button := Button.new()
		button.text = key
		button.custom_minimum_size = Vector2(40, 34)
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_on_letter_pressed.bind(key))
		_letters.add_child(button)
	column.add_child(_letters)

	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 14)
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(bottom_row)
	bottom_row.add_child(_label("Color", 18))
	_swatches.add_theme_constant_override("separation", 6)
	for html in COLORS:
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(36, 34)
		swatch.add_theme_stylebox_override("normal", _swatch_style(Color(html), false))
		swatch.add_theme_stylebox_override("hover", _swatch_style(Color(html), true))
		swatch.add_theme_stylebox_override("focus", _swatch_style(Color(html), true))
		swatch.add_theme_stylebox_override("pressed", _swatch_style(Color(html), true))
		swatch.pressed.connect(_pick_color.bind(Color(html)))
		swatch.focus_entered.connect(_pick_color.bind(Color(html)))  # Moving onto a color previews it.
		_swatches.add_child(swatch)
	bottom_row.add_child(_swatches)

	_open_button.text = "Paint the sign"
	_open_button.add_theme_font_size_override("font_size", 20)
	_open_button.pressed.connect(_finish)
	bottom_row.add_child(_open_button)

	if GameState.restaurant_color in COLORS:
		_color = Color(GameState.restaurant_color)
	(_letters.get_child(0) as Button).grab_focus()
	_pick_color.call_deferred(_color)  # Marks the swatch and shows the sign as it starts.


# Typing on a keyboard always goes into the name, whatever has focus (so the
# letter keys type instead of pressing buttons).
func _input(event: InputEvent) -> void:
	if _name_edit.has_focus():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	if key.keycode == KEY_BACKSPACE:
		_delete_letter()
	elif key.unicode >= 32:
		_type(char(key.unicode))
	elif key.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		_finish()
	else:
		return
	get_viewport().set_input_as_handled()


func _on_letter_pressed(key: String) -> void:
	match key:
		SPACE_KEY:
			_type(" ")
		DELETE_KEY:
			_delete_letter()
		_:
			# Capital at the start of each word, lowercase after.
			var new_word := _name_edit.text.is_empty() or _name_edit.text.ends_with(" ")
			_type(key if new_word else key.to_lower())


func _type(text: String) -> void:
	if _name_edit.text.length() + text.length() > MAX_LENGTH:
		return
	_name_edit.text += text
	_name_edit.caret_column = _name_edit.text.length()
	_emit_changed()


func _delete_letter() -> void:
	_name_edit.text = _name_edit.text.left(-1)
	_name_edit.caret_column = _name_edit.text.length()
	_emit_changed()


func _pick_color(color: Color) -> void:
	_color = color
	for i in COLORS.size():  # The chosen one keeps its dark border.
		var swatch_color := Color(COLORS[i])
		_swatches.get_child(i).add_theme_stylebox_override("normal", _swatch_style(swatch_color, swatch_color == color))
	_emit_changed()


func _chosen_name() -> String:
	var typed := _name_edit.text.strip_edges()
	return typed if not typed.is_empty() else DEFAULT_NAME


func _emit_changed() -> void:
	changed.emit(_chosen_name(), _color)


func _finish() -> void:
	GameState.restaurant_name = _chosen_name()
	GameState.restaurant_color = "#" + _color.to_html(false)
	SaveGame.save_game()
	done.emit()
	queue_free()


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	return label


func _swatch_style(color: Color, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	style.border_color = Color(0.25, 0.18, 0.12) if selected else Color(1, 1, 1, 0.6)
	style.set_border_width_all(4 if selected else 2)
	return style
