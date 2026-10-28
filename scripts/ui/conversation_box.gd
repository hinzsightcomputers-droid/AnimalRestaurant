# ConversationBox: the dialogue box for one player talking with a regular. Their
# line types out letter by letter (holding interact speeds it up), then either
# waits for interact to continue or shows the player's replies as a list they
# move through with their own up/down and pick with interact (so in co-op each
# player drives their own box). Sits along the bottom of that player's view.
#
# Voices: each letter that appears emits letter_typed, at the current typing
# speed, so a voice can stay in sync. If the speaker's character file has
# "voice": { "sound": "res://...", "pitch": 1.0, "every": 2 }, the box plays that
# sound itself every `every` letters, a little faster and higher when sped up.
#
# Display and input only: CustomerManager asks the questions and applies the answers.
class_name ConversationBox
extends Control

signal chosen(index: int)
signal continued
signal letter_typed(letter: String, speed_scale: float)  # For voices: one per letter shown.

const LETTERS_PER_SECOND := 32.0
const FAST_SCALE := 3.5          # How much faster text types while interact is held.
const PAUSES := { ".": 0.22, "!": 0.22, "?": 0.22, ",": 0.1, "—": 0.15 }  # Seconds after these letters.
const REPLY_SECONDS := 8.0       # A finished reply moves on by itself after this, if nobody presses.
const TEXT_COLOR := Color(0.25, 0.18, 0.12)
const DIM_COLOR := Color(0.25, 0.18, 0.12, 0.55)
const PICKED_COLOR := Color(0.75, 0.33, 0.12)

enum Mode { IDLE, TYPING, CHOOSING, WAITING }

var player_index := 0
var speaker_id := ""  # Regular id, for their voice.

var _speaker := Label.new()
var _line := Label.new()
var _options := VBoxContainer.new()
var _hint := Label.new()
var _labels: Array[Label] = []
var _option_texts: Array = []
var _selected := 0
var _mode := Mode.IDLE
var _then_choose := false  # After typing: show the options (ask) or wait to continue (tell).
var _typed := 0.0          # Letters shown so far (fractional while typing).
var _pause_left := 0.0
var _wait_left := 0.0
var _armed := false  # True once interact is let go, so a held press doesn't answer or skip by accident.
var _voice := AudioStreamPlayer.new()
var _voice_pitch := 1.0
var _voice_every := 2
var _letters_since_voice := 0


# A box for `for_player`, inside their view (`parent`), for regular `speaker` (for their voice).
static func open(parent: Control, for_player: int, speaker := "") -> ConversationBox:
	var box := ConversationBox.new()
	box.player_index = for_player
	box.speaker_id = speaker
	parent.add_child(box)
	return box


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel := PanelContainer.new()
	panel.anchor_left = 0.04
	panel.anchor_right = 0.96
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -64  # Above the announcement line at the bottom of the screen.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.97, 0.9, 0.96)
	style.border_color = Color(0.55, 0.4, 0.28)
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	_speaker.add_theme_font_size_override("font_size", 20)
	_speaker.add_theme_color_override("font_color", PICKED_COLOR)
	_line.add_theme_font_size_override("font_size", 22)
	_line.add_theme_color_override("font_color", TEXT_COLOR)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING  # Words don't jump lines as they type.
	_options.add_theme_constant_override("separation", 2)
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", DIM_COLOR)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for node in [_speaker, _line, _options, _hint]:
		column.add_child(node)
	add_child(_voice)
	_load_voice()


# Type out `speaker` saying `text`, then wait for the player to pick one of
# `options`. Returns the index picked.
func ask(speaker: String, text: String, options: Array) -> int:
	for label in _labels:
		label.queue_free()
	_labels.clear()
	_option_texts = options.duplicate()
	for option in options:
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 20)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_options.add_child(label)
		_labels.append(label)
	_selected = 0
	_refresh_options()
	_start_typing(speaker, text, true)
	return await chosen


# Type out `speaker` saying `text`, then wait for interact (or a while to pass).
func tell(speaker: String, text: String) -> void:
	_start_typing(speaker, text, false)
	await continued


func close() -> void:
	queue_free()


