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
	_update_prompts()


func _on_interacted(player_index: int) -> void:
	var player := Player.find(get_tree(), player_index)
	if player == null:
		return
	if held_item == null and player.held_item == null:
		return
	if held_item != null and player.held_item != null:
		GameEvents.announce("The pass is full.")
		return

	# Swap: put down if the counter is empty, pick up if the player's hands are.
	var from_player := player.held_item
	player.set_held_item(held_item)
	held_item = from_player
	held_item_changed.emit(held_item)
	_update_prompts()
	_play_bounce()
	used.emit(self, player_index)


func _update_prompts() -> void:
	var prompt := "Put down" if held_item == null else "Pick up"
	interactable.prompt = prompt
	dining_side.prompt = prompt
