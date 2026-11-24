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
@export var fade_seconds := 0.0           # Above 0: each blob melts away this long after it's put down (butter on a hot griddle).
@export var glaze := false                 # Brush: no blobs; each piece brushed just turns glossy (butter on croissants), a few dabs each.
@export var glaze_dabs := 4                # glaze: dabs for a piece to be fully shiny.
@export var spots := 0                     # Above 0: this many marked spots on each piece (along a pretzel's rope) to land it on; only the piece itself catches it.

const SPOT_REACH := 0.013

var _left := 0.0
var _last = null                           # Where the last blob went (Vector2), or null between strokes.
var _blobs: Array[Vector2] = []            # On what's to be coated.
var _missed := 0
var _tool: Node3D
var _blob_mesh: Mesh
var _outline: Node3D
var _cookies: Array = []
var _touched := {}                         # Pieces with some on (each_some).
var _dabs := {}                            # glaze: piece -> dabs so far.
var _gloss_from := {}                      # glaze: piece -> its roughness before.
var _spots: Array = []                     # spots: [piece, local point (x, z), marker or null once salted].
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


func marks_spot() -> bool:
	return true


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
	if spots > 0:
		_make_spots()


func end() -> void:
	_tool.queue_free()
	_sound.queue_free()
	if _outline != null:
		_outline.queue_free()
	for spot: Array in _spots:
		if spot[2] != null:
			(spot[2] as Node).queue_free()


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
	if spots > 0:
		var salted := _salted()
		session.set_status("%s on %d of %d spots" % [coat_name, salted, _spots.size()])
		if salted >= _spots.size() or _left <= 0.0:
			var share := float(salted) / maxi(_spots.size(), 1)
			session.pop_text("Perfect!" if share >= 1.0 else ("Nearly" if share >= 0.75 else "Some missed"), view_point(), CookSession.mood_of(share))
			finish(lerpf(least_score, 1.0, share))
		return
	if glaze:
		var shine := _glaze_share()
		session.set_status("%s left: %d%%  -  shiny %d%%" % [coat_name, ceili(_left / seconds * 100.0), roundi(shine * 100.0)])
		if _left <= 0.0 or (not input.held and shine >= 1.0):
			var waste := float(_missed) / maxi(_missed + _blobs.size(), 1)
			var score := lerpf(least_score, 1.0, shine * (1.0 - clampf(waste * 0.6, 0.0, 0.5)))
			session.pop_text("Lovely and shiny!" if score >= 0.85 else ("Some aren't shiny" if shine < 1.0 else "Messy"), view_point(), CookSession.mood_of(score))
			finish(score)
		return
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
		if glaze:  # Just shines up the piece under it.
			var piece: Variant = _target_at(at)
			if piece is MeshInstance3D:
				_blobs.append(at)
				_shine(piece)
			else:
				_missed += 1
			continue
		if spots > 0:
			_salt_spots(at)
		var blob := MeshInstance3D.new()
		blob.mesh = _blob_mesh
		var target: Variant = _target_at(at)
		blob.position = Vector3(at.x, _height_at(at) + 0.001, at.y)
		blob.rotation.y = randf() * TAU
		if fade_seconds > 0.0:  # Sizzles into the griddle and goes.
			var melt := blob.create_tween()
			melt.tween_property(blob, "scale", Vector3(1.6, 0.2, 1.6), fade_seconds * 0.4).set_delay(fade_seconds * 0.3).set_ease(Tween.EASE_OUT)
			melt.tween_property(blob, "scale", Vector3.ZERO, fade_seconds * 0.3).set_ease(Tween.EASE_IN)
			melt.tween_callback(blob.queue_free)
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
		if spots > 0 and cookie.has_meta("rope"):  # Only on the rope itself, not the holes.
			if _rope_gap(cookie, point) <= float(cookie.get_meta("rope_radius", 0.01)) * 1.4:
				return cookie
			continue
		if CookSession.on_piece(cookie, point):
			return cookie
	return null


