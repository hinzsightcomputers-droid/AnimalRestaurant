# InteractPrompt: floating text like "[E] Cook" above whatever the player can use.
# Display only: it listens to an Interactor and never changes game state.
extends Label3D

const STACK_GAP := 0.28  # Meters between stacked prompts (a line of text is about 0.24).

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
		global_position = _target.global_position + Vector3.UP * (_target.prompt_height + _stack_rank() * STACK_GAP)
		# Prompts can change ("Cook" -> "Stir!"), and so can the button if the player switches device.
		var prompt := _target.prompt_for(_player.player_index)
		text = "[%s] %s" % [InputSetup.interact_hint(_player.player_index), prompt]
		visible = not prompt.is_empty()  # Nothing to say (e.g. a close-up showing its own instructions).


# Players with a prompt over the same thing stack theirs, lowest-numbered
# player at the bottom, so two prompts never sit on top of each other.
func _stack_rank() -> int:
	var rank := 0
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		var other := node as Player
		if other.player_index < _player.player_index and other.interactor.focused == _target \
				and not _target.prompt_for(other.player_index).is_empty():
			rank += 1
	return rank


func _on_focus_changed(interactable: Interactable) -> void:
	_target = interactable
	visible = interactable != null
	_process(0.0)
