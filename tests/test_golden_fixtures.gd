extends SceneTree

## Suite de pruebas de regresión snapshot para PR-11B: Golden Fixtures.

func _init() -> void:
	print("================================================================")
	print("    EJECUTANDO SUITE DE GOLDEN FIXTURES - FASE 11 (REGRESION)   ")
	print("================================================================")

	var gfm_script = preload("res://src/dungeon_generator/debug/golden_fixture_manager.gd")
	var manager = gfm_script.new()

	var report: Dictionary = manager.verify_golden_seeds(2)

	print("\n--- Resultados de Verificación de Golden Seeds (20 Semillas) ---")
	print("  Total Semillas Evaluadas : %d" % report["total_seeds"])
	print("  Coincidencias Perfectas  : %d" % report["matched_seeds"])
	print("  Discrepancias / Deriva   : %d" % report["mismatched_seeds"])

	for r in report["results"]:
		if r["status"] == "PASS":
			print("    - Semilla %d: [PASS] (Habitaciones: %s)" % [r["seed"], str(r.get("rooms", "-"))])
		else:
			print("    - Semilla %d: [FAIL] (Reason: %s, Stage: %s, Identical: %s)" % [
				r["seed"], str(r.get("reason", "-")), str(r.get("stage", "-")), str(r.get("identical", "-"))
			])

	# Validar Invariantes de Golden Fixtures
	assert(report["total_seeds"] == 20, "Must evaluate exactly 20 golden seeds")
	assert(report["matched_seeds"] == 20, "All 20 golden seeds must match snapshot fingerprints with 0 drift")
	assert(report["mismatched_seeds"] == 0, "No golden seeds may suffer drift or divergence")

	print("\n>>> ALL PR-11B GOLDEN FIXTURES REGRESSION CHECKS PASSED SUCCESSFULLY! <<<\n")
	quit(0)
