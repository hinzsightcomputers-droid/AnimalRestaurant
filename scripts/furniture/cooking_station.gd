# CookingStation: the stove. Using it while carrying Ingredients starts the
# timing minigame for that order; pressing interact again while cooking "stirs".
# When the minigame ends, the cook is handed the finished dish.
class_name CookingStation
extends Station

const RESULT_SHOW_TIME := 1.2  # Seconds the result stays up before the player can move.

@export var order_board: OrderBoard
@export_group("Camera zoom while cooking")
@export var zoom_look_offset := Vector3(0.0, 1.6, 0.3)  # Point the camera looks at, relative to the stove.
@export var camera_zoom: CameraZoomSettings              # Distance, angle and tween time of the zoom-in.

var minigame: CookingMinigame = null  # Not null while someone is cooking.
var _cook: Player = null
var _order: Order = null


func _ready() -> void:
	super._ready()
	interactable.prompt_for_player = _prompt_for


# While cooking, only the cook sees "Stir!". Otherwise "Cook Fish Stew" for
# someone carrying ingredients, and plain "Cook" for free hands (pressing then
# explains you need ingredients). Nothing for anyone carrying a plate.
func _prompt_for(player_index: int) -> String:
	if minigame != null:
		return "Stir!" if _cook != null and player_index == _cook.player_index else ""
	var player := Player.find(get_tree(), player_index)
	if player == null:
		return ""
	var ingredients := player.held_item as Ingredients
	if ingredients != null:
		return "Chop first!" if ingredients.needs_chopping() else "Cook %s" % ingredients.order.dish.get("name", "")
	return interactable.prompt if player.held_item == null else ""


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
	var ingredients := player.held_item as Ingredients
	if ingredients == null:
		if player.held_item != null:
			GameEvents.announce("Your hands are full.")
		else:
			GameEvents.announce("Grab ingredients from the freezer first.")
		return
	if ingredients.needs_chopping():
		GameEvents.announce("The %s need chopping first. Use the chopping board!" % ingredients.display_name().to_lower())
		return
	var order := ingredients.order

	player.set_held_item(null)
	_cook = player
	_order = order
	order_board.set_state(order, Order.State.COOKING)
	minigame = CookingMinigame.new(order.dish)
	minigame.finished.connect(_on_minigame_finished)

	player.movement_locked = true
	player.interactor.lock_to(interactable)
	player.request_camera_focus(global_position + zoom_look_offset, camera_zoom)  # Only this player's camera.
	_play_bounce()
	used.emit(self, player_index)


func _on_minigame_finished(quality: float) -> void:
	_play_bounce()
	GameEvents.announce("%s came out %s (%d%%)" % [
		_order.dish.get("name", "Dish"), CookingMinigame.quality_label(quality).to_lower(), roundi(quality * 100)])

	await get_tree().create_timer(RESULT_SHOW_TIME).timeout

	order_board.set_state(_order, Order.State.READY)
	_cook.set_held_item(CookedDish.new(_order, quality))
	GameState.record_chef_action(_cook.player_index, "cooked")
	_cook.movement_locked = false
	_cook.interactor.unlock()
	_cook.release_camera_focus()
	_cook = null
	_order = null
	minigame = null
