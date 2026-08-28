extends SceneTree

## Test para Task 4: Verificación integral de arquetipos dinámicos a través de ArchetypeCatalog y archetypes.json.

func _init() -> void:
	print("--- Running test_dynamic_archetype_catalog_pipeline (Task 4) ---")
	var manifest_path = "res://resources/dungeon_profiles/archetypes/archetypes.json"
	var custom_arch_path = "res://resources/dungeon_profiles/archetypes/ancient_catacombs.json"
	var catalog_script = preload("res://src/dungeon_generator/profiles/archetype_catalog.gd")
	var loader_script = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
	var multi_gen_script = preload("res://src/dungeon_generator/core/multi_floor_generator.gd")
	var config_script = preload("res://src/dungeon_generator/config/dungeon_config.gd")

	# 1. Crear nuevo JSON de arquetipo
	var test_json = {
		"schema_version": 1,
		"id": "ancient_catacombs",
		"display_name": "Ancient Catacombs",
		"purpose_weights": {"crypt": 3.0, "catacomb": 4.0, "tomb": 2.0},
		"gameplay_purpose_map": {"START": ["entrance"], "BOSS": ["royal_tomb"], "EXPLORE": ["catacomb", "hall"]},
		"room_purpose_distribution": {"entrance": 0.1, "hall": 0.1, "chamber": 0.1, "crypt": 0.3, "catacomb": 0.3, "royal_tomb": 0.1},
		"global_settings": {"min_rooms": 6, "max_rooms": 12, "decoration_density": 0.6},
		"architectural_style": {
			"floor_style": "catacomb_dirt", "wall_style": "dark_stone",
			"door_style": "stone_arch", "stairs_style": "stone",
			"material_profile": "necropolis_stone"
		},
		"room_rules": {"allow_duplicate_purposes": true, "guaranteed": ["entrance"]},
		"rooms": {
			"entrance": "entrance.json", "hall": "hall.json", "chamber": "chamber.json",
			"crypt": "crypt.json", "catacomb": "catacomb.json", "royal_tomb": "royal_tomb.json"
		}
	}
	var f_arch = FileAccess.open(custom_arch_path, FileAccess.WRITE)
	assert(f_arch != null, "Must write custom archetype file")
	f_arch.store_string(JSON.stringify(test_json, "    "))
	f_arch.close()

	# 2. Registrar en archetypes.json
	var manifest_data = {
		"schema_version": 1,
		"archetypes": [
			{"id": "necropolis", "file": "necropolis.json"},
			{"id": "ancient_catacombs", "file": "ancient_catacombs.json"}
		]
	}
	var f_man = FileAccess.open(manifest_path, FileAccess.WRITE)
	assert(f_man != null, "Must update manifest")
	f_man.store_string(JSON.stringify(manifest_data, "    "))
	f_man.close()

	# 3. Verificar recarga de ArchetypeCatalog
	var catalog = catalog_script.new("res://resources/dungeon_profiles/archetypes/")
	assert(catalog.has_archetype(&"ancient_catacombs"), "ArchetypeCatalog must discover ancient_catacombs from manifest")
	print("  [OK] ArchetypeCatalog successfully loaded ancient_catacombs.")

	# 4. Verificar carga de Bundle completo
	var loader = loader_script.new()
	var bundle = loader.load_full_archetype_bundle("ancient_catacombs")
	assert(bundle != null and bundle.archetype != null, "Must load full archetype bundle")
	assert(bundle.archetype.id == &"ancient_catacombs", "Archetype ID must match")
	print("  [OK] ProfileLoader loaded full bundle for dynamic archetype.")

	# 5. Generar mazmorra multi-piso con el nuevo arquetipo
	var multi_gen = multi_gen_script.new()
	var cfg = config_script.new()
	cfg.archetype_id = &"ancient_catacombs"
	cfg.total_floors = 2
	cfg.seed = 998877

	var multi_res = multi_gen.generate_multi_floor(cfg)
	assert(multi_res != null, "MultiFloorGenerator must return valid result")
	assert(multi_res.floors.size() == 2, "Must generate 2 floors")
	print("  [OK] MultiFloorGenerator successfully generated 2 floors with archetype: &\"ancient_catacombs\".")

	# 6. Limpieza: restaurar manifiesto original y borrar archivo temporal
	var clean_manifest = {
		"schema_version": 1,
		"archetypes": [
			{"id": "necropolis", "file": "necropolis.json"}
		]
	}
	var f_clean = FileAccess.open(manifest_path, FileAccess.WRITE)
	if f_clean != null:
		f_clean.store_string(JSON.stringify(clean_manifest, "    "))
		f_clean.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(custom_arch_path))
	print("  [OK] Cleaned up dynamic test manifest and temporary file.")

	print("\n==================================================================")
	print("[PASS] test_dynamic_archetype_catalog_pipeline passed 100%!")
	print("==================================================================\n")
	quit(0)
