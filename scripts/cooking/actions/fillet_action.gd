# FilletAction: fillet a fish. It lies on the board with a dotted line along
# its back, from a ring at the head to the tail. Hold the button on the ring
# and draw the knife along the line; it cuts as far as you follow it, and each
# dot you pass scores how close the knife was. Stray too far and the knife
# slips out: hold it again where the cut stopped to carry on. After the first
# side the fish flips for the second. Then it comes apart: two fillets and
# the bones.
class_name FilletAction
extends CookAction

const FOOD := "res://design/assets/Ultimate Food Pack - Oct 2019/FBX/"

@export var on_surface := "Board"
@export var sides := 2
@export var fish_length := 0.46
@export var dots := 14                     # Along each line.
@export var curve := 0.018                 # How far the line bows.
@export_group("Feel")
@export var perfect_offset := 0.008        # Meters off the line that still score full marks...
@export var worst_offset := 0.04           # ...and the offset that scores none.
@export var slip_offset := 0.06            # Further than this and the knife slips out.
@export var grab_reach := 0.05             # How near the cut's end you have to grab to (re)start.
@export var knife_height := 0.05

var _fish: Node3D
var _side := 0
var _t := 0.0                              # How far along this side's line the cut is (0 = head, 1 = tail).
var _cutting := false
var _flipping := false
var _scores: Array[float] = []
var _side_scores: Array[float] = []
var _dot_nodes: Array[MeshInstance3D] = []
var _passed := 0
var _knife: Node3D
var _start_ring: MeshInstance3D
var _dot_material := StandardMaterial3D.new()
var _cut_material := StandardMaterial3D.new()


func uses_cursor() -> bool:
	return false  # The knife shows the spot.


func _begin() -> void:
	var board := session.surface(on_surface).position
	_fish = ModelFit.place(FOOD + "Fish.fbx", session, board, Vector3(fish_length, 0.0, 0.0))
	for material in [_dot_material, _cut_material]:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.no_depth_test = true
	_dot_material.albedo_color = Color(1.0, 1.0, 1.0, 0.9)
	_dot_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cut_material.albedo_color = Color(0.55, 0.12, 0.1)
	_knife = _make_knife()
	_knife.position = board + Vector3(0.0, knife_height, 0.12)
	_start_ring = session.make_ring(0.022, Color(0.6, 1.0, 0.55, 0.9))
	_lay_line()


func end() -> void:
	_knife.queue_free()
	_start_ring.queue_free()


func update(delta: float, input: CookInput) -> void:
	if _flipping or _side >= sides:
		return
	var spot := input.cursor
	var top := _top()
	var goal := Vector3(spot.x, top + (0.0 if _cutting else knife_height), spot.z)
	_knife.position = _knife.position.lerp(goal, 1.0 - exp(-24.0 * delta))
	_start_ring.position = _point(_t) + Vector3(0.0, 0.003, 0.0)
	_start_ring.visible = not _cutting
	session.set_status("Side %d of %d: %d%% cut" % [_side + 1, sides, roundi(_t * 100.0)])

	if not _cutting:
		if input.just_pressed and _flat(spot - _point(_t)).length() <= grab_reach:
			_cutting = true
			session.play_sound("chop", spot, -10.0, 1.4)
		return
	if not input.held:
		_cutting = false
		return
	# Follow the line: the cut goes as far along as the knife gets, as long as it stays close.
	var along := _nearest_t(spot)
	var off := _flat(spot - _point(along)).length()
	if off > slip_offset:
		_cutting = false
		session.pop_text("Slipped!", spot, -1)
		session.play_sound("clack", spot, -4.0)
		return
	if along > _t and along - _t < 0.15:
		_t = along
		var score := 1.0 - clampf((off - perfect_offset) / (worst_offset - perfect_offset), 0.0, 1.0)
		while _passed < dots and float(_passed) / (dots - 1) <= _t + 0.001:
			_dot_nodes[_passed].material_override = _cut_material
			_side_scores.append(score)
			_passed += 1
			session.play_sound("chop", _point(_t), -16.0, randf_range(1.5, 1.8))
		if _passed >= dots or _t >= 0.99:
			_finish_side()


# For a reel: press on the ring, then draw the knife along the line.
func scripted_hold(delta: float, input: CookInput) -> bool:
	if _flipping or _side >= sides:
		return false
	if not _cutting:
		return input.move_to(_point(_t), delta, 1.2) and not input.held
	input.move_to(_point(minf(_t + 0.06, 1.0)), delta, 0.3)
	return true


