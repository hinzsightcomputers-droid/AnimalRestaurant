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
# Names stand out in color: the chef's own name (and Cheddar's nickname for
# them) in PLAYER_NAME_COLOR, each regular's name in their "name_color" from
# their character file (also used for the speaker's name), and the restaurant's
# name in the color picked for it.
#
# Display and input only: CustomerManager asks the questions and applies the answers.
class_name ConversationBox
extends Control

signal chosen(index: int)
signal continued
signal letter_typed(letter: String, speed_scale: float)  # For voices: one per letter shown.

const GROUP := "conversation_boxes"  # Every open box (the phone waits while anyone is talking).
const LETTERS_PER_SECOND := 32.0
const FAST_SCALE := 3.5          # How much faster text types while interact is held.
const PAUSES := { ".": 0.22, "!": 0.22, "?": 0.22, ",": 0.1, "—": 0.15 }  # Seconds after these letters.
const REPLY_SECONDS := 8.0       # A finished reply moves on by itself after this, if nobody presses.
const TEXT_COLOR := Color(0.25, 0.18, 0.12)
const DIM_COLOR := Color(0.25, 0.18, 0.12, 0.55)
const PICKED_COLOR := Color(0.75, 0.33, 0.12)
const PLAYER_NAME_COLOR := Color("#2f7fd8")

enum Mode { IDLE, TYPING, CHOOSING, WAITING }

var player_index := 0
var speaker_id := ""  # Regular id, for their voice.

var _speaker := Label.new()
var _line := RichTextLabel.new()
var _options := VBoxContainer.new()
var _hint := Label.new()
var _labels: Array[RichTextLabel] = []
var _highlights := {}  # Name -> color, longest names first (see _find_highlights).
var _plain := ""       # The current line as shown, without BBCode tags.
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
	add_to_group(GROUP)
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
	_set_up_rich_text(_line, 22)
	_line.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING  # Words don't jump lines as they type.
	_options.add_theme_constant_override("separation", 2)
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", DIM_COLOR)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for node in [_speaker, _line, _options, _hint]:
		column.add_child(node)
	add_child(_voice)
	_load_voice()
	_find_highlights()


func _set_up_rich_text(label: RichTextLabel, font_size: int) -> void:
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_font_size_override("bold_font_size", font_size)
	label.add_theme_color_override("default_color", TEXT_COLOR)


# Which names to color: this chef's name (and nickname, if the speaker gave them
# one) and every regular's name.
func _find_highlights() -> void:
	var colors := {}
	for id in GameData.characters:
		var character: Dictionary = GameData.characters[id]
		colors[character["name"]] = Color(character.get("name_color", "#555555"))
	for caller in GameData.callers:  # Townsfolk on the phone.
		colors[caller["name"]] = Color(caller.get("name_color", "#555555"))
	if not GameState.restaurant_name.is_empty():
		colors[GameState.restaurant_name] = Color(GameState.restaurant_color)
	var chef_id := Accounts.id_of(player_index)
	var chef_name := Accounts.name_of(player_index)
	if not chef_name.is_empty():
		colors[chef_name] = PLAYER_NAME_COLOR
	var nickname: String = GameState.regulars.get(speaker_id, {}).get("nicknames", {}).get(chef_id, "")
	if not nickname.is_empty():
		colors[nickname] = PLAYER_NAME_COLOR
	# Longest first, so "The Stove Whisperer" is matched before any shorter name inside it.
	var names := colors.keys()
	names.sort_custom(func(a, b): return a.length() > b.length())
	_highlights.clear()
	for name in names:
		_highlights[name] = colors[name]


# `text` as BBCode with every highlighted name in its color (and bold).
func _highlighted(text: String) -> String:
	var result := text.replace("[", "[lb]")  # Show any brackets as typed.
	var taken: Array = []  # [start, end] spans already highlighted.
	var spans: Array = []  # [start, end, color]
	for name in _highlights:
		var regex := RegEx.create_from_string("\\b%s\\b" % _escape_regex(name))
		for found in regex.search_all(result):
			var overlaps := taken.any(func(s): return found.get_start() < s[1] and found.get_end() > s[0])
			if not overlaps:
				taken.append([found.get_start(), found.get_end()])
				spans.append([found.get_start(), found.get_end(), _highlights[name]])
	spans.sort_custom(func(a, b): return a[0] > b[0])  # Back to front, so earlier positions stay valid.
	for span in spans:
		var color: Color = span[2]
		var word := result.substr(span[0], span[1] - span[0])
		result = result.substr(0, span[0]) + "[color=#%s][b]%s[/b][/color]" % [color.to_html(false), word] + result.substr(span[1])
	return result


static func _escape_regex(text: String) -> String:
	var escaped := ""
	for c in text:
		escaped += "\\" + c if c in "\\^$.|?*+()[]{}" else c
	return escaped


# Type out `speaker` saying `text`, then wait for the player to pick one of
# `options`. Returns the index picked.
func ask(speaker: String, text: String, options: Array) -> int:
	_find_highlights()  # A nickname may have been picked since the last line.
	for label in _labels:
		label.queue_free()
	_labels.clear()
	_option_texts = options.duplicate()
	for option in options:
		var label := RichTextLabel.new()
		_set_up_rich_text(label, 20)
		_options.add_child(label)
		_labels.append(label)
	_selected = 0
	_refresh_options()
	_start_typing(speaker, text, true)
	return await chosen


# Type out `speaker` saying `text`, then wait for interact (or a while to pass).
func tell(speaker: String, text: String) -> void:
	_find_highlights()
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
	# In their name color ("Pip (voicemail)" is colored as Pip).
	_speaker.add_theme_color_override("font_color", _highlights.get(speaker.get_slice(" (", 0), PICKED_COLOR))
	_line.text = _highlighted("\"%s\"" % text)
	_plain = _line.get_parsed_text()  # What's shown, without the color tags, for the letter-by-letter typing.
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
	var total := _plain.length()
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
			var letter := _plain[_line.visible_characters]
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
		_labels[i].text = ("> " if picked else "   ") + _highlighted(_option_texts[i])
		_labels[i].add_theme_color_override("default_color", PICKED_COLOR if picked else TEXT_COLOR)


func _button() -> String:
	return "[%s]" % InputSetup.interact_hint(player_index)
