extends SceneTree

const LightPlacement = preload("res://src/dungeon_lighting/data/light_placement.gd")
const LightingResult = preload("res://src/dungeon_lighting/data/lighting_result.gd")
const DungeonLightingConfig = preload("res://src/dungeon_lighting/config/dungeon_lighting_config.gd")
const LightingProfile = preload("res://src/dungeon_lighting/config/lighting_profile.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_lighting_contracts ---")
	print("==================================================================")

	var p := LightPlacement.new()
	p.light_id = 1
	p.cell = Vector2i(10, 15)
	p.wall_side = LightPlacement.WallSide.NORTH
	p.room_id = 3
	p.kind = &"torch"
	assert(p.cell == Vector2i(10, 15), "LightPlacement cell ok")
	assert(p.wall_side == LightPlacement.WallSide.NORTH, "LightPlacement wall_side ok")

	var res := LightingResult.new()
	res.placements.append(p)
	assert(res.placements.size() == 1, "LightingResult placements ok")
	assert(res.has_lights() == true, "LightingResult has_lights ok")

	var cfg := DungeonLightingConfig.new()
	assert(cfg.enabled == true, "Config enabled by default")
	assert(cfg.min_lights_per_room == 1, "min_lights_per_room ok")
	assert(cfg.max_lights_per_room == 4, "max_lights_per_room ok")
	assert(cfg.min_light_spacing >= 3.0, "min_light_spacing ok")

	var prof := LightingProfile.new()
	assert(prof.light_color != Color.BLACK, "Profile has default color")
	assert(prof.flicker_enabled == true, "Profile has flicker enabled")
	assert(prof.energy > 0.0, "Profile has positive energy")

	print("==================================================================")
	print("[PASS] test_lighting_contracts completado con éxito!")
	print("==================================================================")
	quit(0)
