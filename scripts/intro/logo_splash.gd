# LogoSplash: the very first thing on screen. The logo fades in and holds, then
# a circle wipe closes on it and opens on the start screen (StreetIntro). Uses
# the first logo file found in LOGO_PATHS; until one is added, a placeholder line
# of text shows instead. The logo sits on LOGO_BACKGROUND (white, like the logo
# was drawn on). Any button skips ahead.
extends Control

const NEXT_SCENE := "res://scenes/intro/street_intro.tscn"
const LOGO_PATHS := ["res://assets/logo.png", "res://assets/logo.svg", "res://assets/logo.webp", "res://assets/logo.jpg"]
const FADE_IN_SECONDS := 1.0
const HOLD_SECONDS := 1.6
const LOGO_BACKGROUND := Color(1, 1, 1)

@onready var content: Control = $Content
@onready var logo: TextureRect = $Content/Logo
@onready var placeholder: Label = $Content/Placeholder
@onready var background: ColorRect = $Background

var _tween: Tween
var _leaving := false


func _ready() -> void:
	Music.play(Music.MAIN_THEME)  # The game has loaded: the theme starts here and carries on to the start screen.
	var logo_path := _find_logo()
	logo.visible = not logo_path.is_empty()
	placeholder.visible = logo_path.is_empty()
	background.color = IrisTransition.COLOR  # For the placeholder: the same dark as the transitions.
	if not logo_path.is_empty():
		logo.texture = load(logo_path)
		background.color = LOGO_BACKGROUND

	content.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(content, "modulate:a", 1.0, FADE_IN_SECONDS).set_trans(Tween.TRANS_SINE)
	_tween.tween_interval(HOLD_SECONDS)
	_tween.tween_callback(_next)


func _unhandled_input(event: InputEvent) -> void:
	var pressed := (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton) and event.is_pressed()
	if not pressed or _leaving:
		return
	get_viewport().set_input_as_handled()
	_tween.kill()
	_next()


func _next() -> void:
	_leaving = true
	IrisTransition.change_scene(get_tree(), NEXT_SCENE)


func _find_logo() -> String:
	for path in LOGO_PATHS:
		if ResourceLoader.exists(path):
			return path
	return ""
