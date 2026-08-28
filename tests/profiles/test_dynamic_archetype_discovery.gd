extends SceneTree

## Test para descubrimiento dinámico en ArchetypeCatalog y ProfileLoader.

func _init() -> void:
	print("--- Running test_dynamic_archetype_discovery ---")
	var catalog_script = preload("res://src/dungeon_generator/profiles/archetype_catalog.gd")
	var loader_script = preload("res://src/dungeon_generator/profiles/profile_loader.gd")

	var catalog = catalog_script.new("res://resources/dungeon_profiles/archetypes/")
	var ids: Array[StringName] = catalog.get_ids()
	assert(not ids.is_empty(), "Must discover at least one archetype in directory")
	assert(catalog.has_archetype(&"necropolis"), "Must discover necropolis archetype dynamically")
	print("  [OK] ArchetypeCatalog indexed %d archetypes: %s" % [
		ids.size(), str(ids)
	])

	var loader = loader_script.new()
	var available = loader.list_available_archetypes()
	assert(available.has(&"necropolis"), "ProfileLoader must expose discovered archetypes")

	# Test loading dynamically discovered archetype
	var arch = loader.load_archetype("necropolis")
	assert(arch != null and arch.id == &"necropolis", "Must load discovered archetype")
	print("  [OK] ProfileLoader loaded necropolis dynamically.")

	print("\n==================================================================")
	print("[PASS] test_dynamic_archetype_discovery passed 100%!")
	print("==================================================================\n")
	quit(0)
