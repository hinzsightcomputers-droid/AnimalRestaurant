# Customer: one animal guest. Holds its state (arriving, waiting, eating...) and
# walks along the waypoints it is given. CustomerManager decides where customers go
# and what happens when they're served; CustomerDisplay decides how they look.
class_name Customer
extends Node3D

# WAITING_BY_DOOR: a Gone regular come back at closing, waiting for their return scene.
enum State { ARRIVING, WAITING_TO_ORDER, WALKING_TO_SEAT, WAITING_FOR_FOOD, EATING, LEAVING, GONE, WAITING_BY_DOOR }

signal state_changed(customer: Customer)
signal finished_eating(customer: Customer)
signal spoke(customer: Customer)  # Said a one-off line (see say()).
signal talking_changed(customer: Customer)  # A conversation started or ended.
signal emoted(customer: Customer, emotion: StringName)  # Showed a feeling (see emote()).

@export var walk_speed := 2.0
@export var turn_speed := 10.0
@export var eat_duration := 4.0  # Regulars stay longer (eating_seconds in data/regulars.json).

var state: State = State.ARRIVING
var species: Dictionary = {}  # From data/species.json
var dish: Dictionary = {}     # From GameData.dishes. Picked on arrival, revealed when ordering.
var seat: Seat = null         # The chair reserved for this customer.
var display_name := ""        # "Mabel" for a regular, "Frog" for anyone else.
var regular_id := ""          # Empty unless this is a regular (data/characters/).
var greeting_line := ""       # What a regular says at the counter (empty = generic).
var greeting_emotion := &""   # How they feel saying it.
var order_line := ""          # What a regular says when ordering (empty = generic).
var speech := ""              # The latest one-off line, e.g. when served or chatted with.
var chatted := false          # A regular can be chatted with once while eating.
var learned_name := false     # A regular learned a chef's name this visit (for their goodbye).
var talking := false:         # In a conversation: their wait and meal timers pause, so chatting is never punished.
	set(value):
		if talking != value:
			talking = value
			talking_changed.emit(self)

var wait_seconds := 0.0       # From reaching the counter until the food arrives.
var served_quality := 0.0     # Quality of the dish they were served (0..1).
var served_dish: CookedDish = null  # The plate itself (its look shows on the table), if there was one.
var served_by_account := ""   # Account id of the chef who brought the food.
var reaction_line := ""       # What they say when leaving.
var payment := 0              # What they paid.

var _path: Array[Vector3] = []
var _state_after_path: State = State.ARRIVING
var _eat_time_left := 0.0
var _done_eating := false

@onready var interactable: Interactable = $Interactable


func setup(species_data: Dictionary, dish_data: Dictionary, reserved_seat: Seat) -> void:
	species = species_data
	dish = dish_data
	seat = reserved_seat
	display_name = species.get("name", "Customer")


func is_regular() -> bool:
	return not regular_id.is_empty()


func _ready() -> void:
	interactable.prompt_for_player = _prompt_for
	_update_interactable()


# "Serve" for whoever carries this customer's plate, "Check order" for free
# hands (pressing says what they're waiting for), nothing for anyone carrying
# something else. "Talk" to someone waiting by the door.
func _prompt_for(player_index: int) -> String:
	var player := Player.find(get_tree(), player_index)
	if player == null:
		return ""
	var plate := player.held_item as CookedDish
	if plate != null:
		return interactable.prompt if plate.order.customer == self else ""
	if player.held_item != null:
		return ""
	if state == State.WAITING_BY_DOOR:
		return "Talk"
	return "Chat" if state == State.EATING else "Check order"


# Walk through the given points in order, then switch to `state_on_arrival`.
func walk_to(points: Array[Vector3], state_on_arrival: State) -> void:
	_path = points.duplicate()
	_state_after_path = state_on_arrival


# Change where the current walk ends, keeping any waypoints before it
# (so someone still walking in doesn't cut across the room).
func set_destination(point: Vector3) -> void:
	if _path.is_empty():
		_path = [point]
	else:
		_path[-1] = point


func is_walking() -> bool:
	return not _path.is_empty()


# Called when a player takes this customer's order.
func place_order() -> void:
	_set_state(State.WALKING_TO_SEAT)


# Called when a player brings the food.
func serve(quality: float, plate: CookedDish = null) -> void:
	served_quality = quality
	served_dish = plate
	_eat_time_left = eat_duration
	_set_state(State.EATING)


# Say a one-off line in the speech bubble.
func say(line: String) -> void:
	if line.is_empty():
		return
	speech = line
	spoke.emit(self)


# Show a feeling, e.g. &"happy" (EmotionLibrary has them all): icons over
# their head, a little sound and a bounce. Nothing for "" or "neutral".
func emote(emotion: StringName) -> void:
	if emotion != &"" and emotion != &"neutral":
		emoted.emit(self, emotion)


# A regular who's eating and hasn't been chatted with yet this visit.
func can_chat() -> bool:
	return is_regular() and state == State.EATING and not chatted and not _done_eating


# The eating chat: say `line`, and no more chatting this visit.
func chat(line: String) -> void:
	chatted = true
	_update_interactable()
	say(line)


# Walk out along `points` saying `line`, having paid `amount`.
func leave(points: Array[Vector3], line: String, amount: int) -> void:
	reaction_line = line
	payment = amount
	walk_to(points, State.GONE)
	_set_state(State.LEAVING)


func _physics_process(delta: float) -> void:
	if not talking:
		match state:
			State.WAITING_TO_ORDER, State.WALKING_TO_SEAT, State.WAITING_FOR_FOOD:
				wait_seconds += delta
			State.EATING:
				_eat_time_left -= delta
				if _eat_time_left <= 0.0 and not _done_eating:
					_done_eating = true
					finished_eating.emit(self)

	_follow_path(delta)


func _follow_path(delta: float) -> void:
	if _path.is_empty():
		return

	var offset := _path[0] - global_position
	var step := walk_speed * delta

	if offset.length() <= step:
		global_position = _path[0]
		_path.pop_front()
		if _path.is_empty():
			_on_path_finished()
		return

	global_position += offset.normalized() * step
	if Vector2(offset.x, offset.z).length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(offset.x, offset.z), turn_speed * delta)


func _on_path_finished() -> void:
	# Once seated, face the same way as the chair (toward the table).
	if _state_after_path == State.WAITING_FOR_FOOD and seat != null:
		rotation.y = seat.global_rotation.y
	_set_state(_state_after_path)


func _set_state(new_state: State) -> void:
	state = new_state
	_update_interactable()
	state_changed.emit(self)


# Players can interact with a customer who is waiting for food or by the door,
# or chat once with a regular who is eating.
func _update_interactable() -> void:
	interactable.enabled = state in [State.WAITING_FOR_FOOD, State.WAITING_BY_DOOR] or can_chat()
