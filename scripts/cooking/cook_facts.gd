# CookFacts: the chef's tips in the corner of a close-up (data/cooking_facts.json).
# A recipe's facts are its own and those of its topics (eggs, flour, knives...),
# over a hundred each. They come up shuffled, every one before any comes round
# again, and the save remembers how far each recipe has got (GameState.facts_seen).
# A step's own tip shows the first time that step comes up, then only now and then.
class_name CookFacts
extends RefCounted

const PATH := "res://data/cooking_facts.json"
const TIP_AGAIN := 0.2  # How often a step's tip shows once it's been seen.

static var _data := {}


# All of a recipe's facts, its own first.
static func pool(recipe_id: String) -> Array[String]:
	var entry: Dictionary = _all().get("recipes", {}).get(recipe_id, {})
	var facts: Array[String] = []
	facts.assign(entry.get("facts", []))
	for topic: String in entry.get("topics", []):
		for fact: String in _all().get("topics", {}).get(topic, []):
			if not fact in facts:
				facts.append(fact)
	return facts


# The recipe's next fact ("" if it has none).
static func next(recipe_id: String) -> String:
	var facts := pool(recipe_id)
	if facts.is_empty():
		return ""
	var seen := int(GameState.facts_seen.get(recipe_id, 0))
	GameState.facts_seen[recipe_id] = seen + 1
	var random := RandomNumberGenerator.new()  # The same shuffle every time, until it's all been seen.
	random.seed = hash("%s %d" % [recipe_id, seen / facts.size()])
	for i in range(facts.size() - 1, 0, -1):
		var j := random.randi_range(0, i)
		var swapped := facts[i]
		facts[i] = facts[j]
		facts[j] = swapped
	return facts[seen % facts.size()]


# A step's own tip, if it's to show this time ("" if not).
static func tip(recipe_id: String, step: String) -> String:
	var text: String = _all().get("recipes", {}).get(recipe_id, {}).get("steps", {}).get(step, "")
	var key := "%s/%s" % [recipe_id, step]
	if text.is_empty() or GameState.facts_seen.has(key) and randf() >= TIP_AGAIN:
		return ""
	GameState.facts_seen[key] = 1
	return text


static func _all() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_data = parsed
	return _data
