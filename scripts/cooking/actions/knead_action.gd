# KneadAction: knead a dough in its bowl, in rhythm. A ring closes in on the
# dough; press as it reaches it and the dough is pushed out flat and folded
# back over, a little smoother each time (its floury lumps work in). Each
# knead scores how close to the ring the press falls. After the last one it's
# divided into balls that go onto the griddle as rounds (`pieces` of them, the
# recipe's), ready to fill (WrapAction); or, with `onto` empty, it waits in its
# bowl (the session's context "dough") for WrapAction to take it.
class_name KneadAction
extends CookAction

@export var in_surface := "MixBowl"
@export var onto := ""                      # Where the balls go after (empty: it waits in the bowl for WrapAction).
@export var kneads := 6
@export var beat_seconds := 0.8             # How long the ring takes to close in.
@export var tolerance := 0.22               # Seconds off that scores nothing.
@export var perfect_seconds := 0.07
@export var dough_color := Color(0.93, 0.82, 0.62)
@export var dough_radius := 0.05
@export var round_radius := 0.075           # How wide each round is on the griddle.
@export var round_thickness := 0.022
@export var round_gap := 0.2                # How far apart the rounds go.

var _dough: Node3D
var _lumps: Array[MeshInstance3D] = []
var _ring: MeshInstance3D
var _clock := 0.0
var _done_kneads := 0
var _scores: Array[float] = []
var _busy := false
var _turn := 0.0


func _init() -> void:
	view_distance = 0.5
	view_pitch = 62.0


func view_point() -> Vector3:
	return session.surface(in_surface).position


func uses_cursor() -> bool:
	return false


func aims() -> bool:
	return false  # Just the button, in time.


func _begin() -> void:
	var bowl := session.surface(in_surface)
	if bowl.liquid != null:
		bowl.liquid.visible = false  # It's a dough now.
	_dough = Node3D.new()
	var body := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = dough_radius
	ball.height = dough_radius * 1.4
	var dough := StandardMaterial3D.new()
	dough.albedo_color = dough_color
	dough.roughness = 0.85
	dough.set_meta(ToonStyle.FOOD, "dough")
	ball.material = dough
	body.mesh = ball
	_dough.add_child(body)
	var flour := StandardMaterial3D.new()
	flour.albedo_color = Color(0.98, 0.97, 0.93)
	flour.set_meta(ToonStyle.FOOD, "dough")
	for i in 7:  # Floury lumps that work in as it's kneaded.
		var lump := MeshInstance3D.new()
		var bump := SphereMesh.new()
		bump.radius = dough_radius * randf_range(0.18, 0.26)
		bump.height = bump.radius * 1.6
		bump.material = flour
		lump.mesh = bump
		var at := Vector3.FORWARD.rotated(Vector3.UP, i * 2.4).rotated(Vector3.RIGHT, randf_range(-0.9, -0.2))
		lump.position = Vector3(at.x * dough_radius, absf(at.y) * dough_radius * 0.55 + dough_radius * 0.2, at.z * dough_radius)
		_dough.add_child(lump)
		_lumps.append(lump)
	_dough.position = Vector3(bowl.position.x, bowl.position.y + bowl.floor_at + dough_radius * 0.6, bowl.position.z)
	session.add_child(_dough)
	_ring = session.make_ring(dough_radius, Color(1.0, 1.0, 1.0, 0.9))
	_ring.position = _dough.position + Vector3(0.0, dough_radius * 0.75, 0.0)
	session.play_sound("plop", _dough.position, -6.0, 0.8)


func end() -> void:
	if _ring != null:
		_ring.queue_free()
	if is_instance_valid(_dough) and not session.context.get("dough") == _dough:
		_dough.queue_free()


func update(delta: float, input: CookInput) -> void:
	if done or _done_kneads >= kneads:
		return
	_clock += delta * GameState.difficulty_value("closeup_pace")
	# The ring closes in on the dough each beat, then starts again.
	var phase := fmod(_clock, beat_seconds) / beat_seconds
	_ring.scale = Vector3.ONE * lerpf(2.4, 1.0, phase)
	session.set_status("Knead %d of %d: press as the ring meets the dough" % [_done_kneads + 1, kneads])
	if input.just_pressed and not _busy:
		var off := minf(fmod(_clock, beat_seconds), beat_seconds - fmod(_clock, beat_seconds))  # From the nearest ring meeting the dough.
		var score := 1.0 - clampf((off - perfect_seconds) / (tolerance - perfect_seconds), 0.0, 1.0)
		_knead(score)


# Pushed out, folded back over and turned: a little smoother.
func _knead(score: float) -> void:
	_busy = true
	_scores.append(score)
	_done_kneads += 1
	session.pop_text("Knead!" if score >= 0.9 else ("Nice" if score >= 0.5 else "Off the beat"), _dough.position, CookSession.mood_of(score))
	session.play_sound("squish", _dough.position, -4.0, randf_range(0.9, 1.1))
	_turn += deg_to_rad(70.0)
	var smooth := float(_done_kneads) / kneads
	var tween := _dough.create_tween()
	tween.tween_property(_dough, "scale", Vector3(1.35, 0.55, 1.15), 0.1).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_dough, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_dough, "rotation:y", _turn, 0.22)
	for lump in _lumps:
		lump.create_tween().tween_property(lump, "scale", Vector3.ONE * maxf(1.0 - smooth * 1.1, 0.01), 0.2)
	tween.tween_callback(func():
		_busy = false
		if _done_kneads >= kneads:
			_divide())


# Into balls, onto the griddle as rounds, and done.
func _divide() -> void:
	_ring.visible = false
	var count := maxi(session.recipe.pieces, 1)
	if onto.is_empty():
		session.context["dough"] = _dough
		finish(average(_scores))
		return
	_dough.visible = false
	for i in count:
		var spot := round_spot(session, onto, i, count, round_gap)
		var ball := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = dough_radius * 0.7
		mesh.height = dough_radius * 1.1
		var dough := StandardMaterial3D.new()
		dough.albedo_color = dough_color
		dough.set_meta(ToonStyle.FOOD, "dough")
		mesh.material = dough
		ball.mesh = mesh
		ball.position = _dough.position
		session.add_child(ball)
		var from := _dough.position
		var hop := ball.create_tween()
		hop.tween_interval(i * 0.12)
		hop.tween_method(func(t: float): ball.position = from.lerp(spot, t) + Vector3(0.0, sin(t * PI) * 0.12, 0.0), 0.0, 1.0, 0.4).set_trans(Tween.TRANS_SINE)
		hop.tween_callback(func():
			ball.queue_free()
			var piece := session.add_piece(dough_color, round_thickness, spot, onto)
			piece.spread_to = round_radius
			piece.set_radius(round_radius * 0.7)
			piece.create_tween().tween_method(piece.set_radius, round_radius * 0.7, round_radius, 0.2).set_ease(Tween.EASE_OUT)
			session.play_sound("plop", spot, -6.0)
			if i == count - 1:
				finish(average(_scores)))


# Where the `index`th of `count` rounds goes on the surface.
static func round_spot(on_session: CookSession, surface_name: String, index: int, count: int, gap: float) -> Vector3:
	var griddle := on_session.surface(surface_name)
	return griddle.position + Vector3((index - (count - 1) * 0.5) * gap, griddle.thickness * 0.5 + 0.004, 0.0)


# For a reel: right as the ring meets the dough.
func scripted_hold(_delta: float, input: CookInput) -> bool:
	var phase := fmod(_clock, beat_seconds) / beat_seconds
	return phase > 0.96 and not input.held
