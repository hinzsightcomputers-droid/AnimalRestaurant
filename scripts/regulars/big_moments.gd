# BigMoments: the rules for each regular's big moment scene (data/scenes.json):
# which one is due tonight, and what finishing it does. A scene is due when
# its regular meets its "conditions" (checked like a dialogue line's, e.g.
# relationship 85+ and 3 visits at stage 4) and isn't Gone; each plays once,
# because finishing it sets the flags in its "done" (big_moment_done). Its
# rewards go in GameState.unlocks. ScenePlayer plays it; DayManager starts it at
# closing once the last customer has left.
class_name BigMoments
extends RefCounted


# The scene to play at closing tonight, or {} if none. The debug panel's pick
# comes first, whatever its conditions.
static func due() -> Dictionary:
	if not GameState.forced_scene.is_empty():
		return GameData.get_scene(GameState.forced_scene)
	for scene in GameData.scenes:
		if is_ready(scene):
			return scene
	return {}


static func is_ready(scene: Dictionary) -> bool:
	var record: Dictionary = GameState.regulars.get(scene.get("regular", ""), {})
	if record.is_empty() or Redemption.is_gone(record) or Redemption.goodbye_due(record):
		return false
	return DialoguePicker.conditions_met(scene.get("conditions", {}), RegularMemory.dialogue_context(record, ""))


# The scene is over: its flags are set (so it never plays again) and its rewards unlocked.
static func finish(scene: Dictionary) -> void:
	var record: Dictionary = GameState.regulars.get(scene.get("regular", ""), {})
	var done: Dictionary = scene.get("done", {})
	var flags: Dictionary = done.get("set", {})
	for key in flags:
		record[key] = flags[key]
	for reward in done.get("unlock", []):
		if not reward in GameState.unlocks:
			GameState.unlocks.append(reward)
			GameEvents.announce("Unlocked: %s!" % reward_name(reward))
	if GameState.forced_scene == scene.get("id", ""):
		GameState.forced_scene = ""


static func reward_name(reward_id: String) -> String:
	return GameData.scene_settings.get("reward_names", {}).get(reward_id, reward_id)
