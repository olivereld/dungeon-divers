extends SceneTree

const _GoldenRunnerScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_golden_runner.gd")

func _init() -> void:
	print("--- Running test_dungeon_lab_golden_runner ---")
	var runner = _GoldenRunnerScript.new()
	var report = runner.run_golden_suite()

	assert(report != null, "FAIL: golden suite must return a report")
	assert(report["total_seeds"] == 20, "FAIL: expected 20 golden seeds")
	assert(report["matched_seeds"] == 20, "FAIL: expected 20 matching seeds")
	assert(report["mismatched_seeds"] == 0, "FAIL: expected 0 mismatches")
	assert(report.has("results") and report["results"].size() == 20, "FAIL: results list mismatch")

	print("PASS: test_dungeon_lab_golden_runner passed!")
	quit(0)
