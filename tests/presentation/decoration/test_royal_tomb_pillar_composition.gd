extends SceneTree

const _DecorationCompPlannerScript = preload("res://src/presentation/decoration/composition/decoration_composition_planner.gd")
const _DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _PresentationRoomGeomScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const _PresentationSeedContextScript = preload("res://src/presentation/architecture/presentation_seed_context.gd")
const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const _SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const _DungeonPresentationBuilderScript = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const _BiomeProfileScript = preload("res://src/dungeon_generator/presentation/biome_profile.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_royal_tomb_pillar_composition ---")
	print("==================================================================")

	var loader := _ProfileLoaderScript.new()
	var royal_prof = loader.load_room("royal_tomb.json")
	assert(royal_prof != null, "FAIL: royal_tomb.json must load")

	var pal_resolver := _DecorationPaletteResolverScript.new()
	# MAUSOLEUM (1), ROYAL_TOMB (14)
	var palette = pal_resolver.resolve_palette(1, 14, null)
	assert(palette != null, "FAIL: palette must resolve")

	# 1. Test isolated composition in a 8x8 Royal Tomb chamber
	var planner := _DecorationCompPlannerScript.new()
	var f_cells: Array[Vector2i] = []
	for x in range(2, 10):
		for y in range(2, 10):
			f_cells.append(Vector2i(x, y))

	var w_cells: Array[Vector2i] = []
	for x in range(1, 11):
		w_cells.append(Vector2i(x, 1))
		w_cells.append(Vector2i(x, 10))
	for y in range(2, 10):
		w_cells.append(Vector2i(1, y))
		w_cells.append(Vector2i(10, y))

	var room_geom = _PresentationRoomGeomScript.new(
		1,
		Rect2i(2, 2, 8, 8),
		f_cells,
		w_cells,
		[Vector2i(5, 2)], # Door north
		null,
		[]
	)

	var room_ctx = {"room_id": 1, "room_purpose": 14, "room_type": "BOSS"}
	var seed_ctx = _PresentationSeedContextScript.for_room(2026, 1)

	var comp = planner.plan_room_composition(
		royal_prof,
		palette,
		room_geom,
		room_ctx,
		null,
		seed_ctx,
		2.0
	)
	assert(comp != null, "FAIL: comp must not be null")

	var central_sarc_pos := Vector3.ZERO
	var central_sarc_found := false
	var pillar_positions: Array[Vector3] = []

	for d in comp.prop_directives:
		if str(d.prop_id).contains("sarcophagus"):
			central_sarc_found = true
			central_sarc_pos = d.world_position
			print("  [OK] Central Sarcophagus placed at: ", d.world_position, " cells: ", d.occupied_cells)
		elif d.prop_id == &"pillar_stone":
			pillar_positions.append(d.world_position)
			print("  [OK] Surrounding Pillar placed at: ", d.world_position, " cells: ", d.occupied_cells)

	assert(central_sarc_found, "FAIL: Central sarcophagus must be placed in Royal Tomb")
	assert(pillar_positions.size() == 4, "FAIL: Exactly 4 pillars must surround the central tomb, got %d" % pillar_positions.size())

	# Verify separation between central sarcophagus and all 4 pillars
	for p_pos in pillar_positions:
		var dist = central_sarc_pos.distance_to(p_pos)
		print("  -> Distance from Central Sarcophagus to Pillar: %.2f m" % dist)
		assert(dist >= 4.0, "FAIL: Pillars must have good spatial separation from central tomb (>= 4.0m), got %.2f" % dist)

	print("  [OK] All 4 pillars surround central tomb with perfect separation (>= 4m).")

	# 2. End-to-end Pipeline Verification
	var config := _DungeonConfigScript.new()
	config.grid_width = 48
	config.grid_height = 48
	config.seed = 2026
	config.dungeon_archetype = 1 # MAUSOLEUM

	var pipeline := _DungeonPipelineScript.new()
	var d_res = pipeline.generate(config)
	assert(d_res != null, "FAIL: Pipeline generate failed")

	var sem_orchestrator := _SemanticOrchestratorScript.new()
	var sem_res = sem_orchestrator.generate_semantics(d_res, config)
	assert(sem_res != null, "FAIL: Semantic orchestration failed")

	var builder := _DungeonPresentationBuilderScript.new()
	var root := Node3D.new()
	var pres_res = builder.build_presentation(sem_res, root, _BiomeProfileScript.new(), config)
	assert(pres_res != null, "FAIL: Presentation build failed")

	var total_pillars_in_dungeon: int = 0
	for entity in pres_res.spawned_entities:
		if entity != null and entity.name.begins_with("Prop_pillar_stone"):
			total_pillars_in_dungeon += 1

	print("  Total 3D pillar_stone entities spawned in full dungeon: %d" % total_pillars_in_dungeon)
	assert(total_pillars_in_dungeon > 0, "FAIL: Expected pillar_stone models to spawn in generated dungeon")

	print("==================================================================")
	print("[PASS] test_royal_tomb_pillar_composition passed with 100% success!")
	print("==================================================================")
	quit(0)
