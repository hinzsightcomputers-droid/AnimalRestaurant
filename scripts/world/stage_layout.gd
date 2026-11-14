# StageLayout: builds what the restaurant's stages change in the room, when
# the main scene loads (RestaurantGrounds calls it first thing, so the walls it
# adds get the right render layers). Stage 2 knocks the dining room through to
# the left (Stages.grown_left meters): the left wall moves out, and the back
# and front walls, the floor and new tables fill the strip. Decor spots on the
# left wall move with it (Decor.spot_position), and RestaurantGrounds.outdoors
# counts the strip as indoors.
class_name StageLayout
extends RefCounted

const WALL_MODEL := "res://design/assets/KayKit_Bits_Bundle1_1.1/Restaurant Bits/Assets/gltf/wall.gltf"
const TABLE_SCENE := "res://scenes/furniture/table.tscn"
const CHAIR_SCENE := "res://scenes/furniture/chair.tscn"
const LAMP_SCENE := "res://scenes/style/pendant_lamp.tscn"
const LAMP_HEIGHT := 3.0  # As PendantLamp1-4 over the first tables.
const DINING_LEFT := -7.15   # The dining room's left wall before any stage...
const DINING_BACK := -5.15   # ...and its back and front walls.
const DINING_FRONT := 5.15
const WALL_THICK := 0.3
const CHAIR_FROM_TABLE := 1.1  # Chairs either side of a table, as in the main scene.
const AGAINST_LEFT_WALL := -6.0  # Furniture and plants left of this stand against the left wall, and move out with it.


static func apply(main: Node) -> void:
	var grow := Stages.grown_left()
	var room := main.get_node_or_null("RestaurantRoom") as Node3D
	if grow <= 0.0 or room == null:
		return
	var left := DINING_LEFT - grow
	var left_wall := room.get_node_or_null("Walls/LeftWall") as Node3D
	if left_wall != null:
		left_wall.position.x = left
	_add_wall(room.get_node("Walls"), "BackWallStage", Vector3((DINING_LEFT + left) / 2.0, 0.0, DINING_BACK), grow, 3.0)
	var front := room.get_node_or_null("Walls/FrontWall") as Node3D
	if front != null:  # The front wall is low from inside (see RestaurantGrounds), so its new stretch is too.
		_add_wall(front, "PiecesStage", Vector3((DINING_LEFT + left) / 2.0, 0.0, 0.0), grow, 0.6, 3.0)
	_add_floor(room, left, grow)
	var furniture := main.get_node_or_null("Furniture")
	for group in [furniture, room.get_node_or_null("Decor")]:
		if group != null:
			for child in group.get_children():
				if child is Node3D and (child as Node3D).position.x < AGAINST_LEFT_WALL:
					(child as Node3D).position.x -= grow
	_clear_yard(room.get_node_or_null("Outside"), left)
	if furniture != null:
		for stage in range(2, GameState.stage + 1):
			for table in Stages.info(stage).get("tables", []):
				_add_table(furniture, table)
				_add_lamp(main.get_node_or_null("Lamps"), table)


# A stretch of plain wall `width` wide and `height` tall (solid to
# `solid_height`), its bottom middle at `at` in `parent`'s terms.
static func _add_wall(parent: Node, wall_name: String, at: Vector3, width: float, height: float, solid_height := -1.0) -> void:
	var body := StaticBody3D.new()
	body.name = wall_name
	body.position = at
	parent.add_child(body)
	var grid := ModelGrid.new()
	grid.cells = Vector2i(1, 1)
	grid.cell_size = Vector3(width, height, WALL_THICK)
	grid.model = load(WALL_MODEL)
	body.add_child(grid)
	var shape := BoxShape3D.new()
	var solid := solid_height if solid_height > 0.0 else height
	shape.size = Vector3(width, solid, WALL_THICK)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = solid / 2.0
	body.add_child(collision)


# Floor for the new strip, in the dining floor's own material.
static func _add_floor(room: Node3D, left: float, grow: float) -> void:
	var old := room.get_node_or_null("Floor/Mesh") as MeshInstance3D
	var body := StaticBody3D.new()
	body.name = "FloorStage"
	var width := grow + 0.3
	body.position = Vector3(left + width / 2.0 - 0.15, -0.1, 0.0)
	room.add_child(body)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, 0.2, DINING_FRONT - DINING_BACK)
	if old != null and old.mesh != null:
		mesh.material = old.mesh.surface_get_material(0)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	body.add_child(instance)
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)


# A table with a chair either side (as Table1-4 in the main scene).
static func _add_table(furniture: Node, record: Dictionary) -> void:
	var at: Array = record.get("at", [0.0, 0.0])
	var table := (load(TABLE_SCENE) as PackedScene).instantiate() as DiningTable
	table.name = "TableStage_%s" % record.get("spot", "new")
	table.spot = String(record.get("spot", ""))
	table.position = Vector3(float(at[0]), 0.0, float(at[1]))
	furniture.add_child(table)
	for side in [-1.0, 1.0]:
		var chair := (load(CHAIR_SCENE) as PackedScene).instantiate()
		chair.name = "%s%s" % [table.name, "Left" if side < 0.0 else "Right"]
		chair.set("table", table)
		chair.position = table.position + Vector3(side * CHAIR_FROM_TABLE, 0.0, 0.0)
		chair.rotation.y = deg_to_rad(-90.0 if side < 0.0 else 90.0)  # Facing the table, as Chair1Left/Right.
		furniture.add_child(chair)


# The yard scenery the room has grown over (bushes, rocks, a tree outside the
# old left wall) steps out the same distance; a tree would land in the
# neighbour's house there, so it goes.
static func _clear_yard(outside: Node, left: float) -> void:
	if outside == null:
		return
	var grow := DINING_LEFT - left
	for child in outside.get_children():
		var plant := child as Node3D
		if plant == null:
			continue
		var at := plant.position
		if at.x > left - 1.3 and at.x < DINING_LEFT + 0.2 and at.z > DINING_BACK - 0.3 and at.z < DINING_FRONT + 0.3:
			if String(plant.name).begins_with("Tree"):
				plant.visible = false
				plant.process_mode = Node.PROCESS_MODE_DISABLED
			else:
				plant.position.x -= grow


# A pendant lamp over a new table, like the ones over the first four.
static func _add_lamp(lamps: Node, record: Dictionary) -> void:
	if lamps == null or not ResourceLoader.exists(LAMP_SCENE):
		return
	var at: Array = record.get("at", [0.0, 0.0])
	var lamp := (load(LAMP_SCENE) as PackedScene).instantiate() as Node3D
	lamp.name = "PendantLampStage_%s" % record.get("spot", "new")
	lamp.position = Vector3(float(at[0]), LAMP_HEIGHT, float(at[1]))
	lamps.add_child(lamp)
