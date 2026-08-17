class_name TestPresentationAtomicSwap
extends SceneTree

const _DungeonPresentationBuilderScript = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const _DungeonSemanticResultScript = preload("res://src/dungeon_generator/core/semantic/data/dungeon_semantic_result.gd")
const _BiomeProfileScript = preload("res://src/dungeon_generator/presentation/biome_profile.gd")

func _init() -> void:
	print("--- Running test_presentation_atomic_swap ---")

	var builder = _DungeonPresentationBuilderScript.new()
	var profile = _BiomeProfileScript.new()
	var parent_node := Node3D.new()

	# 1. Crear una presentación válida inicial (A)
	var sem_res_a = _DungeonSemanticResultScript.new()
	sem_res_a.gameplay_valid = true
	var grid_a := CellGrid.new(10, 10)
	grid_a.set_cell(Vector2i(2, 2), CellGrid.CellType.FLOOR)
	sem_res_a.grid = grid_a

	var res_a = builder.build_presentation(sem_res_a, parent_node, profile, null, null, true)
	assert(res_a.success == true, "Initial presentation build must succeed")
	assert(res_a.presentation_root != null, "Active root should be created")
	assert(parent_node.get_child_count() == 1, "Parent node should have 1 child (presentation A)")
	var node_a = res_a.presentation_root

	print("  [OK] Initial presentation A successfully built and attached to active tree")

	# 2. Intentar construir una presentación inválida (B) con fallo forzado (gameplay_valid = false)
	var sem_res_b = _DungeonSemanticResultScript.new()
	sem_res_b.gameplay_valid = false # Fallo forzado
	sem_res_b.grid = CellGrid.new(10, 10)

	var res_b = builder.build_presentation(sem_res_b, parent_node, profile, null, node_a, true)

	# 3. Verificación de Swap Atómico y Preservación
	assert(res_b.success == false, "Invalid build must fail")
	assert(res_b.staging_committed == false, "Staging must NOT be committed")
	assert(res_b.previous_presentation_preserved == true, "previous_presentation_preserved must be true")
	assert(res_b.presentation_root == node_a, "Active root must remain node A")
	assert(parent_node.get_child_count() == 1, "Parent must STILL have exactly 1 child")
	assert(parent_node.get_child(0) == node_a, "Node A must remain in active tree unmodified")
	assert(res_b.has_blocking_errors() == true, "Should have blocking error diagnostics")

	print("  [OK] Atomic swap verified: Presentation A preserved intact in tree after failed generation B")

	node_a.free()
	parent_node.free()

	print("[PASS] test_presentation_atomic_swap succeeded with 100% assertions passing!")
	quit(0)
