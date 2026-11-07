# Customer: one animal guest. Holds its state (arriving, waiting, eating...) and
# walks along the waypoints it is given. CustomerManager decides where customers go
# and what happens at each step; CustomerDisplay decides how they look.
# A visit: wait at the host stand, follow a player to a table, order a drink,
# get it, order food, get it, eat, ask for the bill, pay and leave.
# They're solid while on their feet (players bump into them, not through), and
# wait for a player or a customer standing in their way to move (see _blocked).
class_name Customer
extends Node3D

const GROUP := "customers"
const FOLLOW_DISTANCE := 1.1  # How far behind the player leading them they walk.
const TRAIL_STEP := 0.3       # How often (in metres) the leader's footsteps are dropped on their trail.
const BODY_RADIUS := 0.22     # How wide a gap they need to cut straight across to the trail.
const BODY_LAYER := 3         # Physics layer of their body, which players collide with.
const SOLID_RADIUS := 0.28    # Their body, for players to bump into.
const BLOCK_DISTANCE := 0.8   # They stop for a player or a standing customer this close ahead...
const MAX_WAIT_SECONDS := 2.5 # ...but (outside the line) no longer than this, so nobody's stuck for good.

# WAITING_BY_DOOR: a Gone regular come back at closing, waiting for their return scene.
enum State {
	ARRIVING, WAITING_TO_BE_SEATED, FOLLOWING, WALKING_TO_SEAT,
	WAITING_DRINK_ORDER, WAITING_FOR_DRINK, WAITING_FOOD_ORDER, WAITING_FOR_FOOD,
	EATING, WANTS_BILL, LEAVING, GONE, WAITING_BY_DOOR, DONE_EATING,
}
# Sitting at their table, from being seated until they leave.
const SEATED_STATES: Array[State] = [State.WAITING_DRINK_ORDER, State.WAITING_FOR_DRINK, State.WAITING_FOOD_ORDER, State.WAITING_FOR_FOOD, State.EATING, State.DONE_EATING, State.WANTS_BILL]

signal state_changed(customer: Customer)
signal finished_eating(customer: Customer)  # Done with the meal: they wait for someone to come and chat.
signal getting_going(customer: Customer)    # A regular nobody chatted with will ask for the bill soon.
signal spoke(customer: Customer)  # Said a one-off line (see say()).
signal talking_changed(customer: Customer)  # A conversation started or ended.
signal emoted(customer: Customer, emotion: StringName)  # Showed a feeling (see emote()).

@export var walk_speed := 2.0
@export var turn_speed := 10.0
@export var eat_duration := 4.0  # Regulars stay longer (eating_seconds in data/regulars.json).

var state: State = State.ARRIVING
var species: Dictionary = {}  # From data/species.json
var dish: Dictionary = {}     # From GameData.dishes. Picked on arrival, revealed when ordering.
var drink: Dictionary = {}    # The drink they ordered (GameData.drinks), {} until then.
var served_drink: Dictionary = {}  # The drink they got (maybe not the one they asked for).
var drink_quality := 0.0      # How well it was poured.
var drink_secret := false     # A regular who just asked for "the usual" without naming it.
var wanted_table := ""        # The table spot a regular asked for this visit ("" for none).
var surprise_meal := false    # A regular who asked to be surprised with the food too.
var seated_line_pending := false  # Their seating line is one to say at the table (see CustomerManager).
var seat_note := ""           # Something they do as they sit (e.g. Mabel inspecting the table), announced then.
var seat: Seat = null         # Their chair, once a player seats them.
var leader: Player = null     # The player leading them to a table.
var display_name := ""        # "Mabel" for a regular who's told you their name, "Frog" for anyone else.
var regular_id := ""          # Empty unless this is a regular (data/characters/).
var townsfolk_id := ""        # A named walk-in (data/townsfolk/), else empty.
var is_critic := false        # Here for the next star (see Rating).
var quiet := false            # An extra in a reel: no speech bubble over their head.
var last_chef := ""           # The account of the chef who last dealt with them (for {chef} in townsfolk lines).
var greeting_line := ""       # What a regular says at the host stand (empty = generic).
var greeting_emotion := &""   # How they feel saying it.
var greeting_introduces := false  # Their greeting tells you their name ("introduces" on the line).
var order_line := ""          # What a regular says when ordering (empty = generic).
var speech := ""              # The latest one-off line, e.g. when served or chatted with.
var chatted := false          # A regular can be chatted with once while eating.
var laughed := false          # Rush's laugh chain has gone off this visit.
var visit_mood := 0.0         # What a semi-regular's replies did for this visit's satisfaction.
var learned_name := false     # A regular learned a chef's name this visit (for their goodbye).
var talking := false:         # In a conversation: their wait and meal timers pause, so chatting is never punished.
	set(value):
		if talking != value:
			talking = value
			talking_changed.emit(self)

