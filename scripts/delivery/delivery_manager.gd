# DeliveryManager: phoned-in orders. Puts each on the order board (it's cooked
# the normal way) and sends a courier in to wait by the counter. Handing the
# courier the finished dish pays for it and the courier leaves. Couriers wait
# as long as it takes: nothing about a delivery is ever rushed.
class_name DeliveryManager
extends Node3D

@export var order_board: OrderBoard
@export var spawn_point: Marker3D   # Outside the front door.
@export var door_point: Marker3D    # Just inside the front door.
@export var pickup_point: Marker3D  # Where the first courier waits; the rest line up behind.

var _couriers: Array[Courier] = []  # Waiting (or walking in), first in line first.


# `caller` is PhoneCalls.caller_info(...).
func add_delivery(dish: Dictionary, caller: Dictionary) -> void:
	var order := order_board.add_delivery(dish, caller)
	var courier := Courier.new()
	courier.setup(order, GameData.phone_settings.get("courier", {}))
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
	if player == null or courier.leaving:
		return
	var plate := player.held_item as CookedDish
	if plate == null or plate.order != courier.order:
		GameEvents.announce("The courier is waiting for %s's %s." % [courier.order.caller.get("name", "?"), courier.order.dish.get("name", "order")])
		return

	player.set_held_item(null)
	order_board.remove_order(plate.order)
	GameState.record_chef_action(player_index, "served")
	# Paid on how it was cooked only: the wait never counts against a delivery.
	var satisfaction := Satisfaction.calculate(plate.quality, 0.0)
	var reaction := Satisfaction.reaction_for(satisfaction)
	var amount := Satisfaction.payment_for(plate.order.dish, reaction)
	GameState.add_money(amount)
	var caller := plate.order.caller
	GameState.record_service({
		"species": caller.get("species", ""),
		"regular": caller.get("regular_id", ""),
		"delivery": true,
		"dish": plate.order.dish.get("id", ""),
		"price": plate.order.dish.get("price", 0),
		"quality": plate.quality,
		"wait_seconds": 0.0,
		"satisfaction": satisfaction,
		"reaction": reaction.get("id", ""),
		"payment": amount,
	})
	GameEvents.announce("Handed %s's %s to the courier. +$%d" % [caller.get("name", "?"), plate.dish_name(), amount])

	_couriers.erase(courier)
	var here := courier.global_position
	var path: Array[Vector3] = [Vector3(here.x, 0.0, door_point.global_position.z), door_point.global_position, spawn_point.global_position]
	courier.leave(path, amount)
	for i in _couriers.size():  # Everyone behind steps up.
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
