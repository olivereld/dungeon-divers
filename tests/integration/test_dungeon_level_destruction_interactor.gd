extends SceneTree

const _DungeonLevelScene = preload("res://scenes/dungeon/dungeon_level.tscn")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_dungeon_level_destruction_interactor ---")
	print("==================================================================")

	var scene_inst = _DungeonLevelScene.instantiate()
	assert(scene_inst != null, "FAIL: Could not instantiate dungeon_level.tscn")

	root.add_child(scene_inst)
	scene_inst._ready()

	var interactor = scene_inst.get_node_or_null("DestructionDebugInteractor")
	assert(interactor != null, "FAIL: DestructionDebugInteractor node must exist in dungeon_level scene")

	var hud = scene_inst.get_node_or_null("DestructionDebugHUD")
	assert(hud != null, "FAIL: DestructionDebugHUD node must exist in dungeon_level scene")

	scene_inst.free()
	print("[PASS] test_dungeon_level_destruction_interactor passed 100%!")
	print("==================================================================")
	quit(0)
