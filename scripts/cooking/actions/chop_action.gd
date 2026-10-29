# ChopAction: chop what's on a surface into even slices. The pieces lie on the
# board with faint marks where the cuts go; the knife follows the cursor and
# each press brings it down. A cut scores how close it lands to the nearest
# mark still uncut on that piece (even slices) and how close it falls to the
# beat, which ticks (and pulses the marks) so there's something to chop to.
# Pressing with the knife off the food just knocks the board.
class_name ChopAction
extends CookAction

@export var on_surface := "Board"
@export var cuts := 0                      # Cuts in all; 0 = the ingredients' own count ("chops" in data/dish_kitchen.json).
@export var cuts_per_piece := 3            # One piece of food per this many cuts.
@export_group("Pieces")
@export var piece_length := 0.34
@export var piece_radius := 0.034
@export var taper := 0.45                  # How much thinner the right end is (0 = straight, like a cucumber).
@export var piece_spacing := 0.1           # Between pieces, front to back.
@export var piece_color := Color(0.95, 0.55, 0.15)  # When there are no ingredients to take the color from.
@export_group("Feel")
@export var beat_seconds := 0.45           # The rhythm to chop to.
@export var beat_tolerance := 0.16         # Seconds off the beat that scores nothing.
@export var perfect_offset := 0.006        # Meters off a mark that still gets full marks...
@export var worst_offset := 0.035          # ...and the offset that gets none.
@export var even_weight := 0.65            # Evenness's share of the score; rhythm gets the rest.
@export var knife_height := 0.08           # How high the knife hovers between chops.
@export var knife_tilt := 25.0             # Degrees the knife leans, so you see the blade from above.
@export var chop_seconds := 0.1            # The knife's way down (and twice that back up).
@export var grab_margin := 0.02            # How far beside a piece the knife still cuts it.
@export var slice_gap := 0.004             # How far apart the slices sit once cut.

var _pieces: Array[Dictionary] = []        # { node, left, right, z, marks, cuts (x positions), color, mark_nodes }
var _knife: Node3D
var _chopping := false
var _time := 0.0
var _last_beat := -1
var _even: Array[float] = []
var _rhythm: Array[float] = []
var _left := 0


func _begin() -> void:
	var total := cuts
	if total <= 0:
		total = session.ingredients.chops_needed() if session.ingredients != null else 5
	var color := session.ingredients.color() if session.ingredients != null else piece_color
	var count := clampi(ceili(float(total) / cuts_per_piece), 1, 3)
	var board := session.surface(on_surface).position
	for i in count:
		var piece_cuts := total / count + (1 if i < total % count else 0)
		var z := board.z + (i - (count - 1) * 0.5) * piece_spacing
		var left := board.x - piece_length * 0.5
		var piece := { "node": Node3D.new(), "left": left, "right": left + piece_length, "z": z,
			"marks": [], "cuts": [], "color": color, "mark_nodes": [] }
		for m in piece_cuts:
			piece["marks"].append(left + piece_length * (m + 1) / (piece_cuts + 1))
		piece["node"].position = Vector3(0.0, board.y, z)
		session.add_child(piece["node"])
		_pieces.append(piece)
		_build(piece)
		_left += piece_cuts
	_knife = _make_knife()
	_knife.position = Vector3(board.x, board.y + knife_height, board.z)


func end() -> void:
	if _knife != null:
		_knife.queue_free()


func update(delta: float, input: CookInput) -> void:
	_time += delta
	var beat := int(_time / beat_seconds)
	if beat != _last_beat and _left > 0:
		_last_beat = beat
		session.play_sound("tick", _knife.position, -10.0, 0.8)
		for piece in _pieces:
			for mark: Node3D in piece["mark_nodes"]:
				_pulse(mark)
	session.set_status("Cuts left: %d" % _left)
	if not _chopping:
		var goal := Vector3(input.cursor.x, session.surface(on_surface).position.y + knife_height, input.cursor.z)
		_knife.position = _knife.position.lerp(goal, 1.0 - exp(-20.0 * delta))
		if input.just_pressed and _left > 0:
			_chop(input.cursor)
	if _left == 0 and not _chopping:
		var even := average(_even)
		finish(even * even_weight + average(_rhythm) * (1.0 - even_weight))


func _chop(spot: Vector3) -> void:
	_chopping = true
	var board_y := session.surface(on_surface).position.y
	var tween := _knife.create_tween()
	tween.tween_property(_knife, "position", Vector3(spot.x, board_y, spot.z), chop_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var off_beat := fmod(_time, beat_seconds)  # Judged when you press, not when the knife lands.
	off_beat = minf(off_beat, beat_seconds - off_beat)
	tween.tween_callback(_land.bind(spot, 1.0 - clampf(off_beat / beat_tolerance, 0.0, 1.0)))
	tween.tween_property(_knife, "position:y", board_y + knife_height, chop_seconds * 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): _chopping = false)


