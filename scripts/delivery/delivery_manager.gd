# DeliveryManager: phoned-in orders. Puts each on the order board (it's cooked
# the normal way) and sends a courier in to wait by the counter. Handing the
# courier the finished dish pays for it and the courier leaves. Couriers wait
# as long as it takes: nothing about a delivery is ever rushed.
# A Gone regular's last order is different: its courier hands over their
# goodbye note instead of a payment slip. And when a sincere letter's answer is
# due (see Redemption), a courier brings the reply in to be read.
class_name DeliveryManager
extends Node3D

@export var order_board: OrderBoard
@export var spawn_point: Marker3D   # Outside the front door.
@export var door_point: Marker3D    # Just inside the front door.
@export var pickup_point: Marker3D  # Where the first courier waits; the rest line up behind.
@export var view_manager: ViewManager  # To show notes and letters in the right player's view.

var _couriers: Array[Courier] = []  # Waiting (or walking in), first in line first.


func _process(_delta: float) -> void:
	_check_letters()


# `caller` is PhoneCalls.caller_info(...). Returns the order (for its ticket).
func add_delivery(dish: Dictionary, caller: Dictionary) -> Order:
	var order := order_board.add_delivery(dish, caller)
	var courier := Courier.new()
	courier.setup(order, GameData.phone_settings.get("courier", {}))
	_send_in(courier)
	return order


func _send_in(courier: Courier) -> void:
	add_child(courier)
	courier.global_position = spawn_point.global_position
	courier.interactable.interacted.connect(_on_courier_interacted.bind(courier))
	courier.arrived_outside.connect(func(c): c.queue_free())
	_couriers.append(courier)
	courier.walk_to(_path_to(courier, _spot(_couriers.size() - 1)))


# Deliveries still waiting to be picked up (the day doesn't end until they are).
func has_deliveries() -> bool:
	return not _couriers.is_empty()


func _on_courier_interacted(player_index: int, courier: Courier) -> void:
	var player := Player.find(get_tree(), player_index)
	if player == null or courier.leaving or player.movement_locked:
		return
	if courier.order == null:
		_read_letter(player, courier)
		return
	var plate := player.held_item as CookedDish
	if plate == null or plate.order != courier.order:
		GameEvents.announce("The courier is waiting for %s's %s." % [courier.order.caller.get("name", "?"), courier.order.dish.get("name", "order")])
		return

	player.set_held_item(null)
	order_board.remove_order(plate.order)
	GameState.record_chef_action(player_index, "served")
	var caller := plate.order.caller
	var record: Dictionary = GameState.regulars.get(caller.get("regular_id", ""), {})
	var goodbye := not record.is_empty() and Redemption.goodbye_due(record)
	# Paid on how it was cooked only: the wait never counts against a delivery.
	var satisfaction := Satisfaction.calculate(plate.quality, 0.0)
	var reaction := Satisfaction.reaction_for(satisfaction)
	var amount := 0 if goodbye else Satisfaction.payment_for(plate.order.dish, reaction)
	GameState.add_money(amount)
	GameState.record_service({
		"species": caller.get("species", ""),
		"regular": caller.get("regular_id", ""),
		"delivery": true,
		"dish": plate.order.dish.get("id", ""),
		"price": plate.order.dish.get("base_price", 0),
		"quality": plate.quality,
		"wait_seconds": 0.0,
		"satisfaction": satisfaction,
		"reaction": reaction.get("id", ""),
		"payment": amount,
	})
	if not goodbye:
		GameEvents.announce("Handed %s's %s to the courier. +$%d" % [caller.get("name", "?"), plate.dish_name(), amount])
		_send_out(courier, "Thanks! +$%d" % amount)
		return

	# Their last order: a note instead of a payment slip.
	courier.leaving = true  # Nobody else can use it while the note is read.
	var courier_name: String = GameData.phone_settings.get("courier", {}).get("name", "The courier")
	await _show_lines(player, record["id"], [
		[courier_name, Redemption.text("note_handover")],
		["%s (note)" % record["name"], Redemption.goodbye_note(record)],
	])
	Redemption.say_goodbye(record)
	GameEvents.announce("%s is gone. They won't be ordering anymore." % record["name"])
	_send_out(courier, "...")


# A Gone regular's reply to your letter. Once it's read, they come in at closing.
func _read_letter(player: Player, courier: Courier) -> void:
	var record := courier.letter_from
	courier.leaving = true
	var courier_name: String = GameData.phone_settings.get("courier", {}).get("name", "The courier")
	await _show_lines(player, record["id"], [
		[courier_name, Redemption.text("letter_arrives", { "who": record["name"] })],
		["%s (letter)" % record["name"], Redemption.reply_text(record)],
	])
	Redemption.reply_arrived(record)
	GameEvents.announce("%s will come by at closing time." % record["name"])
	_send_out(courier, "Bye!")


# Answers due on letters: a courier brings each sincere one's reply (one at a
# time per regular); an insincere letter just never gets one.
func _check_letters() -> void:
	for record in Redemption.letters_due():
		if not record["letter_sincere"]:
			Redemption.no_reply(record)
			GameEvents.announce("No reply from %s. Maybe the letter didn't say the right things." % record["name"])
		elif not _couriers.any(func(c): return c.letter_from == record):
			var courier := Courier.new()
			courier.setup_letter(record, GameData.phone_settings.get("courier", {}))
			_send_in(courier)
			GameEvents.announce("%s came by with a letter." % GameData.phone_settings.get("courier", {}).get("name", "The courier"))


# [[speaker, text], ...] in a dialogue box for `player`, who waits in place.
func _show_lines(player: Player, regular_id: String, lines: Array) -> void:
	player.movement_locked = true
	var box := ConversationBox.open(ConversationBox.parent_for(view_manager, player.player_index, self), player.player_index, regular_id)
	for line in lines:
		await box.tell(line[0], line[1])
	box.close()
	player.ignore_interact_until_released()
	player.movement_locked = false


# The courier heads back out; everyone behind steps up.
func _send_out(courier: Courier, bubble: String) -> void:
	_couriers.erase(courier)
	var here := courier.global_position
	var path: Array[Vector3] = [Vector3(here.x, 0.0, door_point.global_position.z), door_point.global_position, spawn_point.global_position]
	courier.leave(path, bubble)
	for i in _couriers.size():
		_couriers[i].walk_to(_path_to(_couriers[i], _spot(i)))


# Place in the pickup line: spot 0 is pickup_point, the rest line up toward the front door.
func _spot(index: int) -> Vector3:
	var spacing: float = GameData.phone_settings.get("courier", {}).get("spacing", 0.9)
	return pickup_point.global_position + Vector3(0.0, 0.0, spacing * index)


# From wherever `courier` is to `end`, through the door if it's still outside
# and along the front lane if it hasn't turned up the room yet.
func _path_to(courier: Courier, end: Vector3) -> Array[Vector3]:
	var door := door_point.global_position
	var path: Array[Vector3] = []
	if courier.global_position.z > door.z + 0.1:
		path.append(door)
	if courier.global_position.z > door.z - 0.1:
		path.append(Vector3(end.x, 0.0, door.z))
	path.append(end)
	return path
