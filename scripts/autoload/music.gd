# Music (autoload): background music that keeps playing across scene changes.
# The main theme starts when the game loads (on the logo splash), carries on
# through the start screen, and fades out as the start screen closes into the
# restaurant. Looping is set in the track's import settings (loop points in the
# Import tab), so it repeats sample-accurately with no gap or click.
extends Node

const MAIN_THEME := "res://design/sound/music/Dinner Time Main Theme.wav"
const SILENT_DB := -60.0

var _player := AudioStreamPlayer.new()
var _tween: Tween
var _fading_out := false
var _fade_ends_at := 0.0  # When the running fade reaches silence (seconds since start).


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Keeps playing (and fading) while the game is paused.
	add_child(_player)


# Start `path` from the beginning (unless it's already playing).
func play(path: String) -> void:
	if _player.playing and _player.stream != null and _player.stream.resource_path == path:
		return
	if not ResourceLoader.exists(path):
		push_warning("Music not found: %s" % path)
		return
	_kill_tween()
	_fading_out = false
	_player.stream = load(path)
	_player.volume_db = 0.0
	_player.play()


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


func is_playing() -> bool:
	return _player.playing


func _kill_tween() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
