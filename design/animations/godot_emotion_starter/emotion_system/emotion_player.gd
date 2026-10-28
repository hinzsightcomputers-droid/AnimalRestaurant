class_name EmotionPlayer
extends Node3D
## Plays an emotion on a character: swaps the face (texture swap), spawns the
## head effect, plays a sound and animates the body.
##
##     $EmotionPlayer.play_emotion(&"happy")        # shows it, then returns to neutral after a few seconds
##     $EmotionPlayer.play_emotion(&"sad", 0.0)     # 0 = stay until the next emotion

signal emotion_started(emotion_id: StringName)
signal emotion_ended(emotion_id: StringName)

@export_group("Face (texture swap)")
## A flat quad sitting on the front of the head. The face atlas is shown on it.
@export var face_mesh: MeshInstance3D
## Leave empty to use res://emotion_system/face_atlas.png
@export var face_atlas: Texture2D
@export var atlas_columns: int = 4
@export var atlas_rows: int = 3
## Which atlas cell is the closed-eyes face used for blinking.
@export var blink_face_index: int = 11
@export var blink_enabled: bool = true

@export_group("Head effect")
## An empty Node3D / Marker3D above the head where icons appear.
@export var head_anchor: Node3D
@export var effect_size: float = 0.45

@export_group("Body animation")
## The node that hops / shakes / droops. Put the bear model under it, with its pivot at the feet.
@export var body_root: Node3D
@export var animation_strength: float = 1.0

@export_group("Behaviour")
@export var default_emotion: StringName = &"neutral"
## Seconds before returning to the default face. 0 = never return on its own.
@export var return_to_default_after: float = 2.5
@export var sound_volume_db: float = 0.0

var current_emotion: StringName = &"neutral"

var _emotions: Dictionary = {}
var _face_material: StandardMaterial3D
var _sfx: AudioStreamPlayer3D
var _body_tween: Tween
var _base_pos := Vector3.ZERO
var _base_rot := Vector3.ZERO
var _base_scale := Vector3.ONE
var _return_timer: Timer
var _blink_timer: Timer


func _ready() -> void:
	_emotions = EmotionLibrary.build()
	current_emotion = default_emotion
	_setup_face_material()
	_setup_audio()
	if body_root != null:
		_base_pos = body_root.position
		_base_rot = body_root.rotation
		_base_scale = body_root.scale

	_return_timer = Timer.new()
	_return_timer.one_shot = true
	_return_timer.timeout.connect(_on_return_timeout)
	add_child(_return_timer)

	_blink_timer = Timer.new()
	_blink_timer.one_shot = true
	_blink_timer.timeout.connect(_on_blink_timeout)
	add_child(_blink_timer)
	_blink_timer.start(randf_range(2.0, 4.0))

	_set_face(_face_index_for(default_emotion))


# ------------------------------------------------------------------ public API

func play_emotion(emotion_id: StringName, hold: float = -1.0) -> void:
	## hold < 0 : use return_to_default_after
	## hold = 0 : stay on this emotion until another one is played
	## hold > 0 : return to default after that many seconds
	var data: EmotionData = _emotions.get(emotion_id)
	if data == null:
		push_warning("EmotionPlayer: unknown emotion '%s'" % emotion_id)
		data = _emotions.get(&"neutral")
		if data == null:
			return
	current_emotion = data.id
	_set_face(data.face_index)
	_spawn_effects(data)
	_play_sound(data)
	_play_body_animation(data.body_animation)
	emotion_started.emit(current_emotion)

	var t := return_to_default_after if hold < 0.0 else hold
	if t > 0.0 and current_emotion != default_emotion:
		_return_timer.start(t)
	else:
		_return_timer.stop()


func play_default() -> void:
	play_emotion(default_emotion, 0.0)


## Keep the current face, but go back to default after `seconds`.
func return_to_default_in(seconds: float) -> void:
	if current_emotion == default_emotion:
		return
	_return_timer.start(maxf(seconds, 0.05))


func has_emotion(emotion_id: StringName) -> bool:
	return _emotions.has(emotion_id)


func get_emotion_ids() -> Array:
	return _emotions.keys()


# --------------------------------------------------------------------- face

func _setup_face_material() -> void:
	if face_mesh == null:
		push_warning("EmotionPlayer: face_mesh is not assigned, so faces won't change.")
		return
	if face_atlas == null:
		face_atlas = load("res://emotion_system/face_atlas.png")
	_face_material = StandardMaterial3D.new()
	_face_material.albedo_texture = face_atlas
	_face_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_face_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_face_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_face_material.uv1_scale = Vector3(1.0 / atlas_columns, 1.0 / atlas_rows, 1.0)
	face_mesh.material_override = _face_material


