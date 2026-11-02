# CustomerManager: runs each customer's visit. Sends in this meal's customers
# from today's plan (DayPlan) one at a time, while there are seats at clean
# tables for them. Each visit goes step by step, one interaction each:
#   1. They wait at the host stand (the old order counter). A player seats
#      them there (or by talking to them): a regular says their greeting and
#      what's on their mind, and asks for their usual table if they have one.
#   2. They follow that player, who picks a clean table for them (the table's
#      prompt). They sit and get a menu.
#   3. A player takes their drink order, 4. makes it at the DrinkStation and
#      brings it (a regular's favorite drink adds a little friendship).
#   5. A player takes their food order: a regular's ordering conversation, and
#      the ticket goes on the wheel. 6. The food is cooked and served.
#   7. They eat. A regular lingers until someone chats with them (or about
#      three minutes, saying they should get going first).
#   8. They ask for the bill: a player prints it at the host stand and brings
#      it. They pay for the food and drink plus a tip by how happy they are, a
#      regular says goodbye, and they leave a dirty table.
# The lines townsfolk say at each step are in data/service.json; regulars use
# their character files. Once the meal's last customer has gone, the host
# stand's bell (ServiceBell) is rung for the next meal (see DayManager).
# Customers walk along lanes so they don't cut through furniture: the front lane
# (in line with the door), the back lane (in line with the host stand), and
# straight up and down the aisle behind each chair.
# It also runs the Gone side of regulars (see Redemption): writing a letter at
# the host stand when nobody's waiting, asking a friend about someone Gone
# while the friend eats, and the return scene when a Gone regular comes back
# at closing time and waits by the door.
class_name CustomerManager
extends Node3D

const CUSTOMER_SCENE := preload("res://scenes/customers/customer.tscn")
const SEAT_GROUP := "seats"
const POP_OFFSET := Vector3(0.8, 1.5, 0.3)  # Where serving and paying pops float, beside a customer.
const POP_FONT_SIZE := 56
const QUALITY_COLORS: Array[Color] = [Color(1.0, 0.85, 0.3), Color(0.55, 0.95, 0.45), Color(1.0, 0.98, 0.92), Color(0.7, 0.72, 0.78)]  # Perfect, Great, Okay, Burnt.

@export var order_counter: Station  # The host stand.
@export var order_board: OrderBoard
@export var spawn_point: Marker3D   # Outside the front door.
@export var door_point: Marker3D    # Just inside the front door.
@export var view_manager: ViewManager  # To show dialogue boxes in the right player's view.
@export var queue_spacing := 0.9    # Gap between customers waiting in line.
@export_group("Order chat")
@export var order_chat_seconds := 1.8         # How long the player and customer chat at each step.
@export var order_chat_zoom: CameraZoomSettings  # The talking player's camera during the chat.
@export_group("Serving moment")
@export var serve_seconds := 1.5              # How long the server watches the customer start eating.
@export var serve_zoom: CameraZoomSettings    # The serving player's camera during that moment.
@export_group("Eating chat")
@export var eating_chat_zoom: CameraZoomSettings  # The chatting player's camera (falls back to order_chat_zoom).

var day_manager: DayManager         # Set by the DayManager: rings the bell.
var accepting_customers := true     # False after closing time.
var _queue: Array[Customer] = []    # Waiting at the host stand to be seated, front of the line first.
var _leading: Dictionary = {}       # Player index -> the Customer following them to a table.
var _greeting: Dictionary = {}      # Player index -> the Customer they're welcoming at the host stand.
var _busy: Array[Customer] = []     # Customers in the middle of a step (so a second press waits).
var _seat_owners: Dictionary = {}   # seat (Station) -> Customer sitting there or walking to it.
var _pending: Array = []            # This meal's customers still to come: [plan index, entry].
var _writing_letter := false
var _arrival_timer := Timer.new()
var _meal_size := 0       # How many this meal expects (for its pacing).
var _arrived := 0         # How many of them have walked in so far.
var _rush_called := false
var bell := ServiceBell.new()     # On the host stand: rung to start the next meal.


func _ready() -> void:
	order_counter.used.connect(_on_order_counter_used)
	order_counter.interactable.prompt_for_player = _counter_prompt
	order_counter.add_child(bell)
	bell.position = Vector3(-0.85, 1.06, -0.1)  # On the counter top, at the end away from the register.
	bell.scale = Vector3.ONE * 1.8  # Big enough to spot from the usual camera.
	_arrival_timer.timeout.connect(_try_spawn_customer)
	add_child(_arrival_timer)
	for table in _tables():
		table.seating_prompt = _table_prompt
		table.seat_requested.connect(_on_table_seat_requested)


func _process(_delta: float) -> void:
	# Someone leading a customer left the game: the customer goes back in line.
	for player_index in _leading.keys():
		var customer: Customer = _leading[player_index]
		if not is_instance_valid(customer) or customer.state != Customer.State.FOLLOWING:
			_leading.erase(player_index)
		elif Player.find(get_tree(), player_index) == null:
			_leading.erase(player_index)
			customer.stop_following()
			_queue.push_front(customer)
			_move_queue_forward()


# A meal starts: its customers from today's plan come in one at a time, except
# any already done (a day picked up again). `entries` is the meal's list. They
# come at a pace that gives the meal a shape (see _next_gap).
func start_phase(entries: Array, done: Array) -> void:
	_pending.clear()
	for i in entries.size():
		if not i in done:
			_pending.append([i, entries[i]])
	_meal_size = _pending.size()
	_arrived = 0
	_rush_called = false
	accepting_customers = true
	_arrival_timer.one_shot = true
	_arrival_timer.stop()
	await get_tree().create_timer(float(GameData.day_settings.get("first_arrival_seconds", 3.0)), false).timeout  # false: waits while paused (e.g. name entry).
	_try_spawn_customer()


# The time until the next customer walks in, after `_arrived` of the meal's
# `_meal_size` have: a calm start (a gap after the first), then the rush (the
# middle ones close together, called out once), and for a big meal a slower
# last one. The gaps are multiples of arrival_seconds (data/day.json "pacing").
func _next_gap() -> float:
	var settings := GameData.day_settings
	var pacing: Dictionary = settings.get("pacing", {})
	var base := float(settings.get("arrival_seconds", 9.0)) * GameState.upgrade_multiplier("arrival_interval")  # Welcome Sign.
	var still_to_come := _meal_size - _arrived
	if _arrived == 1 and still_to_come >= 2:
		return base * float(pacing.get("calm_start", 1.6))
	if still_to_come == 1 and _meal_size >= int(pacing.get("wind_down_from", 5)):
		return base * float(pacing.get("wind_down", 1.4))
	if still_to_come >= 1 and not _rush_called and _meal_size >= int(pacing.get("rush_from", 3)):
		_rush_called = true
		_call_rush(String(pacing.get("rush_text", "Here comes the {meal} rush!")))
	return base * float(pacing.get("rush", 0.45)) if still_to_come >= 1 else base


# The rush starts: everyone hears about it.
func _call_rush(text: String) -> void:
	GameEvents.announce(text.format({ "meal": DayCycle.phase_name().to_lower() }))
	var ding := AudioStreamPlayer.new()
	ding.stream = CookSounds.get_sound("ding")
	add_child(ding)
	ding.play()
	ding.finished.connect(ding.queue_free)


# Everyone this meal was expecting has been and gone.
func phase_finished() -> bool:
	return _pending.is_empty() and not has_customers()


# How many of this meal's customers haven't left yet (still to come or inside).
func customers_left() -> int:
	var inside := 0
	for child in get_children():
		if child is Customer and not child.is_queued_for_deletion() and child.state != Customer.State.LEAVING:
			inside += 1
	return _pending.size() + inside


