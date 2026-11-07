# PeelAction: peel a carrot lying on the board, one side at a time. Hold the
# button and drag the peeler along it left to right, end to end (dragging back
# doesn't peel): the skin under the blade curls off in strips and lands on
# the board beside it. Once the side facing up is bare the carrot rolls a
# quarter turn to the next, `sides` in all. A side scores how straight the
# strokes ran down the middle of the carrot and how few it took. Leaves the
# peeled carrot in the session's context "carrot" (see ChopAction.lay_along)
# for chopping.
class_name PeelAction
extends CookAction

@export var on_surface := "Board"
@export var sides := 4
@export var segments := 10                 # Strips of skin along each side.
@export_group("Carrot")
@export var length := 0.34
@export var radius := 0.034
@export var taper := 0.45                  # How much thinner the right end is.
@export var skin_darken := 0.28            # The skin is the ingredients' color this much darker...
@export var flesh_lighten := 0.12          # ...and the peeled carrot this much lighter.
@export var carrot_color := Color(0.94, 0.54, 0.17)  # When there are no ingredients to take it from.
@export_group("Feel")
@export var line_tolerance := 0.012        # Meters off the middle line a stroke can wander for full marks...
@export var worst_wander := 0.045          # ...and the wander that gets none.
@export var extra_stroke_cost := 0.12      # Taken off a side for each stroke after the first.
@export var peel_margin := 0.02            # How far beside the carrot the peeler still peels.
@export var roll_seconds := 0.35
@export var peeler_height := 0.03          # How high the peeler hovers when not pressed.

var _carrot: Node3D                        # Laid along the board (see ChopAction.lay_along).
var _spin := Node3D.new()                  # Turns the carrot about its length, a side at a time.
var _left := 0.0
var _right := 0.0
var _z := 0.0
var _board_y := 0.0
var _side := 0
var _strips: Array = []                    # Per side: its skin strips (null once peeled), left to right.
var _rolling := false
var _peeler: Node3D
var _last_x := 0.0
var _was_peeling := false
var _told_direction := false               # Said "Left to right!" this stroke.
var _strokes := 0
var _wander: Array[float] = []
var _scores: Array[float] = []
var _skin: StandardMaterial3D
var _flesh_color := Color.WHITE
var _scripted_stroke := false             # A reel's peeler is on its way along, pressed.


func _init() -> void:
	view_distance = 0.5  # Close in on the carrot.
	view_pitch = 58.0


func view_point() -> Vector3:
	return Vector3((_left + _right) * 0.5, _board_y, _z)


func _begin() -> void:
	var board := session.surface(on_surface).position
	_board_y = board.y
	_left = board.x - length * 0.5
	_right = board.x + length * 0.5
	_z = board.z
	var color := session.ingredients.color() if session.ingredients != null else carrot_color
	_flesh_color = color.lightened(flesh_lighten)
	_skin = StandardMaterial3D.new()
	_skin.albedo_color = color.darkened(skin_darken)
	_skin.roughness = 0.9
	_skin.cull_mode = BaseMaterial3D.CULL_DISABLED
	_carrot = Node3D.new()
	session.add_child(_carrot)
	ChopAction.lay_along(_carrot, _left, _right, radius, radius * (1.0 - taper), _z, _board_y)
	_carrot.add_child(_spin)
	var core := MeshInstance3D.new()
	var core_mesh := CylinderMesh.new()
	core_mesh.bottom_radius = radius
	core_mesh.top_radius = radius * (1.0 - taper)
	core_mesh.height = length
	core_mesh.radial_segments = 16
	core_mesh.rings = 1
	var flesh := StandardMaterial3D.new()
	flesh.albedo_color = _flesh_color
	flesh.roughness = 0.6
	core_mesh.material = flesh
	core.mesh = core_mesh
	core.rotation.z = -PI * 0.5  # Its thin end to the right.
	_spin.add_child(core)
	for side in sides:
		var strips := []
		for i in segments:
			var strip := MeshInstance3D.new()
			strip.mesh = _strip_mesh(i, side)
			strip.set_meta("centre", _strip_centre(i, side))
			_spin.add_child(strip)
			strips.append(strip)
		_strips.append(strips)
	_peeler = _make_peeler()
	_peeler.position = Vector3(board.x, _top() + peeler_height, _z + 0.08)


