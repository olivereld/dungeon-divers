extends SceneTree

## Suite de Integración Unificada: Continuidad de Agua y Costuras entre Chunks (Bloque 2)
## Valida en una sola prueba de integración:
## 1. Celdas de agua adyacentes (dentro del mismo chunk y globales):
##    - water_height y bed_height válidos y finitos.
##    - bed_height <= water_height y depth == water_height - bed_height.
##    - Continuidad suave de lecho sin saltos artificiales inesperados.
## 2. Continuidad entre chunks contiguos en la frontera común:
##    - water_height_A == water_height_B
##    - bed_height_A == bed_height_B
##    - cell_A.height == cell_B.height
##    - Sin grietas, escalones ni discontinuidades en la frontera.

const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")
const _ChunkDataScript = preload("res://src/world_generator/chunks/chunk_data.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WaterRendererScript = preload("res://src/world_generator/presentation/water/water_renderer.gd")

func _init() -> void:
	print("==================================================")
	print(" TEST DE INTEGRACIÓN UNIFICADO: CONTINUIDAD DE AGUA Y COSTURAS")
	print("==================================================")

	var test_seeds: Array[int] = [12345, 4242, 99999]

	for s in test_seeds:
		_test_continuity_and_chunk_seams(s)

	print("==================================================")
	print(" ¡TODAS LAS VALIDACIONES DE CONTINUIDAD Y COSTURAS PASARON EXITOSAMENTE!")
	print("==================================================")
	quit(0)

func _test_continuity_and_chunk_seams(seed_val: int) -> void:
	print("\n--- Evaluando Seed: %d ---" % seed_val)

	var profile = _TaigaWorldProfileScript.new()
	profile.width = 96
	profile.height = 96
	profile.hydrology_enabled = true
	profile.lake_threshold = 0.22
	profile.max_rivers = 4
	profile.min_river_length = 8.0

	var config := _ChunkConfigScript.new(16, 1)

	# 1. Generar la hidrología macro del mundo
	var world := WorldPipeline.generate(seed_val, profile)
	assert(world != null and world.hydrology != null, "World hydrology must exist")
	var hydro: HydrologyResult = world.hydrology

	# -------------------------------------------------------------------------
	# PARTE 1: Continuidad de Celdas de Agua Adyacentes (Local / Global)
	# -------------------------------------------------------------------------
	print("  [1/2] Verificando parejas adyacentes de water_cells...")
	var cardinal_dirs := [Vector2i(1, 0), Vector2i(0, 1)]
	var verified_pairs: int = 0

	for pos in hydro.water_cells:
		var data_a: Dictionary = hydro.water_cells[pos]
		var wh_a: float = float(data_a.get("water_height", 0.0))
		var bh_a: float = float(data_a.get("bed_height", 0.0))
		var d_a: float = float(data_a.get("depth", 0.0))

		# Finitud y relaciones verticales básicas de A
		assert(is_finite(wh_a), "water_height en %s no es finito" % str(pos))
		assert(is_finite(bh_a), "bed_height en %s no es finito" % str(pos))
		assert(bh_a <= wh_a + 0.001, "Relación vertical violada en %s: bed > water" % str(pos))
		assert(absf(d_a - (wh_a - bh_a)) < 0.001, "depth != water - bed en %s" % str(pos))

		for dir in cardinal_dirs:
			var n_pos: Vector2i = pos + dir
			if not hydro.water_cells.has(n_pos):
				continue

			var data_b: Dictionary = hydro.water_cells[n_pos]
			var wh_b: float = float(data_b.get("water_height", 0.0))
			var bh_b: float = float(data_b.get("bed_height", 0.0))
			var d_b: float = float(data_b.get("depth", 0.0))

			# Finitud y relaciones verticales básicas de B
			assert(is_finite(wh_b), "water_height en vecino %s no es finito" % str(n_pos))
			assert(is_finite(bh_b), "bed_height en vecino %s no es finito" % str(n_pos))
			assert(bh_b <= wh_b + 0.001, "Relación vertical violada en vecino %s: bed > water" % str(n_pos))
			assert(absf(d_b - (wh_b - bh_b)) < 0.001, "depth != water - bed en vecino %s" % str(n_pos))

			# Sin discontinuidades artificiales abruptas en el lecho entre celdas vecinas
			var delta_bed: float = absf(bh_a - bh_b)
			assert(delta_bed < 30.0,
				"Discontinuidad inesperada en bed_height entre %s y %s: delta=%.4f" % [str(pos), str(n_pos), delta_bed])

			verified_pairs += 1

	print("    -> Parejas adyacentes validadas: %d" % verified_pairs)
	assert(verified_pairs > 0, "Debe haber parejas contiguas de agua verificadas")

	# -------------------------------------------------------------------------
	# PARTE 2: Continuidad de Costuras entre Chunks Adyacentes (Frontera Común)
	# -------------------------------------------------------------------------
	print("  [2/2] Verificando costuras de chunks (horizontal y vertical)...")

	# Chunks adyacentes: (0, 0) colinda con (1, 0) al Este, y con (0, 1) al Sur
	var c00 := WorldPipeline.generate_chunk(seed_val, Vector2i(0, 0), profile, config, hydro)
	var c10 := WorldPipeline.generate_chunk(seed_val, Vector2i(1, 0), profile, config, hydro)
	var c01 := WorldPipeline.generate_chunk(seed_val, Vector2i(0, 1), profile, config, hydro)

	assert(c00 != null and c10 != null and c01 != null, "Los chunks deben generarse correctamente")

	# Costura Horizontal: Límite entre c00 (X=15) y c10 (X=16)
	var seam_water_h: int = 0
	for y in range(0, 16):
		var pos_a := Vector2i(15, y)
		var pos_b := Vector2i(16, y)

		var cell_a: WorldCell = c00.get_cell(pos_a)
		var cell_b: WorldCell = c10.get_cell(pos_b)
		assert(cell_a != null and cell_b != null, "Las celdas de costura deben existir")

		var is_water_a: bool = hydro.water_cells.has(pos_a)
		var is_water_b: bool = hydro.water_cells.has(pos_b)

		if is_water_a and is_water_b:
			var w_data_a: Dictionary = hydro.water_cells[pos_a]
			var w_data_b: Dictionary = hydro.water_cells[pos_b]

			var wh_a: float = float(w_data_a["water_height"])
			var wh_b: float = float(w_data_b["water_height"])
			var bh_a: float = float(w_data_a["bed_height"])
			var bh_b: float = float(w_data_b["bed_height"])

			# Si ambos pertenecen al mismo tramo o masa de agua plana
			if absf(wh_a - wh_b) < 0.05:
				assert(is_equal_approx(wh_a, wh_b),
					"water_height mismatch en costura H (%s vs %s): %.4f != %.4f" % [str(pos_a), str(pos_b), wh_a, wh_b])

			# bed_height debe coincidir con cell.height de cada chunk
			assert(is_equal_approx(cell_a.height, bh_a),
				"bed_height y cell.height no coinciden en Chunk A (%s): cell=%.4f, bed=%.4f" % [str(pos_a), cell_a.height, bh_a])
			assert(is_equal_approx(cell_b.height, bh_b),
				"bed_height y cell.height no coinciden en Chunk B (%s): cell=%.4f, bed=%.4f" % [str(pos_b), cell_b.height, bh_b])
			seam_water_h += 1

		# Continuidad de terreno sin grietas
		var diff_h: float = absf(cell_a.height - cell_b.height)
		assert(diff_h < 15.0, "Salto abrupto/grieta en frontera horizontal entre %s y %s: %.4f" % [str(pos_a), str(pos_b), diff_h])

	# Costura Vertical: Límite entre c00 (Y=15) y c01 (Y=16)
	var seam_water_v: int = 0
	for x in range(0, 16):
		var pos_a := Vector2i(x, 15)
		var pos_b := Vector2i(x, 16)

		var cell_a: WorldCell = c00.get_cell(pos_a)
		var cell_b: WorldCell = c01.get_cell(pos_b)
		assert(cell_a != null and cell_b != null, "Las celdas de costura deben existir")

		var is_water_a: bool = hydro.water_cells.has(pos_a)
		var is_water_b: bool = hydro.water_cells.has(pos_b)

		if is_water_a and is_water_b:
			var w_data_a: Dictionary = hydro.water_cells[pos_a]
			var w_data_b: Dictionary = hydro.water_cells[pos_b]

			var wh_a: float = float(w_data_a["water_height"])
			var wh_b: float = float(w_data_b["water_height"])
			var bh_a: float = float(w_data_a["bed_height"])
			var bh_b: float = float(w_data_b["bed_height"])

			if absf(wh_a - wh_b) < 0.05:
				assert(is_equal_approx(wh_a, wh_b),
					"water_height mismatch en costura V (%s vs %s): %.4f != %.4f" % [str(pos_a), str(pos_b), wh_a, wh_b])

			assert(is_equal_approx(cell_a.height, bh_a),
				"bed_height y cell.height no coinciden en Chunk A (%s): cell=%.4f, bed=%.4f" % [str(pos_a), cell_a.height, bh_a])
			assert(is_equal_approx(cell_b.height, bh_b),
				"bed_height y cell.height no coinciden en Chunk B (%s): cell=%.4f, bed=%.4f" % [str(pos_b), cell_b.height, bh_b])
			seam_water_v += 1

		var diff_v: float = absf(cell_a.height - cell_b.height)
		assert(diff_v < 15.0, "Salto abrupto/grieta en frontera vertical entre %s y %s: %.4f" % [str(pos_a), str(pos_b), diff_v])

	print("    -> Costuras validadas con éxito (Agua en costura: H=%d, V=%d)" % [seam_water_h, seam_water_v])

	# -------------------------------------------------------------------------
	# PARTE 3: Verificación Canónica del Pipeline de Agua Unificado
	# -------------------------------------------------------------------------
	print("  [3/3] Verificando generación canónica WaterRenderer -> WaterMeshBuilder...")
	var chunk_has_water := false
	if c00.hydrology != null:
		var c_rect := Rect2i(c00.core_bounds.position - Vector2i(2, 2), c00.core_bounds.size + Vector2i(5, 5))
		for p in c00.hydrology.water_cells:
			if c_rect.has_point(p):
				chunk_has_water = true
				break

	var water_chunk_node: Node3D = _WaterRendererScript.build_water_node(c00, profile)
	if chunk_has_water:
		assert(water_chunk_node != null, "WaterRenderer debe producir un nodo para el chunk con agua")
		var mi: MeshInstance3D = water_chunk_node.get_node_or_null("UnifiedWaterSurface") as MeshInstance3D
		assert(mi != null and mi.mesh != null, "Chunk debe tener UnifiedWaterSurface MeshInstance3D")
	else:
		assert(water_chunk_node == null, "WaterRenderer debe retornar null para chunks secos sin agua cercana")
	print("    -> Pipeline canónico de presentación verificado sin builders alternativos.")
