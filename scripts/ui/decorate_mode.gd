# DecorateMode: After Hours, one chef places decor while the camera looks down
# on the room. A cursor moves over the grid (move keys or stick, or the mouse).
# Everything sits on the floor's squares, drawn while decorating, and fills
# whole squares. Interact puts down what's held, or picks up what's under the
# cursor; held down on something placed, it drags it, and letting go drops it
# there (or back where it was, if it can't go there). Next
# takes something out of storage, rotate turns it, store puts it back, done
# finishes. With the mouse: left click, right click to rotate, wheel for next.
# The square under the cursor is green where it can go and red where it can't.
# Wall decor goes to the nearest free wall spot.
class_name DecorateMode
extends CanvasLayer

signal finished

const MOVE_REPEAT := 0.13
const DRAG_REPEAT := 0.26  # Slower while dragging, so it's easy to stop on the right square.
const HOLD_SECONDS := 0.22  # Held this long, a pick-up is a drag.
const HOVER_RANGE := 0.7  # How near the cursor wall decor counts as under it.
const OK_COLOR := Color(0.3, 0.85, 0.4, 0.45)
const NO_COLOR := Color(0.9, 0.25, 0.2, 0.45)
const HOVER_COLOR := Color(1.0, 0.8, 0.3, 0.45)

var player: Player
var room: DecorRoom
var view_manager: ViewManager

var held := ""            # The item id in hand, "" for none.
var turn := 0
var cursor := Vector2.ZERO

var _move_left := 0.0
var _drag: Dictionary = {}  # What's being dragged, as it was placed. Empty when nothing is.
var _drag_time := 0.0
var _hand_before := ""    # What was in hand before the drag, back in hand after it.
var _grid := MeshInstance3D.new()
var _ghost: Node3D
var _marker := MeshInstance3D.new()
var _marker_material := StandardMaterial3D.new()
var _label := Label.new()


func setup(chef: Player, decor_room: DecorRoom, views: ViewManager) -> void:
	player = chef
	room = decor_room
	view_manager = views


func _ready() -> void:
	layer = 20
	var look: Dictionary = Decor.settings().get("camera", {})
	var zoom := CameraZoomSettings.new()
	zoom.distance = float(look.get("distance", 15.0))
	zoom.pitch_degrees = float(look.get("pitch", 62.0))
	zoom.duration = 0.5
	var center: Array = look.get("center", [0, 0, 0])
	player.decorating = true
	player.movement_locked = true
	player.request_camera_focus(Vector3(center[0], center[1], center[2]), zoom)
	room.collect_stations()

	var plane := PlaneMesh.new()
	_marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	plane.material = _marker_material
	_marker.mesh = plane
	room.add_sibling(_marker)
	_build_grid()

	var panel := PanelContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -44.0  # Above the join hint.
	_label.add_theme_font_size_override("font_size", 18)
	panel.add_child(_label)
	cursor = Vector2(-5.0, -3.5)
	_next_item()
	_refresh()


# The squares, drawn on the floor.
func _build_grid() -> void:
	var cell := float(Decor.settings()["grid"]["cell"])
	var origin := Decor.grid_origin()
	var cells := Decor.grid_cells()
	var size := Vector2(cells) * cell
	var points := PackedVector3Array()
	for x in cells.x + 1:
		points.append(Vector3(origin.x + x * cell, 0.04, origin.y))
		points.append(Vector3(origin.x + x * cell, 0.04, origin.y + size.y))
	for z in cells.y + 1:
		points.append(Vector3(origin.x, 0.04, origin.y + z * cell))
		points.append(Vector3(origin.x + size.x, 0.04, origin.y + z * cell))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 1.0, 1.0, 0.3)
	mesh.surface_set_material(0, material)
	_grid.mesh = mesh
	room.add_sibling(_grid)


func _action(name: String) -> String:
	return InputSetup.action_name(player.player_index, name)


func _process(delta: float) -> void:
	_move_left -= delta
	if not _drag.is_empty():
		_drag_time += delta
	var move := Input.get_vector(_action("move_left"), _action("move_right"), _action("move_up"), _action("move_down"))
	if move.length() > 0.4 and _move_left <= 0.0:
		_move_left = MOVE_REPEAT if _drag.is_empty() else DRAG_REPEAT
		var cell := float(Decor.settings()["grid"]["cell"])
		_move_cursor(cursor + Vector2(signf(move.x) if absf(move.x) > 0.4 else 0.0, signf(move.y) if absf(move.y) > 0.4 else 0.0) * cell)


