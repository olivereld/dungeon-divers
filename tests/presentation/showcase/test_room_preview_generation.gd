extends SceneTree

const RoomArchetypeLabGeneratorScript = preload("res://src/presentation/showcase/room_archetype_lab/room_archetype_lab_generator.gd")
const RoomPreviewRequestScript = preload("res://src/presentation/showcase/room_archetype_lab/room_preview_request.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_room_preview_generation ---")
	print("==================================================================")

	var generator := RoomArchetypeLabGeneratorScript.new()

	# 1. Generación de sala aislada para NECROPOLIS + TOMB
	var req_tomb := RoomPreviewRequestScript.new(
		&"necropolis", &"tomb", 12345, Vector2i(10, 8)
	)
	var res_tomb = generator.generate_preview(req_tomb)

	assert(res_tomb != null and res_tomb.success, "FAIL: Failed to generate TOMB preview")
	assert(res_tomb.room_root != null, "FAIL: Room root node is null")
	assert(res_tomb.composition != null, "FAIL: Composition is null")
	assert(res_tomb.diagnostics.get("props_count", 0) > 0, "FAIL: Expected props in TOMB preview")
	assert(res_tomb.diagnostics.get("fixtures_count", 0) > 0, "FAIL: Expected fixtures in TOMB preview")
	assert(res_tomb.diagnostics.get("occupied_cells_count", 0) > 0, "FAIL: Expected occupied cells in TOMB preview")

	print("  [OK] Isolated TOMB preview generation verified (Props: %d, Fixtures: %d, Occupied: %d)." % [
		res_tomb.diagnostics.get("props_count", 0),
		res_tomb.diagnostics.get("fixtures_count", 0),
		res_tomb.diagnostics.get("occupied_cells_count", 0)
	])

	# 2. Determinismo bit a bit: Segunda corrida con exactamente los mismos parámetros
	var res_tomb_repeat = generator.generate_preview(req_tomb)
	assert(res_tomb_repeat.success, "FAIL: Repeat generation failed")
	assert(res_tomb.diagnostics == res_tomb_repeat.diagnostics, "FAIL: Diagnostics must match identically across repeated runs")
	assert(res_tomb.composition.occupied_cells == res_tomb_repeat.composition.occupied_cells, "FAIL: Occupied cells must match identically")

	for i in range(res_tomb.composition.prop_directives.size()):
		var p1 = res_tomb.composition.prop_directives[i]
		var p2 = res_tomb_repeat.composition.prop_directives[i]
		assert(p1.prop_id == p2.prop_id, "FAIL: Prop ID mismatch at index %d" % i)
		assert(p1.world_position == p2.world_position, "FAIL: Prop position mismatch at index %d" % i)
		assert(p1.rotation_degrees_y == p2.rotation_degrees_y, "FAIL: Prop rotation mismatch at index %d" % i)

	print("  [OK] Absolute determinism across identical requests verified.")

	# 3. Validación de rechazo de combinación incompatible
	var req_invalid := RoomPreviewRequestScript.new(
		&"necropolis", &"barracks", 12345
	)
	var res_invalid = generator.generate_preview(req_invalid)
	assert(not res_invalid.success, "FAIL: Incompatible purpose must return success == false")
	assert(res_invalid.error_message != "", "FAIL: Error message should be populated")
	print("  [OK] Incompatible combination rejection verified.")

	# Liberar memoria de nodos creados
	res_tomb.room_root.free()
	res_tomb_repeat.room_root.free()

	print("[PASS] test_room_preview_generation completed successfully!")
	quit(0)