# Debug: everyone heads straight home, and nobody else comes this meal.
func send_everyone_home() -> void:
	_pending.clear()
	_arrival_timer.stop()
	_queue.clear()
	_leading.clear()
	_busy.clear()
	for child in get_children():
		if child is Customer and not child.is_queued_for_deletion():
			child.queue_free()
	_seat_owners.clear()


# Closing time: no new arrivals, and anyone not seated yet heads home.
# Customers already at a table stay until they've paid.
func close() -> void:
	accepting_customers = false
	_pending.clear()
	_arrival_timer.stop()
	var unseated: Array[Customer] = _queue.duplicate()
	unseated.append_array(_leading.values())
	_queue.clear()
	_leading.clear()
	for customer in unseated:
		var path: Array[Vector3] = [_on_front_lane(customer.global_position), door_point.global_position, spawn_point.global_position]
		customer.leave(path, "Oh, you're closing? Next time!", 0)
		if customer.is_regular():
			RegularMemory.end_visit(GameState.regulars[customer.regular_id])
	for record in Redemption.returning_today():
		_bring_back(record)


func has_customers() -> bool:
	for child in get_children():
		if child is Customer and not child.is_queued_for_deletion():
			return true
	return false


# A regular walking in or waiting at the host stand (the phone stays quiet then).
func regular_arriving() -> bool:
	for child in get_children():
		if child is Customer and child.is_regular() and child.state in [Customer.State.ARRIVING, Customer.State.WAITING_TO_BE_SEATED]:
			return true
	return false


# Someone comes in if there's a seat at a clean table for them (counting
# everyone already waiting to be seated).
func _try_spawn_customer() -> void:
	if not accepting_customers:
		return
	var retry := float(GameData.day_settings.get("pacing", {}).get("retry_seconds", 2.0))
	if not DayCycle.is_open() or _free_seats().size() <= _queue.size() + _leading.size():
		_arrival_timer.start(retry)  # Nowhere to sit them yet: they wait outside a moment.
		return
	var next := _next_customer()
	if next.is_empty():
		_arrival_timer.start(retry)  # Anyone the debug panel sends still comes.
		return
	if next["index"] >= 0:
		_arrived += 1
	_arrival_timer.start(_next_gap())
	var regular: Dictionary = next["regular"]

	var customer: Customer = CUSTOMER_SCENE.instantiate()
	customer.plan_index = next["index"]
	if regular.is_empty():
		customer.setup(GameData.random_species(), GameData.random_dish(), null)
	else:
		_setup_regular(customer, regular)
	add_child(customer)
	customer.global_position = spawn_point.global_position
	customer.reset_physics_interpolation()

	customer.interactable.interacted.connect(_on_customer_interacted.bind(customer))
	customer.finished_eating.connect(_on_customer_finished_eating)
	customer.getting_going.connect(_on_customer_getting_going)
	customer.state_changed.connect(_on_customer_state_changed)

	_queue.append(customer)
	var path: Array[Vector3] = [door_point.global_position, _on_front_lane(_queue_spot(0)), _queue_spot(_queue.size() - 1)]
	customer.walk_to(path, Customer.State.WAITING_TO_BE_SEATED)
	if customer.is_regular():
		GameEvents.announce("%s the %s walked in." % [customer.display_name, customer.species.get("name", "?")])
	else:
		GameEvents.announce("A %s walked in." % customer.display_name)


# Who walks in next: anyone the debug panel queued (an extra, not from the
# plan), else the meal's next customer: { index, regular } (regular {} for
# townsfolk), or {} when nobody's left to come. A planned regular who can't
# come after all (they've stopped visiting, or already came today) counts as
# done and the next one comes instead.
func _next_customer() -> Dictionary:
	if not GameState.forced_visitors.is_empty():
		return { "index": -1, "regular": GameState.regulars.get(GameState.forced_visitors.pop_front(), {}) }
	while not _pending.is_empty():
		var next: Array = _pending.pop_front()
		var entry: Dictionary = next[1]
		if not entry.has("regular"):
			return { "index": next[0], "regular": {} }
		var record: Dictionary = GameState.regulars.get(entry["regular"], {})
		if not record.is_empty() and RegularMemory.visits_in_person(record) and not RegularMemory.visited_today(record):
			return { "index": next[0], "regular": record }
		GameState.mark_done(next[0])
	return {}


# A regular: their own species and name, an order based on their tastes, and
# a greeting picked from what they remember (before this visit changes anything),
# aimed at the chef here they know best.
func _setup_regular(customer: Customer, record: Dictionary) -> void:
	RegularMemory.begin_visit(record)  # From here, this visit can drop them at most one stage.
	var dish := RegularMemory.choose_dish(record)
	var species := GameData.get_species(record["species"]).duplicate()
	if record.has("color"):
		species["color"] = record["color"]  # Their own tint, e.g. Cheddar's bright orange.
	customer.setup(species, dish, null)
	customer.regular_id = record["id"]
	customer.display_name = _known_name(record)
	var eating: Dictionary = GameData.regular_settings.get("eating_seconds", { "min": 60, "max": 90 })
	customer.eat_duration = randf_range(eating["min"], eating["max"])  # Regulars linger over their meal.
	var context := RegularMemory.dialogue_context(record, RegularMemory.favorite_chef_here(record))
	var greeting := RegularMemory.pick_line(record, "greeting", context)
	customer.greeting_line = DialoguePicker.fill(greeting["text"], context) if not greeting.is_empty() else ""
	customer.greeting_emotion = Conversation.emotion_of(greeting)
	customer.greeting_introduces = greeting.get("introduces", false)


# What to call a regular: their name once they've told you it, else their animal.
func _known_name(record: Dictionary) -> String:
	return record["name"] if record["introduced"] else GameData.get_species(record["species"]).get("name", "Customer")


# What a regular's lines can depend on, talking to chef `chef_id` about their order.
func _visit_context(customer: Customer, chef_id: String, extra: Dictionary = {}) -> Dictionary:
	var record: Dictionary = GameState.regulars[customer.regular_id]
	var context := RegularMemory.dialogue_context(record, chef_id, {
		"dish": customer.dish.get("name", ""),
		"ordered_favorite": customer.dish.get("id", "") == record["favorite_dish"],
		"drink": customer.drink.get("name", ""),
	})
	context.merge(extra, true)
	return context


# What a regular says when the food arrives, to the chef who brought it:
# { text, emotion }. Without an emotion of its own, they feel how it came out.
func _pick_served_line(customer: Customer, chef_id: String) -> Dictionary:
	var record: Dictionary = GameState.regulars[customer.regular_id]
	var line := RegularMemory.say_feeling(record, "served", _visit_context(customer, chef_id, {
		"served_quality": customer.served_quality,
		"served_favorite": customer.dish.get("id", "") == record["favorite_dish"],
		"served_disliked": customer.dish.get("id", "") == record["disliked_dish"],
	}))
	if line["emotion"] == &"":
		var quality := customer.served_quality
		line["emotion"] = &"joyful" if quality >= 0.85 else (&"happy" if quality >= 0.5 else &"sad")
	return line


# One of the townsfolk lines for a step of the visit (data/service.json), with
# {drink} and such filled in.
func _townsfolk_line(step: String, context: Dictionary = {}) -> String:
	var lines: Array = GameData.service.get("townsfolk", {}).get(step, [])
	return String(lines.pick_random()).format(context) if not lines.is_empty() else ""


# --- The host stand ------------------------------------------------------------

