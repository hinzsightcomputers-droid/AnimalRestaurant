# CutAction: press cookies out of a rolled sheet of dough (the session's
# context "dough", from RollAction). A round cutter follows the cursor; each
# press cuts one. A cookie scores how cleanly it came out: wholly on the sheet
# and clear of the others. Once they're all cut, the scraps go and the cookies
# hop onto the tray. Leaves them in the session's context "cookies".
class_name CutAction
extends CookAction

@export var onto := "Tray"
@export var cookies := 6
@export var piece_name := "Cookies"        # What they are, for the count, e.g. "Croissants".
@export var cookie_radius := 0.045
@export var cookie_thickness := 0.012
@export var columns := 3                   # On the tray.
@export var tray_spacing := Vector2(0.12, 0.12)

var _sheet: Dictionary
var _cut: Array[MeshInstance3D] = []
var _scores: Array[float] = []
var _cutter: MeshInstance3D
var _moving := false
var _top_y := 0.0                          # The sheet's top (it's gone once the cookies move).
var _material: StandardMaterial3D


func _begin() -> void:
	_sheet = session.context.get("dough", {})
	var dough: MeshInstance3D = _sheet.get("node")
	_top_y = dough.position.y + (dough.mesh as BoxMesh).size.y * 0.5 if dough != null else 0.0
	_material = (dough.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() if dough != null else StandardMaterial3D.new()
	_material.albedo_color = _material.albedo_color.lightened(0.18)
	_cutter = session.make_ring(cookie_radius, Color(0.9, 0.92, 0.95, 0.95))
	_cutter.scale.y = 1.5


func end() -> void:
	_cutter.queue_free()


func cursor_height() -> float:
	return _top()


func update(delta: float, input: CookInput) -> void:
	_cutter.visible = not _moving
	_cutter.position = _cutter.position.lerp(Vector3(input.cursor.x, _top() + 0.01, input.cursor.z), 1.0 - exp(-25.0 * delta))
	if _moving:
		return
	session.set_status("%s: %d of %d" % [piece_name, _cut.size(), cookies])
	if input.just_pressed:
		_press(Vector3(input.cursor.x, 0.0, input.cursor.z))


func _press(at: Vector3) -> void:
	var size: Vector2 = _sheet.get("size", Vector2.ONE)
	var center: Vector3 = _sheet.get("center", Vector3.ZERO)
	# How far the cutter pokes off the sheet, and into another cookie.
	var over_x := maxf(absf(at.x - center.x) + cookie_radius - size.x * 0.5, 0.0)
	var over_z := maxf(absf(at.z - center.z) + cookie_radius - size.y * 0.5, 0.0)
	var off_sheet := maxf(over_x, over_z)
	if off_sheet >= cookie_radius * 1.5:
		session.pop_text("Cut on the dough!", at, -1)
		session.play_sound("clack", at, -6.0)
		return
	var overlap := 0.0
	for other in _cut:
		overlap = maxf(overlap, cookie_radius * 2.0 - Vector2(other.position.x - at.x, other.position.z - at.z).length())
	var score := clampf(1.0 - (off_sheet + maxf(overlap, 0.0)) / cookie_radius, 0.0, 1.0)
	_scores.append(score)
	_cut.append(_make_cookie(at))
	session.play_sound("plop", at, -6.0, 1.5)
	session.wobble(_cutter, 0.3)
	session.pop_text("Clean!" if score >= 0.9 else ("Bit squashed" if score >= 0.5 else "Messy!"), at, CookSession.mood_of(score))
	if _cut.size() >= cookies:
		_moving = true
		await _to_tray()
		session.context["cookies"] = _cut
		finish(average(_scores))


func _make_cookie(at: Vector3) -> MeshInstance3D:
	var cookie := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = cookie_radius
	mesh.bottom_radius = cookie_radius
	mesh.height = cookie_thickness
	mesh.radial_segments = 20
	mesh.rings = 1
	mesh.material = _material.duplicate()  # Each its own, to brown in the oven.
	cookie.mesh = mesh
	cookie.position = Vector3(at.x, _top() + cookie_thickness * 0.5, at.z)
	session.add_child(cookie)
	return cookie


# The scraps shrink away and the cookies hop over onto the tray in rows.
func _to_tray() -> void:
	var dough: MeshInstance3D = _sheet.get("node")
	if dough != null:
		var shrink := dough.create_tween()
		shrink.tween_property(dough, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
		shrink.tween_callback(dough.queue_free)
	var tray := session.surface(onto).position
	var rows := ceili(float(_cut.size()) / columns)
	for i in _cut.size():
		var cookie := _cut[i]
		var spot := tray + Vector3((i % columns - (columns - 1) * 0.5) * tray_spacing.x, cookie_thickness * 0.5, (i / columns - (rows - 1) * 0.5) * tray_spacing.y)
		var hop := cookie.create_tween()
		hop.tween_interval(i * 0.08)
		hop.tween_property(cookie, "position", (cookie.position + spot) * 0.5 + Vector3(0.0, 0.12, 0.0), 0.15).set_ease(Tween.EASE_OUT)
		hop.tween_property(cookie, "position", spot, 0.15).set_ease(Tween.EASE_IN)
		hop.tween_callback(session.play_sound.bind("plop", spot, -10.0, 1.8))
	await session.get_tree().create_timer(_cut.size() * 0.08 + 0.45).timeout


func _top() -> float:
	return _top_y
