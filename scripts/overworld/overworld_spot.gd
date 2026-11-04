class_name OverworldSpot
extends Node2D
## Something in the overworld you can walk up to and use: an NPC (talk),
## a sign (read) or a door into a combat area (enter). The overworld picks
## the nearest one in reach and the HUD shows its prompt above it.

enum Kind { NPC, SIGN, DOOR }

var kind := Kind.NPC
var id := ""
var display_name := ""
## Dialogue: lines shown one after another in the HUD's speech panel.
var lines: Array = []
## Doors: the area they lead to (GameFlow.AREAS).
var target_area := ""
var reach := 34.0
## Where the prompt bubble sits, relative to the spot.
var prompt_offset := Vector2(0, -70)
## Accent colour of the name tag and the marker.
var accent := Color("e83b3b")
## Own prompt word instead of Sprechen / Lesen (e.g. "Beschwören").
var verb := ""
## NPC drawing (optional): a still or a strip, foot at the bottom centre.
var sprite: Sprite2D
var _t := 0.0
var _base_y := 0.0


func prompt() -> String:
	if verb != "":
		return verb
	match kind:
		Kind.DOOR:
			return "Versiegelt" if GameFlow.area_info(target_area).get("locked", false) else "Betreten"
		Kind.SIGN:
			return "Lesen"
	return "Sprechen"


## NPCs turn towards the player while he is close.
func face(x: float) -> void:
	if sprite != null and kind == Kind.NPC:
		sprite.flip_h = x < global_position.x


func _process(delta: float) -> void:
	_t += delta
	if sprite != null and kind == Kind.NPC:
		# calm breathing: a one-pixel bob, never in sync with the others
		sprite.position.y = _base_y - (1.0 if fmod(_t + id.length() * 0.37, 1.6) < 0.8 else 0.0)


func set_sprite(tex: Texture2D, frames := 1) -> void:
	sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.hframes = frames
	sprite.centered = false
	var fw := tex.get_width() / frames
	sprite.offset = Vector2(-fw * 0.5, -tex.get_height())
	add_child(sprite)
	_base_y = sprite.position.y
