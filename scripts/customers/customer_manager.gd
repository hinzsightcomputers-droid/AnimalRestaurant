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
@export var view_manager: ViewManager  # To show dialogue boxes in the right player's view.
@export var first_arrival_delay := 3.0
@export var arrival_interval := 8.0
@export var queue_spacing := 0.9    # Gap between customers waiting in line.
@export_group("Order chat")
@export var order_chat_seconds := 1.8         # How long the player and customer chat when ordering.
@export var order_chat_zoom: CameraZoomSettings  # The ordering player's camera during the chat.
@export_group("Serving moment")
@export var serve_seconds := 1.5              # How long the server watches the customer start eating.
@export var serve_zoom: CameraZoomSettings    # The serving player's camera during that moment.
@export_group("Eating chat")
@export var eating_chat_zoom: CameraZoomSettings  # The chatting player's camera (falls back to order_chat_zoom).

var accepting_customers := true     # False after closing time.
var _queue: Array[Customer] = []    # Customers waiting to order, front of the line first.
var _seat_owners: Dictionary = {}   # seat (Station) -> Customer sitting there or walking to it.
var _regulars_today: Array = []     # Ids of regulars who already came in today (one visit a day each).
var _due_regulars: Array[String] = []  # Regulars whose arrival time came (see send_regular), waiting for a seat.
var _chatting := false              # True while someone is taking an order.


func _ready() -> void:
	order_counter.used.connect(_on_order_counter_used)

	await get_tree().create_timer(first_arrival_delay, false).timeout  # false: waits while paused (e.g. name entry).
	_try_spawn_customer()

	var timer := Timer.new()
	timer.wait_time = arrival_interval * GameState.upgrade_multiplier("arrival_interval")  # Welcome Sign.
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
		if customer.is_regular():
			RegularMemory.end_visit(GameState.regulars[customer.regular_id])
	_queue.clear()


func has_customers() -> bool:
	for child in get_children():
		if child is Customer and not child.is_queued_for_deletion():
			return true
	return false


# A regular walking in or waiting at the counter (the phone stays quiet then).
func regular_arriving() -> bool:
	for child in get_children():
		if child is Customer and child.is_regular() and child.state in [Customer.State.ARRIVING, Customer.State.WAITING_TO_ORDER]:
			return true
	return false


func _try_spawn_customer() -> void:
	if not accepting_customers:
		return
	var seat := _find_free_seat()
	if seat == null:
		return

	var regular := _next_regular()
	if regular.is_empty() and not GameData.regular_settings.get("strangers_walk_in", false):
		return  # Only the regulars come in.

	var customer: Customer = CUSTOMER_SCENE.instantiate()
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


# The DayManager says it's this regular's time to come in (from today's
# schedule). They walk in at the next arrival with a free seat.
func send_regular(regular_id: String) -> void:
	var record: Dictionary = GameState.regulars.get(regular_id, {})
	if record.is_empty() or RegularMemory.visited_today(record):
		return  # Once per real date, even across shifts.
	if accepting_customers and not regular_id in _regulars_today and not regular_id in _due_regulars:
		_due_regulars.append(regular_id)


# Who walks in next: anyone the debug panel queued, then regulars whose time has
# come, or {} for an ordinary customer.
func _next_regular() -> Dictionary:
	if not GameState.forced_visitors.is_empty():
		return GameState.regulars.get(GameState.forced_visitors.pop_front(), {})
	while not _due_regulars.is_empty():
		var record: Dictionary = GameState.regulars.get(_due_regulars.pop_front(), {})
		if not record.is_empty() and RegularMemory.visits_in_person(record):
			return record
	return {}


# A regular: their own species and name, an order based on their tastes, and
# a greeting picked from what they remember (before this visit changes anything),
# aimed at the chef here they know best.
func _setup_regular(customer: Customer, record: Dictionary, seat: Seat) -> void:
	_regulars_today.append(record["id"])
	RegularMemory.begin_visit(record)  # From here, this visit can drop them at most one stage.
	var dish := RegularMemory.choose_dish(record)
	var species := GameData.get_species(record["species"]).duplicate()
	if record.has("color"):
		species["color"] = record["color"]  # Their own tint, e.g. Cheddar's bright orange.
	customer.setup(species, dish, seat)
	customer.regular_id = record["id"]
	customer.display_name = record["name"]
	var eating: Dictionary = GameData.regular_settings.get("eating_seconds", { "min": 60, "max": 90 })
	customer.eat_duration = randf_range(eating["min"], eating["max"])  # Regulars linger over their meal.
	customer.greeting_line = RegularMemory.say(record, "greeting",
		RegularMemory.dialogue_context(record, RegularMemory.favorite_chef_here(record)))


