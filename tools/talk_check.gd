# Talk check: for every townsfolk, how many ordering conversations they could
# have right now (on this save), and why the others are left out. Read-only:
# it never saves. Run as a scene (it needs the autoloads), with APPDATA pointed
# at a copy of the save.
extends Node


func _ready() -> void:
	await get_tree().process_frame
	var chef_id: String = Accounts.accounts[0]["id"] if not Accounts.accounts.is_empty() else ""
	print("TALK chef ", Accounts.get_account(chef_id).get("name", "?"), "  menu ", GameData.menu().map(func(d): return d["id"]))
	for person in GameData.townsfolk:
		var id: String = person["id"]
		var talk: Dictionary = person.get("talk", {})
		if talk.is_empty():
			print("TALK %-12s no talk block (arrival line, order line are the shared walk-in ones; never choices)" % id)
			continue
		var favorite: String = person.get("favorite_dish", "")
		var can_have := GameData.menu().any(func(d): return d["id"] == favorite)
		var words := TownsfolkTalk.context(id, chef_id, { "name": "dish" }, { "name": "drink" })
		var lines: Array = talk.get("order", [])
		var usable := 0
		var why: Array = []
		for line in lines:
			var reasons: Array = []
			if line.get("fav", false) and not can_have:
				reasons.append("fav %s not on menu" % favorite)
			if line.get("only", "") != "":
				reasons.append("only:" + String(line["only"]))
			var missing := {}
			for text in _texts(line):
				for m in RegEx.create_from_string(r"\[([a-z_]+)\]").search_all(TownsfolkTalk.fill(text, words)):
					missing[m.get_string(1)] = true
			if not missing.is_empty():
				reasons.append("unfilled " + str(missing.keys()))
			if line.get("choices", []).is_empty():
				reasons.append("NO CHOICES")
			var ok: bool = TownsfolkTalk._can_converse(id, chef_id, line, words) and (can_have or not line.get("fav", false))
			if ok:
				usable += 1
			if not reasons.is_empty():
				why.append(("ok " if ok else "OUT ") + String(line.get("text", "")).left(40) + "  <" + ", ".join(reasons) + ">")
		print("TALK %-12s order lines %d, usable now %d" % [id, lines.size(), usable])
		for w in why:
			print("        ", w)
	get_tree().quit()


func _texts(line: Dictionary) -> Array:
	var out := [String(line.get("text", ""))]
	for choice in line.get("choices", []):
		out.append(String(choice.get("text", "")))
		for reply in [choice, choice.get("familiar", {}), choice.get("misses", {}), choice.get("day", {})]:
			out.append(String(reply.get("reply", "")))
	return out
