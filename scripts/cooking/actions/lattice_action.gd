# LatticeAction: a lattice top for a pie (the first of the context's
# "cookies", filled with cherries as this starts). First cut every strip:
# press on what's left of the rolled sheet (the context's "dough", kept by
# CutAction's keep_scraps) once for each. Then lay them one at a time,
# alternating across and up-and-down: each comes off the pile into your hand;
# move over the pie and press. Dashed lines on the pie show the even spots
# still free the way the next one goes (the strips per way spread evenly, the
# middle one through its centre). Laid within snap_within of a line it snaps
# onto it, perfect; further off it stays where it was laid, scoring less.
class_name LatticeAction
extends CookAction

@export var per_way := 3                   # Strips each way.
@export var strip_width := 0.016
@export var spacing := 0.5                 # Between strips, as a share of the pie's radius.
@export var filling_color := Color(0.72, 0.08, 0.14)
@export var snap_within := 0.02            # This near a line, it goes right on it.
@export var lay_view := Vector2(0.45, 64.0)  # Camera distance and pitch on the pie once the strips are cut.
@export var worst_offset := 0.045

var _pie: MeshInstance3D
var _radius := 0.0
var _laid := 0
var _holding: MeshInstance3D = null        # The strip in hand, off the pile.
var _pile: Array[MeshInstance3D] = []      # Cut and waiting, where they were cut.
var _scores: Array[float] = []
var _taken := {}                           # "across" / "down" -> slot indices with a strip.
var _knife: MeshInstance3D                 # Over the sheet: where the next strip comes off.
var _sheet: Dictionary
var _guides := Node3D.new()               # Dashed lines where the next strips go.


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


func uses_cursor() -> bool:
	return false  # The knife or the strip in hand shows the spot.


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
	session.add_child(_guides)
	_show_guides()
	if _sheet.is_empty():  # No sheet to cut from: they're ready.
		for i in per_way * 2:
			_pile.append(_make_strip())
			_pile[-1].visible = false
		_take_next()


func end() -> void:
	_knife.queue_free()
	_guides.queue_free()
	if _holding != null:
		_holding.queue_free()
	for strip in _pile:
		strip.queue_free()
	var dough: MeshInstance3D = _sheet.get("node")
	if is_instance_valid(dough):  # The last of the scraps go.
		var shrink := dough.create_tween()
		shrink.tween_property(dough, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
		shrink.tween_callback(dough.queue_free)


func update(delta: float, input: CookInput) -> void:
	var spot := Vector3(input.cursor.x, 0.0, input.cursor.z)
	var across := _laid % 2 == 0
	var cutting := _laid == 0 and _holding == null and _pile.size() < per_way * 2
	_knife.visible = cutting
	if cutting:
		_knife.position = Vector3(spot.x, _sheet_top() + 0.004, spot.z)
		session.set_status("Strips cut: %d of %d" % [_pile.size(), per_way * 2])
		if input.just_pressed:
			if _on_sheet(spot):
				_cut_strip(spot)
			else:
				session.pop_text("Cut it from the dough!", spot, -1)
		return
	if _holding == null:
		return
	_holding.rotation.y = 0.0 if across else PI * 0.5
	var lift := _pie.position.y + CookSession.top_of(_pie) + 0.05
	_holding.position = _holding.position.lerp(Vector3(spot.x, lift, spot.z), 1.0 - exp(-20.0 * delta))
	session.set_status("Laid: %d of %d  -  lay it %s the pie, on a dashed line" % [_laid, per_way * 2, "across" if across else "up and down"])
	if input.just_pressed:
		_lay(spot, across)


func _cut_strip(spot: Vector3) -> void:
	var dough: MeshInstance3D = _sheet["node"]
	var strip := _make_strip()
	(strip.mesh as BoxMesh).size.x = 0.09  # Short while it lies on the sheet.
	strip.position = Vector3(spot.x, _sheet_top() + 0.003 + _pile.size() * 0.002, spot.z)
	_pile.append(strip)
	session.play_sound("chop", spot, -8.0, 1.4)
	session.burst(Vector3(spot.x, _sheet_top(), spot.z), (dough.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color, 6, 0.15)
	session.wobble(strip, 0.1)
	if _pile.size() >= per_way * 2:
		session.pop_text("Lattice!", spot, 1)
		_take_next()


# The next strip off the pile, into your hand at full length.
func _take_next() -> void:
	if _pile.is_empty():
		return
	if _holding == null and _laid == 0:  # Done cutting: in close on the pie to lay them.
		session.frame(_pie.position, lay_view.x, lay_view.y, 0.6)
	_holding = _pile.pop_back()
	_holding.visible = true
	(_holding.mesh as BoxMesh).size.x = _radius * 2.0


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
	var snapped := best_gap <= snap_within
	if snapped:  # Right onto the line.
		along = _slot(best)
		if across:
			off.y = along
		else:
			off.x = along
	var score := 1.0 if snapped else 1.0 - clampf((best_gap - snap_within) / (worst_offset - snap_within), 0.0, 1.0) * 0.6
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
	session.pop_text("Perfect!" if snapped else ("Nearly" if score >= 0.7 else "Off the line"), spot, CookSession.mood_of(score))
	_laid += 1
	_show_guides()
	if _laid >= per_way * 2:
		finish(average(_scores))
	else:
		_take_next()


# A dashed line on the pie at each even spot still free, the way the next
# strip goes.
func _show_guides() -> void:
	for child in _guides.get_children():
		child.queue_free()
	if _laid >= per_way * 2:
		return
	var across := _laid % 2 == 0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 1.0, 1.0, 0.85)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	var dash := BoxMesh.new()
	dash.size = Vector3(0.012, 0.001, 0.003)
	dash.material = material
	var top := _pie.position.y + CookSession.top_of(_pie) + 0.014
	for i in per_way:
		if i in _taken["across" if across else "down"]:
			continue
		var along := _slot(i)
		var half := sqrt(maxf(_radius * _radius - along * along, 0.0)) * 0.92
		var x := -half
		while x < half:
			var piece := MeshInstance3D.new()
			piece.mesh = dash
			piece.rotation.y = 0.0 if across else PI * 0.5
			piece.position = _pie.position + (Vector3(x + 0.006, 0.0, along) if across else Vector3(along, 0.0, x + 0.006))
			piece.position.y = top
			_guides.add_child(piece)
			x += 0.02


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
