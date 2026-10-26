# TableMessDisplay: shows the leftover plate and crumbs on a dirty table,
# shrinking with each scrub. Display only: it listens to the DiningTable.
extends Node3D

const TABLE_TOP_HEIGHT := 0.82
const SMALLEST_SCALE := 0.35  # How small the mess gets right before it's gone.

@onready var table: DiningTable = get_parent()


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	table.cleanliness_changed.connect(_refresh)
	_refresh(table)


func _refresh(_table: DiningTable) -> void:
	visible = table.is_dirty
	if not visible:
		return
	global_position = Vector3(table.mess_position.x, table.global_position.y + TABLE_TOP_HEIGHT, table.mess_position.z)
	var progress := float(table.scrubs_done) / table.scrubs_needed
	scale = Vector3.ONE * lerpf(1.0, SMALLEST_SCALE, progress)
