# ChoppingBoard: where ingredients that need chopping (like carrots) get chopped
# before going to the stove. Using it with those ingredients in hand puts them
# on the board and locks the player there, zoomed in; each press is one chop.
# After enough chops the player picks the chopped ingredients back up.
class_name ChoppingBoard
extends Station

@export_group("Camera zoom while chopping")
@export var zoom_look_offset := Vector3(0.0, 1.0, 0.2)  # Point the camera looks at, relative to the board.
@export var camera_zoom: CameraZoomSettings              # Distance, angle and tween time of the zoom-in.

var _chopper: Player = null
var _ingredients: Ingredients = null
var _chops_done := 0

@onready var pile: MeshInstance3D = $Visual/Pile  # The ingredient on the board while chopping.

var _pile_material := StandardMaterial3D.new()


func _ready() -> void:
	super._ready()
	interactable.prompt_for_player = _prompt_for
	pile.material_override = _pile_material
	pile.visible = false


# "Chop Carrots" for someone carrying ingredients that need it, the chop count
# for whoever is chopping, nothing for anyone else.
func _prompt_for(player_index: int) -> String:
	if _chopper != null:
		return "Chop! (%d/%d)" % [_chops_done, _ingredients.chops_needed()] if player_index == _chopper.player_index else ""
	var player := Player.find(get_tree(), player_index)
	if player == null:
		return ""
	var ingredients := player.held_item as Ingredients
	if ingredients != null and ingredients.needs_chopping():
		return "Chop %s" % ingredients.display_name()
	return ""


func _on_interacted(player_index: int) -> void:
	if _chopper == null:
		_start_chopping(player_index)
		return
	if player_index != _chopper.player_index:
		return  # Someone else is already chopping here.

	_chops_done += 1
	_play_bounce()
	# The pile flattens a little with each chop.
	var progress := float(_chops_done) / _ingredients.chops_needed()
	pile.scale = Vector3(1.0 + progress * 0.4, 1.0 - progress * 0.6, 1.0 + progress * 0.4)
	if _chops_done >= _ingredients.chops_needed():
		_finish_chopping()


func _start_chopping(player_index: int) -> void:
	var player := Player.find(get_tree(), player_index)
	if player == null:
		return
	var ingredients := player.held_item as Ingredients
	if ingredients == null or not ingredients.needs_chopping():
		return

	_chopper = player
	_ingredients = ingredients
	_chops_done = 0
	player.set_held_item(null)
	_pile_material.albedo_color = ingredients.color()
	pile.scale = Vector3.ONE
	pile.visible = true

	player.movement_locked = true
	player.interactor.lock_to(interactable)
	player.request_camera_focus(global_position + zoom_look_offset, camera_zoom)
	_play_bounce()
	used.emit(self, player_index)


func _finish_chopping() -> void:
	_ingredients.chopped = true
	pile.visible = false
	_chopper.set_held_item(_ingredients)
	_chopper.movement_locked = false
	_chopper.interactor.unlock()
	_chopper.release_camera_focus()
	GameEvents.announce("%s chopped the %s." % [Accounts.name_of(_chopper.player_index), _ingredients.order.dish.get("ingredient", {}).get("name", "ingredients").to_lower()])
	GameState.record_chef_action(_chopper.player_index, "chopped")
	_chopper = null
	_ingredients = null