# After hours: the catalogue (the summary screen's shop, friends and summary),
# or opening up once it's a new day. Once the meal's over, ringing the bell for
# the next one. Otherwise, for free
# hands: "Print the bill" when someone's asked for one that nobody's carrying
# yet, "Seat Mabel" for whoever's first in line, or "Write a letter" when
# nobody's waiting and someone Gone could get one.
func _counter_prompt(player_index: int) -> String:
	if DayCycle.is_after_hours():
		return "Open up for a new day" if DayCycle.is_new_day_waiting() else "Host stand: shop, summary"
	if day_manager != null and day_manager.bell_ready():
		return day_manager.bell_prompt()
	var player := Player.find(get_tree(), player_index)
	if player == null or player.held_item != null or _writing_letter:
		return ""
	if bills_to_print() > 0:
		return "Print the bill"
	var next := next_to_seat()
	if next != null:
		return "Seat %s" % next.display_name if not _leading.has(player_index) and not _greeting.has(player_index) else ""
	if not Redemption.letter_targets().is_empty():
		return "Write a letter"
	return ""


# The customer following this player to a table, or null.
func leading(player_index: int) -> Customer:
	return _leading.get(player_index)


# The customer this player is welcoming at the host stand, or null.
func greeting(player_index: int) -> Customer:
	return _greeting.get(player_index)


# First in line, standing at the host stand (not still walking up), or null.
func next_to_seat() -> Customer:
	for customer in _queue:
		if customer.state == Customer.State.WAITING_TO_BE_SEATED and not customer.is_walking() and not customer in _busy:
			return customer
	return null


# Customers waiting for a bill that nobody has printed for them yet.
func bills_to_print() -> int:
	var wanted := 0
	for child in get_children():
		if child is Customer and child.state == Customer.State.WANTS_BILL:
			wanted += 1
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		if node is Player and node.held_item is Receipt:
			wanted -= 1
	return wanted


func _on_order_counter_used(_station: Station, player_index: int) -> void:
	if _writing_letter:
		return
	if DayCycle.is_after_hours() and day_manager != null:
		if not day_manager.start_next_day():
			day_manager.open_summary()
		return
	if day_manager != null and day_manager.bell_ready():
		if day_manager.ring_bell():
			bell.ring()
		return
	var player := Player.find(get_tree(), player_index)
	if player == null or player.held_item != null:
		return
	if bills_to_print() > 0:
		player.set_held_item(Receipt.new())
		GameEvents.announce("%s printed the bill." % Accounts.name_of(player_index))
		return
	var next := next_to_seat()
	if next != null:
		_greet(player, next, order_counter.interactable)
		return
	if not Redemption.letter_targets().is_empty():
		_writing_letter = true
		await _write_letter(player)
		_writing_letter = false
		return
	GameEvents.announce("Nobody is waiting to be seated.")


# Step 1: `player` welcomes `customer` at the host stand (a regular says their
# greeting and so on in a dialogue box), then they follow the player to a table.
func _greet(player: Player, customer: Customer, lock_target: Interactable) -> void:
	if _greeting.has(player.player_index):
		return  # One at a time: still welcoming someone (an extra press at the host stand).
	if _leading.has(player.player_index):
		GameEvents.announce("Seat %s first!" % _who(_leading[player.player_index]))
		return
	_greeting[player.player_index] = customer
	_busy.append(customer)
	var seating := {}
	if customer.is_regular():
		seating = await _regular_greets(player, customer, lock_target)
	else:
		customer.say(_townsfolk_line("host_stand"))
		await _hold_with_zoom(player, _at_counter(player, customer), order_chat_zoom, order_chat_seconds, lock_target)
	_busy.erase(customer)
	_greeting.erase(player.player_index)
	if not is_instance_valid(customer) or customer.state != Customer.State.WAITING_TO_BE_SEATED:
		return  # Sent home meanwhile (closing, or the debug panel).
	_queue.erase(customer)
	if seating.get("seats_self", false) and _seat_self(customer, float(seating.get("walk_speed", 1.0))):
		_move_queue_forward()
		return
	_leading[player.player_index] = customer
	customer.follow(player)
	_move_queue_forward()
	GameEvents.announce("Lead %s to a clean table." % _who(customer))


# A regular at the host stand, all in one dialogue box: first the greeting they
# walked in with, then (the first time) learning this chef's name, what they
# think of the restaurant's name, anything they've heard about you from a
# friend (gossip, once), and which table they'd like (their "seating" line,
# which it returns: it can name a "table" spot, or say they "seats_self").
func _regular_greets(player: Player, customer: Customer, lock_target: Interactable) -> Dictionary:
	var record: Dictionary = GameState.regulars[customer.regular_id]
	var chef_id := Accounts.id_of(player.player_index)
	_lock_player(player, _at_counter(player, customer), order_chat_zoom, lock_target)
	customer.talking = true
	var box := _open_box(player, customer)
	var arrival := RegularMemory.say(record, "arrival", _visit_context(customer, chef_id))  # e.g. Mabel rings her bell.
	if not arrival.is_empty():
		await box.tell("", arrival)
	if not customer.greeting_line.is_empty():
		await _say(box, customer, customer.greeting_line, customer.greeting_emotion)
	if customer.greeting_introduces and not record["introduced"]:
		record["introduced"] = true
		customer.display_name = record["name"]
		GameEvents.announce("You met %s!" % record["name"])

	# The first time they're close enough, they learn this chef's name (Cheddar
	# also picks a nickname). Plays once per chef.
	var name_line := RegularMemory.pick_line(record, "learn_name", _visit_context(customer, chef_id))
	if name_line.has("choices"):
		await _converse(box, player, customer, name_line)
	elif not name_line.is_empty():
		var text := DialoguePicker.fill(name_line["text"], _visit_context(customer, chef_id))
		await _say(box, customer, text, Conversation.emotion_of(name_line))
		_after_line(customer, name_line, chef_id)

	# The first visit after the restaurant is named (or renamed), they say what they think of the name.
	var context_now := _visit_context(customer, chef_id)
	var restaurant_line := RegularMemory.pick_line(record, "restaurant_name", context_now)
	if not restaurant_line.is_empty():
		var text := DialoguePicker.fill(restaurant_line["text"], context_now)
		await _say(box, customer, text, Conversation.emotion_of(restaurant_line))
		record["restaurant_name_heard"] = GameState.restaurant_name

	# Something a friend told them about you since last time.
	var gossip := Gossip.take_next(record)
	if not gossip.is_empty():
		var gossip_context := Gossip.context(gossip)
		var gossip_line := RegularMemory.pick_line(record, "gossip", _visit_context(customer, chef_id, gossip_context))
		if gossip_line.has("choices"):
			await _converse(box, player, customer, gossip_line, gossip_context)
		elif not gossip_line.is_empty():
			var text := DialoguePicker.fill(gossip_line["text"], _visit_context(customer, chef_id, gossip_context))
			await _say(box, customer, text, Conversation.emotion_of(gossip_line))

	# Where they'd like to sit (e.g. Stitches and the corner table).
	var seating := RegularMemory.pick_line(record, "seating", _visit_context(customer, chef_id))
	customer.wanted_table = seating.get("table", record.get("usual_table", ""))
	customer.seat_note = DialoguePicker.fill(seating.get("on_sit", ""), _visit_context(customer, chef_id))
	await _say_line(box, customer, seating, _visit_context(customer, chef_id))
	box.close()
	customer.talking = false
	_unlock_player(player)
	return seating


# --- Seating -------------------------------------------------------------------

# Every table with chairs.
func _tables() -> Array[DiningTable]:
	var tables: Array[DiningTable] = []
	for node in get_tree().get_nodes_in_group(SEAT_GROUP):
		var seat := node as Seat
		if seat != null and seat.table != null and not seat.table in tables:
			tables.append(seat.table)
	return tables


# A table's prompt for a player leading someone: "Seat Mabel here" if it's
# clean with a free chair, else "" (and the table offers its own chores).
func _table_prompt(player_index: int, table: DiningTable) -> String:
	var customer: Customer = _leading.get(player_index)
	if customer == null or not table.is_clean() or _free_seat_at(table) == null:
		return ""
	return "Seat %s here" % customer.display_name


