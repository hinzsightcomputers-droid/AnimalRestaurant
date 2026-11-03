# PleatAction: fold each filled wrapper (the context's "cookies") shut, with
# the controls of folding an omelette: press the button on one to take hold of
# its near edge, then flick up to fold it over the filling into a pleated
# half-moon (press again to let go); an arrow over the one held shows the
# flick. A fold scores how cleanly it was flicked
# (straight up is best; any flick up still folds it).
class_name PleatAction
extends CookAction

@export var fold_seconds := 0.35
@export var pleats := 5                    # Little pinches along the curved edge.
@export_range(0.0, 1.0) var up_needed := 0.6
@export var grab_margin := 0.02

var _cookies: Array = []
var _folded := {}                          # Cookie -> true once it's shut.
var _held: MeshInstance3D = null
var _scores: Array[float] = []
var _ring: MeshInstance3D                  # Round the one held.
var _arrow: Node3D                         # Over the one held: flick up.


func _init() -> void:
	view_distance = 0.45
	view_pitch = 66.0


func view_point() -> Vector3:
	var middle := Vector3.ZERO
	for cookie: Node3D in _cookies:
		middle += cookie.position
	return middle / maxf(_cookies.size(), 1) if not _cookies.is_empty() else super.view_point()


func cursor_area() -> Rect2:
	if _cookies.is_empty():
		return Rect2()
	var area := Rect2(_cookies[0].position.x, _cookies[0].position.z, 0.0, 0.0)
	for cookie: Node3D in _cookies:
		area = area.expand(Vector2(cookie.position.x, cookie.position.z))
	return area.grow(CookSession.half_of(_cookies[0]).x + 0.04)


func cursor_height() -> float:
	if _cookies.is_empty():
		return session.work_height
	return _cookies[0].position.y + CookSession.top_of(_cookies[0])


func _begin() -> void:
	_cookies = session.context.get("cookies", [])
	if _cookies.is_empty():
		finish(1.0)
		return
	_ring = session.make_ring(CookSession.half_of(_cookies[0]).x + 0.006, Color(1.0, 0.92, 0.35, 0.95))
	_ring.visible = false
	_arrow = session.make_flick_arrow()


func end() -> void:
	if _ring != null:
		_ring.queue_free()
		_arrow.queue_free()


func update(_delta: float, input: CookInput) -> void:
	session.set_status("Pleated: %d of %d" % [_folded.size(), _cookies.size()])
	if _held != null:
		session.show_flick(_arrow, _held.position + Vector3(0.0, CookSession.top_of(_held), 0.0))
	else:
		_arrow.visible = false
	if _held == null:
		if input.just_pressed:
			var cookie := _cookie_at(Vector2(input.cursor.x, input.cursor.z))
			if cookie != null:
				_held = cookie
				_ring.visible = true
				_ring.position = cookie.position + Vector3(0.0, CookSession.top_of(cookie) + 0.004, 0.0)
				session.wobble(cookie, 0.08)
				session.play_sound("tick", cookie.position, -8.0, 1.2)
	elif input.flick.y <= -up_needed:  # Away from the camera: up the screen.
		var straight := clampf(-input.flick.normalized().y, 0.0, 1.0)
		var score := lerpf(0.7, 1.0, clampf((straight - up_needed) / (0.97 - up_needed), 0.0, 1.0))
		var cookie := _held
		_held = null
		_ring.visible = false
		_pleat(cookie, score)
	elif input.just_pressed:  # Let go.
		_held = null
		_ring.visible = false
		session.pop_text("Flick up to fold!", input.cursor, 0)


func ready_word(_piece: CookPiece) -> String:
	return ""


func _pleat(cookie: MeshInstance3D, score: float) -> void:
	_folded[cookie] = true
	_scores.append(score)
	var radius := CookSession.half_of(cookie).x
	var height := (cookie.mesh as CylinderMesh).height
	# The near half comes up and over (the wrapper squashing toward the back)...
	var look := _half_moon(radius, height * 1.8)
	look.position.y = -height * 0.5
	look.scale = Vector3(1.0, 0.2, 1.6)
	for child in cookie.get_children():
		if not child.has_meta("look"):  # The filling, now inside.
			child.visible = false
	session.dress(cookie, look, Vector2(radius, radius * 0.5), height * 1.8 - height * 0.5)
	var tween := look.create_tween()
	tween.tween_property(look, "scale", Vector3.ONE, fold_seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	session.play_sound("whoosh", cookie.position, -10.0, 1.4)
	session.pop_text("Pleat!" if score >= 0.85 else "Folded", cookie.position, CookSession.mood_of(score))
	if _folded.size() >= _cookies.size():
		await session.get_tree().create_timer(fold_seconds).timeout
		finish(average(_scores))


# A half-moon dumpling: the far half of the circle, puffed up, with pinched
# pleats along its curved edge.
func _half_moon(radius: float, height: float) -> Node3D:
	var shape := Node3D.new()
	var outline := PackedVector2Array()
	for i in 13:
		var angle := PI + PI * i / 12.0  # Round the far side (-z).
		outline.append(Vector2(cos(angle), sin(angle)) * radius)
	var body := MeshInstance3D.new()
	body.mesh = CookSession.prism(outline, height)
	body.position.z = radius * 0.4  # Its straight edge toward you, its middle on the piece's.
	shape.add_child(body)
	for i in pleats:
		var angle := PI + PI * (i + 1) / (pleats + 1)
		var pinch := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = radius * 0.16
		mesh.height = radius * 0.22
		pinch.mesh = mesh
		pinch.position = Vector3(cos(angle) * radius * 0.92, height, sin(angle) * radius * 0.92 + radius * 0.4)
		shape.add_child(pinch)
	return shape


func _cookie_at(point: Vector2) -> MeshInstance3D:
	for cookie: MeshInstance3D in _cookies:
		if _folded.has(cookie):
			continue
		if Vector2(cookie.position.x, cookie.position.z).distance_to(point) <= CookSession.half_of(cookie).x + grab_margin:
			return cookie
	return null
