# CoverAction: lay one cut piece over another (the context's "cookies": the
# second goes on the first, e.g. the top of a strudel over its filling). It
# lifts off the tray into your hand; move it over and press to lay it down. It
# scores how well it lines up, from perfect_offset off (full marks) to
# worst_offset off (none).
class_name CoverAction
extends CookAction

@export var perfect_offset := 0.006
@export var worst_offset := 0.05
@export var lift := 0.06

var _bottom: MeshInstance3D
var _top: MeshInstance3D
var _laying := false


func _init() -> void:
	view_distance = 0.5
	view_pitch = 64.0


func view_point() -> Vector3:
	return _bottom.position if _bottom != null else super.view_point()


func cursor_area() -> Rect2:
	if _bottom == null:
		return Rect2()
	var half := CookSession.half_of(_bottom)
	return Rect2(_bottom.position.x - half.x, _bottom.position.z - half.y, half.x * 2.0, half.y * 2.0).grow(0.05)


func cursor_height() -> float:
	return _covered_height()


func cursor_dot() -> bool:
	return true


func _begin() -> void:
	var cookies: Array = session.context.get("cookies", [])
	if cookies.size() < 2:
		finish(1.0)
		return
	_bottom = cookies[0]
	_top = cookies[1]
	session.play_sound("tick", _top.position, -8.0)


func update(delta: float, input: CookInput) -> void:
	if _laying:
		return
	var goal := Vector3(input.cursor.x, _covered_height() + lift, input.cursor.z)
	_top.position = _top.position.lerp(goal, 1.0 - exp(-16.0 * delta))
	session.set_status("Line it up with the bottom")
	if input.just_pressed:
		_lay(Vector2(input.cursor.x, input.cursor.z))


func _lay(spot: Vector2) -> void:
	_laying = true
	var off := spot.distance_to(Vector2(_bottom.position.x, _bottom.position.z))
	var score := 1.0 - clampf((off - perfect_offset) / (worst_offset - perfect_offset), 0.0, 1.0)
	var rest := Vector3(spot.x, _covered_height() + (_top.mesh as CylinderMesh).height * 0.5, spot.y)
	var drop := _top.create_tween()
	drop.tween_property(_top, "position", rest, 0.15).set_ease(Tween.EASE_IN)
	await drop.finished
	session.wobble(_top, 0.12)
	session.play_sound("plop", rest, -4.0, 1.1)
	session.pop_text("Lined up!" if score >= 0.9 else ("Nice" if score >= 0.6 else "Crooked!"), rest, CookSession.mood_of(score))
	finish(score)


# The top of the bottom piece and what's on it (the filling).
func _covered_height() -> float:
	return _bottom.position.y + CookSession.top_of(_bottom) + 0.01
