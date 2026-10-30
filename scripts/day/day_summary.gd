# DaySummary: turns the list of today's services (from GameState) into totals
# for the end-of-day screen. Pure logic, no display.
class_name DaySummary
extends RefCounted


# `chef_actions`: account id -> { chopped, cooked, served, cleaned } (from GameState).
static func build(services: Array[Dictionary], chef_actions: Dictionary = {}) -> Dictionary:
	var summary := {
		"chefs": chef_actions.duplicate(true),
		"top_server": _top_server(chef_actions),  # Account id of who served most, or "".
		"customers_served": services.size(),
		"earnings": 0,
		"tips": 0,              # Money paid above the menu price.
		"average_quality": 0.0,
		"average_wait": 0.0,
		"reaction_counts": {},  # reaction id -> count
		"top_dish": "",         # dish id ordered most often
		"best_streak": 0,       # the longest run of good serves (ServiceStreak)
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
		summary["best_streak"] = maxi(summary["best_streak"], int(service.get("streak", 0)))  # Older saves have none.

	summary["average_quality"] /= services.size()
	summary["average_wait"] /= services.size()

	var best_count := 0
	for dish_id in dish_counts:
		if dish_counts[dish_id] > best_count:
			best_count = dish_counts[dish_id]
			summary["top_dish"] = dish_id
	return summary


# Who served the most customers (first found wins a tie), or "" if nobody served.
static func _top_server(chef_actions: Dictionary) -> String:
	var best := ""
	var best_count := 0
	for account_id in chef_actions:
		var count: int = chef_actions[account_id].get("served", 0)
		if count > best_count:
			best = account_id
			best_count = count
	return best
