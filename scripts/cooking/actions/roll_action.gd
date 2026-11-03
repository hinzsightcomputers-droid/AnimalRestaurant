# RollAction: roll a lump of dough out into a sheet. Hold the button and drag
# the rolling pin across the dough: it stretches the way you roll (left and
# right widens it, up and down lengthens it), getting thinner as it spreads.
# Fill the dashed square: once the sheet is as big as the square it's done,
# scoring how well it matches (roll only one way and you get a long thin
# strip). Leaves the sheet for the next step in the session's context
# "dough": { node, size (x, z), center }. With target_size it's a dashed
# rectangle to fill instead (a long one for croissants). With use_sheet it rolls
# on the sheet already there (folded croissant dough) instead of a new lump.
# A double-headed arrow over the dough shows which way it needs rolling next.
class_name RollAction
extends CookAction

const PIN_MODEL := "res://design/assets/KayKit_Bits_Bundle1_1.1/Restaurant Bits/Assets/gltf/rollingpin.gltf"

@export var on_surface := "Counter"
@export var target := 0.32                 # The square to fill (meters a side)...
@export var target_size := Vector2.ZERO    # ...or this rectangle (x, z), if set.
@export var use_sheet := false             # Roll the sheet left by the last step (the context's "dough").
@export var start_size := 0.12
@export var start_thickness := 0.06
@export var stretch := 0.3                 # How much the dough grows per meter rolled over it.
@export var pin_length := 0.16
@export var dough_color := Color(0.69, 0.48, 0.27)  # When there are no ingredients to take it from.
@export var perfect_within := 0.15         # This far off the outline's shape (both ways added) still gets full marks.

var _size := Vector2.ZERO
var _volume := 0.0
var _dough: MeshInstance3D
var _box := BoxMesh.new()
var _pin: Node3D
var _last := Vector3.ZERO
var _rolling := false
var _center := Vector3.ZERO
var _dashes: Array[Node3D] = []
var _arrow: Node3D                         # Which way to roll next.


func _init() -> void:
	view_distance = 0.5  # Close in on the dough.
	view_pitch = 62.0


func view_point() -> Vector3:
	return session.surface(on_surface).position


func cursor_area() -> Rect2:
	var goal := _goal()
	return Rect2(_center.x - goal.x * 0.5, _center.z - goal.y * 0.5, goal.x, goal.y).grow(0.07)


# The rectangle to fill (x, z).
func _goal() -> Vector2:
	return target_size if target_size != Vector2.ZERO else Vector2(target, target)


func uses_cursor() -> bool:
	return false  # The rolling pin shows the spot.


func _begin() -> void:
	_center = session.surface(on_surface).position
	var sheet: Dictionary = session.context.get("dough", {})
	if use_sheet and is_instance_valid(sheet.get("node")):
		_dough = sheet["node"]
		_box = _dough.mesh as BoxMesh
		_size = sheet["size"]
		_volume = _size.x * _size.y * _box.size.y
		_center = sheet["center"]
	else:
		_size = Vector2(start_size, start_size)
		_volume = start_size * start_size * start_thickness
		var material := StandardMaterial3D.new()
		material.albedo_color = session.ingredients.color() if session.ingredients != null else dough_color
		material.roughness = 0.85
		_box.material = material
		_dough = MeshInstance3D.new()
		_dough.mesh = _box
		_dough.position = _center
		session.add_child(_dough)
	_shape()
	_outline()
	_arrow = Node3D.new()  # Made by _point_arrow.
	session.add_child(_arrow)
	_pin = ModelFit.place(PIN_MODEL, session, _center + Vector3(0.0, 0.1, 0.2), Vector3(pin_length, 0.0, 0.0))


func end() -> void:
	_pin.queue_free()
	_arrow.queue_free()
	for dash in _dashes:
		dash.queue_free()


