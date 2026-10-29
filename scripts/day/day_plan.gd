# DayPlan: who comes in at each meal today. Planned once a day (GameState keeps
# it, and it's saved): each phase in data/day.json gets its walk_ins townsfolk,
# and today's regulars (VisitSchedule) are spread across the phases, each at a
# random spot in their phase's line. A plan is one list per phase of
# { "regular": id } or { "walk_in": true }. Pure logic.
class_name DayPlan
extends RefCounted


static func plan() -> Array:
	var phases: Array = GameData.day_settings.get("phases", [])
	var result := []
	for phase in phases:
		var walk_ins: Dictionary = phase.get("walk_ins", { "min": 2, "max": 3 })
		var entries := []
		for i in randi_range(int(walk_ins["min"]), int(walk_ins["max"])):
			entries.append({ "walk_in": true })
		result.append(entries)
	if result.is_empty():
		return result
	# Regulars to different meals while there are meals to go round.
	var order := range(result.size())
	order.shuffle()
	var regulars := VisitSchedule.choose()
	for i in regulars.size():
		var entries: Array = result[order[i % order.size()]]
		entries.insert(randi_range(0, entries.size()), { "regular": regulars[i] })
	return result
