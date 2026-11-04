class_name Sfx
extends Node
## Plays sound effects by event name, defined in assets/audio/sfx_map.json.
##
##   Sfx.play("jump")
##   Sfx.play("hit_heavy", -3.0)   # extra volume in dB
##
## Needs no autoload: the first call adds one Sfx node to the scene tree.
## Swapping a placeholder for a final sound only changes the JSON.

const MAP_PATH := "res://assets/audio/sfx_map.json"
const VOICES := 12  # sounds that can overlap

static var _instance: Sfx

var _map: Dictionary = {}
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


static func play(event: String, volume_db := 0.0) -> void:
	var sfx := _node()
	if sfx:
		sfx._play(event, volume_db)


static func has_event(event: String) -> bool:
	var sfx := _node()
	return sfx != null and sfx._map.has(event)


static func _node() -> Sfx:
	if is_instance_valid(_instance):
		return _instance
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	_instance = Sfx.new()
	_instance.name = "Sfx"
	tree.root.add_child.call_deferred(_instance)
	_instance._setup()
	return _instance


func _setup() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # also during hit-stop / pause
	var f := FileAccess.open(MAP_PATH, FileAccess.READ)
	if f == null:
		push_warning("Sfx: %s fehlt" % MAP_PATH)
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		_map = data
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func _play(event: String, volume_db: float) -> void:
	var entry = _map.get(event)
	if not (entry is Dictionary) or _players.is_empty():
		return
	if not is_inside_tree():  # first call: node is added deferred
		_play.call_deferred(event, volume_db)
		return
	var files: Array = entry.get("files", [])
	if files.is_empty():
		return
	var path: String = "res://" + str(files.pick_random())
	var stream: AudioStream = _streams.get(path)
	if stream == null:
		stream = load(path) as AudioStream
		if stream == null:
			push_warning("Sfx: %s nicht ladbar" % path)
			return
		_streams[path] = stream
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	var jitter: float = entry.get("pitch_jitter", 0.0)
	p.stream = stream
	p.volume_db = float(entry.get("volume_db", 0.0)) + volume_db
	p.pitch_scale = 1.0 + randf_range(-jitter, jitter)
	p.play()
