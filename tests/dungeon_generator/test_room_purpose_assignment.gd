extends SceneTree

const RoomPurposeAssignerScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose_assigner.gd")
const ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const RoomDataScript = preload("res://src/dungeon_generator/core/data/room_data.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_room_purpose_assignment ---")
	print("==================================================================")

	var assigner = RoomPurposeAssignerScript.new()
	var loader = ProfileLoaderScript.new()
	var bundle = loader.load_full_archetype_bundle("necropolis")
	assert(bundle != null and bundle.archetype != null, "FAIL: Must load necropolis bundle")

	# Mock rooms
	var rooms = []
	for i in range(5):
		var r = RoomDataScript.new(i, Rect2i(i * 10, 0, 8, 8))
		rooms.append(r)

	var start_id = 0
	var boss_id = 4
	var objectives = []
	var seed_val = 98765

	var result = assigner.assign_purposes(start_id, boss_id, rooms, objectives, bundle, seed_val)

	assert(result.size() == 5, "FAIL: All rooms must have an assigned purpose")
	assert(result[start_id] == RoomPurposeScript.Type.ENTRANCE or result[start_id] == RoomPurposeScript.Type.SACRISTY)
	assert(result[boss_id] == RoomPurposeScript.Type.ROYAL_TOMB or result[boss_id] == RoomPurposeScript.Type.SANCTUM, "FAIL: Necropolis boss must be ROYAL_TOMB or SANCTUM")

	# Determinismo: misma semilla debe dar exactamente el mismo resultado
	var result_2 = assigner.assign_purposes(start_id, boss_id, rooms, objectives, bundle, seed_val)
	for r_id in result:
		assert(result[r_id] == result_2[r_id], "FAIL: Purpose assignment must be 100% deterministic")

	print("  [OK] Necropolis start/boss and room purpose assignments verified.")
	print("  [OK] Determinism verified.")
	print("[PASS] test_room_purpose_assignment completed successfully.")
	quit(0)
