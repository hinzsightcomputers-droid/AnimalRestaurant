@tool
# ModelGrid: a model repeated in a grid, each copy stretched to fill one cell
# (e.g. wall pieces along a wall, floor tiles, a road). The grid sits with its
# bottom on this node and its middle on this node's x and z. Like ModelFit, it
# shows in the editor and only the settings are saved.
class_name ModelGrid
extends Node3D

@export var model: PackedScene:
	set(value):
		model = value
		_rebuild()
@export var cells := Vector2i(1, 1):  # How many along x and along z.
	set(value):
		cells = value
		_rebuild()
@export var cell_size := Vector3(2.0, 3.0, 2.0):  # Each copy's box (meters).
	set(value):
		cell_size = value
		_rebuild()
@export_range(-180.0, 180.0, 90.0) var turn_degrees := 0.0:  # Turns each copy (inside its cell).
	set(value):
		turn_degrees = value
		_rebuild()

var _holder: Node3D = null


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	_holder = null
	for child in get_children(true):  # Including a copy's, if this node was duplicated.
		if String(child.name).contains("_Grid"):
			remove_child(child)
			child.queue_free()
	if model == null:
		return
	_holder = Node3D.new()
	_holder.name = "_Grid"
	add_child(_holder, false, Node.INTERNAL_MODE_FRONT)
	var start := Vector3((1 - cells.x) * 0.5 * cell_size.x, 0.0, (1 - cells.y) * 0.5 * cell_size.z)
	for x in cells.x:
		for z in cells.y:
			var piece := ModelFit.new()
			piece.position = start + Vector3(x * cell_size.x, 0.0, z * cell_size.z)
			_holder.add_child(piece)
			piece.stretch = true
			piece.turn_degrees = turn_degrees
			piece.size = cell_size  # ModelFit measures after turning, so the cell stays as given.
			piece.model = model
