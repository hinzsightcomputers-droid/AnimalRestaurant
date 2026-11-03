# CutAction: press cookies out of a rolled sheet of dough (the session's
# context "dough", from RollAction). A cutter follows the cursor; each press
# cuts one. A cookie scores how cleanly it came out: wholly on the sheet and
# clear of the others. Once they're all cut, the scraps go (unless
# keep_scraps) and the cookies hop onto the tray. Leaves them in the session's
# context "cookies".
# The cutter's round, or a rectangle or a long triangle (shape, shape_size): a
# shaped piece is still a round piece underneath, dressed in its shape (see
# CookSession.dress). With become "dome", each one rounds up into a little
# ball (mochi) of become_color once it's on the tray.
class_name CutAction
extends CookAction

@export var onto := "Tray"
@export var cookies := 6
@export var piece_name := "Cookies"        # What they are, for the count, e.g. "Croissants".
@export var cookie_radius := 0.045
@export var cookie_thickness := 0.012
@export var columns := 3                   # On the tray.
@export var tray_spacing := Vector2(0.12, 0.12)
@export_enum("round", "rect", "triangle") var shape := "round"
@export var shape_size := Vector2.ZERO     # A rectangle's or triangle's width and depth (the triangle's tip away from you).
@export var keep_scraps := false           # The rest of the sheet stays on the counter (for lattice strips).
@export var become := ""                   # "dome": each rounds up into a ball once it's on the tray.
@export var become_color := Color.WHITE

var _sheet: Dictionary
var _cut: Array[MeshInstance3D] = []
var _scores: Array[float] = []
var _cutter: MeshInstance3D
var _moving := false
var _top_y := 0.0                          # The sheet's top (it's gone once the cookies move).
var _material: StandardMaterial3D


func _init() -> void:
	view_distance = 0.5  # Close in on the sheet.
	view_pitch = 62.0


func view_point() -> Vector3:
	var center: Vector3 = session.context.get("dough", {}).get("center", super.view_point())
	return Vector3(center.x, _top(), center.z)


# The whole cutter stays on the sheet (just its middle, on a sheet too small for it).
func cursor_area() -> Rect2:
	var size: Vector2 = _sheet.get("size", Vector2.ZERO)
	var center: Vector3 = _sheet.get("center", Vector3.ZERO)
	var inside := (size - _half() * 2.0).max(Vector2.ONE * 0.001)
	return Rect2(center.x - inside.x * 0.5, center.z - inside.y * 0.5, inside.x, inside.y)


func _begin() -> void:
	_sheet = session.context.get("dough", {})
	var dough: MeshInstance3D = _sheet.get("node")
	_top_y = dough.position.y + (dough.mesh as BoxMesh).size.y * 0.5 if dough != null else 0.0
	_material = (dough.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() if dough != null else StandardMaterial3D.new()
	_material.albedo_color = _material.albedo_color.lightened(0.18)
	if shape == "round":
		_cutter = session.make_ring(cookie_radius, Color(0.9, 0.92, 0.95, 0.95))
		_cutter.scale.y = 1.5
	else:  # A see-through shape of what it'll cut.
		_cutter = MeshInstance3D.new()
		_cutter.mesh = CookSession.prism(_outline(), 0.003)
		var see_through := StandardMaterial3D.new()
		see_through.albedo_color = Color(0.95, 0.97, 1.0, 0.45)
		see_through.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		see_through.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		see_through.cull_mode = BaseMaterial3D.CULL_DISABLED
		see_through.no_depth_test = true
		_cutter.material_override = see_through
		session.add_child(_cutter)


func end() -> void:
	_cutter.queue_free()


func cursor_height() -> float:
	return _top()


func cursor_dot() -> bool:
	return shape != "round"  # The shape shows where it'll cut.


func update(delta: float, input: CookInput) -> void:
	_cutter.visible = not _moving
	_cutter.position = _cutter.position.lerp(Vector3(input.cursor.x, _top() + 0.01, input.cursor.z), 1.0 - exp(-25.0 * delta))
	if _moving:
		return
	session.set_status("%s: %d of %d" % [piece_name, _cut.size(), cookies])
	if input.just_pressed:
		_press(Vector3(input.cursor.x, 0.0, input.cursor.z))


# Half the cutter's size across (x, z).
func _half() -> Vector2:
	return Vector2(cookie_radius, cookie_radius) if shape == "round" else shape_size * 0.5


# The cutter's shape (x, z), round its middle.
func _outline() -> PackedVector2Array:
	var half := _half()
	if shape == "triangle":
		return PackedVector2Array([Vector2(-half.x, half.y), Vector2(0.0, -half.y), Vector2(half.x, half.y)])
	return PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)])


