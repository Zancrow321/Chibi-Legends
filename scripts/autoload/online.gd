extends Node
## Online-Basis (Endgame Schritt 3): Konto bei Supabase und die Server-
## Funktionen aus supabase/migrations/0001_online_base.sql.
##
## Beim Start meldet sich das Spiel als Gast an (anonymes Konto, Sitzung in
## user://online.json). Klappt das nicht (kein Netz, Datenbank noch nicht
## eingespielt, Gast-Anmeldung aus), läuft alles offline mit den lokalen
## Regeln (RaidLoot) weiter. Wertvolles entscheidet online der Server:
## Bonus-Beute, Seltenheit, Teil-Art, Raid-Marken. Das Teil selbst baut
## build_item() aus dem Seed des Servers.
##
## Tests und Headless-Läufe bleiben offline; im Web schaltet ?offline=1 ab.

signal state_changed(state: String)

const URL := "https://twfapncxxfykevinakke.supabase.co"
## Öffentlicher Schlüssel (darf im Client stehen; die Rechte regeln RLS und
## die Server-Funktionen). Der service_role-Schlüssel gehört nie hierher.
const ANON_KEY := "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR3ZmFwbmN4eGZ5a2V2aW5ha2tlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTM5NTkxODQsImV4cCI6MjEwOTUzNTE4NH0.vEeJ1GO2dTAbMy4CGaMPsDwrVGlKhr5ZErKzumeUI5o"
const SAVE := "user://online.json"
const TIMEOUT := 8.0

var state := "offline"  # offline, connecting, online
var last_error := ""
var session := {}  # access_token, refresh_token, expires_at, user_id
var profile := {}  # from cl_state


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _allowed():
		return
	connect_account.call_deferred()


func _allowed() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a == "--offline":
			return false
	if OS.has_feature("web"):
		var q := str(JavaScriptBridge.eval("window.location.search", true))
		if q.contains("offline=1"):
			return false
	return true


func is_online() -> bool:
	return state == "online"


func _set_state(s: String) -> void:
	if s != state:
		state = s
		state_changed.emit(s)


## Anmelden: gespeicherte Sitzung auffrischen oder neues Gast-Konto.
func connect_account() -> void:
	_set_state("connecting")
	_load()
	var ok := false
	if session.has("refresh_token"):
		ok = await _refresh()
	if not ok:
		ok = await _sign_up_guest()
	if ok:
		var r := await call_fn("cl_state")
		if r.ok:
			profile = r.data
			Profile.ensure()
			Profile.marks = int(profile.get("marks", Profile.marks))
			Profile.save()
			_set_state("online")
			print("Online: angemeldet (%s)" % str(profile.get("name", "")))
			var g := await call_fn("cl_guild_mine")
			if g.ok:
				GuildState.set_from(g.data)
			return
		ok = false
	print("Online: offline weiter (%s)" % last_error)
	_set_state("offline")


func _sign_up_guest() -> bool:
	var r := await _request("/auth/v1/signup", {}, false)
	return _take_session(r)


func _refresh() -> bool:
	var r := await _request("/auth/v1/token?grant_type=refresh_token", {"refresh_token": session.refresh_token}, false)
	return _take_session(r)


func _take_session(r: Dictionary) -> bool:
	if not r.ok or not (r.data is Dictionary) or not r.data.has("access_token"):
		return false
	session = {
		"access_token": r.data.access_token,
		"refresh_token": r.data.get("refresh_token", ""),
		"expires_at": Time.get_unix_time_from_system() + float(r.data.get("expires_in", 3600)),
		"user_id": str(r.data.get("user", {}).get("id", "")),
	}
	_save()
	return true


## Ruft eine Server-Funktion auf: {ok, data, error}.
func call_fn(fn: String, args := {}) -> Dictionary:
	if session.has("expires_at") and Time.get_unix_time_from_system() > float(session.expires_at) - 60.0:
		await _refresh()
	return await _request("/rest/v1/rpc/" + fn, args, true)


func _request(path: String, body: Dictionary, auth: bool) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	add_child(http)
	var headers := PackedStringArray(["apikey: " + ANON_KEY, "Content-Type: application/json"])
	if auth and session.has("access_token"):
		headers.append("Authorization: Bearer " + str(session.access_token))
	var err := http.request(URL + path, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		http.queue_free()
		last_error = "Anfrage nicht gestartet (%d)" % err
		return {"ok": false, "data": null, "error": last_error}
	var res: Array = await http.request_completed
	http.queue_free()
	var code: int = res[1]
	var text: String = (res[3] as PackedByteArray).get_string_from_utf8()
	var data = JSON.parse_string(text) if text != "" else null
	if res[0] != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		last_error = _message(code, data, res[0])
		return {"ok": false, "data": data, "error": last_error}
	return {"ok": true, "data": data, "error": ""}


func _message(code: int, data, result: int) -> String:
	if result != HTTPRequest.RESULT_SUCCESS:
		return "keine Verbindung"
	if data is Dictionary:
		for k in ["message", "msg", "error_description", "error"]:
			if data.has(k):
				return "%d %s" % [code, str(data[k])]
	return "HTTP %d" % code


## Baut ein Teil aus einem Server-Drop (gleicher Seed = gleiches Teil).
func build_item(drop: Dictionary, style_hint := "") -> Dictionary:
	seed(int(drop.seed))
	var it: Dictionary
	if str(drop.get("source", "")) == "essenwacht":
		it = RaidArmor.roll(int(drop.ilvl), style_hint, int(drop.rarity), str(drop.slot))
	else:
		it = Loot.roll(int(drop.ilvl), int(drop.rarity), str(drop.slot), style_hint)
	randomize()
	it["server_id"] = int(drop.id)
	return it


func _load() -> void:
	var f := FileAccess.open(SAVE, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		session = d


func _save() -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(session))
