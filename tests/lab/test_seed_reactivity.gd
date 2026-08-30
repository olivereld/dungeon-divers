extends SceneTree

const _LabConfigScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_configuration.gd")
const _LabControllerScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_controller.gd")

func _init() -> void:
	print("--- Running test_seed_reactivity ---")
	var controller = _LabControllerScript.new()
	var cfg = _LabConfigScript.new()

	# 1. Generate seed 100001
	cfg.seed = 100001
	var res1 = controller.generate_dungeon(cfg)
	var floor1 = controller.get_current_floor_result()
	var room1_pos = floor1.rooms[0].rect.position

	# 2. Generate seed 224279327
	cfg.seed = 224279327
	var res2 = controller.generate_dungeon(cfg)
	var floor2 = controller.get_current_floor_result()
	var room2_pos = floor2.rooms[0].rect.position

	# 3. Verify that the two seeds do not produce identical room 0 positions or fingerprints
	print("Seed 100001 room 0 position: ", room1_pos)
	print("Seed 224279327 room 0 position: ", room2_pos)

	var identical: bool = true
	if floor1.rooms.size() != floor2.rooms.size():
		identical = false
	else:
		for i in range(floor1.rooms.size()):
			if floor1.rooms[i].rect != floor2.rooms[i].rect:
				identical = false
				break

	assert(not identical, "FAIL: Different seeds must produce different dungeon layouts!")
	print("PASS: Seed reactivity verified! Different seeds generate unique dungeons.")
	quit(0)
