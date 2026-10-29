# DrinkStation: the drinks counter, with a fridge and a brewer. Walk up with
# free hands and pick one of the drinks customers are waiting on (only those:
# nothing to make when nobody's ordered).
# How it's made depends on its "prep" (design/menu/drinks.json):
#   grab: straight from the fridge into your hands.
#   pour: hold interact to fill the glass, and let go at the line. The closer
#         to the line, the better; too far and it spills over.
#   brew: start it, and it brews for a moment (brew_seconds in
#         data/drink_kitchen.json) while you do something else. Then come back
#         and pour it the same way.
# One brew at a time. The drink goes in your hands (a Drink) to carry to the table.
class_name DrinkStation
extends Station

enum Pour { NONE, WAIT_RELEASE, WAIT_PRESS, FILLING }

const LINE := 0.8  # The fill line, as a fraction of the cup.
const CUP_SCALE := 2.0
const POUR_LABEL_AT := Vector3(-0.3, 1.38, 0.12)  # While pouring: just above the cup, smaller.
const POUR_LABEL_SIZE := 0.0015

@export var view_manager: ViewManager  # To show the drinks list in the right player's view.

var _choosing := false
var _brewing: Dictionary = {}   # The drink brewing (or brewed, once _brew_left is 0), {} if none.
var _brew_left := 0.0
var _pourer: Player = null      # Who's pouring right now.
var _pour_drink: Dictionary = {}
var _pour := Pour.NONE
var _fill := 0.0
var _cup: DrinkModel = null     # The cup on the counter while brewing or pouring.
var _line: MeshInstance3D = null

@onready var cup_spot: Marker3D = $CupSpot
@onready var status_label: Label3D = $StatusLabel
@onready var _brew_label_at := status_label.position
@onready var _brew_label_size := status_label.pixel_size


func _ready() -> void:
	super._ready()
	interactable.prompt_for_player = _prompt_for


func _prompt_for(player_index: int) -> String:
	var player := Player.find(get_tree(), player_index)
	if player == null or _choosing or _pourer != null or player.held_item != null:
		return ""
	if not _brewing.is_empty():
		return "Pour %s" % _brewing["name"] if _brew_left <= 0.0 else ""
	return "Make a drink" if not _drinks_to_make().is_empty() else ""


func _on_interacted(player_index: int) -> void:
	var player := Player.find(get_tree(), player_index)
	if player == null or _choosing or _pourer != null or player.movement_locked:
		return
	if player.held_item != null:
		GameEvents.announce("Your hands are full.")
		return
	if not _brewing.is_empty():
		if _brew_left > 0.0:
			GameEvents.announce("The %s is still brewing." % _brewing["name"])
			return
		var brewed := _brewing
		_brewing = {}
		_start_pour(player, brewed)
		return
	_choose(player)


# Pick one of the drinks customers are waiting on.
func _choose(player: Player) -> void:
	var drinks := _drinks_to_make()
	if drinks.is_empty():
		GameEvents.announce("Nobody's waiting on a drink.")
		return
	_choosing = true
	player.movement_locked = true
	player.interactor.lock_to(interactable)
	var options: Array = drinks.map(func(d): return d["name"])
	options.append("Never mind")
	var box := ConversationBox.open(ConversationBox.parent_for(view_manager, player.player_index, self), player.player_index, "")
	var picked := await box.ask("Drinks", "What are you making?", options)
	box.close()
	player.ignore_interact_until_released()
	player.movement_locked = false
	player.interactor.unlock()
	_choosing = false
	if picked >= drinks.size():
		return
	var drink: Dictionary = drinks[picked]
	_play_bounce()
	used.emit(self, player.player_index)
	match drink.get("prep", "grab"):
		"pour":
			_start_pour(player, drink)
		"brew":
			_brewing = drink
			_brew_left = float(GameData.drink_settings.get("brew_seconds", 6.0))
			_show_cup(drink, 0.0)
			GameEvents.announce("Brewing %s. Come back to pour it in a moment." % drink["name"])
		_:
			player.set_held_item(Drink.new(drink, 1.0))
			GameEvents.announce("Grabbed a %s from the fridge." % drink["name"])


# The drinks seated customers are waiting for that nobody's making or carrying
# yet, one entry per kind (two lemonades ordered and one poured: one left).
func _drinks_to_make() -> Array:
	var wanted := []
	for node in get_tree().get_nodes_in_group(Customer.GROUP):
		var customer := node as Customer
		if customer != null and customer.state == Customer.State.WAITING_FOR_DRINK:
			wanted.append(customer.drink.get("id", ""))
	var made := []
	if not _brewing.is_empty():
		made.append(_brewing["id"])
	if _pourer != null:
		made.append(_pour_drink.get("id", ""))
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		var held = (node as Player).held_item
		if held is Drink:
			made.append(held.id())
	for id in made:
		wanted.erase(id)
	var drinks := []
	for drink in GameData.drink_menu():
		if drink["id"] in wanted:
			drinks.append(drink)
	return drinks


