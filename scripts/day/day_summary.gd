# DaySummary: turns the list of today's services (from GameState) into totals
# for the end-of-day screen. Pure logic, no display.
class_name DaySummary
extends RefCounted


static func build(services: Array[Dictionary]) -> Dictionary:
	var summary := {
		"customers_served": services.size(),
		"earnings": 0,
		"tips": 0,              # Money paid above the menu price.
		"average_quality": 0.0,
		"average_wait": 0.0,
		"reaction_counts": {},  # reaction id -> count
		"top_dish": "",         # dish id ordered most often
	}
	if services.is_empty():
		return summary

	var dish_counts := {}
	for service in services:
		summary["earnings"] += service["payment"]
		summary["tips"] += maxi(0, service["payment"] - service["price"])
		summary["average_quality"] += service["quality"]
		summary["average_wait"] += service["wait_seconds"]
		var reaction: String = service["reaction"]
		summary["reaction_counts"][reaction] = summary["reaction_counts"].get(reaction, 0) + 1
		dish_counts[service["dish"]] = dish_counts.get(service["dish"], 0) + 1

	summary["average_quality"] /= services.size()
	summary["average_wait"] /= services.size()

	var best_count := 0
	for dish_id in dish_counts:
		if dish_counts[dish_id] > best_count:
			best_count = dish_counts[dish_id]
			summary["top_dish"] = dish_id
	return summary