var wait_seconds := 0.0       # From ordering food until it arrives.
var plan_index := -1          # Which of the meal's planned customers this is (-1: not from the plan).
var served_quality := 0.0     # Quality of the dish they were served (0..1).
var streak := 0                # The run of good serves (ServiceStreak) that their dish made.
var just_in_time := false     # Their dish came in the last few seconds before it would have been too slow (ServiceStreak).
var served_dish: CookedDish = null  # The plate itself (its look shows on the table), if there was one.
var served_by_account := ""   # Account id of the chef who brought the food.
var reaction_line := ""       # What they say when leaving.
var payment := 0              # What they paid.

var sit_seconds := 0.0    # How long their model takes to sit down, or 0: they just walk onto the chair.
var stand_seconds := 0.0  # How long it takes to stand up, or 0: they just walk off the chair.
var sitting_down := false  # On the last step into the chair, timed to the clip.
var standing_up := false   # On the first step out of it, the same.

var _timed_speed := 0.0    # Meters a second on a step timed to a clip.
var _path: Array[Vector3] = []
var _state_after_path: State = State.ARRIVING
var _eat_time_left := 0.0
var _stay_left := 0.0         # A regular nobody chatted with asks for the bill when this runs out.
var _warned := false          # Said they should get going.
var _trail: Array[Vector3] = [] # Where the leader has walked, oldest first: followed so they go around furniture.
var _done_eating := false
var _pace := 1.0              # Walking speed factor for the current walk (Mabel takes her time).
var _waited := 0.0            # How long they've been stopped by someone in the way.
var _waiting_on_customer := false  # Stopped behind another customer.
var _last_step := Vector3.ZERO  # How far they moved last frame (others check whether they're coming at them).
var _body := StaticBody3D.new()

@onready var interactable: Interactable = $Interactable


func setup(species_data: Dictionary, dish_data: Dictionary, reserved_seat: Seat) -> void:
	species = species_data
	dish = dish_data
	seat = reserved_seat
	display_name = species.get("name", "Customer")


func is_regular() -> bool:
	return not regular_id.is_empty()


func is_townsfolk() -> bool:
	return not townsfolk_id.is_empty()


func _ready() -> void:
	add_to_group(GROUP)
	interactable.prompt_for_player = _prompt_for
	var shape := CylinderShape3D.new()
	shape.radius = SOLID_RADIUS
	shape.height = 1.0
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.5
	_body.add_child(collision)
	_body.collision_mask = 0
	add_child(_body)
	_update_body()
	_update_interactable()


