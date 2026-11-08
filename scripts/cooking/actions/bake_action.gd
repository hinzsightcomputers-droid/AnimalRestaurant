# BakeAction: bake the tray in the oven. The camera comes down to look straight
# in through the oven door as the tray slides in; the oven glows, the cookies
# brown through the window, and a meter under it fills: pale, then golden (the
# marked band), then burnt. Press the button to take the tray out: it comes out
# of the door and up onto the top of the oven, the camera rising with it to
# look down on how they came out. Leave them too long and they come out burnt
# on their own.
# With leave_in, once the tray's in it carries on baking while the next steps
# go (a dip made while the pretzels bake), and a TakeOutAction later brings
# the camera back to take it out. Meanwhile it only bakes up to ready_seconds
# short of golden, and it's brought on to there when the TakeOutAction comes,
# so however long the dip took it's golden a moment after you're back.
class_name BakeAction
extends CookAction

@export var tray := "Tray"
@export var oven_front := Vector3(0.45, -0.45, 0.42)  # The oven door's middle, from the session.
@export var bake_seconds := 6.0            # From raw to burnt.
@export var band := Vector2(0.55, 0.75)    # Golden.
@export var golden := Color(0.86, 0.6, 0.3)
@export var burnt := Color(0.25, 0.15, 0.1)
@export var meter_length := 0.36
@export var inside := Vector3(0.0, -0.08, -0.1)  # Where the tray bakes, from the door's middle: just behind the glass, so it shows.
@export var meter_offset := Vector3(0.0, -0.33, 0.03)  # Where the meter stands, from the oven door's middle (under the window).
@export var out_view := Vector2(0.62, 58.0)  # Camera distance and pitch on the tray once it's out, on top of the oven.
@export var leave_in := false              # Keeps baking alongside the next steps, until a TakeOutAction.
@export var ready_seconds := 2.0           # leave_in: how long short of golden it is when you're back.

var claimed := false                       # leave_in: a TakeOutAction is here for it.

var _done := 0.0
var _phase := 0                            # 0 sliding in, 1 baking, 2 coming out.
var _tray: CookSurface
var _home := Vector3.ZERO
var _raw := {}                             # Cookie material -> its raw color.
var _glow := OmniLight3D.new()
var _meter := Node3D.new()
var _fill: MeshInstance3D
var _hum: AudioStreamPlayer3D
var _burning := false  # Past golden: the cook looks up, startled, once.


func _init() -> void:
	view_distance = 0.95  # Straight on at the oven door.
	view_pitch = 6.0
	view_seconds = 0.8


func view_point() -> Vector3:
	return oven_front


