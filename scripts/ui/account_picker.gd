# AccountPicker: asks each player who they are. Player 1 sees it before the
# first day, and anyone who joins later sees it as soon as they join. Pick one
# of the saved chefs (with their playtime) or type a new name, with the keyboard
# or the on-screen letters (for gamepads). The game stays paused while it's up;
# several players waiting are asked one after another. Players keep their
# account across days, so it only shows once per session.
# A chef without a look yet (new, or from before looks) goes on to the
# ChefCustomizer to make one, and one who hasn't said their birthday is asked
# it (BirthdayPicker), so it never interrupts the day.
extends CanvasLayer

const DEFAULT_NAME := "Chef"
const ROW_HEIGHT := 52
const MAX_LIST_HEIGHT := 240
const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const SPACE_KEY := "Space"
const DELETE_KEY := "Del"

@export var player_manager: PlayerManager

@onready var title_label: Label = $Panel/Content/Title
@onready var prompt_label: Label = $Panel/Content/Prompt
@onready var account_scroll: ScrollContainer = $Panel/Content/AccountScroll
@onready var account_list: VBoxContainer = $Panel/Content/AccountScroll/AccountList
@onready var new_label: Label = $Panel/Content/NewLabel
@onready var name_edit: LineEdit = $Panel/Content/NameEdit
@onready var letters: GridContainer = $Panel/Content/Letters
@onready var new_button: Button = $Panel/Content/NewButton
@onready var error_label: Label = $Panel/Content/Error

var _waiting: Array[int] = []  # Players who still need an account; the first is being asked.
var _typed_on_keyboard := false  # True once this player typed on a real keyboard (then Enter submits).


func _ready() -> void:
	visible = false
	name_edit.text_submitted.connect(func(_text): _create_new())
	new_button.pressed.connect(_create_new)
	_build_letters()
	player_manager.player_joined.connect(_on_player_joined)
	# Players spawned before we were ready (e.g. Player 1 on startup).
	for player_index in InputSetup.active_players():
		_add_waiting(player_index)
	_show_next()


func _on_player_joined(player: Player) -> void:
	_add_waiting(player.player_index)
	if _waiting.size() == 1:
		_show_next()


func _add_waiting(player_index: int) -> void:
	if not Accounts.has_account(player_index) and not player_index in _waiting:
		_waiting.append(player_index)


func _show_next() -> void:
	if _waiting.is_empty():
		visible = false
		get_tree().paused = false
		return
	visible = true
	get_tree().paused = true

	var player_index := _waiting[0]
	var choices := Accounts.available()
	var first_ever := Accounts.accounts.is_empty()
	title_label.text = "Welcome, new chef!" if first_ever else "Player %d, who's cooking?" % (player_index + 1)
	title_label.add_theme_color_override("font_color", PlayerVisual.color_for(player_index).darkened(0.35))
	prompt_label.text = "What should your customers call you?" if choices.is_empty() else "Pick your chef, or start a new one."
	new_label.visible = not choices.is_empty()
	new_button.text = "Open the restaurant" if first_ever else "Start as a new chef"
	error_label.visible = false
	name_edit.clear()
	_typed_on_keyboard = false

	for child in account_list.get_children():
		child.queue_free()
	for account in choices:
		var button := Button.new()
		button.text = "%s    (%s played)" % [account["name"], Accounts.format_playtime(account["playtime_seconds"])]
		button.custom_minimum_size = Vector2(0, ROW_HEIGHT - 6)
		button.add_theme_font_size_override("font_size", 22)
		button.pressed.connect(_choose.bind(account["id"]))
		account_list.add_child(button)
	account_scroll.visible = not choices.is_empty()
	account_scroll.custom_minimum_size.y = mini(choices.size() * ROW_HEIGHT, MAX_LIST_HEIGHT)

	if choices.is_empty():
		# Start on the letters, so a gamepad can type right away (see _input for keyboards).
		(letters.get_child(0) as Button).grab_focus()
	else:
		(account_list.get_child(account_list.get_child_count() - choices.size()) as Button).grab_focus()


# Typing on a keyboard always goes into the name box, whatever has focus (so
# Space types a space instead of pressing the focused letter button).
func _input(event: InputEvent) -> void:
	if not visible or name_edit.has_focus():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	if key.keycode == KEY_BACKSPACE:
		_delete_letter()
	elif key.unicode >= 32:
		_type(char(key.unicode))
		_typed_on_keyboard = true
	elif key.keycode in [KEY_ENTER, KEY_KP_ENTER] and _typed_on_keyboard:
		_create_new()  # Someone typing wants Enter to finish, not press the focused letter.
	else:
		return
	get_viewport().set_input_as_handled()


# On-screen keyboard: A-Z, space and delete, as focusable buttons.
func _build_letters() -> void:
	var keys: Array[String] = []
	for letter in LETTERS:
		keys.append(letter)
	keys.append_array([SPACE_KEY, DELETE_KEY])
	for key in keys:
		var button := Button.new()
		button.text = key
		button.custom_minimum_size = Vector2(56, 40)
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(_on_letter_pressed.bind(key))
		letters.add_child(button)


func _on_letter_pressed(key: String) -> void:
	match key:
		SPACE_KEY:
			_type(" ")
		DELETE_KEY:
			_delete_letter()
		_:
			# Capital first letter, lowercase after.
			_type(key if name_edit.text.is_empty() else key.to_lower())


func _type(text: String) -> void:
	if name_edit.text.length() + text.length() > name_edit.max_length:
		return
	name_edit.text += text
	name_edit.caret_column = name_edit.text.length()
	error_label.visible = false


func _delete_letter() -> void:
	name_edit.text = name_edit.text.left(-1)
	name_edit.caret_column = name_edit.text.length()


func _create_new() -> void:
	var chosen := name_edit.text.strip_edges()
	if chosen.is_empty():
		chosen = DEFAULT_NAME
	# Typing a saved chef's name just picks that chef.
	var existing := Accounts.find_by_name(chosen)
	if not existing.is_empty():
		if Accounts.is_in_use(existing["id"]):
			error_label.text = "%s is already cooking! Try another name." % existing["name"]
			error_label.visible = true
			return
		_choose(existing["id"])
		return
	_choose(Accounts.create(chosen)["id"])


func _choose(account_id: String) -> void:
	if not Accounts.has_appearance(account_id):
		# A chef who hasn't made how they look yet (a new one, or from before
		# looks): that first.
		visible = false
		ChefCustomizer.open(get_parent(), account_id, false).finished.connect(func(_saved: bool):
			visible = true
			_choose(account_id))
		return
	if not GameState.birthdays.has(account_id) and not ReelSandbox.active():
		# Their birthday next, before the day starts (not in the middle of it).
		visible = false
		BirthdayPicker.open(get_parent(), account_id, Accounts.get_account(account_id).get("name", DEFAULT_NAME)).finished.connect(func():
			visible = true
			_choose(account_id))
		return
	var player_index: int = _waiting.pop_front()
	Accounts.assign(player_index, account_id)
	GameEvents.announce("Welcome, %s!" % Accounts.name_of(player_index))
	_show_next()
