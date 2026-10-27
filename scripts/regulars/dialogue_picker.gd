# DialoguePicker: chooses what a regular says. Looks through data/dialogue.json
# for lines of the given event whose conditions all match the context, takes the
# highest priority (random among ties), and fills in {placeholders} like {player}.
class_name DialoguePicker
extends RefCounted


static func pick(event: String, context: Dictionary) -> String:
	var best: Array = []
	var best_priority := -INF
	for line in GameData.dialogue:
		if line["event"] != event or not _all_conditions_met(line.get("conditions", {}), context):
			continue
		var priority: float = line.get("priority", 0)
		if priority > best_priority:
			best_priority = priority
			best = [line]
		elif priority == best_priority:
			best.append(line)

	if best.is_empty():
		return ""
	var text: String = best.pick_random()["text"]
	return text.format(context)


static func _all_conditions_met(conditions: Dictionary, context: Dictionary) -> bool:
	for key in conditions:
		if not _condition_met(key, conditions[key], context):
			return false
	return true


static func _condition_met(key: String, want: Variant, context: Dictionary) -> bool:
	var has_visited: bool = context.get("times_visited", 0) > 0
	match key:
		"regular":
			return context.get("regular", "") == want
		"personality":
			return want in context.get("personality", [])
		"first_visit":
			return (not has_visited) == want
		"min_visits":
			return context.get("times_visited", 0) >= want
		"max_visits":
			return context.get("times_visited", 0) <= want
		"min_relationship":
			return context.get("relationship", 0) >= want
		"max_relationship":
			return context.get("relationship", 0) <= want
		"last_quality_min":
			return has_visited and context.get("last_quality", -1.0) >= want
		"last_quality_max":
			return has_visited and context.get("last_quality", -1.0) >= 0.0 and context.get("last_quality", -1.0) <= want
		"knows_player_name", "returned_after_away", "ordered_favorite", "learned_name":
			return context.get(key, false) == want
		"reaction":
			return context.get("reaction", "") == want
	push_warning("Unknown dialogue condition: %s" % key)
	return false
