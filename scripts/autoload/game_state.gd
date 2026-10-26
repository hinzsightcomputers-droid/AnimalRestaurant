# GameState (autoload): the restaurant's progress. Money, the current day, and a
# record of every customer served today (for the end-of-day summary and saving).
extends Node

signal money_changed(money: int)

var money := 0
var day := 1
# One entry per served customer today:
# { species, dish, quality, wait_seconds, satisfaction, reaction, payment }
var services_today: Array[Dictionary] = []


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
