# PassCounter: a spot on the low kitchen wall where anyone can set down what
# they're carrying, and anyone on either side can pick it up. Lets one player
# cook while another serves. Holds one item at a time.
class_name PassCounter
extends Station

signal held_item_changed(item: RefCounted)

var held_item: RefCounted = null

# The second use spot, on the dining-room side ($Interactable is the kitchen side).
@onready var dining_side: Interactable = $InteractableDining


func _ready() -> void:
	super._ready()
	dining_side.interacted.connect(_on_interacted)
	interactable.prompt_for_player = _prompt_for
	dining_side.prompt_for_player = _prompt_for


# "Put down" if they're carrying something and it's empty, "Pick up" if their
# hands are free and something's here, otherwise nothing to do.
func _prompt_for(player_index: int) -> String:
	var player := Player.find(get_tree(), player_index)
	if player == null:
		return ""
	if held_item == null and player.held_item != null:
		return "Put down"
	if held_item != null and player.held_item == null:
		return "Pick up"
	return ""


func _on_interacted(player_index: int) -> void:
	var player := Player.find(get_tree(), player_index)
	if player == null:
		return
	if _prompt_for(player_index).is_empty():
		return

	# Swap: put down if the counter is empty, pick up if the player's hands are.
	var from_player := player.held_item
	player.set_held_item(held_item)
	held_item = from_player
	held_item_changed.emit(held_item)
	_play_bounce()
	used.emit(self, player_index)
