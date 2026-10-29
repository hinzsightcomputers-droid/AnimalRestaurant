# VisitSchedule: decides which regulars come in on today's real date, and when.
# Only a few come each date (regulars_per_day in data/regulars.json), picked at
# random but weighted toward whoever has gone the most real days without
# visiting. Regulars who don't visit in person (Withdrawn, Gone, referral-only)
# are never picked. Pure logic: DayPlan spreads them across the day's meals.
class_name VisitSchedule
extends RefCounted

const NEVER_VISITED_DAYS := 7  # Someone new counts as this many days away.


# Today's regulars: a few ids, in random order.
static func choose() -> Array[String]:
	var settings := GameData.regular_settings
	var per_day: Dictionary = settings.get("regulars_per_day", { "min": 2, "max": 3 })
	var weights := {}
	for id in GameState.regulars:
		var record: Dictionary = GameState.regulars[id]
		if RegularMemory.visits_in_person(record) and not RegularMemory.visited_today(record):
			var days := RegularMemory.days_away(record, GameClock.now_unix())
			weights[id] = (days if days >= 0 else NEVER_VISITED_DAYS) + 1

	var chosen: Array[String] = []
	var count := mini(randi_range(int(per_day["min"]), int(per_day["max"])), weights.size())
	for i in count:
		var id := _weighted_pick(weights)
		chosen.append(id)
		weights.erase(id)
	chosen.shuffle()
	return chosen


# An id from { id: weight }, more likely the bigger its weight.
static func _weighted_pick(weights: Dictionary) -> String:
	var total := 0.0
	for id in weights:
		total += weights[id]
	var roll := randf() * total
	for id in weights:
		roll -= weights[id]
		if roll <= 0.0:
			return id
	return weights.keys().back()
