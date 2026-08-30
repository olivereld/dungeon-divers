extends SceneTree

const _AsyncRunnerScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_async_runner.gd")

func _init() -> void:
	print("--- Running test_dungeon_lab_async_runner ---")
	var runner = _AsyncRunnerScript.new()

	# Test batch execution synchronously or via worker thread
	var seeds: Array[int] = [101, 102, 103, 104, 105]
	var progress_reports: Array[int] = []
	runner.progress.connect(func(c: int, _t: int): progress_reports.append(c))

	var results = runner.run_batch_sync(seeds, func(s: int):
		return s * 2
	)

	assert(results.size() == 5, "FAIL: expected 5 results")
	assert(results[0] == 202 and results[4] == 210, "FAIL: result calculation mismatch")
	assert(progress_reports.size() == 5, "FAIL: progress signal should fire for each item")

	# Test cancellation
	runner.cancel()
	assert(not runner.is_running(), "FAIL: runner should not be running after cancel")

	print("PASS: test_dungeon_lab_async_runner passed!")
	quit(0)
