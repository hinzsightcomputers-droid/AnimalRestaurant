# RestaurantGrounds: the outdoors the chefs can walk around after hours, and
# the doors to it. Builds solid ground outside, an invisible fence around the
# grounds (the street and the trees past it stay scenery), the back door (a
# door in the dining room's back wall that swings open), the front doorway,
# and the open/closed sign by the front door. During service the doors keep
# the chefs in (customers walk through as always); once the day's done
# (DayCycle.doors_open) they're open. The sign flips with the day, and once
# 5 AM has been it opens up for the new day.
class_name RestaurantGrounds
extends Node3D

const FRONT_DOOR := Vector3(5.0, 0.0, 5.15)   # The gap in the front wall.
const FRONT_DOOR_WIDTH := 1.4
const BACK_DOOR := Vector3(-3.3, 0.0, -5.15)  # The doorway in the dining room's back wall.
const BACK_DOOR_WIDTH := 1.2
const DOOR_MODEL := "res://design/assets/KayKit_Bits_Bundle1_1.1/Restaurant Bits/Assets/gltf/door_A.gltf"
const DOOR_SIZE := Vector3(1.1, 0.0, 0.0)  # Fit by width; it keeps its proportions.
const DOOR_OPEN_DEGREES := 95.0  # Swings out, away from the room.
# The grounds: walkable ground and the fence around them (x and z, meters).
const GROUNDS_MIN := Vector2(-22.0, -20.0)
const GROUNDS_MAX := Vector2(22.0, 10.6)   # Up to the curb; wide enough for the regulars' houses either side.
const SIGN_SPOT := Vector3(3.9, 0.0, 5.75)  # Outside, just left of the front door.
const FRONT_WALL_MODEL := "res://design/assets/KayKit_Bits_Bundle1_1.1/Restaurant Bits/Assets/gltf/wall.gltf"
const FRONT_WINDOW_MODEL := "res://design/assets/KayKit_Bits_Bundle1_1.1/Restaurant Bits/Assets/gltf/wall_window_closed_curtains_red.gltf"
const TALL_FRONT_LAYER := 15  # Render layers: the full-height front wall, for views outside...
const LOW_FRONT_LAYER := 16   # ...and the room's low one, for views inside.
const SIDE_WALL_LAYER := 18   # The right-hand walls, hidden from inside views when the camera looks in over them (CameraRig.VIEW_YAW).
const SIDE_WALLS := ["RestaurantRoom/Walls/RightWall", "RestaurantRoom/Kitchen/RightWall"]
# Inside the restaurant (x and z): the dining room, then the kitchen (before
# any stage: outdoors() adds what Stages.grown_left knocked through).
const INDOORS: Array[Rect2] = [Rect2(-7.15, -5.15, 14.3, 10.3), Rect2(0.85, -11.45, 6.3, 6.3)]

@export var day_manager: DayManager

var _barriers: Array[CollisionShape3D] = []  # One per door: solid during service.
var _back_door_hinge: Node3D
var _sign_board: Node3D
var _sign_open := false
var _doors_open := false


func _ready() -> void:
	StageLayout.apply(get_parent())  # First: the walls a stage adds get their layers below.
	_build_ground()
	_build_fence()
	_barriers.append(_door_barrier(FRONT_DOOR, FRONT_DOOR_WIDTH))
	_barriers.append(_door_barrier(BACK_DOOR, BACK_DOOR_WIDTH))
	_build_back_door()
	_build_sign()
	_build_tall_front_wall()
	_refresh(true)


func _process(_delta: float) -> void:
	_refresh(false)


# Doors and sign to match the day (at once on the first call).
func _refresh(instant: bool) -> void:
	var doors_open := DayCycle.doors_open()
	if doors_open != _doors_open or instant:
		_doors_open = doors_open
		for barrier in _barriers:
			barrier.disabled = doors_open
		var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(_back_door_hinge, "rotation:y", deg_to_rad(DOOR_OPEN_DEGREES) if doors_open else 0.0, 0.01 if instant else 0.7)
	var sign_open := DayCycle.is_open()
	if sign_open != _sign_open or instant:
		_sign_open = sign_open
		_paint_sign(instant)


