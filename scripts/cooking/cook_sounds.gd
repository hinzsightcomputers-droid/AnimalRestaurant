# CookSounds: placeholder sounds for close-up cooking, made in code until there
# are real ones. Each is made once and shared.
#   sizzle, pour, drizzle - loops
#   plop, whoosh, tick, ding, chop, clack - one-shots
class_name CookSounds
extends RefCounted

const RATE := 22050
const LOOPS := ["sizzle", "pour", "drizzle"]

static var _made := {}


static func get_sound(sound: String) -> AudioStreamWAV:
	if not _made.has(sound):
		_made[sound] = _make(sound)
	return _made[sound]


static func _make(sound: String) -> AudioStreamWAV:
	var seconds := {"sizzle": 1.5, "pour": 1.0, "drizzle": 1.0, "plop": 0.18, "whoosh": 0.3, "tick": 0.05, "ding": 0.7, "chop": 0.12, "clack": 0.08}.get(sound, 0.2) as float
	var total := int(RATE * seconds)
	var data := PackedByteArray()
	data.resize(total * 2)
	var low := 0.0      # Running low-pass of the noise.
	var crackle := 0.0
	for i in total:
		var t := float(i) / RATE
		var noise := randf_range(-1.0, 1.0)
		var value := 0.0
		match sound:
			"sizzle":  # Hiss with little pops.
				low += (noise - low) * 0.6
				if randf() < 0.002:
					crackle = randf_range(0.4, 0.9)
				crackle *= 0.97
				value = (noise - low) * 0.25 + crackle * noise * 0.6
			"pour":  # A thick, wobbling glug.
				low += (noise - low) * 0.04
				value = low * (2.2 + 1.2 * sin(TAU * 7.0 * t))
			"drizzle":
				low += (noise - low) * 0.1
				value = low * 1.1
			"plop":
				var pitch := lerpf(240.0, 80.0, t / seconds)
				value = sin(TAU * pitch * t) * exp(-t * 28.0) * 0.8
			"whoosh":
				low += (noise - low) * lerpf(0.05, 0.4, t / seconds)
				value = low * sin(PI * t / seconds) * 1.4
			"tick":
				value = sin(TAU * 1800.0 * t) * exp(-t * 120.0) * 0.5
			"chop":  # A crisp crunch, then the knife hitting wood.
				low += (noise - low) * 0.5
				value = low * exp(-t * 45.0) * 1.2 + sin(TAU * 150.0 * t) * exp(-t * 40.0) * 0.6
			"clack":  # Just the knife on the board.
				value = (sin(TAU * 420.0 * t) * 0.6 + noise * 0.3) * exp(-t * 70.0)
			"ding":
				value = (sin(TAU * 1046.0 * t) + 0.4 * sin(TAU * 2093.0 * t)) * exp(-t * 5.0) * 0.35
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	if sound in LOOPS:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = total
	return wav
