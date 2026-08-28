extends SceneTree

## Test para Task 4 (The Acid Test): Creación y carga de un arquetipo nuevo en disco sin tocar NINGÚN archivo de código.

func _init() -> void:
	print("--- Running test_zero_code_new_archetype_pipeline (The Acid Test) ---")
	var temp_arch_path = "res://resources/dungeon_profiles/archetypes/test_celestial_sanctum.json"

	# 1. Crear un archivo JSON de arquetipo completamente nuevo en disco en tiempo de ejecución
	var test_json = {
		"schema_version": 1,
		"id": "test_celestial_sanctum",
		"display_name": "Celestial Sanctum",
		"purpose_weights": {"crypt": 1.0, "hall": 2.0},
		"gameplay_purpose_map": {"START": ["entrance"], "BOSS": ["crypt"], "EXPLORE": ["hall"]},
		"room_purpose_distribution": {"entrance": 0.2, "hall": 0.5, "crypt": 0.3},
		"global_settings": {"min_rooms": 5, "max_rooms": 10, "decoration_density": 0.5},
		"architectural_style": {
			"floor_style": "smooth_slabs", "wall_style": "dark_stone",
			"door_style": "stone_arch", "stairs_style": "stone",
			"material_profile": "necropolis_stone"
		},
		"room_rules": {"allow_duplicate_purposes": true, "guaranteed": ["entrance"]},
		"rooms": {"entrance": "entrance.json", "hall": "hall.json", "crypt": "crypt.json"}
	}

	var file = FileAccess.open(temp_arch_path, FileAccess.WRITE)
	assert(file != null, "Must be able to create temporary archetype JSON file")
	file.store_string(JSON.stringify(test_json, "    "))
	file.close()

	# 2. Verificar que ProfileLoader descubre automáticamente el nuevo arquetipo
	var loader_script = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
	var loader = loader_script.new()
	var available = loader.list_available_archetypes()
	assert(available.has(&"test_celestial_sanctum"), "Dynamic archetype must be auto-discovered by ProfileLoader")
	print("  [OK] ProfileLoader dynamically discovered newly dropped archetype: &\"test_celestial_sanctum\"")

	# 3. Cargar el bundle completo del nuevo arquetipo
	var bundle = loader.load_full_archetype_bundle("test_celestial_sanctum")
	assert(bundle != null and bundle.archetype != null, "Must load full archetype bundle for new archetype")
	assert(bundle.archetype.id == &"test_celestial_sanctum", "Archetype ID must match")
	assert(bundle.archetype.display_name == "Celestial Sanctum", "Display name must match")
	print("  [OK] Fully loaded bundle for test_celestial_sanctum without editing any GDScript file.")

	# 4. Limpiar el archivo de prueba temporal
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_arch_path))
	print("  [OK] Cleaned up temporary test archetype file.")

	print("\n==================================================================")
	print("[PASS] test_zero_code_new_archetype_pipeline passed 100%!")
	print("Zero code changes required for new archetypes!")
	print("==================================================================\n")
	quit(0)
