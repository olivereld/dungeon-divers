extends SceneTree

const PresentationProfileResolverScript = preload("res://src/presentation/architecture/presentation_profile_resolver.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const ArchitecturalStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_presentation_profile_resolver ---")
	print("==================================================================")

	var resolver := PresentationProfileResolverScript.new()

	# 1. Necropolis + Catacomb
	var nec_catacomb = resolver.resolve(&"necropolis", &"catacomb")
	assert(nec_catacomb != null, "FAIL: nec_catacomb must not be null")
	assert(nec_catacomb.wall_style == &"dark_stone")
	assert(nec_catacomb.floor_style == &"catacomb_dirt")
	assert(nec_catacomb.door_style == &"stone_arch")

	# 2. Generic fallback
	var gen_room = resolver.resolve(&"custom_dungeon", &"custom_room")
	assert(gen_room != null, "FAIL: gen_room must not be null")
	assert(not gen_room.wall_style.is_empty())
	assert(not gen_room.floor_style.is_empty())

	# 3. Determinismo
	var nec_catacomb_2 = resolver.resolve(&"necropolis", &"catacomb")
	assert(nec_catacomb.equals(nec_catacomb_2), "FAIL: PresentationProfileResolver must be 100% deterministic")

	print("  [OK] PresentationProfileResolver correctly resolves dynamic archetype x purpose combinations.")
	print("  [OK] Determinism verified.")
	print("[PASS] test_presentation_profile_resolver completed successfully.")
	quit(0)
