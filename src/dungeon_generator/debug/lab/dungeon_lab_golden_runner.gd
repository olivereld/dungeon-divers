class_name DungeonLabGoldenRunner
extends RefCounted

## Adaptador del verificador de regresión Golden Fixtures (20/20 semillas).

const _GoldenFixtureManagerScript = preload("res://src/dungeon_generator/debug/golden_fixture_manager.gd")
const _AsyncRunnerScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_async_runner.gd")

signal golden_progress(completed: int, total: int)
signal golden_completed(summary: Dictionary)

var _manager: RefCounted
var _runner: _AsyncRunnerScript

func _init() -> void:
	_manager = _GoldenFixtureManagerScript.new()
	_runner = _AsyncRunnerScript.new()
	_runner.progress.connect(func(c: int, t: int): golden_progress.emit(c, t))

func cancel() -> void:
	if _runner != null:
		_runner.cancel()

func run_golden_suite(p_runner: _AsyncRunnerScript = null) -> Dictionary:
	var runner_to_use = p_runner if p_runner != null else _runner
	var report: Dictionary = _manager.verify_golden_seeds(2)
	golden_completed.emit(report)
	return report
