extends SceneTree

## Suite de Test: Validación de Continuidad del Agua (Bloque 3)
## Para cada pareja de water_cells vecinas en el plano cardinal:
## 1. Ambos tienen water_height finito
## 2. Ambos tienen bed_height finito
## 3. Ambos tienen depth >= 0
## 4. No hay salto inesperado de geometría / coordenadas limítrofes entre celdas vecinas

const _WorldGenerationContextScript = preload("res://src/world_generator/core/world_generation_context.gd")
const _TerrainStageScript = preload("res://src/world_generator/stages/terrain_stage.gd")
const _HydrologyStageScript = preload("res://src/world_generator/stages/hydrology_stage.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Test Suite: Water Continuity (Bloque 3)")
	print("==================================================")

	var test_seeds: Array[int] = [4242, 12345, 283362, 99999]

	for s in test_seeds:
		_test_water_continuity(s)

	print("==================================================")
	print(" ALL WATER CONTINUITY TESTS PASSED!")
	print("==================================================")
	quit(0)

func _test_water_continuity(seed_val: int) -> void:
	print("\n--- Testing Seed: %d ---" % seed_val)

	var profile = _TaigaWorldProfileScript.new()
	profile.width = 96
	profile.height = 96
	profile.hydrology_enabled = true
	profile.lake_threshold = 0.22
	profile.max_rivers = 4
	profile.min_river_length = 8.0

	var ctx = _WorldGenerationContextScript.new(seed_val, profile)
	var terrain_stage = _TerrainStageScript.new()
	terrain_stage.execute(ctx)

	var hydro_stage = _HydrologyStageScript.new()
	hydro_stage.execute(ctx)

	var result: WorldResult = ctx.result
	var hydro: HydrologyResult = result.hydrology
	assert(hydro != null and not hydro.water_cells.is_empty(), "Hydrology must produce water cells")

	var cardinal_dirs := [Vector2i(1, 0), Vector2i(0, 1)]
	var verified_pairs: int = 0
	var planar_pairs: int = 0
	var stepped_pairs: int = 0

	for pos in hydro.water_cells:
		var data_a: Dictionary = hydro.water_cells[pos]
		var w_h_a: float = float(data_a.get("water_height", 0.0))
		var b_h_a: float = float(data_a.get("bed_height", 0.0))
		var d_a: float = float(data_a.get("depth", 0.0))

		assert(is_finite(w_h_a), "water_height at %s is not finite" % str(pos))
		assert(is_finite(b_h_a), "bed_height at %s is not finite" % str(pos))
		assert(d_a >= -0.001, "depth at %s is negative: %.4f" % [str(pos), d_a])

		for dir in cardinal_dirs:
			var n_pos: Vector2i = pos + dir
			if not hydro.water_cells.has(n_pos):
				continue

			var data_b: Dictionary = hydro.water_cells[n_pos]
			var w_h_b: float = float(data_b.get("water_height", 0.0))
			var b_h_b: float = float(data_b.get("bed_height", 0.0))
			var d_b: float = float(data_b.get("depth", 0.0))

			assert(is_finite(w_h_b), "water_height at neighbor %s is not finite" % str(n_pos))
			assert(is_finite(b_h_b), "bed_height at neighbor %s is not finite" % str(n_pos))
			assert(d_b >= -0.001, "depth at neighbor %s is negative: %.4f" % [str(n_pos), d_b])

			# Verificación de continuidad de superficie de agua
			var delta_w: float = absf(w_h_a - w_h_b)
			if delta_w < 0.001:
				planar_pairs += 1
			else:
				# Existe un escalón hidráulico (ej. cascada entre dos tramos o meandro descendente)
				stepped_pairs += 1
				# El escalón debe ser razonable para un cambio de celdas adyacentes
				assert(delta_w < 50.0, "Salto abrupto e irracional de agua entre %s y %s: delta=%.4f" % [str(pos), str(n_pos), delta_w])

			# Verificación de continuidad del lecho marino/fluvial
			var delta_bed: float = absf(b_h_a - b_h_b)
			assert(delta_bed < 50.0, "Salto abrupto de fondo entre %s y %s: delta=%.4f" % [str(pos), str(n_pos), delta_bed])

			verified_pairs += 1

	print("  Cardinal water pairs verified: %d (Planar: %d, Stepped: %d)" % [verified_pairs, planar_pairs, stepped_pairs])
	assert(verified_pairs > 0, "Debe haber pares contiguos de agua verificados")
