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
		&"necropolis", &"tomb", 123, Vector2i(2, 2)
	)
	assert(not req_small.is_valid(), "FAIL: Small room under 4x4 must be rejected")
	print("  [OK] Minimum dimension enforcement verified.")

	# 3. Compatibilidad de propósitos por arquetipo
	# Necropolis: tomb, sacristy, crypt, catacomb, hall
	assert(RoomPreviewRequestScript.is_purpose_valid_for_archetype(&"necropolis", &"tomb"), "FAIL: tomb must be valid for necropolis")
	assert(RoomPreviewRequestScript.is_purpose_valid_for_archetype(&"necropolis", &"sacristy"), "FAIL: sacristy must be valid for necropolis")
	assert(RoomPreviewRequestScript.is_purpose_valid_for_archetype(&"necropolis", &"crypt"), "FAIL: crypt must be valid for necropolis")

	# Incompatible: necropolis + barracks / forge / excavation
	assert(not RoomPreviewRequestScript.is_purpose_valid_for_archetype(&"necropolis", &"barracks"), "FAIL: barracks must be invalid for necropolis")
	assert(not RoomPreviewRequestScript.is_purpose_valid_for_archetype(&"necropolis", &"forge"), "FAIL: forge must be invalid for necropolis")

	print("  [OK] Archetype to purpose compatibility matrix verified.")
	print("[PASS] test_room_preview_request completed successfully!")
	quit(0)
