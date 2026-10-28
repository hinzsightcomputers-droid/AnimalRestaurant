class_name EmotionPlayer
extends Node3D
## Plays an emotion on a character (from the emotion starter): spawns the icons
## around the head, plays its sound and bounces the body. The regulars are
## models with their own faces, so there's no face swap.
##
##     emotion_player.play_emotion(&"happy")
##
## Put it at the top of the head: the icons and the sound come from here.

## The node that hops / shakes / droops, with its pivot at the feet.
@export var body_root: Node3D
@export var animation_strength: float = 1.0
@export var effect_size: float = 0.45
@export var sound_volume_db: float = 0.0

var _sfx := AudioStreamPlayer3D.new()
var _body_tween: Tween
var _fade: Tween


func _ready() -> void:
	_sfx.name = "EmotionSfx"
	add_child(_sfx)


func play_emotion(emotion_id: StringName) -> void:
	var data: EmotionData = EmotionLibrary.emotions().get(emotion_id)
	if data == null:
		push_warning("EmotionPlayer: unknown emotion '%s'" % emotion_id)
		return
	_spawn_effects(data)
	_play_sound(data)
	_play_body_animation(data.body_animation)


func _spawn_effects(data: EmotionData) -> void:
	if data.effect_texture == null or data.effect_count <= 0 or data.effect_style == &"none":
		return
	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = self
	for i in data.effect_count:
		HeadEffect.spawn(parent, data.effect_texture, data.effect_style,
				global_position, i, data.effect_count, effect_size)


func _play_sound(data: EmotionData) -> void:
	if data.sounds.is_empty():
		return
	_sfx.stream = data.sounds.pick_random()
	_sfx.pitch_scale = randf_range(data.pitch_min, data.pitch_max)
	_sfx.volume_db = sound_volume_db + data.volume_db
	_sfx.play()
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if data.max_seconds > 0.0:  # Fade out over its last quarter second.
		_fade = create_tween()
		_fade.tween_interval(maxf(data.max_seconds - 0.25, 0.0))
		_fade.tween_property(_sfx, "volume_db", -60.0, 0.25)
		_fade.tween_callback(_sfx.stop)


# The body starts from rest each time (it's only ever moved by these).
func _reset_body() -> void:
	body_root.position = Vector3.ZERO
	body_root.rotation = Vector3.ZERO
	body_root.scale = Vector3.ONE


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
			t.tween_property(body_root, "position:y", 0.22 * s, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.tween_property(body_root, "position:y", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.tween_property(body_root, "position:y", 0.10 * s, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.tween_property(body_root, "position:y", 0.0, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		"nod":
			for i in 2:
				t.tween_property(body_root, "rotation:x", 0.16 * s, 0.1)
				t.tween_property(body_root, "rotation:x", 0.0, 0.12)
		"shake":
			for i in 4:
				t.tween_property(body_root, "rotation:z", 0.12 * s, 0.05)
				t.tween_property(body_root, "rotation:z", -0.12 * s, 0.05)
			t.tween_property(body_root, "rotation:z", 0.0, 0.05)
		"droop":
			var squash := Vector3(1.0 + 0.04 * s, 1.0 - 0.08 * s, 1.0 + 0.04 * s)
			t.tween_property(body_root, "scale", squash, 0.35).set_trans(Tween.TRANS_SINE)
			t.parallel().tween_property(body_root, "rotation:x", 0.12 * s, 0.35).set_trans(Tween.TRANS_SINE)
			t.tween_interval(1.0)
			t.tween_property(body_root, "scale", Vector3.ONE, 0.6)
			t.parallel().tween_property(body_root, "rotation:x", 0.0, 0.6)
		"wobble":
			for i in 3:
				var amp := 0.11 * s * (1.0 - float(i) * 0.25)
				t.tween_property(body_root, "rotation:z", amp, 0.08)
				t.tween_property(body_root, "rotation:z", -amp, 0.1)
			t.tween_property(body_root, "rotation:z", 0.0, 0.08)
		"recoil":
			t.tween_property(body_root, "rotation:x", -0.2 * s, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(body_root, "scale", Vector3.ONE * (1.0 + 0.07 * s), 0.07)
			t.tween_property(body_root, "rotation:x", 0.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(body_root, "scale", Vector3.ONE, 0.25)
		_:
			t.kill()