# How far a point is from a pretzel's rope (its path kept by TraceAction).
func _rope_gap(cookie: MeshInstance3D, point: Vector2) -> float:
	var path: PackedVector2Array = cookie.get_meta("rope")
	var local := point - Vector2(cookie.position.x, cookie.position.z)
	var best := INF
	for i in path.size() - 1:
		best = minf(best, local.distance_to(Geometry2D.get_closest_point_to_segment(local, path[i], path[i + 1])))
	return best


# --- glaze --------------------------------------------------------------------

# One more dab on a piece: a bit glossier, up to fully shiny.
func _shine(piece: MeshInstance3D) -> void:
	var material := (piece.mesh as CylinderMesh).material as StandardMaterial3D if piece.mesh is CylinderMesh else null
	if material == null:
		return
	if not _gloss_from.has(piece):
		_gloss_from[piece] = material.roughness
		material.clearcoat_enabled = true
		material.clearcoat_roughness = 0.15
	_dabs[piece] = mini(int(_dabs.get(piece, 0)) + 1, glaze_dabs)
	var share := float(_dabs[piece]) / glaze_dabs
	material.roughness = lerpf(_gloss_from[piece], 0.18, share)
	material.clearcoat = share
	material.metallic_specular = lerpf(0.5, 0.85, share)
	_touched[piece] = true
	if _dabs[piece] == glaze_dabs and share >= 1.0 and not piece.has_meta("glazed"):
		piece.set_meta("glazed", true)
		session.sparkle(piece.position + Vector3(0.0, 0.03, 0.0))


func _glaze_share() -> float:
	if _cookies.is_empty():
		return 1.0
	var total := 0.0
	for cookie in _cookies:
		total += float(_dabs.get(cookie, 0)) / glaze_dabs
	return total / _cookies.size()


# --- spots --------------------------------------------------------------------

# Little rings on each piece where it should go: evenly along a pretzel's rope,
# or round a piece's middle.
func _make_spots() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.006
	ring.outer_radius = 0.0085
	ring.rings = 12
	ring.ring_segments = 4
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.55, 0.85, 1.0, 0.9)
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.no_depth_test = true
	ring.material = paint
	for cookie: MeshInstance3D in _cookies:
		var points: Array[Vector2] = []
		if cookie.has_meta("rope"):
			var path: PackedVector2Array = cookie.get_meta("rope")
			var lengths: Array[float] = [0.0]
			for i in path.size() - 1:
				lengths.append(lengths[-1] + path[i].distance_to(path[i + 1]))
			for n in spots:
				var want: float = lengths[-1] * (n + 0.5) / spots
				var i := 0
				while i < path.size() - 2 and lengths[i + 1] < want:
					i += 1
				points.append(path[i].lerp(path[i + 1], clampf((want - lengths[i]) / maxf(lengths[i + 1] - lengths[i], 0.0001), 0.0, 1.0)))
		else:
			var half := CookSession.half_of(cookie) * 0.55
			for n in spots:
				points.append(Vector2.from_angle(TAU * n / spots) * half)
		for point in points:
			var marker := MeshInstance3D.new()
			marker.mesh = ring
			marker.position = Vector3(cookie.position.x + point.x, cookie.position.y + CookSession.top_of(cookie) + 0.004, cookie.position.z + point.y)
			session.add_child(marker)
			_spots.append([cookie, point, marker])


# Salt landing here covers any spot it's near.
func _salt_spots(at: Vector2) -> void:
	for spot: Array in _spots:
		if spot[2] == null:
			continue
		var cookie: MeshInstance3D = spot[0]
		var where := Vector2(cookie.position.x, cookie.position.z) + (spot[1] as Vector2)
		if where.distance_to(at) <= SPOT_REACH:
			var marker: MeshInstance3D = spot[2]
			spot[2] = null
			var pop := marker.create_tween()
			pop.tween_property(marker, "scale", Vector3(1.6, 1.0, 1.6), 0.1)
			pop.tween_property(marker, "scale", Vector3.ZERO, 0.12)
			pop.tween_callback(marker.queue_free)