func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GROUNDS_MAX.x - GROUNDS_MIN.x + 4.0, 0.2, GROUNDS_MAX.y - GROUNDS_MIN.y + 4.0)
	shape.shape = box
	shape.position = Vector3((GROUNDS_MIN.x + GROUNDS_MAX.x) / 2.0, -0.1, (GROUNDS_MIN.y + GROUNDS_MAX.y) / 2.0)
	body.add_child(shape)
	add_child(body)


func _build_fence() -> void:
	var body := StaticBody3D.new()
	body.name = "Fence"
	var width := GROUNDS_MAX.x - GROUNDS_MIN.x
	var depth := GROUNDS_MAX.y - GROUNDS_MIN.y
	var middle := Vector2((GROUNDS_MIN.x + GROUNDS_MAX.x) / 2.0, (GROUNDS_MIN.y + GROUNDS_MAX.y) / 2.0)
	for side in [
		[Vector3(middle.x, 1.5, GROUNDS_MIN.y), Vector3(width, 3.0, 0.3)],
		[Vector3(middle.x, 1.5, GROUNDS_MAX.y), Vector3(width, 3.0, 0.3)],
		[Vector3(GROUNDS_MIN.x, 1.5, middle.y), Vector3(0.3, 3.0, depth)],
		[Vector3(GROUNDS_MAX.x, 1.5, middle.y), Vector3(0.3, 3.0, depth)],
	]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = side[1]
		shape.shape = box
		shape.position = side[0]
		body.add_child(shape)
	add_child(body)


# An invisible wall across a doorway, for while the chefs should stay in.
func _door_barrier(at: Vector3, width: float) -> CollisionShape3D:
	var body := StaticBody3D.new()
	body.name = "DoorBarrier"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 3.0, 0.3)
	shape.shape = box
	shape.position = at + Vector3(0.0, 1.5, 0.0)
	body.add_child(shape)
	add_child(body)
	return shape


# A door hung on the left of the back doorway, swinging out into the yard.
func _build_back_door() -> void:
	_back_door_hinge = Node3D.new()
	_back_door_hinge.name = "BackDoor"
	_back_door_hinge.position = BACK_DOOR + Vector3(-DOOR_SIZE.x / 2.0, 0.0, 0.0)
	add_child(_back_door_hinge)
	ModelFit.place(DOOR_MODEL, _back_door_hinge, Vector3(DOOR_SIZE.x / 2.0, 0.0, 0.0), DOOR_SIZE)


# A little board on a post, with OPEN or CLOSED on both faces.
func _build_sign() -> void:
	var spot := Node3D.new()
	spot.name = "OpenSign"
	spot.position = SIGN_SPOT
	add_child(spot)
	var post := MeshInstance3D.new()
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.08, 1.2, 0.08)
	post.mesh = post_mesh
	post.position.y = 0.6
	post.material_override = _material(Color(0.36, 0.25, 0.17))
	spot.add_child(post)
	_sign_board = Node3D.new()
	_sign_board.position.y = 1.35
	spot.add_child(_sign_board)
	var board := MeshInstance3D.new()
	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(0.9, 0.42, 0.05)
	board.mesh = board_mesh
	board.material_override = _material(Color(0.95, 0.9, 0.78))
	_sign_board.add_child(board)
	for facing in [1.0, -1.0]:
		var label := Label3D.new()
		label.name = "Front" if facing > 0.0 else "Back"
		label.font_size = 64
		label.pixel_size = 0.004
		label.outline_size = 0
		label.position.z = 0.03 * facing
		label.rotation.y = 0.0 if facing > 0.0 else PI
		_sign_board.add_child(label)
	var interactable := Interactable.new()
	interactable.prompt_for_player = func(_player_index: int) -> String:
		return "Open up for a new day" if DayCycle.is_new_day_waiting() else ""
	interactable.interacted.connect(func(_player_index: int):
		if day_manager != null:
			day_manager.start_next_day())
	spot.add_child(interactable)


