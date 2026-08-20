extends SceneTree

## Suite de pruebas unitarias para PR-10F: MultiFloorValidator.

func _init() -> void:
	print("--- Running test_multifloor_validator (PR-10F) ---")

	var multi_gen_script = preload("res://src/dungeon_generator/core/multi_floor_generator.gd")
	var validator_script = preload("res://src/dungeon_generator/core/validation/multi_floor_validator.gd")
	var floor_connection_script = preload("res://src/dungeon_generator/core/data/floor_connection.gd")

	var validator := validator_script.new()

	# 1. Validar Mazmorra Multinivel Correcta
	var config := DungeonConfig.new()
	config.grid_width = 48
	config.grid_height = 48
	config.total_floors = 3
	config.seed = 133742
	config.use_fixed_seed = true

	var generator = multi_gen_script.new()
	var valid_result: DungeonMultiFloorResult = generator.generate_multi_floor(config)

	var v_res: MultiFloorValidationResult = validator.validate(valid_result)
	assert(v_res.is_valid, "Valid multi-floor result must pass validation: %s" % v_res.to_debug_string())
	assert(v_res.is_connected, "Floors must be fully connected")
	assert(v_res.endpoints_valid, "Endpoints must be valid")
	assert(v_res.path_exists, "Vertical path must exist")
	print("  [OK] Valid 3-floor dungeon passed all formal validation checks")

	# 2. Validar Detección de Piso Desconectado
	var broken_conn_result: DungeonMultiFloorResult = generator.generate_multi_floor(config)
	broken_conn_result.vertical_connections.pop_back() # Eliminar conexión entre F1 y F2

	var v_broken: MultiFloorValidationResult = validator.validate(broken_conn_result)
	assert(not v_broken.is_valid, "Disconnected dungeon must fail validation")
	assert(not v_broken.is_connected, "Disconnected dungeon must report is_connected = false")
	print("  [OK] Disconnected floor detection verified")

	# 3. Validar Detección de Discrepancia de Coordenadas de Endpoint
	var coord_error_result: DungeonMultiFloorResult = generator.generate_multi_floor(config)
	var corrupt_conn: FloorConnection = coord_error_result.vertical_connections[0]
	corrupt_conn.from_cell = Vector2i(999, 999) # Coordenada errónea que no coincide con StairData

	var v_coord_err: MultiFloorValidationResult = validator.validate(coord_error_result)
	assert(not v_coord_err.is_valid, "Coordinate mismatch must fail validation")
	assert(not v_coord_err.endpoints_valid, "Endpoints valid must be false on coordinate mismatch")
	print("  [OK] Endpoint coordinate mismatch detection verified")

	print("\n>>> ALL PR-10F MULTIFLOOR VALIDATOR TESTS PASSED SUCCESSFULLY! <<<\n")
	quit(0)
