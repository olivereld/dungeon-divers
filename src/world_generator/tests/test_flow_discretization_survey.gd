extends SceneTree

const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")

const SEED_COUNT: int = 100
const REPORT_PATH: String = "res://docs/hydrology_flow_survey_report.txt"

func _init() -> void:
	print("==================================================")
	print(" Starting Flow Discretization 100-Seed Survey")
	print("==================================================")

	var aggregate := {
		"seed_count": SEED_COUNT,
		"map_cells": 128 * 128,
		"total_suspicious_ties": 0,
		"seeds_with_suspicious_ties": 0,
		"total_flagged_chains": 0,
		"seeds_with_flagged_chains": 0,
		"total_chains_ge_15": 0,
		"total_diag_flagged_ge_15": 0,
		"total_card_flagged_ge_15": 0,
		"total_unreachable_cells": 0,
		"seeds_with_unreachable_cells": 0,
		"total_suspicious_flat_regions": 0,
		"total_suspicious_flat_area": 0,
		"seeds_with_suspicious_flat_regions": 0,
	}

	# Listas para rastrear peores casos: Array de { "seed": int, "value": float/int, "details": String }
	var worst_ties: Array[Dictionary] = []
	var worst_diag_chains: Array[Dictionary] = []
	var worst_card_chains: Array[Dictionary] = []
	var worst_unreachable: Array[Dictionary] = []
	var worst_flat_area: Array[Dictionary] = []

	var start_time := Time.get_ticks_msec()

	for i in range(SEED_COUNT):
		var seed_value: int = 1000 + i * 37
		var result_metrics: Dictionary = _run_single_seed(seed_value)
		_accumulate(aggregate, seed_value, result_metrics, worst_ties, worst_diag_chains, worst_card_chains, worst_unreachable, worst_flat_area)
		if (i + 1) % 10 == 0 or i == 0:
			print("  [Progress] Completed %d/%d seeds..." % [i + 1, SEED_COUNT])

	var total_duration_sec: float = float(Time.get_ticks_msec() - start_time) / 1000.0
	print("  [Done] All %d seeds processed in %.2f seconds." % [SEED_COUNT, total_duration_sec])

	var report_text := _format_report(aggregate, worst_ties, worst_diag_chains, worst_card_chains, worst_unreachable, worst_flat_area, total_duration_sec)
	print("\n" + report_text)
	_save_report(report_text)

	quit()


func _run_single_seed(seed_value: int) -> Dictionary:
	var profile: WorldProfile = _TaigaWorldProfileScript.new()
	profile.width = 128
	profile.height = 128
	profile.hydrology_enabled = true
	profile.lake_threshold = 0.25
	profile.max_rivers = 3
	profile.min_river_length = 10.0
	profile.hydrology_debug_metrics_enabled = true

	var result: WorldResult = WorldPipeline.generate(seed_value, profile)
	if result == null or result.hydrology == null:
		return {}

	return result.hydrology.debug_layers.get("flow_metrics", {})


