# ChalkAction: write a meal's menu on the chalkboard (MenuBoard). The board
# lies flat in the close-up with the meal's name across the top. The first few
# dishes (data/menu_board.json "traced_dishes") are the big ones in the top
# row: each is drawn by tracing its chalk outline, stroke by stroke, with the
# controls of filleting (hold the button on the ring at the start and follow
# the dots; stray too far and it slips, so hold it again where it stopped).
# Its name chalks itself in underneath when it's drawn. The rest of the menu is
# written smaller underneath, by itself, at the end. Each dot passed scores how
# close the chalk was; the menu scores their average.
# layout() and draw_icon() also draw the finished menu on the board in the room.
class_name ChalkAction
extends CookAction

const BOARD := Vector2(0.64, 0.44)          # The slate, across and deep (x, z).
const CHALK := Color(0.97, 0.97, 0.93, 0.92)
const SLATE := Color(0.16, 0.22, 0.2)
const LINE_WIDTH := 0.0045

static var _data := {}

@export var dishes: Array[Dictionary] = []  # The meal's menu (GameData.meal_menu()).
@export var meal_name := "Menu"
@export var dots_per_meter := 90.0
@export_group("Feel")
@export var perfect_offset := 0.006
@export var worst_offset := 0.03
@export var slip_offset := 0.045
@export var grab_reach := 0.035

var _slots: Array[Dictionary] = []
var _dish := 0                               # Which of the traced dishes.
var _stroke := 0
var _strokes: Array = []                     # The current dish's strokes, in session (x, z).
var _path: Array[Vector2] = []
var _t := 0.0
var _tracing := false
var _passed := 0
var _dots := 0
var _scores: Array[float] = []
var _dot_nodes: Array[MeshInstance3D] = []
var _drawn := 0                              # Path points chalked so far on this stroke.
var _ring: MeshInstance3D
var _chalk_stick: Node3D
var _dot_material := StandardMaterial3D.new()
var _done_material := StandardMaterial3D.new()
var _moving := false
var _board: Node3D


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/menu_board.json"))
	return _data


static func traced_count(total: int) -> int:
	return mini(total, int(data().get("traced_dishes", 3)))


static func strokes_for(dish_id: String) -> Array:
	var icons: Dictionary = data().get("icons", {})
	return icons.get(dish_id, icons.get("_default", []))


# Where each dish goes on a board BOARD big (its middle at 0, 0): the traced
# ones big across the top row, the rest smaller in rows underneath. Each:
# { "at": Vector2 (x, z), "size": icon size, "label": text size }.
static func layout(total: int) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	var big := traced_count(total)
	for i in big:
		slots.append({ "at": Vector2((i - (big - 1) * 0.5) * 0.2, -0.06), "size": 0.11, "label": 0.0007, "width": 0.19 })
	var rest := total - big
	if rest > 0:
		var cols := mini(rest, 6)
		var rows := ceili(rest / float(cols))
		var cell := Vector2(0.58 / cols, 0.11 / rows)
		var size := minf(cell.x * 0.55, cell.y * 0.6)
		for i in rest:
			var col := i % cols
			var row := i / cols
			var in_row := mini(cols, rest - row * cols)
			var width := minf(cell.x - size * 1.3, 0.16)
			var middle := (col - (in_row - 1) * 0.5) * cell.x
			slots.append({ "at": Vector2(middle - (size * 0.1 + width) * 0.5, 0.1 + (row + 0.5) * cell.y - 0.02), "size": size, "label": 0.0005, "beside": true, "width": width })
	return slots


static func chalk_material() -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_color = CHALK
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return paint


# A chalk line along `points` (x, z, on `parent`'s top at height y).
static func chalk_line(parent: Node3D, points: Array, y: float, width := LINE_WIDTH, paint: Material = null) -> void:
	if paint == null:
		paint = chalk_material()
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var length := a.distance_to(b)
		if length < 0.0001:
			continue
		var bit := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(length + width * 0.8, 0.0006, width)
		mesh.material = paint
		bit.mesh = mesh
		var middle := (a + b) * 0.5
		bit.position = Vector3(middle.x, y, middle.y)
		bit.rotation.y = -atan2(b.y - a.y, b.x - a.x)
		parent.add_child(bit)


