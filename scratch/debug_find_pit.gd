extends SceneTree

const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _AutumnForestWorldProfileScript = preload("res://src/world_generator/profiles/autumn_forest_world_profile.gd")
const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")

func _init() -> void:
	var seed_val: int = 12345
	var profile = _AutumnForestWorldProfileScript.new()
	var config := _ChunkConfigScript.new(16, 1, 4)

	var shared_hydrology = _WorldPipelineScript.generate_regional_hydrology(seed_val, profile)
	
	# Buscar en los chunks cargados alrededor del jugador (0, 6), como (0,5), (1,5), (1,6), (0,6), etc.
	for cy in range(4, 9):
		for cx in range(0, 3):
			var c = _WorldPipelineScript.generate_chunk(seed_val, Vector2i(cx, cy), profile, config, shared_hydrology)
			# buscar celdas donde la altura sea menor que sus vecinas inmediatas
			for y in range(c.core_bounds.position.y, c.core_bounds.position.y + c.core_bounds.size.y):
				for x in range(c.core_bounds.position.x, c.core_bounds.position.x + c.core_bounds.size.x):
					var pos = Vector2i(x, y)
					var cell = c.get_cell(pos)
					if cell == null: continue
					var is_w = shared_hydrology.water_cells.has(pos)
					# Revisar vecinos cardinales
					var card_higher = 0
					var card_equal = 0
					var card_lower = 0
					for off in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
						var np = pos + off
						var nc = c.get_cell_or_seam(np) if c.has_method("get_cell_or_seam") else c.get_cell(np)
						if nc != null:
							if nc.height > cell.height: card_higher += 1
							elif nc.height == cell.height: card_equal += 1
							else: card_lower += 1
					
					# Si tiene 3 o 4 vecinos más altos, es un agujero/muesca en el suelo!
					if card_higher >= 3:
						print("¡Agujero/Muesca detectado en %s (Chunk %d,%d)!" % [str(pos), cx, cy])
						print("  Altura: %.2f, is_water: %s, raw_height: %.2f" % [cell.height, is_w, cell.raw_height])
						print("  Card higher: %d, equal: %d, lower: %d" % [card_higher, card_equal, card_lower])

	quit(0)
