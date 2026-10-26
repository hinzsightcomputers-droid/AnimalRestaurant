# CookingStation: the stove. Using it starts the timing minigame for the next
# order on the OrderBoard; pressing interact again while cooking "stirs".
# When the minigame ends, the cook is handed the finished dish.
class_name CookingStation
extends Station

const RESULT_SHOW_TIME := 1.2  # Seconds the result stays up before the player can move.

@export var order_board: OrderBoard

var minigame: CookingMinigame = null  # Not null while someone is cooking.
var _cook: Player = null
var _order: Order = null


func _on_interacted(player_index: int) -> void:
	if minigame != null:
		# Only the player who is cooking can stir.
		if _cook != null and player_index == _cook.player_index:
			minigame.press()
		return
	_try_start_cooking(player_index)


func _physics_process(delta: float) -> void:
	if minigame != null:
		minigame.update(delta)


func _try_start_cooking(player_index: int) -> void:
	var player := Player.find(get_tree(), player_index)
	if player == null:
		return
	if player.held_item != null:
		GameEvents.announce("Your hands are full.")
		return
	var order := order_board.next_to_cook()
	if order == null:
		GameEvents.announce("No orders to cook right now.")
		return

	_cook = player
	_order = order
	order_board.set_state(order, Order.State.COOKING)
	minigame = CookingMinigame.new(order.dish)
	minigame.finished.connect(_on_minigame_finished)

	player.movement_locked = true
	interactable.prompt = "Stir!"
	_play_bounce()
	used.emit(self, player_index)


func _on_minigame_finished(quality: float) -> void:
	_play_bounce()
	GameEvents.announce("%s came out %s (%d%%)" % [
		_order.dish.get("name", "Dish"), CookingMinigame.quality_label(quality).to_lower(), roundi(quality * 100)])

	await get_tree().create_timer(RESULT_SHOW_TIME).timeout

	order_board.set_state(_order, Order.State.READY)
	_cook.set_held_item(CookedDish.new(_order, quality))
	_cook.movement_locked = false
	_cook = null
	_order = null
	minigame = null
	interactable.prompt = "Cook"
