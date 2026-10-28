# CookingStation: the stove. Using it while carrying Ingredients cooks that
# order. A dish with a close-up recipe ("recipe" in data/dishes.json, see
# CookRecipe) opens the close-up scene on the stovetop for that player, who
# cooks it step by step (CookSession reads their controls). Other dishes use the
# timing minigame, where pressing interact again "stirs". Either way the cook is
# handed the finished dish when it's done.
# A big moment scene can also cook together here (cook_together): a regular
# stands beside the chef and coaches each stir, and it can't fail.
class_name CookingStation
extends Station

const RESULT_SHOW_TIME := 1.2  # Seconds the result stays up before the player can move.

@export var order_board: OrderBoard
@export var view_manager: ViewManager  # For the close-up's mouse aiming.
@export_group("Camera zoom while cooking")
@export var zoom_look_offset := Vector3(0.0, 1.6, 0.3)  # Point the camera looks at, relative to the stove.
@export var camera_zoom: CameraZoomSettings              # Distance, angle and tween time of the zoom-in.
@export_group("Close-up recipes")
@export var closeup_scene: PackedScene                   # Put on the stovetop for a recipe (a CookSession).
@export var closeup_offset := Vector3(0.0, 0.9, 0.0)     # Where it goes: the top of the stove.
@export var closeup_look_offset := Vector3(0.0, 0.95, 0.05)
@export var closeup_zoom: CameraZoomSettings
@export_group("")
@export_range(0.0, 1.0) var chop_share := 0.25          # How much the chopping counts toward a chopped dish.

var minigame: CookingMinigame = null  # Not null while someone is cooking with the timing minigame.
var session: CookSession = null       # Not null while someone is cooking a close-up recipe.
var _cook: Player = null
var _order: Order = null
var _chop_quality := -1.0  # How well the ingredients being cooked were chopped (-1: not chopped).
var _together := {}  # During cook_together: the scene's cook step, plus "helper" (the regular).

signal cooked_together(quality: float)


func _ready() -> void:
	super._ready()
	interactable.prompt_for_player = _prompt_for


# While cooking, only the cook sees "Stir!". Otherwise "Cook Fish Stew" for
# someone carrying ingredients, and plain "Cook" for free hands (pressing then
# explains you need ingredients). Nothing for anyone carrying a plate.
func _prompt_for(player_index: int) -> String:
	if session != null:
		return ""  # The close-up shows its own instructions.
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
	if session != null:
		return  # The session reads the cook's button itself.
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
	_chop_quality = ingredients.chop_quality
	order_board.set_state(order, Order.State.COOKING)
	var recipe := CookRecipe.for_dish(order.dish)
	if recipe != null:
		_open_closeup(player, recipe)
		used.emit(self, player_index)
		return
	minigame = CookingMinigame.new(order.dish)
	minigame.finished.connect(_on_minigame_finished)

	player.movement_locked = true
	player.interactor.lock_to(interactable)
	player.request_camera_focus(global_position + zoom_look_offset, camera_zoom)  # Only this player's camera.
	_play_bounce()
	used.emit(self, player_index)


# Practice a recipe with no order (debug panel): nothing to hand over at the end.
func practice(player: Player, recipe: CookRecipe) -> void:
	if session != null or minigame != null or player == null:
		return
	_cook = player
	_order = null
	_open_closeup(player, recipe)


# Put the close-up on the stovetop and zoom this player in on it.
func _open_closeup(player: Player, recipe: CookRecipe) -> void:
	session = closeup_scene.instantiate()
	session.position = closeup_offset
	add_child(session)
	_show_stove_props(false)
	player.movement_locked = true
	player.interactor.lock_to(interactable)
	player.request_camera_focus(global_position + closeup_look_offset, closeup_zoom)
	session.finished.connect(_on_minigame_finished)
	session.start(recipe, player, view_manager if view_manager != null else get_tree().root.find_children("*", "ViewManager", true, false).front())
	_play_bounce()


# The pot makes way for the close-up's griddle and plate.
func _show_stove_props(shown: bool) -> void:
	visual.get_node("Pot").visible = shown


# Cook `dish` ({ name, cook_speed }) with `helper` beside the chef: they say
# one of step.coach per stir, and if it would come out below step.min_quality
# they quietly fix it (step.rescue). Returns the quality.
func cook_together(player: Player, dish: Dictionary, step: Dictionary, helper: Customer) -> float:
	_cook = player
	_order = null
	_together = step.duplicate()
	_together["helper"] = helper
	_together["dish"] = dish
	minigame = CookingMinigame.new(dish)
	minigame.hit_registered.connect(_on_together_stir)
	minigame.finished.connect(_on_minigame_finished)
	player.movement_locked = true
	player.interactor.lock_to(interactable)
	player.request_camera_focus(global_position + zoom_look_offset, camera_zoom)
	_play_bounce()
	return await cooked_together


func _on_together_stir(_score: float) -> void:
	var lines: Array = _together.get("coach", [])
	var index := minigame.scores.size() - 1
	if index < lines.size():
		_together["helper"].say(lines[index])


func _on_minigame_finished(quality: float) -> void:
	if not _together.is_empty():
		_finish_together(quality)
		return
	_play_bounce()
	if _chop_quality >= 0.0:
		quality = lerpf(quality, _chop_quality, chop_share)
	_chop_quality = -1.0
	var dish_name: String = _order.dish.get("name", "Dish") if _order != null else session.recipe.display_name
	GameEvents.announce("%s came out %s (%d%%)" % [
		dish_name, CookingMinigame.quality_label(quality).to_lower(), roundi(quality * 100)])

	await get_tree().create_timer(RESULT_SHOW_TIME * (2.0 if session != null else 1.0)).timeout  # Time to admire the plate.

	if _order != null:
		order_board.set_state(_order, Order.State.READY)
		var cooked := CookedDish.new(_order, quality)
		if session != null:  # It looks the way it came out.
			cooked.look = session.snapshot(session.recipe.serve_on)
			cooked.look_radius = session.surface(session.recipe.serve_on).radius()
		_cook.set_held_item(cooked)
		GameState.record_chef_action(_cook.player_index, "cooked")
	if session != null:
		session.queue_free()
		session = null
		_show_stove_props(true)
	_cook.movement_locked = false
	_cook.interactor.unlock()
	_cook.release_camera_focus()
	_cook = null
	_order = null
	minigame = null


func _finish_together(quality: float) -> void:
	_play_bounce()
	var floor_quality: float = _together.get("min_quality", 0.75)
	var rescued := quality < floor_quality
	if rescued:
		minigame.quality = floor_quality  # The display shows the fixed result.
	GameEvents.announce("%s came out %s." % [_together["dish"].get("name", "It"), CookingMinigame.quality_label(minigame.quality).to_lower()])
	await get_tree().create_timer(RESULT_SHOW_TIME).timeout
	if rescued:  # After their last coaching line has had a moment.
		_together["helper"].say(_together.get("rescue", ""))
		await get_tree().create_timer(RESULT_SHOW_TIME * 1.5).timeout
	_cook.movement_locked = false
	_cook.interactor.unlock()
	_cook.release_camera_focus()
	var result := minigame.quality
	_cook = null
	_together = {}
	minigame = null
	cooked_together.emit(result)
