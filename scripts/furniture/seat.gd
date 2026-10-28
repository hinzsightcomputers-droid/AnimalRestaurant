# Seat: a chair customers can sit on. Knows which table it belongs to, so a
# messy table keeps its seats from being given to new customers.
class_name Seat
extends Station

@export var table: DiningTable

@onready var seat_point: Marker3D = $SeatPoint          # Where the customer sits.
@onready var approach_point: Marker3D = $ApproachPoint  # Where they step to before sitting.


func is_table_clean() -> bool:
	return table == null or table.is_clean()


# Where a seated customer's plate goes: in front of the chair, on the table.
func meal_position() -> Vector3:
	return seat_point.global_position + global_basis.z * 0.75