# OPEN in green or CLOSED in red, flipping the board over unless `instant`.
func _paint_sign(instant: bool) -> void:
	for label in _sign_board.get_children():
		if label is Label3D:
			label.text = "OPEN" if _sign_open else "CLOSED"
			label.modulate = Color(0.2, 0.6, 0.25) if _sign_open else Color(0.8, 0.2, 0.18)
	if instant:
		return
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sign_board.rotation.x = 0.0
	tween.tween_property(_sign_board, "rotation:x", TAU, 0.6)
	tween.tween_callback(func(): _sign_board.rotation.x = 0.0)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material


# The front wall at full height, with windows and a lintel over the doorway,
# for the views of chefs who are outside (the room's own front wall is low, so
# the camera can see in from the front). Each wall is on its own render layer
# and CameraRig shows one or the other.
func _build_tall_front_wall() -> void:
	var tall := Node3D.new()
	tall.name = "TallFrontWall"
	add_child(tall)
	var window: PackedScene = load(FRONT_WINDOW_MODEL)
	var wall: PackedScene = load(FRONT_WALL_MODEL)
	var left_end := -7.3 - Stages.grown_left()
	var door_left := FRONT_DOOR.x - FRONT_DOOR_WIDTH / 2.0
	var door_right := FRONT_DOOR.x + FRONT_DOOR_WIDTH / 2.0
	var windows := 4 + roundi(Stages.grown_left() / 3.0)  # About 3 m a window, as before a stage.
	_wall_grid(tall, window, Vector3((left_end + door_left) / 2.0, 0.0, FRONT_DOOR.z), windows, (door_left - left_end) / windows)
	_wall_grid(tall, wall, Vector3((door_right + 7.3) / 2.0, 0.0, FRONT_DOOR.z), 1, 7.3 - door_right)
	var lintel := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(FRONT_DOOR_WIDTH, 0.8, 0.32)
	mesh.material = _material(Color(0.96, 0.9, 0.79))
	lintel.mesh = mesh
	lintel.position = FRONT_DOOR + Vector3(0.0, 2.6, 0.0)
	tall.add_child(lintel)
	_put_on_layer(tall, TALL_FRONT_LAYER)
	var low := get_parent().get_node_or_null("RestaurantRoom/Walls/FrontWall")
	if low != null:
		_put_on_layer(low, LOW_FRONT_LAYER)
	for path in SIDE_WALLS:
		var side := get_parent().get_node_or_null(path)
		if side != null:
			_put_on_layer(side, SIDE_WALL_LAYER)


func _wall_grid(parent: Node3D, model: PackedScene, at: Vector3, count: int, width: float) -> void:
	var grid := ModelGrid.new()
	grid.position = at
	parent.add_child(grid)
	grid.cells = Vector2i(count, 1)
	grid.cell_size = Vector3(width, 3.0, 0.32)
	grid.model = model


# Every mesh under `node` only on render layer `layer`, and the tall one casts no shadow into the room.
static func _put_on_layer(node: Node, layer: int) -> void:
	for mesh in node.find_children("*", "VisualInstance3D", true, false):
		(mesh as VisualInstance3D).layers = 1 << (layer - 1)
		if layer == TALL_FRONT_LAYER and mesh is GeometryInstance3D:
			(mesh as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# Whether a point's outdoors (not in the dining room or the kitchen).
static func outdoors(point: Vector3) -> bool:
	var grown := Stages.grown_left()
	for area: Rect2 in INDOORS:
		if grown > 0.0 and area == INDOORS[0]:
			area = Rect2(area.position.x - grown, area.position.y, area.size.x + grown, area.size.y)
		if area.has_point(Vector2(point.x, point.z)):
			return false
	return true
