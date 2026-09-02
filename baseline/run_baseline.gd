extends SceneTree

func _init() -> void:
	var diag = preload("res://src/dungeon_generator/diagnostics/dungeon_diagnostics.gd").new()
	diag.save_baseline(10001, 500, "baseline/experiment_500")
	print("[OK] Baseline 500 seeds generated.")
	quit(0)