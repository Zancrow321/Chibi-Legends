@tool
extends RefCounted
## Reads M.U.G.E.N sprite files: SFF v1 (PCX images, shared palettes, .act)
## and SFF v2 / v2.01 (RLE8, RLE5, LZ5, raw, PNG). Images are decoded only
## when asked for, so big files stay fast.

var path := ""
var version := 0  # 1 or 2
var error := ""
var sprites: Array = []  # header info per sprite
var _index: Dictionary = {}  # "group,no" -> sprite index
var _bytes := PackedByteArray()
var _palettes: Array = []  # v2: PackedColorArray per palette; v1: per sprite (or null)
var _act := PackedColorArray()
var _cache: Dictionary = {}
var _ldata := 0
var _tdata := 0


func open(file: String) -> bool:
	path = file
	var f := FileAccess.open(file, FileAccess.READ)
	if f == null:
		error = "Sprite-Datei fehlt: %s" % file
		return false
	_bytes = f.get_buffer(f.get_length())
	if _bytes.size() < 64 or _bytes.slice(0, 11).get_string_from_ascii() != "ElecbyteSpr":
		error = "Keine SFF-Datei: %s" % file
		return false
	var major := _bytes[15]
	if major == 1:
		version = 1
		return _open_v1()
	if major == 2:
		version = 2
		return _open_v2()
	error = "Unbekannte SFF-Version %d" % major
	return false


## Optional .act palette for SFF v1 (stored in reverse order by M.U.G.E.N).
## Used for every sprite except portraits (group 9000), like the engine does
## for the character's first palette.
func set_act(file: String) -> void:
	var f := FileAccess.open(file, FileAccess.READ)
	if f == null:
		return
	var b := f.get_buffer(768)
	if b.size() < 768:
		return
	_act = PackedColorArray()
	_act.resize(256)
	for i in 256:
		var k := (255 - i) * 3
		_act[i] = Color8(b[k], b[k + 1], b[k + 2])
	_cache.clear()


func has(group: int, no: int) -> bool:
	return _index.has("%d,%d" % [group, no])


## {"image": Image (RGBA8), "axis": Vector2i} or {} if missing/broken.
func get_sprite(group: int, no: int) -> Dictionary:
	var key := "%d,%d" % [group, no]
	if not _index.has(key):
		return {}
	if _cache.has(key):
		return _cache[key]
	var idx: int = _index[key]
	var s: Dictionary = sprites[idx]
	var img: Image = _decode(idx, 0)
	var res := {}
	if img != null:
		res = {"image": img, "axis": Vector2i(s.ax, s.ay)}
	_cache[key] = res
	return res


# ------------------------------------------------------------------ SFF v1

func _open_v1() -> bool:
	var count := _u32(20)
	var pos := _u32(24)
	var last_pal: Variant = null
	for i in count:
		if pos <= 0 or pos + 32 > _bytes.size():
			break
		var nxt := _u32(pos)
		var length := _u32(pos + 4)
		var s := {
			"ax": _s16(pos + 8), "ay": _s16(pos + 10), "group": _u16(pos + 12), "no": _u16(pos + 14),
			"link": _u16(pos + 16), "same_pal": _bytes[pos + 18], "off": pos + 32, "len": length,
		}
		var pal: Variant = null
		if length > 0 and (s.same_pal == 0 or last_pal == null) and length > 769 \
				and _bytes[pos + 32 + length - 769] == 12:
			pal = _pcx_palette(pos + 32 + length - 768)
		if pal == null:
			pal = last_pal
		else:
			last_pal = pal
		_palettes.append(pal)
		sprites.append(s)
		var key := "%d,%d" % [s.group, s.no]
		if not _index.has(key):
			_index[key] = i
		if nxt == 0:
			break
		pos = nxt
	if sprites.is_empty():
		error = "SFF v1 ohne Bilder"
		return false
	return true


func _pcx_palette(off: int) -> PackedColorArray:
	var pal := PackedColorArray()
	pal.resize(256)
	for i in 256:
		pal[i] = Color8(_bytes[off + i * 3], _bytes[off + i * 3 + 1], _bytes[off + i * 3 + 2])
	return pal


