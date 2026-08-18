extends SceneTree

## Suite de pruebas unitarias para PR-10A: Contratos Topológicos Verticales (StairData & FloorConnection).

func _init() -> void:
	print("--- Running test_vertical_contracts (PR-10A) ---")

	var stair_data_script = preload("res://src/dungeon_generator/core/data/stair_data.gd")
	var floor_connection_script = preload("res://src/dungeon_generator/core/data/floor_connection.gd")

	# 1. Validar Inicialización e Invariantes de StairData
	var stair_up = stair_data_script.new(
		"stair_f0_f1_a",
		0,
		Vector2i(10, 15),
		0.0,
		"conn_f0_f1_1",
		false # Ascendente
	)
	assert(stair_up.is_valid(), "Valid StairData must pass validation")
	assert(stair_up.stair_id == "stair_f0_f1_a", "Stair ID must match")
	assert(stair_up.floor_number == 0, "Floor number must match")
	assert(stair_up.cell == Vector2i(10, 15), "Cell coordinates must match")
	assert(not stair_up.is_downward, "Stair must be upward")
	print("  [OK] StairData contract and properties verified")

	# 2. Validar Invariantes de StairData Inválido
	var invalid_stair = stair_data_script.new("", 0, Vector2i.ZERO, 0.0, "", false)
	assert(not invalid_stair.is_valid(), "StairData with empty IDs must be invalid")
	print("  [OK] StairData invalidity checks verified")

	# 3. Validar FloorConnection (Downward & Upward)
	var conn_down = floor_connection_script.new(
		"conn_f1_f0_main",
		1, # from_floor
		0, # to_floor
		"stair_f1_down",
		"stair_f0_up",
		Vector2i(12, 18),
		Vector2i(12, 18)
	)
	assert(conn_down.is_valid(), "Valid FloorConnection must pass validation")
	assert(conn_down.is_downward(), "F1 -> F0 connection must be downward")
	assert(not conn_down.is_upward(), "F1 -> F0 connection must not be upward")

	var conn_up = floor_connection_script.new(
		"conn_f0_f1_main",
		0, # from_floor
		1, # to_floor
		"stair_f0_up",
		"stair_f1_down",
		Vector2i(5, 5),
		Vector2i(5, 6)
	)
	assert(conn_up.is_valid(), "Valid FloorConnection must pass validation")
	assert(conn_up.is_upward(), "F0 -> F1 connection must be upward")
	assert(not conn_up.is_downward(), "F0 -> F1 connection must not be downward")
	print("  [OK] FloorConnection directionality verified")

	# 4. Validar Generación Coherente de Pares de Escaleras
	var stair_pair: Array[StairData] = conn_down.create_stair_pair(PI * 0.5, -PI * 0.5)
	assert(stair_pair.size() == 2, "Must generate exactly 2 StairData endpoints")
	
	var from_endpoint: StairData = stair_pair[0]
	var to_endpoint: StairData = stair_pair[1]

	assert(from_endpoint.floor_number == 1 and from_endpoint.is_downward, "From endpoint on F1 must descend")
	assert(to_endpoint.floor_number == 0 and not to_endpoint.is_downward, "To endpoint on F0 must ascend")
	assert(from_endpoint.connection_id == conn_down.connection_id, "Connection IDs must be identical")
	assert(to_endpoint.connection_id == conn_down.connection_id, "Connection IDs must be identical")
	assert(from_endpoint.cell == conn_down.from_cell, "From cell must match connection")
	assert(to_endpoint.cell == conn_down.to_cell, "To cell must match connection")
	print("  [OK] FloorConnection pair factory produces coherent endpoints")

	# 5. Validar Casos de Error en FloorConnection
	var same_floor_conn = floor_connection_script.new("conn_bad", 1, 1, "s1", "s2", Vector2i.ZERO, Vector2i.ZERO)
	assert(not same_floor_conn.is_valid(), "Connection on same floor must be invalid")

	var same_stair_id_conn = floor_connection_script.new("conn_bad", 0, 1, "s1", "s1", Vector2i.ZERO, Vector2i.ZERO)
	assert(not same_stair_id_conn.is_valid(), "Connection with duplicate stair IDs must be invalid")
	print("  [OK] FloorConnection error and edge cases verified")

	print("\n>>> ALL PR-10A VERTICAL CONTRACT TESTS PASSED SUCCESSFULLY! <<<\n")
	quit(0)
