# TopAction: put a topping on each cookie (the session's context "cookies",
# from CutAction): an acorn on top of each. Press over a cookie to set one
# down; it scores how near the middle it lands. Done when every cookie has
# one. A press off the cookies just drops it on the tray.
class_name TopAction
extends CookAction

@export var nut_radius := 0.013
@export var nut_color := Color(0.62, 0.4, 0.2)
@export var cap_color := Color(0.4, 0.27, 0.15)
@export var perfect_offset := 0.006
@export var worst_offset := 0.035

var _cookies: Array = []
var _topped := {}                          # Cookie -> its acorn.
var _scores: Array[float] = []
var _hand: Node3D                          # The acorn waiting to go on, under the cursor.


func _begin() -> void:
	_cookies = session.context.get("cookies", [])
	_hand = _make_acorn()


func end() -> void:
	_hand.queue_free()


func cursor_height() -> float:
	return _cookie_top()


func update(delta: float, input: CookInput) -> void:
	var spot := Vector3(input.cursor.x, _cookie_top(), input.cursor.z)
	_hand.position = _hand.position.lerp(spot + Vector3(0.0, 0.06, 0.0), 1.0 - exp(-20.0 * delta))
	session.set_status("Acorns: %d of %d" % [_topped.size(), _cookies.size()])
	if input.just_pressed:
		_drop(spot)
	if _topped.size() >= _cookies.size():
		finish(average(_scores))


func _drop(spot: Vector3) -> void:
	var cookie := _cookie_at(spot)
	if cookie == null:
		session.pop_text("On a cookie!", spot, -1)
		return
	if _topped.has(cookie):
		session.pop_text("That one has one", spot, 0)
		return
	var acorn := _make_acorn()
	acorn.position = _hand.position
	acorn.reparent(cookie)  # It bakes (and gets served) with its cookie.
	var offset := Vector2(spot.x - cookie.position.x, spot.z - cookie.position.z)
	var rest := Vector3(offset.x, (cookie.mesh as CylinderMesh).height * 0.5 + nut_radius, offset.y)
	var tween := acorn.create_tween()
	tween.tween_property(acorn, "position", rest, 0.12).set_ease(Tween.EASE_IN)
	_topped[cookie] = acorn
	var score := 1.0 - clampf((offset.length() - perfect_offset) / (worst_offset - perfect_offset), 0.0, 1.0)
	_scores.append(score)
	session.play_sound("tick", spot, -4.0, 1.4)
	session.pop_text("Right in the middle!" if score >= 0.9 else ("Nice" if score >= 0.6 else "Off to the side"), spot, CookSession.mood_of(score))


func _cookie_at(spot: Vector3) -> MeshInstance3D:
	for cookie: MeshInstance3D in _cookies:
		var radius := (cookie.mesh as CylinderMesh).top_radius
		if Vector2(cookie.position.x - spot.x, cookie.position.z - spot.z).length() <= radius:
			return cookie
	return null


func _cookie_top() -> float:
	if _cookies.is_empty():
		return session.work_height
	var cookie: MeshInstance3D = _cookies[0]
	return cookie.position.y + (cookie.mesh as CylinderMesh).height * 0.5


# A little acorn: a nut with a darker cap and a stalk, lying on its side.
func _make_acorn() -> Node3D:
	var acorn := Node3D.new()
	var nut := MeshInstance3D.new()
	var nut_mesh := SphereMesh.new()
	nut_mesh.radius = nut_radius
	nut_mesh.height = nut_radius * 2.4
	var nut_material := StandardMaterial3D.new()
	nut_material.albedo_color = nut_color
	nut_material.roughness = 0.4
	nut_mesh.material = nut_material
	nut.mesh = nut_mesh
	acorn.add_child(nut)
	var cap_material := StandardMaterial3D.new()
	cap_material.albedo_color = cap_color
	cap_material.roughness = 0.95
	var cap := MeshInstance3D.new()
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = nut_radius * 1.15
	cap_mesh.height = nut_radius * 1.3
	cap_mesh.is_hemisphere = true
	cap_mesh.material = cap_material
	cap.mesh = cap_mesh
	cap.position.y = nut_radius * 0.9
	acorn.add_child(cap)
	var stalk := MeshInstance3D.new()
	var stalk_mesh := CylinderMesh.new()
	stalk_mesh.top_radius = nut_radius * 0.15
	stalk_mesh.bottom_radius = nut_radius * 0.2
	stalk_mesh.height = nut_radius * 0.8
	stalk_mesh.material = cap_material
	stalk.mesh = stalk_mesh
	stalk.position.y = nut_radius * 1.9
	acorn.add_child(stalk)
	acorn.rotation.z = PI * 0.5  # On its side (its middle at its origin), so it sits on the cookie.
	session.add_child(acorn)
	return acorn
