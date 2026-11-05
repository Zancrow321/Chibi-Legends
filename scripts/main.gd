extends Node2D
## Entry point. The game has two modes (GameFlow): the overworld (academy
## courtyard: exploring, NPCs, gates, a quiet HUD) and the combat areas
## (training room with the combat HUD). AreaTransition switches between them
## with a manga panel wipe and reloads this scene; Main then builds the mode
## that GameFlow names. The game starts in the overworld; ?modus=dungeon in
## the web URL starts in the training forest.
##
## Combat areas: background, training room and HUD.
## Look test: [B] switches the view (flat original / HD-2D A with a 3D
## backdrop / HD-2D B fully 3D / Licht: 2D lights at dusk + parallax, the
## default), [N] jumps between Licht and flat. Effects always run at the
## highest graphics preset (Hd2dSettings). The Licht view is built by DuskStage inside the training room.
## On the web, ?view=flat|a|b|licht and ?abend=0 in the URL pick them directly.

const VIEWS := ["Original (flach)", "HD-2D A: 3D-Kulisse", "HD-2D B: alles 3D", "Licht: Pixel + Dämmerung"]

static var view_mode := 3
static var _url_read := false


static var _intro_shown := false
static var show_title := true  # title screen with the animated logo; ?titel=0 skips it


func _ready() -> void:
	_read_url()
	GameSettings.ensure()
	Profile.ensure()
	for a in [["cycle_view", KEY_B], ["open_creator", KEY_O]]:
		if not InputMap.has_action(a[0]):
			InputMap.add_action(a[0])
			var ev := InputEventKey.new()
			ev.physical_keycode = a[1]
			InputMap.action_add_event(a[0], ev)
	GameFlow.read_url()
	if not _intro_shown:
		_intro_shown = true
		if show_title:
			var title := TitleScreen.new()
			title.finished.connect(func(): AreaTransition.intro(GameFlow.area))
			get_tree().root.add_child.call_deferred(title)
		else:
			AreaTransition.intro.call_deferred(GameFlow.area)
	if GameFlow.is_overworld():
		_build_overworld()
		return

	DuskStage.enabled = view_mode == 3  # the room builds the dusk light look itself
	if view_mode == 0 or view_mode == 3:
		_add_post_fx("dusk" if view_mode == 3 else "flat")
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
	hud.show_help = not GameFlow.combat_help_seen  # H opens it again
	GameFlow.combat_help_seen = true
	hud_layer.add_child(hud)
	var info := Hd2dInfo.new()
	info.view_name = VIEWS[view_mode]
	info.hud = hud
	hud_layer.add_child(info)
	add_child(hud_layer)
	room.numbers = numbers

	# the way back to the overworld: the forest gate, seen from the inside
	var exit := DungeonExit.new()
	exit.room = room
	exit.position = Vector2(34.0, TrainingRoom.GROUND_Y)
	exit.z_index = -2
	room.add_child(exit)

	# Character collection: opens with C / Start; on the first start you pick a free starter.
	var select_layer := CanvasLayer.new()
	select_layer.layer = 20
	var select := CharacterSelect.new()
	select_layer.add_child(select)
	add_child(select_layer)
	room.player.visual.look = Roster.look(Roster.selected(), Roster.selected_skin())
	_add_menu()
	if not _add_creator() and Roster.needs_starter():
		select.open_for.call_deferred(room.player.visual, true)


## Screen shader over the world (grading, shockwaves, heat haze). Added first,
## so fire and stages can register heat sources in their _ready.
func _add_post_fx(mood: String) -> void:
	var post := PostFx.new()
	post.mood = mood
	add_child(post)


## Game menu (Esc): Charakter, Inventar, Optionen. Over the HUDs, under the creator.
func _add_menu() -> GameMenu:
	var layer := CanvasLayer.new()
	layer.layer = 19
	var menu := GameMenu.new()
	layer.add_child(menu)
	layer.add_child(GachaScreen.new())  # Sternschrein (gacha for fighting styles)
	layer.add_child(PassScreen.new())  # Herausforderungen + Saison-Pass (P)
	add_child(layer)
	return menu


## Character Creator: Taste O. Beim allerersten Start öffnet er sich von selbst.
## Returns true when it opens by itself (first start).
func _add_creator() -> bool:
	var creator_layer := CanvasLayer.new()
	creator_layer.layer = 21
	var creator := CreatorScreen.new()
	# every figure (fighter in the dungeon, walker in the courtyard) wears the new look at once
	creator.finished.connect(func(look): get_tree().call_group("fighter_sprite", "set_look", look))
	creator_layer.add_child(creator)
	add_child(creator_layer)
	if not FileAccess.file_exists(CreatorCatalog.SAVE):
		creator.open.call_deferred()
		return true
	return false


## Overworld: the courtyard, bloom for everything that glows, the quiet HUD
## and the collection (C).
func _build_overworld() -> void:
	_add_post_fx("day")
	var world := Overworld.new()
	add_child(world)
	var bloom := Bloom.new()
	add_child(bloom)
	bloom.environment.glow_intensity = 0.7
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 10
	var hud := OverworldHud.new()
	hud.world = world
	world.hud = hud
	hud_layer.add_child(hud)
	add_child(hud_layer)
	var select_layer := CanvasLayer.new()
	select_layer.layer = 20
	var select := CharacterSelect.new()
	select_layer.add_child(select)
	add_child(select_layer)
	hud.select = select
	hud.menu = _add_menu()
	var creator_open := _add_creator()
	world.walker.visual.look = Roster.look(Roster.selected(), Roster.selected_skin())
	if not creator_open and Roster.needs_starter():
		select.open_for.call_deferred(world.walker.visual, true)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("open_creator"):
		get_tree().call_group("creator", "open")
	if GameFlow.is_overworld():
		return  # the look test (views) belongs to the combat areas
	if Input.is_action_just_pressed("cycle_view"):
		view_mode = (view_mode + 1) % VIEWS.size()
		get_tree().reload_current_scene.call_deferred()
	if Input.is_action_just_pressed("toggle_light"):
		view_mode = 0 if view_mode == 3 else 3
		get_tree().paused = false
		get_tree().reload_current_scene.call_deferred()


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
		elif kv[0] == "titel":
			show_title = kv[1] != "0"
