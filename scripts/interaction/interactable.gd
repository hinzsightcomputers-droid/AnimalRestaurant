# Interactable: marks a spot players can interact with (place it where the player
# should stand). Emits `interacted` with the player_index of whoever used it.
# It does not know what the interaction means; the owning object decides that.
class_name Interactable
extends Node3D

const GROUP := "interactables"

signal interacted(player_index: int)

@export var prompt := "Use"          # Shown to the player, e.g. "Cook".
@export var radius := 1.2            # How close (in meters, ignoring height) a player must be.
@export var prompt_height := 1.6     # How high above this point the prompt appears.
@export var enabled := true
@export var priority := 0            # When several are in range, higher priority wins (e.g. a customer over their chair).

# Optional: (player_index) -> String, the prompt for that player, or "" if they
# can't use this right now (then it's skipped for them, and something else
# nearby can be picked). Unset = everyone sees `prompt`.
var prompt_for_player: Callable


func _ready() -> void:
	add_to_group(GROUP)


func prompt_for(player_index: int) -> String:
	if prompt_for_player.is_valid():
		return prompt_for_player.call(player_index)
	return prompt


func interact(player_index: int) -> void:
	if enabled:
		interacted.emit(player_index)
