class_name ItemFrame
extends RefCounted
## Item frames by rarity (PixelLab, tools/item_frames): every item box in
## the menus, the loot feed and the shops sits in the frame of its rarity.
##   assets/items/frames/<id>.png  hollow 96 px frame (tools/item_frames);
##   item boxes draw it over a slot background in the rarity colour, item
##   cards nine-slice it around the whole card.
## Kept subtle (Kaiser 2026-11-06: "Rahmen dezenter"): the frame is drawn
## slightly faded towards paper, the slot background is calm, and only
## soft animation on top (t = seconds):
##   Episch     faint breathing halo
##   Legendär   halo + a slow light sweep over the frame
##   Mythisch   halo + sweep + two slow sparks on the rim
## Without the PNGs it falls back to a plain ink box in the rarity colour.

## Nine-slice margin of the 96 px source (covers the corner ornaments).
const RIM := 24
## Inner edge of the frames is at ~14-21 px of 96, times SLIM.
const INSET := 0.19 * SLIM
const INK := Color("2e222f")
const PAPER := Color("f4ead2")
## Item boxes draw the frame nine-sliced at this share of the box size, so
## the rim is thinner than the full 96 px picture (Kaiser: dezenter).
const SLIM := 0.7

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


## Soft glow behind the frame (call before slot()).
static func halo(ci: CanvasItem, r: Rect2, rarity: int, t: float) -> void:
	if rarity < Loot.EPIC:
		return
	var col := Loot.RARITIES[rarity].color as Color
	var pulse := 0.5 + 0.5 * sin(t * 2.0)
	var steps := 2 if rarity == Loot.EPIC else 3
	for i in steps:
		var g := r.size.x * (0.02 + 0.03 * i)
		ci.draw_rect(r.grow(g), Color(col, (0.07 - 0.02 * i) * (0.6 + 0.4 * pulse)))


## The slot frame with its inner background (behind the icon).
static func slot(ci: CanvasItem, r: Rect2, rarity: int, t := 0.0) -> void:
	var tex := slot_texture(rarity)
	var col := Loot.RARITIES[clampi(rarity, 0, Loot.MYTHIC)].color as Color
	if tex == null:
		ci.draw_rect(r.grow(2), INK)
		ci.draw_rect(r, col.lerp(PAPER, 0.7))
		return
	# calm slot background: paper with a light wash of the rarity colour
	var bg := r.grow(-r.size.x * 0.12 * SLIM)
	ci.draw_rect(bg, col.lerp(PAPER, 0.78))
	ci.draw_circle(bg.get_center(), bg.size.x * 0.34, Color(col, 0.10 + (0.04 * sin(t * 2.0) if rarity >= Loot.EPIC else 0.0)))
	_nine(ci, tex, r, r.size.x / 96.0 * SLIM)


## Gentle light over the frame (call after the icon).
static func shine(ci: CanvasItem, r: Rect2, rarity: int, t: float) -> void:
	if rarity < Loot.LEGENDARY:
		return
	var col := Loot.RARITIES[rarity].color as Color
	# slow diagonal light sweep, once every ~5 s
	var ph := fmod(t * 0.2, 1.0)
	if ph < 0.3:
		var x := r.position.x + (ph / 0.3) * (r.size.x * 1.6) - r.size.x * 0.3
		var w := r.size.x * 0.08
		var pts := PackedVector2Array([Vector2(x, r.position.y), Vector2(x + w, r.position.y), Vector2(x + w - r.size.y * 0.4, r.end.y), Vector2(x - r.size.y * 0.4, r.end.y)])
		var clip := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		for poly in Geometry2D.intersect_polygons(pts, clip):
			ci.draw_colored_polygon(poly, Color(1, 1, 1, 0.14))
	if rarity >= Loot.MYTHIC:  # two slow sparks on the rim
		for k in 2:
			var p := _on_rim(r.grow(-r.size.x * 0.06), fmod(t * 0.08 + k * 0.5, 1.0))
			_star(ci, p, r.size.x * (0.045 + 0.015 * sin(t * 3.0 + k)), Color(col.lightened(0.5), 0.6))


## Full item box: halo, frame, the icon of the item, light. The icon is
## drawn by draw_icon(center, scale) so callers keep their own badges.
static func box(ci: CanvasItem, r: Rect2, item: Dictionary, t: float) -> void:
	var rar := int(item.get("rarity", 0))
	halo(ci, r, rar, t)
	slot(ci, r, rar, t)
	var ir := inner(r)
	ItemIcon.draw_icon(ci, ir.get_center(), item, ir.size.x / 17.0)
	shine(ci, r, rar, t)


## Card / tooltip border: the hollow rim nine-sliced around r, thin.
static func card(ci: CanvasItem, r: Rect2, rarity: int, _t: float, px := 0.6) -> void:
	var tex := rim_texture(rarity)
	if tex == null:
		ci.draw_rect(r, Loot.RARITIES[rarity].color, false, 3.0)
		return
	_nine(ci, tex, r, px)


static var _boxes := {}


## Draws the frame nine-sliced around r with the rim at px times its size.
static func _nine(ci: CanvasItem, tex: Texture2D, r: Rect2, px: float) -> void:
	var sb: StyleBoxTexture = _boxes.get(tex)
	if sb == null:
		sb = StyleBoxTexture.new()
		sb.texture = tex
		for m in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			sb.set_texture_margin(m, RIM)
		sb.draw_center = false
		_boxes[tex] = sb
	ci.draw_set_transform_matrix(Transform2D(0.0, Vector2(px, px), 0.0, r.position))
	ci.draw_style_box(sb, Rect2(Vector2.ZERO, r.size / px))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


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
