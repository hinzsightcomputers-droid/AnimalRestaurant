# Seat: a chair customers can sit on. Knows which table it belongs to, so a
# messy table keeps its seats from being given to new customers. At night the
# chairs go up on the tables.
class_name Seat
extends Station

const SEAT_HEIGHT := 0.45  # The chair's seat above the floor: upside down, it rests on the table there.

@export var table: DiningTable

var _stack_tween: Tween
var _up := false

@onready var seat_point: Marker3D = $SeatPoint          # Where the customer sits.
@onready var approach_point: Marker3D = $ApproachPoint  # Where they step to before sitting.


func is_put_up() -> bool:
	return _up


func is_table_clean() -> bool:
	return table == null or table.is_clean()


# Where a seated customer's plate goes: in front of the chair, on the table.
func meal_position() -> Vector3:
	return seat_point.global_position + global_basis.z * 0.75


# Up on its table, upside down (night), or back on the floor. `seconds` 0 = at once.
func put_up(up: bool, seconds := 0.6) -> void:
	if table == null:
		return
	_up = up
	var target := Transform3D.IDENTITY
	if up:
		var top := table.global_position + Vector3(0.0, DiningTable.TOP_HEIGHT, 0.0)
		var over_its_side := (global_position - table.global_position) * 0.3
		over_its_side.y = 0.0
		target = Transform3D(Basis(Vector3.RIGHT, PI), to_local(top + over_its_side) + Vector3.UP * SEAT_HEIGHT)
	if _stack_tween != null:
		_stack_tween.kill()
	if seconds <= 0.0:
		visual.transform = target
		return
	_stack_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_stack_tween.tween_property(visual, "transform", target, seconds)
