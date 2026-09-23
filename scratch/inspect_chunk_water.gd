extends SceneTree

const _AutumnForestWorldProfileScript = preload("res://src/world_generator/profiles/autumn_forest_world_profile.gd")
const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _ChunkWorldScript = preload("res://src/world_generator/chunks/chunk_world.gd")

func _init() -> void:
	var seed_val = 12345
	var profile = _AutumnForestWorldProfileScript.new()
	var config = _ChunkConfigScript.new(16, 1, 2)
	var shared_hydrology = _WorldPipelineScript.generate_regional_hydrology(seed_val, profile)

	var chunk_world = _ChunkWorldScript.new()
	chunk_world.initialize(seed_val, profile, config, shared_hydrology, 2)
	chunk_world.load_initial_area(Vector2i.ZERO, 2)

	for r_idx in range(shared_hydrology.rivers.size()):
		var r = shared_hydrology.rivers[r_idx]
		print("River %d: pts=%d levels=%s" % [r_idx, r.points.size(), str(r.levels)])
		for i in range(r.points.size()):
			var p = r.points[i]
			var path_p = r.path[i]
			print("  pt[%d]: path=%s p3d=(%.2f, %.2f, %.2f) w=%.2f d=%.2f lvl=%d" % [i, str(path_p), p.x, p.y, p.z, r.widths[i], r.depths[i], r.levels[i]])
	for y in range(16, 24):
		for x in range(27, 34):
			var pos := Vector2i(x, y)
			var c = chunk_world.get_cell_at_world_pos(pos)
			var is_water = shared_hydrology.is_water(pos)
			var wh = shared_hydrology.get_water_height(pos, -999.0)
			var h = c.height if c != null else -999.0
			var lvl = c.elevation_level if c != null else -1
			var data = shared_hydrology.water_cells.get(pos, {})
			var bed = data.get("bed_height", -999.0)
			var type = data.get("type", "none")
			var r_id = data.get("river_index", -1)
			print("pos=(%d,%d) lvl=%d h=%.2f is_water=%s wh=%.2f bed=%.2f type=%s r_id=%d" % [x, y, lvl, h, is_water, wh, bed, type, r_id])

	quit(0)
