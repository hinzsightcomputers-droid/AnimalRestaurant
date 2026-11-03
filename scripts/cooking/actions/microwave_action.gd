# MicrowaveAction: one run of the microwave beside the close-up (its station's
# MicrowaveModel). Press the button to put the mixing bowl in: the door opens,
# it comes round to the front and goes straight in, and the door shuts; it
# it hums and turns for run_seconds (longer on Easy), then dings. Press again
# to take it out: out within prompt_seconds of the ding is full marks, and it
# loses a little for every second it's left after that. The bowl's contents
# come out cooked: turned cooked_color, and with glossy, shiny and a little
# see-through. An arrow shows where the bowl goes next.
class_name MicrowaveAction
extends CookAction

@export var bowl := "Bowl"
@export var run_seconds := 3.0
@export var prompt_seconds := 1.5
@export var cooked_color := Color(0, 0, 0, 0)  # What the bowl's contents turn (none: stay as they are).
@export var glossy := false

var _model: MicrowaveModel
var _phase := 0                            # 0 waiting to go in, 1 going in, 2 running, 3 dinged, 4 coming out.
var _left := 0.0
var _since_ding := 0.0
var _home := Vector3.ZERO
var _hum: AudioStreamPlayer3D
var _arrow: Node3D                         # From the bowl to the door, or back.


func _init() -> void:
	view_distance = 1.1  # Back far enough to see the bowl's spot and the microwave.
	view_pitch = 26.0
	view_seconds = 0.6


func view_point() -> Vector3:
	var front := _front()
	var pot := session.surface(bowl).position if session.surface(bowl) != null else front
	return (front + pot) * 0.5


func uses_cursor() -> bool:
	return false


func _begin() -> void:
	_model = session.get_parent().find_child("MicrowaveModel", true, false) as MicrowaveModel if session.get_parent() != null else null
	_home = session.surface(bowl).position
	_hum = session.loop_sound("sizzle", -30.0)
	_hum.position = _front()
	var way := _front() + _out() * 0.12 - _home
	_arrow = session.make_arrow(Vector2(way.x, way.z).length() * 0.6)
	_arrow.rotation = Vector3(deg_to_rad(72.0), atan2(-way.z, way.x), 0.0)  # Tipped to face the camera.
	_arrow.scale = Vector3(1.0, 1.0, 2.5)  # Chunky: it's seen from further off.


func end() -> void:
	_hum.queue_free()
	_arrow.queue_free()
	if _model != null:
		_model.set_running(false)


func update(delta: float, input: CookInput) -> void:
	var pot := session.surface(bowl)
	_point_arrow()
	match _phase:
		0:
			session.set_status("Press to put the bowl in")
			if input.just_pressed:
				_put_in(pot)
		2:
			_left -= delta * GameState.difficulty_value("closeup_pace")
			pot.rotate_y(delta * 1.6)  # Round on the turntable.
			session.set_status("Heating... %ds" % ceili(maxf(_left, 0.0)))
			if input.just_pressed:
				session.pop_text("Not yet!", _front(), 0)
			if _left <= 0.0:
				_ding()
		3:
			_since_ding += delta
			session.set_status("Ding! Take it out")
			if input.just_pressed:
				_take_out(pot)


func _put_in(pot: CookSurface) -> void:
	_phase = 1
	await _door(true)
	var inside := _inside()
	var door := inside + (_front() - inside) * Vector3(1.0, 0.0, 1.0) + _out() * 0.1  # Just out in front of the door, as high as the turntable.
	var go := pot.create_tween()
	go.tween_property(pot, "position", (_home + door) * 0.5 + Vector3(0.0, 0.08, 0.0), 0.25).set_ease(Tween.EASE_OUT)
	go.tween_property(pot, "position", door, 0.25).set_ease(Tween.EASE_IN_OUT)
	go.tween_property(pot, "position", inside, 0.3).set_trans(Tween.TRANS_SINE)
	await go.finished
	await _door(false)
	if _model != null:
		_model.set_running(true)
	session.play_sound("clack", inside, -4.0, 1.3)
	_hum.play()
	_left = run_seconds
	_phase = 2


func _ding() -> void:
	_phase = 3
	_since_ding = 0.0
	_hum.stop()
	if _model != null:
		_model.set_running(false)
	session.play_sound("ding", _front(), 0.0, 1.4)
	session.pop_text("Ding!", _front() + Vector3(0.0, 0.1, 0.0), 1)
	var pot := session.surface(bowl)
	if cooked_color.a > 0.0:
		pot.set_liquid_color(cooked_color)
	if glossy and pot.liquid != null:
		var material := pot.liquid.mesh.surface_get_material(0) as StandardMaterial3D
		material.roughness = 0.05
		material.metallic_specular = 1.0
		material.albedo_color.a = 0.82
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func _take_out(pot: CookSurface) -> void:
	_phase = 4
	var score := 1.0 if _since_ding <= prompt_seconds else clampf(1.0 - (_since_ding - prompt_seconds) * 0.1, 0.6, 1.0)
	await _door(true)
	var inside := _inside()
	var door := inside + (_front() - inside) * Vector3(1.0, 0.0, 1.0) + _out() * 0.1
	var back := pot.create_tween()
	back.tween_property(pot, "position", door, 0.3).set_trans(Tween.TRANS_SINE)
	back.parallel().tween_property(pot, "rotation:y", 0.0, 0.3)
	back.tween_property(pot, "position", (_home + door) * 0.5 + Vector3(0.0, 0.08, 0.0), 0.25).set_ease(Tween.EASE_OUT)
	back.tween_property(pot, "position", _home, 0.25).set_ease(Tween.EASE_IN)
	await back.finished
	await _door(false)
	session.play_sound("plop", _home, -6.0)
	session.pop_text("Just in time!" if score >= 0.95 else "Bit long", _home, CookSession.mood_of(score))
	finish(score)


# Opens (or shuts) the door, and waits till it has.
func _door(open: bool) -> void:
	if _model == null:
		return
	_model.set_open(open)
	session.play_sound("tick", _front(), -8.0, 0.8 if open else 1.1)
	await session.get_tree().create_timer(0.28).timeout


# Waiting to go in: from the bowl to the door. Dinged: back from the door to
# the bowl's spot. Otherwise hidden. It bobs the way to go.
func _point_arrow() -> void:
	_arrow.visible = _phase == 0 or _phase == 3
	if not _arrow.visible:
		return
	var door := _front() + _out() * 0.12
	var from := _home if _phase == 0 else door
	var to := door if _phase == 0 else _home
	var way := to - from
	_arrow.rotation.y = atan2(-way.z, way.x)
	var bob := (1.0 + sin(Time.get_ticks_msec() * 0.008)) * 0.01
	_arrow.position = (from + to) * 0.5 + Vector3(0.0, 0.12, 0.0) + Vector3(way.x, 0.0, way.z).normalized() * bob


# Straight out of the door (flat, in the session).
func _out() -> Vector3:
	if _model == null:
		return Vector3(0.0, 0.0, 1.0)
	var out := session.global_transform.basis.inverse() * _model.global_transform.basis.z
	return Vector3(out.x, 0.0, out.z).normalized()


# The turntable's middle, in the session (or a spot to the right without a microwave).
func _inside() -> Vector3:
	if _model == null:
		return _home + Vector3(0.5, 0.0, 0.0)
	return session.to_local(_model.inside_point())


func _front() -> Vector3:
	if _model == null:
		return _home + Vector3(0.5, 0.1, 0.15)
	return session.to_local(_model.front_point())