# A dish's icon `size` across, its middle at `at`, chalked on `parent` at height y.
static func draw_icon(parent: Node3D, dish_id: String, at: Vector2, size: float, y: float, width := LINE_WIDTH) -> void:
	var paint := chalk_material()
	for stroke in strokes_for(dish_id):
		chalk_line(parent, _placed(stroke, at, size), y, width, paint)


# Chalk words lying flat on `parent` at (x, z) = at.
static func chalk_text(parent: Node3D, text: String, at: Vector2, y: float, pixel: float, font_size := 48, wrap_width := 0.0) -> Label3D:
	var label := Label3D.new()
	if wrap_width > 0.0:  # Long names go onto a second line.
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.width = wrap_width / pixel
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.text = text
	label.font = load("res://assets/fonts/Fredoka.ttf")
	label.font_size = font_size
	label.pixel_size = pixel
	label.modulate = CHALK
	label.outline_size = 0
	label.shaded = false
	label.double_sided = false
	label.rotation.x = -PI * 0.5
	label.position = Vector3(at.x, y, at.y)
	parent.add_child(label)
	return label


# The whole written menu, as on the board in the room: its name and every dish.
static func draw_menu(parent: Node3D, title: String, menu: Array, y: float) -> void:
	chalk_text(parent, title, Vector2(0.0, -0.175), y, 0.0016, 64)
	var slots := layout(menu.size())
	for i in menu.size():
		_draw_slot(parent, menu[i], slots[i], y)


static func _draw_slot(parent: Node3D, dish: Dictionary, slot: Dictionary, y: float) -> void:
	var at: Vector2 = slot["at"]
	var size: float = slot["size"]
	draw_icon(parent, String(dish.get("id", "")), at, size, y, LINE_WIDTH if size > 0.08 else LINE_WIDTH * 0.6)
	var label := chalk_text(parent, String(dish.get("name", "")), at + (Vector2(size * 0.6, 0.0) if slot.get("beside", false) else Vector2(0.0, size * 0.5 + 0.012)), y, slot["label"], 48, 0.0 if slot.get("beside", false) else slot.get("width", 0.0))
	if slot.get("beside", false):
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


static func _placed(stroke: Array, at: Vector2, size: float) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for p in stroke:
		points.append(at + Vector2(float(p[0]), -float(p[1])) * size)  # Up the icon is away, up the board.
	return points


func _init() -> void:
	view_distance = 0.42
	view_pitch = 62.0


func view_point() -> Vector3:
	if _slots.is_empty() or _dish >= traced_count(dishes.size()):
		return Vector3(0.0, _top(), 0.02)
	var at: Vector2 = _slots[_dish]["at"]
	return Vector3(at.x, _top(), at.y + 0.02)


func uses_cursor() -> bool:
	return false  # The chalk shows the spot.


func cursor_height() -> float:
	return _top()


func cursor_area() -> Rect2:
	return Rect2(-BOARD * 0.5, BOARD)


func _top() -> float:
	return session.work_height


func _begin() -> void:
	_board = Node3D.new()
	session.add_child(_board)
	_build_slate()
	chalk_text(_board, meal_name, Vector2(0.0, -0.175), _top() + 0.0006, 0.0016, 64)
	_slots = layout(dishes.size())
	for material in [_dot_material, _done_material]:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.no_depth_test = true
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dot_material.albedo_color = Color(1.0, 0.95, 0.5, 0.95)
	_done_material.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	_ring = session.make_ring(0.016, Color(0.6, 1.0, 0.55, 0.95))
	_chalk_stick = _make_chalk()
	session.add_child(_chalk_stick)
	_chalk_stick.position = Vector3(0.2, _top() + 0.04, 0.15)
	if traced_count(dishes.size()) == 0:
		_write_the_rest()
		return
	_start_dish(0)


func end() -> void:
	if is_instance_valid(_ring):
		_ring.queue_free()
	if is_instance_valid(_chalk_stick):
		_chalk_stick.queue_free()
	_clear_dots()


