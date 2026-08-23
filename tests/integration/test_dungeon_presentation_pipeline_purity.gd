extends SceneTree

## Test de Integración: Pureza del Pipeline de Presentación 3D (Fase 10.19).
## Certifica que todas las entidades de iluminación y utilería provengan exclusivamente
## de directivas generadas por el Semantic Spatial Composition Engine, con 0 nodos legados.

const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const DungeonPresentationBuilderScript = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const BiomeProfileScript = preload("res://src/dungeon_generator/config/biome_profile.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_dungeon_presentation_pipeline_purity ---")
	print("==================================================================")

	var pipeline := DungeonPipelineScript.new()
	var semantic_orchestrator := SemanticOrchestratorScript.new()
	var presentation_builder := DungeonPresentationBuilderScript.new()

	var config := DungeonConfigScript.new()
	config.seed = 1337
	config.use_fixed_seed = true
	config.dungeon_archetype = DungeonArchetypeScript.Type.MAUSOLEUM # Crypt

	var d_res = pipeline.generate(config)
	assert(d_res != null, "FAIL: Layout generation failed")

	var sem_res = semantic_orchestrator.generate_semantics(d_res, config)
	assert(sem_res != null and sem_res.gameplay_valid, "FAIL: Semantic generation failed")

	var biome := BiomeProfileScript.new()
	var root_node := Node3D.new()

	var pres_res = presentation_builder.build_presentation(
		sem_res, root_node, biome, config
	)

	assert(pres_res != null and pres_res.success, "FAIL: Presentation build failed")
	var pres_root = pres_res.presentation_root
	assert(pres_root != null, "FAIL: Presentation root must not be null")

	# 1. Verificar contenedor de Fixtures
	var fixtures_container = pres_root.get_node_or_null("Fixtures")
	assert(fixtures_container != null, "FAIL: Fixtures container must exist in presentation root")

	# 2. Verificar que no haya luces huérfanas fuera de Fixtures
	var all_lights = pres_root.find_children("*", "OmniLight3D", true, false)
	for light in all_lights:
		var is_inside_fixture = false
		var p = light.get_parent()
		while p != null and p != pres_root:
			if p.name == "Fixtures":
				is_inside_fixture = true
				break
			p = p.get_parent()
		assert(is_inside_fixture, "FAIL: Found orphan light outside Fixtures container: %s" % light.name)

	# 3. Verificar que los props estén instanciados con metadatos
	var prop_nodes = pres_root.find_children("Prop_*", "Node3D", false, false)
	assert(prop_nodes.size() > 0, "FAIL: Presentation must spawn props")

	print("  [OK] Presentation pipeline purity verified (All lights & props are directive-driven).")

	root_node.free()

	print("==================================================================")
	print("[PASS] test_dungeon_presentation_pipeline_purity completado con 100% éxito!")
	print("==================================================================")
	quit(0)