func _set_face(index: int) -> void:
	if _face_material == null:
		return
	@warning_ignore("integer_division")
	var row := index / atlas_columns
	var col := index % atlas_columns
	_face_material.uv1_offset = Vector3(float(col) / atlas_columns, float(row) / atlas_rows, 0.0)


func _face_index_for(emotion_id: StringName) -> int:
	var d: EmotionData = _emotions.get(emotion_id)
	return d.face_index if d != null else 0


func _on_blink_timeout() -> void:
	if blink_enabled and current_emotion == default_emotion and _face_material != null:
		_set_face(blink_face_index)
		await get_tree().create_timer(0.12).timeout
		if current_emotion == default_emotion:
			_set_face(_face_index_for(default_emotion))
	_blink_timer.start(randf_range(2.5, 5.5))


func _on_return_timeout() -> void:
	var ended := current_emotion
	current_emotion = default_emotion
	_set_face(_face_index_for(default_emotion))
	emotion_ended.emit(ended)


# ------------------------------------------------------------ effects + sound

func _spawn_effects(data: EmotionData) -> void:
	if data.effect_texture == null or data.effect_count <= 0 or data.effect_style == &"none":
		return
	var anchor: Node3D = head_anchor if head_anchor != null else self
	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = self
	for i in data.effect_count:
		HeadEffect.spawn(parent, data.effect_texture, data.effect_style,
				anchor.global_position, i, data.effect_count, effect_size)


func _setup_audio() -> void:
	_sfx = AudioStreamPlayer3D.new()
	_sfx.name = "EmotionSfx"
	var holder: Node = head_anchor if head_anchor != null else self
	holder.add_child.call_deferred(_sfx)


func _play_sound(data: EmotionData) -> void:
	if data.sounds.is_empty() or _sfx == null:
		return
	_sfx.stream = data.sounds.pick_random()
	_sfx.pitch_scale = randf_range(data.pitch_min, data.pitch_max)
	_sfx.volume_db = sound_volume_db + data.volume_db
	_sfx.play()


# ----------------------------------------------------------- body animation

func _reset_body() -> void:
	body_root.position = _base_pos
	body_root.rotation = _base_rot
	body_root.scale = _base_scale


func _play_body_animation(anim: StringName) -> void:
	if body_root == null or anim == &"none":
		return
	if _body_tween != null and _body_tween.is_valid():
		_body_tween.kill()
	_reset_body()

	var s := animation_strength
	var t := create_tween()
	_body_tween = t

	match String(anim):
		"hop":
			t.tween_property(body_root, "position:y", _base_pos.y + 0.22 * s, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.tween_property(body_root, "position:y", _base_pos.y, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.tween_property(body_root, "position:y", _base_pos.y + 0.10 * s, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.tween_property(body_root, "position:y", _base_pos.y, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		"nod":
			for i in 2:
				t.tween_property(body_root, "rotation:x", _base_rot.x + 0.16 * s, 0.1)
				t.tween_property(body_root, "rotation:x", _base_rot.x, 0.12)
		"shake":
			for i in 4:
				t.tween_property(body_root, "rotation:z", _base_rot.z + 0.12 * s, 0.05)
				t.tween_property(body_root, "rotation:z", _base_rot.z - 0.12 * s, 0.05)
			t.tween_property(body_root, "rotation:z", _base_rot.z, 0.05)
		"droop":
			var squash := Vector3(_base_scale.x * (1.0 + 0.04 * s), _base_scale.y * (1.0 - 0.08 * s), _base_scale.z * (1.0 + 0.04 * s))
			t.tween_property(body_root, "scale", squash, 0.35).set_trans(Tween.TRANS_SINE)
			t.parallel().tween_property(body_root, "rotation:x", _base_rot.x + 0.12 * s, 0.35).set_trans(Tween.TRANS_SINE)
			t.tween_interval(1.0)
			t.tween_property(body_root, "scale", _base_scale, 0.6)
			t.parallel().tween_property(body_root, "rotation:x", _base_rot.x, 0.6)
		"wobble":
			for i in 3:
				var amp := 0.11 * s * (1.0 - float(i) * 0.25)
				t.tween_property(body_root, "rotation:z", _base_rot.z + amp, 0.08)
				t.tween_property(body_root, "rotation:z", _base_rot.z - amp, 0.1)
			t.tween_property(body_root, "rotation:z", _base_rot.z, 0.08)
		"recoil":
			t.tween_property(body_root, "rotation:x", _base_rot.x - 0.2 * s, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(body_root, "scale", _base_scale * (1.0 + 0.07 * s), 0.07)
			t.tween_property(body_root, "rotation:x", _base_rot.x, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(body_root, "scale", _base_scale, 0.25)
		_:
			t.kill()
