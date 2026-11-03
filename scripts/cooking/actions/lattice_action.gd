# LatticeAction: a lattice top for a pie (the first of the context's
# "cookies", filled with cherries as this starts). Strips go across it one at
# a time, alternating across and up-and-down: press on what's left of the
# rolled sheet (the context's "dough", kept by CutAction's keep_scraps) to cut
# a strip, then move over the pie and press to lay it. A strip scores how near
# it lands to its even spot (the strips per way spread evenly across the pie,
# the middle one through its centre).
class_name LatticeAction
extends CookAction

@export var per_way := 3                   # Strips each way.
@export var strip_width := 0.016
@export var spacing := 0.5                 # Between strips, as a share of the pie's radius.
@export var filling_color := Color(0.72, 0.08, 0.14)
@export var perfect_offset := 0.006
@export var worst_offset := 0.04

var _pie: MeshInstance3D
var _radius := 0.0
var _laid := 0
var _holding: MeshInstance3D = null        # The strip in hand, once cut.
var _scores: Array[float] = []
var _taken := {}                           # "across" / "down" -> slot indices with a strip.
var _knife: MeshInstance3D                 # Over the sheet: where the next strip comes off.
var _sheet: Dictionary


func _init() -> void:
	view_distance = 0.95
	view_pitch = 62.0


# Between the sheet and the pie, to see both.
func view_point() -> Vector3:
	if _pie == null:
		return super.view_point()
	var sheet_at: Vector3 = _sheet.get("center", _pie.position)
	return (sheet_at + _pie.position) * 0.5


func cursor_height() -> float:
	return _pie.position.y + CookSession.top_of(_pie) if _pie != null else session.work_height


func cursor_dot() -> bool:
	return true


func _begin() -> void:
	var cookies: Array = session.context.get("cookies", [])
	if cookies.is_empty():
		finish(1.0)
		return
	_pie = cookies[0]
	_radius = CookSession.half_of(_pie).x
	_sheet = session.context.get("dough", {})
	if not is_instance_valid(_sheet.get("node")):
		_sheet = {}
	var filling := MeshInstance3D.new()  # The cherries, for the strips to go over.
	var mesh := CylinderMesh.new()
	mesh.top_radius = _radius * 0.86
	mesh.bottom_radius = _radius * 0.86
	mesh.height = 0.006
	var red := StandardMaterial3D.new()
	red.albedo_color = filling_color
	red.roughness = 0.3
	mesh.material = red
	filling.mesh = mesh
	filling.set_meta("own_material", true)
	filling.position.y = CookSession.top_of(_pie) + 0.003
	_pie.add_child(filling)
	_taken = { "across": [], "down": [] }
	_knife = MeshInstance3D.new()
	var blade := BoxMesh.new()
	blade.size = Vector3(0.09, 0.004, strip_width)
	var see_through := StandardMaterial3D.new()
	see_through.albedo_color = Color(0.95, 0.97, 1.0, 0.6)
	see_through.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	see_through.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	see_through.no_depth_test = true
	blade.material = see_through
	_knife.mesh = blade
	session.add_child(_knife)
	if _sheet.is_empty():
		_holding = _make_strip()  # No sheet to cut from: one's ready.


