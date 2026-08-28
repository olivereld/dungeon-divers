extends SceneTree

const DungeonSemanticResultScript = preload("res://src/dungeon_generator/core/semantic/data/dungeon_semantic_result.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const RoomDataScript = preload("res://src/dungeon_generator/core/data/room_data.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_semantic_diagnostics ---")
	print("==================================================================")

	var res := DungeonSemanticResultScript.new()
	res.dungeon_archetype = &"necropolis"
	res.dungeon_archetype_name = "necropolis"

	# Mock rooms y propósitos
	for i in range(4):
		var r = RoomDataScript.new(i, Rect2i(i * 10, 0, 8, 8))
		res.rooms.append(r)

	res.room_purposes = {
		0: &"entrance",
		1: &"crypt",
		2: &"crypt",
		3: &"royal_tomb"
	}

	var dist = res.get_purpose_distribution()
	assert(dist[&"crypt"] == 2, "FAIL: crypt count must be 2")
	assert(dist[&"entrance"] == 1, "FAIL: entrance count must be 1")
	assert(dist[&"royal_tomb"] == 1, "FAIL: royal_tomb count must be 1")

	var crypt_rooms = res.get_rooms_by_purpose(&"crypt")
	assert(crypt_rooms.size() == 2 and crypt_rooms.has(1) and crypt_rooms.has(2))

	var debug_str = res.to_debug_string()
	assert(debug_str.contains("necropolis"), "FAIL: Debug string must include Archetype")
	assert(debug_str.contains("crypt: 2"), "FAIL: Debug string must include distribution")

	print("  [OK] get_purpose_distribution() and get_rooms_by_purpose() verified.")
	print("  [OK] to_debug_string() formatted with archetype and purpose stats.")
	print("[PASS] test_semantic_diagnostics completed successfully!")
	quit(0)
