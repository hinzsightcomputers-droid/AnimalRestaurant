class_name TalkBlips
extends Node3D
## The Animal Crossing style "babble". Plays a short blip for letters while a line is typed out.
## Put short voice blips (50-100 ms) in res://emotion_system/audio/blips/ - or assign blip_streams.
## Give each character a different base_pitch so they sound different.

@export var blip_streams: Array[AudioStream] = []
@export var blip_folder: String = "res://emotion_system/audio/blips"
@export var base_pitch: float = 1.0
@export var pitch_jitter: float = 0.04
@export var volume_db: float = -6.0
## 1 = a blip on every letter, 2 = every second letter...
@export var every_n_letters: int = 2
## Vary the pitch per letter so it sounds like a little melody instead of one note.
@export var melodic: bool = true

const SEMITONES := [-3, -1, 0, 2, 4, 7, 9]
const EMOTION_PITCH := {
	&"happy": 1.08, &"joyful": 1.15, &"excited": 1.22, &"surprised": 1.18,
	&"sad": 0.88, &"angry": 0.82, &"nervous": 1.12, &"confused": 0.98,
	&"tired": 0.84, &"shy": 1.06,
}

var _player: AudioStreamPlayer3D
var _emotion_mult: float = 1.0
var _letter_count: int = 0


func _ready() -> void:
	if blip_streams.is_empty():
		blip_streams = EmotionLibrary.load_sounds_from_folder(blip_folder)
	_player = AudioStreamPlayer3D.new()
	_player.name = "BlipPlayer"
	add_child(_player)


func set_emotion(emotion_id: StringName) -> void:
	_emotion_mult = EMOTION_PITCH.get(emotion_id, 1.0)


func blip(ch: String) -> void:
	if blip_streams.is_empty() or _player == null or ch.length() == 0:
		return
	if ch.to_lower() == ch.to_upper():
		return  # not a letter (space, punctuation, digit)
	_letter_count += 1
	if _letter_count % maxi(every_n_letters, 1) != 0:
		return

	var pitch := base_pitch * _emotion_mult
	if melodic:
		var step: int = SEMITONES[ch.to_lower().unicode_at(0) % SEMITONES.size()]
		pitch *= pow(2.0, float(step) / 12.0)
	pitch *= randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)

	_player.stream = blip_streams.pick_random()
	_player.pitch_scale = clampf(pitch, 0.25, 4.0)
	_player.volume_db = volume_db
	_player.play()
