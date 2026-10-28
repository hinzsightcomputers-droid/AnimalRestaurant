# CookingMinigame: pure timing logic, no input or visuals.
# A marker slides back and forth between -1 and 1. Each press() scores how close
# it is to the center (the sweet spot). After HITS_NEEDED presses, the average
# score is the dish quality from 0 to 1.
class_name CookingMinigame
extends RefCounted

signal hit_registered(score: float)
signal finished(quality: float)

const HITS_NEEDED := 3
const SWEET_SPOT_HALF_WIDTH := 0.15  # Inside this distance from center = full score.
const BASE_SPEED := 1.6              # Marker speed (bar widths per second) for cook_speed 1.0.
const SPEED_UP_PER_HIT := 1.1        # Each stir makes the next one a little faster.

var marker := -1.0   # Current marker position, -1 (left) to 1 (right).
var speed: float
var scores: Array[float] = []
var quality := 0.0
var is_finished := false

var _direction := 1.0


func _init(dish: Dictionary) -> void:
	speed = BASE_SPEED * float(dish.get("cook_speed", 1.0)) * GameState.upgrade_multiplier("stir_speed")


func update(delta: float) -> void:
	if is_finished:
		return
	marker += _direction * speed * delta
	# Bounce off the ends of the bar.
	if marker >= 1.0:
		marker = 1.0
		_direction = -1.0
	elif marker <= -1.0:
		marker = -1.0
		_direction = 1.0


func press() -> void:
	if is_finished:
		return

	var score := score_at(marker)
	scores.append(score)
	hit_registered.emit(score)

	if scores.size() >= HITS_NEEDED:
		var total := 0.0
		for s in scores:
			total += s
		quality = total / scores.size()
		is_finished = true
		finished.emit(quality)
	else:
		speed *= SPEED_UP_PER_HIT


# 1.0 inside the sweet spot, falling to 0.0 at the ends of the bar.
static func score_at(position: float) -> float:
	var distance := absf(position)
	if distance <= SWEET_SPOT_HALF_WIDTH:
		return 1.0
	return clampf(1.0 - (distance - SWEET_SPOT_HALF_WIDTH) / (1.0 - SWEET_SPOT_HALF_WIDTH), 0.0, 1.0)


static func quality_label(value: float) -> String:
	if value >= 0.9:
		return "Perfect"
	if value >= 0.7:
		return "Great"
	if value >= 0.4:
		return "Okay"
	return "Burnt"