func _press(at: Vector3) -> void:
	var size: Vector2 = _sheet.get("size", Vector2.ONE)
	var center: Vector3 = _sheet.get("center", Vector3.ZERO)
	var half := _half()
	# How far the cutter pokes off the sheet, and into another cookie.
	var over_x := maxf(absf(at.x - center.x) + half.x - size.x * 0.5, 0.0)
	var over_z := maxf(absf(at.z - center.z) + half.y - size.y * 0.5, 0.0)
	var off_sheet := maxf(over_x, over_z)
	var small := minf(half.x, half.y)
	if off_sheet >= small * 1.5:
		session.pop_text("Cut on the dough!", at, -1)
		session.play_sound("clack", at, -6.0)
		return
	var overlap := 0.0
	for other in _cut:
		var gap := Vector2(absf(other.position.x - at.x), absf(other.position.z - at.z))
		if shape == "round":
			overlap = maxf(overlap, cookie_radius * 2.0 - gap.length())
		else:
			overlap = maxf(overlap, minf(half.x * 2.0 - gap.x, half.y * 2.0 - gap.y))
	var score := clampf(1.0 - (off_sheet + maxf(overlap, 0.0)) / small, 0.0, 1.0)
	_scores.append(score)
	_cut.append(_make_cookie(at))
	session.play_sound("plop", at, -6.0, 1.5)
	session.wobble(_cutter, 0.3)
	session.pop_text("Clean!" if score >= 0.9 else ("Bit squashed" if score >= 0.5 else "Messy!"), at, CookSession.mood_of(score))
	if _cut.size() >= cookies:
		_moving = true
		session.frame(session.surface(onto).position, view_distance, view_pitch, 0.6)  # Along with them.
		await _to_tray()
		session.context["cookies"] = _cut
		finish(average(_scores))


func _make_cookie(at: Vector3) -> MeshInstance3D:
	var cookie := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = maxf(_half().x, _half().y)
	mesh.bottom_radius = mesh.top_radius
	mesh.height = cookie_thickness
	mesh.radial_segments = 20
	mesh.rings = 1
	mesh.material = _material.duplicate()  # Each its own, to brown in the oven.
	cookie.mesh = mesh
	cookie.position = Vector3(at.x, _top() + cookie_thickness * 0.5, at.z)
	session.add_child(cookie)
	if shape != "round":
		var look := MeshInstance3D.new()
		look.mesh = CookSession.prism(_outline(), cookie_thickness)
		look.position.y = -cookie_thickness * 0.5
		session.dress(cookie, look, _half())
	return cookie


# The scraps shrink away (unless they're kept) and the cookies hop over onto
# the tray in rows.
func _to_tray() -> void:
	var dough: MeshInstance3D = _sheet.get("node")
	if dough != null and not keep_scraps:
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
		if become == "dome":
			hop.tween_callback(_round_up.bind(cookie))
	await session.get_tree().create_timer(_cut.size() * 0.08 + 0.45).timeout


# A cut piece pulls itself up into a soft round ball.
func _round_up(cookie: MeshInstance3D) -> void:
	var radius := cookie_radius * 0.85
	((cookie.mesh as CylinderMesh).material as StandardMaterial3D).albedo_color = become_color
	var ball := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 1.4
	ball.mesh = mesh
	ball.position.y = radius * 0.7 - cookie_thickness * 0.5
	session.dress(cookie, ball, Vector2.ZERO, radius * 1.4 - cookie_thickness * 0.5)
	session.wobble(ball, 0.25)


func _top() -> float:
	return _top_y
