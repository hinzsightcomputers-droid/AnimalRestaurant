# CharacterAppearance: how one chef looks. Everyone shares one skeleton and one
# base body, so any of these can go with any other. Ids point into the
# Wardrobe (hair, clothes, accessories: data/wardrobe/) and into
# data/appearance.json (body shapes, face parts, colors). Kept on the chef's
# account as a small Dictionary (to_dict / from_dict), which is also all a
# co-op partner would need to see this chef. ChefModel builds it (ChefBuilder).
class_name CharacterAppearance
extends Resource

const FEATURES := ["eyes", "brows", "nose", "mouth"]  # Face parts, each moved and sized Mii-style.
const CLOTHES := ["top", "bottom", "dress", "shoes"]

@export var body_shape := "standard"
@export var skin_color := Color("#f1c7a0")
@export var hair_id := ""
@export var hair_color := Color("#5a3a22")
@export var eye_color := Color("#3b6ea5")
## feature -> { "id": String, "offset": Vector2 (face-canvas units, + is right
## and down), "scale": float }. See feature_id() and friends.
@export var features := {}
@export var face_paint: Array[String] = []
@export var top := ""
@export var bottom := ""
@export var dress := ""
@export var shoes := ""
@export var accessories: Array[String] = []  # Apron, hat, glasses, face accessory ids (one per slot).


func feature_id(feature: String) -> String:
	return String(features.get(feature, {}).get("id", ""))


func feature_offset(feature: String) -> Vector2:
	return features.get(feature, {}).get("offset", Vector2.ZERO)


func feature_scale(feature: String) -> float:
	return float(features.get(feature, {}).get("scale", 1.0))


func set_feature(feature: String, id := "", offset = null, feature_scale = null) -> void:
	var now: Dictionary = features.get_or_add(feature, { "id": "", "offset": Vector2.ZERO, "scale": 1.0 })
	if not id.is_empty():
		now["id"] = id
	if offset != null:
		now["offset"] = offset
	if feature_scale != null:
		now["scale"] = float(feature_scale)


# The item id worn in `slot` (hair, top, bottom, dress, shoes, apron, hat, glasses,
# face_accessory), or "".
func worn(slot: String) -> String:
	if slot == "hair":
		return hair_id
	if slot in CLOTHES:
		return get(slot)
	for id in accessories:
		if Wardrobe.get_item(id).get("slot", "") == slot:
			return id
	return ""


# Puts on a Wardrobe item in its slot, taking off whatever was there. A dress
# takes the place of a top and bottom, and the other way round.
func wear(item_id: String) -> void:
	var slot: String = Wardrobe.get_item(item_id).get("slot", "")
	if slot.is_empty():
		push_warning("No wardrobe item %s" % item_id)
		return
	take_off(slot)
	match slot:
		"hair":
			hair_id = item_id
		"dress":
			top = ""
			bottom = ""
			dress = item_id
		"top", "bottom":
			dress = ""
			set(slot, item_id)
		"shoes":
			shoes = item_id
		_:
			accessories.append(item_id)


func take_off(slot: String) -> void:
	if slot == "hair":
		hair_id = ""
	elif slot in CLOTHES:
		set(slot, "")
	else:
		var keep: Array[String] = []
		for id in accessories:
			if Wardrobe.get_item(id).get("slot", "") != slot:
				keep.append(id)
		accessories = keep


func toggle_face_paint(paint_id: String) -> void:
	if paint_id in face_paint:
		face_paint.erase(paint_id)
	else:
		face_paint.append(paint_id)


# Everything worn, hair first: the ids ChefBuilder puts on.
func worn_items() -> Array[String]:
	var ids: Array[String] = []
	for id in [hair_id, top, bottom, dress, shoes] + Array(accessories):
		if not String(id).is_empty():
			ids.append(id)
	return ids


func to_dict() -> Dictionary:
	var face := {}
	for feature in FEATURES:
		var offset := feature_offset(feature)
		face[feature] = { "id": feature_id(feature), "offset": [snappedf(offset.x, 0.001), snappedf(offset.y, 0.001)], "scale": snappedf(feature_scale(feature), 0.001) }
	var data := {
		"body": body_shape,
		"skin": "#" + skin_color.to_html(false),
		"hair": hair_id,
		"hair_color": "#" + hair_color.to_html(false),
		"eye_color": "#" + eye_color.to_html(false),
		"face_paint": Array(face_paint),
		"accessories": Array(accessories),
	}
	data.merge(face)
	for slot in CLOTHES:
		data[slot] = get(slot)
	return data


# From to_dict()'s Dictionary; anything missing comes from the default look.
static func from_dict(data: Dictionary) -> CharacterAppearance:
	var look := CharacterAppearance.new()
	var base: Dictionary = Wardrobe.looks().get("default", {}).duplicate(true)
	base.merge(data, true)
	look.body_shape = String(base.get("body", "standard"))
	look.skin_color = Color.from_string(String(base.get("skin", "")), look.skin_color)
	look.hair_id = String(base.get("hair", ""))
	look.hair_color = Color.from_string(String(base.get("hair_color", "")), look.hair_color)
	look.eye_color = Color.from_string(String(base.get("eye_color", "")), look.eye_color)
	for feature in FEATURES:
		var part = base.get(feature, {})
		if part is Dictionary:
			var at: Array = part.get("offset", [0, 0])
			look.set_feature(feature, String(part.get("id", "")), Vector2(float(at[0]), float(at[1])) if at.size() >= 2 else Vector2.ZERO, float(part.get("scale", 1.0)))
	look.face_paint.assign(Array(base.get("face_paint", [])).map(func(id): return String(id)))
	look.accessories.assign(Array(base.get("accessories", [])).map(func(id): return String(id)))
	for slot in CLOTHES:
		look.set(slot, String(base.get(slot, "")))
	return look


static func default_look() -> CharacterAppearance:
	return from_dict({})


func copy() -> CharacterAppearance:
	return from_dict(to_dict())