func _land(spot: Vector3, on_beat: float) -> void:
	var piece := _piece_at(spot)
	if piece.is_empty() or piece["marks"].is_empty():
		session.play_sound("clack", spot)
		session.wobble(_knife, 0.1)
		return
	# The nearest mark still to cut on this piece is the one this cut is for.
	var marks: Array = piece["marks"]
	var nearest: float = marks[0]
	for mark: float in marks:
		if absf(mark - spot.x) < absf(nearest - spot.x):
			nearest = mark
	marks.erase(nearest)
	var x := clampf(spot.x, piece["left"] + 0.01, piece["right"] - 0.01)
	piece["cuts"].append(x)
	piece["cuts"].sort()
	_left -= 1

	var even := 1.0 - clampf((absf(x - nearest) - perfect_offset) / (worst_offset - perfect_offset), 0.0, 1.0)
	_even.append(even)
	_rhythm.append(on_beat)

	_build(piece)
	var at := Vector3(x, session.surface(on_surface).position.y + piece_radius, piece["z"])
	session.play_sound("chop", at, 0.0, lerpf(0.9, 1.15, on_beat))
	session.burst(at, piece["color"], 10, 0.3)
	var score := even * even_weight + on_beat * (1.0 - even_weight)
	var words := "Perfect!" if score >= 0.9 else ("Even!" if even >= 0.8 else ("Nice" if score >= 0.6 else ("Uneven!" if even < on_beat else "Off beat!")))
	session.pop_text(words, at, CookSession.mood_of(score))


# The piece the knife is over, or {} for none.
func _piece_at(spot: Vector3) -> Dictionary:
	for piece in _pieces:
		if absf(spot.z - piece["z"]) <= piece_radius + grab_margin \
				and spot.x >= piece["left"] - grab_margin and spot.x <= piece["right"] + grab_margin:
			return piece
	return {}


# The piece as slices between its cuts (one whole piece before any), lying
# along x and tapering to the right, with its marks above it.
func _build(piece: Dictionary) -> void:
	var node: Node3D = piece["node"]
	for child in node.get_children():
		child.queue_free()
	var flesh := StandardMaterial3D.new()
	flesh.albedo_color = piece["color"]
	flesh.roughness = 0.6
	var edges: Array = [piece["left"]]
	edges.append_array(piece["cuts"])
	edges.append(piece["right"])
	var count := edges.size() - 1
	for i in count:
		var a: float = edges[i] + (slice_gap * 0.5 if i > 0 else 0.0)
		var b: float = edges[i + 1] - (slice_gap * 0.5 if i < count - 1 else 0.0)
		var slice := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.bottom_radius = _radius_at(piece, a)
		mesh.top_radius = _radius_at(piece, b)
		mesh.height = b - a
		mesh.radial_segments = 16
		mesh.rings = 1
		mesh.material = flesh
		slice.mesh = mesh
		slice.rotation.z = -PI * 0.5  # Its top (the thin end) points right.
		var middle := (a + b) * 0.5
		# Slices roll apart a touch from the middle once cut.
		var spread := (i - (count - 1) * 0.5) * slice_gap if count > 1 else 0.0
		slice.position = Vector3(middle + spread, _radius_at(piece, middle), 0.0)
		node.add_child(slice)
	var marks := []
	for mark: float in piece["marks"]:
		marks.append(_make_mark(node, mark, _radius_at(piece, mark)))
	piece["mark_nodes"] = marks


# The marks swell on each beat.
func _pulse(mark: Node3D) -> void:
	var tween := mark.create_tween()
	mark.scale = Vector3(2.2, 1.0, 1.25)
	tween.tween_property(mark, "scale", Vector3.ONE, beat_seconds * 0.6).set_ease(Tween.EASE_OUT)


func _radius_at(piece: Dictionary, x: float) -> float:
	var t := clampf((x - piece["left"]) / (piece["right"] - piece["left"]), 0.0, 1.0)
	return piece_radius * (1.0 - taper * t)


# A thin white line over the piece where a cut should go.
func _make_mark(parent: Node3D, x: float, radius: float) -> MeshInstance3D:
	var mark := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.003, 0.002, radius * 2.0 + 0.02)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 1.0, 1.0, 0.8)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	mark.mesh = mesh
	mark.position = Vector3(x, radius * 2.0 + 0.004, 0.0)
	parent.add_child(mark)
	return mark


# A chef's knife, its origin at the middle of the blade's edge. The blade runs
# front to back across the food, the handle toward the cook.
func _make_knife() -> Node3D:
	var knife := Node3D.new()
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.85, 0.87, 0.9)
	steel.metallic = 0.7
	steel.roughness = 0.25
	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.004, 0.045, 0.16)
	blade_mesh.material = steel
	blade.mesh = blade_mesh
	blade.position = Vector3(0.0, 0.0225, -0.02)
	knife.add_child(blade)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.35, 0.24, 0.16)
	var handle := MeshInstance3D.new()
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.016, 0.022, 0.09)
	handle_mesh.material = wood
	handle.mesh = handle_mesh
	handle.position = Vector3(0.0, 0.034, 0.105)
	knife.add_child(handle)
	knife.rotation.z = deg_to_rad(knife_tilt)
	session.add_child(knife)
	return knife
