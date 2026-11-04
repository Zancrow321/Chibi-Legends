extends Node2D
## Entry point: assembles background, training room and HUD.
## Phase 1 starts straight in the training room; menus and modes follow later.
## Look test: [B] switches the view (flat original / HD-2D A with a 3D
## backdrop / HD-2D B fully 3D / Licht: 2D lights at dusk + parallax, the
## default), [G] the graphics preset (Hoch/Mittel/Niedrig), [N] jumps between
## Licht and flat. The Licht view is built by DuskStage inside the training room.
## On the web, ?view=flat|a|b|licht, ?abend=0 and ?q=0|1|2 in the URL pick them directly.

const VIEWS := ["Original (flach)", "HD-2D A: 3D-Kulisse", "HD-2D B: alles 3D", "Licht: Pixel + Dämmerung"]

static var view_mode := 3
static var _url_read := false


func _ready() -> void:
	_read_url()
	for a in [["cycle_view", KEY_B], ["cycle_quality", KEY_G]]:
		if not InputMap.has_action(a[0]):
			InputMap.add_action(a[0])
			var ev := InputEventKey.new()
			ev.physical_keycode = a[1]
			InputMap.action_add_event(a[0], ev)

	DuskStage.enabled = view_mode == 3  # the room builds the dusk light look itself
	var room := TrainingRoom.new()
	var numbers := DamageNumbers.new()
	match view_mode:
		1:
			add_child(room)
			var backdrop := Hd2dBackdrop.new()
			backdrop.room = room
			add_child(backdrop)
		3:
			add_child(room)
		2:
			var stage := Hd2dStage.new()
			stage.room = room
			stage.numbers = numbers
			add_child(stage)
		_:
			var bg_layer := CanvasLayer.new()
			bg_layer.layer = -1
			var bg := ForestBackground.new()
			bg_layer.add_child(bg)
			add_child(bg_layer)
			add_child(room)
			bg.camera = room.camera

	if view_mode == 0 or view_mode == 3:
		# 2D views: HDR bloom on effects (the 3D views have their own environment)
		var bloom := Bloom.new()
		bloom.room = room
		add_child(bloom)

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 10
	hud_layer.add_child(numbers)
	var hud := Hud.new()
	hud.room = room
	hud.process_mode = Node.PROCESS_MODE_ALWAYS  # cut-in banner plays during the super pause
	room.hud = hud
	hud_layer.add_child(hud)
	var info := Hd2dInfo.new()
	info.view_name = VIEWS[view_mode]
	hud_layer.add_child(info)
	add_child(hud_layer)
	room.numbers = numbers

	# Character collection: opens with C / Start; on the first start you pick a free starter.
	var select_layer := CanvasLayer.new()
	select_layer.layer = 20
	var select := CharacterSelect.new()
	select_layer.add_child(select)
	add_child(select_layer)
	room.player.visual.look = Roster.look(Roster.selected(), Roster.selected_skin())
	if Roster.needs_starter():
		select.open_for.call_deferred(room.player.visual, true)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("cycle_view"):
		view_mode = (view_mode + 1) % VIEWS.size()
		get_tree().reload_current_scene.call_deferred()
	if Input.is_action_just_pressed("toggle_light"):
		view_mode = 0 if view_mode == 3 else 3
		get_tree().paused = false
		get_tree().reload_current_scene.call_deferred()
	if Input.is_action_just_pressed("cycle_quality"):
		Hd2dSettings.quality = (Hd2dSettings.quality + 2) % 3  # Hoch -> Mittel -> Niedrig -> Hoch
		get_tree().call_group("hd2d_view", "apply_quality")


static func _read_url() -> void:
	if _url_read or not OS.has_feature("web"):
		return
	_url_read = true
	var search := str(JavaScriptBridge.eval("window.location.search", true))
	for part in search.trim_prefix("?").split("&"):
		var kv := part.split("=")
		if kv.size() != 2:
			continue
		if kv[0] == "view":
			view_mode = {"flat": 0, "a": 1, "b": 2, "licht": 3}.get(kv[1], view_mode)
		elif kv[0] == "abend":
			view_mode = 0 if kv[1] == "0" else 3
		elif kv[0] == "q" and kv[1].is_valid_int():
			Hd2dSettings.quality = clampi(kv[1].to_int(), 0, 2)
