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

	# Test local query for cells around player: (29, 18) to (32, 21)
	for y in range(17, 22):
		for x in range(28, 33):
			var pos := Vector2i(x, y)
			var is_w = shared_hydrology.water_cells.has(pos)
			var wh = 0.0
			var sdf = 0.0
			if is_w:
				wh = float(shared_hydrology.water_cells[pos].get("water_height", 0.0))
				var has_dry_neighbor = false
				for off in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
					if not shared_hydrology.water_cells.has(pos + off):
						has_dry_neighbor = true
						break
				sdf = 0.65 if has_dry_neighbor else 1.0
			else:
				var min_d_sq = 999.0
				var nearest_h = 0.0
				for dy in range(-3, 4):
					for dx in range(-3, 4):
						var np = pos + Vector2i(dx, dy)
						if shared_hydrology.water_cells.has(np):
							var d_sq = float(dx * dx + dy * dy)
							if d_sq < min_d_sq:
								min_d_sq = d_sq
								nearest_h = float(shared_hydrology.water_cells[np].get("water_height", 0.0))
				if min_d_sq < 900.0:
					var dist = sqrt(min_d_sq)
					wh = nearest_h
					var signed_dist = -(dist - 0.5)
					sdf = clampf(0.5 + signed_dist / 6.0, 0.0, 0.49)
				else:
					wh = 0.0
					sdf = 0.0
			print("pos=(%d,%d) is_w=%s wh=%.2f sdf=%.3f" % [x, y, is_w, wh, sdf])

	quit(0)
