# LineBag: picks lines so a set doesn't repeat till every line in it has had a
# turn (a shuffled bag), and never the same line twice running, even across a
# refill. Each set has its own key, e.g. "townsfolk:bill" or "reaction:happy".
# Starts again each day (GameState's new day calls reset()).
class_name LineBag
extends RefCounted

static var _bags := {}  # key -> lines still to come this round.
static var _last := {}  # key -> the line said most recently.


static func reset() -> void:
	_bags.clear()
	_last.clear()


# One of `lines` for the set `key`, or null when there are none. If the set's
# lines change (say a chef they've now met unlocks more), any line no longer
# in it is dropped from the bag and new ones join the next round.
static func pick(key: String, lines: Array) -> Variant:
	if lines.is_empty():
		return null
	if lines.size() == 1:
		return lines[0]
	var bag: Array = Array(_bags.get(key, [])).filter(func(line): return line in lines)
	if bag.is_empty():
		bag = lines.duplicate()
		bag.shuffle()
		if bag.back() == _last.get(key):  # Don't start the new round with the line just said.
			bag.push_front(bag.pop_back())
	var line: Variant = bag.pop_back()
	_bags[key] = bag
	_last[key] = line
	return line
