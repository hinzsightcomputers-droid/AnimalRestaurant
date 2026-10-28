class_name EmotionData
extends Resource
## One emotion = a head effect + sounds + a body animation.
## EmotionLibrary builds these for you, but you can also make your own
## EmotionData resources in the editor and add them to the library.

@export var id: StringName = &"neutral"

## The icon that pops above the head (the "lines around the head" part).
@export var effect_texture: Texture2D

## How the icon moves: none, float_up, burst, drop, pop
@export var effect_style: StringName = &"none"
@export var effect_count: int = 0

## Sounds are picked at random. EmotionLibrary fills these from
## design/sound/sound_effects/Emotions/<emotion>/ automatically.
@export var sounds: Array[AudioStream] = []
@export var pitch_min: float = 0.95
@export var pitch_max: float = 1.05
@export var volume_db: float = 0.0
## Fade the sound out by this many seconds in (0 = let it play to the end).
@export var max_seconds: float = 0.0

## Body animation: none, hop, nod, shake, droop, wobble, recoil
@export var body_animation: StringName = &"none"
