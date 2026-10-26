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


func _ready() -> void:
	add_to_group(GROUP)


func interact(player_index: int) -> void:
	if enabled:
		interacted.emit(player_index)
