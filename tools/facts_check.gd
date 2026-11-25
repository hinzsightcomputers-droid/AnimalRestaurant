extends Node

# Counts every recipe's cooking facts (at least 100, see CookFacts) and draws them
# all: each must come up once before any does again, then in a new order; steps'
# tips must name real steps. Prints PASS/FAIL per recipe:
#   godot --headless --path . res://tools/facts_check.tscn


func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CookFacts.PATH))
	for id: String in data["recipes"]:
		var recipe: CookRecipe = load("res://data/recipes/%s.tres" % id)
		var titles := recipe.steps.map(func(s): return s.title)
		var lost: Array = data["recipes"][id]["steps"].keys().filter(func(t): return not t in titles)
		var count := CookFacts.pool(id).size()
		GameState.facts_seen.erase(id)
		var first: Array[String] = []
		var second: Array[String] = []
		for i in count:
			first.append(CookFacts.next(id))
		for i in count:
			second.append(CookFacts.next(id))
		var once := {}
		for fact in first:
			once[fact] = true
		var good := count >= 100 and once.size() == count and first != second and lost.is_empty()
		print("FACTS CHECK %s %s: %d facts%s" % ["PASS" if good else "FAIL", id, count, "" if lost.is_empty() else ", no such step: %s" % [lost]])
	get_tree().quit()
