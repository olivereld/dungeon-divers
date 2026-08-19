extends SceneTree

## Suite de pruebas de estrés para PR-11A: Harness de Stress Testing Masivo.

func _init() -> void:
	print("================================================================")
	print("   EJECUTANDO SUITE DE STRESS TESTING MASIVO - FASE 11 (QA)    ")
	print("================================================================")

	var stress_tester_script = preload("res://src/dungeon_generator/debug/dungeon_stress_tester.gd")
	var tester = stress_tester_script.new()

	# Ejecutar batería de 10.000 semillas (multi-floor 2 niveles con validación formal completa)
	var report = tester.run_stress_test(10000, 200000, true, 500, false)

	print(report.to_summary_string())

	# Validar Invariantes de Hardening de la Fase 11
	assert(report.crash_count == 0, "Crash count must be exactly 0")
	assert(report.fail_count == 0, "Failure count must be 0 (got %d failures)" % report.fail_count)
	assert(report.get_success_rate() == 100.0, "Success rate must be 100%% (got %.2f%%)" % report.get_success_rate())
	assert(report.p95_ms < 50.0, "P95 latency must be under 50ms (got %.2f ms)" % report.p95_ms)

	print("\n>>> ALL PR-11A STRESS TESTING HARNESS CHECKS PASSED SUCCESSFULLY! <<<\n")
	quit(0)
