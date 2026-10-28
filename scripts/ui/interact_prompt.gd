# InteractPrompt: floating text like "[E] Cook" above whatever the player can use.
# Display only: it listens to an Interactor and never changes game state.
extends Label3D

@export var interactor: Interactor

var _target: Interactable = null

@onready var _player: Player = get_parent()


func _ready() -> void:
	top_level = true  # Don't move or rotate with the player.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	visible = false
	interactor.focus_changed.connect(_on_focus_changed)


func _process(_delta: float) -> void:
	if _target != null:
		global_position = _target.global_position + Vector3.UP * _target.prompt_height
		# Prompts can change ("Cook" -> "Stir!"), and so can the button if the player switches device.
		var prompt := _target.prompt_for(_player.player_index)
		text = "[%s] %s" % [InputSetup.interact_hint(_player.player_index), prompt]
		visible = not prompt.is_empty()  # Nothing to say (e.g. a close-up showing its own instructions).


func _on_focus_changed(interactable: Interactable) -> void:
	_target = interactable
	visible = interactable != null
	_process(0.0)
