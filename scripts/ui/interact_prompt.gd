# InteractPrompt: floating text like "[E] Cook" above whatever the player can use.
# Display only: it listens to an Interactor and never changes game state.
extends Label3D

const STACK_GAP := 0.28  # Meters between stacked prompts (a line of text is about 0.24).
const CLEAR_OF_LABEL := 0.32  # Over the player's own held-item label...
const NEAR := 1.2  # ...when the prompt's this close to them (meters across the floor).
const LIFT_SPEED := 3.0  # Meters a second, so it doesn't jump.

@export var interactor: Interactor

var _target: Interactable = null

@onready var _player: Player = get_parent()
@onready var _held_label: Label3D = get_node_or_null("../HeldItemDisplay/Label")

var _lift := 0.0


func _ready() -> void:
	top_level = true  # Don't move or rotate with the player.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	visible = false
	interactor.focus_changed.connect(_on_focus_changed)


func _process(delta: float) -> void:
	if _target != null:
		_lift = move_toward(_lift, _lift_needed(), LIFT_SPEED * delta)
		global_position = _target.global_position + Vector3.UP * (_target.prompt_height + _lift + _stack_rank() * STACK_GAP)
		# Prompts can change ("Cook" -> "Stir!"), and so can the button if the player switches device.
		var prompt := _target.prompt_for(_player.player_index)
		text = "[%s] %s" % [InputSetup.interact_hint(_player.player_index), prompt]
		visible = not prompt.is_empty()  # Nothing to say (e.g. a close-up showing its own instructions).


# How far to raise the prompt so it clears what the player's carrying, when they're right by it.
func _lift_needed() -> float:
	if _held_label == null or not _held_label.visible:
		return 0.0
	var across := _target.global_position - _player.global_position
	if Vector2(across.x, across.z).length() > NEAR:
		return 0.0
	return maxf(_held_label.global_position.y + CLEAR_OF_LABEL - _target.global_position.y - _target.prompt_height, 0.0)


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
