# CoatAction: hold the button and move to coat things, with only so much to
# go round (like a drizzle): a pastry brush painting melted butter over the cut
# pieces, or a shaker dusting powder (cornstarch over a patch of counter, sugar
# over mochi). It scores how much of what's to be coated got covered (full
# marks at target_coverage), less a little for what missed, from least_score
# up; with always_full, full marks wherever it lands; with each_some, full marks
# once every piece has some on (salt on pretzels). keep_on keeps the tool
# over a surface (the sugar stays on the plate). It's done once the coat's
# run out, or once there's enough on and you let go.
# With turn_out, a container's contents are turned out once it's done (the
# mochi dough onto the dusted counter).
class_name CoatAction
extends CookAction

@export_enum("brush", "shaker") var tool := "brush"
@export var on_surface := ""               # Coat a patch of this surface; empty: the cut pieces.
@export var patch := Vector2(0.26, 0.26)   # on_surface: the patch to coat, outlined.
@export var coat_name := "Butter"          # For the status line.
@export var coat_color := Color(1.0, 0.86, 0.4, 0.75)
@export var seconds := 4.0                 # How long it lasts while held.
@export var blob_radius := 0.012
@export var spacing := 0.008
@export_range(0.0, 1.0) var target_coverage := 0.6
@export_range(0.0, 1.0) var least_score := 0.5
@export var always_full := false
@export var each_some := false
@export var keep_on := ""                  # A surface the tool can't leave.
@export var turn_out := ""                 # A container to turn out onto on_surface afterwards.

var _left := 0.0
var _last = null                           # Where the last blob went (Vector2), or null between strokes.
var _blobs: Array[Vector2] = []            # On what's to be coated.
var _missed := 0
var _tool: Node3D
var _blob_mesh: Mesh
var _outline: Node3D
var _cookies: Array = []
var _touched := {}                         # Pieces with some on (each_some).
var _sound: AudioStreamPlayer3D


func view_point() -> Vector3:
	if not on_surface.is_empty():
		return session.surface(on_surface).position
	var middle := Vector3.ZERO
	for cookie: Node3D in _cookies:
		middle += cookie.position
	return middle / maxf(_cookies.size(), 1) if not _cookies.is_empty() else super.view_point()


func cursor_area() -> Rect2:
	if not keep_on.is_empty():
		return session.area_of(keep_on, 0.0)
	if not on_surface.is_empty():
		var at := session.surface(on_surface).position
		return Rect2(at.x - patch.x * 0.5, at.z - patch.y * 0.5, patch.x, patch.y).grow(0.05)
	if _cookies.is_empty():
		return Rect2()
	var area := Rect2(_cookies[0].position.x, _cookies[0].position.z, 0.0, 0.0)
	for cookie: Node3D in _cookies:
		area = area.expand(Vector2(cookie.position.x, cookie.position.z))
	return area.grow(0.08)


func cursor_height() -> float:
	return _height_at(Vector2.INF)


func uses_cursor() -> bool:
	return false  # The brush or shaker shows the spot.


