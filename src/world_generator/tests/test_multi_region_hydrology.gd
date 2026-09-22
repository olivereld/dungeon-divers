extends SceneTree

const _ChunkWorldScript = preload("res://src/world_generator/chunks/chunk_world.gd")
const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")
const _AutumnForestWorldProfileScript = preload("res://src/world_generator/profiles/autumn_forest_world_profile.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")

func _init() -> void:
	print("==================================================")
	print(" TEST: HIDROLOGIA MULTIRREGION EN MUNDO INFINITO")
	print("==================================================")

	var profile := _AutumnForestWorldProfileScript.new()
	var config := _ChunkConfigScript.new(16, 1)
	var seed_val := 12345

	var chunk_world: ChunkWorld = _ChunkWorldScript.new()
	var initial_hydro: HydrologyResult = _WorldPipelineScript.generate_regional_hydrology(seed_val, profile)
	chunk_world.initialize(seed_val, profile, config, initial_hydro)

	print("[1/4] Estado inicial: macro-region (0, 0)...")
	print("      Lagos iniciales: %d, Rios iniciales: %d, Celdas de agua: %d" % [
		chunk_world.shared_hydrology.lakes.size(),
		chunk_world.shared_hydrology.rivers.size(),
		chunk_world.shared_hydrology.water_cells.size()
	])
	var init_water_cells := chunk_world.shared_hydrology.water_cells.size()
	assert(init_water_cells > 0, "Region inicial debe tener celdas de agua")

	print("[2/4] Solicitando chunks lejanos en macro-region (2, 2) (coords chunk: (8, 8) a (11, 11))...")
	var distant_chunk_coord := Vector2i(8, 8)
	var distant_chunk: RefCounted = chunk_world.chunk_manager.load_chunk(distant_chunk_coord)
	assert(distant_chunk != null, "distant_chunk debe generarse")

	print("      Celdas de agua acumuladas en shared_hydrology: %d" % chunk_world.shared_hydrology.water_cells.size())
	assert(chunk_world.shared_hydrology.water_cells.size() > init_water_cells, "shared_hydrology debe haber crecido al incorporar nueva macro-region")

	var distant_lakes: int = chunk_world.shared_hydrology.lakes.size()
	var distant_rivers: int = chunk_world.shared_hydrology.rivers.size()
	print("      Lagos totales: %d, Rios totales: %d" % [distant_lakes, distant_rivers])
	assert(distant_lakes >= initial_hydro.lakes.size(), "Lagos totales deben mantenerse o aumentar")

	print("[3/4] Solicitando chunks en coordenadas negativas (macro-region (-2, -1))...")
	var neg_chunk_coord := Vector2i(-8, -4)
	var neg_chunk: RefCounted = chunk_world.chunk_manager.load_chunk(neg_chunk_coord)
	assert(neg_chunk != null, "neg_chunk debe generarse")

	print("      Celdas de agua tras coordenadas negativas: %d" % chunk_world.shared_hydrology.water_cells.size())

	print("[4/4] Verificando consulta espacial en indices de macro-region...")
	var query_bounds := Rect2i(128, 128, 32, 32)
	var segs: Array = chunk_world.shared_hydrology.spatial_index.query_river_segments(query_bounds)
	var lakes: Array = chunk_world.shared_hydrology.spatial_index.query_lakes(query_bounds)
	print("      Consulta espacial en (128, 128, 32, 32): %d segmentos de rio, %d lagos" % [segs.size(), lakes.size()])

	print("==================================================")
	print(" TEST MULTIRREGION: EXITOSO (Rios y lagos generados en todo el mundo)")
	print("==================================================")
	quit(0)
