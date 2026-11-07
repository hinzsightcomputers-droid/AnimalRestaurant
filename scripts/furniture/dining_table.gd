# DiningTable: a table that gets messy after a customer eats: their dirty dish
# stays behind, with a spill or two beside it. Cleaning it takes two chores,
# which two players can split: someone carrying a dish bin (from the Sink)
# clears the dishes into it (a close-up, see BusAction), then someone with free
# hands wipes the spills (see WipeAction). Its seats aren't given to new
# customers until both are done.
# A player leading a customer to their seat seats them here (see
# CustomerManager), and each table has a spot (corner, window...) a regular can
# ask for.
class_name DiningTable
extends Station

signal cleanliness_changed(table: DiningTable)
signal seat_requested(table: DiningTable, player_index: int)

const TOP_HEIGHT := 0.82
const PLATE_MODEL := "res://design/assets/KayKit_Bits_Bundle1_1.1/Restaurant Bits/Assets/gltf/plate_dirty.gltf"
const RESULT_SHOW_TIME := 1.0  # Seconds the close-up stays after the chore is done.

@export var view_manager: ViewManager  # For the close-up's mouse aiming (found if not set).
@export var spills_per_dish := 2
@export var spot := ""  # Where it is, for regulars with a usual table: corner, window, middle or kitchen.
@export_group("Close-up")
@export var closeup_scene: PackedScene          # Put on the table top (a CookSession).
@export var clear_recipe: CookRecipe
@export var wipe_recipe: CookRecipe
@export var closeup_look_offset := Vector3(0.0, 0.82, 0.12)
@export var closeup_zoom: CameraZoomSettings

var dishes: Array[Dictionary] = []    # Left behind: { at (world), model }.
var spills: Array[Vector3] = []       # Where (world).
var session: CookSession = null       # Not null while someone is clearing or wiping.
var _worker: Player = null
var _bin: DishBin = null              # The bin being filled, while clearing.
# Set by CustomerManager: (player_index, table) -> "Seat Mabel" if that player
# is leading someone who can sit here, else "".
var seating_prompt: Callable


func _ready() -> void:
	super._ready()
	interactable.prompt_for_player = _prompt_for
	_update_interactable()


func is_clean() -> bool:
	return dishes.is_empty() and spills.is_empty()


func is_wiping() -> bool:
	return session != null and _bin == null


# Called when a customer leaves; `at` is where their plate was, `dish` what they ate.
func make_dirty(at: Vector3, dish: Dictionary = {}) -> void:
	var was_clean := is_clean()
	dishes.append({ "at": at, "model": dish.get("dirty_model", PLATE_MODEL) })
	var toward_middle := Vector3(global_position.x - at.x, 0.0, global_position.z - at.z).normalized()
	for i in spills_per_dish:
		var side := toward_middle.rotated(Vector3.UP, randf_range(0.6, 1.4) * (1.0 if i % 2 == 0 else -1.0))
		spills.append(at + side * randf_range(0.22, 0.3))
	_update_interactable()
	cleanliness_changed.emit(self)
	if was_clean:
		GameEvents.announce("A table needs clearing.")


func _prompt_for(player_index: int) -> String:
	if session != null:
		return ""
	var seating := _seating_prompt(player_index)
	if not seating.is_empty():
		return seating
	var player := Player.find(get_tree(), player_index)
	if player == null:
		return ""
	var bin := player.held_item as DishBin
	if not dishes.is_empty():
		if bin != null:
			return "Clear dishes" if not bin.is_full() else "Dish bin is full"
		return "Needs the dish bin" if player.held_item == null else ""
	if not spills.is_empty() and player.held_item == null:
		return "Wipe table"
	return ""


func _on_interacted(player_index: int) -> void:
	if session != null:
		return  # The session reads the worker's button itself.
	if not _seating_prompt(player_index).is_empty():
		seat_requested.emit(self, player_index)
		_play_bounce()
		return
	var player := Player.find(get_tree(), player_index)
	if player == null:
		return
	var bin := player.held_item as DishBin
	if not dishes.is_empty():
		if bin == null:
			if player.held_item == null:
				GameEvents.announce("Grab a dish bin from the sink to clear the dishes.")
			return
		if bin.is_full():
			GameEvents.announce("That bin is full. Wash those dishes at the sink first!")
			return
		_open_closeup(player, clear_recipe, bin)
	elif not spills.is_empty() and player.held_item == null:
		_open_closeup(player, wipe_recipe, null)
	else:
		return
	used.emit(self, player_index)


