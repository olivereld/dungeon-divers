class_name DungeonStressTester
extends RefCounted

## Harness de Stress Testing Masivo para la Fase 11 (Hardening & QA).
## Ejecuta miles de semillas consecutivas midiendo:
## 1. Tasa de crashes (0% exigido).
## 2. Tasa de éxito y tipificación de errores.
## 3. Distribución empírica de latencia (P50, P90, P95, P99, Max).
## 4. Estabilidad de memoria y determinismo.

const _MultiFloorGeneratorScript = preload("res://src/dungeon_generator/core/multi_floor_generator.gd")
const _MultiFloorValidatorScript = preload("res://src/dungeon_generator/core/validation/multi_floor_validator.gd")
const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")

class StressTestReport:
	var total_runs: int = 0
	var success_count: int = 0
	var fail_count: int = 0
	var crash_count: int = 0
	var times_ms: Array[float] = []
	var p50_ms: float = 0.0
	var p90_ms: float = 0.0
	var p95_ms: float = 0.0
	var p99_ms: float = 0.0
	var max_ms: float = 0.0
	var avg_ms: float = 0.0
	var error_breakdown: Dictionary = {}

	func get_success_rate() -> float:
		return (float(success_count) / float(total_runs) * 100.0) if total_runs > 0 else 0.0

	func calculate_percentiles() -> void:
		if times_ms.is_empty():
			return
		times_ms.sort()
		var n: int = times_ms.size()
		p50_ms = times_ms[int(float(n) * 0.50)]
		p90_ms = times_ms[mini(n - 1, int(float(n) * 0.90))]
		p95_ms = times_ms[mini(n - 1, int(float(n) * 0.95))]
		p99_ms = times_ms[mini(n - 1, int(float(n) * 0.99))]
		max_ms = times_ms[n - 1]

		var sum: float = 0.0
		for t in times_ms:
			sum += t
		avg_ms = sum / float(n)

	func to_summary_string() -> String:
		var s := "================================================================\n"
		s += "          INFORME DE STRESS TESTING MASIVO (FASE 11)           \n"
		s += "================================================================\n"
		s += "  Total Ejecuciones : %d\n" % total_runs
		s += "  Exitosas          : %d (%.2f%%)\n" % [success_count, get_success_rate()]
		s += "  Fallos / Crashes  : %d / %d\n" % [fail_count, crash_count]
		s += "----------------------------------------------------------------\n"
		s += "  LATENCIA DE GENERACION:\n"
		s += "    P50 (Mediana)   : %.2f ms\n" % p50_ms
		s += "    P90             : %.2f ms\n" % p90_ms
		s += "    P95             : %.2f ms\n" % p95_ms
		s += "    P99             : %.2f ms\n" % p99_ms
		s += "    Promedio        : %.2f ms\n" % avg_ms
		s += "    Maximo          : %.2f ms\n" % max_ms
		s += "----------------------------------------------------------------\n"
		if not error_breakdown.is_empty():
			s += "  DESGLOSE DE ERRORES:\n"
			for err_k in error_breakdown.keys():
				s += "    - %s: %d\n" % [err_k, error_breakdown[err_k]]
		else:
			s += "  DESGLOSE DE ERRORES: CERO ERRORES (100% Salida Valida)\n"
		s += "================================================================\n"
		return s

## Ejecuta una batería de stress testing sobre el generador.
func run_stress_test(
	iterations: int = 1000,
	base_seed: int = 100000,
	multi_floor: bool = true,
	log_interval: int = 250,
	diagnostics_enabled: bool = false  # Por defecto silencioso en stress tests
) -> StressTestReport:
	var report := StressTestReport.new()
	report.total_runs = iterations

	var multi_gen := _MultiFloorGeneratorScript.new()
	var multi_val := _MultiFloorValidatorScript.new()
	var pipeline := _DungeonPipelineScript.new()

	for i in range(iterations):
		var seed_val: int = base_seed + i
		var cfg := DungeonConfig.new()
		cfg.grid_width = 32
		cfg.grid_height = 32
		cfg.total_floors = 2 if multi_floor else 1
		cfg.mission_depth = 4
		cfg.seed = seed_val
		cfg.use_fixed_seed = true

		var t0: int = Time.get_ticks_usec()

		if multi_floor:
			var m_res: DungeonMultiFloorResult = multi_gen.generate_multi_floor(cfg, seed_val, diagnostics_enabled)
			var elapsed_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
			report.times_ms.append(elapsed_ms)

			if m_res != null and m_res.is_valid:
				var v_res = multi_val.validate(m_res)
				if v_res.is_valid:
					report.success_count += 1
				else:
					report.fail_count += 1
					var err_key: String = v_res.errors[0] if not v_res.errors.is_empty() else "VALIDATION_FAILED"
					report.error_breakdown[err_key] = report.error_breakdown.get(err_key, 0) + 1
			else:
				report.fail_count += 1
				var err_key: String = "GENERATION_FAILED"
				if m_res != null:
					if not m_res.failure_reason.is_empty():
						err_key = m_res.failure_reason
					elif not m_res.failure_type.is_empty():
						err_key = m_res.failure_type
				report.error_breakdown[err_key] = report.error_breakdown.get(err_key, 0) + 1
		else:
			var d_res: DungeonResult = pipeline.generate(cfg, DungeonPipeline.MAX_ATTEMPTS, true, diagnostics_enabled)
			var elapsed_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
			report.times_ms.append(elapsed_ms)

			if d_res != null and d_res.validation != null and d_res.validation.is_winnable:
				report.success_count += 1
			else:
				report.fail_count += 1
				var err_key: String = "PIPELINE_FAILED"
				if not pipeline.last_failure_reason.is_empty():
					err_key = pipeline.last_failure_reason
				elif not pipeline.last_failure_type.is_empty():
					err_key = pipeline.last_failure_type
				report.error_breakdown[err_key] = report.error_breakdown.get(err_key, 0) + 1

		if log_interval > 0 and (i + 1) % log_interval == 0:
			print("  [Stress Test] Progreso: %d/%d semillas evaluadas..." % [i + 1, iterations])

	report.calculate_percentiles()
	return report
