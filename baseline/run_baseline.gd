extends SceneTree

func _init() -> void:
	var diag = preload("res://src/dungeon_generator/diagnostics/dungeon_diagnostics.gd").new()
	diag.save_baseline(10001, 100, "baseline/experiment_100")
	print("[OK] Baseline 100 seeds generated.")
	quit(0)