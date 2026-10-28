# TableMessDisplay: shows a messy table's dirty dishes and spills. Display
# only: it listens to the DiningTable. While a close-up is open, that shows the
# dishes (or the spills, while wiping) itself.
extends Node3D

const DISH_SIZE := 0.36
const SPILL_RADIUS := 0.1
const SPILL_COLOR := Color(0.55, 0.36, 0.2, 0.85)

@onready var table: DiningTable = get_parent()

var _spill_material := StandardMaterial3D.new()


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_spill_material.albedo_color = SPILL_COLOR
	_spill_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_spill_material.roughness = 0.2
	table.cleanliness_changed.connect(_refresh)
	_refresh(table)


func _refresh(_table: DiningTable) -> void:
	for child in get_children():
		child.queue_free()
	var top := table.global_position.y + DiningTable.TOP_HEIGHT
	for at in table.spills if not table.is_wiping() else []:
		var disc := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = SPILL_RADIUS
		mesh.bottom_radius = SPILL_RADIUS
		mesh.height = 0.002
		mesh.material = _spill_material
		disc.mesh = mesh
		add_child(disc)
		disc.global_position = Vector3(at.x, top + 0.002, at.z)
	for entry in table.dishes if table.session == null else []:
		var dish := ModelFit.place(entry["model"], self, Vector3.ZERO, Vector3(DISH_SIZE, 0.0, DISH_SIZE))
		if dish != null:
			dish.global_position = Vector3(entry["at"].x, top, entry["at"].z)