func _accumulate(
	aggregate: Dictionary,
	seed_value: int,
	metrics: Dictionary,
	worst_ties: Array[Dictionary],
	worst_diag_chains: Array[Dictionary],
	worst_card_chains: Array[Dictionary],
	worst_unreachable: Array[Dictionary],
	worst_flat_area: Array[Dictionary]
) -> void:
	if metrics.is_empty():
		return

	# 1. Suspicious ties
	var ties_arr: Array = metrics.get("suspicious_ties", [])
	var tie_count: int = ties_arr.size()
	aggregate["total_suspicious_ties"] += tie_count
	if tie_count > 0:
		aggregate["seeds_with_suspicious_ties"] += 1
	worst_ties.append({ "seed": seed_value, "value": tie_count, "pct": (float(tie_count) / float(aggregate["map_cells"])) * 100.0 })

	# 2. Chains & Streaks
	var flagged_chains: Array = metrics.get("flagged_chains", [])
	var flagged_count: int = flagged_chains.size()
	aggregate["total_flagged_chains"] += flagged_count
	if flagged_count > 0:
		aggregate["seeds_with_flagged_chains"] += 1

	var diag_streaks: Dictionary = metrics.get("max_diagonal_streak_per_chain", {})
	var card_streaks: Dictionary = metrics.get("max_cardinal_streak_per_chain", {})
	var chain_lens: Dictionary = metrics.get("chain_lengths", {})

	var seed_chains_ge_15: int = 0
	var seed_diag_ge_15: int = 0
	var seed_card_ge_15: int = 0

	for c_id in chain_lens:
		var l: int = int(chain_lens[c_id])
		if l >= 15:
			seed_chains_ge_15 += 1
			if int(diag_streaks.get(c_id, 0)) >= FlowDiscretizationMetrics.DIAGONAL_STREAK_WARN:
				seed_diag_ge_15 += 1
			if int(card_streaks.get(c_id, 0)) >= FlowDiscretizationMetrics.CARDINAL_STREAK_WARN:
				seed_card_ge_15 += 1

	aggregate["total_chains_ge_15"] += seed_chains_ge_15
	aggregate["total_diag_flagged_ge_15"] += seed_diag_ge_15
	aggregate["total_card_flagged_ge_15"] += seed_card_ge_15

	var diag_rate: float = (float(seed_diag_ge_15) / float(seed_chains_ge_15) * 100.0) if seed_chains_ge_15 > 0 else 0.0
	var card_rate: float = (float(seed_card_ge_15) / float(seed_chains_ge_15) * 100.0) if seed_chains_ge_15 > 0 else 0.0
	worst_diag_chains.append({ "seed": seed_value, "value": seed_diag_ge_15, "total": seed_chains_ge_15, "rate": diag_rate })
	worst_card_chains.append({ "seed": seed_value, "value": seed_card_ge_15, "total": seed_chains_ge_15, "rate": card_rate })

	# 3. Unreachable cells
	var unreach_arr: Array = metrics.get("unreachable_cells", [])
	var unreach_count: int = unreach_arr.size()
	aggregate["total_unreachable_cells"] += unreach_count
	if unreach_count > 0:
		aggregate["seeds_with_unreachable_cells"] += 1
	worst_unreachable.append({ "seed": seed_value, "value": unreach_count })

	# 4. Suspicious flat regions
	var flats_arr: Array = metrics.get("suspicious_flat_regions", [])
	var flat_regions_count: int = flats_arr.size()
	var flat_area_sum: int = 0
	for r in flats_arr:
		flat_area_sum += int(r.get("area", 0))

	aggregate["total_suspicious_flat_regions"] += flat_regions_count
	aggregate["total_suspicious_flat_area"] += flat_area_sum
	if flat_regions_count > 0:
		aggregate["seeds_with_suspicious_flat_regions"] += 1

	var flat_area_pct: float = (float(flat_area_sum) / float(aggregate["map_cells"])) * 100.0
	worst_flat_area.append({ "seed": seed_value, "value": flat_area_sum, "pct": flat_area_pct, "regions": flat_regions_count })


func _sort_descending(arr: Array[Dictionary], key: String) -> void:
	arr.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get(key, 0.0)) > float(b.get(key, 0.0))
	)


