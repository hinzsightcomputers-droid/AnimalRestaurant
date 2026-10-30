# OrderBoard: the list of orders the kitchen is working on, oldest first.
# The counter adds orders (and the phone adds deliveries), the freezer picks the
# next one to gather ingredients for (once its ticket is on the wheel), and the
# stove cooks whichever order's ingredients it's handed.
class_name OrderBoard
extends Node

signal changed

var orders: Array[Order] = []
var _next_number := 1


func add_order(customer: Customer) -> Order:
	var order := Order.new(customer, customer.dish)
	order.pantry_items = Pantry.take_for(order.dish)
	_number(order)
	orders.append(order)
	changed.emit()
	return order


# A phoned-in order, cooked like any other and picked up by the courier.
func add_delivery(dish: Dictionary, caller: Dictionary) -> Order:
	var order := Order.new(null, dish, caller)
	order.pantry_items = Pantry.take_for(order.dish)
	_number(order)
	orders.append(order)
	changed.emit()
	return order


# The oldest order on the wheel nobody has gathered ingredients for yet, or null.
func next_to_gather() -> Order:
	for order in orders:
		if order.state == Order.State.WAITING and order.on_wheel:
			return order
	return null


# Whether some order is only waiting for its ticket to go on the wheel.
func has_ticket_off_wheel() -> bool:
	return orders.any(func(o): return o.state == Order.State.WAITING and not o.on_wheel)


func clip(order: Order) -> void:
	order.on_wheel = true
	changed.emit()


func _number(order: Order) -> void:
	order.number = _next_number
	_next_number += 1


func set_state(order: Order, state: Order.State) -> void:
	order.state = state
	changed.emit()


func remove_order(order: Order) -> void:
	orders.erase(order)
	for player in get_tree().get_nodes_in_group(Player.GROUP):  # A ticket nobody clipped yet.
		player.drop_ticket(order)
	changed.emit()
