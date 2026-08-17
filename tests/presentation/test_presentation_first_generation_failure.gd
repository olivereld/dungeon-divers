class_name TestPresentationFirstGenerationFailure
extends SceneTree

const _DungeonPresentationBuilderScript = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const _DungeonSemanticResultScript = preload("res://src/dungeon_generator/core/semantic/data/dungeon_semantic_result.gd")
const _BiomeProfileScript = preload("res://src/dungeon_generator/presentation/biome_profile.gd")

func _init() -> void:
	print("--- Running test_presentation_first_generation_failure ---")

	var builder = _DungeonPresentationBuilderScript.new()
	var profile = _BiomeProfileScript.new()
	var parent_node := Node3D.new()

	# Caso: Primera generación fallida sin presentación previa existente
	var sem_res_fail = _DungeonSemanticResultScript.new()
	sem_res_fail.gameplay_valid = false # Fallo forzado
	sem_res_fail.grid = CellGrid.new(10, 10)

	var res = builder.build_presentation(sem_res_fail, parent_node, profile, null, null, true)

	assert(res.success == false, "Build must fail when semantic result is invalid")
	assert(res.staging_committed == false, "Staging must not be committed")
	assert(res.previous_presentation_preserved == false, "previous_presentation_preserved must be false when no previous presentation existed")
	assert(res.presentation_root == null, "presentation_root must be null on initial generation failure")
	assert(parent_node.get_child_count() == 0, "Parent node must remain completely clean with 0 orphan nodes")
	assert(res.has_blocking_errors() == true, "Result must contain blocking error diagnostics")
	assert(res.diagnostics.size() > 0, "Diagnostics must explain the failure cause explicitly")

	print("  [OK] First generation failure cleanly handled: presentation_root == null, 0 orphan nodes, diagnostics present")

	parent_node.free()

	print("[PASS] test_presentation_first_generation_failure succeeded with 100% assertions passing!")
	quit(0)
