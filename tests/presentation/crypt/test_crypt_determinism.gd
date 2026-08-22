extends SceneTree

const RoomArchetypeLabGeneratorScript = preload("res://src/presentation/showcase/room_archetype_lab/room_archetype_lab_generator.gd")
const RoomPreviewRequestScript = preload("res://src/presentation/showcase/room_archetype_lab/room_preview_request.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_crypt_determinism ---")
	print("==================================================================")

	var generator := RoomArchetypeLabGeneratorScript.new()

	var test_seeds = [42, 12345, 98765, 999999]

	for s in test_seeds:
		var req := RoomPreviewRequestScript.new(
			DungeonArchetypeScript.Type.MAUSOLEUM, RoomPurposeScript.Type.TOMB, s, Vector2i(10, 8)
		)

		var res1 = generator.generate_preview(req)
		var res2 = generator.generate_preview(req)

		assert(res1.success and res2.success, "FAIL: Generation failed for seed %d" % s)
		assert(res1.diagnostics == res2.diagnostics, "FAIL: Diagnostics mismatch for seed %d" % s)
		assert(res1.composition.occupied_cells == res2.composition.occupied_cells, "FAIL: Occupied cells mismatch for seed %d" % s)

		for i in range(res1.composition.prop_directives.size()):
			var p1 = res1.composition.prop_directives[i]
			var p2 = res2.composition.prop_directives[i]
			assert(p1.prop_id == p2.prop_id, "FAIL: Prop ID mismatch for seed %d at %d" % [s, i])
			assert(p1.world_position == p2.world_position, "FAIL: Position mismatch for seed %d at %d" % [s, i])
			assert(p1.rotation_degrees_y == p2.rotation_degrees_y, "FAIL: Rotation mismatch for seed %d at %d" % [s, i])

		res1.room_root.free()
		res2.room_root.free()
		print("  [OK] Determinism verified for seed %d." % s)

	print("[PASS] test_crypt_determinism completed successfully!")
	quit(0)
