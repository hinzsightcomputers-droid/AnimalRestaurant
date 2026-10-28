class_name DialogueCharacter
extends Node3D
## Put this on the root of each talking character. The DialogueRunner finds
## characters by character_id, so the id must match the "speaker" in your dialogue JSON.
##
##     $Stitches.react(&"angry")     # trigger a reaction from your own code

@export var character_id: StringName = &"stitches"
@export var display_name: String = "Stitches"
@export var name_color: Color = Color("#8a5a3c")
@export var emotion_player: EmotionPlayer
@export var talk_blips: TalkBlips


func _ready() -> void:
	add_to_group("dialogue_characters")


## hold: 0 = stay until the next emotion, > 0 = return to neutral after that many seconds,
##       < 0 = use the EmotionPlayer's default.
func react(emotion_id: StringName, hold: float = -1.0) -> void:
	if talk_blips != null:
		talk_blips.set_emotion(emotion_id)
	if emotion_player != null:
		emotion_player.play_emotion(emotion_id, hold)


func speak_letter(ch: String) -> void:
	if talk_blips != null:
		talk_blips.blip(ch)


func finish_talking() -> void:
	if talk_blips != null:
		talk_blips.set_emotion(&"neutral")
	if emotion_player != null:
		emotion_player.return_to_default_in(2.0)