# What a player can do with this customer right now, given what they carry:
# seat them, take their drink or food order, give them their drink, food or
# bill, chat, or "" for nothing.
func _prompt_for(player_index: int) -> String:
	var player := Player.find(get_tree(), player_index)
	if player == null:
		return ""
	var held := player.held_item
	match state:
		State.WAITING_TO_BE_SEATED:
			return "Seat %s" % display_name if held == null and not is_walking() else ""
		State.WAITING_DRINK_ORDER:
			return "Take drink order" if held == null else ""
		State.WAITING_FOR_DRINK:
			if held is Drink:
				return "Give %s" % held.display_name()
			return "Check drink" if held == null else ""
		State.WAITING_FOOD_ORDER:
			return "Take order" if held == null else ""
		State.WAITING_FOR_FOOD:
			if held is CookedDish:
				return interactable.prompt if held.order.customer == self else ""
			return "Check order" if held == null else ""
		State.EATING:
			return "Chat" if held == null and can_chat() else ""
		State.DONE_EATING:
			return "Chat" if held == null else ""
		State.WANTS_BILL:
			if held is Receipt:
				return "Give the bill"
			return "Check" if held == null else ""
		State.WAITING_BY_DOOR:
			return "Talk" if held == null else ""
	return ""


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


func is_seated() -> bool:
	return state in SEATED_STATES


# A player starts leading them from the host stand to a table.
func follow(player: Player) -> void:
	leader = player
	_path.clear()
	_trail = [player.global_position]
	_set_state(State.FOLLOWING)


# Back to waiting to be seated (their leader left the game).
func stop_following() -> void:
	leader = null
	_set_state(State.WAITING_TO_BE_SEATED)


# The player leading them picked a table: walk to `chair` and sit.
# They finish walking the leader's trail first, so they don't cut across.
func sit_at(chair: Seat) -> void:
	leader = null
	seat = chair
	_skip_ahead()
	var path: Array[Vector3] = _trail.duplicate()
	_trail.clear()
	path.append_array([chair.approach_point.global_position, chair.seat_point.global_position])
	walk_to(path, State.WAITING_DRINK_ORDER)
	_set_state(State.WALKING_TO_SEAT)


# They found a table on their own: walk `points` to `chair` and sit, at
# `speed_factor` of their usual pace.
func seat_self(chair: Seat, points: Array[Vector3], speed_factor := 1.0) -> void:
	leader = null
	seat = chair
	_pace = speed_factor
	walk_to(points, State.WAITING_DRINK_ORDER)
	_set_state(State.WALKING_TO_SEAT)


# They asked for `drink_data`.
func order_drink(drink_data: Dictionary) -> void:
	drink = drink_data
	_set_state(State.WAITING_FOR_DRINK)


# A player brought them a drink (the one they ordered or not), poured this well.
func serve_drink(drink_data: Dictionary, quality: float) -> void:
	served_drink = drink_data
	drink_quality = quality
	_set_state(State.WAITING_FOOD_ORDER)


func got_the_drink_they_ordered() -> bool:
	return not served_drink.is_empty() and served_drink.get("id", "") == drink.get("id", "")


# Called when a player takes this customer's food order.
func place_order() -> void:
	_set_state(State.WAITING_FOR_FOOD)


# Called when a player brings the food. Townsfolk ask for the bill once they've
# eaten; a regular stays until someone has chatted with them, or for
# regular_stay_seconds (data/service.json), whichever comes first.
func serve(quality: float, plate: CookedDish = null) -> void:
	served_quality = quality
	served_dish = plate
	_eat_time_left = eat_duration
	_stay_left = maxf(float(GameData.service.get("regular_stay_seconds", 180)), eat_duration)
	_set_state(State.EATING)


# How much of their meal is left: 1 when it arrives, 0 once it's eaten.
func meal_left() -> float:
	return clampf(_eat_time_left / eat_duration, 0.0, 1.0) if eat_duration > 0.0 else 0.0


# Done eating: they show "..." until someone comes over to chat.
func finish_eating() -> void:
	_set_state(State.DONE_EATING)


# They've asked: waiting for the bill.
func want_bill() -> void:
	_set_state(State.WANTS_BILL)


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


# A regular or semi-regular who's eating and hasn't been chatted with yet this visit.
func can_chat() -> bool:
	var talks := is_regular() or (is_townsfolk() and TownsfolkTalk.has_talk(townsfolk_id))
	return talks and state == State.EATING and not chatted and not _done_eating


