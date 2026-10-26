# Customer: one animal guest. Holds its state (arriving, waiting, seated...) and
# walks along the waypoints it is given. CustomerManager decides where customers go;
# CustomerDisplay decides how they look.
class_name Customer
extends Node3D

enum State { ARRIVING, WAITING_TO_ORDER, WALKING_TO_SEAT, WAITING_FOR_FOOD }

signal state_changed(customer: Customer)

@export var walk_speed := 2.0
@export var turn_speed := 10.0

var state: State = State.ARRIVING
var species: Dictionary = {}  # From data/species.json
var dish: Dictionary = {}     # From data/dishes.json. Picked on arrival, revealed when ordering.
var seat: Station = null      # The chair reserved for this customer.

var _path: Array[Vector3] = []
var _state_after_path: State = State.ARRIVING


func setup(species_data: Dictionary, dish_data: Dictionary, reserved_seat: Station) -> void:
	species = species_data
	dish = dish_data
	seat = reserved_seat


# Walk through the given points in order, then switch to `state_on_arrival`.
func walk_to(points: Array[Vector3], state_on_arrival: State) -> void:
	_path = points.duplicate()
	_state_after_path = state_on_arrival


func is_walking() -> bool:
	return not _path.is_empty()


# Called when a player takes this customer's order.
func place_order() -> void:
	_set_state(State.WALKING_TO_SEAT)


func _physics_process(delta: float) -> void:
	if _path.is_empty():
		return

	var offset := _path[0] - global_position
	var step := walk_speed * delta

	if offset.length() <= step:
		global_position = _path[0]
		_path.pop_front()
		if _path.is_empty():
			_on_path_finished()
		return

	global_position += offset.normalized() * step
	if Vector2(offset.x, offset.z).length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(offset.x, offset.z), turn_speed * delta)


func _on_path_finished() -> void:
	# Once seated, face the same way as the chair (toward the table).
	if _state_after_path == State.WAITING_FOR_FOOD and seat != null:
		rotation.y = seat.global_rotation.y
	_set_state(_state_after_path)


func _set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(self)
