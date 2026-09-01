extends SceneTree

func _init() -> void:
	var diag = preload("res://src/dungeon_generator/diagnostics/dungeon_diagnostics.gd").new()
	diag.save_baseline(10000, 100, "baseline/baseline")
	print("[OK] Baseline 100 seeds generated.")
	quit(0)