# The eating chat: say `line`, and no more chatting this visit.
func chat(line: String) -> void:
	chatted = true
	_update_interactable()
	say(line)


# Walk out along `points` saying `line`, having paid `amount`.
func leave(points: Array[Vector3], line: String, amount: int) -> void:
	reaction_line = line
	payment = amount
	leader = null
	var way := points.duplicate()
	if stand_seconds > 0.0 and seat != null and is_seated():
		var beside := seat.approach_point.global_position
		way.push_front(beside)
		standing_up = true
		_timed_speed = global_position.distance_to(beside) / stand_seconds
	walk_to(way, State.GONE)
	_set_state(State.LEAVING)


func _physics_process(delta: float) -> void:
	if not talking:
		match state:
			State.WAITING_FOR_FOOD:
				wait_seconds += delta
			State.EATING:
				_eat(delta)
	var before := global_position
	if state == State.FOLLOWING:
		_follow_leader(delta)
	else:
		_follow_path(delta)
	_last_step = global_position - before


func _eat(delta: float) -> void:
	_eat_time_left -= delta
	_stay_left -= delta
	if _done_eating or _eat_time_left > 0.0:
		return
	if not is_regular() or chatted or _stay_left <= 0.0:
		_done_eating = true
		_update_interactable()
		finished_eating.emit(self)
	elif not _warned and _stay_left <= float(GameData.service.get("get_going_warning_seconds", 20)):
		_warned = true
		getting_going.emit(self)


# Walk the way the player leading them walked, staying a step behind. They
# cut straight to the furthest bit of the trail they can walk to without
# bumping into anything, and wait if they can't reach any of it yet (the player
# is still behind the host stand).
func _follow_leader(delta: float) -> void:
	if leader == null or not is_instance_valid(leader):
		return
	var here := leader.global_position
	here.y = global_position.y
	if _trail.is_empty() or _trail.back().distance_to(here) >= TRAIL_STEP:
		_trail.append(here)
	if not _skip_ahead():
		var facing := here - global_position
		rotation.y = lerp_angle(rotation.y, atan2(facing.x, facing.z), turn_speed * delta)
		return
	if _blocked(_trail[0] - global_position, delta):
		return
	var left := minf(walk_speed * 1.4 * delta, _trail_length() - FOLLOW_DISTANCE)
	while left > 0.0 and not _trail.is_empty():
		var offset := _trail[0] - global_position
		offset.y = 0.0
		if offset.length() <= left:
			global_position += offset
			left -= offset.length()
			_trail.pop_front()
			continue
		global_position += offset.normalized() * left
		if offset.length() > 0.01:
			rotation.y = lerp_angle(rotation.y, atan2(offset.x, offset.z), turn_speed * delta)
		left = 0.0


# Drop the trail up to the last point they have a clear walk to. False if
# they can't get to any of it.
func _skip_ahead() -> bool:
	for i in range(_trail.size() - 1, -1, -1):
		if _clear_walk_to(_trail[i]):
			_trail = _trail.slice(i)
			return true
	return false


