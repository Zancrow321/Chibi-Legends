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

	# Character creator: opens with C / Start, and on the very first start.
	var creator_layer := CanvasLayer.new()
	creator_layer.layer = 20
	var creator := CharacterCreator.new()
	creator_layer.add_child(creator)
	add_child(creator_layer)
	var saved := Appearance.load_look()
	if saved.is_empty():
		creator.open_for.call_deferred(room.player.visual, true)
	else:
		room.player.visual.look = saved
