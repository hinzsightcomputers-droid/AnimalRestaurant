# PassCounter: a spot on the low kitchen wall where anyone can set down what
# they're carrying, and anyone on either side can pick it up. Lets one player
# cook while another serves. Holds up to SLOTS things side by side. From the
# kitchen side a press puts down first; from the dining-room side it picks up
# first, as many as the chef's hands (and tray) can take.
class_name PassCounter
extends Station

signal held_item_changed(item: RefCounted)

const SLOTS := 3
const SLOT_STEP := 0.43  # Meters between the spots along the counter.

# The first spot's thing (shown by $HeldItemDisplay); the others are in _slots.
var held_item: RefCounted = null

var _slots: Array = []  # The holders of every spot: this counter, then PassSlots.

# The second use spot, on the dining-room side ($Interactable is the kitchen side).
@onready var dining_side: Interactable = $InteractableDining


# One more spot on the counter, with its own HeldItemDisplay.
class PassSlot extends Node3D:
	signal held_item_changed(item: RefCounted)
	var held_item: RefCounted = null


func _ready() -> void:
	super._ready()
	dining_side.interacted.connect(_use.bind(true))
	interactable.prompt_for_player = _prompt_for.bind(false)
	dining_side.prompt_for_player = _prompt_for.bind(true)
	_slots = [self]
	var display: Node3D = $HeldItemDisplay
	for i in range(1, SLOTS):
		var slot := PassSlot.new()
		slot.name = "Slot%d" % i
		slot.position.x = SLOT_STEP * (-1.0 if i % 2 == 1 else 1.0) * ceili(i / 2.0)
		add_child(slot)
		var plate: Node3D = display.plate.duplicate()
		var crate: Node3D = display.crate.duplicate()
		slot.add_child(plate)
		slot.add_child(crate)
		var copy: Node3D = display.duplicate()
		copy.holder = slot
		copy.plate = plate
		copy.food = plate.get_node("Food")
		copy.crate = crate
		copy.crate_contents = crate.get_node("Contents")
		slot.add_child(copy)
		_slots.append(slot)
	_show_labels()


# Everything on the counter, first spot first.
func items() -> Array:
	return _slots.map(func(s): return s.held_item).filter(func(item): return item != null)


func has_items() -> bool:
	return not items().is_empty()


# Whether the plate for `order` is waiting here.
func holds_order(order: Order) -> bool:
	return items().any(func(item): return item is CookedDish and item.order == order)


func _free_slot():
	for slot in _slots:
		if slot.held_item == null:
			return slot
	return null


# What a press does for this player from this side: "Put down", "Pick up" or "".
func _prompt_for(player_index: int, dining: bool) -> String:
	var player := Player.find(get_tree(), player_index)
	if player == null:
		return ""
	var can_put := player.held_item != null and _free_slot() != null
	var can_pick := items().any(func(item): return player.can_take(item))
	if dining and can_pick:
		return "Pick up"
	if can_put:
		return "Put down"
	return "Pick up" if can_pick else ""


func _on_interacted(player_index: int) -> void:
	_use(player_index, false)


func _use(player_index: int, dining: bool) -> void:
	var player := Player.find(get_tree(), player_index)
	if player == null:
		return
	match _prompt_for(player_index, dining):
		"Put down":
			var slot = _free_slot()
			_set_slot(slot, player.held_item)
			player.set_held_item(null)  # The next thing on their tray comes to hand.
		"Pick up":
			for slot in _slots:  # As many as they can carry.
				if slot.held_item != null and player.can_take(slot.held_item):
					player.take(slot.held_item)
					_set_slot(slot, null)
		_:
			return
	_play_bounce()
	used.emit(self, player_index)


func _set_slot(slot, item: RefCounted) -> void:
	slot.held_item = item
	slot.held_item_changed.emit(item)
	_show_labels()


# One label for the whole counter (the first spot's), listing what's on it,
# rather than one per plate running into each other.
func _show_labels() -> void:
	var lines := []
	for slot in _slots:
		var display: Node = $HeldItemDisplay if slot == self else slot.get_node_or_null("HeldItemDisplay")
		if display != null:
			display.get_node("Label").visible = false
		var item: RefCounted = slot.held_item
		if item is CookedDish:
			lines.append("%s (%s)" % [item.dish_name(), CookingMinigame.quality_label(item.quality)])
		elif item is Drink:
			lines.append("%s (%s)" % [item.display_name(), CookingMinigame.quality_label(item.quality)])
		elif item != null and item.has_method("display_name"):
			lines.append(item.display_name())
	var first: Label3D = $HeldItemDisplay/Label
	first.text = "
".join(lines)
	first.visible = not lines.is_empty()
