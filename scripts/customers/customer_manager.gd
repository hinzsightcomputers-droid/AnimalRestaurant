# CustomerManager: runs each customer's visit. Sends in this meal's customers
# from today's plan (DayPlan) one at a time, each once a seat at a clean table
# is free, lines them up at the order counter, seats them once their order is
# taken, handles serving, then has them pay, leave a dirty table, and walk out.
# Once the meal's last customer has gone, the counter's bell (ServiceBell) is
# rung for the next meal (see DayManager).
# Customers walk along lanes so they don't cut through furniture: the front lane
# (in line with the door), the back lane (in line with the counter), and straight
# up and down the aisle behind each chair.
# It also runs the Gone side of regulars (see Redemption): writing a letter at
# the order counter when nobody's waiting, asking a friend about someone Gone
# while the friend eats, and the return scene when a Gone regular comes back
# at closing time and waits by the door.
class_name CustomerManager
extends Node3D

const CUSTOMER_SCENE := preload("res://scenes/customers/customer.tscn")
const SEAT_GROUP := "seats"

@export var order_counter: Station
@export var order_board: OrderBoard
@export var spawn_point: Marker3D   # Outside the front door.
@export var door_point: Marker3D    # Just inside the front door.
@export var view_manager: ViewManager  # To show dialogue boxes in the right player's view.
@export var queue_spacing := 0.9    # Gap between customers waiting in line.
@export_group("Order chat")
@export var order_chat_seconds := 1.8         # How long the player and customer chat when ordering.
@export var order_chat_zoom: CameraZoomSettings  # The ordering player's camera during the chat.
@export_group("Serving moment")
@export var serve_seconds := 1.5              # How long the server watches the customer start eating.
@export var serve_zoom: CameraZoomSettings    # The serving player's camera during that moment.
@export_group("Eating chat")
@export var eating_chat_zoom: CameraZoomSettings  # The chatting player's camera (falls back to order_chat_zoom).

var day_manager: DayManager         # Set by the DayManager: rings the bell.
var accepting_customers := true     # False after closing time.
var _queue: Array[Customer] = []    # Customers waiting to order, front of the line first.
var _seat_owners: Dictionary = {}   # seat (Station) -> Customer sitting there or walking to it.
var _pending: Array = []            # This meal's customers still to come: [plan index, entry].
var _chatting := false              # True while someone is taking an order.
var _arrival_timer := Timer.new()
var bell := ServiceBell.new()     # On the counter: rung to start the next meal.


func _ready() -> void:
	order_counter.used.connect(_on_order_counter_used)
	order_counter.interactable.prompt_for_player = _counter_prompt
	order_counter.add_child(bell)
	bell.position = Vector3(-0.85, 1.06, -0.1)  # On the counter top, at the end away from the register.
	bell.scale = Vector3.ONE * 1.8  # Big enough to spot from the usual camera.
	_arrival_timer.timeout.connect(_try_spawn_customer)
	add_child(_arrival_timer)


# A meal starts: its customers from today's plan come in one at a time, except
# any already done (a day picked up again). `entries` is the meal's list.
func start_phase(entries: Array, done: Array) -> void:
	_pending.clear()
	for i in entries.size():
		if not i in done:
			_pending.append([i, entries[i]])
	accepting_customers = true
	var settings := GameData.day_settings
	_arrival_timer.wait_time = float(settings.get("arrival_seconds", 9.0)) * GameState.upgrade_multiplier("arrival_interval")  # Welcome Sign.
	_arrival_timer.stop()
	await get_tree().create_timer(float(settings.get("first_arrival_seconds", 3.0)), false).timeout  # false: waits while paused (e.g. name entry).
	_try_spawn_customer()
	_arrival_timer.start()


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
	for child in get_children():
		if child is Customer and not child.is_queued_for_deletion():
			_seat_owners.erase(child.seat)
			child.queue_free()
	_seat_owners.clear()


# Closing time: no new arrivals, and anyone who hasn't ordered yet heads home.
# Customers who already ordered stay until they're served.
func close() -> void:
	accepting_customers = false
	_pending.clear()
	_arrival_timer.stop()
	for customer in _queue:
		_seat_owners.erase(customer.seat)
		var path: Array[Vector3] = [_on_front_lane(customer.global_position), door_point.global_position, spawn_point.global_position]
		customer.leave(path, "Oh, you're closing? Next time!", 0)
		if customer.is_regular():
			RegularMemory.end_visit(GameState.regulars[customer.regular_id])
	_queue.clear()
	for record in Redemption.returning_today():
		_bring_back(record)


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
	var next := _next_customer()
	if next.is_empty():
		return
	var regular: Dictionary = next["regular"]

	var customer: Customer = CUSTOMER_SCENE.instantiate()
	customer.plan_index = next["index"]
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
func _setup_regular(customer: Customer, record: Dictionary, seat: Seat) -> void:
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
	var greeting := RegularMemory.say_feeling(record, "greeting",
		RegularMemory.dialogue_context(record, RegularMemory.favorite_chef_here(record)))
	customer.greeting_line = greeting["text"]
	customer.greeting_emotion = greeting["emotion"]


