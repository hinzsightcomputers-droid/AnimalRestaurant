# OrderBoard: the list of orders the kitchen is working on, oldest first.
# The counter adds orders (and the phone adds deliveries), the freezer picks the
# next one to gather ingredients for, and the stove cooks whichever order's
# ingredients it's handed.
class_name OrderBoard
extends Node

signal changed

var orders: Array[Order] = []


func add_order(customer: Customer) -> Order:
	var order := Order.new(customer, customer.dish)
	orders.append(order)
	changed.emit()
	return order


# A phoned-in order, cooked like any other and picked up by the courier.
func add_delivery(dish: Dictionary, caller: Dictionary) -> Order:
	var order := Order.new(null, dish, caller)
	orders.append(order)
	changed.emit()
	return order


# The oldest order nobody has gathered ingredients for yet, or null.
func next_to_gather() -> Order:
	for order in orders:
		if order.state == Order.State.WAITING:
			return order
	return null


func set_state(order: Order, state: Order.State) -> void:
	order.state = state
	changed.emit()


func remove_order(order: Order) -> void:
	orders.erase(order)
	changed.emit()
