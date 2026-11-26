# RiceInAction: a cup of raw rice follows the cursor; press over the pot to
# tip it in, and it settles on the bottom (CookRiceAction.setup_rice) for the
# water to go in after. A press off the pot just says where it goes. Not
# scored (weight 0): it's the start of cooking the rice.
class_name RiceInAction
extends CookAction

@export var into := "RicePot"
@export var grains := 260

var _cup: Node3D
var _tipped := false


func _init() -> void:
	weight = 0.0
	view_distance = 0.5
	view_pitch = 60.0


func view_point() -> Vector3:
	return session.surface(into).position


func uses_cursor() -> bool:
	return false


func marks_spot() -> bool:
	return true


func cursor_height() -> float:
	return session.surface(into).position.y


func _begin() -> void:
	_cup = Node3D.new()
	var body := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.032
	mesh.bottom_radius = 0.026
	mesh.height = 0.05
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.78, 0.8, 0.83)
	steel.metallic = 0.6
	steel.roughness = 0.35
	mesh.material = steel
	body.mesh = mesh
	_cup.add_child(body)
	var heap := MeshInstance3D.new()  # The rice in it.
	var top := CylinderMesh.new()
	top.top_radius = 0.029
	top.bottom_radius = 0.029
	top.height = 0.003
	var rice := StandardMaterial3D.new()
	rice.albedo_color = CookRiceAction.RICE
	top.material = rice
	heap.mesh = top
	heap.position.y = 0.02
	_cup.add_child(heap)
	session.add_child(_cup)


func end() -> void:
	if _cup != null:
		_cup.queue_free()


func update(delta: float, input: CookInput) -> void:
	if _tipped:
		return
	var pot := session.surface(into)
	var spot := Vector3(input.cursor.x, pot.position.y, input.cursor.z)
	_cup.position = _cup.position.lerp(spot + Vector3(0.0, 0.12, 0.0), 1.0 - exp(-18.0 * delta))
	session.set_status("Rice: tip it into the pot")
	if not input.just_pressed:
		return
	if Vector2(spot.x - pot.position.x, spot.z - pot.position.z).length() > pot.radius():
		session.pop_text("In the pot!", spot, -1)
		return
	_tipped = true
	var tween := _cup.create_tween()
	tween.tween_property(_cup, "position", pot.position + Vector3(pot.radius() * 0.4, 0.12, 0.0), 0.1)
	tween.tween_property(_cup, "rotation:z", deg_to_rad(120.0), 0.25).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func():
		var rice := CookRiceAction.setup_rice(session, pot, grains)
		rice.scale = Vector3(1.0, 0.01, 1.0)
		rice.create_tween().tween_property(rice, "scale", Vector3.ONE, 0.35).set_ease(Tween.EASE_OUT)
		session.play_sound("pour", pot.position, -10.0, 1.6)
		session.burst(pot.position + Vector3(0.0, 0.05, 0.0), CookRiceAction.RICE, 10, 0.2))
	tween.tween_interval(0.45)
	tween.tween_callback(func(): finish(1.0))


# For a reel: over the pot, then tip.
func scripted_hold(delta: float, input: CookInput) -> bool:
	return input.move_to(session.surface(into).position, delta, 1.0) and not input.held
