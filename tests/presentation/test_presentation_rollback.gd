class_name TestPresentationRollback
extends SceneTree

const _DungeonPresentationBuilderScript = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const _DungeonSemanticResultScript = preload("res://src/dungeon_generator/core/semantic/data/dungeon_semantic_result.gd")
const _LockDataScript = preload("res://src/dungeon_generator/core/semantic/data/lock_data.gd")
const _BiomeProfileScript = preload("res://src/dungeon_generator/presentation/biome_profile.gd")

func _init() -> void:
	print("--- Running test_presentation_rollback ---")

	var builder = _DungeonPresentationBuilderScript.new()
	var profile = _BiomeProfileScript.new()
	var parent_node := Node3D.new()

	# Configurar un resultado semántico donde el GridMap es válido pero un Lock apunta a connection inexistente
	var sem_res = _DungeonSemanticResultScript.new()
	sem_res.gameplay_valid = true
	var grid := CellGrid.new(10, 10)
	grid.set_cell(Vector2i(2, 2), CellGrid.CellType.FLOOR)
	sem_res.grid = grid

	# Lock inválido -> MISSING_DOOR_PAIR con severidad ERROR
	sem_res.locks.append(_LockDataScript.new(1, 999, 0, 1, 1))

	var res = builder.build_presentation(sem_res, parent_node, profile, null, null, true)

	assert(res.success == false, "Build must fail when entity spawning produces blocking ERROR")
	assert(res.staging_committed == false, "Staging must not be committed")
	assert(parent_node.get_child_count() == 0, "Parent node must remain clean with 0 orphan nodes after rollback")
	assert(res.has_blocking_errors() == true, "Result must contain blocking ERROR")

	var has_missing_door_pair: bool = false
	for d in res.diagnostics:
		if d.get("code") == "MISSING_DOOR_PAIR":
			has_missing_door_pair = true
			break
	assert(has_missing_door_pair == true, "Diagnostics must contain MISSING_DOOR_PAIR")

	print("  [OK] Rollback verified: StagingRoot destroyed and 0 orphan nodes left on entity spawn failure")

	parent_node.free()

	print("[PASS] test_presentation_rollback succeeded with 100% assertions passing!")
	quit(0)