func _move_cursor(to: Vector2) -> void:
	var grid: Dictionary = Decor.settings()["grid"]
	var cell := float(grid["cell"])
	var snapped_to := Vector2(snappedf(to.x - 0.25, cell) + 0.25, snappedf(to.y - 0.25, cell) + 0.25)
	cursor = snapped_to.clamp(Vector2(grid["min"][0], grid["min"][1]), Vector2(grid["max"][0], grid["max"][1]))
	_refresh()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(_action("interact")):
		use()
	elif event.is_action_released(_action("interact")):
		release()
	elif event.is_action_pressed(_action("decor_rotate")):
		rotate_item()
	elif event.is_action_pressed(_action("decor_next")):
		_next_item()
		_refresh()
	elif event.is_action_pressed(_action("decor_store")):
		store()
	elif event.is_action_pressed(_action("decor_done")):
		finish()
	elif event is InputEventMouseMotion:
		var point = _mouse_point()
		if point != null:
			_move_cursor(point)
	elif event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			release()
	elif event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				use()
			MOUSE_BUTTON_RIGHT:
				rotate_item()
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				_next_item()
				_refresh()
	else:
		return
	get_viewport().set_input_as_handled()


# Where the mouse is on the floor, or null.
func _mouse_point() -> Variant:
	var rig := view_manager.rig_for(player.player_index) if view_manager != null else null
	if rig == null:
		return null
	var mouse := rig.camera.get_viewport().get_mouse_position()
	var origin := rig.camera.project_ray_origin(mouse)
	var direction := rig.camera.project_ray_normal(mouse)
	if absf(direction.y) < 0.01:
		return null
	var hit := origin + direction * (-origin.y / direction.y)
	return Vector2(hit.x, hit.z)


func item_held() -> Dictionary:
	return Decor.get_item(held)


# The next thing in storage, then nothing, then round again.
func _next_item() -> void:
	if not _drag.is_empty():
		return
	var stored: Array = GameState.decor_stored.keys().filter(func(id): return int(GameState.decor_stored[id]) > 0 and not Decor.get_item(id).is_empty())
	stored.sort()
	stored.append("")
	held = stored[(stored.find(held) + 1) % stored.size()]
	_show_ghost()


func _show_ghost() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	if not held.is_empty():
		_ghost = Decor.build(item_held())
		room.add_sibling(_ghost)


func rotate_item() -> void:
	turn = posmod(turn + 90, 360)
	_refresh()


# Where what's held goes on the floor: on the squares, nearest the cursor.
func drop_point() -> Vector2:
	return Decor.snap(item_held(), cursor, turn)


# The free wall spot nearest the cursor, or -1.
func nearest_spot() -> int:
	var best := -1
	var best_distance := INF
	for spot in Decor.settings().get("wall_spots", []).size():
		var at := Decor.spot_position(spot)
		var distance := Vector2(at.x, at.z).distance_to(cursor)
		if distance < best_distance and not Decor.spot_taken(spot):
			best = spot
			best_distance = distance
	return best


# Whether what's held can go down here.
func can_place() -> bool:
	var item := item_held()
	if item.is_empty():
		return false
	if item.get("kind", "floor") == "wall":
		return nearest_spot() >= 0
	return room.can_go(item, drop_point(), turn)


# The placed decor under the cursor (its index in decor_placed), or -1.
func hovered() -> int:
	var best := -1
	var best_distance := HOVER_RANGE
	for i in GameState.decor_placed.size():
		var placed: Dictionary = GameState.decor_placed[i]
		var spot := int(placed.get("spot", -1))
		var at := Vector2(float(placed.get("x", 0.0)), float(placed.get("z", 0.0)))
		var under := false
		if spot >= 0:
			var wall := Decor.spot_position(spot)
			at = Vector2(wall.x, wall.z)
			under = at.distance_to(cursor) <= HOVER_RANGE
		else:
			var size := Decor.footprint(Decor.get_item(String(placed.get("id", ""))), int(placed.get("turn", 0)))
			under = Rect2(at - size * 0.5, size).has_point(cursor)
		var distance := at.distance_to(cursor)
		if under and distance <= best_distance:
			best = i
			best_distance = distance
	return best


