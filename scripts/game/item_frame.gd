class_name ItemFrame
extends RefCounted
## Item frames by rarity (PixelLab, tools/item_frames): every item box in
## the menus, the loot feed and the shops sits in the frame of its rarity.
##   assets/items/frames/<id>.png  hollow 96 px frame (tools/item_frames);
##   item boxes draw it over a slot background in the rarity colour, item
##   cards nine-slice it around the whole card.
## On top, drawn in code and animated (t = seconds):
##   Episch     pulsing violet halo around the frame
##   Legendär   halo + a light sweep over the frame + orbiting sparks
##   Mythisch   halo + sweep + flames licking up the sides + star rays
## Without the PNGs it falls back to a plain ink box in the rarity colour.

## Nine-slice margin of the 96 px source (covers the corner ornaments).
const RIM := 24
## Inner edge of the frames is at ~14-21 px of 96.
const INSET := 0.19
const INK := Color("2e222f")

static var _tex := {}


static func _load(name: String) -> Texture2D:
	if not _tex.has(name):
		var p := "res://assets/items/frames/%s.png" % name
		_tex[name] = load(p) if ResourceLoader.exists(p) else null
	return _tex[name]


static func slot_texture(rarity: int) -> Texture2D:
	return _load(str(Loot.RARITIES[clampi(rarity, 0, Loot.MYTHIC)].id))


static func rim_texture(rarity: int) -> Texture2D:
	return slot_texture(rarity)


## The inner area of a slot of rect r (where the icon goes).
static func inner(r: Rect2) -> Rect2:
	return r.grow(-r.size.x * INSET)


## Glow behind the frame (call before slot()).
static func halo(ci: CanvasItem, r: Rect2, rarity: int, t: float) -> void:
	if rarity < Loot.EPIC:
		return
	var col := Loot.RARITIES[rarity].color as Color
	var pulse := 0.5 + 0.5 * sin(t * (3.0 + rarity))
	var steps := 3 + (rarity - Loot.EPIC) * 2
	for i in steps:
		var g := r.size.x * (0.03 + 0.035 * i) * (0.85 + 0.3 * pulse)
		ci.draw_rect(r.grow(g), Color(col, (0.16 - 0.1 * float(i) / steps) * (0.6 + 0.4 * pulse)))
	if rarity >= Loot.MYTHIC:  # turning star rays behind everything
		for k in 8:
			var a := t * 0.7 + k * TAU / 8.0
			var c := r.get_center()
			var tip := c + Vector2.from_angle(a) * r.size.x * (0.8 + 0.1 * sin(t * 3.0 + k))
			var side := Vector2.from_angle(a + PI * 0.5) * r.size.x * 0.06
			ci.draw_colored_polygon(PackedVector2Array([c + side, tip, c - side]), Color(col.lightened(0.25), 0.22))


## The slot frame with its inner background (behind the icon).
static func slot(ci: CanvasItem, r: Rect2, rarity: int, t := 0.0) -> void:
	var tex := slot_texture(rarity)
	var col := Loot.RARITIES[clampi(rarity, 0, Loot.MYTHIC)].color as Color
	if tex == null:
		ci.draw_rect(r.grow(2), INK)
		ci.draw_rect(r, col.lerp(Color("f4ead2"), 0.7))
		return
	# slot background: dark in the rarity colour, lighter towards the middle
	var bg := r.grow(-r.size.x * 0.12)
	ci.draw_rect(bg, col.darkened(0.72))
	ci.draw_rect(bg.grow(-bg.size.x * 0.1), col.darkened(0.6))
	var glow := 0.22 if rarity < Loot.EPIC else 0.28 + 0.1 * sin(t * 4.0)  # breathes from Episch
	ci.draw_circle(bg.get_center(), bg.size.x * 0.36, Color(col, glow))
	ci.draw_texture_rect(tex, r, false)