func _format_report(
	agg: Dictionary,
	worst_ties: Array[Dictionary],
	worst_diag: Array[Dictionary],
	worst_card: Array[Dictionary],
	worst_unreach: Array[Dictionary],
	worst_flat: Array[Dictionary],
	duration_sec: float
) -> String:
	_sort_descending(worst_ties, "value")
	_sort_descending(worst_diag, "rate")
	_sort_descending(worst_card, "rate")
	_sort_descending(worst_unreach, "value")
	_sort_descending(worst_flat, "pct")

	var n: float = float(agg["seed_count"])
	var total_cells_all_seeds: float = float(agg["map_cells"]) * n

	var avg_ties: float = float(agg["total_suspicious_ties"]) / n
	var avg_ties_pct: float = (float(agg["total_suspicious_ties"]) / total_cells_all_seeds) * 100.0

	var total_chains_ge_15: float = float(agg["total_chains_ge_15"])
	var diag_rate_total: float = (float(agg["total_diag_flagged_ge_15"]) / maxf(1.0, total_chains_ge_15)) * 100.0
	var card_rate_total: float = (float(agg["total_card_flagged_ge_15"]) / maxf(1.0, total_chains_ge_15)) * 100.0

	var avg_unreach: float = float(agg["total_unreachable_cells"]) / n
	var avg_flat_area: float = float(agg["total_suspicious_flat_area"]) / n
	var avg_flat_area_pct: float = (float(agg["total_suspicious_flat_area"]) / total_cells_all_seeds) * 100.0

	var out: String = ""
	out += "================================================================================\n"
	out += " REPORTE CUANTITATIVO: SURVEY DE DISCRETIZACIÓN DE FLOW FIELD (100 SEEDS)\n"
	out += "================================================================================\n"
	out += "Fecha de ejecución: %s\n" % Time.get_datetime_string_from_system()
	out += "Seeds evaluadas: %d (1000 a %d con paso 37)\n" % [agg["seed_count"], 1000 + (agg["seed_count"] - 1) * 37]
	out += "Dimensiones por mapa: 128x128 (%d celdas por seed, %d total evaluadas)\n" % [agg["map_cells"], int(total_cells_all_seeds)]
	out += "Tiempo total: %.2f s (%.1f ms/seed)\n\n" % [duration_sec, (duration_sec / n) * 1000.0]

	out += "--------------------------------------------------------------------------------\n"
	out += " 1. RESUMEN GLOBAL Y COMPARATIVA CONTRA UMBRALES DE ACTIVACIÓN (BLOQUE C)\n"
	out += "--------------------------------------------------------------------------------\n"
	out += "| Métrica                       | Medición 100 seeds | Umbral Activación | ¿Activa Fix? |\n"
	out += "|-------------------------------|--------------------|-------------------|--------------|\n"

	var c1_active: bool = avg_ties_pct > 0.5
	out += "| Suspicious Ties (Bifurc.)     | %6.3f%% celdas     | > 0.500%% celdas   | %-12s |\n" % [avg_ties_pct, "SÍ (C1)" if c1_active else "NO"]

	var c2_active: bool = diag_rate_total > 10.0
	out += "| Diagonal Streaks (L >= 15)    | %6.2f%% cadenas    | > 10.00%% cadenas  | %-12s |\n" % [diag_rate_total, "SÍ (C2)" if c2_active else "NO"]

	var c3_active: bool = card_rate_total > 10.0
	out += "| Cardinal Streaks (Grid-snap)  | %6.2f%% cadenas    | > 10.00%% cadenas  | %-12s |\n" % [card_rate_total, "SÍ (C3)" if c3_active else "NO"]

	var c4_active: bool = agg["total_unreachable_cells"] > 0
	out += "| Unreachable Cells (Ciclos)    | %6d total         | > 0 en cualq.     | %-12s |\n" % [agg["total_unreachable_cells"], "SÍ (C4, OBLIG)" if c4_active else "NO"]

	var c5_active: bool = avg_flat_area_pct > 2.0
	out += "| Suspicious Flats (Fantasma)   | %6.3f%% mapa       | > 2.000%% mapa     | %-12s |\n" % [avg_flat_area_pct, "SÍ (C5)" if c5_active else "NO"]
	out += "--------------------------------------------------------------------------------\n\n"

	out += "--------------------------------------------------------------------------------\n"
	out += " 2. DETALLE ESTADÍSTICO POR CATEGORÍA\n"
	out += "--------------------------------------------------------------------------------\n"
	out += "A. Suspicious Ties (Empates no-colineales en score):\n"
	out += "   - Total absoluto: %d celdas en todo el lote\n" % agg["total_suspicious_ties"]
	out += "   - Promedio por seed: %.2f celdas (%.4f%% del mapa)\n" % [avg_ties, avg_ties_pct]
	out += "   - Seeds con al menos 1 tie: %d / %d\n" % [agg["seeds_with_suspicious_ties"], agg["seed_count"]]
	out += "   - Top 5 peores seeds:\n"
	for i in range(mini(5, worst_ties.size())):
		var item: Dictionary = worst_ties[i]
		out += "       %d. Seed %d: %d ties (%.3f%% del mapa)\n" % [i + 1, item["seed"], item["value"], item["pct"]]
	out += "\n"

	out += "B. Diagonal Streaks (Rachas consecutivas de pasos diagonales >= 5):\n"
	out += "   - Cadenas con longitud >= 15 evaluadas: %d\n" % int(total_chains_ge_15)
	out += "   - Cadenas (L>=15) con racha diagonal >= 5: %d (%.2f%%)\n" % [agg["total_diag_flagged_ge_15"], diag_rate_total]
	out += "   - Top 5 peores seeds por tasa de rachas diagonales en cadenas largas:\n"
	for i in range(mini(5, worst_diag.size())):
		var item: Dictionary = worst_diag[i]
		out += "       %d. Seed %d: %d/%d cadenas largas (%.1f%%)\n" % [i + 1, item["seed"], item["value"], item["total"], item["rate"]]
	out += "\n"

	out += "C. Cardinal Streaks / Grid-Snapping (Rachas consecutivas de pasos cardinales >= 5):\n"
	out += "   - Cadenas (L>=15) con racha cardinal >= 5: %d (%.2f%%)\n" % [agg["total_card_flagged_ge_15"], card_rate_total]
	out += "   - Top 5 peores seeds por tasa de rachas cardinales en cadenas largas:\n"
	for i in range(mini(5, worst_card.size())):
		var item: Dictionary = worst_card[i]
		out += "       %d. Seed %d: %d/%d cadenas largas (%.1f%%)\n" % [i + 1, item["seed"], item["value"], item["total"], item["rate"]]
	out += "\n"

	out += "D. Unreachable Cells (Celdas sin terminal / ciclos detectados):\n"
	out += "   - Total absoluto: %d celdas\n" % agg["total_unreachable_cells"]
	out += "   - Seeds afectadas: %d / %d\n" % [agg["seeds_with_unreachable_cells"], agg["seed_count"]]
	if agg["total_unreachable_cells"] > 0:
		out += "   - Top 5 peores seeds:\n"
		for i in range(mini(5, worst_unreach.size())):
			var item: Dictionary = worst_unreach[i]
			if item["value"] > 0:
				out += "       %d. Seed %d: %d celdas inalcanzables\n" % [i + 1, item["seed"], item["value"]]
	else:
		out += "   - ¡PERFECTO! Cero celdas inalcanzables en las 100 seeds. Aciclicidad confirmada al 100%.\n"
	out += "\n"

	out += "E. Suspicious Flat Regions (Planicies fantasma post Priority-Flood con varianza en H_raw):\n"
	out += "   - Total de regiones sospechosas detectadas: %d\n" % agg["total_suspicious_flat_regions"]
	out += "   - Área total acumulada: %d celdas (promedio %.2f celdas/seed, %.4f%% del mapa)\n" % [agg["total_suspicious_flat_area"], avg_flat_area, avg_flat_area_pct]
	out += "   - Seeds con regiones sospechosas: %d / %d\n" % [agg["seeds_with_suspicious_flat_regions"], agg["seed_count"]]
	out += "   - Top 5 peores seeds por área plana sospechosa:\n"
	for i in range(mini(5, worst_flat.size())):
		var item: Dictionary = worst_flat[i]
		out += "       %d. Seed %d: %d celdas (%.3f%% del mapa, %d regiones)\n" % [i + 1, item["seed"], item["value"], item["pct"], item["regions"]]
	out += "\n"

	out += "================================================================================\n"
	out += " CONCLUSIÓN PARA EL BLOQUE C\n"
	out += "================================================================================\n"
	var any_fix_needed: bool = c1_active or c2_active or c3_active or c4_active or c5_active
	if not any_fix_needed:
		out += ">> RESULTADO: NINGÚN UMBRAL FUE SUPERADO. La discretización actual opera dentro de\n"
		out += "   los márgenes de calidad geomorfológica especificados. No se justifica modificar\n"
		out += "   la función de score ni los pesos del algoritmo D8.\n"
	else:
		out += ">> RESULTADO: Se superaron umbrales en las siguientes sub-tareas:\n"
		if c1_active:
			out += "   - Sub-tarea C1 (Ties > 0.5%): Activa fix de persistencia de dirección.\n"
		if c2_active:
			out += "   - Sub-tarea C2 (Diagonal > 10%): Activa factor alignment por pendiente.\n"
		if c3_active:
			out += "   - Sub-tarea C3 (Cardinal > 10%): Activa ajuste de drop por distancia euclídea.\n"
		if c4_active:
			out += "   - Sub-tarea C4 (Ciclos > 0): OBLIGATORIO corregir orden causal de flood_rank.\n"
		if c5_active:
			out += "   - Sub-tarea C5 (Flats > 2%): Activa micro-gradiente determinista.\n"
	out += "================================================================================\n"
	return out


func _save_report(report: String) -> void:
	var global_path: String = ProjectSettings.globalize_path(REPORT_PATH)
	var file := FileAccess.open(global_path, FileAccess.WRITE)
	if file != null:
		file.store_string(report)
		file.close()
		print("  [Saved] Report saved to: %s" % global_path)
	else:
		printerr("  [Error] Could not save report to: %s" % global_path)
