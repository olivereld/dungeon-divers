extends SceneTree

const RoomArchetypeLabGeneratorScript = preload("res://src/presentation/showcase/room_archetype_lab/room_archetype_lab_generator.gd")
const RoomPreviewRequestScript = preload("res://src/presentation/showcase/room_archetype_lab/room_preview_request.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_crypt_clearance ---")
	print("==================================================================")

	var generator := RoomArchetypeLabGeneratorScript.new()

	var req := RoomPreviewRequestScript.new(
		DungeonArchetypeScript.Type.MAUSOLEUM, RoomPurposeScript.Type.TOMB, 77777, Vector2i(12, 10), 2.0, true, true
	)

	var res = generator.generate_preview(req)
	assert(res.success, "FAIL: Generation failed")

	# Puerta en (1, 5), Escaleras en (10, 5)
	var door_pos := Vector2i(1, 5)
	var stairs_pos := Vector2i(10, 5)

	# 1. Comprobar que todas las celdas 3x3 de puerta y escaleras están reservadas
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var c_door := door_pos + Vector2i(dx, dy)
			var c_stairs := stairs_pos + Vector2i(dx, dy)
			assert(res.composition.reserved_cells.has(c_door), "FAIL: Door clearance missing at %s" % str(c_door))
			assert(res.composition.reserved_cells.has(c_stairs), "FAIL: Stairs clearance missing at %s" % str(c_stairs))

	# 2. Comprobar que ningún prop ocupa alguna de las celdas de despeje
	for prop in res.composition.prop_directives:
		for cell in prop.occupied_cells:
			assert(not res.composition.reserved_cells.has(cell), "FAIL: Prop %s occupies clearance cell %s" % [prop.prop_id, str(cell)])

	res.room_root.free()
	print("  [OK] 100% clean structural clearances verified for door and stairs.")
	print("[PASS] test_crypt_clearance completed successfully!")
	quit(0)
