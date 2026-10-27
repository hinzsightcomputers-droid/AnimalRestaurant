# Freezer: hands the player the ingredients for the oldest waiting order, to
# carry over to the stove.
class_name Freezer
extends Station

@export var order_board: OrderBoard


func _ready() -> void:
	super._ready()
	interactable.prompt_for_player = _prompt_for


# Only for players with free hands.
func _prompt_for(player_index: int) -> String:
	var player := Player.find(get_tree(), player_index)
	return interactable.prompt if player != null and player.held_item == null else ""


func _on_interacted(player_index: int) -> void:
	var player := Player.find(get_tree(), player_index)
	if player == null:
		return
	if player.held_item != null:
		GameEvents.announce("Your hands are full.")
		return
	var order := order_board.next_to_gather()
	if order == null:
		GameEvents.announce("No orders need ingredients right now.")
		return

	order_board.set_state(order, Order.State.GATHERED)
	var ingredients := Ingredients.new(order)
	player.set_held_item(ingredients)
	var hint := " Chop them first!" if ingredients.needs_chopping() else ""
	GameEvents.announce("Got %s for %s.%s" % [ingredients.display_name(), order.dish.get("name", "Dish"), hint])
	_play_bounce()
	used.emit(self, player_index)