func update(delta: float, input: CookInput) -> void:
	var spot := Vector2(input.cursor.x, input.cursor.z)
	_chalk_stick.position = _chalk_stick.position.lerp(Vector3(spot.x, _top() + (0.004 if _tracing else 0.03), spot.y), 1.0 - exp(-24.0 * delta))
	if _moving or done or _path.is_empty():
		return
	_ring.position = _point3(_t)
	_ring.visible = not _tracing
	session.set_status("%s: line %d of %d" % [String(dishes[_dish].get("name", "")), _stroke + 1, _strokes.size()])
	if not _tracing:
		if input.just_pressed and spot.distance_to(_point(_t)) <= grab_reach:
			_tracing = true
			session.play_sound("tick", _point3(_t), -10.0, 1.6)
		return
	if not input.held:
		_tracing = false
		return
	var along := _nearest_t(spot)
	var off := spot.distance_to(_point(along))
	if off > slip_offset:
		_tracing = false
		session.pop_text("Slipped!", _point3(_t), -1)
		return
	if along > _t and along - _t < 0.2:
		_t = along
		var score := 1.0 - clampf((off - perfect_offset) / (worst_offset - perfect_offset), 0.0, 1.0)
		while _passed < _dots and float(_passed) / maxf(_dots - 1, 1) <= _t + 0.001:
			_dot_nodes[_passed].material_override = _done_material
			_scores.append(score)
			_passed += 1
		_chalk_to(_t)
		if _passed >= _dots or _t >= 0.98:
			_finish_stroke()


func _start_dish(index: int) -> void:
	_dish = index
	var slot := _slots[index]
	_strokes = []
	for stroke in strokes_for(String(dishes[index].get("id", ""))):
		_strokes.append(_placed(stroke, slot["at"], slot["size"]))
	if index > 0:
		session.frame(view_point(), view_distance, view_pitch, 0.35)
	_start_stroke(0)


func _start_stroke(index: int) -> void:
	_stroke = index
	_t = 0.0
	_passed = 0
	_drawn = 0
	_tracing = false
	_clear_dots()
	_path = _even(_strokes[index], 80)
	var length := 0.0
	for i in _path.size() - 1:
		length += _path[i].distance_to(_path[i + 1])
	_dots = clampi(roundi(length * dots_per_meter), 3, 16)
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.0028
	dot_mesh.height = 0.0056
	for i in _dots:
		var dot := MeshInstance3D.new()
		dot.mesh = dot_mesh
		dot.material_override = _dot_material
		dot.position = _point3(float(i) / maxf(_dots - 1, 1))
		session.add_child(dot)
		_dot_nodes.append(dot)


func _finish_stroke() -> void:
	_tracing = false
	while _passed < _dots:
		_scores.append(_scores[-1] if not _scores.is_empty() else 1.0)
		_passed += 1
	_chalk_to(1.0)
	_clear_dots()
	if _stroke + 1 < _strokes.size():
		_start_stroke(_stroke + 1)
		return
	# The dish is drawn: its name chalks itself in underneath.
	var dish := dishes[_dish]
	var slot := _slots[_dish]
	var at: Vector2 = slot["at"]
	var label := chalk_text(_board, String(dish.get("name", "")), at + Vector2(0.0, float(slot["size"]) * 0.5 + 0.012), _top() + 0.0006, slot["label"], 48, slot.get("width", 0.0))
	label.modulate.a = 0.0
	label.create_tween().tween_property(label, "modulate:a", CHALK.a, 0.3)
	session.play_sound("plop", Vector3(at.x, _top(), at.y), -10.0, 1.5)
	_path.clear()
	_ring.visible = false
	if _dish + 1 < traced_count(dishes.size()):
		_moving = true
		await session.get_tree().create_timer(0.3).timeout
		_moving = false
		_start_dish(_dish + 1)
	else:
		_write_the_rest()