# Hold interact to fill to the line. The player stays at the counter until it's done.
func _start_pour(player: Player, drink: Dictionary) -> void:
	_pourer = player
	_pour_drink = drink
	_fill = 0.0
	_pour = Pour.WAIT_RELEASE
	player.movement_locked = true
	player.interactor.lock_to(interactable)
	player.request_camera_focus(cup_spot.global_position + Vector3.UP * DrinkModel.HEIGHT * CUP_SCALE * LINE, _pour_zoom())
	player.hide_from_own_view(true)  # So the chef doesn't block the cup.
	_show_cup(drink, 0.0)
	status_label.text = "Hold to pour %s.\nLet go at the line!" % drink["name"]
	status_label.position = POUR_LABEL_AT
	status_label.pixel_size = POUR_LABEL_SIZE
	status_label.visible = true


func _process(delta: float) -> void:
	if not _brewing.is_empty() and _brew_left > 0.0:
		_brew_left -= delta
		status_label.visible = _pourer == null
		status_label.text = "Brewing %s... %ds" % [_brewing["name"], ceili(_brew_left)] if _brew_left > 0.0 else "%s is ready to pour!" % _brewing["name"]
	if _pourer == null:
		if _brewing.is_empty() and _cup != null:
			_hide_cup()
		return
	if not is_instance_valid(_pourer):
		_pourer = null
		_pour = Pour.NONE
		return
	var pressed := _pourer.input.is_interact_pressed()
	match _pour:
		Pour.WAIT_RELEASE:
			if not pressed:
				_pour = Pour.WAIT_PRESS
		Pour.WAIT_PRESS:
			if pressed:
				_pour = Pour.FILLING
		Pour.FILLING:
			_fill += delta / float(GameData.drink_settings.get("fill_seconds", 1.6)) * LINE
			_cup.set_fill(_fill)
			var spill := float(GameData.drink_settings.get("spill_fill", 1.25)) * LINE
			if not pressed or _fill >= spill:
				_finish_pour(_fill >= spill)


func _finish_pour(spilled: bool) -> void:
	var player := _pourer
	var quality := 0.2 if spilled else clampf(1.0 - absf(_fill - LINE) / 0.4, 0.1, 1.0)
	_pourer = null
	_pour = Pour.NONE
	player.set_held_item(Drink.new(_pour_drink, quality))
	player.ignore_interact_until_released()
	player.movement_locked = false
	player.interactor.unlock()
	player.release_camera_focus()
	player.hide_from_own_view(false)
	_play_bounce()
	if spilled:
		GameEvents.announce("Oops, the %s spilled over!" % _pour_drink["name"])
	else:
		GameEvents.announce("Poured a %s (%s)." % [_pour_drink["name"], CookingMinigame.quality_label(quality)])
	status_label.visible = not _brewing.is_empty()
	status_label.position = _brew_label_at
	status_label.pixel_size = _brew_label_size
	_hide_cup()
	if not _brewing.is_empty():
		_show_cup(_brewing, 0.0)  # Back to the brew it was making.


# Close in on the cup, level with the fill line so you can see exactly where
# the drink is, from the side so the chef isn't in the way.
func _pour_zoom() -> CameraZoomSettings:
	var zoom := CameraZoomSettings.new()
	zoom.distance = 0.6
	zoom.pitch_degrees = 1.0
	zoom.yaw_degrees = rad_to_deg(atan2(global_basis.z.x, global_basis.z.z)) - 35.0
	return zoom


func _show_cup(drink: Dictionary, fill: float) -> void:
	_hide_cup()
	_cup = DrinkModel.make(drink, fill, true)
	_cup.scale = Vector3.ONE * CUP_SCALE
	cup_spot.add_child(_cup)
	if drink.get("vessel", "glass") == "bottle":
		return
	# The line to stop at: a thin dark ring around the cup.
	_line = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = DrinkModel.rim_radius(drink) * 1.0
	ring.outer_radius = DrinkModel.rim_radius(drink) * 1.18
	_line.mesh = ring
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.2, 0.15)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line.material_override = material
	_line.scale = Vector3(1.0, 0.25, 1.0)
	_line.position.y = DrinkModel.HEIGHT * 0.96 * LINE
	_cup.add_child(_line)


func _hide_cup() -> void:
	if _cup != null:
		_cup.queue_free()
		_cup = null
		_line = null
