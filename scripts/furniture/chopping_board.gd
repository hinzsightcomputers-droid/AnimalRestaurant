# ChoppingBoard: where ingredients that need chopping (like carrots) get chopped
# before going to the stove (or filleted, for a fish: the ingredient can name
# its own close-up recipe). Using it with those ingredients in hand puts them
# on the board and zooms that player in on a close-up (a CookSession running
# the chopping recipe, see ChopAction). When they're chopped the player picks
# them back up, and how well they were chopped counts toward the dish.
class_name ChoppingBoard
extends Station

const RESULT_SHOW_TIME := 1.5  # Seconds the result stays up before the player can move.

@export var view_manager: ViewManager  # For the close-up's mouse aiming.
@export_group("Close-up")
@export var closeup_scene: PackedScene                 # Put on the board (a CookSession).
@export var recipe: CookRecipe                         # What it runs: the chopping, unless the ingredient names another.
@export var closeup_offset := Vector3(-0.1, 0.94, 0.05)  # Where it goes: the top of the board.
@export var closeup_look_offset := Vector3(-0.1, 0.94, -0.08)
@export var closeup_zoom: CameraZoomSettings

var session: CookSession = null  # Not null while someone is chopping.
var _chopper: Player = null
var _ingredients: Ingredients = null

@onready var knife: Array[Node3D] = [$Visual/Blade, $Visual/Handle]  # Picked up while chopping.


func _ready() -> void:
	super._ready()
	interactable.prompt_for_player = _prompt_for


# "Chop Carrots" for someone carrying ingredients that need it, nothing for
# anyone else (the close-up shows its own instructions).
func _prompt_for(player_index: int) -> String:
	if session != null:
		return ""
	var player := Player.find(get_tree(), player_index)
	if player == null:
		return ""
	var ingredients := player.held_item as Ingredients
	if ingredients != null and ingredients.needs_chopping():
		return "%s %s" % [ingredients.chop_verb(), ingredients.display_name()]
	return ""


func _on_interacted(player_index: int) -> void:
	if session != null:
		return  # The session reads the chopper's button itself.
	var player := Player.find(get_tree(), player_index)
	if player == null:
		return
	var ingredients := player.held_item as Ingredients
	if ingredients == null or not ingredients.needs_chopping():
		return
	player.set_held_item(null)
	_open_closeup(player, ingredients)
	used.emit(self, player_index)


# Chop with no order (debug panel): nothing to hand back at the end.
func practice(player: Player, with_recipe: CookRecipe = null) -> void:
	if session == null and player != null:
		_open_closeup(player, null, with_recipe)


# For a reel (see ReelDirector): `recipe` played well by itself, no order.
func reel_cook(player: Player, with_recipe: CookRecipe, _dish: Dictionary) -> void:
	practice(player, with_recipe)
	session.input.scripted = true
	session.big_hint()


func _open_closeup(player: Player, ingredients: Ingredients, with_recipe: CookRecipe = null) -> void:
	if with_recipe == null and ingredients != null:
		with_recipe = CookRecipe.for_dish({ "recipe": ingredients.chop_recipe() })
	if with_recipe == null:
		with_recipe = recipe
	_chopper = player
	_ingredients = ingredients
	session = closeup_scene.instantiate()
	session.position = closeup_offset
	add_child(session)
	for part in knife:
		part.visible = false
	player.movement_locked = true
	player.interactor.lock_to(interactable)
	player.request_camera_focus(global_position + closeup_look_offset, closeup_zoom)
	session.home_view = [global_position + closeup_look_offset, closeup_zoom]
	session.finished.connect(_on_chopped)
	session.start(with_recipe, player, view_manager if view_manager != null else get_tree().root.find_children("*", "ViewManager", true, false).front(), ingredients)
	_play_bounce()


func _on_chopped(quality: float) -> void:
	_play_bounce()
	await get_tree().create_timer(RESULT_SHOW_TIME).timeout
	session.queue_free()
	session = null
	for part in knife:
		part.visible = true
	if _ingredients != null:
		_ingredients.chopped = true
		_ingredients.chop_quality = quality
		_chopper.set_held_item(_ingredients)
		var verb := _ingredients.chop_verb().to_lower()
		GameEvents.announce("%s %s the %s (%s)." % [Accounts.name_of(_chopper.player_index), verb + ("ped" if verb == "chop" else "ed"),
			_ingredients.order.dish.get("ingredient", {}).get("name", "ingredients").to_lower(),
			CookingMinigame.quality_label(quality).to_lower()])
		GameState.record_chef_action(_chopper.player_index, "chopped")
	_chopper.movement_locked = false
	_chopper.interactor.unlock()
	_chopper.release_camera_focus()
	_chopper = null
	_ingredients = null
