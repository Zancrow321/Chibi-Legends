extends Node2D
## Entry point: assembles background, training room and HUD.
## Phase 1 starts straight in the training room; menus and modes follow later.


func _ready() -> void:
	var room := TrainingRoom.new()

	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -1
	var bg := ForestBackground.new()
	bg_layer.add_child(bg)
	add_child(bg_layer)

	add_child(room)
	bg.camera = room.camera

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 10
	var numbers := DamageNumbers.new()
	hud_layer.add_child(numbers)
	var hud := Hud.new()
	hud.room = room
	hud_layer.add_child(hud)
	add_child(hud_layer)
	room.numbers = numbers
