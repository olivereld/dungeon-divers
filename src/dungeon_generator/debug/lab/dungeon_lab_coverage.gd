class_name DungeonLabCoverage
extends RefCounted

## Ejecutor de cobertura y balance multi-semilla para perfiles y plantillas.

const _PipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _AsyncRunnerScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_async_runner.gd")

signal coverage_progress(completed: int, total: int)
signal coverage_completed(report: Dictionary)

var _runner: _AsyncRunnerScript

func _init() -> void:
	_runner = _AsyncRunnerScript.new()
	_runner.progress.connect(func(c: int, t: int): coverage_progress.emit(c, t))

func cancel() -> void:
	if _runner != null:
		_runner.cancel()

func run_coverage(
	pipeline: _PipelineScript,
	archetype_id: StringName,
	seed_start: int = 100001,
	seed_count: int = 100
) -> Dictionary:
	var seeds: Array[int] = []
	for i in range(seed_count):
		seeds.append(seed_start + i)

	var total_rooms: int = 0
	var profile_dist: Dictionary = {}
	var template_counts: Dictionary = {}
	var fallback_count: int = 0
	var template_resolved_count: int = 0

	var results = _runner.run_batch_sync(seeds, func(s: int):
		var cfg := DungeonConfig.new()
		cfg.seed = s
		cfg.algorithm = "Hybrid"
		cfg.archetype_id = archetype_id
		cfg.grid_width = 64
		cfg.grid_height = 64
		return pipeline.generate(cfg)
	)

	for res in results:
		if res == null:
			continue
		for r in res.rooms:
			total_rooms += 1
			var p_id: StringName = r.custom_data.get("profile_id", str(r.room_type)) if "custom_data" in r else str(r.room_type)
			var t_id: StringName = r.custom_data.get("resolved_template_id", &"none") if "custom_data" in r else &"none"
			var is_fb: bool = r.custom_data.get("is_template_fallback", true) if "custom_data" in r else true

			profile_dist[p_id] = profile_dist.get(p_id, 0) + 1

			if not is_fb and t_id != &"procedural_fallback" and t_id != &"none":
				template_resolved_count += 1
				template_counts[t_id] = template_counts.get(t_id, 0) + 1
			else:
				fallback_count += 1

	var coverage_pct: float = 0.0
	if total_rooms > 0:
		coverage_pct = (float(template_resolved_count) / float(total_rooms)) * 100.0

	var report := {
		"archetype_id": archetype_id,
		"seed_start": seed_start,
		"seed_count": seed_count,
		"total_rooms": total_rooms,
		"profile_distribution": profile_dist,
		"template_selection_counts": template_counts,
		"template_resolved_count": template_resolved_count,
		"fallback_count": fallback_count,
		"coverage_percentage": coverage_pct
	}

	coverage_completed.emit(report)
	return report

func export_report(report: Dictionary, path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(report, "  "))
	f.close()
	return true
