# AccountPicker: asks each player who they are. Player 1 sees it before the
# first day, and anyone who joins later sees it as soon as they join. Pick one
# of the saved chefs (with their playtime) or type a new name. The game stays
# paused while it's up; several players waiting are asked one after another.
# Players keep their account across days, so it only shows once per session.
extends CanvasLayer

const DEFAULT_NAME := "Chef"
const ROW_HEIGHT := 52
const MAX_LIST_HEIGHT := 240

@export var player_manager: PlayerManager

@onready var title_label: Label = $Panel/Content/Title
@onready var prompt_label: Label = $Panel/Content/Prompt
@onready var account_scroll: ScrollContainer = $Panel/Content/AccountScroll
@onready var account_list: VBoxContainer = $Panel/Content/AccountScroll/AccountList
@onready var new_label: Label = $Panel/Content/NewLabel
@onready var name_edit: LineEdit = $Panel/Content/NameEdit
@onready var new_button: Button = $Panel/Content/NewButton
@onready var error_label: Label = $Panel/Content/Error

var _waiting: Array[int] = []  # Players who still need an account; the first is being asked.


func _ready() -> void:
	visible = false
	name_edit.text_submitted.connect(func(_text): _create_new())
	new_button.pressed.connect(_create_new)
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
		name_edit.grab_focus()
	else:
		(account_list.get_child(account_list.get_child_count() - choices.size()) as Button).grab_focus()


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
	var player_index: int = _waiting.pop_front()
	Accounts.assign(player_index, account_id)
	GameEvents.announce("Welcome, %s!" % Accounts.name_of(player_index))
	_show_next()