# Step 2: the leading player picked `table`: the customer sits there. A regular
# who wanted that spot is pleased; townsfolk say something about it.
func _on_table_seat_requested(table: DiningTable, player_index: int) -> void:
	var customer: Customer = _leading.get(player_index)
	var seat := _free_seat_at(table)
	if customer == null or seat == null:
		return
	_leading.erase(player_index)
	_seat_owners[seat] = customer
	customer.sit_at(seat)
	_on_seated(customer, table)


# A regular whose seating line "seats_self" walks to a table on their own: the
# one they asked for if it's free, else any free one. False if there's none
# (then they're led as usual).
func _seat_self(customer: Customer, speed_factor: float) -> bool:
	var seats := _free_seats()
	if seats.is_empty():
		return false
	var wanted := seats.filter(func(s): return s.table != null and s.table.spot == customer.wanted_table)
	var seat: Seat = wanted[0] if not wanted.is_empty() else seats.pick_random()
	_seat_owners[seat] = customer
	var approach := seat.approach_point.global_position
	var path: Array[Vector3] = [
		Vector3(approach.x, 0.0, _queue_spot(0).z),  # Along the back lane...
		approach,                                    # ...down the aisle behind the chair...
		seat.seat_point.global_position,             # ...and sit.
	]
	customer.seat_self(seat, path, speed_factor)
	_on_seated(customer, seat.table)
	return true


# Someone is on their way to a chair at `table`. A regular remembers it (for
# lines like Stitches trying a middle table), is pleased if it's the one they
# wanted, and may do something as they sit; townsfolk say something about it.
func _on_seated(customer: Customer, table: DiningTable) -> void:
	if customer.is_regular():
		var record: Dictionary = GameState.regulars[customer.regular_id]
		record["last_table"] = table.spot
		if not customer.wanted_table.is_empty() and customer.wanted_table == table.spot:
			customer.emote(&"happy")
			GameEvents.announce("%s got the %s table." % [customer.display_name, table.spot])
		if not customer.seat_note.is_empty():
			GameEvents.announce(customer.seat_note)
	else:
		customer.say(_townsfolk_line("seated"))
	GameEvents.announce("%s sat down. Take their drink order!" % _who(customer).capitalize())


# A free chair at `table`, or null.
func _free_seat_at(table: DiningTable) -> Seat:
	for seat in _free_seats():
		if seat.table == table:
			return seat
	return null


# --- Drinks --------------------------------------------------------------------

# Step 3: they say what they'd like to drink, in a dialogue box. A regular
# uses their "drink_order" lines; townsfolk a line from data/service.json.
func _take_drink_order(player: Player, customer: Customer) -> void:
	_busy.append(customer)
	var drink := _choose_drink(customer)
	if customer.is_regular():
		drink = await _regular_orders_drink(player, customer, drink)
	else:
		await _talk(player, customer, _townsfolk_line("drink_order", { "drink": drink.get("name", "drink") }), &"")
	_busy.erase(customer)
	if not is_instance_valid(customer) or customer.state != Customer.State.WAITING_DRINK_ORDER:
		return  # Sent home meanwhile.
	customer.order_drink(drink)
	if customer.drink_secret:
		GameEvents.announce("%s would like the usual." % _who(customer).capitalize())
	else:
		GameEvents.announce("%s would like %s." % [_who(customer).capitalize(), _a(drink.get("name", "a drink"))])


# A regular's drink order, in a dialogue box: one of their "drink_order" lines.
# `rolled` is what they'd usually have today (see _choose_drink): lines marked
# "wants_favorite" go with it if there are any. A line's "drink" says what they
# order (see _line_drink); "pick" has the chef choose from the drinks menu.
# Returns the drink they ordered.
func _regular_orders_drink(player: Player, customer: Customer, rolled: Dictionary) -> Dictionary:
	var record: Dictionary = GameState.regulars[customer.regular_id]
	var context := _visit_context(customer, Accounts.id_of(player.player_index), {
		"wants_favorite": rolled.get("id", "") == _favorite_drink_of(record),
	})
	var line := RegularMemory.pick_line(record, "drink_order", context)
	if line.is_empty():
		context["wants_favorite"] = not context["wants_favorite"]
		line = RegularMemory.pick_line(record, "drink_order", context)
	if line.is_empty():
		return rolled
	var drink := rolled
	_lock_player(player, _at_table(customer), order_chat_zoom, customer.interactable)
	customer.talking = true
	var box := _open_box(player, customer)
	if line.get("drink", "") == "pick":  # "Surprise me!": the chef picks.
		var question := DialoguePicker.fill(line["text"], context)
		customer.say(question)
		customer.emote(Conversation.emotion_of(line))
		var menu := GameData.drink_menu()
		drink = menu[await box.ask(customer.display_name, question, menu.map(func(d): return d["name"]), Conversation.emotion_of(line))]
	else:
		drink = _line_drink(line.get("drink", ""), record, rolled)
		context["drink"] = drink.get("name", "")
		await _say_line(box, customer, line, context)
	customer.drink_secret = line.get("secret", false)
	customer.surprise_meal = line.get("surprise_meal", false)
	box.close()
	customer.talking = false
	_unlock_player(player)
	return drink


# What a drink_order line's "drink" means for this regular:
#   "" (none): `rolled`, what they'd usually have today.
#   "favorite": their favorite_drink, or favorite_drink_fallback until it's unlocked.
#   "other": anything else unlocked (not water).
#   "bold_soda": an unlocked soda tagged "bold", else any unlocked soda.
#   a drink id: that drink, or their favorite if it isn't unlocked.
func _line_drink(ref: String, record: Dictionary, rolled: Dictionary) -> Dictionary:
	match ref:
		"":
			return rolled
		"favorite":
			var favorite := _favorite_drink_of(record)
			return GameData.get_drink(favorite) if not favorite.is_empty() else rolled
		"other":
			var others := GameData.drink_menu().filter(func(d): return d["id"] != _favorite_drink_of(record) and d["id"] != "water")
			return others.pick_random() if not others.is_empty() else rolled
		"bold_soda":
			var sodas := GameData.drink_menu().filter(func(d): return d.get("type", "") == "soda")
			var bold := sodas.filter(func(d): return "bold" in d.get("tags", []))
			if not bold.is_empty():
				return bold.pick_random()
			return sodas.pick_random() if not sodas.is_empty() else rolled
	return GameData.get_drink(ref) if GameData.is_unlocked(ref) else _line_drink("favorite", record, rolled)


# A regular's favorite drink id if it's on the menu, else what they have until
# it is (favorite_drink_fallback, e.g. Cheddar's Koala-Cola), else "".
func _favorite_drink_of(record: Dictionary) -> String:
	for id in [record.get("favorite_drink", ""), record.get("favorite_drink_fallback", "")]:
		if not id.is_empty() and GameData.is_unlocked(id):
			return id
	return ""


# What they'll drink: a regular has their favorite most of the time, else
# something else they can have; townsfolk anything unlocked.
func _choose_drink(customer: Customer) -> Dictionary:
	if not customer.is_regular():
		return GameData.random_drink()
	var favorite := _favorite_drink_of(GameState.regulars[customer.regular_id])
	if not favorite.is_empty() and randf() < float(GameData.drink_settings.get("regular_favorite_chance", 0.7)):
		return GameData.get_drink(favorite)
	var others := GameData.drink_menu().filter(func(d): return d["id"] != favorite and d["id"] != "water")
	return others.pick_random() if not others.is_empty() else GameData.get_drink("water")


