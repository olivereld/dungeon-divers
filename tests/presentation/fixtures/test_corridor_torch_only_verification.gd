extends SceneTree

const DungeonPipeline = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestrator = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const DungeonPresentationBuilder = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const BiomeProfile = preload("res://src/dungeon_generator/presentation/biome_profile.gd")
const DungeonConfig = preload("res://src/dungeon_generator/config/dungeon_config.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_corridor_torch_only_verification ---")
	print("==================================================================")

	var config := DungeonConfig.new()
	config.grid_width = 40
	config.grid_height = 40
	config.seed = 1337
	config.dungeon_archetype = 1 # MAUSOLEUM

	var pipeline := DungeonPipeline.new()
	var dungeon_res = pipeline.generate(config)
	assert(dungeon_res != null, "FAIL: dungeon_res is null")

	var semantic_orchestrator := SemanticOrchestrator.new()
	var sem_res = semantic_orchestrator.generate_semantics(dungeon_res, config)
	assert(sem_res != null, "FAIL: sem_res is null")

	var presentation_builder := DungeonPresentationBuilder.new()
	var root_node := Node3D.new()
	var biome := BiomeProfile.new()

	var pres_res = presentation_builder.build_presentation(sem_res, root_node, biome, config)
	assert(pres_res != null, "FAIL: pres_res is null")

	var spawned_entities = pres_res.spawned_entities
	var corridor_fixtures_found: int = 0
	var non_torch_corridor_fixtures: int = 0

	for entity in spawned_entities:
		if entity != null and entity.name.begins_with("Fixture_"):
			var light: OmniLight3D = entity.find_child("Light3D", true, false) as OmniLight3D
			if light == null:
				light = entity.find_child("*Light*", true, false) as OmniLight3D

			if light != null:
				var c: Color = light.light_color
				# Si coincide con el color de corredor (#D6B36A)
				if is_equal_approx(c.r, Color("#D6B36A").r) and is_equal_approx(c.g, Color("#D6B36A").g) and is_equal_approx(c.b, Color("#D6B36A").b):
					corridor_fixtures_found += 1
					var entity_name := String(entity.name).to_lower()
					if not entity_name.contains("torch"):
						non_torch_corridor_fixtures += 1
						print("  FAIL: Found non-torch fixture in corridor: ", entity.name)
					else:
						print("  [OK] Confirmed corridor fixture is a TORCH: ", entity.name, " with color #D6B36A")

	print("  Total corridor torches verified: %d" % corridor_fixtures_found)
	assert(corridor_fixtures_found > 0, "FAIL: Expected corridor torches to be spawned")
	assert(non_torch_corridor_fixtures == 0, "FAIL: Non-torch fixtures found in corridor!")

	print("  [OK] 100% of corridor fixtures are strictly TORCHES with color #D6B36A.")
	print("==================================================================")
	print("[PASS] test_corridor_torch_only_verification passed successfully!")
	print("==================================================================")
	quit(0)
