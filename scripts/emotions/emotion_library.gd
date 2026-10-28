class_name EmotionLibrary
extends RefCounted
## The emotion table (from the emotion starter). To add or change an emotion, edit PRESETS.
##
## Icons:   res://design/animations/emotion_effects/<emotion>.png
## Sounds:  drop .wav / .ogg / .mp3 files into res://design/sound/sound_effects/Emotions/<emotion>/
##          (several files = one is picked at random each time)

const EFFECT_DIR := "res://design/animations/emotion_effects/"
const AUDIO_DIR := "res://design/sound/sound_effects/Emotions/"
const AUDIO_EXTENSIONS := ["wav", "ogg", "mp3"]

# style   = none | float_up | burst | drop | pop
# count   = how many effect icons spawn
# anim    = none | hop | nod | shake | droop | wobble | recoil
# volume  = how loud its sound plays (dB), to even out the sounds
# cut     = fade its sound out by this many seconds in, for a long one
const PRESETS := {
	&"neutral":   {"style": &"none",     "count": 0, "anim": &"none"},
	&"happy":     {"style": &"float_up", "count": 3, "anim": &"nod"},
	&"joyful":    {"style": &"float_up", "count": 4, "anim": &"hop"},
	&"excited":   {"style": &"burst",    "count": 5, "anim": &"hop"},
	&"surprised": {"style": &"pop",      "count": 1, "anim": &"recoil"},
	&"sad":       {"style": &"pop",      "count": 1, "anim": &"droop"},
	&"angry":     {"style": &"float_up", "count": 3, "anim": &"shake"},
	&"nervous":   {"style": &"drop",     "count": 3, "anim": &"wobble", "volume": 6.0},  # A quiet squeak.
	&"confused":  {"style": &"pop",      "count": 1, "anim": &"wobble"},
	&"tired":     {"style": &"float_up", "count": 3, "anim": &"droop", "cut": 2.0},  # A long, slow scratch.
	&"shy":       {"style": &"float_up", "count": 2, "anim": &"wobble"},
}

static var _built := {}


## Every emotion, built once and shared.
static func emotions() -> Dictionary:
	if _built.is_empty():
		_built = build()
	return _built


static func build() -> Dictionary:
	var result := {}
	for id in PRESETS:
		var p: Dictionary = PRESETS[id]
		var d := EmotionData.new()
		d.id = id
		d.effect_style = p["style"]
		d.effect_count = p["count"]
		d.body_animation = p["anim"]
		d.volume_db = p.get("volume", 0.0)
		d.max_seconds = p.get("cut", 0.0)
		var tex_path: String = EFFECT_DIR + String(id) + ".png"
		if ResourceLoader.exists(tex_path):
			d.effect_texture = load(tex_path)
		d.sounds = load_sounds_from_folder(AUDIO_DIR + String(id))
		result[id] = d
	return result


## Loads every .wav/.ogg/.mp3 in a folder. Works in the editor and in exported games.
static func load_sounds_from_folder(dir_path: String) -> Array[AudioStream]:
	var out: Array[AudioStream] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir():
			# Exported games list "file.wav.import" instead of "file.wav".
			var clean := file.trim_suffix(".import").trim_suffix(".remap")
			if clean.get_extension().to_lower() in AUDIO_EXTENSIONS:
				var full := dir_path.path_join(clean)
				if ResourceLoader.exists(full):
					var stream := load(full)
					if stream is AudioStream and not out.has(stream):
						out.append(stream as AudioStream)
		file = dir.get_next()
	dir.list_dir_end()
	return out
