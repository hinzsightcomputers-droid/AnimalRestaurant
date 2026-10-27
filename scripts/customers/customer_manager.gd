# CustomerManager: runs each customer's visit. Spawns them (only if a seat at a
# clean table is free), lines them up at the order counter, seats them once their
# order is taken, handles serving, then has them pay, leave a dirty table, and walk out.
# Customers walk along lanes so they don't cut through furniture: the front lane
# (in line with the door), the back lane (in line with the counter), and straight
# up and down the aisle behind each chair.
class_name CustomerManager
extends Node3D

const CUSTOMER_SCENE := preload("res://scenes/customers/customer.tscn")
const SEAT_GROUP := "seats"

@export var order_counter: Station
@export var order_board: OrderBoard
@export var spawn_point: Marker3D   # Outside the front door.
@export var door_point: Marker3D    # Just inside the front door.
@export var first_arrival_delay := 3.0
@export var arrival_interval := 8.0
@export var queue_spacing := 0.9    # Gap between customers waiting in line.
@export_group("Order chat")
@export var order_chat_seconds := 1.8         # How long the player and customer chat when ordering.
@export var order_chat_zoom: CameraZoomSettings  # The ordering player's camera during the chat.
@export_group("Serving moment")
@export var serve_seconds := 1.5              # How long the server watches the customer start eating.
@export var serve_zoom: CameraZoomSettings    # The serving player's camera during that moment.

var accepting_customers := true     # False after closing time.
var _queue: Array[Customer] = []    # Customers waiting to order, front of the line first.
var _seat_owners: Dictionary = {}   # seat (Station) -> Customer sitting there or walking to it.
var _regulars_today: Array = []     # Ids of regulars who already came in today (one visit a day each).
var _chatting := false              # True while someone is taking an order.


func _ready() -> void:
	order_counter.used.connect(_on_order_counter_used)

	await get_tree().create_timer(first_arrival_delay, false).timeout  # false: waits while paused (e.g. name entry).
	_try_spawn_customer()

	var timer := Timer.new()
	timer.wait_time = arrival_interval
	timer.timeout.connect(_try_spawn_customer)
	add_child(timer)
	timer.start()


# Closing time: no new arrivals, and anyone who hasn't ordered yet heads home.
# Customers who already ordered stay until they're served.
func close() -> void:
	accepting_customers = false
	for customer in _queue:
		_seat_owners.erase(customer.seat)
		var path: Array[Vector3] = [_on_front_lane(customer.global_position), door_point.global_position, spawn_point.global_position]
		customer.leave(path, "Oh, you're closing? Next time!", 0)
	_queue.clear()


func has_customers() -> bool:
	for child in get_children():
		if child is Customer and not child.is_queued_for_deletion():
			return true
	return false


func _try_spawn_customer() -> void:
	if not accepting_customers:
		return
	var seat := _find_free_seat()
	if seat == null:
		return

	var customer: Customer = CUSTOMER_SCENE.instantiate()
	var regular := RegularMemory.pick_visitor(_regulars_today)
	if regular.is_empty():
		customer.setup(GameData.random_species(), GameData.random_dish(), seat)
	else:
		_setup_regular(customer, regular, seat)
	add_child(customer)
	customer.global_position = spawn_point.global_position
	customer.reset_physics_interpolation()

	customer.interactable.interacted.connect(_on_customer_interacted.bind(customer))
	customer.finished_eating.connect(_on_customer_finished_eating)
	customer.state_changed.connect(_on_customer_state_changed)

	_seat_owners[seat] = customer
	_queue.append(customer)
	var path: Array[Vector3] = [door_point.global_position, _on_front_lane(_queue_spot(0)), _queue_spot(_queue.size() - 1)]
	customer.walk_to(path, Customer.State.WAITING_TO_ORDER)
	if customer.is_regular():
		GameEvents.announce("%s the %s walked in." % [customer.display_name, customer.species.get("name", "?")])
	else:
		GameEvents.announce("A %s walked in." % customer.display_name)


