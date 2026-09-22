extends SceneTree

func _init() -> void:
	print("==================================================")
	print(" Running Stepped Navigation Unit & Integration Tests")
	print("==================================================")

	# 1. Regla contractual básica con celdas sintéticas
	var cell_a := WorldCell.new(Vector2i(0, 0))
	cell_a.elevation_level = 2
	cell_a.is_walkable = true

	var cell_b := WorldCell.new(Vector2i(1, 0))
	cell_b.elevation_level = 2
	cell_b.is_walkable = true

	# Caso 1: same level -> walkable según reglas existentes
	assert(NavigationStage.can_transition(cell_a, cell_b) == true, "Same level walkable cells must allow transition")
	assert(cell_a.can_transition_to(cell_b) == true, "WorldCell.can_transition_to must match NavigationStage")

	# Caso 2: different level -> no transición caminable
	var cell_c := WorldCell.new(Vector2i(2, 0))
	cell_c.elevation_level = 3  # Nivel diferente (+1)
	cell_c.is_walkable = true
	assert(NavigationStage.can_transition(cell_a, cell_c) == false, "Different levels (2 != 3) must NOT allow transition")
	assert(cell_a.can_transition_to(cell_c) == false, "WorldCell.can_transition_to must be false across levels")

	var cell_d := WorldCell.new(Vector2i(3, 0))
	cell_d.elevation_level = 1  # Nivel diferente (-1)
	cell_d.is_walkable = true
	assert(NavigationStage.can_transition(cell_a, cell_d) == false, "Different levels (2 != 1) must NOT allow transition")

	# Caso 3: same level pero una celda no transitable (p. ej. agua profunda)
	var cell_e := WorldCell.new(Vector2i(4, 0))
	cell_e.elevation_level = 2
	cell_e.is_walkable = false
	assert(NavigationStage.can_transition(cell_a, cell_e) == false, "Unwalkable cell on same level must block transition")
	assert(NavigationStage.can_transition(cell_e, cell_a) == false, "Transition must be symmetric")

	# Caso 4: nulos o fuera de límites
	assert(NavigationStage.can_transition(cell_a, null) == false, "Null neighbor must return false")
	assert(NavigationStage.can_transition(null, cell_a) == false, "Null source must return false")
	assert(cell_a.can_transition_to(null) == false, "can_transition_to(null) must return false")

	print(" [PASS] 1. Synthetic transition contract (same level vs different level)")

	# 2. Integración sobre mapa generado completo
	var pipeline := WorldPipeline.new()
	var profile := TaigaWorldProfile.new()
	var result: WorldResult = pipeline.generate(12345, profile)

	var same_level_transitions := 0
	var different_level_blocked := 0
	var total_tested := 0

	for pos in result.cells:
		var cur: WorldCell = result.cells[pos]
		var neighbors: Array[Vector2i] = [
			pos + Vector2i(1, 0),
			pos + Vector2i(0, 1)
		]
		for n_pos in neighbors:
			if result.cells.has(n_pos):
				var n_cell: WorldCell = result.cells[n_pos]
				total_tested += 1
				var can_move := NavigationStage.can_transition(cur, n_cell)
				var can_move_pos := NavigationStage.can_transition_pos(result, pos, n_pos)
				assert(can_move == can_move_pos, "can_transition and can_transition_pos must match")

				if cur.elevation_level != n_cell.elevation_level:
					# different level -> NUNCA transitable
					assert(can_move == false, "Cross-level transition at %s -> %s must be false" % [str(pos), str(n_pos)])
					different_level_blocked += 1
				else:
					# same level -> depende exclusivamente de las reglas existentes
					var expected := cur.is_walkable and n_cell.is_walkable
					assert(can_move == expected, "Same-level transition at %s -> %s mismatch with walkability" % [str(pos), str(n_pos)])
					if can_move:
						same_level_transitions += 1

	assert(different_level_blocked > 0, "Map must contain cross-level cliff edges that were blocked")
	assert(same_level_transitions > 0, "Map must contain walkable same-level transitions")

	print(" [PASS] 2. Full world integration: %d cross-level transitions blocked, %d same-level transitions permitted (Total edges: %d)" % [
		different_level_blocked, same_level_transitions, total_tested
	])
	print("==================================================")
	print(" ALL STEPPED NAVIGATION TESTS PASSED!")
	print("==================================================")
	quit()