## Light, sparks and flames over the frame (call after the icon).
static func shine(ci: CanvasItem, r: Rect2, rarity: int, t: float) -> void:
	if rarity < Loot.LEGENDARY:
		if rarity == Loot.EPIC:  # two slow glints on the corners
			var ec := Loot.RARITIES[rarity].color as Color
			for k in 2:
				var a := 0.5 + 0.5 * sin(t * 2.3 + k * PI)
				var c := r.position + Vector2(r.size.x * 0.12, r.size.y * 0.12) if k == 0 else r.end - Vector2(r.size.x * 0.12, r.size.y * 0.12)
				_star(ci, c, r.size.x * 0.09 * a, Color(ec.lightened(0.6), a))
		return
	var col := Loot.RARITIES[rarity].color as Color
	# diagonal light sweep over the rim, once every ~2.5 s
	var ph := fmod(t * 0.4, 1.0)
	if ph < 0.45:
		var x := r.position.x + (ph / 0.45) * (r.size.x * 1.6) - r.size.x * 0.3
		var w := r.size.x * 0.12
		var pts := PackedVector2Array([Vector2(x, r.position.y), Vector2(x + w, r.position.y), Vector2(x + w - r.size.y * 0.4, r.end.y), Vector2(x - r.size.y * 0.4, r.end.y)])
		var clip := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		for poly in Geometry2D.intersect_polygons(pts, clip):
			ci.draw_colored_polygon(poly, Color(1, 1, 1, 0.28))
	# sparks running around the rim
	var n := 3 if rarity == Loot.LEGENDARY else 5
	for k in n:
		var p := _on_rim(r.grow(-r.size.x * 0.06), fmod(t * 0.22 + float(k) / n, 1.0))
		_star(ci, p, r.size.x * (0.07 + 0.03 * sin(t * 6.0 + k)), Color(col.lightened(0.55), 0.9))
	if rarity >= Loot.MYTHIC:  # flames licking up both sides and the top
		for k in 10:
			var life := fmod(t * 1.3 + k * 0.137, 1.0)
			var side := k % 2
			var y := r.end.y - life * r.size.y * 1.15
			var x := (r.position.x if side == 0 else r.end.x) + sin(t * 5.0 + k) * 0.04 * r.size.x
			var s := r.size.x * 0.09 * (1.0 - life)
			ci.draw_circle(Vector2(x, y), s, Color(col.lerp(Color("f9c22b"), life), 0.55 * (1.0 - life)))
			ci.draw_circle(Vector2(x, y), s * 0.5, Color(1, 0.95, 0.7, 0.5 * (1.0 - life)))


## Full item box: halo, frame, the icon of the item, light. The icon is
## drawn by draw_icon(center, scale) so callers keep their own badges.
static func box(ci: CanvasItem, r: Rect2, item: Dictionary, t: float) -> void:
	var rar := int(item.get("rarity", 0))
	halo(ci, r, rar, t)
	slot(ci, r, rar, t)
	var ir := inner(r)
	ItemIcon.draw_icon(ci, ir.get_center(), item, ir.size.x / 17.0)
	shine(ci, r, rar, t)


## Card / tooltip border: the hollow rim nine-sliced around r.
static func card(ci: CanvasItem, r: Rect2, rarity: int, t: float, px := 2.0) -> void:
	if rarity >= Loot.LEGENDARY:
		halo(ci, r, rarity, t * 0.6)
	var tex := rim_texture(rarity)
	if tex == null:
		ci.draw_rect(r, Loot.RARITIES[rarity].color, false, 3.0)
		return
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	for m in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_texture_margin(m, RIM)
	sb.draw_center = false
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	# draw at pixel scale: the rim keeps its 1:scale pixel look
	ci.draw_set_transform_matrix(Transform2D(0.0, Vector2(px, px), 0.0, r.position))
	ci.draw_style_box(sb, Rect2(Vector2.ZERO, r.size / px))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	if rarity >= Loot.LEGENDARY:
		var col := Loot.RARITIES[rarity].color as Color
		for k in 4:
			var p := _on_rim(r.grow(-RIM * px * 0.4), fmod(t * 0.08 + k * 0.25, 1.0))
			_star(ci, p, 7.0 + 2.0 * sin(t * 5.0 + k), Color(col.lightened(0.55), 0.85))


## Point at u (0..1) around the rect, clockwise from the top left.
static func _on_rim(r: Rect2, u: float) -> Vector2:
	var per := 2.0 * (r.size.x + r.size.y)
	var d := u * per
	if d < r.size.x:
		return r.position + Vector2(d, 0)
	d -= r.size.x
	if d < r.size.y:
		return Vector2(r.end.x, r.position.y + d)
	d -= r.size.y
	if d < r.size.x:
		return Vector2(r.end.x - d, r.end.y)
	d -= r.size.x
	return Vector2(r.position.x, r.end.y - d)


## Four-point glint.
static func _star(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	if s <= 0.3:
		return
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.25, 0), c + Vector2(0, s), c + Vector2(-s * 0.25, 0)]), col)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s, 0), c + Vector2(0, s * 0.25), c + Vector2(s, 0), c + Vector2(0, -s * 0.25)]), col)