func update(delta: float, input: CookInput) -> void:
	var spot := Vector3(input.cursor.x, 0.0, input.cursor.z)
	var on_dough := absf(spot.x - _center.x) <= _size.x * 0.5 + 0.03 and absf(spot.z - _center.z) <= _size.y * 0.5 + 0.03
	var pressing := input.held and on_dough
	var goal := Vector3(spot.x, _center.y + (_thickness() if pressing else _thickness() + 0.05), spot.z)
	var moved := spot - _last
	_last = spot
	if pressing and _rolling and moved.length() > 0.0005:
		# Grow the way it's rolled, keeping the dough's volume.
		_size.x += absf(moved.x) * stretch
		_size.y += absf(moved.z) * stretch
		_shape()
		# The pin lies across the way it's rolled (either end first: it's the same pin).
		var across := atan2(-moved.z, moved.x) + PI * 0.5
		if absf(angle_difference(_pin.rotation.y, across)) > PI * 0.5:
			across += PI
		_pin.rotation.y = lerp_angle(_pin.rotation.y, across, 1.0 - exp(-14.0 * delta))
	_rolling = pressing
	_point_arrow(delta)
	_pin.position = _pin.position.lerp(goal, 1.0 - exp(-22.0 * delta))
	var fill := _goal()
	session.set_status("Sheet: %d%% of the %s" % [roundi(minf(_size.x * _size.y / (fill.x * fill.y), 1.0) * 100.0), "square" if fill.x == fill.y else "rectangle"])
	if _size.x * _size.y >= fill.x * fill.y * 0.97:
		var off := absf(_size.x - fill.x) / fill.x + absf(_size.y - fill.y) / fill.y
		var score := clampf(1.0 - maxf(off - perfect_within, 0.0) * 1.5, 0.0, 1.0)
		session.pop_text("Nice and even!" if score >= 0.85 else ("Bit lopsided" if score >= 0.5 else "That's a strip!"), _center, CookSession.mood_of(score))
		session.context["dough"] = { "node": _dough, "size": _size, "center": _center }
		finish(score)


# Along whichever way the sheet is furthest short of the outline, over the
# dough and gently pulsing.
func _point_arrow(delta: float) -> void:
	var fill := _goal()
	var across := _size.x / fill.x < _size.y / fill.y
	var length := (fill.x if across else fill.y) * 0.7
	var way := "%s %.3f" % [across, length]
	if _arrow.get_meta("way", "") != way:  # Remade only when it changes.
		var old := _arrow
		_arrow = session.make_arrow(length, true)
		_arrow.set_meta("way", way)
		_arrow.rotation.y = 0.0 if across else PI * 0.5
		_arrow.position = old.position
		_arrow.scale = old.scale
		old.queue_free()
	_arrow.position = Vector3(_center.x, _center.y + _thickness() + 0.01, _center.z)
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.06
	_arrow.scale = _arrow.scale.lerp(Vector3(pulse, 1.0, pulse), 1.0 - exp(-10.0 * delta))


func _thickness() -> float:
	return _volume / (_size.x * _size.y)


func _shape() -> void:
	_box.size = Vector3(_size.x, _thickness(), _size.y)
	_dough.position.y = _center.y + _thickness() * 0.5
	var streaks := _dough.get_node_or_null("Streaks") as Node3D  # Butter folded in (DoughFoldAction): stretched with the sheet.
	if streaks != null:
		var base: Vector2 = streaks.get_meta("size")
		streaks.scale = Vector3(_size.x / base.x, 1.0, _size.y / base.y)
		streaks.position.y = _thickness() * 0.5


# A dashed square on the counter: how big to roll it.
func _outline() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 1.0, 1.0, 0.75)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var goal := _goal()
	for side in 4:
		var span := goal.x if side < 2 else goal.y
		var dashes := maxi(roundi(span / goal.x * 6.0), 3) if side >= 2 else 6
		var dash := span / dashes * 0.6
		for i in dashes:
			var along := -span * 0.5 + (i + 0.5) * span / dashes
			var piece := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(dash, 0.002, 0.005)
			mesh.material = material
			piece.mesh = mesh
			match side:
				0: piece.position = Vector3(along, 0.001, -goal.y * 0.5)
				1: piece.position = Vector3(along, 0.001, goal.y * 0.5)
				2: piece.position = Vector3(-goal.x * 0.5, 0.001, along)
				3: piece.position = Vector3(goal.x * 0.5, 0.001, along)
			if side >= 2:
				piece.rotation.y = PI * 0.5
			piece.position += _center
			session.add_child(piece)
			_dashes.append(piece)