func end() -> void:
	_peeler.queue_free()


func cursor_area() -> Rect2:
	return Rect2(_left, _z, length, 0.0).grow_individual(0.04, radius + 0.04, 0.04, radius + 0.04)


func cursor_height() -> float:
	return _top()


# For a reel: one straight stroke down the middle of each side, left to right.
func scripted_hold(delta: float, input: CookInput) -> bool:
	if _rolling or _side >= sides:
		_scripted_stroke = false
		return false
	if not _scripted_stroke:
		_scripted_stroke = input.move_to(Vector3(_left - peel_margin * 0.5, 0.0, _z), delta, 1.5)
		return false
	if input.move_to(Vector3(_right + peel_margin * 0.5, 0.0, _z), delta, 0.7):
		_scripted_stroke = false
	return true


func update(delta: float, input: CookInput) -> void:
	session.set_status("Sides peeled: %d of %d" % [_side, sides])
	var over := absf(input.cursor.z - _z) <= radius + peel_margin \
		and input.cursor.x >= _left - peel_margin and input.cursor.x <= _right + peel_margin
	var peeling := input.held and over and not _rolling and _side < sides
	var lift := 0.0 if peeling else peeler_height
	var goal := Vector3(input.cursor.x, _top_at(input.cursor.x) + lift, input.cursor.z)
	_peeler.position = _peeler.position.lerp(goal, 1.0 - exp(-25.0 * delta))
	if peeling:
		if not _was_peeling:
			_strokes += 1
			_told_direction = false
			_last_x = input.cursor.x
		_wander.append(absf(input.cursor.z - _z))
		if input.cursor.x > _last_x:  # Only left to right peels.
			_peel_between(_last_x, input.cursor.x)
		elif _last_x - input.cursor.x > 0.002 and not _told_direction:
			_told_direction = true
			session.pop_text("Left to right!", Vector3(input.cursor.x, _top(), _z), -1)
		_last_x = input.cursor.x
	_was_peeling = peeling
	if _side >= sides and not _rolling:
		session.context["carrot"] = { "node": _carrot, "left": _left, "right": _right, "z": _z,
			"radius": radius, "taper": taper, "color": _flesh_color }
		finish(average(_scores))


# Every strip on the side facing up whose middle the peeler swept over.
func _peel_between(from_x: float, to_x: float) -> void:
	var low := minf(from_x, to_x)
	var high := maxf(from_x, to_x)
	var strips: Array = _strips[_side]
	for i in segments:
		var middle := _left + (i + 0.5) * length / segments
		if strips[i] != null and middle >= low and middle <= high:
			_peel_off(strips[i])
			strips[i] = null
	if strips.all(func(strip): return strip == null):
		_side_done()


# The strip curls up off the carrot and drops onto the board behind it,
# turning about its own middle.
func _peel_off(strip: MeshInstance3D) -> void:
	var pivot := Node3D.new()
	session.add_child(pivot)
	pivot.global_position = strip.global_transform * (strip.get_meta("centre") as Vector3)
	strip.reparent(pivot)
	var land := Vector3(pivot.position.x + randf_range(-0.02, 0.02), _board_y + 0.004, _z - radius - randf_range(0.04, 0.1))
	var tween := pivot.create_tween().set_parallel(true)
	tween.tween_property(pivot, "position:y", pivot.position.y + 0.045, 0.14).set_ease(Tween.EASE_OUT)
	tween.tween_property(pivot, "rotation:x", -PI * randf_range(0.7, 1.0), 0.42)
	tween.tween_property(pivot, "position:z", land.z, 0.42).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_property(pivot, "position", land, 0.18).set_ease(Tween.EASE_IN)
	session.play_sound("whoosh", pivot.position, -16.0, randf_range(1.6, 2.0))


