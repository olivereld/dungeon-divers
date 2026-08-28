class_name TestPresentationBuilder
extends SceneTree

const _DungeonPresentationBuilderScript = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const _DungeonSemanticResultScript = preload("res://src/dungeon_generator/core/semantic/data/dungeon_semantic_result.gd")
const _KeyDataScript = preload("res://src/dungeon_generator/core/semantic/data/key_data.gd")
const _ObjectiveDataScript = preload("res://src/dungeon_generator/core/semantic/data/objective_data.gd")
const _BiomeProfileScript = preload("res://src/dungeon_generator/presentation/biome_profile.gd")
const _RoomDataScript = preload("res://src/dungeon_generator/core/data/room_data.gd")

func _init() -> void:
	print("--- Running test_presentation_builder ---")

	var builder = _DungeonPresentationBuilderScript.new()
	var profile = _BiomeProfileScript.new()
	var parent_node := Node3D.new()

	var sem_res = _DungeonSemanticResultScript.new()
	sem_res.gameplay_valid = true
	sem_res.rooms.append(_RoomDataScript.new(0, Rect2i(2, 2, 4, 4), &"start"))

	var grid := CellGrid.new(12, 12)
	for y in range(2, 6):
		for x in range(2, 6):
			grid.set_cell(Vector2i(x, y), CellGrid.CellType.FLOOR)
	sem_res.grid = grid

	sem_res.keys.append(_KeyDataScript.new(1, &"key_iron", 0, Vector2i(3, 3)))
	sem_res.objectives.append(_ObjectiveDataScript.new(1, _ObjectiveDataScript.ObjectiveType.SPAWN, 0, Vector2i(2, 2), true))
	sem_res.objectives.append(_ObjectiveDataScript.new(2, _ObjectiveDataScript.ObjectiveType.BOSS, 0, Vector2i(5, 5), true))

	var res = builder.build_presentation(sem_res, parent_node, profile, null, null, true)
	if not res.success:
		for diag in res.diagnostics:
			print("  [DIAG] %s (%s): %s" % [diag.code, diag.severity, diag.message])

	assert(res.success == true, "Builder should return success == true for valid inputs")
	assert(res.staging_committed == true, "staging_committed should be true")
	assert(res.previous_presentation_preserved == false, "previous_presentation_preserved should be false")
	assert(res.presentation_root != null, "presentation_root should be assigned")
	assert(res.total_tiles_rendered > 0, "total_tiles_rendered should be > 0")
	assert(res.spawned_entities.size() >= 1, "Should spawn entities for key/boss")

	var pres_root: Node3D = res.presentation_root
	assert(pres_root.has_node("FloorGridMap"), "Should have FloorGridMap node")
	assert(pres_root.has_node("WallGridMap"), "Should have WallGridMap node")
	assert(pres_root.has_node("Entities"), "Should have Entities node")

	print("  [OK] Presentation builder successfully constructed and committed full 3D layout")

	parent_node.free()

	print("[PASS] test_presentation_builder succeeded with 100% assertions passing!")
	quit(0)
