extends SceneTree

const RockSizeConfig = preload("res://src/rock_generation/config/rock_size_config.gd")
const RockConfig = preload("res://src/rock_generation/config/rock_config.gd")

func _init() -> void:
	print("==================================================")
	print(" TEST ROCK CONFIG & SERIALIZATION MODEL")
	print("==================================================")

	var passed := 0
	var total := 0

	# 1. Test RockSizeConfig
	total += 1
	if _test_size_config():
		passed += 1
		print("[PASS] 1. RockSizeConfig instanciado y clonado correctamente")
	else:
		printerr("[FAIL] 1. Fallo en RockSizeConfig")

	# 2. Test RockConfig Presets
	total += 1
	if _test_rock_config_presets():
		passed += 1
		print("[PASS] 2. Presets canónicos (Taiga, Desierto, Montaña) válidos")
	else:
		printerr("[FAIL] 2. Fallo en Presets canónicos")

	# 3. Test Roundtrip Serialization
	total += 1
	if _test_roundtrip_dict():
		passed += 1
		print("[PASS] 3. Serialización bidireccional Dictionary íntegra")
	else:
		printerr("[FAIL] 3. Fallo en serialización Dictionary")

	# 4. Test JSON String
	total += 1
	if _test_json_string():
		passed += 1
		print("[PASS] 4. Parseo y generación de JSON string correctos")
	else:
		printerr("[FAIL] 4. Fallo en JSON string")

	# 5. Test File Save and Load
	total += 1
	if _test_file_io():
		passed += 1
		print("[PASS] 5. Guardado y carga de archivo JSON correctos")
	else:
		printerr("[FAIL] 5. Fallo en File I/O")

	print("==================================================")
	print("RESULTADO: %d / %d tests superados." % [passed, total])
	print("==================================================")

	if passed == total:
		quit(0)
	else:
		quit(1)

func _test_size_config() -> bool:
	var l = RockSizeConfig.create_large()
	var m = RockSizeConfig.create_medium()
	var s = RockSizeConfig.create_small()

	if l.category != RockSizeConfig.Category.LARGE or l.min_scale != 1.30:
		return false
	if m.category != RockSizeConfig.Category.MEDIUM or m.segments != 8:
		return false
	if s.category != RockSizeConfig.Category.SMALL or s.rings != 3:
		return false

	var copy = l.clone()
	if copy.category != l.category or copy.irregularity != l.irregularity or copy.scale_x_range != l.scale_x_range:
		return false
	return true

func _test_rock_config_presets() -> bool:
	var taiga = RockConfig.create_default_taiga()
	var desert = RockConfig.create_default_desert()
	var mountain = RockConfig.create_default_mountain()

	if taiga.biome != "taiga" or taiga.distribution["density"] != 0.15:
		return false
	if desert.biome != "desert" or desert.profiles[RockSizeConfig.Category.LARGE].height_ratio >= taiga.profiles[RockSizeConfig.Category.LARGE].height_ratio:
		return false
	if mountain.biome != "mountain" or mountain.profiles[RockSizeConfig.Category.LARGE].height_ratio <= taiga.profiles[RockSizeConfig.Category.LARGE].height_ratio:
		return false
	return true

func _test_roundtrip_dict() -> bool:
	var cfg = RockConfig.create_default_taiga()
	cfg.distribution["density"] = 0.42
	cfg.clustering["large"]["min_satellites"] = 5
	cfg.profiles[RockSizeConfig.Category.LARGE].irregularity = 0.88

	var d: Dictionary = cfg.to_dict()
	var restored = RockConfig.new()
	restored.from_dict(d)

	if restored.distribution["density"] != 0.42:
		return false
	if restored.clustering["large"]["min_satellites"] != 5:
		return false
	if restored.profiles[RockSizeConfig.Category.LARGE].irregularity != 0.88:
		return false
	return true

func _test_json_string() -> bool:
	var cfg = RockConfig.create_default_desert()
	var json_str: String = cfg.to_json_string(true)
	if json_str.is_empty():
		return false

	var restored = RockConfig.new()
	var err: Error = restored.from_json_string(json_str)
	if err != OK:
		return false
	if restored.biome != "desert":
		return false
	return true

func _test_file_io() -> bool:
	var path := "user://test_authoring_rock_config.json"
	var cfg = RockConfig.create_default_mountain()
	var err: Error = cfg.save_to_json(path)
	if err != OK:
		printerr("Error al guardar JSON: ", err)
		return false

	var loaded = RockConfig.new()
	err = loaded.load_from_json(path)
	if err != OK:
		printerr("Error al cargar JSON: ", err)
		return false

	if loaded.biome != "mountain":
		return false
	if loaded.distribution["min_slope_degrees"] != 20.0:
		return false

	# Limpieza
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return true
