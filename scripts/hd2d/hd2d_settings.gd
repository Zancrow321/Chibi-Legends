class_name Hd2dSettings
extends RefCounted
## Graphics presets for the HD-2D look. The game always runs at Hoch (all
## effects at maximum); there is no player choice. The lower presets stay only
## for the shader probe tool (tools/shader/probe.gd).

const NAMES := ["Niedrig", "Mittel", "Hoch"]

static var quality := 2


static func preset(q: int = quality) -> Dictionary:
	match q:
		0:
			return {"scale": 0.5, "depth_dof": false, "mid_blur": false, "reflection": false, "shadows": false, "particles": 0.0, "bloom": 0.45, "shafts": true}
		1:
			return {"scale": 0.75, "depth_dof": false, "mid_blur": false, "reflection": false, "shadows": true, "particles": 0.5, "bloom": 0.55, "shafts": true}
		_:
			return {"scale": 1.0, "depth_dof": true, "mid_blur": true, "reflection": true, "shadows": true, "particles": 1.0, "bloom": 0.6, "shafts": true}
