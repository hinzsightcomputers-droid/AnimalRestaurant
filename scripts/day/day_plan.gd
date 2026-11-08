# DayPlan: which regulars come in at each meal today. Planned once a day
# (GameState keeps it, and it's saved): today's regulars (VisitSchedule) each go
# in a meal their visit_window covers (ArrivalPacing.meal_for), else wherever
# there's room, and the critic in any meal when due (see Rating). A plan is one
# list per meal of { "regular": id } or { "critic": true }; townsfolk aren't in
# it, they walk in by themselves at the meal's pace (ArrivalPacing). Pure logic.
class_name DayPlan
extends RefCounted


static func plan() -> Array:
	var result := []
	for _phase in GameData.day_settings.get("phases", []):
		result.append([])
	if result.is_empty():
		return result
	for regular_id in VisitSchedule.choose():
		result[ArrivalPacing.meal_for(regular_id, result.size())].append({ "regular": regular_id })
	if Rating.critic_due():
		result.pick_random().append({ "critic": true })
	return result
