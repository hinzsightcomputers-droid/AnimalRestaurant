# CustomerManager: spawns customers, lines them up at the order counter, and sends
# each one to their reserved seat once a player takes their order at the counter.
# A customer only spawns if there is a free seat for them.
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

var _queue: Array[Customer] = []    # Customers waiting to order, front of the line first.
var _seat_owners: Dictionary = {}   # seat (Station) -> Customer sitting there or walking to it.


func _ready() -> void:
	order_counter.used.connect(_on_order_counter_used)

	await get_tree().create_timer(first_arrival_delay).timeout
	_try_spawn_customer()

	var timer := Timer.new()
	timer.wait_time = arrival_interval
	timer.timeout.connect(_try_spawn_customer)
	add_child(timer)
	timer.start()


func _try_spawn_customer() -> void:
	var seat := _find_free_seat()
	if seat == null:
		return

	var customer: Customer = CUSTOMER_SCENE.instantiate()
	customer.setup(GameData.random_species(), GameData.random_dish(), seat)
	add_child(customer)
	customer.global_position = spawn_point.global_position
	customer.reset_physics_interpolation()

	_seat_owners[seat] = customer
	_queue.append(customer)
	var path: Array[Vector3] = [door_point.global_position, _queue_spot(_queue.size() - 1)]
	customer.walk_to(path, Customer.State.WAITING_TO_ORDER)
	GameEvents.announce("A %s walked in." % customer.species.get("name", "customer"))


func _on_order_counter_used(_station: Station, player_index: int) -> void:
	if _queue.is_empty():
		GameEvents.announce("Nobody is waiting to order.")
		return

	var customer := _queue[0]
	if customer.state != Customer.State.WAITING_TO_ORDER or customer.is_walking():
		return  # Front customer hasn't reached the counter yet.

	_queue.pop_front()
	customer.place_order()
	order_board.add_order(customer)
	GameEvents.announce("Player %d took an order: %s wants %s." % [
		player_index + 1, customer.species.get("name", "?"), customer.dish.get("name", "?")])

	var path: Array[Vector3] = [
		customer.seat.get_node("ApproachPoint").global_position,
		customer.seat.get_node("SeatPoint").global_position,
	]
	customer.walk_to(path, Customer.State.WAITING_FOR_FOOD)
	_move_queue_forward()


# Everyone still in line steps up one spot.
func _move_queue_forward() -> void:
	for i in _queue.size():
		var path: Array[Vector3] = [_queue_spot(i)]
		_queue[i].walk_to(path, Customer.State.WAITING_TO_ORDER)


# Position in line: spot 0 is at the counter, later spots line up behind it.
func _queue_spot(index: int) -> Vector3:
	var front: Vector3 = order_counter.get_node("CustomerSpot").global_position
	return front + Vector3(0.0, 0.0, queue_spacing * index)


func _find_free_seat() -> Station:
	for seat in get_tree().get_nodes_in_group(SEAT_GROUP):
		if not _seat_owners.has(seat):
			return seat
	return null