func _begin() -> void:
	_left = seconds
	_cookies = session.context.get("cookies", []) if on_surface.is_empty() else []
	_tool = session.make_brush() if tool == "brush" else _make_shaker()
	_sound = session.loop_sound("drizzle", -14.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = coat_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if coat_color.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	if tool == "brush":  # Glossy streaks.
		var disc := CylinderMesh.new()
		disc.top_radius = blob_radius
		disc.bottom_radius = blob_radius
		disc.height = 0.0015
		disc.radial_segments = 10
		material.roughness = 0.1
		material.metallic_specular = 0.9
		disc.material = material
		_blob_mesh = disc
	else:  # Little specks.
		var speck := SphereMesh.new()
		speck.radius = blob_radius * 0.35
		speck.height = blob_radius * 0.3
		speck.radial_segments = 6
		speck.rings = 2
		material.roughness = 0.9
		speck.material = material
		_blob_mesh = speck
	if not on_surface.is_empty():
		_outline = _make_outline()


func end() -> void:
	_tool.queue_free()
	_sound.queue_free()
	if _outline != null:
		_outline.queue_free()


func update(delta: float, input: CookInput) -> void:
	if not keep_on.is_empty():
		input.cursor = session.surface(keep_on).keep_inside(input.cursor, blob_radius)
	var spot := Vector2(input.cursor.x, input.cursor.z)
	var coating := input.held and _left > 0.0
	var height := _height_at(spot)
	var hover := 0.004 if tool == "brush" and coating else (0.05 if tool == "brush" else 0.12)
	_tool.position = _tool.position.lerp(Vector3(spot.x, height + hover, spot.y), 1.0 - exp(-22.0 * delta))
	if tool == "shaker":
		_tool.rotation.z = lerp_angle(_tool.rotation.z, 2.6 + (sin(Time.get_ticks_msec() * 0.03) * 0.25 if coating else 0.0), 1.0 - exp(-14.0 * delta))
	if coating:
		_left = maxf(0.0, _left - delta)
		if _last == null:
			_coat(spot)
			_last = spot
		else:
			var steps := int((_last as Vector2).distance_to(spot) / spacing)
			for i in steps:
				_coat((_last as Vector2).lerp(spot, float(i + 1) / steps))
			if steps > 0:
				_last = spot
			elif tool == "shaker" and randf() < delta * 12.0:  # Held still: it still falls.
				_coat(spot)
		if not _sound.playing:
			_sound.play()
	else:
		_last = null
		if _sound.playing:
			_sound.stop()
	if each_some:
		session.set_status("%s on %d of %d" % [coat_name, _touched.size(), _cookies.size()])
		if _left <= 0.0 or (not input.held and _touched.size() >= _cookies.size()):
			var share := float(_touched.size()) / maxi(_cookies.size(), 1)
			session.pop_text("Perfect!" if share >= 1.0 else "Some got none", view_point(), CookSession.mood_of(share))
			finish(share)
		return
	var coverage := _coverage()
	session.set_status("%s left: %d%%  -  covered %d%%" % [coat_name, ceili(_left / seconds * 100.0), roundi(minf(coverage / target_coverage, 1.0) * 100.0)])
	if _left <= 0.0 or (not input.held and coverage >= target_coverage):
		var score := 1.0 if always_full else _score(coverage)
		session.pop_text("Lovely!" if score >= 0.85 else ("Patchy" if coverage < target_coverage else "Messy"), session.surface(on_surface).position if not on_surface.is_empty() else view_point(), CookSession.mood_of(score))
		if not turn_out.is_empty():
			_turn_out()
		finish(score)


# A blob (or a few specks) of the coat where it lands: on a piece or the patch
# (counting toward the coverage), or wasted beside it.
func _coat(point: Vector2) -> void:
	var landing := [point] if tool == "brush" else [point + Vector2.from_angle(randf() * TAU) * randf() * blob_radius * 1.6, point + Vector2.from_angle(randf() * TAU) * randf() * blob_radius * 1.6]
	for at: Vector2 in landing:
		var blob := MeshInstance3D.new()
		blob.mesh = _blob_mesh
		var target: Variant = _target_at(at)
		blob.position = Vector3(at.x, _height_at(at) + 0.001, at.y)
		blob.rotation.y = randf() * TAU
		if target is MeshInstance3D:  # Bakes with the piece.
			session.add_child(blob)
			blob.reparent(target)
			_touched[target] = true
		else:
			session.add_child(blob)
		if target != null:
			_blobs.append(at)
		else:
			_missed += 1


# What's to be coated under a point: a piece, the patch's surface, or null.
func _target_at(point: Vector2) -> Variant:
	if not on_surface.is_empty():
		var at := session.surface(on_surface).position
		return session.surface(on_surface) if absf(point.x - at.x) <= patch.x * 0.5 and absf(point.y - at.z) <= patch.y * 0.5 else null
	for cookie: MeshInstance3D in _cookies:
		if CookSession.on_piece(cookie, point):
			return cookie
	return null


func _height_at(point: Vector2) -> float:
	if not on_surface.is_empty():
		return session.surface(on_surface).position.y
	var cookie = _target_at(point) if point != Vector2.INF else null
	if cookie == null and not _cookies.is_empty():
		cookie = _cookies[0]
	if cookie == null:
		return session.work_height
	if _target_at(point) == null and point != Vector2.INF:  # Beside them: down on what they're on.
		return (cookie as Node3D).position.y - ((cookie as MeshInstance3D).mesh as CylinderMesh).height * 0.5
	return (cookie as Node3D).position.y + CookSession.top_of(cookie)


# Share of what's to be coated (sampled on a grid over it) that has some on.
func _coverage() -> float:
	var samples := 0
	var covered := 0
	var reach := blob_radius * (1.1 if tool == "brush" else 1.6)
	var areas: Array[Rect2] = []
	if not on_surface.is_empty():
		var at := session.surface(on_surface).position
		areas.append(Rect2(at.x - patch.x * 0.5, at.z - patch.y * 0.5, patch.x, patch.y))
	else:
		for cookie: MeshInstance3D in _cookies:
			var half := CookSession.half_of(cookie)
			areas.append(Rect2(cookie.position.x - half.x, cookie.position.z - half.y, half.x * 2.0, half.y * 2.0))
	for area in areas:
		for gx in 6:
			for gz in 6:
				var sample := area.position + area.size * Vector2((gx + 0.5) / 6.0, (gz + 0.5) / 6.0)
				if on_surface.is_empty() and _target_at(sample) == null:
					continue  # Off a round (or shaped) piece's own outline.
				samples += 1
				for blob in _blobs:
					if blob.distance_to(sample) <= reach:
						covered += 1
						break
	return float(covered) / maxi(samples, 1)


func _score(coverage: float) -> float:
	var waste := float(_missed) / maxi(_missed + _blobs.size(), 1)
	var neatness := clampf(coverage / target_coverage, 0.0, 1.0) * (1.0 - clampf(waste * 0.8, 0.0, 1.0))
	return lerpf(least_score, 1.0, neatness)


# The container's contents tip out onto the patch: its liquid's gone.
func _turn_out() -> void:
	var pot := session.surface(turn_out)
	if pot == null or pot.liquid == null:
		return
	var at := session.surface(on_surface).position
	pot.liquid.visible = false
	session.burst(at + Vector3(0.0, 0.02, 0.0), pot.liquid_color(), 12, 0.25)
	session.play_sound("plop", at, -2.0, 0.8)
	session.pop_text("Turn it out!", at, 0)


# A dashed square round the patch to coat.
func _make_outline() -> Node3D:
	var outline := Node3D.new()
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(1.0, 1.0, 1.0, 0.7)
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for side in 4:
		var span := patch.x if side < 2 else patch.y
		for i in 6:
			var dash := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(span / 6.0 * 0.6, 0.002, 0.005)
			mesh.material = paint
			dash.mesh = mesh
			var along := -span * 0.5 + (i + 0.5) * span / 6.0
			match side:
				0: dash.position = Vector3(along, 0.001, -patch.y * 0.5)
				1: dash.position = Vector3(along, 0.001, patch.y * 0.5)
				2: dash.position = Vector3(-patch.x * 0.5, 0.001, along)
				3: dash.position = Vector3(patch.x * 0.5, 0.001, along)
			if side >= 2:
				dash.rotation.y = PI * 0.5
			outline.add_child(dash)
	outline.position = session.surface(on_surface).position
	session.add_child(outline)
	return outline


# A shaker of powder, tipped over: its cap toward what it dusts.
func _make_shaker() -> Node3D:
	var shaker := Node3D.new()
	var body := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.022
	mesh.bottom_radius = 0.025
	mesh.height = 0.07
	var tin := StandardMaterial3D.new()
	tin.albedo_color = Color(0.88, 0.9, 0.95)
	tin.metallic = 0.5
	mesh.material = tin
	body.mesh = mesh
	shaker.add_child(body)
	var cap := MeshInstance3D.new()
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 0.024
	cap_mesh.height = 0.028
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(coat_color, 1.0)
	cap_mesh.material = white
	cap.mesh = cap_mesh
	cap.position.y = 0.036
	shaker.add_child(cap)
	shaker.rotation.z = 2.6
	session.add_child(shaker)
	return shaker
