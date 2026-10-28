# DialoguePicker: chooses what a regular says. Looks through data/dialogue.json
# for lines of the given event whose conditions all match the context, takes the
# highest priority (random among ties), and fills in {placeholders} like {player}
# and the character files' [tokens] like [name].
class_name DialoguePicker
extends RefCounted

# [token] in a character's line -> the dialogue_context key that fills it in.
# Tokens not listed here use the key of the same name (e.g. [dish], [soup]).
const TOKENS := {
	"name": "player",
	"wrong name": "wrong_name",
}


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
	return fill(text, context)


# {key} and [token] placeholders -> values from the context.
static func fill(text: String, context: Dictionary) -> String:
	var result := text.format(context)
	var regex := RegEx.create_from_string("\\[([a-z_ ]+)\\]")
	for found in regex.search_all(result):
		var key: String = TOKENS.get(found.get_string(1), found.get_string(1))
		if context.has(key):
			result = result.replace(found.get_string(), str(context[key]))
	return result


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
		"stage":
			return context.get("stage", 0) == want
		"min_stage":
			return context.get("stage", 0) >= want
		"max_stage":
			return context.get("stage", 0) <= want
		"knows_player_name", "returned_after_away", "ordered_favorite", "learned_name", "new_chef_for_them", "has_rude_line":
			return context.get(key, false) == want
		"min_known_here":
			return context.get("known_here_count", 0) >= want
		"reaction":
			return context.get("reaction", "") == want
	push_warning("Unknown dialogue condition: %s" % key)
	return false
