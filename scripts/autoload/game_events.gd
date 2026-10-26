# GameEvents (autoload): game-wide signals, so game logic can announce things
# without knowing who displays them (the HUD listens).
extends Node

signal message(text: String)


# Show a short message to the players (and print it for debugging).
func announce(text: String) -> void:
	print(text)
	message.emit(text)
