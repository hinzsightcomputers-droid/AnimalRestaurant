# GameState (autoload): the restaurant's progress. Money, the current day, what
# each regular remembers, and a record of every customer served today (for the
# end-of-day summary and saving).
extends Node

signal money_changed(money: int)

var money := 0
var day := 1
var player_name := "Chef"  # What regulars call you once they learn your name.
# One entry per served customer today:
# { species, regular, dish, price, quality, wait_seconds, satisfaction, reaction, payment }
var services_today: Array[Dictionary] = []
# Regular id -> that regular's current record (same fields as data/regulars.json).
var regulars: Dictionary = {}


func _ready() -> void:
	reset_regulars()


# Back to the starting regulars from data/regulars.json.
func reset_regulars() -> void:
	regulars.clear()
	for record in GameData.regulars:
		regulars[record["id"]] = record.duplicate(true)


func start_next_day() -> void:
	day += 1
	services_today.clear()


func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)


func record_service(service: Dictionary) -> void:
	services_today.append(service)


func earnings_today() -> int:
	var total := 0
	for service in services_today:
		total += service["payment"]
	return total
