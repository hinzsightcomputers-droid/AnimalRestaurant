# ScrapeAction: get chopped food off a board into a pot. Hold the button on
# the board and carry it over (let go near the pot and it rests on the rim,
# tipped in), then hold the button and push the knife along the board to sweep
# the pieces over the edge. Push gently: a piece shoved in too fast splashes.
# What lands in the pot goes into its contents, for the steps after (stirring).
class_name ScrapeAction
extends CookAction

enum Phase { CARRY, PLACING, SCRAPE, DONE }

@export var from_surface := "Board"
@export var into := "Pot"
@export var pieces := 0                     # Bits of food; 0 = from the ingredients (their chops + 3).
@export var piece_radius := 0.017
@export var piece_thickness := 0.009
@export var piece_color := Color(0.95, 0.55, 0.15)  # When there are no ingredients to take it from.
@export_group("Feel")
@export var rim_height := 0.15              # The top of the pot's rim, above the session...
@export var rim_radius := 0.15              # ...and how far out it is from the pot's middle.
@export var board_thickness := 0.03         # From the board's top down to its underside.
@export var carry_height := 0.05            # How far above the rim the board's underside is carried.
@export var overhang := 0.03                # How far past the rim, toward the middle, its near end reaches.
@export var tilt_degrees := 14.0            # How far it tips toward the pot on the rim.
@export var near_pot := 0.1                 # How far from the pot you can let go and it still goes on the rim.
@export var grab_margin := 0.02
@export var splash_speed := 0.55            # Knife speed (meters a second) that splashes what it pushes in.

var _phase := Phase.CARRY
var _board: CookSurface
var _home := Vector3.ZERO
var _carrying := false
var _side := 1.0                            # The board rests on this side of the pot (+1 = right).
var _on_board: Array[Node3D] = []
var _knife: Node3D
var _knife_u := 0.0                         # The knife along the board: bigger is nearer the pot.
var _falling := 0
var _scores: Array[float] = []


func _begin() -> void:
	_board = session.surface(from_surface)
	_home = _board.position
	var count := pieces
	if count <= 0:
		count = session.ingredients.chops_needed() + 3 if session.ingredients != null else 8
	var color := session.ingredients.color() if session.ingredients != null else piece_color
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	for i in count:
		var piece := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = piece_radius * randf_range(0.75, 1.0)
		mesh.bottom_radius = mesh.top_radius
		mesh.height = piece_thickness
		mesh.radial_segments = 12
		mesh.rings = 1
		mesh.material = material
		piece.mesh = mesh
		piece.position = Vector3(randf_range(-0.4, 0.4) * _board.size.x, piece_thickness * 0.5, randf_range(-0.35, 0.35) * _board.size.y)
		piece.rotation.y = randf() * TAU
		_board.add_child(piece)
		_on_board.append(piece)


func end() -> void:
	if _knife != null:
		_knife.queue_free()


func update(delta: float, input: CookInput) -> void:
	match _phase:
		Phase.CARRY:
			_carry(delta, input)
		Phase.SCRAPE:
			_scrape(delta, input)
	if _phase == Phase.SCRAPE and _on_board.is_empty() and _falling == 0:
		_phase = Phase.DONE
		_knife.queue_free()
		_knife = null
		# Up off the rim and level first, then back down beside the pot.
		var tween := _board.create_tween()
		tween.tween_property(_board, "position:y", _carry_y(), 0.2).set_trans(Tween.TRANS_QUAD)
		tween.parallel().tween_property(_board, "rotation", Vector3.ZERO, 0.2)
		tween.tween_property(_board, "position", Vector3(_home.x, _carry_y(), _home.z), 0.25).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(_board, "position", _home, 0.15).set_trans(Tween.TRANS_QUAD)
		finish(average(_scores))
	session.set_status("Pieces left: %d" % _on_board.size() if _phase == Phase.SCRAPE else "")


func _carry(delta: float, input: CookInput) -> void:
	if not _carrying:
		if input.just_pressed and _board.contains(input.cursor, grab_margin):
			_carrying = true
			session.play_sound("tick", _board.position)
			session.wobble(_board, 0.06)
		return
	var goal := Vector3(input.cursor.x, _carry_y(), input.cursor.z)
	_board.position = _board.position.lerp(goal, 1.0 - exp(-16.0 * delta))
	if input.held:
		return
	_carrying = false
	var pot := session.surface(into)
	var gap := Vector2(_board.position.x - pot.position.x, _board.position.z - pot.position.z).length()
	if gap <= pot.radius() + _board.size.x * 0.5 + near_pot:
		_rest_on_rim(pot)
	else:
		var tween := _board.create_tween()
		tween.tween_property(_board, "position", Vector3(_home.x, _carry_y(), _home.z), 0.25).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(_board, "position", _home, 0.15).set_trans(Tween.TRANS_QUAD)
		session.pop_text("Over the pot!", _home, 0)