# A regular: their own species and name, an order based on their tastes, and
# a greeting picked from what they remember (before this visit changes anything),
# aimed at the chef here they know best.
func _setup_regular(customer: Customer, record: Dictionary, seat: Seat) -> void:
	_regulars_today.append(record["id"])
	var dish := RegularMemory.choose_dish(record)
	customer.setup(GameData.get_species(record["species"]), dish, seat)
	customer.regular_id = record["id"]
	customer.display_name = record["name"]
	customer.greeting_line = DialoguePicker.pick("greeting",
		RegularMemory.dialogue_context(record, RegularMemory.favorite_chef_here(record)))


# What a regular says when ordering, to the chef taking the order.
func _pick_order_line(customer: Customer, chef_id: String) -> String:
	var record: Dictionary = GameState.regulars[customer.regular_id]
	return DialoguePicker.pick("order", RegularMemory.dialogue_context(record, chef_id, {
		"dish": customer.dish.get("name", ""),
		"ordered_favorite": customer.dish.get("id", "") == record["favorite_dish"],
	}))


func _on_order_counter_used(_station: Station, player_index: int) -> void:
	if _chatting:
		return
	if _queue.is_empty():
		GameEvents.announce("Nobody is waiting to order.")
		return

	var customer := _queue[0]
	if customer.state != Customer.State.WAITING_TO_ORDER or customer.is_walking():
		return  # Front customer hasn't reached the counter yet.

	_queue.pop_front()
	if customer.is_regular():
		customer.order_line = _pick_order_line(customer, Accounts.id_of(player_index))
	customer.place_order()
	order_board.add_order(customer)
	GameEvents.announce("%s took an order: %s wants %s." % [
		Accounts.name_of(player_index), customer.display_name, customer.dish.get("name", "?")])
	await _order_chat(player_index, customer)

	var approach := customer.seat.approach_point.global_position
	var path: Array[Vector3] = [
		Vector3(approach.x, 0.0, _queue_spot(0).z),  # Along the back lane...
		approach,                                    # ...down the aisle behind the chair...
		customer.seat.seat_point.global_position,    # ...and sit.
	]
	customer.walk_to(path, Customer.State.WAITING_FOR_FOOD)
	_move_queue_forward()


# A short chat while the customer says their order: the player stays at the
# counter and their camera zooms in on the two of them.
func _order_chat(player_index: int, customer: Customer) -> void:
	var player := Player.find(get_tree(), player_index)
	if player == null:
		return
	_chatting = true
	var between := (player.global_position + customer.global_position) * 0.5 + Vector3.UP * 1.2
	await _hold_with_zoom(player, between, order_chat_zoom, order_chat_seconds, order_counter.interactable)
	_chatting = false


# Keep `player` in place for `seconds` with their camera zoomed in on `point`,
# their presses stuck to `lock_target` so they can't drift to something nearby.
func _hold_with_zoom(player: Player, point: Vector3, settings: CameraZoomSettings, seconds: float, lock_target: Interactable) -> void:
	player.movement_locked = true
	player.interactor.lock_to(lock_target)
	player.request_camera_focus(point, settings)

	await get_tree().create_timer(seconds, false).timeout

	player.movement_locked = false
	player.interactor.unlock()
	player.release_camera_focus()


# A player pressed interact on a seated customer: serve them if holding their dish.
func _on_customer_interacted(player_index: int, customer: Customer) -> void:
	var customer_name := _who(customer)
	var player := Player.find(get_tree(), player_index)
	var plate: CookedDish = null
	if player != null:
		plate = player.held_item as CookedDish

	if plate == null:
		GameEvents.announce("%s is waiting for %s." % [customer_name.capitalize(), customer.dish.get("name", "their food")])
		return
	if plate.order.customer != customer:
		GameEvents.announce("That's not what %s ordered." % customer_name)
		return

	player.set_held_item(null)
	order_board.remove_order(plate.order)
	customer.served_by_account = Accounts.id_of(player_index)
	customer.serve(plate.quality)
	GameEvents.announce("Served %s to %s." % [plate.dish_name(), customer_name])

	# A short zoom on the customer digging in.
	var at_table := (customer.global_position + customer.seat.meal_position()) * 0.5 + Vector3.UP * 0.8
	_hold_with_zoom(player, at_table, serve_zoom, serve_seconds, customer.interactable)


