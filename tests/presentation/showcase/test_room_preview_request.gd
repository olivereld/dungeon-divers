extends SceneTree

const RoomPreviewRequestScript = preload("res://src/presentation/showcase/room_archetype_lab/room_preview_request.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_room_preview_request ---")
	print("==================================================================")

	# 1. Petición por defecto válida
	var req_default := RoomPreviewRequestScript.new()
	assert(req_default.is_valid(), "FAIL: Default request must be valid")
	print("  [OK] Default request validation verified.")

	# 2. Validación de dimensiones mínimas
	var req_small := RoomPreviewRequestScript.new(
		DungeonArchetypeScript.Type.MAUSOLEUM, RoomPurposeScript.Type.TOMB, 123, Vector2i(2, 2)
	)
	assert(not req_small.is_valid(), "FAIL: Small room under 4x4 must be rejected")
	print("  [OK] Minimum dimension enforcement verified.")

	# 3. Compatibilidad de propósitos por arquetipo
	# Mausoleum / Crypt: TOMB, SACRISTY, CRYPT, ROYAL_TOMB
	assert(RoomPreviewRequestScript.is_purpose_valid_for_archetype(DungeonArchetypeScript.Type.MAUSOLEUM, RoomPurposeScript.Type.TOMB), "FAIL: TOMB must be valid for MAUSOLEUM")
	assert(RoomPreviewRequestScript.is_purpose_valid_for_archetype(DungeonArchetypeScript.Type.MAUSOLEUM, RoomPurposeScript.Type.SACRISTY), "FAIL: SACRISTY must be valid for MAUSOLEUM")
	assert(RoomPreviewRequestScript.is_purpose_valid_for_archetype(DungeonArchetypeScript.Type.MAUSOLEUM, RoomPurposeScript.Type.CRYPT), "FAIL: CRYPT must be valid for MAUSOLEUM")

	# Incompatible: MAUSOLEUM + BARRACKS / FORGE / EXCAVATION
	assert(not RoomPreviewRequestScript.is_purpose_valid_for_archetype(DungeonArchetypeScript.Type.MAUSOLEUM, RoomPurposeScript.Type.BARRACKS), "FAIL: BARRACKS must be invalid for MAUSOLEUM")
	assert(not RoomPreviewRequestScript.is_purpose_valid_for_archetype(DungeonArchetypeScript.Type.MAUSOLEUM, RoomPurposeScript.Type.FORGE), "FAIL: FORGE must be invalid for MAUSOLEUM")

	# Fortress: BARRACKS, ARMORY, THRONE_ROOM
	assert(RoomPreviewRequestScript.is_purpose_valid_for_archetype(DungeonArchetypeScript.Type.FORTRESS, RoomPurposeScript.Type.BARRACKS), "FAIL: BARRACKS must be valid for FORTRESS")
	assert(not RoomPreviewRequestScript.is_purpose_valid_for_archetype(DungeonArchetypeScript.Type.FORTRESS, RoomPurposeScript.Type.TOMB), "FAIL: TOMB must be invalid for FORTRESS")

	# Temple: SHRINE, SANCTUM, ALTAR_ROOM
	assert(RoomPreviewRequestScript.is_purpose_valid_for_archetype(DungeonArchetypeScript.Type.TEMPLE, RoomPurposeScript.Type.SHRINE), "FAIL: SHRINE must be valid for TEMPLE")

	# Mine: EXCAVATION, MINE_STORAGE, FORGE
	assert(RoomPreviewRequestScript.is_purpose_valid_for_archetype(DungeonArchetypeScript.Type.MINE, RoomPurposeScript.Type.EXCAVATION), "FAIL: EXCAVATION must be valid for MINE")

	print("  [OK] Archetype to purpose compatibility matrix verified.")
	print("[PASS] test_room_preview_request completed successfully!")
	quit(0)
