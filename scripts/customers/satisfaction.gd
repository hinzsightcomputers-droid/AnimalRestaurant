# Satisfaction: turns cooking quality (and the drink) into a satisfaction score (0..1) and
# picks a reaction tier. Waiting never counts against it: quick service just
# earns a small bonus. All the numbers come from data/reactions.json.
class_name Satisfaction
extends RefCounted


# The dish's quality, plus fast_service_bonus if it came within
# fast_service_seconds (Comfy Cushions add to that).
static func calculate(quality: float, wait_seconds: float) -> float:
	return clampf(quality + fast_bonus(wait_seconds), 0.0, 1.0)


static func fast_bonus(wait_seconds: float) -> float:
	return GameData.reactions.get("fast_service_bonus", 0.05) if wait_seconds <= fast_seconds() else 0.0


# How quick a serve has to be for fast_bonus.
static func fast_seconds() -> float:
	return (float(GameData.reactions.get("fast_service_seconds", 40.0)) + GameState.upgrade_bonus("patient_seconds")) * GameState.difficulty_value("patience")


# The best reaction tier whose min_satisfaction is reached.
static func reaction_for(satisfaction: float) -> Dictionary:
	var best: Dictionary = {}
	for reaction in GameData.reactions.get("reactions", []):
		if satisfaction >= reaction["min_satisfaction"]:
			if best.is_empty() or reaction["min_satisfaction"] > best["min_satisfaction"]:
				best = reaction
	return best


# What a dish and drink cost before any tip: their base_price times the pay scale.
static func price_of(dish: Dictionary, drink: Dictionary = {}) -> float:
	return (float(dish.get("base_price", 0)) + float(drink.get("base_price", 0))) * GameState.pay_scale()


# What the customer pays for a dish, tip included.
static func payment_for(dish: Dictionary, reaction: Dictionary) -> int:
	var price := price_of(dish)
	var percent: float = reaction.get("payment_percent", 100)
	if percent > 100.0:
		percent += GameState.upgrade_bonus("tip_percent")  # Tip Jar: bigger tips only.
	return roundi(price * percent / 100.0)


# What their drink adds to how they feel: right_drink_mood for the one they
# ordered, wrong_drink_mood for something else, nothing without one
# (data/drink_kitchen.json).
static func drink_mood(ordered: Dictionary, served: Dictionary) -> float:
	if served.is_empty():
		return 0.0
	var right: bool = served.get("id", "") == ordered.get("id", "")
	return float(GameData.drink_settings.get("right_drink_mood" if right else "wrong_drink_mood", 0.0))


# What a seated customer pays: the dish and the drink, tip included (and any
# extra for a serving streak, ServiceStreak).
static func bill_for(dish: Dictionary, drink: Dictionary, reaction: Dictionary, streak_percent := 0.0) -> int:
	var price := price_of(dish, drink)
	var percent: float = reaction.get("payment_percent", 100)
	if percent > 100.0:
		percent += GameState.upgrade_bonus("tip_percent")  # Tip Jar: bigger tips only.
	return roundi(price * (percent + streak_percent) / 100.0)
