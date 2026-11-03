# FillAction: pour to a line, like a drink at the drink station. Hold the
# button to pour and let go at the line: the closer, the better, and once it
# gets to spill_at times the line it spills over (scoring little). It fills
# one thing at a time, the jug moving on by itself:
#   - into a container surface (a saucepan, a bowl: CookSurface.depth), its
#     liquid rising to a line marked inside it;
#   - into each cut piece in turn (the context's "cookies", e.g. tart cases): a
#     rim goes round each and the filling rises inside it to a line on the rim;
#   - with spread, onto the first cut piece: the filling spreads out flat
#     toward a dashed outline (apples on a strudel), and past spill_at it runs
#     over the edge.
class_name FillAction
extends CookAction

@export var into := ""                     # A container surface; empty: the cut pieces.
@export var spread := false                # Spread over the first cut piece instead.
@export var liquid_name := "Milk"          # For the status line.
@export var liquid_color := Color(0.97, 0.96, 0.92)
@export var line := 0.6                    # The line: how full (container), or how far out (spread), it should get.
@export var fill_seconds := 1.6            # Holding this long fills to the line (longer on Easy).
@export var spill_at := 1.25               # This many times the line spills over.
@export var perfect_within := 0.06         # This far off the line (as a share of it) still gets full marks.
@export var rim_height := 0.016            # Pieces: how tall the rim round each case is.
@export var pour_height := 0.15            # The jug's spout above what it fills.

var _targets: Array = []                   # Cookies, or [the container].
var _index := 0
var _fill := 0.0                           # How far the current one has got toward the line (1 = at it).
var _pouring := false
var _settling := 0.0                       # Moving on to the next one.
var _scores: Array[float] = []
var _jug: Node3D
var _stream: MeshInstance3D
var _mark: Node3D
var _filling: MeshInstance3D               # Pieces: the current one's filling.
var _glug: AudioStreamPlayer3D


func view_point() -> Vector3:
	if not into.is_empty():
		return session.surface(into).position
	var middle := Vector3.ZERO
	for cookie: Node3D in _targets:
		middle += cookie.position
	return middle / maxf(_targets.size(), 1) if not _targets.is_empty() else super.view_point()


func uses_cursor() -> bool:
	return false


func _begin() -> void:
	if not into.is_empty():
		_targets = [session.surface(into)]
	elif spread:
		_targets = session.context.get("cookies", []).slice(0, 1)
	else:
		_targets = session.context.get("cookies", []).duplicate()
	if _targets.is_empty():
		finish(1.0)
		return
	_jug = session.make_jug(liquid_color)
	_glug = session.loop_sound("pour", -8.0)
	_stream = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.004
	mesh.bottom_radius = 0.006
	mesh.height = 1.0
	var material := StandardMaterial3D.new()
	material.albedo_color = liquid_color
	mesh.material = material
	_stream.mesh = mesh
	_stream.visible = false
	session.add_child(_stream)
	if into.is_empty() and not spread:
		for cookie: MeshInstance3D in _targets:
			_add_rim(cookie)
	_start_on(0)


func end() -> void:
	if _jug != null:
		_jug.queue_free()
		_stream.queue_free()
		_glug.queue_free()
	if _mark != null:
		_mark.queue_free()


func update(delta: float, input: CookInput) -> void:
	var target: Node3D = _targets[mini(_index, _targets.size() - 1)]
	var spout := _spout_of(target)
	_jug.position = _jug.position.lerp(spout, 1.0 - exp(-12.0 * delta))
	_jug.rotation.z = lerp_angle(_jug.rotation.z, deg_to_rad(55.0) if _pouring else 0.0, 1.0 - exp(-12.0 * delta))
	if _settling > 0.0:
		_settling -= delta
		if _settling <= 0.0:
			_start_on(_index)
		return
	if not _pouring and input.just_pressed:
		_pouring = true
	if _pouring:
		_fill += delta / fill_seconds * GameState.difficulty_value("closeup_pace")
		_show_fill(target)
		if not _glug.playing:
			_glug.play()
		if not input.held or _fill >= spill_at:
			_stop(target)
	_stream.visible = _pouring
	if _pouring:
		var below := _surface_y(target)
		_stream.position = Vector3(_jug.position.x, (below + _jug.position.y) * 0.5, _jug.position.z)
		_stream.scale = Vector3(1.0, maxf(_jug.position.y - below, 0.01), 1.0)
	var words := "Hold %s to pour, let go at the line" % "the button" if not _pouring else ("%d%% of the line" % roundi(_fill * 100.0))
	session.set_status("%s %d of %d: %s" % [liquid_name, _index + 1, _targets.size(), words] if _targets.size() > 1 else "%s: %s" % [liquid_name, words])


