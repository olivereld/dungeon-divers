extends SceneTree

const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const DungeonPresentationBuilderScript = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const BiomeProfileScript = preload("res://src/dungeon_generator/config/biome_profile.gd")

func _init() -> void:
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	print("==================================================================")
	print("--- Running test_fixture_end_to_end ---")
	print("==================================================================")

	var cfg := DungeonConfigScript.new()
	cfg.seed = 112233
	cfg.use_fixed_seed = true
	cfg.dungeon_archetype = &"necropolis"

	var pipeline := DungeonPipelineScript.new()
	var res = pipeline.generate(cfg, 5, true)
	var orchestrator := SemanticOrchestratorScript.new()
	var sem = orchestrator.generate_semantics(res, cfg)

	var pres_builder := DungeonPresentationBuilderScript.new()
	var parent_node := Node3D.new()
	root.add_child(parent_node)

	var biome := BiomeProfileScript.new()
	var pres_res = pres_builder.build_presentation(sem, parent_node, biome, cfg)

	assert(pres_res != null, "FAIL: Presentation result cannot be null")
	assert(not pres_res.has_blocking_errors(), "FAIL: Blocking errors detected in presentation")
	assert(pres_res.total_tiles_rendered > 0, "FAIL: Tiles rendered must be > 0")

	# Verificar que existen entidades de fixtures en presentation_root
	var fixtures_container = pres_res.presentation_root.get_node_or_null("Fixtures")
	assert(fixtures_container != null, "FAIL: Fixtures container missing")
	var staging_fixtures = fixtures_container.get_children()
	assert(not staging_fixtures.is_empty(), "FAIL: No fixtures materialized in 3D presentation staging")

	for fix in staging_fixtures:
		assert(fix.has_meta("fixture_directive"), "FAIL: Fixture node missing fixture_directive meta")
		assert(fix.has_meta("room_id"), "FAIL: Fixture node missing room_id meta")

	parent_node.queue_free()

	print("  [OK] End-to-end 3D architectural fixtures verified in presentation staging (%d fixtures spawned)." % staging_fixtures.size())
	print("[PASS] test_fixture_end_to_end completed successfully!")
	quit(0)
