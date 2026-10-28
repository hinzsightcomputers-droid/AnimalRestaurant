class_name DialogueRunner
extends CanvasLayer
## Loads a dialogue JSON file, shows it in a cozy text box with a typewriter effect,
## fires each line's emotion on the speaking character, and applies the reactions
## attached to the choices you pick.
##
##     var runner := DialogueRunner.new()
##     add_child(runner)
##     runner.start()                      # starts at "start" in the JSON
##     runner.start("some_node_id")        # or jump to a specific node
##
## Keyboard: Enter / Space to advance. Mouse: click the box.

signal dialogue_started
signal dialogue_finished
signal line_shown(speaker_id: StringName, text: String, emotion: StringName)
signal choice_made(node_id: String, choice_index: int, choice_text: String)

@export_file("*.json") var dialogue_file: String = "res://dialogue/sample_dialogue.json"
@export var chars_per_second: float = 32.0
## How long the reaction plays before the conversation moves on after a choice.
@export var reaction_pause: float = 0.8
@export var autostart: bool = false

## Anything a choice sets with "set" ends up here, e.g. flags["accepted_pancakes"] == true.
var flags: Dictionary = {}

enum State { IDLE, TYPING, WAITING, CHOOSING, PAUSED }

var _data: Dictionary = {}
var _nodes: Dictionary = {}
var _characters: Dictionary = {}
var _state: State = State.IDLE
var _node_id: String = ""
var _node: Dictionary = {}
var _line_index: int = 0
var _type_accum: float = 0.0
var _plain_text: String = ""
var _total_chars: int = 0
var _current_speaker: DialogueCharacter
var _spoken: Array[DialogueCharacter] = []

var _panel: PanelContainer
var _name_label: Label
var _text_label: RichTextLabel
var _choices_box: VBoxContainer
var _hint: Label


func _ready() -> void:
	_build_ui()
	if autostart:
		start()


# ------------------------------------------------------------------ public API

func load_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_error("DialogueRunner: file not found: %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_error("DialogueRunner: %s is not valid JSON (top level must be an object)" % path)
		return false
	_data = parsed
	_nodes = _data.get("nodes", {})
	return true


func start(node_id: String = "") -> void:
	if _nodes.is_empty() and not load_file(dialogue_file):
		return
	_collect_characters()
	_panel.visible = true
	dialogue_started.emit()
	_goto(node_id if node_id != "" else str(_data.get("start", "")))


func is_running() -> bool:
	return _state != State.IDLE


# ------------------------------------------------------------------- UI setup

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.visible = false
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 36)
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.custom_minimum_size = Vector2(0, 170)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#fff4dc")
	sb.border_color = Color("#8a5a3c")
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(22)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 16
	sb.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.gui_input.connect(_on_panel_gui_input)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 28)
	_name_label.add_theme_color_override("font_color", Color("#8a5a3c"))
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_name_label)

	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = true
	_text_label.fit_content = true
	_text_label.scroll_active = false
	_text_label.custom_minimum_size = Vector2(0, 64)
	_text_label.add_theme_font_size_override("normal_font_size", 26)
	_text_label.add_theme_color_override("default_color", Color("#4a3426"))
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_text_label)

	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 6)
	_choices_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_choices_box)

	_hint = Label.new()
	_hint.text = "Enter / click"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color("#b89a82"))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.visible = false
	vbox.add_child(_hint)


func _collect_characters() -> void:
	_characters.clear()
	for n in get_tree().get_nodes_in_group("dialogue_characters"):
		var c := n as DialogueCharacter
		if c != null:
			_characters[c.character_id] = c


# ---------------------------------------------------------------- flow control

func _goto(node_id: String) -> void:
	if node_id == "" or not _nodes.has(node_id):
		_end()
		return
	_node_id = node_id
	_node = _nodes[node_id]
	_line_index = 0
	_clear_choices()
	_show_line()