func _side_done() -> void:
	var wander := average(_wander)
	var line := 1.0 - clampf((wander - line_tolerance) / (worst_wander - line_tolerance), 0.0, 1.0)
	var score := clampf(line - maxi(_strokes - 1, 0) * extra_stroke_cost, 0.0, 1.0)
	_scores.append(score)
	var at := Vector3((_left + _right) * 0.5, _top(), _z)
	var words := "Clean strip!" if score >= 0.85 else ("Wobbly line" if line < 0.6 else ("Took a few goes" if _strokes > 2 else "Nice"))
	session.pop_text(words, at, CookSession.mood_of(score))
	_side += 1
	_strokes = 0
	_wander.clear()
	_was_peeling = false
	if _side < sides:  # Roll it over to the next side.
		_rolling = true
		var roll := _spin.create_tween()
		roll.tween_property(_spin, "rotation:x", _spin.rotation.x + TAU / sides, roll_seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		roll.tween_callback(func(): _rolling = false)
		session.play_sound("plop", at, -10.0, 0.8)


# A strip of skin: segment `i` along the carrot, the quarter (of `sides`) of its
# round that faces up when `side` is the side being peeled.
func _strip_mesh(i: int, side: int) -> ArrayMesh:
	var x0 := -length * 0.5 + i * length / segments
	var x1 := x0 + length / segments
	var arc := TAU / sides
	var middle := -side * arc  # Up (+y), once the carrot has rolled `side` times.
	var steps := 5
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(_skin)
	for s in steps:
		var a0 := middle - arc * 0.5 + arc * s / steps
		var a1 := a0 + arc / steps
		var corners := [[x0, a0], [x1, a0], [x1, a1], [x0, a1]]
		var points: Array[Vector3] = []
		for corner in corners:
			var r := _radius_at_local(corner[0]) + 0.0015
			points.append(Vector3(corner[0], cos(corner[1]) * r, sin(corner[1]) * r))
		for index in [0, 1, 2, 0, 2, 3]:
			var point: Vector3 = points[index]
			tool.set_normal(Vector3(0.0, point.y, point.z).normalized())
			tool.add_vertex(point)
	return tool.commit()


# The middle of strip `i` on side `side`, on the carrot (its own coordinates).
func _strip_centre(i: int, side: int) -> Vector3:
	var x := -length * 0.5 + (i + 0.5) * length / segments
	var angle := -side * TAU / sides
	return Vector3(x, cos(angle), sin(angle)) * Vector3(1.0, _radius_at_local(x), _radius_at_local(x))


# Radius at x along the carrot (its own coordinates: 0 is the middle).
func _radius_at_local(x: float) -> float:
	var t := clampf(x / length + 0.5, 0.0, 1.0)
	return radius * (1.0 - taper * t)


# The top of the carrot at session x, and at its middle.
func _top_at(x: float) -> float:
	return _board_y + _radius_at_local(clampf(x - (_left + _right) * 0.5, -length * 0.5, length * 0.5)) * 2.0


func _top() -> float:
	return _top_at((_left + _right) * 0.5)


# A Y-peeler, its origin at the middle of the blade: a short blade across the
# carrot on two prongs, and a handle back toward the cook.
func _make_peeler() -> Node3D:
	var peeler := Node3D.new()
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.82, 0.84, 0.88)
	steel.metallic = 0.7
	steel.roughness = 0.3
	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.008, 0.004, 0.05)
	blade_mesh.material = steel
	blade.mesh = blade_mesh
	peeler.add_child(blade)
	for end_z in [-0.025, 0.025]:
		var prong := MeshInstance3D.new()
		var prong_mesh := BoxMesh.new()
		prong_mesh.size = Vector3(0.006, 0.03, 0.005)
		prong_mesh.material = steel
		prong.mesh = prong_mesh
		prong.position = Vector3(0.0, 0.015, end_z)
		peeler.add_child(prong)
	var plastic := StandardMaterial3D.new()
	plastic.albedo_color = Color(0.3, 0.62, 0.42)
	var handle := MeshInstance3D.new()
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.016, 0.014, 0.1)
	handle_mesh.material = plastic
	handle.mesh = handle_mesh
	handle.position = Vector3(0.0, 0.034, 0.075)
	peeler.add_child(handle)
	var yoke := MeshInstance3D.new()
	var yoke_mesh := BoxMesh.new()
	yoke_mesh.size = Vector3(0.006, 0.006, 0.056)
	yoke_mesh.material = steel
	yoke.mesh = yoke_mesh
	yoke.position = Vector3(0.0, 0.03, 0.0)
	peeler.add_child(yoke)
	session.add_child(peeler)
	return peeler
