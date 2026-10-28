# PlayerInput: reads input for one player and turns it into simple values
# (a move vector, an "interact pressed" flag). Gameplay scripts only talk to
# this node, so later we can swap in network or AI input without touching gameplay.
class_name PlayerInput
extends Node

@export var player_index := 0


# Returns the stick / WASD direction. x = left/right, y = up/down (up is negative).
func get_move_vector() -> Vector2:
	return Input.get_vector(_action("move_left"), _action("move_right"), _action("move_up"), _action("move_down"))


func is_interact_just_pressed() -> bool:
	return Input.is_action_just_pressed(_action("interact"))


func is_interact_pressed() -> bool:
	return Input.is_action_pressed(_action("interact"))


func _action(action: String) -> String:
	return InputSetup.action_name(player_index, action)