func _decode_v1(idx: int, depth: int) -> Image:
	var s: Dictionary = sprites[idx]
	if s.len == 0:
		if depth > 8 or s.link >= sprites.size() or s.link == idx:
			return null
		return _decode(s.link, depth + 1)
	var o: int = s.off
	if _bytes[o] != 10 or _bytes[o + 3] != 8 or _bytes[o + 65] != 1:
		return null  # only 8-bit single-plane PCX
	var w := _u16(o + 8) - _u16(o + 4) + 1
	var h := _u16(o + 10) - _u16(o + 6) + 1
	var bpl := _u16(o + 66)
	if w <= 0 or h <= 0 or bpl < w:
		return null
	var idxs := PackedByteArray()
	idxs.resize(bpl * h)
	var i := o + 128
	var end: int = o + s.len
	var j := 0
	var total := bpl * h
	while j < total and i < end:
		var b := _bytes[i]
		i += 1
		if (b & 0xC0) == 0xC0:
			var n := b & 0x3F
			var c := _bytes[i] if i < end else 0
			i += 1
			for k in n:
				if j < total:
					idxs[j] = c
					j += 1
		else:
			idxs[j] = b
			j += 1
	var pal: Variant = _palettes[idx]
	if _act.size() == 256 and s.group != 9000:
		pal = _act
	if pal == null:
		pal = _grey()
	return _indexed_to_image(idxs, w, h, bpl, pal)


# ------------------------------------------------------------------ SFF v2

func _open_v2() -> bool:
	var spr_off := _u32(36)
	var spr_count := _u32(40)
	var pal_off := _u32(44)
	var pal_count := _u32(48)
	_ldata = _u32(52)
	_tdata = _u32(60)
	var pal_nodes: Array = []
	for i in pal_count:
		var p := pal_off + i * 16
		if p + 16 > _bytes.size():
			break
		pal_nodes.append({"n": _u16(p + 4), "link": _u16(p + 6), "off": _u32(p + 8), "len": _u32(p + 12)})
	for i in pal_nodes.size():
		var node: Dictionary = pal_nodes[i]
		if node.len == 0 and node.link < pal_nodes.size():
			node = pal_nodes[node.link]
		var pal := PackedColorArray()
		pal.resize(256)
		pal.fill(Color(0, 0, 0))
		var base: int = _ldata + node.off
		for c in mini(256, int(node.len) / 4):
			var k := base + c * 4
			if k + 2 < _bytes.size():
				pal[c] = Color8(_bytes[k], _bytes[k + 1], _bytes[k + 2])
		_palettes.append(pal)
	for i in spr_count:
		var p := spr_off + i * 28
		if p + 28 > _bytes.size():
			break
		var s := {
			"group": _u16(p), "no": _u16(p + 2), "w": _u16(p + 4), "h": _u16(p + 6),
			"ax": _s16(p + 8), "ay": _s16(p + 10), "link": _u16(p + 12), "fmt": _bytes[p + 14],
			"depth": _bytes[p + 15], "off": _u32(p + 16), "len": _u32(p + 20), "pal": _u16(p + 24),
			"flags": _u16(p + 26),
		}
		sprites.append(s)
		var key := "%d,%d" % [s.group, s.no]
		if not _index.has(key):
			_index[key] = i
	if sprites.is_empty():
		error = "SFF v2 ohne Bilder"
		return false
	return true


func _decode_v2(idx: int, depth: int) -> Image:
	var s: Dictionary = sprites[idx]
	if s.len == 0:
		if depth > 8 or s.link >= sprites.size() or s.link == idx:
			return null
		return _decode(s.link, depth + 1)
	var base: int = (_tdata if (s.flags & 1) else _ldata) + s.off
	var w: int = s.w
	var h: int = s.h
	if base + s.len > _bytes.size() or w == 0 or h == 0:
		return null
	var pal: PackedColorArray = _palettes[s.pal] if s.pal < _palettes.size() else _grey()
	var fmt: int = s.fmt
	if fmt >= 10:
		var img := Image.new()
		if img.load_png_from_buffer(_bytes.slice(base + 4, base + s.len)) != OK:
			return null
		var had_alpha := img.detect_alpha() != Image.ALPHA_NONE
		img.convert(Image.FORMAT_RGBA8)
		if not had_alpha:
			# indexed PNG without transparency: palette color 0 is see-through
			var key := pal[0]
			for y in img.get_height():
				for x in img.get_width():
					var c := img.get_pixel(x, y)
					if c.is_equal_approx(Color(key.r, key.g, key.b, 1.0)):
						img.set_pixel(x, y, Color(0, 0, 0, 0))
		return img
	var data := _bytes.slice(base + 4, base + s.len)
	var px: PackedByteArray
	match fmt:
		0:
			px = _bytes.slice(base, base + s.len)
		2:
			px = _rle8(data, w * h)
		3:
			px = _rle5(data, w * h)
		4:
			px = _lz5(data, w * h)
		_:
			return null
	return _indexed_to_image(px, w, h, w, pal)


