# ServeAction: tongs follow the cursor; press on each cut piece (the
# context's "cookies") and the tongs pick it up and carry it to the plate,
# where it lands in its place round the middle by itself (no aiming, like the
# spatula plating griddle pieces: give the step weight 0).
class_name ServeAction
extends CookAction

@export var target := "Plate"
@export var ring := 0.055                  # How far from the plate's middle they sit.
@export var carry_seconds := 0.5
@export var grab_margin := 0.02

var _cookies: Array = []
var _served := {}
var _tongs: Node3D
var _carrying: Node3D = null


func _init() -> void:
	weight = 0.0
	view_distance = 0.75
	view_pitch = 58.0


# Between the pieces and the plate.
func view_point() -> Vector3:
	var middle := Vector3.ZERO
	for cookie: Node3D in _cookies:
		middle += cookie.position
	middle = middle / maxf(_cookies.size(), 1) if not _cookies.is_empty() else super.view_point()
	return (middle + session.surface(target).position) * 0.5


func cursor_dot() -> bool:
	return true


func _begin() -> void:
	_cookies = session.context.get("cookies", [])
	if _cookies.is_empty():
		finish(1.0)
		return
	_tongs = session.make_tongs()
	_tongs.position = _cookies[0].position + Vector3(0.0, 0.08, 0.0)


func end() -> void:
	_tongs.queue_free()


func update(delta: float, input: CookInput) -> void:
	session.set_status("On the plate: %d of %d" % [_served.size(), _cookies.size()])
	if _carrying != null:
		_tongs.position = _carrying.position + Vector3(0.0, 0.01, 0.0)
		return
	_tongs.position = _tongs.position.lerp(input.cursor + Vector3(0.0, 0.06, 0.0), 1.0 - exp(-20.0 * delta))
	if input.just_pressed:
		var cookie := _cookie_at(Vector2(input.cursor.x, input.cursor.z))
		if cookie != null:
			_carry(cookie)


func ready_word(_piece: CookPiece) -> String:
	return ""


func _carry(cookie: MeshInstance3D) -> void:
	_carrying = cookie
	var index := _served.size()
	_served[cookie] = true
	var plate := session.surface(target)
	var angle := TAU * index / _cookies.size() - PI * 0.5
	var spot := plate.position + Vector3(cos(angle) * ring, (cookie.mesh as CylinderMesh).height * 0.5, sin(angle) * ring)
	session.play_sound("tick", cookie.position, -6.0, 1.5)
	var from := cookie.position
	var tween := cookie.create_tween()
	tween.tween_method(func(t: float):
		cookie.position = from.lerp(spot, t) + Vector3(0.0, sin(t * PI) * 0.1, 0.0), 0.0, 1.0, carry_seconds).set_trans(Tween.TRANS_SINE)
	await tween.finished
	session.play_sound("plop", spot, -6.0, 1.3)
	session.wobble(cookie, 0.15)
	session.stack_push(target, cookie, spot - Vector3(0.0, (cookie.mesh as CylinderMesh).height * 0.5, 0.0), (cookie.mesh as CylinderMesh).height)
	_carrying = null
	if _served.size() >= _cookies.size():
		finish(1.0)


func _cookie_at(point: Vector2) -> MeshInstance3D:
	for cookie: MeshInstance3D in _cookies:
		if _served.has(cookie):
			continue
		if Vector2(cookie.position.x, cookie.position.z).distance_to(point) <= CookSession.half_of(cookie).x + grab_margin:
			return cookie
	return null
