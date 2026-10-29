# Satisfaction: turns cooking quality and wait time into a satisfaction score
# (0..1) and picks a reaction tier. All the numbers come from data/reactions.json.
class_name Satisfaction
extends RefCounted


# 1.0 = perfect food served quickly, 0.0 = burnt food after a very long wait.
static func calculate(quality: float, wait_seconds: float) -> float:
	var config := GameData.reactions
	var quality_weight: float = config.get("quality_weight", 0.7)
	var wait_weight: float = config.get("wait_weight", 0.3)
	return clampf(quality * quality_weight + wait_score(wait_seconds) * wait_weight, 0.0, 1.0)


# 1.0 up to patient_seconds, then drops to 0.0 at max_wait_seconds.
static func wait_score(wait_seconds: float) -> float:
	var config := GameData.reactions
	var extra_patience := GameState.upgrade_bonus("patient_seconds")  # Comfy Cushions.
	var patient: float = config.get("patient_seconds", 40.0) + extra_patience
	var max_wait: float = config.get("max_wait_seconds", 100.0) + extra_patience
	if wait_seconds <= patient:
		return 1.0
	return clampf(1.0 - (wait_seconds - patient) / (max_wait - patient), 0.0, 1.0)


# The best reaction tier whose min_satisfaction is reached.
static func reaction_for(satisfaction: float) -> Dictionary:
	var best: Dictionary = {}
	for reaction in GameData.reactions.get("reactions", []):
		if satisfaction >= reaction["min_satisfaction"]:
			if best.is_empty() or reaction["min_satisfaction"] > best["min_satisfaction"]:
				best = reaction
	return best


# What the customer pays for a dish, tip included.
static func payment_for(dish: Dictionary, reaction: Dictionary) -> int:
	var price: float = dish.get("base_price", 0)
	var percent: float = reaction.get("payment_percent", 100)
	if percent > 100.0:
		percent += GameState.upgrade_bonus("tip_percent")  # Tip Jar: bigger tips only.
	return roundi(price * percent / 100.0)