# Step 4: `player` brings them `item`. The one they ordered pleases them; a
# regular's favorite adds a little friendship (favorite_relationship_bonus in
# data/drink_kitchen.json). Any drink is accepted.
func _give_drink(player: Player, customer: Customer, item: Drink) -> void:
	_busy.append(customer)
	player.set_held_item(null)
	customer.serve_drink(item.drink, item.quality)
	var right := customer.got_the_drink_they_ordered()
	GameEvents.announce("%s brought %s %s." % [Accounts.name_of(player.player_index), _who(customer), _a(item.display_name())])
	if customer.is_regular():
		var record: Dictionary = GameState.regulars[customer.regular_id]
		var favorite: bool = item.id() == record.get("favorite_drink", "")
		if favorite:
			var before: int = record["relationship"]
			RegularMemory.change_relationship(record, int(GameData.drink_settings.get("favorite_relationship_bonus", 1)))
			_announce_change(record, before, "favorite drink")
		var context := _visit_context(customer, Accounts.id_of(player.player_index), {
			"drink": item.display_name(),
			"right_drink": right,
			"served_favorite_drink": favorite,
			"served_drink": item.id(),
			"served_drink_type": item.drink.get("type", ""),
		})
		var line := RegularMemory.pick_line(record, "drink_served", context)
		if not line.is_empty():
			customer.talking = true
			_lock_player(player, _at_table(customer), order_chat_zoom, customer.interactable)
			var box := _open_box(player, customer)
			await _say_line(box, customer, line, context)
			box.close()
			_unlock_player(player)
			customer.talking = false
		if Conversation.emotion_of(line) == &"":
			customer.emote(&"happy" if right else &"neutral")
	else:
		customer.say(_townsfolk_line("drink_served" if right else "wrong_drink"))
		customer.emote(&"happy" if right else &"neutral")
	_busy.erase(customer)


# "a Coffee", "an Apple Cider".
func _a(thing: String) -> String:
	return ("an %s" if thing.left(1).to_lower() in ["a", "e", "i", "o", "u"] else "a %s") % thing


# `customer` says one line to `player` in a dialogue box, with the player held
# at the table (camera zoomed by `zoom`, or order_chat_zoom) and the meal's
# timers paused. Nothing for an empty line.
func _talk(player: Player, customer: Customer, text: String, emotion: StringName, zoom: CameraZoomSettings = null) -> void:
	if text.is_empty():
		return
	customer.talking = true
	_lock_player(player, _at_table(customer), zoom if zoom != null else order_chat_zoom, customer.interactable)
	var box := _open_box(player, customer)
	await _say(box, customer, text, emotion)
	box.close()
	_unlock_player(player)
	customer.talking = false


# --- Food ----------------------------------------------------------------------

# Step 5: the food order, at the table. A regular has their ordering
# conversation; townsfolk say what they want. The ticket goes in the player's
# pocket for the TicketWheel.
func _take_food_order(player: Player, customer: Customer) -> void:
	if TicketWheel.is_full(get_tree()):
		GameEvents.announce("The ticket wheel is full! Finish an order first.")
		return
	_busy.append(customer)
	if customer.is_regular():
		await _regular_orders(player, customer)  # May change what they order.
	customer.place_order()
	var order := order_board.add_order(customer)
	GameEvents.announce("%s took an order: %s wants %s." % [
		Accounts.name_of(player.player_index), customer.display_name, customer.dish.get("name", "?")])
	if not customer.is_regular():
		await _talk(player, customer, _townsfolk_line("food_order", { "dish": customer.dish.get("name", "special") }), &"")
	await TicketPopup.write(view_manager, player, order)
	_busy.erase(customer)


# A regular orders, in a dialogue box: usually the ordering conversation from
# their file, sometimes (once they trust you) "What do you recommend?" or
# "Surprise me" instead, where the player picks the dish. Lines without
# choices are just said.
func _regular_orders(player: Player, customer: Customer) -> void:
	var record: Dictionary = GameState.regulars[customer.regular_id]
	var chef_id := Accounts.id_of(player.player_index)
	_lock_player(player, _at_table(customer), order_chat_zoom, customer.interactable)
	customer.talking = true
	var box := _open_box(player, customer)
	var context := _visit_context(customer, chef_id)
	var line := {}
	if customer.surprise_meal or GameState.force_pick_for_me or randf() < GameData.regular_settings.get("pick_for_me_chance", 0.35):
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
		await _say(box, customer, customer.order_line, Conversation.emotion_of(line))
	box.close()
	customer.talking = false
	_unlock_player(player)


# Once a line has been said: its memory flags, whether they learned the chef's
# name, and whether it made two regulars friends.
func _after_line(customer: Customer, line: Dictionary, chef_id: String) -> void:
	var record: Dictionary = GameState.regulars[customer.regular_id]
	if line.has("hides") and GameState.hidden_secret.is_empty() and customer.seat != null:
		# "I hid something in this restaurant": it's in their chair, to be found (Seat).
		GameState.hidden_secret = { "item": line["hides"], "seat": String(customer.seat.name), "by": record["id"], "found": false }
	if line.has("befriends") and Gossip.befriend(record["id"], line["befriends"]):
		GameEvents.announce("%s and %s are friends now!" % [record["name"], GameState.regulars[line["befriends"]]["name"]])
	if Conversation.apply_line(record, line, chef_id):
		customer.learned_name = true
		GameEvents.announce("%s learned %s's name!" % [record["name"], Accounts.get_account(chef_id).get("name", "your")])
		var nickname: String = record.get("nicknames", {}).get(chef_id, "")
		if not nickname.is_empty():
			GameEvents.announce("%s calls you \"%s\" now." % [record["name"], nickname])


# A dialogue box for `player` talking with `customer`, in that player's view.
func _open_box(player: Player, customer: Customer) -> ConversationBox:
	return ConversationBox.open(_view_of(player), player.player_index, customer.regular_id)


# `customer` says `text` in `box` feeling `emotion` (it shows over their
# head and colors their voice; &"" for nothing in particular).
func _say(box: ConversationBox, customer: Customer, text: String, emotion: StringName = &"") -> void:
	customer.say(text)
	customer.emote(emotion)
	await box.tell(customer.display_name, text, emotion)


# Say a whole `line` in `box`: its "before" beats, its text, then its "after"
# beats. A beat is { "text", "emotion" } said by them, or { "narration" } told
# without a speaker (e.g. "He slurps the pearls loudly on purpose.").
func _say_line(box: ConversationBox, customer: Customer, line: Dictionary, context: Dictionary) -> void:
	for beat in line.get("before", []):
		await _say_beat(box, customer, beat, context)
	if not String(line.get("text", "")).is_empty():
		await _say(box, customer, DialoguePicker.fill(line["text"], context), Conversation.emotion_of(line))
	for beat in line.get("after", []):
		await _say_beat(box, customer, beat, context)


func _say_beat(box: ConversationBox, customer: Customer, beat: Dictionary, context: Dictionary) -> void:
	if beat.has("narration"):
		await box.tell("", DialoguePicker.fill(beat["narration"], context))
	else:
		await _say(box, customer, DialoguePicker.fill(beat.get("text", ""), context), StringName(beat.get("emotion", "")))


