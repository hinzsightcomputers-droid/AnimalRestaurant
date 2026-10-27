# Freezer: hands the player the ingredients for the oldest waiting order, to
# carry over to the stove.
class_name Freezer
extends Station

@export var order_board: OrderBoard


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
	GameEvents.announce("Got %s for %s." % [ingredients.display_name(), order.dish.get("name", "Dish")])
	_play_bounce()
	used.emit(self, player_index)