static func _rle8(src: PackedByteArray, size: int) -> PackedByteArray:
	var p := PackedByteArray()
	p.resize(size)
	var i := 0
	var j := 0
	while j < size and i < src.size():
		var b := src[i]
		i += 1
		if (b & 0xC0) == 0x40:
			var n := b & 0x3F
			var c := src[i] if i < src.size() else 0
			i += 1
			for k in n:
				if j < size:
					p[j] = c
					j += 1
		else:
			p[j] = b
			j += 1
	return p


static func _rle5(src: PackedByteArray, size: int) -> PackedByteArray:
	var p := PackedByteArray()
	p.resize(size)
	var last := src.size() - 1
	if last < 0:
		return p
	var i := 0
	var j := 0
	while j < size:
		var rl := int(src[i])
		if i < last:
			i += 1
		var dl := int(src[i] & 0x7F)
		var c := 0
		if src[i] >> 7 != 0:
			if i < last:
				i += 1
			c = src[i]
		if i < last:
			i += 1
		while true:
			if j < size:
				p[j] = c
				j += 1
			rl -= 1
			if rl < 0:
				dl -= 1
				if dl < 0:
					break
				c = src[i] & 0x1F
				rl = src[i] >> 5
				if i < last:
					i += 1
	return p


static func _lz5(src: PackedByteArray, size: int) -> PackedByteArray:
	var p := PackedByteArray()
	p.resize(size)
	var last := src.size() - 1
	if last < 0:
		return p
	var i := 0
	var j := 0
	var ct := int(src[0])
	var cts := 0
	var rb := 0
	var rbc := 0
	if i < last:
		i += 1
	var guard := 0
	while j < size:
		guard += 1
		if guard > size * 4 + 64:
			break  # broken data: stop instead of hanging
		var d := int(src[i])
		var n := 0
		if i < last:
			i += 1
		if ct & (1 << cts):
			if d & 0x3F == 0:
				d = ((d << 2) | int(src[i])) + 1
				if i < last:
					i += 1
				n = int(src[i]) + 2
				if i < last:
					i += 1
			else:
				rb |= (d & 0xC0) >> rbc
				rbc += 2
				n = d & 0x3F
				if rbc < 8:
					d = int(src[i]) + 1
					if i < last:
						i += 1
				else:
					d = rb + 1
					rb = 0
					rbc = 0
			while true:
				if j < size:
					p[j] = p[j - d] if j - d >= 0 else 0
					j += 1
				n -= 1
				if n < 0:
					break
		else:
			if d & 0xE0 == 0:
				n = int(src[i]) + 8
				if i < last:
					i += 1
			else:
				n = d >> 5
				d &= 0x1F
			for k in n:
				if j < size:
					p[j] = d
					j += 1
		cts += 1
		if cts >= 8:
			ct = int(src[i])
			cts = 0
			if i < last:
				i += 1
	return p


# ------------------------------------------------------------------ shared

func _decode(idx: int, depth: int) -> Image:
	return _decode_v1(idx, depth) if version == 1 else _decode_v2(idx, depth)


static func _indexed_to_image(idxs: PackedByteArray, w: int, h: int, stride: int, pal: PackedColorArray) -> Image:
	var rgba := PackedByteArray()
	rgba.resize(w * h * 4)
	var lut := PackedByteArray()
	lut.resize(1024)
	for c in 256:
		var col: Color = pal[c] if c < pal.size() else Color(0, 0, 0)
		lut[c * 4] = col.r8
		lut[c * 4 + 1] = col.g8
		lut[c * 4 + 2] = col.b8
		lut[c * 4 + 3] = 0 if c == 0 else 255
	for y in h:
		var row := y * stride
		var out := y * w * 4
		for x in w:
			var c := idxs[row + x] * 4
			rgba[out] = lut[c]
			rgba[out + 1] = lut[c + 1]
			rgba[out + 2] = lut[c + 2]
			rgba[out + 3] = lut[c + 3]
			out += 4
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, rgba)


static func _grey() -> PackedColorArray:
	var pal := PackedColorArray()
	pal.resize(256)
	for i in 256:
		pal[i] = Color8(i, i, i)
	return pal


func _u16(o: int) -> int:
	return _bytes.decode_u16(o) if o + 2 <= _bytes.size() else 0


func _s16(o: int) -> int:
	return _bytes.decode_s16(o) if o + 2 <= _bytes.size() else 0


func _u32(o: int) -> int:
	return _bytes.decode_u32(o) if o + 4 <= _bytes.size() else 0
