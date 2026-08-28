extends SceneTree

## Test para Task 1: ArchetypeCatalog y catálogo centralizado desde archetypes.json.

func _init() -> void:
	print("--- Running test_archetype_catalog (Task 1) ---")
	var catalog_script = preload("res://src/dungeon_generator/profiles/archetype_catalog.gd")
	var catalog = catalog_script.new("res://resources/dungeon_profiles/archetypes/")

	var ids = catalog.get_ids()
	assert(not ids.is_empty(), "Must discover registered archetypes")
	assert(catalog.has_archetype(&"necropolis"), "Must have necropolis archetype")
	assert(catalog.get_profile_path(&"necropolis").ends_with("necropolis.json"), "Path must resolve correctly")
	assert(not catalog.has_archetype(&"non_existent"), "Must return false for unknown archetypes")
	print("  [OK] ArchetypeCatalog successfully read archetypes.json and resolved IDs: %s" % str(ids))

	print("\n==================================================================")
	print("[PASS] test_archetype_catalog passed 100%!")
	print("==================================================================\n")
	quit(0)