# Its top while carried: underside clear of the pot's rim.
func _carry_y() -> float:
	return rim_height + carry_height + board_thickness


# Resting on the rim, tipped toward the pot: its underside touches the top of
# the rim, and its near end reaches over the soup.
func _rest_on_rim(pot: CookSurface) -> void:
	_phase = Phase.PLACING
	_side = 1.0 if _board.position.x >= pot.position.x else -1.0
	var tilt := deg_to_rad(tilt_degrees)
	var middle_out := rim_radius - overhang + _board.size.x * 0.5 * cos(tilt)  # Pot middle to board middle.
	var top := rim_height + board_thickness / cos(tilt) + (middle_out - rim_radius) * tan(tilt) + 0.004
	var at := Vector3(pot.position.x + _side * middle_out, top, pot.position.z)
	var tween := _board.create_tween().set_parallel(true)
	tween.tween_property(_board, "position", at, 0.25).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_board, "rotation:z", deg_to_rad(tilt_degrees) * _side, 0.25)
	tween.chain().tween_callback(func():
		session.play_sound("plop", at, -4.0, 0.7)
		_knife = _make_knife()
		_knife_u = -_board.size.x * 0.5
		_phase = Phase.SCRAPE)


func _scrape(delta: float, input: CookInput) -> void:
	var half := _board.size.x * 0.5
	# Along the board as seen from above, so the knife is where you point whatever the board's height.
	var along := (input.cursor.x - _board.position.x) / cos(_board.rotation.z)
	var target := clampf(-along * _side, -half, half + 0.02)
	var before := _knife_u
	_knife_u = lerpf(_knife_u, target, 1.0 - exp(-25.0 * delta))
	var speed := absf(_knife_u - before) / maxf(delta, 0.0001)
	_knife.position = Vector3(-_knife_u * _side, 0.0 if input.held else 0.03, 0.0)
	if not input.held or _knife_u <= before:
		return
	# Pieces the knife was behind get pushed ahead of it; past the edge they fall in.
	for piece: Node3D in _on_board.duplicate():
		var u := -piece.position.x * _side
		var back := u - piece_radius
		if back >= before - 0.003 and back < _knife_u:
			u = _knife_u + piece_radius
			piece.position.x = -u * _side
			if u > half:
				_drop(piece, speed)


func _drop(piece: Node3D, speed: float) -> void:
	_on_board.erase(piece)
	_falling += 1
	piece.reparent(session)
	var pot := session.surface(into)
	var spot := Vector2.from_angle(randf() * TAU) * randf_range(0.0, pot.radius() * 0.6)
	var at := pot.position + Vector3(spot.x, piece_thickness * 0.5, spot.y)
	var splash := speed > splash_speed
	var tween := piece.create_tween()
	tween.tween_property(piece, "position", at, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		_falling -= 1
		pot.contents.append(piece)
		_scores.append(0.4 if splash else 1.0)
		session.play_sound("plop", at, -2.0 if splash else -6.0, 0.8 if splash else 1.2)
		session.burst(at, pot.color, 16 if splash else 4, 0.55 if splash else 0.15)
		if splash:
			session.pop_text("Splash!", at, -1))


# A knife lying across the board, edge down, for pushing with.
func _make_knife() -> Node3D:
	var knife := Node3D.new()
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.85, 0.87, 0.9)
	steel.metallic = 0.7
	steel.roughness = 0.25
	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.004, 0.035, _board.size.y * 0.85)
	blade_mesh.material = steel
	blade.mesh = blade_mesh
	blade.position.y = 0.0175
	knife.add_child(blade)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.35, 0.24, 0.16)
	var handle := MeshInstance3D.new()
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.016, 0.022, 0.08)
	handle_mesh.material = wood
	handle.mesh = handle_mesh
	handle.position = Vector3(0.0, 0.025, _board.size.y * 0.425 + 0.04)
	knife.add_child(handle)
	_board.add_child(knife)
	return knife