func _open_closeup(player: Player, recipe: CookRecipe, bin: DishBin) -> void:
	_worker = player
	_bin = bin
	session = closeup_scene.instantiate()
	session.position = Vector3(0.0, TOP_HEIGHT, 0.0)
	add_child(session)
	session.global_rotation = Vector3.ZERO  # Lined up with the camera, however the table turns.
	if bin != null:
		player.set_held_item(null)  # It's on the table now.
		var model := DishBinModel.new()
		model.name = "Bin"
		session.surface("Bin").add_child(model)
		model.set_dishes(bin.dishes)
		var taking := []
		for entry in dishes.slice(0, bin.room()):
			taking.append({ "at": _on_top(entry["at"]), "model": entry["model"] })
		session.context["dishes"] = taking
	else:
		session.surface("Bin").visible = false
		var where := []
		for at in spills:
			where.append(_on_top(at))
		session.context["spills"] = where
	cleanliness_changed.emit(self)  # The mess display hides: the close-up shows it now.
	player.movement_locked = true
	player.interactor.lock_to(interactable)
	player.request_camera_focus(global_position + closeup_look_offset, closeup_zoom)
	session.finished.connect(_on_done)
	var views := view_manager if view_manager != null else get_tree().root.find_children("*", "ViewManager", true, false).front() as ViewManager
	session.start(recipe, player, views)
	_play_bounce()


# A world spot as a place on the close-up's table top.
func _on_top(at: Vector3) -> Vector3:
	var local := session.to_local(at)
	return Vector3(local.x, 0.0, local.z)


func _on_done(_quality: float) -> void:
	_play_bounce()
	var name_of := Accounts.name_of(_worker.player_index)
	if _bin != null:
		var taken := dishes.slice(0, _bin.room())
		for entry in taken:
			_bin.dishes.append(entry["model"])
		dishes = dishes.slice(taken.size())
		GameEvents.announce("%s cleared the table.%s" % [name_of, " Now it needs a wipe!" if dishes.is_empty() else ""])
		GameState.record_chef_action(_worker.player_index, "cleared")
	else:
		spills.clear()
		GameEvents.announce("%s wiped the table." % name_of)
		GameState.record_chef_action(_worker.player_index, "cleaned")
	await get_tree().create_timer(RESULT_SHOW_TIME).timeout
	session.queue_free()
	session = null
	if _bin != null:
		_worker.set_held_item(_bin)  # Back in their hands, fuller.
	_worker.movement_locked = false
	_worker.interactor.unlock()
	_worker.release_camera_focus()
	_worker.ignore_interact_until_released()
	_worker = null
	_bin = null
	_update_interactable()
	cleanliness_changed.emit(self)


func _seating_prompt(player_index: int) -> String:
	return seating_prompt.call(player_index, self) if seating_prompt.is_valid() else ""


# Always usable: the prompt says what there is to do (seat someone, clear, wipe), or nothing.
func _update_interactable() -> void:
	interactable.enabled = true
	interactable.prompt = "Clear dishes" if not dishes.is_empty() else "Wipe table"
	interactable.priority = 0 if is_clean() else 1  # A mess to clean beats its own chairs, close by.


# For a reel (see ReelDirector): clear it (clear_recipe) or wipe it, played well
# by itself. A clean table gets a mess first: a dirty dish at each chair.
func reel_cook(player: Player, recipe: CookRecipe, _dish: Dictionary) -> void:
	if recipe == clear_recipe:
		if dishes.is_empty():
			_reel_mess()
		var bin := player.held_item as DishBin
		_open_closeup(player, clear_recipe, bin if bin != null else DishBin.new())
	else:
		if spills.is_empty():
			_reel_mess()
			dishes.clear()
		_open_closeup(player, wipe_recipe, null)
	session.input.scripted = true
	session.big_hint()


func _reel_mess() -> void:
	var dirty := [{}, GameData.get_dish("vegetable_soup")]
	var i := 0
	for seat in get_tree().root.find_children("*", "Seat", true, false):
		if seat.table == self:
			make_dirty(seat.meal_position(), dirty[i % dirty.size()])
			i += 1