func end() -> void:
	_knife.queue_free()
	if _holding != null:
		_holding.queue_free()
	var dough: MeshInstance3D = _sheet.get("node")
	if is_instance_valid(dough):  # The last of the scraps go.
		var shrink := dough.create_tween()
		shrink.tween_property(dough, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
		shrink.tween_callback(dough.queue_free)


func update(delta: float, input: CookInput) -> void:
	var spot := Vector3(input.cursor.x, 0.0, input.cursor.z)
	var across := _laid % 2 == 0
	_knife.visible = _holding == null
	if _holding == null:
		_knife.position = Vector3(spot.x, _sheet_top() + 0.004, spot.z)
		session.set_status("Strips: %d of %d  -  cut one from the dough" % [_laid, per_way * 2])
		if input.just_pressed:
			if _on_sheet(spot):
				_cut_strip(spot)
			else:
				session.pop_text("Cut it from the dough!", spot, -1)
		return
	_holding.rotation.y = 0.0 if across else PI * 0.5
	var lift := _pie.position.y + CookSession.top_of(_pie) + 0.05
	_holding.position = _holding.position.lerp(Vector3(spot.x, lift, spot.z), 1.0 - exp(-20.0 * delta))
	session.set_status("Strips: %d of %d  -  lay it %s the pie" % [_laid, per_way * 2, "across" if across else "up and down"])
	if input.just_pressed:
		_lay(spot, across)


func _cut_strip(spot: Vector3) -> void:
	var dough: MeshInstance3D = _sheet["node"]
	_holding = _make_strip()
	_holding.position = Vector3(spot.x, _sheet_top() + 0.01, spot.z)
	session.play_sound("chop", spot, -8.0, 1.4)
	session.burst(Vector3(spot.x, _sheet_top(), spot.z), (dough.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color, 6, 0.15)
	session.pop_text("Lattice!", spot, 0)


func _lay(spot: Vector3, across: bool) -> void:
	var off := Vector2(spot.x - _pie.position.x, spot.z - _pie.position.z)
	var along := off.y if across else off.x  # How far from the middle, the way the strips are spaced.
	if absf(along) > _radius or (across and absf(off.x) > _radius) or (not across and absf(off.y) > _radius):
		session.pop_text("Over the pie!", spot, -1)
		return
	# The nearest free even spot, the way it's going.
	var way := "across" if across else "down"
	var best := -1
	var best_gap := INF
	for i in per_way:
		if i in _taken[way]:
			continue
		var gap := absf(along - _slot(i))
		if gap < best_gap:
			best_gap = gap
			best = i
	_taken[way].append(best)
	var score := 1.0 - clampf((best_gap - perfect_offset) / (worst_offset - perfect_offset), 0.0, 1.0)
	_scores.append(score)
	var strip := _holding
	_holding = null
	var length := 2.0 * sqrt(maxf(_radius * _radius - along * along, 0.0)) * 0.96
	(strip.mesh as BoxMesh).size.x = maxf(length, 0.02)
	strip.reparent(_pie)  # Bakes (and is served) with it.
	var rest := Vector3(off.x if not across else 0.0, CookSession.top_of(_pie) + 0.008 + _laid * 0.0015, off.y if across else 0.0)
	var drop := strip.create_tween()
	drop.tween_property(strip, "position", rest, 0.15).set_ease(Tween.EASE_IN)
	session.play_sound("plop", spot, -6.0, 1.4)
	session.pop_text("Even!" if score >= 0.9 else ("Nice" if score >= 0.6 else "Off to the side"), spot, CookSession.mood_of(score))
	_laid += 1
	if _laid >= per_way * 2:
		finish(average(_scores))
	elif _sheet.is_empty():
		_holding = _make_strip()


# Where strip `i` should go, from the pie's middle.
func _slot(i: int) -> float:
	return (i - (per_way - 1) * 0.5) * spacing * _radius


func _make_strip() -> MeshInstance3D:
	var strip := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(_radius * 2.0, 0.005, strip_width)
	strip.mesh = mesh
	strip.material_override = (_pie.mesh as CylinderMesh).material  # Browns with the pie.
	session.add_child(strip)
	return strip


func _on_sheet(spot: Vector3) -> bool:
	if _sheet.is_empty():
		return false
	var size: Vector2 = _sheet["size"]
	var center: Vector3 = _sheet["center"]
	return absf(spot.x - center.x) <= size.x * 0.5 and absf(spot.z - center.z) <= size.y * 0.5


func _sheet_top() -> float:
	var dough: MeshInstance3D = _sheet.get("node")
	if not is_instance_valid(dough):
		return session.work_height
	return dough.position.y + (dough.mesh as BoxMesh).size.y * 0.5
