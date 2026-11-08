# ChefReactions: the faces the chefs pull in play. Wherever something happens,
# game code calls react() with a trigger name, and data/appearance.json's
# "reactions" says which face (a face.expressions key) and for how long. To
# add one: a line there, and a react() call where it happens.
#
# Quick ones last a second or two, then the chef's own face is back (blinking
# never stops). A "hold" one (focused while cooking) stays until release(),
# with quick ones showing over it.
#
# Triggers now:
#   happy      perfect_dish, regular_stage_up, warm_reply_liked, star_earned
#              (a star given out at closing, the fifth included)
#   surprised  dish_burning, outburst (Amy, Hezzy), gasp (Jessie), and "fire"
#              ready for when there are fires
#   sad        customer_left_angry, rude_reply_hurt
#   focused    cooking (held through every close-up and the stir minigame)
class_name ChefReactions
extends RefCounted

const NEARBY := 6.0  # Meters: how close a chef has to be to react to something `at` a place.


# `trigger` on player `player_index`'s chef, or on every chef (-1); with `at`
# (a Vector3), only the chefs within NEARBY of it.
static func react(tree: SceneTree, trigger: String, player_index := -1, at: Variant = null) -> void:
	var reaction := _reaction(trigger)
	if reaction.is_empty():
		return
	for chef in chefs(tree, player_index, at):
		if reaction.get("hold", false):
			chef.face.hold(String(reaction["expression"]))
		else:
			chef.face.set_expression(String(reaction["expression"]), float(reaction.get("seconds", 1.5)))


# Lets go of a held trigger (e.g. "cooking") on that chef (or every chef: -1).
static func release(tree: SceneTree, trigger: String, player_index := -1) -> void:
	var reaction := _reaction(trigger)
	for chef in chefs(tree, player_index):
		if chef.face.held == String(reaction.get("expression", "")):
			chef.face.hold("")


# The chefs of player `player_index` (or everyone: -1), near `at` if given.
static func chefs(tree: SceneTree, player_index := -1, at: Variant = null) -> Array[ChefModel]:
	var found: Array[ChefModel] = []
	if tree == null:
		return found
	for node in tree.get_nodes_in_group(Player.GROUP):
		var player := node as Player
		if player == null or (player_index >= 0 and player.player_index != player_index):
			continue
		if at is Vector3 and Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length() > NEARBY:
			continue
		var chef := player.visual.get_node_or_null("Chef") as ChefModel
		if chef != null:
			found.append(chef)
	return found


static func _reaction(trigger: String) -> Dictionary:
	var reaction: Dictionary = Wardrobe.looks().get("reactions", {}).get(trigger, {})
	if reaction.is_empty():
		push_warning("No chef reaction \"%s\" in data/appearance.json" % trigger)
	return reaction
