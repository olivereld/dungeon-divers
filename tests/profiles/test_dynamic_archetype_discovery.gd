extends SceneTree

## Test para Task 1: ArchetypeRegistry y descubrimiento dinámico en ProfileLoader.

func _init() -> void:
	print("--- Running test_dynamic_archetype_discovery (Task 1) ---")
	var registry_script = preload("res://src/dungeon_generator/profiles/archetype_registry.gd")
	var loader_script = preload("res://src/dungeon_generator/profiles/profile_loader.gd")

	var registry = registry_script.new()
	var discovered: Dictionary = registry.discover_archetypes("res://resources/dungeon_profiles/archetypes/")
	assert(not discovered.is_empty(), "Must discover at least one archetype in directory")
	assert(discovered.has(&"necropolis"), "Must discover necropolis archetype dynamically")
	print("  [OK] ArchetypeRegistry discovered %d archetypes on disk: %s" % [
		discovered.size(), str(discovered.keys())
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
