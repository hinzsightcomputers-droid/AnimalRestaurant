# DoughFoldAction: fold the rolled sheet (the context's "dough") into thirds
# like a letter, with the controls of folding an omelette: press the button on
# the sheet, then flick up: the near third folds over, then (again) the far
# third, leaving it a third as long and three times as thick. With turn_first
# it starts with a press to give the sheet a quarter turn. With butter_streaks
# it shows the butter folded through it once it's done. With no folds it's
# just the turn. A fold scores how
# cleanly it was flicked, like PleatAction.
class_name DoughFoldAction
extends CookAction

@export var folds := 2
@export var turn_first := false
@export var butter_streaks := false
@export_range(0.0, 1.0) var up_needed := 0.6
@export var fold_seconds := 0.3

var _sheet: Dictionary
var _dough: MeshInstance3D
var _box: BoxMesh
var _folded := 0
var _turned := false
var _held := false
var _busy := false
var _scores: Array[float] = []
var _length := 0.0                         # The sheet's length (z) before folding.


func _init() -> void:
	view_distance = 0.55
	view_pitch = 62.0


func view_point() -> Vector3:
	return _sheet.get("center", super.view_point())


func cursor_area() -> Rect2:
	var size: Vector2 = _sheet.get("size", Vector2.ZERO)
	var center: Vector3 = _sheet.get("center", Vector3.ZERO)
	return Rect2(center.x - size.x * 0.5, center.z - size.y * 0.5, size.x, size.y).grow(0.05)


func cursor_height() -> float:
	return _dough.position.y + _box.size.y * 0.5 if _dough != null else session.work_height


func _begin() -> void:
	_sheet = session.context.get("dough", {})
	_dough = _sheet.get("node")
	if not is_instance_valid(_dough):
		finish(1.0)
		return
	_box = _dough.mesh as BoxMesh
	_turned = not turn_first
	_length = _sheet["size"].y


func update(_delta: float, input: CookInput) -> void:
	if _busy:
		return
	if not _turned:
		session.set_status("Give it a quarter turn")
		if input.just_pressed:
			_turn()
		return
	session.set_status("Folds: %d of %d" % [_folded, folds])
	if not _held:
		if input.just_pressed and _on_sheet(input.cursor):
			_held = true
			session.wobble(_dough, 0.05)
			session.play_sound("tick", _dough.position, -8.0, 1.1)
	elif input.flick.y <= -up_needed:
		var straight := clampf(-input.flick.normalized().y, 0.0, 1.0)
		_scores.append(lerpf(0.7, 1.0, clampf((straight - up_needed) / (0.97 - up_needed), 0.0, 1.0)))
		_held = false
		_fold()
	elif input.just_pressed:
		_held = false
		session.pop_text("Flick up to fold!", input.cursor, 0)


# A quarter turn: it ends up the other way round (its size swapped, not turned).
func _turn() -> void:
	_busy = true
	session.pop_text("Turn!", _dough.position, 1)
	session.play_sound("whoosh", _dough.position, -10.0)
	var spin := _dough.create_tween()
	spin.tween_property(_dough, "rotation:y", PI * 0.5, 0.35).set_trans(Tween.TRANS_SINE)
	await spin.finished
	_dough.rotation.y = 0.0
	var size: Vector2 = _sheet["size"]
	_set_size(Vector2(size.y, size.x), _box.size.y)
	var streaks := _dough.get_node_or_null("Streaks") as Node3D
	if streaks != null:
		streaks.rotation.y += PI * 0.5
	_length = size.x
	_turned = true
	_busy = false
	if folds <= 0:  # Just the turn.
		session.context["dough"] = _sheet
		finish(1.0)


# A third folds over: shorter by a third of its length, thicker to match.
func _fold() -> void:
	_busy = true
	var size: Vector2 = _sheet["size"]
	var near := _folded % 2 == 0  # The near third first, then the far.
	var flap := MeshInstance3D.new()  # The third coming over, for show.
	var flap_mesh := BoxMesh.new()
	flap_mesh.size = Vector3(size.x, _box.size.y, _length / 3.0)
	flap_mesh.material = _box.material
	flap.mesh = flap_mesh
	var hinge := Node3D.new()
	var edge := size.y * 0.5 - _length / 3.0  # Where it bends.
	hinge.position = Vector3(_dough.position.x, _dough.position.y + _box.size.y * 0.5, _dough.position.z + (edge if near else -edge))
	session.add_child(hinge)
	hinge.add_child(flap)
	flap.position = Vector3(0.0, -_box.size.y * 0.5, (_length / 6.0) * (1.0 if near else -1.0))
	var thickness := _box.size.y
	var new_length := size.y - _length / 3.0
	_set_size(Vector2(size.x, new_length), thickness * size.y / new_length)
	_dough.position.z += (-1.0 if near else 1.0) * _length / 6.0
	_sheet["center"] = Vector3(_dough.position.x, _sheet["center"].y, _dough.position.z)
	session.play_sound("whoosh", hinge.position, -10.0, 1.2)
	var tween := hinge.create_tween()
	tween.tween_property(hinge, "rotation:x", -PI if near else PI, fold_seconds).set_trans(Tween.TRANS_SINE)
	await tween.finished
	hinge.queue_free()
	session.wobble(_dough, 0.1)
	session.play_sound("plop", _dough.position, -6.0, 0.9)
	_folded += 1
	session.pop_text("Fold!", _dough.position, CookSession.mood_of(_scores[-1]))
	_busy = false
	if _folded >= folds:
		if butter_streaks:
			_add_streaks()
		session.context["dough"] = _sheet
		finish(average(_scores))


func _set_size(size: Vector2, thickness: float) -> void:
	_sheet["size"] = size
	_box.size = Vector3(size.x, thickness, size.y)
	_dough.position.y = _sheet["center"].y + thickness * 0.5


# Pale stripes of butter through the dough (stretched with it when it's rolled).
func _add_streaks() -> void:
	var old := _dough.get_node_or_null("Streaks")
	if old != null:
		old.free()
	var streaks := Node3D.new()
	streaks.name = "Streaks"
	var size: Vector2 = _sheet["size"]
	streaks.set_meta("size", size)
	var butter := StandardMaterial3D.new()
	butter.albedo_color = Color(1.0, 0.9, 0.55)
	for i in 5:
		var streak := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(size.x * randf_range(0.5, 0.85), 0.0015, 0.006)
		mesh.material = butter
		streak.mesh = mesh
		streak.position = Vector3(randf_range(-0.1, 0.1) * size.x, 0.0, lerpf(-0.4, 0.4, i / 4.0) * size.y)
		streaks.add_child(streak)
	streaks.position.y = _box.size.y * 0.5
	_dough.add_child(streaks)


func _on_sheet(cursor: Vector3) -> bool:
	return cursor_area().grow(-0.03).has_point(Vector2(cursor.x, cursor.z))
