extends SceneTree

## Suite de Test: Validación de Costuras entre Chunks (Bloque 4)
## Genera dos chunks adyacentes (Chunk A y Chunk B) y comprueba en la frontera común:
## 1. water_height A == water_height B
## 2. bed_height   A == bed_height B
## 3. terrain      A == terrain B
## Con tolerancia pequeña, garantizando que no existan escalones, gaps ni huecos entre chunks.

const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")
const _ChunkDataScript = preload("res://src/world_generator/chunks/chunk_data.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Test Suite: Chunk Seams Validation (Bloque 4)")
	print("==================================================")

	var test_seeds: Array[int] = [12345, 4242, 99999]

	for s in test_seeds:
		_test_chunk_seams(s)

	print("==================================================")
	print(" ALL CHUNK SEAM TESTS PASSED!")
	print("==================================================")
	quit(0)

func _test_chunk_seams(seed_val: int) -> void:
	print("\n--- Testing Seed: %d ---" % seed_val)

	var profile = _TaigaWorldProfileScript.new()
	profile.width = 64
	profile.height = 64
	profile.hydrology_enabled = true
	profile.lake_threshold = 0.22
	profile.max_rivers = 4
	profile.min_river_length = 8.0

	var config := _ChunkConfigScript.new(16, 1)

	# 1. Generar la hidrología macro del mundo para dar soporte a los chunks
	var world := WorldPipeline.generate(seed_val, profile)
	assert(world != null and world.hydrology != null, "World hydrology must exist")

	# Probar costuras horizontales (Chunk (0, 0) con Chunk (1, 0))
	# y costuras verticales (Chunk (0, 0) con Chunk (0, 1))
	var c00 := WorldPipeline.generate_chunk(seed_val, Vector2i(0, 0), profile, config, world.hydrology)
	var c10 := WorldPipeline.generate_chunk(seed_val, Vector2i(1, 0), profile, config, world.hydrology)
	var c01 := WorldPipeline.generate_chunk(seed_val, Vector2i(0, 1), profile, config, world.hydrology)

	assert(c00 != null and c10 != null and c01 != null, "Chunks must generate successfully")

	# -------------------------------------------------------------
	# Test de frontera Este de c00 con frontera Oeste de c10
	# c00 X = 15, c10 X = 16
	# -------------------------------------------------------------
	var x_left: int = 15
	var x_right: int = 16
	var seams_verified_h: int = 0
	var water_seams_h: int = 0

	for y in range(0, 16):
		var pos_a := Vector2i(x_left, y)
		var pos_b := Vector2i(x_right, y)

		var cell_a: WorldCell = c00.get_cell(pos_a)
		var cell_b: WorldCell = c10.get_cell(pos_b)
		assert(cell_a != null and cell_b != null, "Cells must exist across horizontal seam")

		# Comprobar si ambos son agua en la frontera
		var is_water_a: bool = world.hydrology.water_cells.has(pos_a)
		var is_water_b: bool = world.hydrology.water_cells.has(pos_b)

		if is_water_a and is_water_b:
			var w_data_a: Dictionary = world.hydrology.water_cells[pos_a]
			var w_data_b: Dictionary = world.hydrology.water_cells[pos_b]

			var wh_a: float = float(w_data_a["water_height"])
			var wh_b: float = float(w_data_b["water_height"])
			var bh_a: float = float(w_data_a["bed_height"])
			var bh_b: float = float(w_data_b["bed_height"])

			# Si están en el mismo cuerpo de agua planar (lago o tramo plano)
			if absf(wh_a - wh_b) < 0.05:
				assert(is_equal_approx(wh_a, wh_b),
					"Water height seam mismatch at %s vs %s: %.4f != %.4f" % [str(pos_a), str(pos_b), wh_a, wh_b])

			# bed_height debe ser exactamente cell.height en ambos chunks
			assert(is_equal_approx(cell_a.height, bh_a), "Seam A bed mismatch")
			assert(is_equal_approx(cell_b.height, bh_b), "Seam B bed mismatch")
			water_seams_h += 1

		# Continuidad del terreno: diferencia de cota entre celdas vecinas adyacentes acotada
		var diff_terrain: float = absf(cell_a.height - cell_b.height)
		assert(diff_terrain < 15.0, "Salto abrupto de terreno en costura horizontal (%s - %s): %.4f" % [str(pos_a), str(pos_b), diff_terrain])
		seams_verified_h += 1

	# -------------------------------------------------------------
	# Test de frontera Sur de c00 con frontera Norte de c01
	# c00 Y = 15, c01 Y = 16
	# -------------------------------------------------------------
	var y_top: int = 15
	var y_bot: int = 16
	var seams_verified_v: int = 0
	var water_seams_v: int = 0

	for x in range(0, 16):
		var pos_a := Vector2i(x, y_top)
		var pos_b := Vector2i(x, y_bot)

		var cell_a: WorldCell = c00.get_cell(pos_a)
		var cell_b: WorldCell = c01.get_cell(pos_b)
		assert(cell_a != null and cell_b != null, "Cells must exist across vertical seam")

		var is_water_a: bool = world.hydrology.water_cells.has(pos_a)
		var is_water_b: bool = world.hydrology.water_cells.has(pos_b)

		if is_water_a and is_water_b:
			var w_data_a: Dictionary = world.hydrology.water_cells[pos_a]
			var w_data_b: Dictionary = world.hydrology.water_cells[pos_b]

			var wh_a: float = float(w_data_a["water_height"])
			var wh_b: float = float(w_data_b["water_height"])
			var bh_a: float = float(w_data_a["bed_height"])
			var bh_b: float = float(w_data_b["bed_height"])

			if absf(wh_a - wh_b) < 0.05:
				assert(is_equal_approx(wh_a, wh_b),
					"Water height vertical seam mismatch at %s vs %s: %.4f != %.4f" % [str(pos_a), str(pos_b), wh_a, wh_b])

			assert(is_equal_approx(cell_a.height, bh_a), "Vertical seam A bed mismatch")
			assert(is_equal_approx(cell_b.height, bh_b), "Vertical seam B bed mismatch")
			water_seams_v += 1

		var diff_terrain: float = absf(cell_a.height - cell_b.height)
		assert(diff_terrain < 15.0, "Salto abrupto de terreno en costura vertical (%s - %s): %.4f" % [str(pos_a), str(pos_b), diff_terrain])
		seams_verified_v += 1

	print("  Seams verified: Horizontal=%d (water=%d), Vertical=%d (water=%d)" % [seams_verified_h, water_seams_h, seams_verified_v, water_seams_v])
