# Stages: the restaurant's big upgrades (data/stages.json). GameState.stage is
# the one built; buying the next (its star rating and fee met) sets
# GameState.stage_building, and the crew finishes it overnight (begin_day).
# StageLayout builds what a stage changes in the room.
class_name Stages
extends RefCounted

const PATH := "res://data/stages.json"

static var _data: Dictionary = {}


static func all() -> Array:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else { "stages": [] }
	return _data.get("stages", [])


# The stage's record, or {} if there's no such stage.
static func info(stage: int) -> Dictionary:
	for record in all():
		if int(record.get("stage", 0)) == stage:
			return record
	return {}


# The one after what's built (or being built), or {} at the last.
static func next() -> Dictionary:
	return info(maxi(GameState.stage, GameState.stage_building) + 1)


# Why the next stage can't be bought right now, or "" if it can.
static func why_not(record: Dictionary) -> String:
	if record.is_empty():
		return "The restaurant's as big as it gets."
	if GameState.stage_building > GameState.stage:
		return "The crew's already booked for tonight."
	if not bool(record.get("built", false)):
		return "Coming in a later update."
	if GameState.stars < int(record.get("stars", 99)):
		return "Needs %d stars." % int(record.get("stars", 0))
	if GameState.money < int(record.get("fee", 0)):
		return "$%d (need $%d more)" % [int(record.get("fee", 0)), int(record.get("fee", 0)) - GameState.money]
	return ""


# How many meters the dining room has grown to the left, all stages built so far.
static func grown_left() -> float:
	var total := 0.0
	for stage in range(2, GameState.stage + 1):
		total += float(info(stage).get("grow_left", 0.0))
	return total


# What the built stages add to the customer cap (ArrivalPacing.bonus).
static func arrival_bonus() -> int:
	var total := 0
	for stage in range(2, GameState.stage + 1):
		total += int(info(stage).get("arrival_bonus", 0))
	return total
