# Music (autoload): background music that keeps playing across scene changes.
# The main theme starts when the game loads (on the logo splash), carries on
# through the start screen, and fades out as the start screen closes into the
# restaurant. In the restaurant the hour themes take over: one song per block
# of real local hours, named by its hours (e.g. "8am-11am.wav" plays from 8:00
# until 11:59 am). Each loops until its hours are over, fades out over the last
# few seconds, and the next block's song starts right on the hour.
# Looping is set in each track's import settings (loop points in the Import
# tab), so songs repeat sample-accurately with no gap or click.
extends Node

const MAIN_THEME := "res://design/sound/music/Dinner Time Main Theme.wav"
const HOUR_THEMES_DIR := "res://design/sound/music/hour_themes"
const SILENT_DB := -60.0
const HOUR_FADE_OUT_SECONDS := 3.0  # The old block's song fades out over the seconds before the hour.
const RESTAURANT_FADE_IN_SECONDS := 1.5  # The hour song coming in as the restaurant opens.

var _player := AudioStreamPlayer.new()
var _tween: Tween
var _fading_out := false
var _fade_ends_at := 0.0  # When the running fade reaches silence (seconds since start).
var _hour_themes: Array[Dictionary] = []  # { first, last, path }: hours 0-23, last included.
var _hour_mode := false  # In the restaurant: follow the clock.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Keeps playing (and fading) while the game is paused.
	_player.bus = Settings.MUSIC_BUS  # Its own volume on the settings screen.
	add_child(_player)
	_hour_themes = _find_hour_themes()


# Play `path` (e.g. MAIN_THEME) from the beginning, unless it's already playing.
func play(path: String, fade_in_seconds := 0.0) -> void:
	_hour_mode = false
	_start(path, fade_in_seconds)


# In the restaurant: play the song for the current hour, and switch on the hour.
func play_hour_themes() -> void:
	_hour_mode = true
	_start(_hour_theme_at(GameClock.now_local()["hour"]), RESTAURANT_FADE_IN_SECONDS)


# Fade to silence over `seconds`, then stop. If it's already fading, it only
# changes when this would finish sooner (e.g. the opening was skipped), carrying
# on from the volume it has reached.
func fade_out(seconds: float) -> void:
	if not _player.playing:
		return
	var ends_at := Time.get_ticks_msec() / 1000.0 + seconds
	if _fading_out and ends_at >= _fade_ends_at:
		return
	_fading_out = true
	_fade_ends_at = ends_at
	_kill_tween()
	_tween = create_tween()
	# Even steps in decibels sound like an even fade to the ear.
	_tween.tween_property(_player, "volume_db", SILENT_DB, seconds).set_trans(Tween.TRANS_LINEAR)
	_tween.tween_callback(_player.stop)


# Drop the music to `db` (0 = full volume again) over `seconds`, e.g. under a
# big moment scene.
func dip(db: float, seconds: float) -> void:
	if not _player.playing or _fading_out:
		return
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", db, seconds).set_trans(Tween.TRANS_SINE)


func is_playing() -> bool:
	return _player.playing


func current_path() -> String:
	return _player.stream.resource_path if _player.stream != null else ""


# Following the clock: the new block's song starts as soon as its first hour
# begins, and the old one fades out just before.
func _process(_delta: float) -> void:
	if _hour_mode:
		_follow_clock(GameClock.now_local(), fmod(Time.get_unix_time_from_system(), 1.0))


# `now` is a local time dictionary (hour, minute, second), `fraction` the part
# of a second past it.
func _follow_clock(now: Dictionary, fraction: float) -> void:
	var path := _hour_theme_at(now["hour"])
	if path != current_path():
		_start(path, 0.0)  # Right on the hour, at full volume.
		return
	var next_path := _hour_theme_at((int(now["hour"]) + 1) % 24)
	var until_hour: float = 3600.0 - (now["minute"] * 60 + now["second"] + fraction)
	if next_path != path and until_hour <= HOUR_FADE_OUT_SECONDS:
		fade_out(until_hour)


func _start(path: String, fade_in_seconds: float) -> void:
	if path.is_empty():
		return
	if _player.playing and not _fading_out and current_path() == path:
		return
	if not ResourceLoader.exists(path):
		push_warning("Music not found: %s" % path)
		return
	_kill_tween()
	_fading_out = false
	_player.stream = load(path)
	_player.volume_db = SILENT_DB if fade_in_seconds > 0.0 else 0.0
	_player.play()
	if fade_in_seconds > 0.0:
		_tween = create_tween()
		_tween.tween_property(_player, "volume_db", 0.0, fade_in_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# The hour theme for `hour` (0-23), or "" if no file covers it.
func _hour_theme_at(hour: int) -> String:
	return _theme_in(_hour_themes, hour)


static func _theme_in(themes: Array[Dictionary], hour: int) -> String:
	for theme in themes:
		var first: int = theme["first"]
		var last: int = theme["last"]
		var inside := first <= hour and hour <= last if first <= last else hour >= first or hour <= last  # e.g. 10pm-2am.
		if inside:
			return theme["path"]
	return ""


# Every "<hour><am|pm>-<hour><am|pm>.wav" in HOUR_THEMES_DIR.
func _find_hour_themes() -> Array[Dictionary]:
	var themes: Array[Dictionary] = []
	var pattern := RegEx.create_from_string("^(\\d{1,2})(am|pm)-(\\d{1,2})(am|pm)\\.(wav|ogg|mp3)$")
	for file_name in DirAccess.get_files_at(HOUR_THEMES_DIR):
		file_name = file_name.trim_suffix(".import").trim_suffix(".remap")  # Exported games list these instead.
		var found := pattern.search(file_name.to_lower())
		var path := "%s/%s" % [HOUR_THEMES_DIR, file_name]
		if found == null or themes.any(func(t): return t["path"] == path):
			continue
		themes.append({
			"first": _to_24_hour(int(found.get_string(1)), found.get_string(2)),
			"last": _to_24_hour(int(found.get_string(3)), found.get_string(4)),
			"path": path,
		})
	for hour in 24:
		if _theme_in(themes, hour).is_empty():
			push_warning("No hour theme covers %d:00 (add a file to %s)." % [hour, HOUR_THEMES_DIR])
	return themes


# 12am -> 0, 8am -> 8, 12pm -> 12, 6pm -> 18.
static func _to_24_hour(hour: int, am_pm: String) -> int:
	return hour % 12 + (12 if am_pm == "pm" else 0)


func _kill_tween() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