# Done eating: work out how happy they are, take payment, and walk them out.
func _on_customer_finished_eating(customer: Customer) -> void:
	var satisfaction := Satisfaction.calculate(customer.served_quality, customer.wait_seconds)
	var reaction := Satisfaction.reaction_for(satisfaction)
	var amount := Satisfaction.payment_for(customer.dish, reaction)
	var lines: Array = reaction.get("lines", ["Thank you!"])
	var line: String = lines.pick_random()
	if customer.is_regular():
		line = _remember_visit(customer, reaction.get("id", ""))

	GameState.add_money(amount)
	GameState.record_service({
		"species": customer.species.get("id", ""),
		"regular": customer.regular_id,
		"dish": customer.dish.get("id", ""),
		"price": customer.dish.get("price", 0),
		"quality": customer.served_quality,
		"wait_seconds": customer.wait_seconds,
		"satisfaction": satisfaction,
		"reaction": reaction.get("id", ""),
		"payment": amount,
	})

	# They leave their plate behind; the seat isn't reused until the table is cleaned.
	_seat_owners.erase(customer.seat)
	if customer.seat.table != null:
		customer.seat.table.make_dirty(customer.seat.meal_position())

	var approach := customer.seat.approach_point.global_position
	var path: Array[Vector3] = [
		approach,
		_on_front_lane(approach),
		door_point.global_position,
		spawn_point.global_position,
	]
	customer.leave(path, line, amount)
	GameEvents.announce("%s paid $%d (%s, waited %ds)." % [
		_who(customer).capitalize(), amount, reaction.get("id", "?"), roundi(customer.wait_seconds)])


# Update what the regular remembers about this visit and pick their goodbye line.
func _remember_visit(customer: Customer, reaction_id: String) -> String:
	var record: Dictionary = GameState.regulars[customer.regular_id]
	var relationship_before: int = record["relationship"]
	var now := Time.get_datetime_string_from_system(true)
	var server_id := customer.served_by_account
	var learned_name := RegularMemory.record_visit(record, customer.served_quality, reaction_id, now, server_id)

	if record["relationship"] != relationship_before:
		GameEvents.announce("%s's friendship: %d -> %d" % [record["name"], relationship_before, record["relationship"]])
	if learned_name:
		GameEvents.announce("%s learned %s's name!" % [record["name"], Accounts.get_account(server_id).get("name", "your")])

	return DialoguePicker.pick("farewell", RegularMemory.dialogue_context(record, server_id, {
		"reaction": reaction_id,
		"learned_name": learned_name,
		# They've been here before, but this is the first time this chef served them.
		"new_chef_for_them": record["times_visited"] > 1 and record["served_by"].get(server_id, 0) == 1,
	}))


# "Pip" for a regular, "the Rabbit" for anyone else.
func _who(customer: Customer) -> String:
	return customer.display_name if customer.is_regular() else "the %s" % customer.display_name


func _on_customer_state_changed(customer: Customer) -> void:
	if customer.state == Customer.State.GONE:
		customer.queue_free()


# Everyone still in line steps up one spot.
func _move_queue_forward() -> void:
	for i in _queue.size():
		_queue[i].set_destination(_queue_spot(i))


# Position in line: spot 0 is at the counter, later spots line up behind it.
func _queue_spot(index: int) -> Vector3:
	var front: Vector3 = order_counter.get_node("CustomerSpot").global_position
	return front + Vector3(0.0, 0.0, queue_spacing * index)


# The point on the front lane (in line with the door) straight ahead of `point`.
func _on_front_lane(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, door_point.global_position.z)


# A random seat nobody has claimed, at a clean table.
func _find_free_seat() -> Seat:
	var free_seats: Array[Seat] = []
	for node in get_tree().get_nodes_in_group(SEAT_GROUP):
		var seat := node as Seat
		if seat != null and not _seat_owners.has(seat) and seat.is_table_clean():
			free_seats.append(seat)
	return free_seats.pick_random() if not free_seats.is_empty() else null