func _salted() -> int:
	var count := 0
	for spot: Array in _spots:
		if spot[2] == null:
			count += 1
	return count


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
				0: dash.position = Vector3(along, 0.007, -patch.y * 0.5)
				1: dash.position = Vector3(along, 0.007, patch.y * 0.5)
				2: dash.position = Vector3(-patch.x * 0.5, 0.007, along)
				3: dash.position = Vector3(patch.x * 0.5, 0.007, along)
			if side >= 2:
				dash.rotation.y = PI * 0.5
			outline.add_child(dash)
	outline.position = session.surface(on_surface).position
	session.add_child(outline)
	return outline


# A shaker of powder, tipped over: its cap toward what it dusts.
func _make_shaker() -> Node3D:
	var shaker := KitchenProps.shaker(Color(coat_color, 1.0), KitchenProps.CREAM)
	shaker.rotation.z = 2.6
	session.add_child(shaker)
	return shaker


# --- For a reel -----------------------------------------------------------------

var _scripted_route: Array = []            # [point, paint?] in order.
var _scripted_next := 0
var _scripted_stuck := 0.0                 # Seconds spent heading for the current stop.
var _scripted_speed := 0.5


# Back and forth over each piece (or the patch), let go between them, done once
# there's enough on.
func scripted_hold(delta: float, input: CookInput) -> bool:
	if glaze and _glaze_share() >= 1.0:
		return false
	if spots == 0 and not glaze:
		if each_some and _touched.size() >= _cookies.size():
			return false
		if not each_some and _coverage() >= target_coverage:
			return false
	if spots > 0:  # Straight to the next ring still wanting salt, shaking.
		for spot: Array in _spots:
			if spot[2] != null:
				var cookie: Node3D = spot[0]
				input.move_to(cookie.position + Vector3(spot[1].x, 0.0, spot[1].y), delta, 0.5)
				return true
		return false
	if _scripted_route.is_empty():
		_scripted_route = _scripted_plan()
	var stop: Array = _scripted_route[_scripted_next % _scripted_route.size()]
	_scripted_stuck += delta
	# Arrived, or the cursor can't get there (kept inside the tray): on to the next.
	if input.move_to(stop[0], delta, _scripted_speed if stop[1] else 1.2) or _scripted_stuck > 1.5:
		_scripted_next += 1
		_scripted_stuck = 0.0
	return stop[1]


func _scripted_plan() -> Array:
	var areas := []  # [middle, half size]
	if not on_surface.is_empty():
		areas.append([session.surface(on_surface).position, patch * 0.5 * 0.85])
	else:
		for cookie: MeshInstance3D in _cookies:
			areas.append([cookie.position, CookSession.half_of(cookie) * 0.7])
	var step := blob_radius * (2.4 if tool == "shaker" else 1.8)
	var route := []
	var painted := 0.0
	for area in areas:
		var middle: Vector3 = area[0]
		var half: Vector2 = area[1]
		var rows := maxi(ceili(half.y * 2.0 / step), 2)
		for row in rows:
			var z := middle.z - half.y + half.y * 2.0 * row / (rows - 1)
			var x_from := -half.x if row % 2 == 0 else half.x
			if row == 0:
				route.append([Vector3(middle.x + x_from, 0.0, z), false])
			else:
				route.append([Vector3(middle.x + x_from, 0.0, z), true])
				painted += half.y * 2.0 / (rows - 1)
			route.append([Vector3(middle.x - x_from, 0.0, z), true])
			painted += half.x * 2.0
	_scripted_speed = clampf(painted / (seconds * 0.8), 0.2, 1.0)
	return route
