# DayManager: runs the restaurant day. Counts down while open, then closes
# (no new customers). Once the last customer has left, the day ends: the game
# pauses and `day_ended` carries the summary for the summary screen.
class_name DayManager
extends Node

signal day_closed
signal day_ended(summary: Dictionary)

@export var customer_manager: CustomerManager
@export var day_length_seconds := 180.0

var time_left := 0.0
var is_open := true
var _has_ended := false


func _ready() -> void:
	time_left = day_length_seconds


func _process(delta: float) -> void:
	if _has_ended:
		return
	if is_open:
		time_left = maxf(time_left - delta, 0.0)
		if time_left <= 0.0:
			_close()
	elif not customer_manager.has_customers():
		_end_day()


# Called by the summary screen's button.
func start_next_day() -> void:
	GameState.start_next_day()
	get_tree().paused = false
	get_tree().reload_current_scene()  # Fresh restaurant; GameState (an autoload) keeps money and day.


func _close() -> void:
	is_open = false
	customer_manager.close()
	GameEvents.announce("Closing time! Finish serving your last customers.")
	day_closed.emit()


func _end_day() -> void:
	_has_ended = true
	get_tree().paused = true
	day_ended.emit(DaySummary.build(GameState.services_today))