func _show_line() -> void:
	var lines: Array = _node.get("lines", [])
	if _line_index >= lines.size():
		_after_lines()
		return

	var line: Dictionary = lines[_line_index]
	var speaker_id := StringName(str(line.get("speaker", _node.get("speaker", ""))))
	var emotion := StringName(str(line.get("emotion", "neutral")))

	_current_speaker = _characters.get(speaker_id)
	if _current_speaker != null:
		_name_label.text = _current_speaker.display_name
		_name_label.add_theme_color_override("font_color", _current_speaker.name_color)
		_name_label.visible = true
		_current_speaker.react(emotion, 0.0)
		if not _spoken.has(_current_speaker):
			_spoken.append(_current_speaker)
	else:
		_name_label.text = String(speaker_id).capitalize()
		_name_label.visible = speaker_id != &""

	_text_label.text = str(line.get("text", ""))
	_text_label.visible_characters = 0
	_plain_text = _text_label.get_parsed_text()
	_total_chars = _plain_text.length()
	_type_accum = 0.0
	_hint.visible = false
	_state = State.TYPING
	line_shown.emit(speaker_id, _plain_text, emotion)


func _process(delta: float) -> void:
	if _state != State.TYPING:
		return
	_type_accum += delta * chars_per_second
	while _type_accum >= 1.0 and _text_label.visible_characters < _total_chars:
		_type_accum -= 1.0
		var idx := _text_label.visible_characters
		_text_label.visible_characters = idx + 1
		if _current_speaker != null and idx < _plain_text.length():
			_current_speaker.speak_letter(_plain_text.substr(idx, 1))
	if _text_label.visible_characters >= _total_chars:
		_finish_typing()


func _finish_typing() -> void:
	_text_label.visible_characters = -1
	var lines: Array = _node.get("lines", [])
	var is_last := _line_index >= lines.size() - 1
	if is_last and not _node.get("choices", []).is_empty():
		_show_choices()
	else:
		_state = State.WAITING
		_hint.visible = true


func _advance() -> void:
	match _state:
		State.TYPING:
			_text_label.visible_characters = _total_chars
			_finish_typing()
		State.WAITING:
			_line_index += 1
			_show_line()


func _after_lines() -> void:
	if not _node.get("choices", []).is_empty():
		_show_choices()
	elif str(_node.get("next", "")) != "":
		_goto(str(_node["next"]))
	else:
		_end()


func _show_choices() -> void:
	_clear_choices()
	_hint.visible = false
	var choices: Array = _node.get("choices", [])
	for i in choices.size():
		var b := Button.new()
		b.text = str(choices[i].get("text", "..."))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(_on_choice_pressed.bind(i))
		_choices_box.add_child(b)
	_state = State.CHOOSING
	if _choices_box.get_child_count() > 0:
		(_choices_box.get_child(0) as Button).call_deferred("grab_focus")


func _clear_choices() -> void:
	for c in _choices_box.get_children():
		_choices_box.remove_child(c)
		c.queue_free()


func _on_choice_pressed(index: int) -> void:
	if _state != State.CHOOSING:
		return
	_state = State.PAUSED
	var choice: Dictionary = _node["choices"][index]
	_clear_choices()

	var to_set: Dictionary = choice.get("set", {})
	for key in to_set:
		flags[key] = to_set[key]

	# Reactions: { "character_id": "emotion" } - how each character feels about what you said.
	var reactions: Dictionary = choice.get("reactions", {})
	for cid in reactions:
		var ch: DialogueCharacter = _characters.get(StringName(str(cid)))
		if ch != null:
			ch.react(StringName(str(reactions[cid])), 0.0)

	choice_made.emit(_node_id, index, str(choice.get("text", "")))
	await get_tree().create_timer(reaction_pause).timeout
	_goto(str(choice.get("next", "")))


func _end() -> void:
	_state = State.IDLE
	_panel.visible = false
	_clear_choices()
	for ch in _spoken:
		ch.finish_talking()
	_spoken.clear()
	dialogue_finished.emit()


# ---------------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if (_state == State.TYPING or _state == State.WAITING) and event.is_action_pressed("ui_accept"):
		_advance()
		get_viewport().set_input_as_handled()


func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
