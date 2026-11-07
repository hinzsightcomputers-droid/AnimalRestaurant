# Sink: where the dishes get washed. Spare dish bins wait on their own counter
# at the far left (take one to clear tables with, see DiningTable); bring one back full and
# wash its dishes in a close-up (see WashAction), which racks them clean on
# the right. The stove takes a clean plate from the rack for every dine-in
# order, so when the rack runs dry, someone has to wash up.
class_name Sink
extends Station

const GROUP := "sink"
const PLATE_MODEL := "res://design/assets/KayKit_Bits_Bundle1_1.1/Restaurant Bits/Assets/gltf/plate.gltf"
const COUNTER_TOP := 0.9
const RESULT_SHOW_TIME := 1.0

@export var view_manager: ViewManager     # For the close-up's mouse aiming (found if not set).
@export var start_plates := 10
@export var bins := 2
@export var rack_slots := 14              # How many plates the rack shows (it holds any number).
@export var bin_spot := Vector3(-1.325, COUNTER_TOP, 0.0)  # Where spare bins stack (clear of the one being washed).
@export var rack_spot := Vector3(0.8, COUNTER_TOP, -0.05)   # The middle of the rack.
@export var rack_width := 0.34            # From the first slot to the last.
@export_group("Close-up")
@export var closeup_scene: PackedScene
@export var recipe: CookRecipe
@export var closeup_look_offset := Vector3(0.0, 0.9, 0.05)
@export var closeup_zoom: CameraZoomSettings   # Its yaw is turned to match the sink.

var plates := 0                           # Clean, on the rack.
var bins_here := 0
var session: CookSession = null
var _washer: Player = null
var _bin: DishBin = null
var _bin_models: Array[DishBinModel] = []
var _rack_plates := Node3D.new()


func _ready() -> void:
	super._ready()
	add_to_group(GROUP)
	interactable.prompt_for_player = _prompt_for
	plates = start_plates
	bins_here = bins
	for i in bins:
		var model := DishBinModel.new()
		model.position = bin_spot + Vector3(0.0, i * 0.035, 0.0)
		visual.add_child(model)
		_bin_models.append(model)
	visual.add_child(_rack_plates)
	_refresh()


func _prompt_for(player_index: int) -> String:
	if session != null:
		return ""
	var player := Player.find(get_tree(), player_index)
	if player == null:
		return ""
	var bin := player.held_item as DishBin
	if bin != null:
		return "Put the bin back" if bin.dishes.is_empty() else "Wash dishes"
	if player.held_item == null and bins_here > 0:
		return "Take dish bin"
	return ""


func _on_interacted(player_index: int) -> void:
	if session != null:
		return  # The session reads the washer's button itself.
	var player := Player.find(get_tree(), player_index)
	if player == null:
		return
	var bin := player.held_item as DishBin
	if bin != null:
		if bin.dishes.is_empty():
			player.set_held_item(null)
			bins_here += 1
			_refresh()
			_play_bounce()
		else:
			_open_closeup(player, bin)
	elif player.held_item == null:
		if bins_here <= 0:
			GameEvents.announce("Both dish bins are out. Bring one back!")
			return
		bins_here -= 1
		player.set_held_item(DishBin.new())
		_refresh()
		_play_bounce()
		GameEvents.announce("Clear a messy table into the bin, then bring it back to wash.")
	else:
		return
	used.emit(self, player_index)


# A clean plate off the rack for a dish (false if there are none).
func take_plate() -> bool:
	if plates <= 0:
		return false
	plates -= 1
	_refresh()
	return true


func add_clean_plate() -> void:
	plates += 1
	_refresh()


# Where the next clean plate goes on the rack (world space).
func next_rack_spot() -> Vector3:
	return visual.global_transform * _slot(mini(plates, rack_slots - 1))


func _open_closeup(player: Player, bin: DishBin) -> void:
	_washer = player
	_bin = bin
	player.set_held_item(null)
	session = closeup_scene.instantiate()
	session.position = Vector3(0.0, COUNTER_TOP, 0.0)
	add_child(session)
	var model := DishBinModel.new()
	model.name = "Bin"
	session.surface("Bin").add_child(model)
	model.set_dishes(bin.dishes)
	session.context["rack_spot"] = next_rack_spot
	session.context["on_racked"] = func():
		add_clean_plate()
		GameState.record_chef_action(player.player_index, "washed")
	player.movement_locked = true
	player.interactor.lock_to(interactable)
	var zoom: CameraZoomSettings = closeup_zoom.duplicate()
	zoom.yaw_degrees = rad_to_deg(global_rotation.y)  # From in front of the sink, however it turns.
	player.request_camera_focus(global_transform * closeup_look_offset, zoom)
	session.finished.connect(_on_washed)
	var views := view_manager if view_manager != null else get_tree().root.find_children("*", "ViewManager", true, false).front() as ViewManager
	session.start(recipe, player, views)
	_play_bounce()


func _on_washed(_quality: float) -> void:
	_play_bounce()
	GameEvents.announce("%s washed %d dish%s." % [Accounts.name_of(_washer.player_index), _bin.dishes.size(), "" if _bin.dishes.size() == 1 else "es"])
	_bin.dishes.clear()
	await get_tree().create_timer(RESULT_SHOW_TIME).timeout
	session.queue_free()
	session = null
	bins_here += 1  # The empty bin stays by the sink.
	_refresh()
	_washer.movement_locked = false
	_washer.interactor.unlock()
	_washer.release_camera_focus()
	_washer.ignore_interact_until_released()
	_washer = null
	_bin = null


# The spare bins and the plates on the rack.
func _refresh() -> void:
	for i in _bin_models.size():
		_bin_models[i].visible = i < bins_here
	for child in _rack_plates.get_children():
		child.queue_free()
	for i in mini(plates, rack_slots):
		var plate := ModelFit.place(PLATE_MODEL, _rack_plates, Vector3.ZERO, Vector3(0.2, 0.0, 0.2))
		if plate != null:
			plate.position = _slot(i)
			plate.rotation.z = PI * 0.5  # Standing on its edge.


# A rack slot's middle, in the visual's coordinates: slots run left to right.
func _slot(index: int) -> Vector3:
	var step := rack_width / maxf(rack_slots - 1, 1)
	return rack_spot + Vector3(-rack_width * 0.5 + index * step, 0.12, 0.0)


# For a reel (see ReelDirector): wash the bin in their hands, played well by
# itself; with none (or an empty one), a bin of two dirty plates.
func reel_cook(player: Player, _recipe: CookRecipe, _dish: Dictionary) -> void:
	var bin := player.held_item as DishBin
	if bin == null or bin.dishes.is_empty():
		bin = DishBin.new()
		bin.dishes.append_array([DiningTable.PLATE_MODEL, DiningTable.PLATE_MODEL])
	_open_closeup(player, bin)
	session.input.scripted = true
	session.big_hint()
