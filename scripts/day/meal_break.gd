# MealBreak: the breather between meals. Once a meal's customers have all gone,
# before anyone rings the bell for the next one, a staff meal is laid out on a
# clean table: a plate for each chef. Eating it (interact, hands free) takes a
# moment and leaves them well fed: a little quicker on their feet for the next
# meal. The floors need a sweep too (FloorCare). Nothing's timed: the bell
# starts the next meal whenever they like. Words in data/service.json "break".
class_name MealBreak
extends Node3D

const EAT_SECONDS := 1.8
const PLATE_OUT := 0.3        # Plates sit this far out from the table's middle.
const PLATE_WIDTH := 0.3

var on := false

var _eaten := {}              # Player indexes who've had theirs.
var _plates: Array[Node3D] = []
var _interactable := Interactable.new()
var _laid := false
var _table: DiningTable  # Where it's laid.


static func settings() -> Dictionary:
	return GameData.service.get("break", {})


func _ready() -> void:
	_interactable.radius = 1.6
	_interactable.prompt_height = 1.3
	_interactable.priority = 2  # Over the table's chairs.
	_interactable.enabled = false
	_interactable.prompt_for_player = _prompt_for
	_interactable.interacted.connect(_on_interacted)
	add_child(_interactable)


# The meal's over: take a break (none after the last one: that's closing).
func begin() -> void:
	on = true
	_eaten.clear()
	GameEvents.announce(String(settings().get("text", "Time for a breather!")))


# The bell was rung: whoever ate has a spring in their step, and it's cleared away.
func finish() -> void:
	for player: Player in get_tree().get_nodes_in_group(Player.GROUP):
		player.well_fed = on and _eaten.has(player.player_index)
	on = false
	_laid = false
	_interactable.enabled = false
	if _table != null and is_instance_valid(_table):
		_table.put_centerpiece_away("staff_meal", false)
	_table = null
	for plate in _plates:
		plate.queue_free()
	_plates.clear()


func _process(_delta: float) -> void:
	if not on or _laid:
		return
	var table := _clean_table()  # As soon as there is one.
	if table != null:
		_lay(table)


func _clean_table() -> DiningTable:
	var found: DiningTable = null
	for node in get_tree().get_nodes_in_group(CustomerManager.SEAT_GROUP):
		var table: DiningTable = node.table if node is Seat else null
		if table != null and table.is_clean() and table.session == null and (found == null or table.spot == String(settings().get("table", "kitchen"))):
			found = table
	return found


func _lay(table: DiningTable) -> void:
	_laid = true
	_table = table
	table.put_centerpiece_away("staff_meal", true)
	global_position = table.global_position
	_interactable.enabled = true
	var chefs := InputSetup.active_players()
	var menu := GameData.menu()
	for i in chefs.size():
		var plate := Node3D.new()
		var out := Vector2.from_angle(TAU * i / chefs.size()) * (PLATE_OUT if chefs.size() > 1 else 0.0)
		plate.position = Vector3(out.x, DiningTable.TOP_HEIGHT, out.y)
		add_child(plate)
		ModelFit.place(Sink.PLATE_MODEL, plate, Vector3.ZERO, Vector3(PLATE_WIDTH, 0.0, PLATE_WIDTH))
		if not menu.is_empty():
			ModelFit.place(String(menu.pick_random().get("model", "")), plate, Vector3(0.0, 0.03, 0.0), Vector3(PLATE_WIDTH * 0.75, 0.0, PLATE_WIDTH * 0.75))
		plate.scale = Vector3.ONE * 0.1
		create_tween().tween_property(plate, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(i * 0.1)
		_plates.append(plate)


func _prompt_for(player_index: int) -> String:
	var player := Player.find(get_tree(), player_index)
	if player == null or player.held_item != null or _eaten.has(player_index) or _plates.is_empty():
		return ""
	return String(settings().get("prompt", "Staff meal"))


func _on_interacted(player_index: int) -> void:
	if not on or _prompt_for(player_index).is_empty():
		return
	var player := Player.find(get_tree(), player_index)
	if player.movement_locked:
		return
	_eaten[player_index] = true
	var plate: Node3D = _plates.pop_back()
	player.movement_locked = true
	var toward := global_position - player.global_position
	player.visual.rotation.y = atan2(toward.x, toward.z)
	var munch := create_tween()
	for bite in 4:
		munch.tween_callback(_bite.bind(player))
		munch.tween_property(plate, "scale", Vector3.ONE * (1.0 - 0.06 * (bite + 1)), EAT_SECONDS / 4.0)
	await munch.finished
	plate.queue_free()
	if not is_instance_valid(player):
		return
	player.movement_locked = false
	player.ignore_interact_until_released()
	GameEvents.announce(String(settings().get("eaten_text", "{name} is well fed!")).format({ "name": Accounts.name_of(player_index) }))
	if InputSetup.active_players().all(func(p): return _eaten.has(p)):
		GameEvents.announce(String(settings().get("all_text", "Everyone's fed. Ring the bell when you're ready!")))
	if not on:  # The bell was rung mid-mouthful.
		player.well_fed = true


func _bite(player: Player) -> void:
	if not is_instance_valid(player):
		return
	var sound := AudioStreamPlayer3D.new()
	sound.stream = CookSounds.get_sound("chop")
	sound.volume_db = -14.0
	sound.pitch_scale = randf_range(1.5, 1.8)
	sound.finished.connect(sound.queue_free)
	add_child(sound)
	sound.play()
	var chew := create_tween()
	chew.tween_property(player.visual, "scale", Vector3(1.04, 0.95, 1.04), 0.1)
	chew.tween_property(player.visual, "scale", Vector3.ONE, 0.15)
