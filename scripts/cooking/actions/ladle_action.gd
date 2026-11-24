# LadleAction: serve a soup. A ladle follows the cursor: press over the pot to
# scoop it full, then press over the bowl to pour it in, a few times over. Each
# ladleful scores how near the bowl's middle it was poured (the ring shows
# where's perfect); over the rim some of it spills.
class_name LadleAction
extends CookAction

@export var from_surface := "Pot"
@export var target := "Bowl"
@export var ladles := 3
@export var perfect_offset := 0.045        # Pouring this near the bowl's middle gets full marks.
@export_range(0.0, 1.0) var least_score := 0.5  # What one half over the rim scores.
@export var full_level := 0.8              # How full the bowl ends up (of its depth).

var _ladle: Node3D
var _soup: MeshInstance3D                  # In the ladle.
var _full := false
var _busy := false
var _poured := 0
var _scores: Array[float] = []
var _ring: MeshInstance3D


# Between the pot and the bowl.
func view_point() -> Vector3:
	return (session.surface(from_surface).position + session.surface(target).position) * 0.5


func uses_cursor() -> bool:
	return false  # The ladle shows the spot.


func cursor_height() -> float:
	return session.surface(from_surface).position.y


func _begin() -> void:
	var pot := session.surface(from_surface)
	var bowl := session.surface(target)
	_ladle = _make_ladle(pot.color)
	_ladle.position = pot.position + Vector3(0.0, 0.12, 0.0)
	_ring = session.make_ring(perfect_offset, Color(1.0, 1.0, 1.0, 0.9))
	_ring.position = bowl.position + Vector3(0.0, bowl.depth, 0.0)


func end() -> void:
	_ladle.queue_free()
	_ring.queue_free()


func update(delta: float, input: CookInput) -> void:
	var pot := session.surface(from_surface)
	var bowl := session.surface(target)
	_ring.visible = _full
	if not _busy:
		var goal := Vector3(input.cursor.x, pot.position.y + 0.11, input.cursor.z)
		_ladle.position = _ladle.position.lerp(goal, 1.0 - exp(-18.0 * delta))
		if input.just_pressed:
			var at := Vector3(_ladle.position.x, 0.0, _ladle.position.z)
			if not _full:
				if pot.contains(at, 0.02):
					_scoop(pot)
				else:
					session.pop_text("Scoop from the pot", pot.position, 0)
			elif bowl.contains(at, 0.05):
				_pour(bowl, at)
			else:
				session.pop_text("Over the bowl!", bowl.position, 0)
	session.set_status("Ladle %d of %d: %s" % [mini(_poured + 1, ladles), ladles, "over the bowl" if _full else "scoop from the pot"])


# For a reel: scoop and pour till it's full.
func scripted_hold(delta: float, input: CookInput) -> bool:
	if _busy:
		return false
	var goal := session.surface(target if _full else from_surface).position
	var there := input.move_to(goal, delta)
	return there and Vector2(_ladle.position.x - goal.x, _ladle.position.z - goal.z).length() < 0.02 and not input.held


func _scoop(pot: CookSurface) -> void:
	_busy = true
	var tween := _ladle.create_tween()
	tween.tween_property(_ladle, "position:y", pot.position.y - 0.005, 0.14).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func():
		_soup.visible = true
		session.play_sound("plop", pot.position, -6.0, 0.9)
		session.burst(pot.position, pot.color, 4, 0.15))
	tween.tween_property(_ladle, "position:y", pot.position.y + 0.11, 0.16).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func():
		_full = true
		_busy = false)


func _pour(bowl: CookSurface, at: Vector3) -> void:
	_busy = true
	var off := Vector2(at.x - bowl.position.x, at.z - bowl.position.z).length()
	var result := 1.0 if off <= perfect_offset else lerpf(1.0, least_score, clampf((off - perfect_offset) / maxf(bowl.radius() + 0.05 - perfect_offset, 0.01), 0.0, 1.0))
	var pot := session.surface(from_surface)
	var tween := _ladle.create_tween()
	tween.tween_property(_ladle, "position", Vector3(at.x, bowl.position.y + bowl.depth + 0.07, at.z), 0.12)
	tween.tween_property(_ladle, "rotation:z", deg_to_rad(70.0), 0.18)
	tween.tween_callback(func():
		_soup.visible = false
		_poured += 1
		_scores.append(result)
		bowl.fill_to(full_level * _poured / ladles, pot.color)
		session.play_sound("plop", at, -4.0, 1.1)
		session.burst(bowl.position + Vector3(0.0, bowl.depth, 0.0), pot.color, 14 if result < 0.8 else 4, 0.4 if result < 0.8 else 0.15)
		session.pop_text("Lovely!" if result >= 1.0 else ("Nice" if result >= 0.8 else "Spilled a bit: pour in the middle"), bowl.position, CookSession.mood_of(result)))
	tween.tween_interval(0.1)
	tween.tween_property(_ladle, "rotation:z", 0.0, 0.15)
	tween.tween_callback(func():
		_full = false
		_busy = false
		if _poured >= ladles:
			finish(average(_scores)))


# A steel ladle, its origin at the cup, the handle up and back.
func _make_ladle(soup_color: Color) -> Node3D:
	var ladle := Node3D.new()
	var cup := MeshInstance3D.new()
	var cup_mesh := CylinderMesh.new()
	cup_mesh.top_radius = 0.034
	cup_mesh.bottom_radius = 0.02
	cup_mesh.height = 0.03
	cup_mesh.material = KitchenProps.steel(KitchenProps.SAGE_STEEL)
	cup.mesh = cup_mesh
	ladle.add_child(cup)
	_soup = MeshInstance3D.new()
	var soup_mesh := CylinderMesh.new()
	soup_mesh.top_radius = 0.031
	soup_mesh.bottom_radius = 0.031
	soup_mesh.height = 0.004
	var soup := StandardMaterial3D.new()
	soup.albedo_color = soup_color
	soup.roughness = 0.25
	soup_mesh.material = soup
	_soup.mesh = soup_mesh
	_soup.position.y = 0.0155
	_soup.visible = false
	ladle.add_child(_soup)
	var handle := MeshInstance3D.new()
	var handle_mesh := CapsuleMesh.new()
	handle_mesh.radius = 0.008
	handle_mesh.height = 0.2
	handle_mesh.material = KitchenProps.handle_wood()
	handle.mesh = handle_mesh
	handle.rotation.x = deg_to_rad(40.0)
	handle.position = Vector3(0.0, 0.085, 0.085)
	ladle.add_child(handle)
	session.add_child(ladle)
	return ladle
