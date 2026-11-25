# CutAction: press cookies out of a rolled sheet of dough (the session's
# context "dough", from RollAction). A cutter follows the cursor (pale where it
# can cut, red where it can't); each press cuts one, which lifts a little out of
# a dark cut line that stays in the sheet. It can't cut into one already cut:
# trying to costs a little. If there's no room left for the next, the scraps are
# rolled together into a whole sheet again (that costs a little too), so you can
# never get stuck. Once they're all cut, the scraps go (unless
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

const CLEAR := Color(0.95, 0.97, 1.0)      # The cutter, where it can cut...
const BLOCKED := Color(1.0, 0.16, 0.1)     # ...and where it can't.
const GROOVE := Color(0.24, 0.12, 0.06)    # The cut line left in the sheet...
const GROOVE_WIDTH := 0.006
const LIFT := 0.006                        # ...and how far a cut piece comes up out of it.
const TOUCH := 0.003                       # Cuts this close to (or into) each other still count as apart.
const MISS_COST := 0.08
const REROLL_COST := 0.1

var _sheet: Dictionary
var _cut: Array[MeshInstance3D] = []
var _misses := 0                           # Presses on one already cut.
var _rerolls := 0
var _set_aside := 0                        # How many of the cut ones are off the sheet (it's been rolled out again since).
var _paint: StandardMaterial3D             # The cutter's.
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
	_material.set_meta(ToonStyle.FOOD, "dough")
	if shape == "round":
		_cutter = session.make_ring(cookie_radius, Color(CLEAR, 0.95))
		_cutter.scale.y = 1.5
		_paint = (_cutter.mesh as TorusMesh).material
	else:  # A see-through shape of what it'll cut.
		_cutter = MeshInstance3D.new()
		_cutter.mesh = CookSession.prism(_outline(), 0.003)
		var see_through := StandardMaterial3D.new()
		see_through.albedo_color = Color(CLEAR, 0.5)
		see_through.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		see_through.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		see_through.cull_mode = BaseMaterial3D.CULL_DISABLED
		see_through.no_depth_test = true
		_cutter.material_override = see_through
		_paint = see_through
		session.add_child(_cutter)


func end() -> void:
	_cutter.queue_free()


func cursor_height() -> float:
	return _top()


func uses_cursor() -> bool:
	return false  # The cutter shows the spot.


func update(delta: float, input: CookInput) -> void:
	_cutter.visible = not _moving
	var here := Vector2(input.cursor.x, input.cursor.z)
	_paint.albedo_color = Color(CLEAR, _paint.albedo_color.a) if not _blocked(here) else Color(BLOCKED, _paint.albedo_color.a)
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
	if shape == "round":
		var circle := PackedVector2Array()
		for i in 24:
			circle.append(Vector2.from_angle(TAU * i / 24.0) * half.x)
		return circle
	if shape == "triangle":
		return PackedVector2Array([Vector2(-half.x, half.y), Vector2(0.0, -half.y), Vector2(half.x, half.y)])
	return PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)])


func _press(at: Vector3) -> void:
	if _blocked(Vector2(at.x, at.z)):
		_misses += 1
		session.pop_text("Already cut there!", at, -1)
		session.play_sound("clack", at, -6.0)
		session.wobble(_cutter, 0.2)
		return
	_mark(at)
	_cut.append(_make_cookie(at))
	session.play_sound("plop", at, -6.0, 1.5)
	session.wobble(_cutter, 0.3)
	session.pop_text("Clean!", at, 1)
	if _cut.size() >= cookies:
		_moving = true
		session.frame(session.surface(onto).position, view_distance, view_pitch, 0.6)  # Along with them.
		await _to_tray()
		session.context["cookies"] = _cut
		finish(maxf(1.0 - _misses * MISS_COST - _rerolls * REROLL_COST, 0.4))
	elif free_spot(_sheet, _outline(), cursor_area()) == Vector2.INF:
		_roll_again()


# Whether cutting here would cut into one already cut.
func _blocked(at: Vector2) -> bool:
	return is_cut(_sheet, _outline(), at)


# The sheet's cuts so far (its "cuts"): outlines (x, z) in the session. Also for
# LatticeAction, cutting strips from what's left.
static func is_cut(sheet: Dictionary, outline: PackedVector2Array, at: Vector2) -> bool:
	var shape_here := PackedVector2Array()
	for point in outline:
		shape_here.append(point * (1.0 - TOUCH / maxf(point.length(), 0.001)) + at)
	for other: PackedVector2Array in sheet.get("cuts", []):
		if not Geometry2D.intersect_polygons(shape_here, other).is_empty():
			return true
	return false


# Somewhere in `area` there's still room to cut `outline`, or INF.
static func free_spot(sheet: Dictionary, outline: PackedVector2Array, area: Rect2) -> Vector2:
	var steps := Vector2i(maxi(ceili(area.size.x / 0.008), 1), maxi(ceili(area.size.y / 0.008), 1))
	for x in steps.x + 1:
		for z in steps.y + 1:
			var at := area.position + area.size * Vector2(float(x) / steps.x, float(z) / steps.y)
			if not is_cut(sheet, outline, at):
				return at
	return Vector2.INF