# Run a conversation `line` (with choices) between `player` and `customer` in
# `box`. Returns what the customer said last. The line, or the chosen reply, can
# decide what they order, or change how other regulars feel (gossip). `extra`
# adds to what the line can mention (e.g. the gossip's quote).
func _converse(box: ConversationBox, player: Player, customer: Customer, line: Dictionary, extra: Dictionary = {}) -> String:
	var record: Dictionary = GameState.regulars[customer.regular_id]
	var chef_id := Accounts.id_of(player.player_index)
	_order_dish(customer, Conversation.dish_of(line, record))
	var context := _visit_context(customer, chef_id, extra)
	var opening := DialoguePicker.fill(line["text"], context)
	customer.say(opening)
	customer.emote(Conversation.emotion_of(line))

	var choices := Conversation.choices_of(line)
	var options := []
	for choice in choices:
		options.append(DialoguePicker.fill(choice["text"], context))
	var picked := await box.ask(customer.display_name, opening, options, Conversation.emotion_of(line))

	var before: int = record["relationship"]
	var others_before := {}
	for other_id in choices[picked].get("others", {}):
		others_before[other_id] = GameState.regulars.get(other_id, {}).get("relationship", 0)
	var result := Conversation.apply_choice(record, choices[picked], options[picked], chef_id)
	_after_line(customer, line, chef_id)
	_order_dish(customer, Conversation.dish_of(choices[picked], record))
	context = _visit_context(customer, chef_id, extra)  # The reply can use a nickname just picked.
	_announce_change(record, before, choices[picked].get("tone", ""))
	for other_id in result["others"]:  # e.g. Mabel passes your apology on to Stitches.
		_announce_change(GameState.regulars[other_id], others_before[other_id], "")

	var reply := DialoguePicker.fill(result["reply"], context)
	if not reply.is_empty():
		await _say(box, customer, reply, result["emotion"])
	if choices[picked].has("then"):  # e.g. "Knock knock." -> "...Who's there?" and you finish the joke.
		return await _converse(box, player, customer, choices[picked]["then"], extra)
	return reply if not reply.is_empty() else opening


# "What do you recommend?" / "Surprise me": the player picks a dish from the
# menu and the regular reacts to it (favorite, disliked, or anything else).
func _pick_for_me(box: ConversationBox, player: Player, customer: Customer, line: Dictionary) -> String:
	var record: Dictionary = GameState.regulars[customer.regular_id]
	var context := _visit_context(customer, Accounts.id_of(player.player_index))
	var question := DialoguePicker.fill(line["text"], context)
	customer.say(question)
	customer.emote(Conversation.emotion_of(line))
	var menu := GameData.menu()
	var picked := await box.ask(customer.display_name, question, menu.map(func(d): return d["name"]), Conversation.emotion_of(line))

	_order_dish(customer, menu[picked])
	context["dish"] = customer.dish.get("name", "")
	var before: int = record["relationship"]
	var result := Conversation.apply_dish_pick(record, line, customer.dish, context)
	_announce_change(record, before, "")
	var reply := DialoguePicker.fill(result["reply"], context)
	if not reply.is_empty():
		await _say(box, customer, reply, result["emotion"])
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
	return ConversationBox.parent_for(view_manager, player.player_index, self)


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

# Between the player at the host stand and the customer they're greeting.
func _at_counter(player: Player, customer: Customer) -> Vector3:
	return (player.global_position + customer.global_position) * 0.5 + Vector3.UP * 1.2


# A player pressed interact on a customer: whatever their step needs (see the
# top of this file), or what they're waiting for if the player has nothing for them.
func _on_customer_interacted(player_index: int, customer: Customer) -> void:
	var player := Player.find(get_tree(), player_index)
	# Not while still held in a moment, so one extra press doesn't use up the next step.
	if player == null or player.movement_locked or customer in _busy:
		return
	var held := player.held_item
	match customer.state:
		Customer.State.WAITING_TO_BE_SEATED:
			if held == null and not customer.is_walking():
				_greet(player, customer, customer.interactable)
		Customer.State.WAITING_DRINK_ORDER:
			if held == null:
				_take_drink_order(player, customer)
		Customer.State.WAITING_FOR_DRINK:
			if held is Drink:
				_give_drink(player, customer, held)
			else:
				var wanted := "the usual" if customer.drink_secret else _a(customer.drink.get("name", "a drink"))
				GameEvents.announce("%s is waiting for %s. Make it at the drinks counter." % [_who(customer).capitalize(), wanted])
		Customer.State.WAITING_FOOD_ORDER:
			if held == null:
				_take_food_order(player, customer)
		Customer.State.WAITING_FOR_FOOD:
			_serve(player, customer)
		Customer.State.EATING:
			if held == null and customer.can_chat():
				_eating_chat(player, customer)
		Customer.State.WANTS_BILL:
			if held is Receipt:
				_settle_bill(player, customer)
			else:
				GameEvents.announce("%s would like the bill. Print it at the host stand." % _who(customer).capitalize())
		Customer.State.WAITING_BY_DOOR:
			if held == null:
				_return_scene(player, customer)


# Step 6: serve them the plate the player's holding, if it's theirs.
func _serve(player: Player, customer: Customer) -> void:
	var customer_name := _who(customer)
	var plate := player.held_item as CookedDish
	if plate == null:
		GameEvents.announce("%s is waiting for %s." % [customer_name.capitalize(), customer.dish.get("name", "their food")])
		return
	if plate.order.customer != customer:
		GameEvents.announce("That's not what %s ordered." % customer_name)
		return

	player.set_held_item(null)
	order_board.remove_order(plate.order)
	customer.served_by_account = Accounts.id_of(player.player_index)
	GameState.record_chef_action(player.player_index, "served")
	customer.serve(plate.quality, plate)
	GameEvents.announce("Served %s to %s." % [plate.dish_name(), customer_name])
	_pop_serve(customer)
	if not customer.is_regular():
		var quality := customer.served_quality
		var tier := "served_" + CookingMinigame.quality_label(quality).to_lower()  # How it looks to them.
		var said := _townsfolk_line(tier if GameData.service.get("townsfolk", {}).has(tier) else "served", { "dish": plate.dish_name() })
		await _talk(player, customer, said,
			&"joyful" if quality >= 0.85 else (&"happy" if quality >= 0.5 else &"sad"), serve_zoom)
		return

	# A regular says something about the food in a dialogue box (the meal waits).
	var line := _pick_served_line(customer, customer.served_by_account)
	if String(line["text"]).is_empty():
		_hold_with_zoom(player, _at_table(customer), serve_zoom, serve_seconds, customer.interactable)
		return
	customer.talking = true
	_lock_player(player, _at_table(customer), serve_zoom, customer.interactable)
	var box := _open_box(player, customer)
	await _say(box, customer, line["text"], line["emotion"])
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
	elif line.has("asks_dish"):
		await _ask_dish(box, customer, line, context)
		_after_line(customer, line, Accounts.id_of(player.player_index))
	else:
		var text := DialoguePicker.fill(line["text"], context) if not line.is_empty() else "Mm. It's good."
		await _say(box, customer, text, Conversation.emotion_of(line))
		if not line.is_empty():
			_after_line(customer, line, Accounts.id_of(player.player_index))
	await _ask_about_gone(box, player, customer)
	box.close()
	_unlock_player(player)
	customer.talking = false


# A line that asks the chef to pick a dish from the menu ("What's YOUR
# favorite food?"): the dish id goes in the memory field its "asks_dish" names,
# then they say its "reply".
func _ask_dish(box: ConversationBox, customer: Customer, line: Dictionary, context: Dictionary) -> void:
	var record: Dictionary = GameState.regulars[customer.regular_id]
	var question := DialoguePicker.fill(line["text"], context)
	customer.say(question)
	customer.emote(Conversation.emotion_of(line))
	var menu := GameData.menu()
	var picked := await box.ask(customer.display_name, question, menu.map(func(d): return d["name"]), Conversation.emotion_of(line))
	record[line["asks_dish"]] = menu[picked]["id"]
	var reply := DialoguePicker.fill(line.get("reply", ""), RegularMemory.dialogue_context(record, Accounts.id_of(box.player_index)))
	if not reply.is_empty():
		await _say(box, customer, reply, StringName(line.get("reply_emotion", "")))


# --- Gone regulars (see Redemption) ------------------------------------------

