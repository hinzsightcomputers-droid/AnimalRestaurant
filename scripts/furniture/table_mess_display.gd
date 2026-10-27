# TableMessDisplay: shows a leftover plate and crumbs for each customer who ate
# at a dirty table, shrinking with each scrub. Display only: it listens to the
# DiningTable. The first child ("Pile") is copied for each extra plate.
extends Node3D

const TABLE_TOP_HEIGHT := 0.82
const SMALLEST_SCALE := 0.35  # How small the mess gets right before it's gone.

@onready var table: DiningTable = get_parent()
@onready var _piles: Array[Node3D] = [$Pile]


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	table.cleanliness_changed.connect(_refresh)
	_refresh(table)


func _refresh(_table: DiningTable) -> void:
	visible = table.is_dirty
	if not visible:
		return

	while _piles.size() < table.mess_positions.size():
		var pile: Node3D = _piles[0].duplicate()
		add_child(pile)
		_piles.append(pile)

	var progress := float(table.scrubs_done) / table.scrubs_needed
	for i in _piles.size():
		var pile := _piles[i]
		pile.visible = i < table.mess_positions.size()
		if pile.visible:
			var at := table.mess_positions[i]
			pile.global_position = Vector3(at.x, table.global_position.y + TABLE_TOP_HEIGHT, at.z)
			pile.scale = Vector3.ONE * lerpf(1.0, SMALLEST_SCALE, progress)