# What a regular's lines can depend on, talking to chef `chef_id` about their order.
func _visit_context(customer: Customer, chef_id: String, extra: Dictionary = {}) -> Dictionary:
	var record: Dictionary = GameState.regulars[customer.regular_id]
	var context := RegularMemory.dialogue_context(record, chef_id, {
		"dish": customer.dish.get("name", ""),
		"ordered_favorite": customer.dish.get("id", "") == record["favorite_dish"],
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


# "Take order", or "Write a letter" when nobody's ready to order and someone Gone could get one.
# "Ticket wheel full!" when there's no clip left for another order. Once the
# meal's over, ringing the bell for the next one.
func _counter_prompt(_player_index: int) -> String:
	if day_manager != null and day_manager.bell_ready():
		return day_manager.bell_prompt()
	if _someone_ready_to_order() and not _chatting and TicketWheel.is_full(get_tree()):
		return "Ticket wheel full!"
	if not _someone_ready_to_order() and not _chatting and not Redemption.letter_targets().is_empty():
		return "Write a letter"
	return order_counter.interactable.prompt


func _someone_ready_to_order() -> bool:
	return not _queue.is_empty() and _queue[0].state == Customer.State.WAITING_TO_ORDER and not _queue[0].is_walking()


func _on_order_counter_used(_station: Station, player_index: int) -> void:
	if _chatting:
		return
	if day_manager != null and day_manager.bell_ready():
		bell.ring()
		day_manager.ring_bell()
		return
	var player := Player.find(get_tree(), player_index)
	if not _someone_ready_to_order() and player != null and not Redemption.letter_targets().is_empty():
		_chatting = true
		await _write_letter(player)
		_chatting = false
		return
	if _queue.is_empty():
		GameEvents.announce("Nobody is waiting to order.")
		return

	var customer := _queue[0]
	if customer.state != Customer.State.WAITING_TO_ORDER or customer.is_walking():
		return  # Front customer hasn't reached the counter yet.
	if TicketWheel.is_full(get_tree()):
		GameEvents.announce("The ticket wheel is full! Finish an order first.")
		return

	_queue.pop_front()
	_chatting = true
	if customer.is_regular() and player != null:
		await _regular_orders(player, customer)  # May change what they order.
	customer.place_order()
	var order := order_board.add_order(customer)
	GameEvents.announce("%s took an order: %s wants %s." % [
		Accounts.name_of(player_index), customer.display_name, customer.dish.get("name", "?")])
	if not customer.is_regular() and player != null:
		await _order_chat(player, customer)
	if player != null:
		await TicketPopup.write(view_manager, player, order)
	else:
		order_board.clip(order)
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
# with (press interact), then anything they've heard about you from a friend
# (gossip, once), then usually the ordering conversation from their file,
# sometimes (once they trust you) "What do you recommend?" or "Surprise me"
# instead, where the player picks the dish. Lines without choices are just said.
func _regular_orders(player: Player, customer: Customer) -> void:
	var record: Dictionary = GameState.regulars[customer.regular_id]
	var chef_id := Accounts.id_of(player.player_index)
	_lock_player(player, _at_counter(player, customer), order_chat_zoom, order_counter.interactable)
	customer.talking = true
	var box := _open_box(player, customer)
	var arrival := RegularMemory.say(record, "arrival", _visit_context(customer, chef_id))  # e.g. Mabel rings her bell.
	if not arrival.is_empty():
		await box.tell("", arrival)
	if not customer.greeting_line.is_empty():
		await _say(box, customer, customer.greeting_line, customer.greeting_emotion)

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
		await _say(box, customer, customer.order_line, Conversation.emotion_of(line))
	box.close()
	customer.talking = false
	_unlock_player(player)


# Once a line has been said: its memory flags, whether they learned the chef's
# name, and whether it made two regulars friends.
func _after_line(customer: Customer, line: Dictionary, chef_id: String) -> void:
	var record: Dictionary = GameState.regulars[customer.regular_id]
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
	if customer.state == Customer.State.WAITING_BY_DOOR:
		if player != null and player.held_item == null and not player.movement_locked:
			_return_scene(player, customer)
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
	customer.serve(plate.quality, plate)
	GameEvents.announce("Served %s to %s." % [plate.dish_name(), customer_name])
	if not customer.is_regular():
		# A short zoom on the customer digging in.
		_hold_with_zoom(player, _at_table(customer), serve_zoom, serve_seconds, customer.interactable)
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
	customer.display_name = record["name"]
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
	return (customer.global_position + customer.seat.meal_position()) * 0.5 + Vector3.UP * 0.8


# Done eating: work out how happy they are, take payment, and walk them out.
func _on_customer_finished_eating(customer: Customer) -> void:
	var satisfaction := Satisfaction.calculate(customer.served_quality, customer.wait_seconds)
	var reaction := Satisfaction.reaction_for(satisfaction)
	var amount := Satisfaction.payment_for(customer.dish, reaction)
	var lines: Array = reaction.get("lines", ["Thank you!"])
	var line: String = lines.pick_random()
	var feeling := &""
	if customer.is_regular():
		var goodbye := _remember_visit(customer, reaction.get("id", ""))
		line = goodbye["text"]
		feeling = goodbye["emotion"]

	GameState.add_money(amount)
	GameState.record_service({
		"species": customer.species.get("id", ""),
		"regular": customer.regular_id,
		"dish": customer.dish.get("id", ""),
		"price": customer.dish.get("base_price", 0),
		"quality": customer.served_quality,
		"wait_seconds": customer.wait_seconds,
		"satisfaction": satisfaction,
		"reaction": reaction.get("id", ""),
		"payment": amount,
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
	customer.leave(path, line, amount)
	customer.emote(feeling)
	GameEvents.announce("%s paid $%d (%s, waited %ds)." % [
		_who(customer).capitalize(), amount, reaction.get("id", "?"), roundi(customer.wait_seconds)])


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
	return customer.display_name if customer.is_regular() else "the %s" % customer.display_name


func _on_customer_state_changed(customer: Customer) -> void:
	if customer.state == Customer.State.LEAVING:
		GameState.mark_done(customer.plan_index)  # Their part of today's plan is done.
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