# After an eating chat: if this regular is friends with someone Gone and likes
# you enough, you can ask them to talk to that friend.
func _ask_about_gone(box: ConversationBox, player: Player, customer: Customer) -> void:
	var record: Dictionary = GameState.regulars[customer.regular_id]
	var chef_id := Accounts.id_of(player.player_index)
	for gone_id in Redemption.friend_can_help(record, chef_id):
		var gone: Dictionary = GameState.regulars[gone_id]
		var asked := await box.ask(customer.display_name, Redemption.text("ask_friend_prompt", { "friend": record["name"], "who": gone["name"] }),
			["\"%s\"" % Redemption.ask_friend_text(gone), Redemption.text("not_now")])
		if asked == 0:
			var context := Redemption.help_context(record, gone_id, chef_id)
			var help_line := RegularMemory.pick_line(record, "gossip", context)
			var text := DialoguePicker.fill(help_line["text"], context)
			await _say(box, customer, text, Conversation.emotion_of(help_line))
			Redemption.friend_agreed(gone)
			GameEvents.announce("%s will talk to %s." % [record["name"], gone["name"]])
		return  # One ask per chat.


# "Write a letter" at the counter: pick who to (if more than one), then each
# part of the letter from three choices. Their file decides which tones make it
# sincere; the choices are shuffled so the right one isn't always first.
func _write_letter(player: Player) -> void:
	var targets := Redemption.letter_targets()
	_lock_player(player, player.global_position + Vector3.UP * 1.2, order_chat_zoom, order_counter.interactable)
	var box := ConversationBox.open(_view_of(player), player.player_index, "")
	var options: Array = targets.map(func(r): return r["name"])
	options.append(Redemption.text("not_now"))
	var picked := await box.ask("Letter", Redemption.text("letter_who"), options)
	if picked < targets.size():
		var record: Dictionary = targets[picked]
		var tones := []
		var title := "Letter to %s" % record["name"]
		for part in Redemption.letter_of(record).get("parts", []):
			var choices: Array = part.get("choices", []).duplicate()
			choices.shuffle()
			var choice: Dictionary = choices[await box.ask(title, part.get("prompt", ""), choices.map(func(c): return c["text"]))]
			tones.append(choice.get("tone", ""))
		var sincere := Redemption.send_letter(record, tones)
		await box.tell(title, Redemption.text("letter_sent", { "who": record["name"] }))
		print("Letter to %s: %s, sincere: %s" % [record["id"], tones, sincere])
		GameEvents.announce("Your letter is on its way to %s." % record["name"])
	box.close()
	_unlock_player(player)


# A Gone regular comes back at closing (after a sincere letter, or a friend's
# word) and waits just inside the door for someone to talk to them.
func _bring_back(record: Dictionary) -> void:
	walk_in(record, Customer.State.WAITING_BY_DOOR)
	GameEvents.announce("%s is standing by the door." % record["name"])


# A regular comes in outside the usual visits (a return or big moment scene)
# and stops just inside the door, switching to `state_on_arrival`.
func walk_in(record: Dictionary, state_on_arrival: Customer.State) -> Customer:
	var customer: Customer = CUSTOMER_SCENE.instantiate()
	var species := GameData.get_species(record["species"]).duplicate()
	if record.has("color"):
		species["color"] = record["color"]
	customer.setup(species, {}, null)
	customer.regular_id = record["id"]
	customer.display_name = _known_name(record)
	add_child(customer)
	customer.global_position = spawn_point.global_position
	customer.reset_physics_interpolation()
	customer.interactable.interacted.connect(_on_customer_interacted.bind(customer))
	customer.state_changed.connect(_on_customer_state_changed)
	var inside := door_point.global_position + Vector3(0.0, 0.0, -0.8)
	var path: Array[Vector3] = [door_point.global_position, inside]
	customer.walk_to(path, state_on_arrival)
	return customer


# Someone from walk_in heads home (from wherever they are).
func walk_out(customer: Customer) -> void:
	var path: Array[Vector3] = [_on_front_lane(customer.global_position), door_point.global_position, spawn_point.global_position]
	customer.leave(path, "...", 0)


# Their return scene: the opening, your reply and theirs, their closing line.
# Then they're back at 0 and head home (they'll visit again like before).
func _return_scene(player: Player, customer: Customer) -> void:
	var record: Dictionary = GameState.regulars[customer.regular_id]
	var chef_id := Accounts.id_of(player.player_index)
	customer.talking = true
	_lock_player(player, (player.global_position + customer.global_position) * 0.5 + Vector3.UP * 1.2, order_chat_zoom, customer.interactable)
	var box := _open_box(player, customer)
	var opening := RegularMemory.pick_line(record, "return_scene", _visit_context(customer, chef_id))
	if not opening.is_empty():
		await _converse(box, player, customer, opening)
	var context := _visit_context(customer, chef_id)
	var closing := RegularMemory.pick_line(record, "return_closing", context)
	if not closing.is_empty():
		var text := DialoguePicker.fill(closing["text"], context)
		await _say(box, customer, text, Conversation.emotion_of(closing))
		_after_line(customer, closing, chef_id)
	box.close()
	_unlock_player(player)
	customer.talking = false
	Redemption.welcome_back(record)
	GameEvents.announce("%s is back! (%d, %s)" % [record["name"], record["relationship"], RegularMemory.stage_name(record)])
	walk_out(customer)


# Between a seated customer and their plate, a little above the table.
func _at_table(customer: Customer) -> Vector3:
	if customer.seat == null:
		return customer.global_position + Vector3.UP * 1.2
	return (customer.global_position + customer.seat.meal_position()) * 0.5 + Vector3.UP * 0.8


# A regular nobody has chatted with is about to ask for the bill.
func _on_customer_getting_going(customer: Customer) -> void:
	var record: Dictionary = GameState.regulars[customer.regular_id]
	var line := RegularMemory.say(record, "get_going", _visit_context(customer, customer.served_by_account))
	customer.say(line if not line.is_empty() else String(GameData.service.get("regular_get_going", "I should get going soon.")))


# Step 7 is over: they'd like the bill.
func _on_customer_finished_eating(customer: Customer) -> void:
	customer.want_bill()
	var line := ""
	if customer.is_regular():
		line = RegularMemory.say(GameState.regulars[customer.regular_id], "bill", _visit_context(customer, customer.served_by_account))
	if line.is_empty():
		line = _townsfolk_line("bill")
	customer.say(line)
	GameEvents.announce("%s would like the bill." % _who(customer).capitalize())