func is_typing() -> bool:
	return _mode == Mode.TYPING


func _process(delta: float) -> void:
	var interact := InputSetup.action_name(player_index, "interact")
	var holding := Input.is_action_pressed(interact)
	if not _armed and not holding:
		_armed = true
	var pressed := _armed and Input.is_action_just_pressed(interact)

	match _mode:
		Mode.TYPING:
			_type(delta, FAST_SCALE if holding else 1.0)
		Mode.CHOOSING:
			if Input.is_action_just_pressed(InputSetup.action_name(player_index, "move_up")):
				_selected = wrapi(_selected - 1, 0, _labels.size())
				_refresh_options()
			elif Input.is_action_just_pressed(InputSetup.action_name(player_index, "move_down")):
				_selected = wrapi(_selected + 1, 0, _labels.size())
				_refresh_options()
			elif pressed:
				_mode = Mode.IDLE
				_armed = false
				chosen.emit(_selected)
		Mode.WAITING:
			_wait_left -= delta
			if pressed or _wait_left <= 0.0:
				_mode = Mode.IDLE
				_armed = false
				continued.emit()


func _start_typing(speaker: String, text: String, then_choose: bool) -> void:
	_speaker.text = speaker
	_line.text = "\"%s\"" % text
	_line.visible_characters = 0
	_typed = 0.0
	_pause_left = 0.0
	_letters_since_voice = 0
	_then_choose = then_choose
	_options.visible = false
	_hint.text = "Hold %s to speed up" % _button()
	_mode = Mode.TYPING


# Reveal letters at `speed_scale` times the normal speed, pausing after punctuation.
func _type(delta: float, speed_scale: float) -> void:
	var total := _line.get_total_character_count()
	var time := delta
	while time > 0.0 and _line.visible_characters < total:
		if _pause_left > 0.0:
			var used := minf(_pause_left, time)
			_pause_left -= used
			time -= used
			continue
		_typed += time * LETTERS_PER_SECOND * speed_scale
		time = 0.0
		while _line.visible_characters < mini(int(_typed), total):
			var letter := _line.text[_line.visible_characters]
			_line.visible_characters += 1
			_on_letter(letter, speed_scale)
			if PAUSES.has(letter):
				_pause_left = PAUSES[letter] / speed_scale
				_typed = _line.visible_characters
				break
	if _line.visible_characters >= total and _pause_left <= 0.0:
		_finish_typing()


func _finish_typing() -> void:
	_line.visible_characters = -1
	_armed = false  # Let go of interact before it counts, so speeding up doesn't also skip.
	if _then_choose:
		_options.visible = true
		_hint.text = "%s  Pick    Up/Down  Choose" % _button()
		_mode = Mode.CHOOSING
	else:
		_hint.text = "%s  Continue" % _button()
		_wait_left = REPLY_SECONDS
		_mode = Mode.WAITING


func _on_letter(letter: String, speed_scale: float) -> void:
	letter_typed.emit(letter, speed_scale)
	if _voice.stream == null or letter.strip_edges().is_empty() or letter == "\"":
		return
	_letters_since_voice += 1
	if _letters_since_voice >= _voice_every:
		_letters_since_voice = 0
		_voice.pitch_scale = _voice_pitch * randf_range(0.92, 1.08) * (1.15 if speed_scale > 1.0 else 1.0)
		_voice.play()


# The speaker's "voice" from their character file, if they have one.
func _load_voice() -> void:
	var voice: Dictionary = GameData.characters.get(speaker_id, {}).get("voice", {})
	var path: String = voice.get("sound", "")
	if not path.is_empty() and ResourceLoader.exists(path):
		_voice.stream = load(path)
	_voice_pitch = voice.get("pitch", 1.0)
	_voice_every = maxi(1, int(voice.get("every", 2)))


func _refresh_options() -> void:
	for i in _labels.size():
		var picked := i == _selected
		_labels[i].text = ("> " if picked else "   ") + _option_texts[i]
		_labels[i].add_theme_color_override("font_color", PICKED_COLOR if picked else TEXT_COLOR)


func _button() -> String:
	return "[%s]" % InputSetup.interact_hint(player_index)