func _finish_side() -> void:
	_cutting = false
	while _passed < dots:  # The last dots go with the end of the cut.
		_side_scores.append(_side_scores[-1] if not _side_scores.is_empty() else 1.0)
		_passed += 1
	var score := average(_side_scores)
	_scores.append(score)
	session.pop_text("Clean cut!" if score >= 0.85 else ("Not bad" if score >= 0.6 else "Ragged!"), _point(1.0), CookSession.mood_of(score))
	session.burst(_point(1.0), Color(0.95, 0.6, 0.45), 8, 0.25)
	_side += 1
	_flipping = true
	if _side < sides:
		await _flip()
		_t = 0.0
		_passed = 0
		_side_scores.clear()
		_lay_line()
		_flipping = false
	else:
		_knife.visible = false
		_start_ring.visible = false
		await _open_up()
		finish(average(_scores))


# Over onto its other side: up, round, down.
func _flip() -> void:
	for node in _dot_nodes:
		node.queue_free()
	_dot_nodes.clear()
	var lift := _fish.create_tween()
	lift.tween_property(_fish, "position:y", _fish.position.y + 0.1, 0.15).set_ease(Tween.EASE_OUT)
	lift.tween_property(_fish, "rotation:x", _fish.rotation.x + PI, 0.25)
	lift.tween_property(_fish, "position:y", _rest_height(), 0.15).set_ease(Tween.EASE_IN)
	session.play_sound("whoosh", _fish.position, -10.0)
	await lift.finished
	session.play_sound("plop", _fish.position, -4.0, 0.8)
	session.wobble(_fish, 0.08)


# The fish comes apart: two fillets either side, the bones pushed to the back.
func _open_up() -> void:
	for node in _dot_nodes:
		node.queue_free()
	_dot_nodes.clear()
	var board := session.surface(on_surface).position
	var fade := _fish.create_tween()
	fade.tween_property(_fish, "scale", Vector3(1.0, 0.2, 1.0), 0.2)
	await fade.finished
	_fish.queue_free()
	var bones := ModelFit.place(FOOD + "FishBone.fbx", session, board + Vector3(0.0, 0.0, -0.11), Vector3(fish_length * 0.75, 0.0, 0.0))
	session.wobble(bones, 0.15)
	for side in [-1.0, 1.0]:
		var fillet := ModelFit.place(FOOD + "Sashimi_Salmon.fbx", session, board + Vector3(side * 0.12, 0.0, 0.06), Vector3(0.2, 0.0, 0.0))
		fillet.rotation.y = side * 0.25
		session.wobble(fillet, 0.2)
	session.play_sound("plop", board, -2.0, 1.2)
	await session.get_tree().create_timer(0.5).timeout


# The line for this side: dots from the head (+x) to the tail, bowing a little
# one way, then the other way once flipped.
func _lay_line() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.004
	mesh.height = 0.008
	mesh.radial_segments = 8
	mesh.rings = 4
	for i in dots:
		var dot := MeshInstance3D.new()
		dot.mesh = mesh
		dot.material_override = _dot_material
		dot.position = _point(float(i) / (dots - 1))
		session.add_child(dot)
		_dot_nodes.append(dot)


# A point on this side's line (0 = head, 1 = tail), on top of the fish.
func _point(t: float) -> Vector3:
	var board := session.surface(on_surface).position
	var half := fish_length * 0.42
	var bow := curve * (1.0 if _side % 2 == 0 else -1.0)
	return Vector3(board.x + lerpf(half, -half, t), _top(), board.z + sin(t * PI) * bow - 0.008)


func _nearest_t(spot: Vector3) -> float:
	var best := _t
	var best_gap := INF
	for i in 101:
		var t := float(i) / 100.0
		var gap := _flat(spot - _point(t)).length_squared()
		if gap < best_gap:
			best_gap = gap
			best = t
	return best


func _top() -> float:
	return session.surface(on_surface).position.y + fish_length * 0.09


# Where the fish's origin sits: on the board, or (upside down) its height above it.
func _rest_height() -> float:
	var board_y := session.surface(on_surface).position.y
	return board_y + (fish_length * 0.09 if _side % 2 == 1 else 0.0)


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


# A long thin filleting knife, its blade along x (the way it cuts), handle to the right.
func _make_knife() -> Node3D:
	var knife := Node3D.new()
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.85, 0.87, 0.9)
	steel.metallic = 0.7
	steel.roughness = 0.25
	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.15, 0.025, 0.003)
	blade_mesh.material = steel
	blade.mesh = blade_mesh
	blade.position = Vector3(-0.04, 0.0125, 0.0)
	knife.add_child(blade)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.35, 0.24, 0.16)
	var handle := MeshInstance3D.new()
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.09, 0.02, 0.014)
	handle_mesh.material = wood
	handle.mesh = handle_mesh
	handle.position = Vector3(0.08, 0.016, 0.0)
	knife.add_child(handle)
	knife.rotation.x = deg_to_rad(-30.0)  # Leaning, so the blade shows from above.
	session.add_child(knife)
	return knife
