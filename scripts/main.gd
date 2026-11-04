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
	hud.process_mode = Node.PROCESS_MODE_ALWAYS  # cut-in banner plays during the super pause
	room.hud = hud
	hud_layer.add_child(hud)
	add_child(hud_layer)
	room.numbers = numbers

	# Character collection: opens with C / Start. Starts with the selected character.
	var select_layer := CanvasLayer.new()
	select_layer.layer = 20
	select_layer.add_child(CharacterSelect.new())
	add_child(select_layer)
	room.player.visual.look = Roster.look(Roster.selected(), Roster.selected_skin())