func _start_on(index: int) -> void:
	_index = index
	_fill = 0.0
	_pouring = false
	var target: Node3D = _targets[index]
	if _mark != null:
		_mark.queue_free()
	_mark = _make_mark(target)
	if into.is_empty():
		_filling = MeshInstance3D.new()
		var mesh: Mesh
		var footprint := CookSession.half_of(target)
		if spread:  # A flat layer the piece's shape, spreading out.
			mesh = BoxMesh.new()
			(mesh as BoxMesh).size = Vector3(footprint.x * 2.0, 0.008, footprint.y * 2.0)
		else:
			mesh = CylinderMesh.new()
			(mesh as CylinderMesh).top_radius = footprint.x * 0.82
			(mesh as CylinderMesh).bottom_radius = footprint.x * 0.82
			(mesh as CylinderMesh).height = 0.002
		var material := StandardMaterial3D.new()
		material.albedo_color = liquid_color
		material.roughness = 0.35
		mesh.surface_set_material(0, material)
		_filling.mesh = mesh
		_filling.set_meta("own_material", true)
		_filling.scale = Vector3(0.001, 1.0, 0.001) if spread else Vector3.ONE
		_filling.position.y = CookSession.top_of(target) + 0.003
		_filling.visible = false
		target.add_child(_filling)


func _show_fill(target: Node3D) -> void:
	if not into.is_empty():
		(target as CookSurface).fill_to(_fill * line, liquid_color)
		return
	_filling.visible = true
	if spread:  # Out from the middle; at the line it's line of the way to the edge.
		var out := sqrt(_fill) * line
		_filling.scale = Vector3(out, 1.0, out)
	else:  # Up the case.
		var height := maxf(rim_height * line * _fill, 0.002)
		(_filling.mesh as CylinderMesh).height = height
		_filling.position.y = CookSession.top_of(target) + height * 0.5


func _stop(target: Node3D) -> void:
	_pouring = false
	_glug.stop()
	_stream.visible = false
	var spilled := _fill >= spill_at
	var error := absf(_fill - 1.0)
	var score := 0.2 if spilled else (1.0 if error <= perfect_within else clampf(1.0 - (error - perfect_within) / 0.45, 0.1, 1.0))
	_scores.append(score)
	var at := Vector3(target.position.x, _surface_y(target), target.position.z)
	if spilled:
		session.burst(at, liquid_color, 14, 0.4)
		session.pop_text("Spilled over!", at, -1)
	else:
		session.pop_text("Right to the line!" if score >= 0.95 else ("Nearly" if score >= 0.7 else ("Too little" if _fill < 1.0 else "Too much!")), at, CookSession.mood_of(score))
	session.play_sound("plop", at, -8.0, 1.2)
	if _index + 1 < _targets.size():
		_index += 1
		_settling = 0.35
	else:
		_mark.visible = false
		finish(average(_scores))


# Where the jug's spout goes: above the middle of what it fills.
func _spout_of(target: Node3D) -> Vector3:
	return Vector3(target.position.x - 0.01, _surface_y(target) + pour_height, target.position.z)


func _surface_y(target: Node3D) -> float:
	if not into.is_empty():
		return (target as CookSurface).liquid_top()
	return target.position.y + CookSession.top_of(target)


# The line to fill to: a white ring inside the container (or round the case's
# rim), or a dashed outline on the piece (spread).
func _make_mark(target: Node3D) -> Node3D:
	if spread:
		var outline := Node3D.new()
		var half := CookSession.half_of(target) * line
		var paint := StandardMaterial3D.new()
		paint.albedo_color = Color(1.0, 1.0, 1.0, 0.85)
		paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		paint.no_depth_test = true
		for side in 4:
			var span := half.x * 2.0 if side < 2 else half.y * 2.0
			var dashes := 5
			for i in dashes:
				var dash := MeshInstance3D.new()
				var mesh := BoxMesh.new()
				mesh.size = Vector3(span / dashes * 0.6, 0.002, 0.004)
				mesh.material = paint
				dash.mesh = mesh
				var along := -span * 0.5 + (i + 0.5) * span / dashes
				match side:
					0: dash.position = Vector3(along, 0.0, -half.y)
					1: dash.position = Vector3(along, 0.0, half.y)
					2: dash.position = Vector3(-half.x, 0.0, along)
					3: dash.position = Vector3(half.x, 0.0, along)
				if side >= 2:
					dash.rotation.y = PI * 0.5
				outline.add_child(dash)
		outline.position = Vector3(target.position.x, target.position.y + CookSession.top_of(target) + 0.004, target.position.z)
		session.add_child(outline)
		return outline
	var radius: float
	var at: Vector3
	if not into.is_empty():
		var pot := target as CookSurface
		radius = pot.radius() * 0.95
		at = Vector3(pot.position.x, pot.position.y + pot.depth * line, pot.position.z)
	else:
		radius = CookSession.half_of(target).x * 0.9
		at = Vector3(target.position.x, target.position.y + CookSession.top_of(target) + rim_height * line, target.position.z)
	var ring := session.make_ring(radius, Color(1.0, 1.0, 1.0, 0.9))
	ring.position = at
	return ring


# A tart case's rim: a short wall of the same pastry round the piece.
func _add_rim(cookie: MeshInstance3D) -> void:
	var radius := CookSession.half_of(cookie).x
	var rim := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius * 0.86
	mesh.outer_radius = radius * 1.02
	mesh.rings = 24
	mesh.ring_segments = 8
	rim.mesh = mesh
	rim.material_override = (cookie.mesh as CylinderMesh).material  # Browns with it.
	rim.scale = Vector3(1.0, rim_height / (radius * 0.16), 1.0)
	rim.position.y = CookSession.top_of(cookie) + rim_height * 0.5
	cookie.add_child(rim)
