extends SceneTree

## Architecture Regression Test Central
## Valida que todo el pipeline (Data -> ArchetypeCatalog -> ProfileLoader -> Resolvers -> Generation -> Presentation)
## opera de manera 100% data-driven y extensible sin condicionales ni enums hardcodeados en GDScript.

const ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const ArchetypeCatalogScript = preload("res://src/dungeon_generator/profiles/archetype_catalog.gd")
const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const PresentationProfileResolverScript = preload("res://src/presentation/architecture/presentation_profile_resolver.gd")
const PresentationContextBuilderScript = preload("res://src/presentation/architecture/presentation_context_builder.gd")
const DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const DungeonPresentationBuilderScript = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const _BiomeProfileScript = preload("res://src/dungeon_generator/presentation/biome_profile.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_data_driven_architecture ---")
	print("==================================================================")

	var loader := ProfileLoaderScript.new()
	var pres_resolver := PresentationProfileResolverScript.new()
	var pal_resolver := DecorationPaletteResolverScript.new()
	var pipeline := DungeonPipelineScript.new()
	var orchestrator := SemanticOrchestratorScript.new()
	var context_builder := PresentationContextBuilderScript.new()
	var pres_builder := DungeonPresentationBuilderScript.new()

	# 1. Descubrimiento dinámico de arquetipos desde configuración
	var discovered_archetypes: Array[StringName] = loader.list_available_archetypes()
	assert(not discovered_archetypes.is_empty(), "FAIL: ArchetypeCatalog must dynamically discover available archetypes")

	var total_loaded_profiles: int = 0
	var total_resolved_presentation: int = 0
	var total_resolved_decoration: int = 0
	var total_generated_success: int = 0

	for arch_id in discovered_archetypes:
		# 2. Cargar ProfileBundle
		var bundle = loader.load_full_archetype_bundle(str(arch_id))
		assert(bundle != null and bundle.archetype != null, "FAIL: Must load bundle for archetype '%s'" % str(arch_id))
		assert(bundle.archetype.schema_version == 1, "FAIL: Archetype '%s' schema_version must be 1" % str(arch_id))
		total_loaded_profiles += 1

		# 3. Resolver perfiles arquitectónicos y de decoración para todas las salas declaradas
		assert(not bundle.rooms.is_empty(), "FAIL: Archetype '%s' must declare at least one room" % str(arch_id))
		for room_id in bundle.rooms:
			var room_prof = bundle.rooms[room_id]
			assert(room_prof != null, "FAIL: Room profile '%s' in archetype '%s' cannot be null" % [str(room_id), str(arch_id)])

			var arch_style = pres_resolver.resolve_from_room_profile(room_prof)
			assert(arch_style != null, "FAIL: Failed to resolve ArchitecturalStyle for room '%s'" % str(room_id))
			total_resolved_presentation += 1

			var dec_palette = pal_resolver.resolve_palette_by_id(arch_id, room_id)
			assert(dec_palette != null, "FAIL: Failed to resolve DecorationPalette for room '%s'" % str(room_id))
			total_resolved_decoration += 1

		# 4. Ejecutar pipeline de generación semántica y presentación mínima
		var config := DungeonConfigScript.new()
		config.seed = 54321
		config.archetype_id = arch_id

		var dungeon_res = pipeline.generate(config)
		assert(dungeon_res != null and dungeon_res.grid != null, "FAIL: Generation failed for archetype '%s'" % str(arch_id))

		var semantic_res = orchestrator.generate_semantics(dungeon_res, config)
		assert(semantic_res != null and semantic_res.gameplay_valid, "FAIL: Semantic generation failed for archetype '%s'" % str(arch_id))
		assert(semantic_res.archetype_id == arch_id, "FAIL: Semantic result archetype_id must match requested archetype")

		var room_contexts = context_builder.build_contexts(semantic_res)
		assert(room_contexts.size() == dungeon_res.rooms.size(), "FAIL: Context count must match room count")

		for ctx in room_contexts:
			assert(ctx.room_profile != null, "FAIL: Every room context must carry a resolved ProfileRoom")

		var parent_node := Node3D.new()
		var biome := _BiomeProfileScript.new()
		var pres_result = pres_builder.build_presentation(semantic_res, parent_node, biome, config)
		assert(pres_result != null and pres_result.success, "FAIL: Presentation build failed for archetype '%s'" % str(arch_id))
		parent_node.free()

		total_generated_success += 1

	# 5. Escáner Anti-Hardcoding (Fase J)
	_verify_no_hardcoded_archetype_branching()

	print("------------------------------------------------------------------")
	print("Discovered archetypes: %d" % discovered_archetypes.size())
	print("Loaded profiles: %d" % total_loaded_profiles)
	print("Resolved presentation profiles: %d" % total_resolved_presentation)
	print("Resolved decoration profiles: %d" % total_resolved_decoration)
	print("Generated successfully: %d" % total_generated_success)
	print("Architecture validation: PASS")
	print("==================================================================")
	print("[PASS] test_data_driven_architecture completado con 100% éxito!")
	print("==================================================================")
	quit(0)

func _verify_no_hardcoded_archetype_branching() -> void:
	var critical_files: Array[String] = [
		"res://src/dungeon_generator/profiles/profile_loader.gd",
		"res://src/dungeon_generator/profiles/archetype_catalog.gd",
		"res://src/dungeon_generator/profiles/room_profile_resolver.gd",
		"res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd",
		"res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd",
		"res://src/presentation/architecture/presentation_profile_resolver.gd",
		"res://src/presentation/architecture/presentation_context_builder.gd",
		"res://src/presentation/decoration/decoration_palette_resolver.gd"
	]

	var forbidden_patterns: Array[String] = [
		"if archetype_id == &\"necropolis\"",
		"if arch_id == &\"necropolis\"",
		"if target_arch_id == &\"necropolis\"",
		"match archetype_id:",
		"match arch_id:"
	]

	for file_path in critical_files:
		if not FileAccess.file_exists(file_path):
			continue
		var f := FileAccess.open(file_path, FileAccess.READ)
		if f == null:
			continue
		var content := f.get_as_text()
		f.close()

		for pattern in forbidden_patterns:
			assert(not content.contains(pattern), "FAIL: Forbidden hardcoded domain branching '%s' found in '%s'" % [pattern, file_path])

	print("  [OK] Anti-hardcoding scanner passed (0 domain branch regressions detected).")
