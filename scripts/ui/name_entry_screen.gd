# NameEntryScreen: on a brand-new game, asks for the name regulars will call
# you before the first day starts. The game stays paused until a name is chosen.
# Hidden for saved games that already have a name.
extends CanvasLayer

const DEFAULT_NAME := "Chef"

@onready var name_edit: LineEdit = $Panel/Content/NameEdit
@onready var open_button: Button = $Panel/Content/OpenButton


func _ready() -> void:
	if GameState.has_chosen_name:
		queue_free()
		return
	get_tree().paused = true
	name_edit.text_submitted.connect(func(_text): _confirm())
	open_button.pressed.connect(_confirm)
	name_edit.grab_focus()


func _confirm() -> void:
	var chosen := name_edit.text.strip_edges()
	GameState.set_player_name(chosen if not chosen.is_empty() else DEFAULT_NAME)
	get_tree().paused = false
	queue_free()