# The dark line round a cut.
func _mark(at: Vector3) -> void:
	var placed := PackedVector2Array()
	var wider := PackedVector2Array()
	for point in _outline():
		placed.append(point + Vector2(at.x, at.z))
		wider.append(point * (1.0 + GROOVE_WIDTH * (1.0 if shape == "round" else 1.8) / point.length()))
	var cuts: Array = _sheet.get("cuts", [])
	cuts.append(placed)
	_sheet["cuts"] = cuts
	var line := MeshInstance3D.new()
	line.mesh = CookSession.prism(wider, 0.0012)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = GROOVE
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	line.material_override = paint
	line.position = Vector3(at.x, _top(), at.z)
	session.add_child(line)
	var marks: Array = _sheet.get("marks", [])
	marks.append(line)
	_sheet["marks"] = marks


static func clear_cuts(sheet: Dictionary) -> void:
	for mark: Node3D in sheet.get("marks", []):
		if is_instance_valid(mark):
			mark.queue_free()
	sheet["marks"] = []
	sheet["cuts"] = []


# No room for the next one: what's been cut is set aside in front of the sheet
# and the scraps are rolled out whole again.
func _roll_again() -> void:
	_rerolls += 1
	clear_cuts(_sheet)
	var size: Vector2 = _sheet.get("size", Vector2.ONE * 0.3)
	var center: Vector3 = _sheet.get("center", Vector3.ZERO)
	for i in range(_set_aside, _cut.size()):
		var spot := Vector3(center.x - size.x * 0.5 - _half().x * 1.3, _cut[i].position.y, center.z - size.y * 0.5 + _half().y + i * 0.03)
		_cut[i].create_tween().tween_property(_cut[i], "position", spot, 0.35).set_trans(Tween.TRANS_QUAD)
	_set_aside = _cut.size()
	session.pop_text("Scraps rolled out again!", center, 0)
	var dough: MeshInstance3D = _sheet.get("node")
	if dough != null:
		session.wobble(dough, 0.15)
	session.play_sound("whoosh", center, -6.0)


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
	cookie.create_tween().tween_property(cookie, "position:y", cookie.position.y + LIFT, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if shape == "round":
		var look := MeshInstance3D.new()
		look.mesh = rounded_disc(mesh.top_radius, cookie_thickness)
		session.dress(cookie, look)
	else:
		var look := MeshInstance3D.new()
		look.mesh = CookSession.prism(_outline(), cookie_thickness)
		look.position.y = -cookie_thickness * 0.5
		session.dress(cookie, look, _half())
	return cookie


# A disc with soft, rounded edges, its middle at the origin.
static func rounded_disc(reach: float, height: float) -> ArrayMesh:
	const ROUND := 40
	const SIDE := 9
	var bulge := minf(height * 0.5, reach * 0.4)
	var profile: Array[Vector2] = [Vector2(0.0, -height * 0.5)]
	for i in SIDE:
		var up := PI * (i / (SIDE - 1.0) - 0.5)
		profile.append(Vector2(reach - bulge + cos(up) * bulge, sin(up) * height * 0.5))
	profile.append(Vector2(reach * 0.6, height * 0.53))
	profile.append(Vector2(0.0, height * 0.55))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(0)
	for point in profile:
		for i in ROUND + 1:
			var angle := TAU * i / ROUND
			tool.add_vertex(Vector3(cos(angle) * point.x, point.y, sin(angle) * point.x))
	for ring in profile.size() - 1:
		for i in ROUND:
			var a := ring * (ROUND + 1) + i
			var b := a + ROUND + 1
			for index in [a, a + 1, b, a + 1, b + 1, b]:
				tool.add_index(index)
	tool.generate_normals()
	return tool.commit()


# The scraps shrink away (unless they're kept) and the cookies hop over onto
# the tray in rows.
func _to_tray() -> void:
	var dough: MeshInstance3D = _sheet.get("node")
	if not keep_scraps:
		clear_cuts(_sheet)
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


# For a reel: one press for each, spaced out evenly over the sheet.
func scripted_hold(delta: float, input: CookInput) -> bool:
	if _moving or _cut.size() >= cookies:
		return false
	return input.move_to(_scripted_spot(_cut.size()), delta, 1.0) and not input.held


func _scripted_spot(i: int) -> Vector3:
	var size: Vector2 = _sheet.get("size", Vector2.ONE * 0.3)
	var center: Vector3 = _sheet.get("center", Vector3.ZERO)
	var half := _half()
	var across := clampi(floori(size.x / (half.x * 2.0)), 1, cookies)  # As many as fit side by side...
	var rows := ceili(float(cookies) / across)
	if rows > maxi(floori(size.y / (half.y * 2.0)), 1):  # ...unless the rows wouldn't fit: then spread them evenly.
		across = maxi(ceili(sqrt(cookies * size.x / size.y)), 1)
		rows = ceili(float(cookies) / across)
	var cell := Vector2(size.x / across, size.y / rows)
	var spot := center + Vector3(-size.x * 0.5 + cell.x * (i % across + 0.5), 0.0, -size.y * 0.5 + cell.y * (i / across + 0.5))
	if _blocked(Vector2(spot.x, spot.z)):  # A lopsided sheet: wherever there's room.
		var free := free_spot(_sheet, _outline(), cursor_area())
		if free != Vector2.INF:
			spot = Vector3(free.x, spot.y, free.y)
	return spot
