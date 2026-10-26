# OrderBoard: the list of orders the kitchen is working on, oldest first.
# The counter adds orders, the stove picks the next one to cook.
class_name OrderBoard
extends Node

signal changed

var orders: Array[Order] = []


func add_order(customer: Customer) -> Order:
	var order := Order.new(customer, customer.dish)
	orders.append(order)
	changed.emit()
	return order


# The oldest order nobody has started cooking yet, or null.
func next_to_cook() -> Order:
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
