# DayManager: runs the restaurant day. Counts down while open, sending each of
# today's scheduled regulars in when their time comes, then closes (no new
# customers). Once the last customer has left (and every delivery is picked up),
# any big moment scene due tonight plays (ScenePlayer), then the day ends: the
# game pauses and `day_ended` carries the summary for the summary screen.
class_name DayManager
extends Node

signal day_closed
signal day_ended(summary: Dictionary)

@export var customer_manager: CustomerManager
@export var delivery_manager: DeliveryManager
@export var scene_player: ScenePlayer
@export var day_length_seconds := 180.0

var time_left := 0.0
var is_open := true
var _has_ended := false
var _sent_regulars: Array[String] = []  # Today's scheduled regulars already sent in.


func _ready() -> void:
	time_left = day_length_seconds
	GameState.begin_shift()
	GameState.todays_visits()  # Plan today's regulars now, so the debug panel can show them.
	Music.play_hour_themes()  # In the restaurant the music follows the real hour (carries on across shifts).


func _process(delta: float) -> void:
	if _has_ended:
		return
	if is_open:
		time_left = maxf(time_left - delta, 0.0)
		_send_due_regulars()
		if time_left <= 0.0:
			_close()
	elif not customer_manager.has_customers() and not _deliveries_waiting():
		if scene_player != null and scene_player.play_due():
			return  # Wait for tonight's big moment.
		_end_day()


# Called by the summary screen's button. The shift was already counted (and
# saved) when the day ended.
func start_next_day() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()  # Fresh restaurant; GameState (an autoload) keeps money and the date.


# How far through the open day we are: 0 at opening, 1 at closing.
func progress() -> float:
	return 1.0 - time_left / day_length_seconds if day_length_seconds > 0.0 else 1.0


func _deliveries_waiting() -> bool:
	return delivery_manager != null and delivery_manager.has_deliveries()


func _send_due_regulars() -> void:
	for visit in GameState.todays_visits():
		if visit["at"] <= progress() and not visit["id"] in _sent_regulars:
			_sent_regulars.append(visit["id"])
			customer_manager.send_regular(visit["id"])


func _close() -> void:
	is_open = false
	customer_manager.close()
	GameEvents.announce("Closing time! Finish serving your last customers.")
	day_closed.emit()


func _end_day() -> void:
	_has_ended = true
	get_tree().paused = true
	var summary := DaySummary.build(GameState.services_today, GameState.chef_actions_today)
	summary["date"] = GameState.date
	summary["shift"] = GameState.shift
	GameState.finish_shift()  # Count the shift + save.
	day_ended.emit(summary)
