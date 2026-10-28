class_name EmotionLibrary
extends RefCounted
## Builds the emotion table. To add or change an emotion, edit PRESETS.
##
## Effects:  res://emotion_system/effects/<emotion>.png   (replace with your own art)
## Sounds:   drop .wav / .ogg / .mp3 files into res://emotion_system/audio/<emotion>/
##           (several files = one is picked at random each time)

const EFFECT_DIR := "res://emotion_system/effects/"
const AUDIO_DIR := "res://emotion_system/audio/"
const AUDIO_EXTENSIONS := ["wav", "ogg", "mp3"]

# face    = cell number in face_atlas.png
# style   = none | float_up | burst | drop | pop
# count   = how many effect icons spawn
# anim    = none | hop | nod | shake | droop | wobble | recoil
const PRESETS := {
	&"neutral":   {"face": 0,  "style": &"none",     "count": 0, "anim": &"none"},
	&"happy":     {"face": 1,  "style": &"float_up", "count": 3, "anim": &"nod"},
	&"joyful":    {"face": 2,  "style": &"float_up", "count": 4, "anim": &"hop"},
	&"excited":   {"face": 3,  "style": &"burst",    "count": 5, "anim": &"hop"},
	&"surprised": {"face": 4,  "style": &"pop",      "count": 1, "anim": &"recoil"},
	&"sad":       {"face": 5,  "style": &"pop",      "count": 1, "anim": &"droop"},
	&"angry":     {"face": 6,  "style": &"float_up", "count": 3, "anim": &"shake"},
	&"nervous":   {"face": 7,  "style": &"drop",     "count": 3, "anim": &"wobble"},
	&"confused":  {"face": 8,  "style": &"pop",      "count": 1, "anim": &"wobble"},
	&"tired":     {"face": 9,  "style": &"float_up", "count": 3, "anim": &"droop"},
	&"shy":       {"face": 10, "style": &"float_up", "count": 2, "anim": &"wobble"},
}


static func build() -> Dictionary:
	var result := {}
	for id in PRESETS:
		var p: Dictionary = PRESETS[id]
		var d := EmotionData.new()
		d.id = id
		d.face_index = p["face"]
		d.effect_style = p["style"]
		d.effect_count = p["count"]
		d.body_animation = p["anim"]
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