func _begin() -> void:
	_tray = session.surface(tray)
	_home = _tray.position
	for cookie: MeshInstance3D in session.context.get("cookies", []):
		cookie.reparent(_tray)  # They go in with it.
		var material := (cookie.mesh as CylinderMesh).material as StandardMaterial3D
		_raw[material] = material.albedo_color
	_build_meter()
	_glow.light_color = Color(1.0, 0.55, 0.2)
	_glow.light_energy = 0.0
	_glow.omni_range = 0.6
	_glow.position = oven_front + Vector3(0.0, 0.0, 0.15)
	session.add_child(_glow)
	_hum = session.loop_sound("sizzle", -40.0)
	_hum.position = oven_front
	_hum.play()
	var slide := _tray.create_tween()
	slide.tween_property(_tray, "position", oven_front + Vector3(0.0, 0.05, 0.25), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	slide.tween_property(_tray, "position", oven_front + inside, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	slide.tween_callback(func():
		session.play_sound("clack", oven_front, -2.0, 0.7)
		_phase = 1
		if leave_in:
			to_background = true)


func end() -> void:
	_glow.queue_free()
	_meter.queue_free()
	_hum.queue_free()


func uses_cursor() -> bool:
	return false


func update(delta: float, input: CookInput) -> void:
	if _phase != 1:
		return
	var waiting := leave_in and not claimed  # Something else is being made meanwhile.
	var rate := GameState.difficulty_value("closeup_pace") / bake_seconds  # Slower on Easy.
	var ready := band.x - ready_seconds * rate
	if waiting:
		_done = minf(_done + delta * rate, ready)
	else:
		if leave_in:
			_done = maxf(_done, ready)
		_done = minf(_done + delta * rate, 1.0)
	_glow.light_energy = lerpf(_glow.light_energy, 1.6, 1.0 - exp(-3.0 * delta))
	_hum.volume_db = lerpf(_hum.volume_db, -22.0, 1.0 - exp(-2.0 * delta))
	_fill.scale.x = maxf(_done, 0.001)
	_fill.position.x = (_done - 1.0) * meter_length * 0.5
	for material: StandardMaterial3D in _raw:  # Browning, through the oven window.
		material.albedo_color = _color_for(_raw[material])
	if waiting:
		return  # Not taken out till a TakeOutAction comes for it.
	if _done > band.y and not _burning:
		_burning = true
		session.react("dish_burning")
	var words := "Still pale..." if _done < band.x else ("Golden!" if _done <= band.y else "Burning!")
	session.set_status(words)
	if input.just_pressed or _done >= 1.0:
		_take_out()


func _take_out() -> void:
	_phase = 2
	var score := _score()
	for material: StandardMaterial3D in _raw:
		material.albedo_color = _color_for(_raw[material])
	session.play_sound("clack", oven_front, -2.0, 0.8)
	# Out of the door towards the camera, then up and over onto the top of the
	# oven, the camera rising with it to look down on how they came out.
	var out := oven_front + Vector3(0.0, inside.y, 0.22)  # Clear of the door.
	session.frame(out, view_distance * 1.1, 28.0, 0.5)  # Back a little as it comes at you...
	var slide := _tray.create_tween()
	slide.tween_property(_tray, "position", out, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	slide.tween_callback(func(): session.frame(_home, out_view.x, out_view.y, 1.0))  # ...then up with it.
	slide.tween_property(_tray, "position", Vector3(out.x, _home.y + 0.1, out.z), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	slide.tween_property(_tray, "position", _home, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	var cool := _glow.create_tween()
	cool.tween_property(_glow, "light_energy", 0.0, 1.0)
	await slide.finished
	session.play_sound("clack", _home, -6.0, 1.1)
	for cookie in session.context.get("cookies", []):
		cookie.reparent(session)  # Off the tray, so they're part of how the dish looks.
	var steam := session.make_steam(0.15)
	steam.position = _home
	session.add_child(steam)
	steam.emitting = true
	session.burst(_home + Vector3(0.0, 0.03, 0.0), Color(1.0, 0.9, 0.6), 14, 0.3)
	var words := "Golden!" if score >= 0.9 else ("A bit pale" if _done < band.x else ("Bit dark" if score >= 0.4 else "Burnt!"))
	session.pop_text(words, _home, CookSession.mood_of(score))
	finish(score)


# Full marks in the golden band; pale ones lose a little, burnt ones a lot.
func _score() -> float:
	if _done < band.x:
		return clampf(_done / band.x, 0.0, 1.0) * 0.85
	if _done <= band.y:
		return 1.0
	return clampf(1.0 - (_done - band.y) / (1.0 - band.y), 0.0, 1.0) * 0.8


# Raw dough browns to golden through the band, then darkens to burnt.
func _color_for(raw: Color) -> Color:
	var middle := (band.x + band.y) * 0.5
	if _done <= middle:
		return raw.lerp(golden, _done / middle)
	return golden.lerp(burnt, (_done - middle) / (1.0 - middle))


# A flat bar on the oven top: how done they are, the golden part marked.
func _build_meter() -> void:
	_meter.position = oven_front + meter_offset
	_meter.rotation.x = PI * 0.5  # Standing up, facing the camera at the door.
	session.add_child(_meter)
	_bar(Vector3(meter_length, 0.002, 0.04), 0.0, Color(0.2, 0.15, 0.1, 0.75), 0.0)
	var length := (band.y - band.x) * meter_length
	_bar(Vector3(length, 0.003, 0.048), ((band.x + band.y) * 0.5 - 0.5) * meter_length, Color(1.0, 0.75, 0.3, 0.75), 0.002)
	_fill = _bar(Vector3(meter_length, 0.004, 0.026), 0.0, Color(1.0, 0.45, 0.2), 0.004)
	_fill.scale.x = 0.001
	_fill.position.x = -meter_length * 0.5


func _bar(box_size: Vector3, x: float, color: Color, y: float) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.render_priority = roundi(y * 1000.0)
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = Vector3(x, y, 0.0)
	_meter.add_child(node)
	return node


# For a reel: out right in the middle of golden.
func scripted_hold(_delta: float, _input: CookInput) -> bool:
	return _phase == 1 and not (leave_in and not claimed) and _done >= (band.x + band.y) * 0.5