# Nothing in the way (players aside) walking straight to `point`: rays at waist
# height down the middle and either side.
func _clear_walk_to(point: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var along := point - global_position
	along.y = 0.0
	if along.length() < 0.05:
		return true
	var side := along.normalized().cross(Vector3.UP) * BODY_RADIUS
	for shift in [Vector3.ZERO, side, -side]:
		var from: Vector3 = global_position + shift + Vector3.UP * 0.4
		var query := PhysicsRayQueryParameters3D.create(from, from + along)
		var exclude: Array[RID] = []
		for i in 4:
			query.exclude = exclude
			var hit := space.intersect_ray(query)
			if hit.is_empty():
				break
			if not hit["collider"] is Player and not hit["collider"].get_parent() is Customer:
				return false
			exclude.append(hit["rid"])
	return true


# How far they'd walk along the trail to reach the leader.
func _trail_length() -> float:
	var length := 0.0
	var from := global_position
	for point in _trail:
		length += Vector2(point.x - from.x, point.z - from.z).length()
		from = point
	return length


func _follow_path(delta: float) -> void:
	if _path.is_empty():
		return

	var offset := _path[0] - global_position
	if sit_seconds > 0.0 and not sitting_down and _path.size() == 1 and seat != null and _state_after_path == State.WAITING_DRINK_ORDER:
		sitting_down = true
		_timed_speed = offset.length() / sit_seconds
	var step := (_timed_speed if _timed_speed > 0.0 else walk_speed * _pace) * delta
	if _timed_speed <= 0.0 and _blocked(offset, delta):
		return

	if offset.length() <= step:
		global_position = _path[0]
		_path.pop_front()
		_timed_speed = 0.0
		sitting_down = false
		standing_up = false
		if _path.is_empty():
			_on_path_finished()
		return

	global_position += offset.normalized() * step
	if sitting_down:
		rotation.y = lerp_angle(rotation.y, seat.global_rotation.y, turn_speed * delta)
	elif not standing_up and Vector2(offset.x, offset.z).length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(offset.x, offset.z), turn_speed * delta)


# Someone is just ahead going `direction`: a player (not the one they're
# following), or a customer on their feet who isn't coming straight at them
# (two walking head-on just pass; two stuck waiting on each other: one goes).
# In line at the host stand they wait for the customer ahead as long as it
# takes; anywhere else they wait up to MAX_WAIT_SECONDS, then carry on. When
# following a player they only stop for other players (the trail goes where
# the player could walk).
func _blocked(direction: Vector3, delta: float) -> bool:
	direction.y = 0.0
	if direction.length() < 0.01:
		return false
	direction = direction.normalized()
	var by_player := false
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		if node != leader and _is_ahead(node.global_position, direction):
			by_player = true
	_waiting_on_customer = false
	if state != State.FOLLOWING:
		for node in get_tree().get_nodes_in_group(GROUP):
			var other := node as Customer
			if other != self and not other.is_seated() and other.state != State.GONE 					and other._last_step.dot(direction) >= -0.001 and _is_ahead(other.global_position, direction) 					and not (other._waiting_on_customer and get_instance_id() < other.get_instance_id()):
				_waiting_on_customer = true
	if _waiting_on_customer and state in [State.ARRIVING, State.WAITING_TO_BE_SEATED]:
		return true
	if not by_player and not _waiting_on_customer:
		_waited = 0.0
		return false
	_waited += delta
	return _waited < MAX_WAIT_SECONDS


func _is_ahead(point: Vector3, direction: Vector3) -> bool:
	var to := point - global_position
	to.y = 0.0
	return to.length() > 0.05 and to.length() < BLOCK_DISTANCE and to.normalized().dot(direction) > 0.5


func _on_path_finished() -> void:
	_pace = 1.0
	# Once seated, face the same way as the chair (toward the table).
	if _state_after_path == State.WAITING_DRINK_ORDER and seat != null:
		rotation.y = seat.global_rotation.y
	_set_state(_state_after_path)


func _set_state(new_state: State) -> void:
	state = new_state
	_update_body()
	_update_interactable()
	state_changed.emit(self)


# Solid on their feet; not once sat at the table (the chair is solid already).
func _update_body() -> void:
	_body.collision_layer = 0 if is_seated() else 1 << (BODY_LAYER - 1)


# Players can interact with a customer at every step that needs them (the
# prompt says what), or chat once with a regular who is eating.
func _update_interactable() -> void:
	interactable.enabled = state in [State.WAITING_TO_BE_SEATED, State.WAITING_DRINK_ORDER, State.WAITING_FOR_DRINK,
		State.WAITING_FOOD_ORDER, State.WAITING_FOR_FOOD, State.DONE_EATING, State.WANTS_BILL, State.WAITING_BY_DOOR] or can_chat()
