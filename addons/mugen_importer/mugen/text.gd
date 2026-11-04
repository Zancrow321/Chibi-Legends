@tool
extends RefCounted
## Helpers for M.U.G.E.N text files (.def, .air, .cns, .cmd, .st):
## Latin-1 reading, comments, [Sections] with key = value lines and
## case-insensitive file lookup (characters are often made on Windows).


## Reads a text file byte by byte as Latin-1, so odd characters in comments
## never break parsing. Returns "" if the file is missing.
static func read_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var buf := f.get_buffer(f.get_length())
	var ascii := true
	for b in buf:
		if b > 127:
			ascii = false
			break
	if ascii:
		return buf.get_string_from_ascii()
	var parts := PackedStringArray()
	parts.resize(buf.size())
	for i in buf.size():
		parts[i] = String.chr(buf[i])
	return "".join(parts)


## Removes a ; comment that is not inside quotes.
static func strip_comment(line: String) -> String:
	var in_quote := false
	for i in line.length():
		var c := line[i]
		if c == '"':
			in_quote = not in_quote
		elif c == ";" and not in_quote:
			return line.substr(0, i)
	return line


## Splits a file into sections. Each: {name, name_l, lines (raw, trimmed,
## no comments), kv: [[key_lower, value]], props: {key_lower: value}}.
## Lines before the first section land in a section named "".
static func sections(text: String) -> Array:
	var out: Array = []
	var cur := {"name": "", "name_l": "", "lines": [], "kv": [], "props": {}}
	out.append(cur)
	for raw in text.replace("\r", "").split("\n"):
		var line := strip_comment(raw).strip_edges()
		if line == "":
			continue
		if line.begins_with("[") and line.find("]") > 0:
			var name := line.substr(1, line.find("]") - 1).strip_edges()
			cur = {"name": name, "name_l": name.to_lower(), "lines": [], "kv": [], "props": {}}
			out.append(cur)
			continue
		cur.lines.append(line)
		var eq := line.find("=")
		if eq > 0:
			var key := line.substr(0, eq).strip_edges().to_lower()
			var val := line.substr(eq + 1).strip_edges()
			cur.kv.append([key, val])
			if not cur.props.has(key):
				cur.props[key] = val
	return out


static func unquote(s: String) -> String:
	s = s.strip_edges()
	if s.length() >= 2 and s.begins_with('"') and s.ends_with('"'):
		return s.substr(1, s.length() - 2)
	return s


## Numbers from a comma list ("-4, 3.5") as floats; missing ones are 0.
static func numbers(s: String, count: int = 0) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for part in s.split(","):
		var p := part.strip_edges()
		out.append(p.to_float() if p.is_valid_float() or p.is_valid_int() else 0.0)
	while out.size() < count:
		out.append(0.0)
	return out


## Finds rel (may use backslashes, any letter case) relative to base_dir.
## Returns the real path or "" if not found.
static func find_file(base_dir: String, rel: String) -> String:
	rel = unquote(rel).replace("\\", "/").strip_edges()
	if rel == "":
		return ""
	var direct := base_dir.path_join(rel)
	if FileAccess.file_exists(direct):
		return direct
	var dir := base_dir
	var parts := rel.split("/", false)
	for i in parts.size():
		var want: String = parts[i].to_lower()
		var found := ""
		var names: PackedStringArray = DirAccess.get_files_at(dir) if i == parts.size() - 1 else DirAccess.get_directories_at(dir)
		for n in names:
			if n.to_lower() == want:
				found = n
				break
		if found == "":
			return ""
		dir = dir.path_join(found)
	return dir
