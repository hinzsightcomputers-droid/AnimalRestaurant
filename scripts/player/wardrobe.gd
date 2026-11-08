# Wardrobe: everything a chef can wear, one file per item in data/wardrobe/
# (see _template.json there), plus the rest of the look in data/appearance.json
# (base body, body shapes, face parts, colors, the default chef).
#
# An item: { id, name, slot, placeholder?, unlock?, hidden?, mesh, parts,
# hides, hat_variant, tint? }
#   slot         hair, top, bottom, dress, shoes, hat, glasses, face_accessory
#   mesh         skinned to the shared skeleton: { "scene": a .glb/.tscn,
#                "nodes": [mesh names in it] } (no "nodes": every mesh in it)
#   parts        or simple shapes held by a bone (placeholders, glasses):
#                [{ "sphere"|"box"|"cylinder"|"torus": size, "at": [x,y,z],
#                "scale"?, "rotation"? (degrees), "bone"? (default head),
#                "color"? (else the hair color for hair) }]
#   hides        base body regions it covers (torso, arm_left, arm_right,
#                leg_left, leg_right, feet), so they don't poke through
#   hat_variant  hair only: the hair id to wear under a hat instead
#   unlock       only wearable once GameState.unlocks has it
#   hidden       not offered in the customizer (e.g. hat variants)
#   placeholder  stand-in art, to replace with the real thing
class_name Wardrobe
extends RefCounted

const ITEMS_DIR := "res://data/wardrobe"
const LOOKS_PATH := "res://data/appearance.json"
const SLOTS := ["hair", "top", "bottom", "dress", "shoes", "hat", "glasses", "face_accessory"]
const ACCESSORY_SLOTS := ["hat", "glasses", "face_accessory"]
const REGIONS := ["torso", "arm_left", "arm_right", "leg_left", "leg_right", "feet"]

static var _items := {}
static var _looks := {}


static func items() -> Dictionary:
	if _items.is_empty():
		for file in DirAccess.get_files_at(ITEMS_DIR):
			if not file.ends_with(".json") or file.begins_with("_"):
				continue
			var item = JSON.parse_string(FileAccess.get_file_as_string(ITEMS_DIR.path_join(file)))
			if item is Dictionary and item.has("id") and item.get("slot", "") in SLOTS:
				_items[item["id"]] = item
			else:
				push_warning("Wardrobe item %s needs an id and a slot" % file)
	return _items


static func get_item(id: String) -> Dictionary:
	return items().get(id, {})


# The items for `slot` someone can pick, by name.
static func of_slot(slot: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in items().values():
		if item["slot"] == slot and not item.get("hidden", false) and is_unlocked(item):
			result.append(item)
	result.sort_custom(func(a, b): return String(a.get("name", a["id"])) < String(b.get("name", b["id"])))
	return result


static func is_unlocked(item: Dictionary) -> bool:
	var unlock: String = item.get("unlock", "")
	return unlock.is_empty() or unlock in GameState.unlocks


static func looks() -> Dictionary:
	if _looks.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(LOOKS_PATH))
		_looks = parsed if parsed is Dictionary else {}
	return _looks


# The choices for a face part ("eyes", "brows", "nose", "mouth", "face_paint"):
# [{ id, name, texture, ... }].
static func face_parts(kind: String) -> Array:
	return looks().get("face", {}).get("parts", {}).get(kind, [])


static func face_part(kind: String, id: String) -> Dictionary:
	for part in face_parts(kind):
		if part["id"] == id:
			return part
	return {}


static func body_shape(id: String) -> Dictionary:
	for shape in looks().get("body_shapes", []):
		if shape["id"] == id:
			return shape
	return {}


# Every placeholder: item and face part ids still waiting for real art.
static func placeholders() -> Array[String]:
	var ids: Array[String] = []
	for item in items().values():
		if item.get("placeholder", false):
			ids.append(item["id"])
	for kind in looks().get("face", {}).get("parts", {}):
		for part in face_parts(kind):
			if part.get("placeholder", false):
				ids.append("%s/%s" % [kind, part["id"]])
	return ids
