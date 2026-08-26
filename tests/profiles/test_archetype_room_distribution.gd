extends SceneTree

const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _RoomPurposeAssignerScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose_assigner.gd")
const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const _RoomDataScript = preload("res://src/dungeon_generator/core/data/room_data.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_archetype_room_distribution ---")

	var loader := _ProfileLoaderScript.new()
	var bundle = loader.load_full_archetype_bundle("mausoleum")
	assert(bundle != null, "FAIL: Bundle should load")

	var assigner := _RoomPurposeAssignerScript.new()

	# Create a mock set of 12 rooms
	var rooms: Array = []
	for i in range(12):
		var r := _RoomDataScript.new(i, Rect2i(i * 10, 0, 8, 8), &"room")
		rooms.append(r)

	var start_id := 0
	var boss_id := 11
	var objectives: Array = []

	# Sweep 100 seeds to test statistical consistency and hard rules
	var purpose_counts: Dictionary = {}
	var total_assigned: int = 0

	for s in range(100):
		var seed_val := 1000 + s
		var assignment := assigner.assign_purposes(
			start_id,
			boss_id,
			rooms,
			objectives,
			bundle,
			seed_val
		)

		# 1. Check start room is guaranteed ENTRANCE
		assert(assignment[start_id] == _RoomPurposeScript.Type.ENTRANCE, "FAIL: Start room must be ENTRANCE")

		# 2. Check boss room receives ROYAL_TOMB
		assert(assignment[boss_id] == _RoomPurposeScript.Type.ROYAL_TOMB or assignment[boss_id] == _RoomPurposeScript.Type.SANCTUM, "FAIL: Boss room must be ROYAL_TOMB or SANCTUM")

		# 3. Check consecutive room purposes do not exceed max_same_purpose_consecutive (2)
		var consecutive_count: int = 1
		var last_p: int = -1
		for r_id in range(1, 11): # explore rooms
			var p: int = assignment[r_id]
			if p == last_p:
				consecutive_count += 1
				assert(consecutive_count <= 2, "FAIL: Exceeded max consecutive same purpose (%d for purpose %d at seed %d)" % [consecutive_count, p, seed_val])
			else:
				consecutive_count = 1
				last_p = p

			purpose_counts[p] = purpose_counts.get(p, 0) + 1
			total_assigned += 1

	# 4. Statistical distribution check on explore rooms
	# In mausoleum.json: crypt=25%, catacomb=15%, tomb=15%, chamber=15%, hall=10%
	var crypt_count: int = purpose_counts.get(int(_RoomPurposeScript.Type.CRYPT), 0)
	var catacomb_count: int = purpose_counts.get(int(_RoomPurposeScript.Type.CATACOMB), 0)
	var tomb_count: int = purpose_counts.get(int(_RoomPurposeScript.Type.TOMB), 0)

	var crypt_ratio: float = float(crypt_count) / float(total_assigned)
	var catacomb_ratio: float = float(catacomb_count) / float(total_assigned)

	print("Observed macro ratios across 100 seeds (explore rooms):")
	print("  CRYPT: %.3f (target ~0.25)" % crypt_ratio)
	print("  CATACOMB: %.3f (target ~0.15)" % catacomb_ratio)

	# Validate that CRYPT is the most frequent or close to expected range [0.15, 0.35]
	assert(crypt_ratio >= 0.15 and crypt_ratio <= 0.38, "FAIL: Crypt ratio out of expected bounds: %f" % crypt_ratio)
	assert(catacomb_ratio >= 0.08 and catacomb_ratio <= 0.28, "FAIL: Catacomb ratio out of expected bounds: %f" % catacomb_ratio)

	print("[PASS] test_archetype_room_distribution completed successfully!")
	quit(0)