# Interact: put down what's held, or pick up what's here (what's in hand is
# in storage anyway, so nothing's lost by swapping).
func use() -> void:
	if held.is_empty() or not can_place():
		_lift()
		return
	_drag = {}  # Put down by hand: nothing left to drop when the button comes up.
	_put_down()
	if int(GameState.decor_stored.get(held, 0)) <= 0:
		held = ""
		_show_ghost()
	_refresh()


func _lift() -> void:
	var index := hovered()
	if index < 0:
		return
	var placed: Dictionary = GameState.decor_placed[index]
	GameState.decor_take_back(index)
	_hand_before = held
	held = String(placed["id"])
	turn = int(placed.get("turn", 0))
	_drag = placed.duplicate()
	_drag_time = 0.0
	if int(placed.get("spot", -1)) < 0:
		cursor = Decor.cursor_on(item_held(), Vector2(float(placed["x"]), float(placed["z"])), turn)
	_show_ghost()
	room.refresh()
	_refresh()


func _put_down() -> void:
	var wall: bool = item_held().get("kind", "floor") == "wall"
	var point := drop_point()
	GameState.decor_place(held, point.x, point.y, turn, nearest_spot() if wall else -1)
	room.refresh()


# The button came up: a quick tap leaves it in hand, a drag drops it here, or
# back where it was if it can't go here.
func release() -> void:
	if _drag.is_empty():
		return
	var from := _drag
	_drag = {}
	if _drag_time < HOLD_SECONDS:
		return
	if can_place():
		_put_down()
	else:
		_put_back(from)
	held = _hand_before if int(GameState.decor_stored.get(_hand_before, 0)) > 0 else ""
	_show_ghost()
	_refresh()


func _put_back(from: Dictionary) -> void:
	GameState.decor_place(String(from["id"]), float(from["x"]), float(from["z"]), int(from.get("turn", 0)), int(from.get("spot", -1)))
	room.refresh()


# Store: what's being dragged, or what's under the cursor, goes into storage.
# Over nothing, it just empties the hand (what's in hand is in storage anyway).
func store() -> void:
	var index := hovered()
	if not _drag.is_empty():  # Already in storage, from when it was lifted.
		_drag = {}
		held = _hand_before if int(GameState.decor_stored.get(_hand_before, 0)) > 0 else ""
		_show_ghost()
	elif index >= 0:
		GameState.decor_take_back(index)
		room.refresh()
	elif not held.is_empty():
		held = ""
		_show_ghost()
	_refresh()


func finish() -> void:
	if not _drag.is_empty():
		_put_back(_drag)
	if _ghost != null:
		_ghost.queue_free()
	_marker.queue_free()
	_grid.queue_free()
	player.decorating = false
	player.movement_locked = false
	player.ignore_interact_until_released()
	player.release_camera_focus()
	SaveGame.save_game()
	finished.emit()
	queue_free()


func _refresh() -> void:
	var item := item_held()
	var wall: bool = item.get("kind", "floor") == "wall"
	var point := drop_point() if not item.is_empty() else cursor
	var at := Vector3(point.x, 0.05, point.y)
	var size := Decor.footprint(item, turn) if not item.is_empty() else Vector2(0.5, 0.5)
	var color := HOVER_COLOR if item.is_empty() and hovered() >= 0 else (Color(1, 1, 1, 0.3) if item.is_empty() else (OK_COLOR if can_place() else NO_COLOR))
	if wall and nearest_spot() >= 0:
		var spot := nearest_spot()
		var wall_at := Decor.spot_position(spot)
		at = Vector3(wall_at.x, 0.05, wall_at.z)
		if _ghost != null:
			_ghost.position = wall_at
			_ghost.rotation_degrees.y = Decor.spot_turn(spot)
	elif _ghost != null:
		_ghost.position = Vector3(point.x, 0.0, point.y)
		_ghost.rotation_degrees.y = turn
	_marker.position = at
	(_marker.mesh as PlaneMesh).size = size
	_marker_material.albedo_color = color
	var lines := PackedStringArray()
	lines.append("Decorating  (decor score %d)" % Decor.score())
	if item.is_empty():
		lines.append("In hand: nothing")
	else:
		lines.append("In hand: %s (%d in storage)" % [item.get("name", "?"), int(GameState.decor_stored.get(held, 0))])
	lines.append(InputSetup.decor_hint(player.player_index))
	_label.text = "\n".join(lines)
