extends SceneTree

const RoomArchetypeLabGeneratorScript = preload("res://src/presentation/showcase/room_archetype_lab/room_archetype_lab_generator.gd")
const RoomPreviewRequestScript = preload("res://src/presentation/showcase/room_archetype_lab/room_preview_request.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_crypt_room_purposes ---")
	print("==================================================================")

	var generator := RoomArchetypeLabGeneratorScript.new()

	var purposes = [
		RoomPurposeScript.Type.TOMB,
		RoomPurposeScript.Type.SACRISTY,
		RoomPurposeScript.Type.MORTUARY,
		RoomPurposeScript.Type.CRYPT
	]

	for purp in purposes:
		var req := RoomPreviewRequestScript.new(
			DungeonArchetypeScript.Type.MAUSOLEUM, purp, 424242, Vector2i(10, 8)
		)
		var res = generator.generate_preview(req)
		assert(res != null and res.success, "FAIL: Generation failed for purpose: %s" % RoomPurposeScript.to_name(purp))
		assert(res.diagnostics.get("props_count", 0) > 0, "FAIL: Zero props for purpose: %s" % RoomPurposeScript.to_name(purp))
		assert(res.diagnostics.get("fixtures_count", 0) > 0, "FAIL: Zero fixtures for purpose: %s" % RoomPurposeScript.to_name(purp))
		assert(res.diagnostics.get("occupied_cells_count", 0) > 0, "FAIL: Zero occupied cells for purpose: %s" % RoomPurposeScript.to_name(purp))

		print("  [OK] Purpose %s generated successfully (Props: %d, Fixtures: %d, Occupied: %d)." % [
			RoomPurposeScript.to_name(purp),
			res.diagnostics.get("props_count", 0),
			res.diagnostics.get("fixtures_count", 0),
			res.diagnostics.get("occupied_cells_count", 0)
		])
		res.room_root.free()

	print("[PASS] test_crypt_room_purposes completed successfully!")
	quit(0)
