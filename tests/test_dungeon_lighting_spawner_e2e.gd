extends SceneTree

const DungeonPresentationBuilder = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const DungeonPipeline = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestrator = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const DungeonConfig = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const BiomeProfile = preload("res://src/dungeon_generator/presentation/biome_profile.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_dungeon_lighting_spawner_e2e ---")
	print("==================================================================")

	var config := DungeonConfig.new()
	config.seed = 45678
	config.use_fixed_seed = true
	var biome := BiomeProfile.new()

	var pipeline := DungeonPipeline.new()
	var d_res = pipeline.generate(config)
	assert(d_res != null, "DungeonResult generated")

	var sem_orch := SemanticOrchestrator.new()
	var sem_res = sem_orch.generate_semantics(d_res, config)
	assert(sem_res != null and sem_res.gameplay_valid, "SemanticResult valid")

	var builder := DungeonPresentationBuilder.new()
	var pres_res = builder.build_presentation(sem_res, null, biome, config)

	assert(pres_res.success == true, "Presentation build success")
	var staging = pres_res.presentation_root
	assert(staging != null, "Presentation root exists")

	var lighting_node = staging.get_node_or_null("Lighting")
	assert(lighting_node != null, "Lighting node exists in hierarchy")
	assert(lighting_node.has_node("RoomLights"), "RoomLights container exists")
	assert(lighting_node.has_node("CorridorLights"), "CorridorLights container exists")

	var total_omnis: int = 0
	var room_lights = lighting_node.get_node("RoomLights")
	for torch in room_lights.get_children():
		var omni = torch.get_node_or_null("OmniLight3D")
		if omni != null:
			total_omnis += 1
			assert(omni.light_energy > 0.0, "OmniLight has positive energy")
			assert(torch.has_node("FlickerController"), "FlickerController attached to torch")

	assert(total_omnis > 0, "Room OmniLights spawned successfully (total: %d)" % total_omnis)
	print("  [OK] Hierarchy Lighting/RoomLights and CorridorLights validated (%d torches)." % total_omnis)

	staging.free()

	print("==================================================================")
	print("[PASS] test_dungeon_lighting_spawner_e2e completado con éxito!")
	print("==================================================================")
	quit(0)