# What a regular's lines can depend on, talking to chef `chef_id` about their order.
func _visit_context(customer: Customer, chef_id: String, extra: Dictionary = {}) -> Dictionary:
	var record: Dictionary = GameState.regulars[customer.regular_id]
	var context := RegularMemory.dialogue_context(record, chef_id, {
		"dish": customer.dish.get("name", ""),
		"ordered_favorite": customer.dish.get("id", "") == record["favorite_dish"],
	})
	context.merge(extra, true)
	return context


# What a regular says when the food arrives, to the chef who brought it.
func _pick_served_line(customer: Customer, chef_id: String) -> String:
	var record: Dictionary = GameState.regulars[customer.regular_id]
	return RegularMemory.say(record, "served", _visit_context(customer, chef_id, {
		"served_quality": customer.served_quality,
		"served_favorite": customer.dish.get("id", "") == record["favorite_dish"],
		"served_disliked": customer.dish.get("id", "") == record["disliked_dish"],
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
	_chatting = true
	var player := Player.find(get_tree(), player_index)
	if customer.is_regular() and player != null:
		await _regular_orders(player, customer)  # May change what they order.
	customer.place_order()
	order_board.add_order(customer)
	GameEvents.announce("%s took an order: %s wants %s." % [
		Accounts.name_of(player_index), customer.display_name, customer.dish.get("name", "?")])
	if not customer.is_regular() and player != null:
		await _order_chat(player, customer)
	_chatting = false

	var approach := customer.seat.approach_point.global_position
	var path: Array[Vector3] = [
		Vector3(approach.x, 0.0, _queue_spot(0).z),  # Along the back lane...
		approach,                                    # ...down the aisle behind the chair...
		customer.seat.seat_point.global_position,    # ...and sit.
	]
	customer.walk_to(path, Customer.State.WAITING_FOR_FOOD)
	_move_queue_forward()


# A short chat while an ordinary customer says their order: the player stays at
# the counter and their camera zooms in on the two of them.
func _order_chat(player: Player, customer: Customer) -> void:
	await _hold_with_zoom(player, _at_counter(player, customer), order_chat_zoom, order_chat_seconds, order_counter.interactable)


# A regular orders, all in one dialogue box: first the greeting they walked in
# with (press interact), then usually the ordering conversation from their file,
# sometimes (once they trust you) "What do you recommend?" or "Surprise me"
# instead, where the player picks the dish. Lines without choices are just said.
func _regular_orders(player: Player, customer: Customer) -> void:
	var record: Dictionary = GameState.regulars[customer.regular_id]
	var chef_id := Accounts.id_of(player.player_index)
	_lock_player(player, _at_counter(player, customer), order_chat_zoom, order_counter.interactable)
	customer.talking = true
	var box := _open_box(player, customer)
	if not customer.greeting_line.is_empty():
		customer.say(customer.greeting_line)
		await box.tell(customer.display_name, customer.greeting_line)

	# The first time they're close enough, they learn this chef's name (Cheddar
	# also picks a nickname). Plays once per chef.
	var name_line := RegularMemory.pick_line(record, "learn_name", _visit_context(customer, chef_id))
	if name_line.has("choices"):
		await _converse(box, player, customer, name_line)
	elif not name_line.is_empty():
		var text := DialoguePicker.fill(name_line["text"], _visit_context(customer, chef_id))
		customer.say(text)
		await box.tell(customer.display_name, text)
		_after_line(customer, name_line, chef_id)

	# The first visit after the restaurant is named (or renamed), they say what they think of the name.
	var context_now := _visit_context(customer, chef_id)
	var restaurant_line := RegularMemory.pick_line(record, "restaurant_name", context_now)
	if not restaurant_line.is_empty():
		var text := DialoguePicker.fill(restaurant_line["text"], context_now)
		customer.say(text)
		await box.tell(customer.display_name, text)
		record["restaurant_name_heard"] = GameState.restaurant_name

	# Picked now, so it can already use the name they just learned.
	var context := _visit_context(customer, chef_id)
	var line := {}
	if GameState.force_pick_for_me or randf() < GameData.regular_settings.get("pick_for_me_chance", 0.35):
		line = RegularMemory.pick_line(record, "pick_for_me", context)
		if not line.is_empty():
			GameState.force_pick_for_me = false
	if line.is_empty():
		line = RegularMemory.pick_line(record, "order", context)
	if line.has("reactions"):
		customer.order_line = await _pick_for_me(box, player, customer, line)
	elif line.has("choices"):
		customer.order_line = await _converse(box, player, customer, line)
	elif not line.is_empty():
		customer.order_line = DialoguePicker.fill(line["text"], context)
		customer.say(customer.order_line)
		await box.tell(customer.display_name, customer.order_line)
	box.close()
	customer.talking = false
	_unlock_player(player)


# Once a line has been said: its memory flags, and whether they learned the chef's name.
func _after_line(customer: Customer, line: Dictionary, chef_id: String) -> void:
	var record: Dictionary = GameState.regulars[customer.regular_id]
	if Conversation.apply_line(record, line, chef_id):
		customer.learned_name = true
		GameEvents.announce("%s learned %s's name!" % [record["name"], Accounts.get_account(chef_id).get("name", "your")])
		var nickname: String = record.get("nicknames", {}).get(chef_id, "")
		if not nickname.is_empty():
			GameEvents.announce("%s calls you \"%s\" now." % [record["name"], nickname])


# A dialogue box for `player` talking with `customer`, in that player's view.
func _open_box(player: Player, customer: Customer) -> ConversationBox:
	return ConversationBox.open(_view_of(player), player.player_index, customer.regular_id)


# Run a conversation `line` (with choices) between `player` and `customer` in
# `box`. Returns what the customer said last. The line, or the chosen reply, can
# decide what they order.
func _converse(box: ConversationBox, player: Player, customer: Customer, line: Dictionary) -> String:
	var record: Dictionary = GameState.regulars[customer.regular_id]
	var chef_id := Accounts.id_of(player.player_index)
	_order_dish(customer, Conversation.dish_of(line, record))
	var context := _visit_context(customer, chef_id)
	var opening := DialoguePicker.fill(line["text"], context)
	customer.say(opening)

	var choices := Conversation.choices_of(line)
	var options := []
	for choice in choices:
		options.append(DialoguePicker.fill(choice["text"], context))
	var picked := await box.ask(customer.display_name, opening, options)

	var before: int = record["relationship"]
	var result := Conversation.apply_choice(record, choices[picked], options[picked], chef_id)
	_after_line(customer, line, chef_id)
	_order_dish(customer, Conversation.dish_of(choices[picked], record))
	context = _visit_context(customer, chef_id)  # The reply can use a nickname just picked.
	_announce_change(record, before, choices[picked].get("tone", ""))

	var reply := DialoguePicker.fill(result["reply"], context)
	if not reply.is_empty():
		customer.say(reply)
		await box.tell(customer.display_name, reply)
	return reply if not reply.is_empty() else opening


# "What do you recommend?" / "Surprise me": the player picks a dish from the
# menu and the regular reacts to it (favorite, disliked, or anything else).
func _pick_for_me(box: ConversationBox, player: Player, customer: Customer, line: Dictionary) -> String:
	var record: Dictionary = GameState.regulars[customer.regular_id]
	var context := _visit_context(customer, Accounts.id_of(player.player_index))
	var question := DialoguePicker.fill(line["text"], context)
	customer.say(question)
	var options := []
	for dish in GameData.dishes:
		options.append(dish["name"])
	var picked := await box.ask(customer.display_name, question, options)

	_order_dish(customer, GameData.dishes[picked])
	context["dish"] = customer.dish.get("name", "")
	var before: int = record["relationship"]
	var result := Conversation.apply_dish_pick(record, line, customer.dish, context)
	_announce_change(record, before, "")
	var reply := DialoguePicker.fill(result["reply"], context)
	if not reply.is_empty():
		customer.say(reply)
		await box.tell(customer.display_name, reply)
	return reply


# Change what the customer orders (ignored if `dish` is {}).
func _order_dish(customer: Customer, dish: Dictionary) -> void:
	if not dish.is_empty():
		customer.dish = dish


func _announce_change(record: Dictionary, before: int, tone: String) -> void:
	var after: int = record["relationship"]
	if after == before and tone.is_empty():
		return  # e.g. telling Stitches your name: nothing to report.
	var how := " (%s)" % tone if not tone.is_empty() else ""
	GameEvents.announce("%s%s: %+d -> %d (%s)" % [record["name"], how, after - before, after, RegularMemory.stage_name(record)])


# Where a dialogue box goes for this player: their own view (or the screen if
# there's no view manager, e.g. in tests).
func _view_of(player: Player) -> Control:
	var view := view_manager.view_for(player.player_index) if view_manager != null else null
	if view != null:
		return view
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(screen)
	screen.child_exiting_tree.connect(func(_box): layer.queue_free())
	return screen


# Keep `player` in place for `seconds` with their camera zoomed in on `point`,
# their presses stuck to `lock_target` so they can't drift to something nearby.
func _hold_with_zoom(player: Player, point: Vector3, settings: CameraZoomSettings, seconds: float, lock_target: Interactable) -> void:
	_lock_player(player, point, settings, lock_target)
	await get_tree().create_timer(seconds, false).timeout
	_unlock_player(player)


func _lock_player(player: Player, point: Vector3, settings: CameraZoomSettings, lock_target: Interactable) -> void:
	player.movement_locked = true
	player.interactor.lock_to(lock_target)
	player.request_camera_focus(point, settings)


func _unlock_player(player: Player) -> void:
	player.ignore_interact_until_released()  # The press that ended it shouldn't start something new.
	player.movement_locked = false
	player.interactor.unlock()
	player.release_camera_focus()


# Between the player at the counter and the customer they're serving.
func _at_counter(player: Player, customer: Customer) -> Vector3:
	return (player.global_position + customer.global_position) * 0.5 + Vector3.UP * 1.2


# A player pressed interact on a seated customer: serve them if holding their
# dish, or chat with a regular who's eating.
func _on_customer_interacted(player_index: int, customer: Customer) -> void:
	var customer_name := _who(customer)
	var player := Player.find(get_tree(), player_index)
	if customer.state == Customer.State.EATING:
		# Not while still held in the serving moment, so one extra press doesn't use up the chat.
		if player != null and player.held_item == null and not player.movement_locked and customer.can_chat():
			_eating_chat(player, customer)
		return
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
	GameState.record_chef_action(player_index, "served")
	customer.serve(plate.quality)
	GameEvents.announce("Served %s to %s." % [plate.dish_name(), customer_name])
	if not customer.is_regular():
		# A short zoom on the customer digging in.
		_hold_with_zoom(player, _at_table(customer), serve_zoom, serve_seconds, customer.interactable)
		return

	# A regular says something about the food in a dialogue box (the meal waits).
	var line := _pick_served_line(customer, customer.served_by_account)
	if line.is_empty():
		_hold_with_zoom(player, _at_table(customer), serve_zoom, serve_seconds, customer.interactable)
		return
	customer.talking = true
	_lock_player(player, _at_table(customer), serve_zoom, customer.interactable)
	customer.say(line)
	var box := _open_box(player, customer)
	await box.tell(customer.display_name, line)
	box.close()
	_unlock_player(player)
	customer.talking = false


# Walking up to a regular mid-meal: they say something fitting how well they
# know you, sometimes with replies to choose from. Once per visit; the player
# stays put and the meal waits while they talk.
func _eating_chat(player: Player, customer: Customer) -> void:
	var record: Dictionary = GameState.regulars[customer.regular_id]
	var context := _visit_context(customer, Accounts.id_of(player.player_index))
	var line := RegularMemory.pick_line(record, "eating_chat", context)
	GameEvents.announce("%s chatted with %s." % [Accounts.name_of(player.player_index), customer.display_name])
	var zoom := eating_chat_zoom if eating_chat_zoom != null else order_chat_zoom
	customer.chat("")  # Uses up the chat; the dialogue box says the lines.
	customer.talking = true
	_lock_player(player, _at_table(customer), zoom, customer.interactable)
	var box := _open_box(player, customer)
	if line.has("choices"):
		await _converse(box, player, customer, line)
	else:
		var text := DialoguePicker.fill(line["text"], context) if not line.is_empty() else "Mm. It's good."
		customer.say(text)
		await box.tell(customer.display_name, text)
	box.close()
	_unlock_player(player)
	customer.talking = false


# Between a seated customer and their plate, a little above the table.
func _at_table(customer: Customer) -> Vector3:
	return (customer.global_position + customer.seat.meal_position()) * 0.5 + Vector3.UP * 0.8


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
	var now := GameClock.now_string()  # The real date, unless the debug panel moved it.
	var server_id := customer.served_by_account
	RegularMemory.record_visit(record, customer.served_quality, reaction_id, now, server_id)
	RegularMemory.end_visit(record)

	if record["relationship"] != relationship_before:
		GameEvents.announce("%s's friendship: %d -> %d (%s)" % [record["name"], relationship_before, record["relationship"], RegularMemory.stage_name(record)])

	return RegularMemory.say(record, "farewell", RegularMemory.dialogue_context(record, server_id, {
		"reaction": reaction_id,
		"learned_name": customer.learned_name,
		# They've been here before, but this is the first time this chef served them.
		"new_chef_for_them": record["times_visited"] > 1 and record["served_by"].get(server_id, 0) == 1,
	}))


# "Mabel" for a regular, "the Frog" for anyone else.
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