# Step 8: `player` brings the bill. They work out how happy they are (the food,
# how quickly it came, and the drink), pay for the food and drink plus a tip,
# and walk out, leaving a dirty table. A regular says goodbye and remembers the
# visit. On day 3 or later, before there's a phone, a townsfolk asks whether
# you deliver (the phone goes up the next morning).
func _settle_bill(player: Player, customer: Customer) -> void:
	_busy.append(customer)
	player.set_held_item(null)
	var satisfaction := Satisfaction.calculate(customer.served_quality, customer.wait_seconds)
	satisfaction = clampf(satisfaction + Satisfaction.drink_mood(customer.drink, customer.served_drink), 0.0, 1.0)
	var reaction := Satisfaction.reaction_for(satisfaction)
	var streak_percent := ServiceStreak.tip_percent(customer.streak)
	var save_percent := float(ServiceStreak.settings().get("just_in_time_tip_percent", 10)) if customer.just_in_time else 0.0
	var amount := Satisfaction.bill_for(customer.dish, customer.served_drink, reaction, streak_percent + save_percent)
	var lines: Array = reaction.get("lines", ["Thank you!"])
	var line: String = lines.pick_random()
	var feeling := &"happy" if satisfaction >= 0.75 else (&"sad" if satisfaction < 0.4 else &"")
	var asks_delivery := false
	if customer.is_regular():
		var goodbye := _remember_visit(customer, reaction.get("id", ""))
		line = goodbye["text"]
		feeling = goodbye["emotion"]
	elif _asks_about_delivery():
		asks_delivery = true
		GameState.delivery_asked = true
		SaveGame.save_game()

	# They say goodbye (and maybe ask about delivery) in a dialogue box as they pay.
	customer.talking = true
	_lock_player(player, _at_table(customer), order_chat_zoom, customer.interactable)
	var box := _open_box(player, customer)
	if not line.is_empty():
		await _say(box, customer, line, feeling)
	if asks_delivery:
		await _say(box, customer, String(GameData.service.get("delivery_question", "Do you deliver?")))
	box.close()
	_unlock_player(player)
	customer.talking = false
	if not is_instance_valid(customer):
		return

	GameState.add_money(amount)
	var price := int(customer.dish.get("base_price", 0)) + int(customer.served_drink.get("base_price", 0))
	var without_save := Satisfaction.bill_for(customer.dish, customer.served_drink, reaction, streak_percent)
	var save_bonus := amount - without_save
	var streak_bonus := without_save - Satisfaction.bill_for(customer.dish, customer.served_drink, reaction)
	_pop_payment(customer, amount, amount - price - streak_bonus - save_bonus, streak_bonus, save_bonus, reaction)
	if amount > price:
		GameEvents.announce("%s paid $%d (+$%d tip)." % [_who(customer).capitalize(), amount, amount - price])
	else:
		GameEvents.announce("%s paid $%d." % [_who(customer).capitalize(), amount])
	GameState.record_service({
		"species": customer.species.get("id", ""),
		"regular": customer.regular_id,
		"dish": customer.dish.get("id", ""),
		"drink": customer.served_drink.get("id", ""),
		"price": price,
		"quality": customer.served_quality,
		"wait_seconds": customer.wait_seconds,
		"satisfaction": satisfaction,
		"reaction": reaction.get("id", ""),
		"payment": amount,
		"streak": customer.streak,
	})

	# They leave their dirty dish behind; the seat isn't reused until the table is cleared and wiped.
	_seat_owners.erase(customer.seat)
	if customer.seat.table != null:
		customer.seat.table.make_dirty(customer.seat.meal_position(), customer.dish)

	var approach := customer.seat.approach_point.global_position
	var path: Array[Vector3] = [
		approach,
		_on_front_lane(approach),
		door_point.global_position,
		spawn_point.global_position,
	]
	_busy.erase(customer)
	customer.leave(path, line, amount)
	customer.emote(feeling)
	GameEvents.announce("%s paid $%d (%s, waited %ds)." % [
		_who(customer).capitalize(), amount, reaction.get("id", "?"), roundi(customer.wait_seconds)])


# The dish just reached the table: the serving streak grows or ends
# (ServiceStreak), and how it went pops up beside them (with a save, if it came
# in the last few seconds).
func _pop_serve(customer: Customer) -> void:
	var before := ServiceStreak.count
	customer.streak = ServiceStreak.record(customer.served_quality, customer.wait_seconds)
	customer.just_in_time = ServiceStreak.in_the_nick_of_time(customer.wait_seconds)
	var settings := ServiceStreak.settings()
	var text := "%s!" % CookingMinigame.quality_label(customer.served_quality)
	if customer.streak >= 2:
		text += "\n" + String(settings.get("serve_good", "Streak x{count}!")).format({ "count": customer.streak })
	elif customer.streak == 0 and before >= 2:
		var poor := customer.served_quality < float(settings.get("min_quality", 0.7))
		text += "\n" + String(settings.get("lost_poor" if poor else "lost_slow", "Streak lost"))
	if customer.just_in_time:
		text += "\n" + String(settings.get("just_in_time", "Just in time!"))
	FloatText.pop(self, customer.global_position + POP_OFFSET, text, _quality_color(customer.served_quality), POP_FONT_SIZE)


# Paying: the money, the tip, the streak's share and a just-in-time save's pop
# up beside them, coloured by how happy they were.
func _pop_payment(customer: Customer, amount: int, tip: int, streak_bonus: int, save_bonus: int, reaction: Dictionary) -> void:
	var settings := ServiceStreak.settings()
	var text := String(settings.get("paid", "+${amount}")).format({ "amount": amount })
	if tip > 0:
		text += "\n" + String(settings.get("tip", "{reaction}: +${tip} tip")).format({
			"reaction": String(reaction.get("id", "")).capitalize(), "tip": tip })
	if streak_bonus > 0:
		text += "\n" + String(settings.get("streak_tip", "Streak x{count}: +${bonus}")).format({ "count": customer.streak, "bonus": streak_bonus })
	if save_bonus > 0:
		text += "\n%s +$%d" % [String(settings.get("just_in_time", "Just in time!")), save_bonus]
	var colors := { "delighted": QUALITY_COLORS[0], "happy": QUALITY_COLORS[1], "okay": QUALITY_COLORS[2] }
	FloatText.pop(self, customer.global_position + POP_OFFSET, text, colors.get(reaction.get("id", ""), QUALITY_COLORS[3]), POP_FONT_SIZE)


static func _quality_color(quality: float) -> Color:
	return QUALITY_COLORS[0 if quality >= 0.9 else (1 if quality >= 0.7 else (2 if quality >= 0.4 else 3))]


# Whether a townsfolk paying now asks "Do you deliver?": once, from
# delivery_question_day on (data/service.json), while there's no phone yet.
func _asks_about_delivery() -> bool:
	return not GameState.delivery_asked and not GameState.phone_unlocked \
		and GameState.day_number >= int(GameData.service.get("delivery_question_day", 3))


# Update what the regular remembers about this visit and pick their goodbye
# line: { text, emotion }.
func _remember_visit(customer: Customer, reaction_id: String) -> Dictionary:
	var record: Dictionary = GameState.regulars[customer.regular_id]
	var relationship_before: int = record["relationship"]
	var now := GameClock.now_string()  # The real date, unless the debug panel moved it.
	var server_id := customer.served_by_account
	RegularMemory.record_visit(record, customer.served_quality, reaction_id, now, server_id)
	RegularMemory.end_visit(record)

	if record["relationship"] != relationship_before:
		GameEvents.announce("%s's friendship: %d -> %d (%s)" % [record["name"], relationship_before, record["relationship"], RegularMemory.stage_name(record)])

	return RegularMemory.say_feeling(record, "farewell", RegularMemory.dialogue_context(record, server_id, {
		"reaction": reaction_id,
		"learned_name": customer.learned_name,
		# They've been here before, but this is the first time this chef served them.
		"new_chef_for_them": record["times_visited"] > 1 and record["served_by"].get(server_id, 0) == 1,
	}))


# "Mabel" for a regular, "the Frog" for anyone else.
func _who(customer: Customer) -> String:
	var named: bool = customer.is_regular() and GameState.regulars[customer.regular_id]["introduced"]
	return customer.display_name if named else "the %s" % customer.display_name


func _on_customer_state_changed(customer: Customer) -> void:
	if customer.state == Customer.State.LEAVING:
		GameState.mark_done(customer.plan_index)  # Their part of today's plan is done.
	if customer.state == Customer.State.GONE:
		customer.queue_free()


# Everyone still in line steps up one spot.
func _move_queue_forward() -> void:
	for i in _queue.size():
		_queue[i].set_destination(_queue_spot(i))


# Position in line: spot 0 is at the host stand, later spots line up behind it.
func _queue_spot(index: int) -> Vector3:
	var front: Vector3 = order_counter.get_node("CustomerSpot").global_position
	return front + Vector3(0.0, 0.0, queue_spacing * index)


# The point on the front lane (in line with the door) straight ahead of `point`.
func _on_front_lane(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, door_point.global_position.z)


# Seats nobody has claimed, at clean tables (and not stacked up for the night).
func _free_seats() -> Array[Seat]:
	var free_seats: Array[Seat] = []
	for node in get_tree().get_nodes_in_group(SEAT_GROUP):
		var seat := node as Seat
		if seat != null and not _seat_owners.has(seat) and seat.is_table_clean() and not seat.is_put_up():
			free_seats.append(seat)
	return free_seats