# The smaller dishes underneath, written one after another by themselves.
func _write_the_rest() -> void:
	_moving = true
	session.frame(Vector3(0.0, _top(), 0.0), 0.62, 64.0, 0.4)
	var big := traced_count(dishes.size())
	for i in range(big, dishes.size()):
		await session.get_tree().create_timer(0.12).timeout
		var holder := Node3D.new()
		_board.add_child(holder)
		_draw_slot(holder, dishes[i], _slots[i], _top() + 0.0006)
		session.play_sound("tick", Vector3.ZERO, -14.0, 1.8)
	await session.get_tree().create_timer(0.4).timeout
	var score := average(_scores) if not _scores.is_empty() else 1.0
	session.pop_text("Menu's up!" if score >= 0.7 else "A bit wobbly!", Vector3(0.0, _top(), 0.02), CookSession.mood_of(score))
	finish(score)


# Chalk down the stroke as far as `t`.
func _chalk_to(t: float) -> void:
	var upto := clampi(ceili(t * (_path.size() - 1)), 0, _path.size() - 1)
	if upto <= _drawn:
		return
	chalk_line(_board, _path.slice(_drawn, upto + 1), _top() + 0.0006)
	_drawn = upto


func scripted_hold(delta: float, input: CookInput) -> bool:
	if _moving or done or _path.is_empty():
		return false
	if not _tracing:
		return input.move_to(_point3(_t), delta, 1.0) and not input.held
	input.move_to(_point3(minf(_t + 0.08, 1.0)), delta, 0.25)
	return true


func _point(t: float) -> Vector2:
	var at := clampf(t, 0.0, 1.0) * (_path.size() - 1)
	var i := mini(floori(at), _path.size() - 2)
	return _path[i].lerp(_path[i + 1], at - i)


func _point3(t: float) -> Vector3:
	var p := _point(t)
	return Vector3(p.x, _top() + 0.002, p.y)


func _nearest_t(spot: Vector2) -> float:
	var best := _t
	var best_gap := INF
	for i in _path.size():
		var t := float(i) / (_path.size() - 1)
		if t < _t - 0.05 or t > _t + 0.25:
			continue
		var gap := spot.distance_squared_to(_path[i])
		if gap < best_gap:
			best_gap = gap
			best = t
	return best


func _even(points: Array, count: int) -> Array[Vector2]:
	var lengths: Array[float] = [0.0]
	for i in range(1, points.size()):
		lengths.append(lengths[-1] + (points[i] as Vector2).distance_to(points[i - 1]))
	var total := lengths[-1]
	var out: Array[Vector2] = []
	var j := 0
	for k in count + 1:
		var want := total * k / count
		while j < points.size() - 2 and lengths[j + 1] < want:
			j += 1
		var span := lengths[j + 1] - lengths[j]
		out.append((points[j] as Vector2).lerp(points[j + 1], 0.0 if span <= 0.0 else (want - lengths[j]) / span))
	return out


func _clear_dots() -> void:
	for dot in _dot_nodes:
		if is_instance_valid(dot):
			dot.queue_free()
	_dot_nodes.clear()


# The slate in a wooden frame, lying flat in the close-up.
func _build_slate() -> void:
	var slate := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(BOARD.x, 0.012, BOARD.y)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = SLATE
	paint.roughness = 0.95
	mesh.material = paint
	slate.mesh = mesh
	slate.position.y = _top() - 0.006
	_board.add_child(slate)
	var wood := KitchenProps.board_wood()
	for side in [Vector4(0, -1, BOARD.x + 0.06, 0.03), Vector4(0, 1, BOARD.x + 0.06, 0.03), Vector4(-1, 0, 0.03, BOARD.y), Vector4(1, 0, 0.03, BOARD.y)]:
		var rail := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(side.z, 0.022, side.w)
		box.material = wood
		rail.mesh = box
		rail.position = Vector3(side.x * (BOARD.x + 0.03) * 0.5, _top() - 0.002, side.y * (BOARD.y + 0.03) * 0.5)
		_board.add_child(rail)


func _make_chalk() -> Node3D:
	var stick := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.004
	mesh.bottom_radius = 0.004
	mesh.height = 0.04
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.98, 0.98, 0.95)
	paint.roughness = 1.0
	mesh.material = paint
	stick.mesh = mesh
	stick.rotation.z = deg_to_rad(-30.0)
	var holder := Node3D.new()
	stick.position = Vector3(0.01, 0.017, 0.0)
	holder.add_child(stick)
	return holder
